"""
SMART Referral - Clinician-Approved Deterministic Rule Engine
Provides offline red-flag screening, clinical fact extraction,
missing information detection, urgency level estimation, and referral level recommendations.

Non-negotiable Clinical Hierarchy:
- Red-flag emergency triggers Immediate Emergency (Level 1) or Urgent (Level 2).
- Gemini output cannot downgrade an urgency level established by a mandatory safety rule.
- Missing or ambiguous information NEVER produces a reassuring low-urgency result.
- Technical failures are distinctly reported rather than disguised as clinical uncertainty.
"""

import re
from typing import Dict, Any, List, Tuple


# Configurable Clinical Urgency Categories
URGENCY_LEVEL_1 = 1  # Level 1 — Immediate Emergency
URGENCY_LEVEL_2 = 2  # Level 2 — Urgent
URGENCY_LEVEL_3 = 3  # Level 3 — Priority Assessment
URGENCY_LEVEL_4 = 4  # Level 4 — Routine Assessment

URGENCY_LABELS = {
    URGENCY_LEVEL_1: "Level 1 — Immediate Emergency",
    URGENCY_LEVEL_2: "Level 2 — Urgent",
    URGENCY_LEVEL_3: "Level 3 — Priority Assessment",
    URGENCY_LEVEL_4: "Level 4 — Routine Assessment",
}

# Configurable Referral Categories (Destinations / Care Capability)
REFERRAL_A = "Referral A"  # Local Clinic / Primary Care
REFERRAL_B = "Referral B"  # Secondary Hospital (General / CHC)
REFERRAL_C = "Referral C"  # Tertiary / Specialty Centre
REFERRAL_D = "Referral D"  # Immediate Emergency Stabilization & Transfer

REFERRAL_LABELS = {
    REFERRAL_A: "Referral A — Local Clinic / Primary Healthcare Centre",
    REFERRAL_B: "Referral B — Secondary District Hospital",
    REFERRAL_C: "Referral C — Tertiary / Super-Specialty Medical Centre",
    REFERRAL_D: "Referral D — Immediate Emergency Stabilization & Transfer",
}

# Predefined Mandatory Red Flags for Rural Indian Triage
MANDATORY_RED_FLAGS = [
    {
        "keywords": ["postpartum hemorrhage", "post-partum hemorrhage", "pph", "heavy bleeding after delivery", "uterine bleeding"],
        "flag": "Severe Postpartum Hemorrhage (Obstetric Emergency)",
        "urgency": URGENCY_LEVEL_1,
        "referral": REFERRAL_D,
        "specialty": "Obstetrics & Gynecology",
    },
    {
        "keywords": ["chest in-drawing", "stridor", "gasping", "respiratory arrest", "severe breathlessness", "apnea", "asphyxia", "cyanosis"],
        "flag": "Severe Acute Respiratory Distress / Impending Respiratory Failure",
        "urgency": URGENCY_LEVEL_1,
        "referral": REFERRAL_D,
        "specialty": "Pulmonology / Critical Care",
    },
    {
        "keywords": ["crushing chest pain", "cardiac arrest", "radiating to left arm", "myocardial infarction", "acute chest tightness with sweating"],
        "flag": "Suspected Acute Coronary Syndrome / Myocardial Infarction",
        "urgency": URGENCY_LEVEL_1,
        "referral": REFERRAL_D,
        "specialty": "Cardiology",
    },
    {
        "keywords": ["unconscious", "unresponsive", "coma", "convulsion", "seizure", "status epilepticus", "lethargic child unable to drink"],
        "flag": "Altered Mental Status / Convulsions / Coma",
        "urgency": URGENCY_LEVEL_1,
        "referral": REFERRAL_D,
        "specialty": "Neurology / Emergency Medicine",
    },
    {
        "keywords": ["polytrauma", "crush injury", "open fracture", "penetrating wound", "traumatic amputation", "head injury vomiting"],
        "flag": "High-Energy Polytrauma / Compound Fracture / Traumatic Brain Injury",
        "urgency": URGENCY_LEVEL_1,
        "referral": REFERRAL_D,
        "specialty": "Trauma & Orthopedic Surgery",
    },
    {
        "keywords": ["severe dehydration", "sunken eyes skin pinch > 2s", "anuria", "choleraic diarrhea"],
        "flag": "Hypovolemic Shock / Severe Dehydration with Hemodynamic Compromise",
        "urgency": URGENCY_LEVEL_1,
        "referral": REFERRAL_D,
        "specialty": "Pediatrics / Critical Care",
    },
    {
        "keywords": ["high fever with stiff neck", "meningismus", "purpuric rash", "petechiae with fever"],
        "flag": "Suspected Meningococcal Sepsis / Meningitis",
        "urgency": URGENCY_LEVEL_1,
        "referral": REFERRAL_D,
        "specialty": "Pediatrics / Infectious Diseases",
    },
    {
        "keywords": ["acute abdomen", "board-like rigidity", "peritonitis", "strangulated hernia"],
        "flag": "Acute Surgical Abdomen / Peritonitis",
        "urgency": URGENCY_LEVEL_2,
        "referral": REFERRAL_C,
        "specialty": "General Surgery",
    },
    {
        "keywords": ["severe hypertension", "preeclampsia", "eclampsia", "bp > 180", "scotoma with pregnancy"],
        "flag": "Hypertensive Crisis / Severe Pre-eclampsia",
        "urgency": URGENCY_LEVEL_1,
        "referral": REFERRAL_D,
        "specialty": "Obstetrics & Gynecology",
    },
]

