"""
Condition-to-Capability Clinical Mapping Engine.
Defines the medically reviewable mapping between patient clinical conditions,
urgency levels, essential medical specialties, doctor clinical capabilities,
diagnostic & surgical infrastructure, and clinical rationales.
"""

from typing import Dict, List, Any

# 8 Medically reviewable referral scenarios as specified in clinical protocols:
CLINICAL_CONDITIONS: Dict[str, Dict[str, Any]] = {
    "suspected_heart_attack": {
        "condition_key": "suspected_heart_attack",
        "condition_name": "Suspected Acute Coronary Syndrome / Myocardial Infarction",
        "urgency_level": "immediate",
        "required_specialties": ["Cardiology", "Emergency Medicine"],
        "essential_doctor_capabilities": [
            "Emergency cardiac resuscitation",
            "12-lead ECG rhythm interpretation",
            "Acute thrombolysis and hemodynamic stabilization",
        ],
        "essential_equipment": [
            "12-Lead ECG",
            "Defibrillator",
            "Cath Lab / Cardiac",
            "24/7 Emergency Care",
        ],
        "emergency_stabilization_required": True,
        "critical_care_required": True,
        "supporting_capabilities": [
            "Cardiac Biomarkers (Troponin I/T)",
            "Echocardiography (2D Echo)",
            "Coronary Care Unit (CCU)",
            "Temporary Pacemaker Insertion",
        ],
        "acceptable_referral_fallback": "Immediate transfer to nearest tertiary center with functional Cardiac Catheterization Lab and emergency percutaneous coronary intervention (PCI).",
        "required_data_freshness_hours": 2,
        "capability_rationales": {
            "Cath Lab / Cardiac": "Primary PCI is the gold standard reperfusion therapy for acute STEMI and must be initiated within the 90-minute door-to-balloon window.",
            "12-Lead ECG": "Essential for immediate diagnosis and differentiation between STEMI and NSTEMI within 10 minutes of arrival.",
            "24/7 Emergency Care": "Continuous emergency presence is mandatory for immediate electrical cardioversion or defibrillation during ventricular arrhythmias.",
            "ICU / CCU": "Post-resuscitation monitoring of hemodynamic instability and cardiogenic shock requires advanced invasive arterial pressure monitoring.",
        },
    },
    "suspected_stroke": {
        "condition_key": "suspected_stroke",
        "condition_name": "Suspected Acute Ischemic Stroke / Intracranial Hemorrhage",
        "urgency_level": "immediate",
        "required_specialties": ["Neurology", "Emergency Medicine"],
        "essential_doctor_capabilities": [
            "Rapid neurological assessment (NIHSS)",
            "Intravenous thrombolysis eligibility screening",
            "Airway and blood pressure management in acute stroke",
        ],
        "essential_equipment": [
            "16-Slice CT Scanner",
            "24/7 Emergency Care",
        ],
        "emergency_stabilization_required": True,
        "critical_care_required": True,
        "supporting_capabilities": [
            "MRI Scanner",
            "Neurosurgery / Craniotomy",
            "Intensive Care Unit (ICU)",
            "Neuro-radiology Interventional Suite",
        ],
        "acceptable_referral_fallback": "Transfer to dedicated comprehensive stroke unit with immediate unenhanced CT neuroimaging and IV thrombolysis protocol.",
        "required_data_freshness_hours": 2,
        "capability_rationales": {
            "16-Slice CT Scanner": "Immediate brain imaging is clinically mandatory to differentiate ischemic infarction from hemorrhagic stroke before any thrombolytic agent is given.",
            "24/7 Emergency Care": "Enables rapid triage and treatment initiation inside the 4.5-hour intravenous alteplase/tenecteplase therapeutic window.",
            "Neurology": "Required for specialized clinical decisions regarding mechanical thrombectomy and secondary stroke prevention.",
            "ICU": "Close neurological and hemodynamic surveillance to detect hemorrhagic transformation and cerebral edema.",
        },
    },
    "major_trauma": {
        "condition_key": "major_trauma",
        "condition_name": "Severe Polytrauma & Hemorrhagic Shock",
        "urgency_level": "immediate",
        "required_specialties": ["Orthopaedics", "General Surgery", "Emergency Medicine"],
        "essential_doctor_capabilities": [
            "Advanced Trauma Life Support (ATLS) protocols",
            "Damage-control surgical resuscitation",
            "Rapid tube thoracostomy and central vascular access",
        ],
        "essential_equipment": [
            "Trauma Care",
            "24/7 Blood Bank",
            "Operating Theater",
            "24/7 Emergency Care",
            "ICU Mechanical Ventilation",
        ],
        "emergency_stabilization_required": True,
        "critical_care_required": True,
        "supporting_capabilities": [
            "16-Slice CT Scanner",
            "Digital X-Ray",
            "Orthopedic Fracture Fixation",
            "Massive Transfusion Protocol",
        ],
        "acceptable_referral_fallback": "Direct routing to Level 1 / Level 2 Trauma Care Center with multi-disciplinary surgical theater and packed red blood cell availability.",
        "required_data_freshness_hours": 2,
        "capability_rationales": {
            "24/7 Blood Bank": "Exsanguinating hemorrhagic trauma requires immediate uncrossed O-negative or type-specific blood resuscitation to prevent lethal coagulopathy.",
            "Operating Theater": "Emergency exploratory laparotomy and surgical hemorrhage arrest are necessary for uncontrollable internal torso bleeding.",
            "Trauma Care": "Specialized trauma bay with surgical lighting, chest drainage sets, and rapid blood infusers.",
            "ICU Mechanical Ventilation": "Mandatory for ventilatory failure from severe pulmonary contusions and traumatic brain injury.",
        },
    },
    "pediatric_respiratory_distress": {
        "condition_key": "pediatric_respiratory_distress",
        "condition_name": "Child with Severe Respiratory Distress / Croup / Pneumonia",
        "urgency_level": "urgent",
        "required_specialties": ["Paediatrics"],
        "essential_doctor_capabilities": [
            "Pediatric Advanced Life Support (PALS)",
            "Pediatric airway management and nebulization",
            "Neonatal/pediatric vascular access and fluid resuscitation",
        ],
        "essential_equipment": [
            "Pediatric Respiratory Support",
            "24/7 Emergency Care",
        ],
        "emergency_stabilization_required": True,
        "critical_care_required": True,
        "supporting_capabilities": [
            "Pediatric ICU (PICU)",
            "High-flow Nasal Cannula (HFNC)",
            "Pulse Oximetry",
            "Pediatric Blood Gas Analysis",
        ],
        "acceptable_referral_fallback": "Transfer to secondary or tertiary facility with pediatric ward, oxygen therapy, and on-call pediatrician.",
        "required_data_freshness_hours": 4,
        "capability_rationales": {
            "Paediatrics": "Children have distinct anatomy, physiology, and pharmacological dosing requiring certified pediatric specialist management.",
            "Pediatric Respiratory Support": "Adult respiratory circuits generate barotrauma in infants; age-appropriate uncuffed/cuffed tubes, micro-nebulizers, and ventilators are required.",
            "24/7 Emergency Care": "Sudden respiratory fatigue and respiratory arrest occur rapidly in young children with subglottic narrowing.",
        },
    },
    "pregnancy_danger_signs": {
        "condition_key": "pregnancy_danger_signs",
        "condition_name": "Obstetric Emergency / Antepartum Hemorrhage / Eclampsia",
        "urgency_level": "immediate",
        "required_specialties": ["Obstetrics & Gynecology", "Obstetrics/gynaecology"],
        "essential_doctor_capabilities": [
            "Emergency obstetric surgery (Cesarean Section)",
            "Management of severe pre-eclampsia and magnesium sulfate protocols",
            "Active management of postpartum/antepartum hemorrhage",
        ],
        "essential_equipment": [
            "Emergency Cesarean Section (C-Section)",
            "Operating Theater",
            "24/7 Blood Bank",
            "24/7 Emergency Care",
        ],
        "emergency_stabilization_required": True,
        "critical_care_required": False,
        "supporting_capabilities": [
            "Ultrasound / Sonography",
            "Neonatal ICU (NICU)",
            "Maternal High Dependency Unit",
            "Fetal Heart Rate Doppler",
        ],
        "acceptable_referral_fallback": "Transfer to First Referral Unit (FRU) or sub-district hospital with active obstetric surgical theater.",
        "required_data_freshness_hours": 4,
        "capability_rationales": {
            "Emergency Cesarean Section (C-Section)": "Fetal distress, cord prolapse, and uterine rupture require delivery within 30 minutes to prevent perinatal death.",
            "24/7 Blood Bank": "Obstetric hemorrhage remains the leading cause of maternal mortality; immediate crossmatched blood availability is lifesaving.",
            "Obstetrics & Gynecology": "Specialized obstetric knowledge is required for operative vaginal delivery, vacuum extraction, or peripartum hysterectomy.",
        },
    },
    "routine_fever": {
        "condition_key": "routine_fever",
        "condition_name": "Routine Acute Febrile Illness Without Danger Signs",
        "urgency_level": "routine",
        "required_specialties": ["General medicine", "General Practice", "Family Medicine"],
        "essential_doctor_capabilities": [
            "Primary clinical examination and differential diagnosis",
            "Management of endemic febrile illnesses (Malaria, Dengue, Typhoid)",
            "Outpatient prescription and warning sign counseling",
        ],
        "essential_equipment": [
            "Pathology & Biochemistry Lab",
        ],
        "emergency_stabilization_required": False,
        "critical_care_required": False,
        "supporting_capabilities": [
            "Rapid Diagnostic Tests (RDTs)",
            "Complete Blood Count (CBC)",
            "Pharmacy / Oral Medication Dispensing",
        ],
        "acceptable_referral_fallback": "Local Community Health Centre (CHC) or Primary Health Centre (PHC) clinic.",
        "required_data_freshness_hours": 24,
        "capability_rationales": {
            "General medicine": "Broad-spectrum primary evaluation prevents inappropriate antibiotic usage while identifying early sepsis.",
            "Pathology & Biochemistry Lab": "Confirmatory peripheral blood smear, platelet counts, and serology guide safe outpatient therapy.",
        },
    },
    "diabetes_followup": {
        "condition_key": "diabetes_followup",
        "condition_name": "Chronic Diabetes Mellitus Follow-up & Glycemic Review",
        "urgency_level": "routine",
        "required_specialties": ["General medicine", "Internal Medicine", "General Practice"],
        "essential_doctor_capabilities": [
            "Long-term glycemic control evaluation",
            "Diabetic microvascular complication screening",
            "Insulin regimen adjustment and lifestyle guidance",
        ],
        "essential_equipment": [
            "Pathology & Biochemistry Lab",
        ],
        "emergency_stabilization_required": False,
        "critical_care_required": False,
        "supporting_capabilities": [
            "Glycated Hemoglobin (HbA1c)",
            "Serum Creatinine / eGFR",
            "Urine Albumin-to-Creatinine Ratio (UACR)",
            "Diabetic Foot Neuropathy Screening",
        ],
        "acceptable_referral_fallback": "Designated Non-Communicable Disease (NCD) clinic or primary care physician.",
        "required_data_freshness_hours": 48,
        "capability_rationales": {
            "Pathology & Biochemistry Lab": "Objective laboratory measurement of HbA1c, renal function, and lipid profile is fundamental to clinical management.",
            "General medicine": "Holistic management of cardiovascular risk factors and chronic medication adherence.",
        },
    },
    "new_neurological_symptoms": {
        "condition_key": "new_neurological_symptoms",
        "condition_name": "New Non-Acute Neurological Symptoms / Focal Deficit Evaluation",
        "urgency_level": "urgent",
        "required_specialties": ["Neurology", "General medicine"],
        "essential_doctor_capabilities": [
            "Detailed cranial nerve and motor-sensory localization",
            "Neuro-ophthalmological exam and visual field testing",
            "Differential diagnosis of demyelinating vs compressive lesions",
        ],
        "essential_equipment": [
            "16-Slice CT Scanner",
        ],
        "emergency_stabilization_required": False,
        "critical_care_required": False,
        "supporting_capabilities": [
            "MRI Scanner",
            "Electroencephalogram (EEG)",
            "Nerve Conduction Velocity (NCV) / Electromyography",
            "Cerebrospinal Fluid (CSF) Analysis",
        ],
        "acceptable_referral_fallback": "Secondary hospital with neurologist consultation or tertiary hospital neurology OPD.",
        "required_data_freshness_hours": 12,
        "capability_rationales": {
            "16-Slice CT Scanner": "Non-contrast neuroimaging excludes mass lesions, chronic subdural hematomas, and structural abnormalities.",
            "Neurology": "Specialist localization of complex nervous system signs to avoid missed treatable neuropathologies.",
        },
    },
}


