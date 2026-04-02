import {onCall, CallableRequest} from "firebase-functions/v2/https";
import {setGlobalOptions} from "firebase-functions";
import * as admin from "firebase-admin";
import fetch from "node-fetch";
import {VertexAI} from "@google-cloud/vertexai";

admin.initializeApp();
setGlobalOptions({maxInstances: 10});

/**
 * Normalizes text for better comparison.
 * @param {string} value Text to normalize.
 * @return {string} Normalized text.
 */
function normalizeText(value: string): string {
  return value.toLowerCase()
    .replace(/\([^)]*\)/g, "")
    .replace(/[^a-z0-9\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

/**
 * Robustly fetches JSON with error handling.
 * @param {string} url URL to fetch.
 * @return {Promise<any>} Parsed JSON.
 */
async function fetchJson(url: string): Promise<any> {
  try {
    const res = await fetch(url, {headers: {Accept: "application/json"}});
    if (!res.ok) return null;
    return await res.json();
  } catch (e) {
    return null;
  }
}

/**
 * Ultimate RxCUI Lookup: Handles Brand names, Generics, and Typos.
 * @param {string} name Drug name.
 * @return {Promise<string | null>} RxCUI.
 */
async function getUltimateRxCui(name: string): Promise<string | null> {
  const clean = normalizeText(name);
  if (!clean) return null;

  // 1. Try RxNorm Exact
  const exact = await fetchJson(
    `https://rxnav.nlm.nih.gov/REST/rxcui.json?name=${encodeURIComponent(clean)}`
  );
  if (exact?.idGroup?.rxnormId?.[0]) return exact.idGroup.rxnormId[0];

  // 2. Try RxNorm Approximate (Great for "Paracetamol" vs "Acetaminophen")
  const approx = await fetchJson(
    `https://rxnav.nlm.nih.gov/REST/approximateTerm.json?term=${
      encodeURIComponent(clean)}&maxEntries=1`
  );
  if (approx?.approximateGroup?.candidate?.[0]?.rxcui) {
    return approx.approximateGroup.candidate[0].rxcui;
  }

  // 3. Try RxTerms
  const terms = await fetchJson(
    `https://rxnav.nlm.nih.gov/REST/RxTerms/rxcui.json?name=${
      encodeURIComponent(clean)}`
  );
  if (terms?.idGroup?.rxnormId?.[0]) return terms.idGroup.rxnormId[0];

  return null;
}

/**
 * Gets pharmacological classes and generic ingredients.
 * @param {string} rxcui Drug RxCUI.
 * @return {Promise<{classes: string[], ingredients: string[]}>} Context.
 */
async function getMedicalContext(rxcui: string) {
  const classData = await fetchJson(
    `https://rxnav.nlm.nih.gov/REST/rxclass/class/byRxcui.json?rxcui=${
      rxcui}&relaSource=EPC`
  );
  const classes = (classData?.rxclassDrugInfoList?.rxclassDrugInfo || [])
    .map((i: any) => i.rxclassMinConceptItem.className.toLowerCase());

  const relData = await fetchJson(
    `https://rxnav.nlm.nih.gov/REST/rxcui/${rxcui}/related.json?tty=IN`
  );
  const ingredients = (relData?.relatedGroup?.conceptGroup?.[0]
    ?.conceptProperties || []).map((p: any) => p.name.toLowerCase());

  return {classes, ingredients};
}

/**
 * Fetches relevant FDA Label warnings.
 * @param {string} name Drug name.
 * @return {Promise<string>} Warnings text.
 */
async function getFdaWarnings(name: string): Promise<string> {
  const cleanName = normalizeText(name);
  const data = await fetchJson(
    `https://api.fda.gov/drug/label.json?search=openfda.generic_name:"${
      encodeURIComponent(cleanName)}"&limit=1`
  );
  const result = data?.results?.[0];
  if (!result) return "No FDA label data found.";
  return [
    result.drug_interactions,
    result.warnings,
    result.contraindications,
  ].flat().filter((p) => typeof p === "string").join(" ");
}

export const checkInteraction = onCall(async (request: CallableRequest) => {
  const uid = request.auth?.uid;
  const searchedDrugs: string[] = request.data?.drugs || [];

  try {
    let userData: any = {};
    if (uid) {
      const doc = await admin.firestore().collection("user").doc(uid).get();
      userData = doc.data() || {};
    }

    const profileMeds = (userData["current meds"] || []).map((m: any) => m.name);
    const allUniqueMeds = [...new Set([...searchedDrugs, ...profileMeds])];

    const medAnalysis = await Promise.all(allUniqueMeds.map(async (name) => {
      const rxcui = await getUltimateRxCui(name);
      const context = rxcui ?
        await getMedicalContext(rxcui) :
        {classes: [], ingredients: []};
      const warnings = await getFdaWarnings(name);
      return {name, rxcui, ...context, warnings};
    }));

    const prompt = `
      MEDICAL SAFETY ANALYSIS TASK
      USER PROFILE:
      - Age: ${userData.age}, Gender: ${userData.gender}
      - Chronic Diseases: ${JSON.stringify(userData.ChronicalDiseases || [])}
      - Allergies: ${JSON.stringify(userData.allergies || [])}
      - Past Surgeries: ${JSON.stringify(userData.surgeries || [])}

      MEDICATIONS TO ANALYZE (USER IS CURRENTLY SEARCHING):
      ${searchedDrugs.join(", ")}

      ALL MEDICATION CONTEXT (SEARCHED + CURRENT PROFILE MEDS):
      ${medAnalysis.map((m) => `- ${m.name} (Ingredients: ${
    m.ingredients.join(", ")}, Classes: ${m.classes.join(", ")})`).join("\n")}

      FDA WARNING DATA:
      ${medAnalysis.map((m) => `Warnings for ${m.name}: ${
    m.warnings.substring(0, 500)}`).join("\n")}

      INSTRUCTIONS:
      1. Identify interactions between the searched medications.
      2. Identify interactions between searched medications and profile meds.
      3. Identify risks based on User's Profile (Allergies, Diseases).
      4. Determine severity (HIGH, MODERATE, LOW).
      5. Provide a detailed medical explanation of WHY this severity was chosen.
      6. If an allergy matches an ingredient, set severity to HIGH.

      RETURN JSON ONLY: {"severity": "HIGH"|"MODERATE"|"LOW",
      "description": "Full detailed medical explanation."}
    `;

    const vertexAI = new VertexAI({
      project: "medicheck-b9455",
      location: "us-central1",
    });

    // Using gemini-1.5-flash-002 as it's more widely available and faster
    const model = vertexAI.getGenerativeModel({model: "gemini-2.5-flash-lite"});

    const aiRes = await model.generateContent({
      contents: [{role: "user", parts: [{text: prompt}]}],
    });
    const text = aiRes.response.candidates?.[0].content.parts[0].text;

    if (text) {
      const match = text.match(/\{[\s\S]*\}/);
      return JSON.parse(match ? match[0] : text);
    }

    return {severity: "ERROR", description: "AI failed to generate report."};
  } catch (error) {
    const err = error as Error;
    return {severity: "ERROR", description: `System error: ${err.message}`};
  }
});

export const getRxId = onCall(async (request: CallableRequest) => {
  const name = String(request.data?.name ?? "").trim();
  const id = await getUltimateRxCui(name);
  return {rxcui: id};
});