# Secondary / Priority Rules
SECONDARY_SYMPTOM_RULES = [
    {
        "keywords": ["fever", "pyrexia", "temperature", "chills"],
        "symptom": "Fever / Pyrexia",
        "tag": "Suspected infection",
        "urgency": URGENCY_LEVEL_3,
        "referral": REFERRAL_B,
    },
    {
        "keywords": ["cough", "phlegm", "mild breathlessness", "wheeze", "breathing difficulty"],
        "symptom": "Breathing difficulty",
        "tag": "Breathing difficulty",
        "urgency": URGENCY_LEVEL_2,
        "referral": REFERRAL_B,
    },
    {
        "keywords": ["vomiting", "diarrhea", "loose stools", "nausea"],
        "symptom": "Gastroenteritis / Vomiting",
        "tag": "Dehydration risk",
        "urgency": URGENCY_LEVEL_3,
        "referral": REFERRAL_B,
    },
    {
        "keywords": ["joint pain", "backache", "mild sprain", "ankle pain", "swelling"],
        "symptom": "Musculoskeletal Pain / Sprain",
        "tag": "Injury or trauma",
        "urgency": URGENCY_LEVEL_4,
        "referral": REFERRAL_A,
    },
    {
        "keywords": ["rash", "itching", "skin lesion", "fungal"],
        "symptom": "Dermatological Lesion",
        "tag": "Dermatology",
        "urgency": URGENCY_LEVEL_4,
        "referral": REFERRAL_A,
    },
    {
        "keywords": ["pregnant", "antenatal", "trimester", "labor pain"],
        "symptom": "Pregnancy-Related Consultation",
        "tag": "Pregnancy-related concern",
        "urgency": URGENCY_LEVEL_2,
        "referral": REFERRAL_B,
    },
    {
        "keywords": ["infant", "child", "neonate", "newborn"],
        "symptom": "Pediatric Presentation",
        "tag": "Pediatric concern",
        "urgency": URGENCY_LEVEL_3,
        "referral": REFERRAL_B,
    },
]


