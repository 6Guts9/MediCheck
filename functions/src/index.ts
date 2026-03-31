import {onCall} from "firebase-functions/v2/https";
import {setGlobalOptions} from "firebase-functions";
import fetch from "node-fetch";

setGlobalOptions({maxInstances: 10});

type JsonRecord = Record<string, unknown>;

function normalizeText(value: string): string {
  return value
    .toLowerCase()
    .replace(/\([^)]*\)/g, "")
    .replace(/[^a-z0-9\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

async function fetchJson(url: string): Promise<unknown | null> {
  try {
    const res = await fetch(url, {
      headers: {Accept: "application/json"},
    });
    if (!res.ok) return null;
    return await res.json();
  } catch (e) {
    console.error(`Fetch error for ${url}:`, e);
    return null;
  }
}

function asRecord(value: unknown): JsonRecord | null {
  if (typeof value === "object" && value !== null) {
    return value as JsonRecord;
  }
  return null;
}

function getStringArray(value: unknown): string[] {
  return Array.isArray(value) ? value.filter((v) => typeof v === "string") as string[] : [];
}

async function getRxCui(name: string): Promise<string | null> {
  const cleanName = normalizeText(name);

  const exact = await fetchJson(
    `https://rxnav.nlm.nih.gov/REST/rxcui.json?name=${encodeURIComponent(cleanName)}`
  );

  const exactRecord = asRecord(exact);
  const exactIdGroup = asRecord(exactRecord?.idGroup);
  const exactIds = getStringArray(exactIdGroup?.rxnormId);
  if (exactIds.length > 0) return exactIds[0];

  const approx = await fetchJson(
    `https://rxnav.nlm.nih.gov/REST/approximateTerm.json?term=${encodeURIComponent(cleanName)}&maxEntries=1`
  );
  const approxRecord = asRecord(approx);
  const approxGroup = asRecord(approxRecord?.approximateGroup);
  const candidates = Array.isArray(approxGroup?.candidate) ? approxGroup?.candidate as unknown[] : [];
  const firstCandidate = asRecord(candidates[0]);
  const approxId = firstCandidate && typeof firstCandidate.rxcui === "string" ? firstCandidate.rxcui : null;
  return approxId;
}

async function getClassesByRxcui(rxcui: string): Promise<string[]> {
  const data = await fetchJson(
    `https://rxnav.nlm.nih.gov/REST/rxclass/class/byRxcui.json?rxcui=${encodeURIComponent(rxcui)}&relaSource=ALL`
  );

  const record = asRecord(data);
  const drugInfoList = asRecord(record?.rxclassDrugInfoList);
  const infos = Array.isArray(drugInfoList?.rxclassDrugInfo) ? drugInfoList.rxclassDrugInfo as unknown[] : [];

  const classes = new Set<string>();

  for (const item of infos) {
    const itemRecord = asRecord(item);
    const classItem = asRecord(itemRecord?.rxclassMinConceptItem);
    const className = typeof classItem?.className === "string" ? classItem.className : null;
    if (className) {
      classes.add(normalizeText(className));
    }
  }

  return Array.from(classes);
}

async function getOpenFdaLabel(name: string): Promise<string> {
  const cleanName = normalizeText(name);

  const queries = [
    `https://api.fda.gov/drug/label.json?search=openfda.generic_name:${encodeURIComponent(cleanName)}&limit=1`,
    `https://api.fda.gov/drug/label.json?search=openfda.brand_name:${encodeURIComponent(cleanName)}&limit=1`,
  ];

  for (const url of queries) {
    const data = await fetchJson(url);
    const record = asRecord(data);
    const results = Array.isArray(record?.results) ? record.results as unknown[] : [];
    const first = asRecord(results[0]);
    if (first) {
      const parts: string[] = [];

      for (const key of ["drug_interactions", "warnings", "warnings_and_cautions", "contraindications"]) {
        const section = first[key];
        if (Array.isArray(section)) {
          parts.push(...section.filter((v) => typeof v === "string") as string[]);
        } else if (typeof section === "string") {
          parts.push(section);
        }
      }

      return parts.join(" ").toLowerCase();
    }
  }

  return "";
}

function containsAny(text: string, terms: string[]): boolean {
  return terms.some((term) => text.includes(normalizeText(term)));
}

function scoreFromEvidence(evidence: string[]): "HIGH" | "MODERATE" | "LOW" {
  const joined = evidence.join(" ").toLowerCase();

  if (/(contraindicated|fatal|life-threatening|serious bleeding|major bleeding|do not use)/i.test(joined)) {
    return "HIGH";
  }
  if (/(monitor|caution|increased risk|bleeding|ulcer|stomach irritation)/i.test(joined)) {
    return "MODERATE";
  }
  return "LOW";
}

function classBasedRules(classesA: string[], classesB: string[]) {
  const a = classesA.join(" ");
  const b = classesB.join(" ");

  const aHasNsaid = a.includes("nsaid") || a.includes("nonsteroidal anti inflammatory");
  const bHasNsaid = b.includes("nsaid") || b.includes("nonsteroidal anti inflammatory");
  const aHasSalicylate = a.includes("salicylate");
  const bHasSalicylate = b.includes("salicylate");
  const aHasAnticoagulant = a.includes("anticoagulant") || a.includes("blood coagulation");
  const bHasAnticoagulant = b.includes("anticoagulant") || b.includes("blood coagulation");
  if ((aHasNsaid && bHasNsaid) || (aHasSalicylate && bHasNsaid) || (bHasSalicylate && aHasNsaid)) {
    return {
      severity: "HIGH" as const,
      reason:
"Both drugs belong to NSAID/salicylate-type classes, which can increase stomach bleeding and ulcer risk.",
    };
  }

  if ((aHasNsaid && bHasAnticoagulant) || (bHasNsaid && aHasAnticoagulant)) {
    return {
      severity: "HIGH" as const,
      reason: "NSAID-type drugs can increase bleeding risk when combined with anticoagulant-related drugs.",
    };
  }

  return null;
}

export const checkInteraction = onCall(async (request) => {
  const drugA = String(request.data?.drugA ?? "").trim();
  const drugB = String(request.data?.drugB ?? "").trim();

  if (!drugA || !drugB) {
    return {error: "Drug names required"};
  }

  try {
    const rxcuiA = await getRxCui(drugA);
    const rxcuiB = await getRxCui(drugB);

    if (!rxcuiA || !rxcuiB) {
      return {
        severity: "NOT FOUND",
        description:
        `Could not identify:
  ${!rxcuiA ? drugA : drugB}.Try the generic name.`,
      };
    }

    const classesA = await getClassesByRxcui(rxcuiA);
    const classesB = await getClassesByRxcui(rxcuiB);

    const labelA = await getOpenFdaLabel(drugA);
    const labelB = await getOpenFdaLabel(drugB);

    const evidence: string[] = [];

    const classRule = classBasedRules(classesA, classesB);
    if (classRule) {
      evidence.push(classRule.reason);
    }

    const aText = labelA;
    const bText = labelB;

    const matchA = containsAny(aText, [drugB]);
    const matchB = containsAny(bText, [drugA]);

    if (matchA) {
      evidence.push(`FDA label for ${drugA} mentions ${drugB}.`);
    }

    if (matchB) {
      evidence.push(`FDA label for ${drugB} mentions ${drugA}.`);
    }

    const labelMatched = evidence.length > 0;

    if (!labelMatched && !classRule) {
      return {
        severity: "NO DATA",
        description:
"No reliable interaction evidence found in the supported sources for this pair.",
      };
    }

    const severityFromLabels = scoreFromEvidence([labelA, labelB, ...evidence]);
    const finalSeverity =
      classRule?.severity === "HIGH" ?
        "HIGH" :
        classRule?.severity === "MODERATE" ?
          "MODERATE" :
          severityFromLabels;

    const descriptionParts: string[] = [];

    if (classRule) {
      descriptionParts.push(classRule.reason);
    }

    if (evidence.length > 0) {
      descriptionParts.push(...evidence);
    }

    if (labelA) {
      descriptionParts.push(`FDA label evidence was found for ${drugA}.`);
    }
    if (labelB) {
      descriptionParts.push(`FDA label evidence was found for ${drugB}.`);
    }

    return {
      severity: finalSeverity,
      description: descriptionParts.join(" "),
      rxcuiA,
      rxcuiB,
      classesA,
      classesB,
    };
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown error";
    console.error("Interaction Error:", error);
    return {
      severity: "ERROR",
      description: `System error: ${message}`,
    };
  }
});

export const getRxId = onCall(async (request) => {
  const name = String(request.data?.name ?? "").trim();
  if (!name) return {error: "No name provided"};
  const id = await getRxCui(name);
  return {rxcui: id};
});
