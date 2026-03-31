import { onCall, CallableRequest } from "firebase-functions/v2/https";
import fetch from "node-fetch";

/**
 * Helper to fetch JSON from APIs
 */
async function fetchJson(url: string) {
  try {
    const res = await fetch(url, { headers: { 'Accept': 'application/json' } });
    if (!res.ok) return null;
    return await res.json() as any;
  } catch (e) {
    return null;
  }
}

/**
 * Gets the Generic Name and Pharmacological Classes (e.g. NSAID) for a drug
 */
async function getDrugMetadata(name: string) {
  const cleanName = name.split('(')[0].trim();
  try {
    // 1. Get RxCUI
    const idRes = await fetchJson(`https://rxnav.nlm.nih.gov/REST/rxcui.json?name=${encodeURIComponent(cleanName)}`);
    const rxcui = idRes?.idGroup?.rxnormId?.[0];
    if (!rxcui) return { genericName: cleanName, classes: [] };

    // 2. Get Classes (EPC - Explicit Pharmacological Class)
    const classRes = await fetchJson(`https://rxnav.nlm.nih.gov/REST/rxclass/class/byRxcui.json?rxcui=${rxcui}&relaSource=EPC`);
    const classes: string[] = [];
    const concepts = classRes?.rxclassDrugInfoList?.rxclassDrugInfo || [];
    for (const info of concepts) {
      classes.push(info.rxclassMinConceptItem.className.toLowerCase());
    }

    return { genericName: cleanName.toLowerCase(), classes };
  } catch (e) {
    return { genericName: cleanName.toLowerCase(), classes: [] };
  }
}

export const checkInteraction = onCall(async (request: CallableRequest) => {
  const drugA = request.data.drugA;
  const drugB = request.data.drugB;

  if (!drugA || !drugB) return { error: "Drug names required" };

  try {
    // 1. Get metadata (Name + Classes) for both
    const metaA = await getDrugMetadata(drugA);
    const metaB = await getDrugMetadata(drugB);

    // 2. Fetch FDA Labels
    const fetchLabel = async (name: string) => {
      const url = `https://api.fda.gov/drug/label.json?search=openfda.generic_name:"${encodeURIComponent(name)}"&limit=1`;
      const data = await fetchJson(url);
      return data?.results?.[0];
    };

    const labelA = await fetchLabel(metaA.genericName);
    const labelB = await fetchLabel(metaB.genericName);

    // 3. Define interaction check logic
    const analyze = (label: any, targetMeta: any) => {
      if (!label || !label.drug_interactions) return null;
      const text = label.drug_interactions.join(" ").toLowerCase();

      // Look for generic name
      if (text.includes(targetMeta.genericName)) return label.drug_interactions.join(" ");

      // Look for common class abbreviations/shorthand
      const shorthand: Record<string, string[]> = {
        "nonsteroidal anti-inflammatory": ["nsaid", "non-steroidal", "nonsteroidal"],
        "anticoagulant": ["blood thinner", "warfarin"],
        "antihistamine": ["allergy medicine"]
      };

      // Check classes and shorthand
      for (const cls of targetMeta.classes) {
        if (text.includes(cls)) return label.drug_interactions.join(" ");
        for (const [key, terms] of Object.entries(shorthand)) {
          if (cls.includes(key) && terms.some(t => text.includes(t))) {
            return label.drug_interactions.join(" ");
          }
        }
      }
      return null;
    };

    // 4. Run bidirectional analysis
    let interactionText = analyze(labelA, metaB) || analyze(labelB, metaA);

    if (!interactionText) {
      return {
        severity: "NONE",
        description: "No specific interaction warnings found in FDA records for this pair."
      };
    }

    // 5. Severity scoring based on critical keywords
    let severity = "MODERATE";
    const highRisk = /contraindicated|fatal|life-threatening|serious bleeding|stomach bleeding|do not use/i;
    const moderateRisk = /monitor|caution|ask a doctor|increase the risk/i;

    if (highRisk.test(interactionText)) severity = "HIGH";
    else if (moderateRisk.test(interactionText)) severity = "MODERATE";
    else severity = "LOW";

    return {
      severity,
      description: interactionText.slice(0, 600) + "..."
    };

  } catch (error: any) {
    return { severity: "ERROR", description: error.message };
  }
});

// Standalone ID lookup for autocomplete
export const getRxId = onCall(async (request: CallableRequest) => {
  const name = request.data.name;
  if (!name) return { error: "No name provided" };
  const res = await fetch(`https://rxnav.nlm.nih.gov/REST/rxcui.json?name=${encodeURIComponent(name)}`);
  return await res.json();
});