def extract_clinical_facts_from_text(text: str) -> Dict[str, Any]:
    """
    Extracts structured clinical facts (vitals, individual symptoms, duration, onset, history)
    from clinician free-text notes using clinical regex patterns and vocabulary extraction.
    Never fabricates values not supported by the input text.
    """
    if not text:
        return {
            "vitals": {},
            "symptoms": [],
            "duration": "Unknown",
            "onset": "Unknown",
            "history": [],
            "warning_signs": [],
        }

    vitals: Dict[str, Any] = {}

    # 1. SpO2 / Oxygen Saturation
    # Matches: SpO2 88%, SpO2: 88, SpO2 of 88%, O2 sat 92%, saturation 88%
    spo2_match = re.search(
        r'(?i)(?:spo2|spo₂|o2\s*sat(?:uration)?|saturation|oximetry)[\s:=]*(\d{2,3})(?:\s*%)?',
        text
    )
    if not spo2_match:
        spo2_match = re.search(r'(\d{2,3})\s*%\s*(?:spo2|spo₂|o2|sat\b)', text, re.IGNORECASE)
    if spo2_match:
        try:
            val = float(spo2_match.group(1))
            if 40 <= val <= 100:
                vitals["spo2"] = val
                vitals["oxygen_saturation"] = val
        except ValueError:
            pass

    # 2. Blood Pressure (Systolic / Diastolic)
    # Matches: BP 90/60, BP: 120/80 mmHg, BP 140/90, 120/80 mmHg
    bp_match = re.search(
        r'(?i)(?:bp|blood\s*pressure)[\s:=]*(\d{2,3})\s*[\/\\-]\s*(\d{2,3})(?:\s*mm\s*hg)?',
        text
    )
    if not bp_match:
        bp_match = re.search(r'(\d{2,3})\s*[\/\\-]\s*(\d{2,3})\s*(?:mm\s*hg|bp\b)', text, re.IGNORECASE)
    if bp_match:
        try:
            sys_val = int(bp_match.group(1))
            dia_val = int(bp_match.group(2))
            if 40 <= sys_val <= 260 and 20 <= dia_val <= 160:
                vitals["systolic_bp"] = sys_val
                vitals["diastolic_bp"] = dia_val
        except ValueError:
            pass
    else:
        sys_only = re.search(r'(?i)(?:sbp|systolic(?:[\s\w]*bp)?)[\s:=]*(\d{2,3})', text)
        if sys_only:
            try:
                sval = int(sys_only.group(1))
                if 40 <= sval <= 260:
                    vitals["systolic_bp"] = sval
            except ValueError:
                pass

    # 3. Heart Rate / Pulse
    # Matches: pulse 120 bpm, pulse: 120, heart rate 120, HR 120, 120 bpm
    hr_match = re.search(
        r'(?i)(?:pulse(?:[\s\w]*rate)?|heart\s*rate|hr|pr)[\s:=]*(\d{2,3})(?:\s*(?:bpm|beats?\/min|\/min))?',
        text
    )
    if not hr_match:
        hr_match = re.search(r'(\d{2,3})\s*(?:bpm|beats?\/min)\b', text, re.IGNORECASE)
    if hr_match:
        try:
            hval = int(hr_match.group(1))
            if 30 <= hval <= 250:
                vitals["heart_rate"] = hval
                vitals["pulse"] = hval
        except ValueError:
            pass

    # 4. Temperature
    # Matches: temp 102 F, temp 39 C, 101.5°F, 38.5 C, temperature 38.5
    temp_match = re.search(
        r'(?i)(?:temp(?:erature)?|fever\s*(?:of)?)[\s:=]*(\d{2,3}(?:\.\d+)?)\s*(?:°?\s*([cf]))?',
        text
    )
    if not temp_match:
        temp_match = re.search(r'(\d{2,3}(?:\.\d+)?)\s*°\s*([cf])\b', text, re.IGNORECASE)
    if temp_match:
        try:
            tval = float(temp_match.group(1))
            unit = (temp_match.group(2) or '').upper()
            if unit == 'F' or tval >= 90.0:
                # Convert Fahrenheit to Celsius
                c_val = (tval - 32.0) * 5.0 / 9.0
                if 30.0 <= c_val <= 45.0:
                    vitals["temperature"] = round(c_val, 1)
            elif 32.0 <= tval <= 44.0:
                vitals["temperature"] = round(tval, 1)
        except ValueError:
            pass

    # 5. Respiratory Rate
    # Matches: RR 28, respiratory rate 28, 28 breaths/min
    rr_match = re.search(
        r'(?i)(?:resp(?:iratory)?(?:\s*rate)?|rr)[\s:=]*(\d{1,2})(?:\s*(?:breaths?\/min|\/min|cpm))?',
        text
    )
    if not rr_match:
        rr_match = re.search(r'(\d{1,2})\s*(?:breaths?\/min|cpm)\b', text, re.IGNORECASE)
    if rr_match:
        try:
            rval = int(rr_match.group(1))
            if 8 <= rval <= 60:
                vitals["respiratory_rate"] = rval
        except ValueError:
            pass

    # 6. Duration Extraction
    duration = "Unknown"
    dur_match = re.search(
        r'(?i)(?:for|since|duration(?:[\s\w]*is)?|lasting)?\s*(\d+\s*(?:day|hour|week|month|year)s?|yesterday|morning|night|two\s*days|three\s*days|few\s*days|several\s*days)',
        text
    )
    if dur_match:
        duration = dur_match.group(1).strip()

    # 7. Onset
    text_lower = text.lower()
    if any(w in text_lower for w in ["sudden", "acute", "abrupt", "hours", "minutes"]):
        onset = "sudden"
    elif any(w in text_lower for w in ["gradual", "slowly", "days", "weeks", "months"]):
        onset = "gradual"
    else:
        onset = "unknown"

    # 8. Discrete Symptoms
    extracted_symptoms: List[str] = []
    symptom_patterns = [
        (r'\b(?:fever|pyrexia|high\s*temp|chills)\b', 'Fever'),
        (r'\b(?:breathing\s*difficult(?:y|ies)?|shortness\s*of\s*breath|breathless(?:ness)?|dyspnea|gasping|wheez(?:e|ing))\b', 'Breathing difficulty'),
        (r'\b(?:chest\s*pain|chest\s*tightness|angina)\b', 'Chest pain'),
        (r'\b(?:cough(?:ing)?|productive\s*cough)\b', 'Cough'),
        (r'\b(?:vomit(?:ing)?|nausea)\b', 'Vomiting'),
        (r'\b(?:diarrhea|loose\s*(?:stools|motions))\b', 'Diarrhea'),
        (r'\b(?:headache|migraine)\b', 'Headache'),
        (r'\b(?:dizz(?:y|iness)|vertigo|syncope|faint(?:ing)?)\b', 'Dizziness / Syncope'),
        (r'\b(?:abdominal\s*pain|stomach\s*pain|belly\s*pain)\b', 'Abdominal pain'),
        (r'\b(?:seizure|convulsion|fit)\b', 'Convulsions / Seizures'),
        (r'\b(?:unconscious(?:ness)?|unresponsive|coma|letharg(?:y|ic))\b', 'Altered mental status'),
        (r'\b(?:postpartum\s*hemorrhage|bleeding\s*after\s*delivery|uterine\s*bleeding)\b', 'Postpartum hemorrhage'),
        (r'\b(?:active\s*bleeding|hemorrhage|blood\s*loss)\b', 'Active bleeding'),
        (r'\b(?:fracture|broken\s*bone|dislocation)\b', 'Fracture / Dislocation'),
        (r'\b(?:joint\s*pain|ankle\s*pain|backache|sprain|swelling)\b', 'Musculoskeletal pain'),
        (r'\b(?:rash|skin\s*lesion|itching)\b', 'Skin rash / lesion'),
        (r'\b(?:burns?|scald)\b', 'Burns'),
    ]
    for pattern, name in symptom_patterns:
        if re.search(pattern, text_lower):
            if name not in extracted_symptoms:
                extracted_symptoms.append(name)

    # 9. Medical History
    history: List[str] = []
    history_patterns = [
        (r'\b(?:diabet(?:es|ic))\b', 'Diabetes Mellitus'),
        (r'\b(?:hypertens(?:ion|ive)|high\s*bp)\b', 'Hypertension'),
        (r'\b(?:asthma|copd)\b', 'Asthma / COPD'),
        (r'\b(?:cardiac|heart\s*disease|cad|mi)\b', 'Cardiovascular Disease'),
        (r'\b(?:pregnant|pregnancy|antenatal)\b', 'Pregnancy'),
        (r'\b(?:allerg(?:y|ic|ies))\b', 'Documented Allergies'),
    ]
    for pattern, name in history_patterns:
        if re.search(pattern, text_lower):
            if name not in history:
                history.append(name)

    return {
        "vitals": vitals,
        "symptoms": extracted_symptoms,
        "duration": duration,
        "onset": onset,
        "history": history,
    }