def get_condition_definition(condition_key: str) -> Dict[str, Any]:
    """Retrieves condition definition or defaults to routine fever."""
    return CLINICAL_CONDITIONS.get(condition_key, CLINICAL_CONDITIONS["routine_fever"])


def map_condition_string_to_key(text: str) -> str:
    """Intelligently matches a patient complaint or condition string to an authoritative condition key."""
    t = text.lower()
    if any(k in t for k in ["cardiac", "chest pain", "heart", "stemi", "angina", "infarction"]):
        return "suspected_heart_attack"
    if any(k in t for k in ["stroke", "hemiplegia", "slurred speech", "facial droop", "transient ischemic"]):
        return "suspected_stroke"
    if any(k in t for k in ["trauma", "fracture", "accident", "polytrauma", "hemorrhage", "crush"]):
        return "major_trauma"
    if any(k in t for k in ["pediatric", "child", "infant", "breathing", "croup", "stridor", "pneumonia"]):
        return "pediatric_respiratory_distress"
    if any(k in t for k in ["pregnan", "obstetric", "labor", "labour", "pph", "eclampsia", "bleeding per vaginam"]):
        return "pregnancy_danger_signs"
    if any(k in t for k in ["diabet", "sugar", "glucose", "hba1c", "glycemic"]):
        return "diabetes_followup"
    if any(k in t for k in ["neuro", "numbness", "seizure", "tingling", "weakness", "vision loss", "headache"]):
        return "new_neurological_symptoms"
    return "routine_fever"
