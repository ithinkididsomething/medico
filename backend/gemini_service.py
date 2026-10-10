"""
SMART Referral - Gemini AI Clinical Symptom Analysis Service
Connects to Google Gemini API securely on the backend when online.
Strictly validates schemas, handles timeouts, enforces mandatory clinical safety rules,
and falls back to deterministic clinical rules whenever offline or unavailable.
Differentiates technical failure states from genuine clinical uncertainty.
"""

import json
import logging
import os
import re
import urllib.error
import urllib.request
from typing import Dict, Any, List

import clinical_rules

logger = logging.getLogger("gemini_service")

# Secure API Key and Model configuration
def _load_env_file():
    paths = [
        os.path.join(os.path.dirname(os.path.abspath(__file__)), ".env"),
        os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".env"),
    ]
    for path in paths:
        if os.path.exists(path):
            try:
                with open(path, "r", encoding="utf-8") as f:
                    for line in f:
                        line = line.strip()
                        if line and not line.startswith("#") and "=" in line:
                            k, v = line.split("=", 1)
                            k = k.strip()
                            v = v.strip().strip("'").strip('"')
                            if k and (k not in os.environ or not os.environ[k]):
                                os.environ[k] = v
            except Exception:
                pass

_load_env_file()

def _get_configured_api_key() -> str:
    _load_env_file()
    key = os.environ.get("GEMINI_API_KEY", "").strip()
    if not key:
        key = os.environ.get("GOOGLE_API_KEY", "").strip()
    return key

def _get_model_name() -> str:
    _load_env_file()
    return os.environ.get("GEMINI_MODEL", "gemini-3.8-flash").strip()

def _get_gemini_api_url() -> str:
    model = _get_model_name()
    return f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"

REQUEST_TIMEOUT_SECONDS = 30