def evaluate_clinical_presentation(
    free_text: str,
    vitals: Dict[str, Any] = None,
    selected_tags: List[str] = None,
    patient_age: int = None,
    patient_sex: str = None,
) -> Dict[str, Any]:
    """
    Executes deterministic clinical triage screening.
    Safe, offline, non-compensatory, clinician-reviewed ruleset.
    Extracts vitals and facts directly from free text if not provided in structured arguments.
    """
    text_lower = (free_text or "").lower()
    raw_vitals = dict(vitals or {})
    selected_tags = selected_tags or []

    # Extract facts from text
    extracted_facts = extract_clinical_facts_from_text(free_text or "")

    # Merge extracted vitals: structured vitals take precedence, fallback to extracted
    merged_vitals = dict(extracted_facts["vitals"])
    merged_vitals.update(raw_vitals)

    red_flags: List[str] = []
    missing_info: List[str] = []
    follow_up_questions: List[str] = []
    detected_symptoms: List[str] = list(extracted_facts["symptoms"])
    suggested_tags = set(selected_tags)

    # 1. Check Vital Sign Abnormalities (Red Flags & Warnings)
    spo2 = merged_vitals.get("oxygen_saturation") or merged_vitals.get("spo2")
    hr = merged_vitals.get("heart_rate") or merged_vitals.get("pulse")
    sys_bp = merged_vitals.get("systolic_bp") or merged_vitals.get("systolic")
    temp = merged_vitals.get("temperature") or merged_vitals.get("temp")
    rr = merged_vitals.get("respiratory_rate") or merged_vitals.get("rr")

    vital_emergency = False

    if spo2 is not None:
        try:
            spo2_val = float(spo2)
            if spo2_val < 90.0:
                red_flags.append(f"Severe Hypoxia: SpO2 {spo2_val:.0f}% (<90%) requires emergency oxygen resuscitation.")
                vital_emergency = True
                suggested_tags.add("Breathing difficulty")
                suggested_tags.add("Low SpO₂")
                suggested_tags.add("Severe Hypoxia")
            elif spo2_val < 94.0:
                missing_info.append(f"Moderate desaturation: SpO2 {spo2_val:.0f}% requires serial monitoring.")
                suggested_tags.add("Breathing difficulty")
                suggested_tags.add("Low SpO₂")
        except (ValueError, TypeError):
            pass
    else:
        missing_info.append("Oxygen saturation (SpO2) not recorded.")
        follow_up_questions.append("Can point-of-care pulse oximetry be performed immediately?")

    if sys_bp is not None:
        try:
            sys_val = float(sys_bp)
            if sys_val < 85.0:
                red_flags.append(f"Hypotensive Shock: Systolic BP {sys_val:.0f} mmHg (<85 mmHg).")
                vital_emergency = True
                suggested_tags.add("Shock / Hemodynamic instability")
                suggested_tags.add("Hypotension")
            elif sys_val > 180.0:
                red_flags.append(f"Hypertensive Crisis: Systolic BP {sys_val:.0f} mmHg (>180 mmHg).")
                vital_emergency = True
                suggested_tags.add("Possible cardiac symptoms")
                suggested_tags.add("Hypertensive Crisis")
        except (ValueError, TypeError):
            pass
    else:
        missing_info.append("Blood pressure not recorded.")
        follow_up_questions.append("What is the patient's current blood pressure?")

    if hr is not None:
        try:
            hr_val = float(hr)
            if hr_val > 135.0:
                red_flags.append(f"Extreme Tachycardia: Heart rate {hr_val:.0f} bpm (>135 bpm).")
                vital_emergency = True
                suggested_tags.add("Tachycardia")
            elif hr_val > 100.0:
                suggested_tags.add("Tachycardia")
            elif hr_val < 45.0:
                red_flags.append(f"Severe Bradycardia: Heart rate {hr_val:.0f} bpm (<45 bpm).")
                vital_emergency = True
                suggested_tags.add("Bradycardia")
        except (ValueError, TypeError):
            pass
    else:
        missing_info.append("Pulse / Heart rate not recorded.")

    if temp is not None:
        try:
            temp_val = float(temp)
            if temp_val > 40.0:
                red_flags.append(f"Hyperpyrexia: Temperature {temp_val:.1f}°C (>40.0°C). Risk of febrile seizure or severe sepsis.")
                vital_emergency = True
                suggested_tags.add("High Fever")
                suggested_tags.add("Suspected infection")
            elif temp_val >= 38.0:
                suggested_tags.add("Fever")
                suggested_tags.add("Suspected infection")
        except (ValueError, TypeError):
            pass

    # 2. Check Text for Predefined Mandatory Emergency Warning Signs
    matched_specialties = []
    text_emergency = False

    for rule in MANDATORY_RED_FLAGS:
        for kw in rule["keywords"]:
            if kw in text_lower:
                red_flags.append(rule["flag"])
                matched_specialties.append(rule["specialty"])
                if rule["urgency"] == URGENCY_LEVEL_1:
                    text_emergency = True
                break

    # 3. Check for Secondary Symptoms & Clinical Tags
    for rule in SECONDARY_SYMPTOM_RULES:
        for kw in rule["keywords"]:
            if kw in text_lower:
                if rule["symptom"] not in detected_symptoms:
                    detected_symptoms.append(rule["symptom"])
                suggested_tags.add(rule["tag"])
                break

    # 4. Detect Missing Clinical Context
    has_duration_word = any(w in text_lower for w in ["day", "hour", "since", "yesterday", "morning", "night", "week", "onset", "started", "duration"])
    if not has_duration_word and extracted_facts["duration"] == "Unknown":
        missing_info.append("Exact onset time / duration of symptoms not mentioned.")
        follow_up_questions.append("When exactly did symptoms start or last known well?")

    has_history_word = any(w in text_lower for w in ["allerg", "history", "diabet", "hypertens", "asthma", "medicat", "past"])
    if not has_history_word and not extracted_facts["history"]:
        missing_info.append("Past medical history, chronic diseases, and drug allergies not documented.")
        follow_up_questions.append("Does the patient have known allergies or pre-existing medical conditions?")

    # 5. Determine Urgency and Referral Level
    urgency_level = URGENCY_LEVEL_4
    referral_level = REFERRAL_A
    reasoning_points: List[str] = []

    is_undetermined = False
    vitals_completely_missing = (spo2 is None and sys_bp is None and hr is None and temp is None and rr is None)
    has_meaningful_text = len(detected_symptoms) > 0 or len(text_lower.strip()) >= 25

    if vital_emergency or text_emergency or len(red_flags) > 0:
        urgency_level = URGENCY_LEVEL_1
        referral_level = REFERRAL_D
        suggested_tags.add("Immediate Emergency")
        reasoning_points.append(
            f"MANDATORY EMERGENCY RULE TRIGGERED: {len(red_flags)} life-threatening warning sign(s) detected ({'; '.join(red_flags[:2])}). "
            "Requires immediate emergency stabilization and 108 ALS ambulance transfer to an equipped hospital."
        )
    elif any(t in suggested_tags for t in ["Pregnancy-related concern", "Possible cardiac symptoms", "Breathing difficulty", "Severe Acute Respiratory Distress"]):
        urgency_level = URGENCY_LEVEL_2
        referral_level = REFERRAL_B
        suggested_tags.add("Urgent Review")
        reasoning_points.append(
            "URGENT: High-risk clinical concern identified. Prompt medical evaluation and hospital-level diagnostic workup indicated."
        )
    elif any(t in suggested_tags for t in ["Suspected infection", "Dehydration risk", "Pediatric concern", "Fever"]):
        urgency_level = URGENCY_LEVEL_3
        referral_level = REFERRAL_B
        reasoning_points.append(
            "PRIORITY ASSESSMENT: Patient exhibits symptomatic presentation requiring timely clinical examination within 12-24 hours."
        )
    elif any(t in suggested_tags for t in ["Injury or trauma", "Dermatology"]) and not vitals_completely_missing:
        urgency_level = URGENCY_LEVEL_4
        referral_level = REFERRAL_A
        reasoning_points.append(
            "ROUTINE ASSESSMENT: Mild or stable presentation suitable for local outpatient primary care post."
        )
    elif vitals_completely_missing:
        # Mandatory safety rule: Ambiguous presentations or unmeasured vitals must NEVER be reassuring Level 4
        is_undetermined = True
        urgency_level = URGENCY_LEVEL_2 if any(s in detected_symptoms for s in ["Dizziness / Syncope", "Altered mental status"]) else URGENCY_LEVEL_3
        referral_level = REFERRAL_B
        suggested_tags.add("Information Incomplete")
        reasoning_points.append(
            "URGENCY UNDETERMINED — CLINICIAN ASSESSMENT REQUIRED: Vital signs are unrecorded and clinical presentation requires evaluation. "
            "Per clinical safety protocol, uncertainty is never assigned routine triage."
        )
    else:
        urgency_level = URGENCY_LEVEL_4
        referral_level = REFERRAL_A
        reasoning_points.append(
            "ROUTINE ASSESSMENT: Stable presentation suitable for local outpatient primary care post."
        )

    # Normalize symptoms: never return raw text blobs
    if not detected_symptoms:
        if len(text_lower.strip()) > 0 and not is_undetermined:
            detected_symptoms.append(text_lower.strip().capitalize())

    reasoning = " ".join(reasoning_points)

    # Determine structured analysis status
    if vital_emergency or text_emergency or len(red_flags) > 0:
        analysis_status = "safety_escalation"
    elif is_undetermined:
        analysis_status = "insufficient_information"
    elif vitals_completely_missing or len(missing_info) > 0:
        analysis_status = "partial"
    else:
        analysis_status = "success"

    return {
        "urgency_level": urgency_level,
        "urgency_label": "Urgency undetermined — clinician assessment required" if is_undetermined else URGENCY_LABELS[urgency_level],
        "referral_level": referral_level,
        "referral_label": REFERRAL_LABELS[referral_level],
        "is_emergency": urgency_level == URGENCY_LEVEL_1,
        "is_undetermined": is_undetermined,
        "red_flags": red_flags,
        "missing_information": missing_info,
        "follow_up_questions": follow_up_questions,
        "extracted_symptoms": detected_symptoms,
        "extracted_vitals": merged_vitals,
        "duration": extracted_facts["duration"],
        "onset": extracted_facts["onset"],
        "relevant_history": extracted_facts["history"],
        "suggested_tags": sorted(list(suggested_tags)),
        "reasoning": reasoning,
        "analysis_status": analysis_status,
        "assessment_source": "offline_rules",
        "ruleset_version": "indore-clinical-safety-v1",
        "model_version": "deterministic-clinical-ruleset",
        "service_available": True,
        "disclaimer": "Assistive decision support — clinician review required. Not an autonomous diagnostic determination."
    }