def analyze_patient_presentation(
    free_text: str,
    vitals: Dict[str, Any] = None,
    selected_tags: List[str] = None,
    patient_age: int = None,
    patient_sex: str = None,
    client_offline: bool = False,
) -> Dict[str, Any]:
    """
    Analyzes patient free-text presentation and vital parameters.
    Online: Queries Gemini 1.5 Flash securely, validates JSON schema, extracts structured vitals,
            and enforces mandatory safety checks.
    Offline / Fallback: Runs clinician-approved deterministic rule engine.
    """
    vitals = vitals or {}
    selected_tags = selected_tags or []
    api_key = _get_configured_api_key()

    # 1. Run local deterministic screening first (baseline safety ground-truth & extraction)
    safety_rule_result = clinical_rules.evaluate_clinical_presentation(
        free_text=free_text,
        vitals=vitals,
        selected_tags=selected_tags,
        patient_age=patient_age,
        patient_sex=patient_sex,
    )

    # If client is marked offline, report offline rules truthfully
    if client_offline:
        res = dict(safety_rule_result)
        res["assessment_source"] = "offline_rules"
        res["gemini_available"] = False
        res["service_available"] = False
        res["analysis_status"] = "service_unavailable"
        res["source_label"] = "Offline rule-based assessment — client offline"
        return res

    # If no API key configured, return technical status (not false clinical conclusion)
    if not api_key:
        logger.info("[GeminiService] No API key configured. Executing offline clinical rules.")
        res = dict(safety_rule_result)
        res["assessment_source"] = "offline_rules"
        res["gemini_available"] = False
        res["service_available"] = False
        res["analysis_status"] = "authentication_error"
        res["source_label"] = "AI analysis unavailable (No API key configured) — using offline clinical rules"
        res["technical_error"] = "No GEMINI_API_KEY found in server environment."
        return res

    # 2. Online Gemini Request Construction
    merged_vitals = safety_rule_result.get("extracted_vitals", {})

    prompt = f"""
You are an assistive clinical triage support assistant for primary healthcare clinics in rural India.
Analyze the following patient presentation notes and extract all factual clinical findings.
Do not provide a definitive diagnosis. Provide structured assistive triage recommendation only.

PATIENT CONTEXT:
- Age: {patient_age if patient_age is not None else 'Unrecorded'}
- Sex: {patient_sex if patient_sex else 'Unrecorded'}
- Known Vital Signs: {json.dumps(merged_vitals)}
- Clinician Selected Tags: {json.dumps(selected_tags)}
- Free-Text Description:
\"\"\"{free_text}\"\"\"

CLINICAL TRIAGE DEFINITIONS:
- Urgency Level 1 — Immediate Emergency: Potentially life-threatening, immediate emergency response & stabilization needed.
- Urgency Level 2 — Urgent: Prompt evaluation or hospital transfer required.
- Urgency Level 3 — Priority Assessment: Timely clinical assessment within 12-24 hours.
- Urgency Level 4 — Routine Assessment: Non-emergency primary care outpatient post assessment.
- Referral Level A: Local Clinic / Primary Care
- Referral Level B: Secondary District Hospital
- Referral Level C: Tertiary / Super-Specialty Medical Centre
- Referral Level D: Immediate Emergency Stabilization & Transfer

CRITICAL CLINICAL EXTRACTION RULES:
1. Extract ALL mentioned vital signs (SpO2, pulse/heart rate, blood pressure, temperature, respiratory rate) explicitly present in the text.
2. Missing or ambiguous symptoms must NEVER automatically produce a reassuring low-urgency result.
3. If critical vital signs are abnormal (e.g. SpO2 < 90%, BP < 85 or > 180, HR > 135), assign Level 1.
4. Separate symptoms, duration, medical history, missing information, and suggested tags cleanly. Do not produce single large text dumps.

Respond ONLY with valid JSON matching this exact structure:
{{
  "extracted_symptoms": ["list", "of", "individual", "symptoms"],
  "extracted_vitals": {{
    "spo2": null,
    "heart_rate": null,
    "systolic_bp": null,
    "diastolic_bp": null,
    "temperature": null,
    "respiratory_rate": null
  }},
  "duration": "onset duration string if known, else 'Unknown'",
  "onset": "sudden/gradual/unknown",
  "severity": "mild/moderate/severe/critical",
  "relevant_history": ["list of medical history noted or inferred"],
  "reported_warning_signs": ["list of warning signs"],
  "missing_information": ["list of missing vitals or clinical details"],
  "follow_up_questions": ["questions the clinician should ask"],
  "suggested_tags": ["clinical category tags like 'Low SpO₂', 'Breathing difficulty', etc."],
  "urgency_level": 1, 2, 3, or 4,
  "urgency_label": "Level 1 — Immediate Emergency",
  "referral_level": "Referral A", "Referral B", "Referral C", or "Referral D",
  "referral_label": "Referral D — Immediate Emergency Stabilization & Transfer",
  "reasoning": "Clear, concise clinical explanation of why this level was selected",
  "red_flags": ["list of red flags if present"],
  "is_emergency": true or false
}}
"""

    payload = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {
            "temperature": 0.1,
            "responseMimeType": "application/json",
            "thinkingConfig": {
                "thinkingBudget": 0,
            },
        },
    }

    req_url = f"{_get_gemini_api_url()}?key={api_key}"
    headers = {"Content-Type": "application/json; charset=utf-8"}
    req_body = json.dumps(payload).encode("utf-8")

    try:
        req = urllib.request.Request(req_url, data=req_body, headers=headers, method="POST")
        with urllib.request.urlopen(req, timeout=REQUEST_TIMEOUT_SECONDS) as resp:
            resp_body = resp.read().decode("utf-8")
            data = json.loads(resp_body)
            raw_text = data["candidates"][0]["content"]["parts"][0]["text"]
            
            # Robust JSON parsing: strip any markdown code blocks
            clean_json_str = re.sub(r'^```(?:json)?\s*', '', raw_text.strip(), flags=re.MULTILINE)
            clean_json_str = re.sub(r'\s*```$', '', clean_json_str.strip(), flags=re.MULTILINE)
            parsed_json = json.loads(clean_json_str)

            # Validate schema
            validated = _validate_and_sanitize_gemini_output(parsed_json, fallback=safety_rule_result)

            # Non-negotiable Clinical Safety Override:
            # Gemini must NOT downgrade an urgency level established by a mandatory safety rule
            if len(safety_rule_result["red_flags"]) > 0:
                if validated["urgency_level"] > safety_rule_result["urgency_level"]:
                    validated["safety_override_applied"] = True
                    validated["urgency_level"] = safety_rule_result["urgency_level"]
                    validated["urgency_label"] = clinical_rules.URGENCY_LABELS[safety_rule_result["urgency_level"]]
                    validated["referral_level"] = safety_rule_result["referral_level"]
                    validated["referral_label"] = clinical_rules.REFERRAL_LABELS[safety_rule_result["referral_level"]]
                    validated["is_emergency"] = safety_rule_result["is_emergency"]
                    validated["reasoning"] = (
                        f"MANDATORY SAFETY RULE ENFORCED: Local red flag rule ({'; '.join(safety_rule_result['red_flags'])}) "
                        f"prevented AI downgrade. Original AI suggestion: {validated['reasoning']}"
                    )
                    for rf in safety_rule_result["red_flags"]:
                        if rf not in validated["red_flags"]:
                            validated["red_flags"].append(rf)

            for mi in safety_rule_result["missing_information"]:
                if mi not in validated["missing_information"]:
                    validated["missing_information"].append(mi)

            # Merge vitals extracted locally if model missed any
            for k, v in safety_rule_result.get("extracted_vitals", {}).items():
                if validated["extracted_vitals"].get(k) is None and v is not None:
                    validated["extracted_vitals"][k] = v

            validated["assessment_source"] = "gemini"
            validated["gemini_available"] = True
            validated["source_label"] = "Gemini AI Assisted — clinician review required"
            validated["model_version"] = _get_model_name()
            validated["ruleset_version"] = "indore-clinical-safety-v1"
            validated["service_available"] = True
            validated["disclaimer"] = "AI recommendation is an assistive tool — not an autonomous diagnostic decision. Clinician review required."

            # Result status
            if validated["is_emergency"] or len(validated["red_flags"]) > 0:
                validated["analysis_status"] = "safety_escalation"
            elif validated.get("is_undetermined"):
                validated["analysis_status"] = "insufficient_information"
            elif len(validated["missing_information"]) > 0:
                validated["analysis_status"] = "partial"
            else:
                validated["analysis_status"] = "success"

            return validated

    except urllib.error.HTTPError as e:
        status_code = e.code
        if status_code in (401, 403):
            err_type = "authentication_error"
            msg = "Invalid or expired Gemini API credentials."
        elif status_code == 429:
            err_type = "rate_limited"
            msg = "Gemini API rate limit exceeded."
        elif status_code == 400:
            err_type = "invalid_response"
            msg = "Bad request to Gemini API or schema rejected."
        else:
            err_type = "service_unavailable"
            msg = f"Gemini API returned HTTP {status_code}."

        logger.warning(f"[GeminiService] Technical failure ({err_type}): {msg}")
        fallback = dict(safety_rule_result)
        fallback["assessment_source"] = "offline_rules"
        fallback["gemini_available"] = False
        fallback["service_available"] = False
        fallback["analysis_status"] = err_type
        fallback["source_label"] = f"AI analysis unavailable ({msg}) — using offline clinical rules"
        fallback["last_error"] = msg
        return fallback

    except urllib.error.URLError as e:
        logger.warning(f"[GeminiService] Network failure: {e}")
        fallback = dict(safety_rule_result)
        fallback["assessment_source"] = "offline_rules"
        fallback["gemini_available"] = False
        fallback["service_available"] = False
        fallback["analysis_status"] = "service_unavailable"
        fallback["source_label"] = "AI analysis unavailable (Network connection failed) — using offline clinical rules"
        fallback["last_error"] = str(e.reason) if hasattr(e, "reason") else str(e)
        return fallback

    except TimeoutError as e:
        logger.warning(f"[GeminiService] Request timeout: {e}")
        fallback = dict(safety_rule_result)
        fallback["assessment_source"] = "offline_rules"
        fallback["gemini_available"] = False
        fallback["service_available"] = False
        fallback["analysis_status"] = "timeout"
        fallback["source_label"] = "AI analysis unavailable (Request timed out) — using offline clinical rules"
        fallback["last_error"] = "Gemini request timed out after 8 seconds."
        return fallback

    except json.JSONDecodeError as e:
        logger.warning(f"[GeminiService] Malformed JSON from model: {e}")
        fallback = dict(safety_rule_result)
        fallback["assessment_source"] = "offline_rules"
        fallback["gemini_available"] = False
        fallback["service_available"] = False
        fallback["analysis_status"] = "invalid_response"
        fallback["source_label"] = "AI analysis unavailable (Model output malformed) — using offline clinical rules"
        fallback["last_error"] = "Failed to parse JSON response from Gemini."
        return fallback

    except Exception as e:
        logger.error(f"[GeminiService] Unexpected error: {e}")
        fallback = dict(safety_rule_result)
        fallback["assessment_source"] = "offline_rules"
        fallback["gemini_available"] = False
        fallback["service_available"] = False
        fallback["analysis_status"] = "service_unavailable"
        fallback["source_label"] = "AI analysis unavailable — using offline clinical rules"
        fallback["last_error"] = str(e)
        return fallback


def _validate_and_sanitize_gemini_output(raw: Dict[str, Any], fallback: Dict[str, Any]) -> Dict[str, Any]:
    """Validates and coerces model output into strict application schema."""
    urgency = raw.get("urgency_level")
    if not isinstance(urgency, int) or urgency not in [1, 2, 3, 4]:
        urgency = fallback.get("urgency_level", 3)

    referral = raw.get("referral_level")
    if referral not in [clinical_rules.REFERRAL_A, clinical_rules.REFERRAL_B, clinical_rules.REFERRAL_C, clinical_rules.REFERRAL_D]:
        referral = fallback.get("referral_level", clinical_rules.REFERRAL_B)

    # Sanitize extracted vitals
    vitals_raw = raw.get("extracted_vitals")
    if not isinstance(vitals_raw, dict):
        vitals_raw = {}

    sanitized_vitals: Dict[str, Any] = {}
    for key in ["spo2", "heart_rate", "systolic_bp", "diastolic_bp", "temperature", "respiratory_rate"]:
        val = vitals_raw.get(key)
        if val is not None:
            try:
                sanitized_vitals[key] = float(val) if key in ("spo2", "temperature") else int(val)
            except (ValueError, TypeError):
                pass

    return {
        "extracted_symptoms": list(raw.get("extracted_symptoms") or fallback.get("extracted_symptoms", [])),
        "extracted_vitals": sanitized_vitals,
        "duration": str(raw.get("duration") or fallback.get("duration", "Unknown")),
        "onset": str(raw.get("onset") or fallback.get("onset", "Unknown")),
        "severity": str(raw.get("severity") or "moderate"),
        "relevant_history": list(raw.get("relevant_history") or fallback.get("relevant_history", [])),
        "reported_warning_signs": list(raw.get("reported_warning_signs") or []),
        "missing_information": list(raw.get("missing_information") or fallback.get("missing_information", [])),
        "follow_up_questions": list(raw.get("follow_up_questions") or fallback.get("follow_up_questions", [])),
        "suggested_tags": list(raw.get("suggested_tags") or fallback.get("suggested_tags", [])),
        "urgency_level": urgency,
        "urgency_label": clinical_rules.URGENCY_LABELS.get(urgency, "Level 3 — Priority Assessment"),
        "referral_level": referral,
        "referral_label": clinical_rules.REFERRAL_LABELS.get(referral, "Referral B — Secondary District Hospital"),
        "reasoning": str(raw.get("reasoning") or fallback.get("reasoning", "Clinical assessment based on presenting symptoms.")),
        "red_flags": list(raw.get("red_flags") or fallback.get("red_flags", [])),
        "is_emergency": raw.get("is_emergency") is True or urgency == 1,
        "is_undetermined": raw.get("is_undetermined") is True,
        "safety_override_applied": False,
    }
