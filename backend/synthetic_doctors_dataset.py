"""
Synthetic Doctor Dataset Generator for 45 Healthcare Facilities.
Generates an internal, development-only dataset of fictional Indian doctors linked
to the 45 preloaded healthcare facilities in the Indore healthcare network.

NOTICE: ALL PROFILES IN THIS FILE ARE STRICTLY SYNTHETIC AND SIMULATED.
DO NOT USE AS REAL CLINICIAN CREDENTIALS OR FOR ACTUAL CLINICAL REFERRALS.
"""

import json
from datetime import datetime, timezone
from typing import List, Dict, Any

SYNTHETIC_DOCTORS: List[Dict[str, Any]] = [
    # --- TERTIARY HOSPITALS (indore_hospital_001 to 009) ---
    {
        "doctor_id": "doc_synth_001",
        "display_name": "Dr. Ananya Sharma",
        "full_name": "Dr. Ananya Sharma",
        "email": "synth.ananya.sharma@demo.medico.in",
        "phone_number": "9100000001",
        "is_synthetic": 1,
        "record_source": "synthetic_demo",
        "verification_status": "unverified_demo",
        "primary_specialty": "Cardiology",
        "secondary_specialties": ["Interventional Cardiology", "Critical Care"],
        "qualifications": [
            {"cadre": "primary_mbbs", "title": "MBBS", "institution": "MGM Medical College Indore", "year": 2012},
            {"cadre": "postgraduate_md_ms_dnb", "title": "MD General Medicine", "institution": "AIIMS New Delhi", "year": 2016},
            {"cadre": "super_specialty_dm_mch", "title": "DM Cardiology", "institution": "SGPGI Lucknow", "year": 2019},
        ],
        "years_of_experience": 12,
        "practice_environment": "tertiary_hospital",
        "facility_affiliation_ids": ["indore_hospital_001"],
        "clinical_capabilities": [
            "Emergency cardiac resuscitation",
            "12-lead ECG rhythm interpretation",
            "Acute thrombolysis and hemodynamic stabilization",
            "Temporary Pacemaker Insertion",
        ],
        "procedure_capabilities": [
            "Coronary Angiography",
            "Primary Percutaneous Coronary Intervention (PCI)",
            "Balloon Angioplasty",
            "Pericardiocentesis",
        ],
        "emergency_capabilities": [
            "Advanced Cardiac Life Support (ACLS)",
            "Synchronized Cardioversion",
            "Defibrillation",
            "Endotracheal Intubation",
        ],
        "critical_care_capabilities": [
            "Cardiac ICU (CCU) management",
            "Intra-aortic balloon pump (IABP) monitoring",
            "Invasive arterial line placement",
        ],
        "diagnostic_capabilities": [
            "2D Echocardiography",
            "Transesophageal Echo (TEE)",
            "Treadmill Stress Test (TMT)",
            "Holter Monitoring",
        ],
        "availability_status": "available",
        "duty_shift": "day",
    },
    {
        "doctor_id": "doc_synth_002",
        "display_name": "Dr. Rahul Verma",
        "full_name": "Dr. Rahul Verma",
        "email": "synth.rahul.verma@demo.medico.in",
        "phone_number": "9100000002",
        "is_synthetic": 1,
        "record_source": "synthetic_demo",
        "verification_status": "unverified_demo",
        "primary_specialty": "Orthopaedics",
        "secondary_specialties": ["Trauma Surgery", "Joint Replacement"],
        "qualifications": [
            {"cadre": "primary_mbbs", "title": "MBBS", "institution": "GMC Bhopal", "year": 2011},
            {"cadre": "postgraduate_md_ms_dnb", "title": "MS Orthopaedics", "institution": "KEM Hospital Mumbai", "year": 2015},
            {"cadre": "diploma_fellowship", "title": "Fellowship in Complex Trauma", "institution": "CMC Vellore", "year": 2017},
        ],
        "years_of_experience": 13,
        "practice_environment": "tertiary_hospital",
        "facility_affiliation_ids": ["indore_hospital_002", "indore_hospital_001"],
        "clinical_capabilities": [
            "Advanced Trauma Life Support (ATLS) protocols",
            "Damage-control surgical resuscitation",
            "Polytrauma musculoskeletal assessment",
        ],
        "procedure_capabilities": [
            "Complex Fracture Open Reduction & Internal Fixation (ORIF)",
            "External Fixator Application",
            "Emergency Compartment Syndrome Fasciotomy",
            "Pelvic Fracture Stabilization",
        ],
        "emergency_capabilities": [
            "Splinting and closed fracture reduction",
            "Spinal immobilization",
            "Hemorrhagic pelvic clamp placement",
        ],
        "critical_care_capabilities": [
            "Fat embolism syndrome monitoring",
            "Post-operative ICU surgical care",
        ],
        "diagnostic_capabilities": [
            "Digital X-Ray interpretation",
            "Musculoskeletal CT reconstruction analysis",
        ],
        "availability_status": "available",
        "duty_shift": "day",
    },
    {
        "doctor_id": "doc_synth_003",
        "display_name": "Dr. Priya Patel",
        "full_name": "Dr. Priya Patel",
        "email": "synth.priya.patel@demo.medico.in",
        "phone_number": "9100000003",
        "is_synthetic": 1,
        "record_source": "synthetic_demo",
        "verification_status": "unverified_demo",
        "primary_specialty": "Obstetrics & Gynecology",
        "secondary_specialties": ["High-Risk Pregnancy", "Fetal Medicine"],
        "qualifications": [
            {"cadre": "primary_mbbs", "title": "MBBS", "institution": "Baroda Medical College", "year": 2013},
            {"cadre": "postgraduate_md_ms_dnb", "title": "MS Obstetrics & Gynaecology", "institution": "Seth GS Medical College Mumbai", "year": 2017},
        ],
        "years_of_experience": 11,
        "practice_environment": "tertiary_hospital",
        "facility_affiliation_ids": ["indore_hospital_003", "indore_hospital_002"],
        "clinical_capabilities": [
            "Emergency obstetric surgery (Cesarean Section)",
            "Management of severe pre-eclampsia and magnesium sulfate protocols",
            "Active management of postpartum/antepartum hemorrhage",
        ],
        "procedure_capabilities": [
            "Emergency Lower Segment Cesarean Section (LSCS)",
            "Peripartum Hysterectomy for intractable PPH",
            "B-Lynch suture and uterine artery ligation",
            "Assisted Operative Vaginal Delivery (Vacuum/Forceps)",
        ],
        "emergency_capabilities": [
            "Bakri Balloon intrauterine tamponade",
            "Neonatal resuscitation initiation",
            "Massive transfusion protocol activation in obstetrics",
        ],
        "critical_care_capabilities": [
            "Obstetric HDU/ICU management",
            "Invasive monitoring in eclampsia",
        ],
        "diagnostic_capabilities": [
            "Obstetric Bedside Ultrasound",
            "Fetal Cardiotocography (CTG) interpretation",
            "Doppler fetal flow analysis",
        ],
        "availability_status": "available",
        "duty_shift": "night",
    },
    {
        "doctor_id": "doc_synth_004",
        "display_name": "Dr. Arjun Singh",
        "full_name": "Dr. Arjun Singh",
        "email": "synth.arjun.singh@demo.medico.in",
        "phone_number": "9100000004",
        "is_synthetic": 1,
        "record_source": "synthetic_demo",
        "verification_status": "unverified_demo",
        "primary_specialty": "Emergency Medicine",
        "secondary_specialties": ["Trauma Resuscitation", "Critical Care"],
        "qualifications": [
            {"cadre": "primary_mbbs", "title": "MBBS", "institution": "Armed Forces Medical College Pune", "year": 2010},
            {"cadre": "postgraduate_md_ms_dnb", "title": "MD Emergency Medicine", "institution": "AIIMS New Delhi", "year": 2014},
        ],
        "years_of_experience": 14,
        "practice_environment": "tertiary_hospital",
        "facility_affiliation_ids": ["indore_hospital_004", "indore_hospital_001"],
        "clinical_capabilities": [
            "Advanced cardiac resuscitation",
            "Rapid sequence intubation (RSI)",
            "Emergency ultrasound (FAST/eFAST)",
            "Mass casualty incident triage",
        ],
        "procedure_capabilities": [
            "Tube thoracostomy (chest tube insertion)",
            "Central venous catheterization (USG-guided)",
            "Cricothyroidotomy (emergency surgical airway)",
            "Arterial catheterization",
        ],
        "emergency_capabilities": [
            "Cardiopulmonary Resuscitation (ACLS/BLS Director)",
            "Electrical pacing and defibrillation",
            "Toxicology antidote administration",
            "Severe sepsis fluid resuscitation",
        ],
        "critical_care_capabilities": [
            "Mechanical ventilation lung-protective strategies",
            "Vasoactive infusion titration",
        ],
        "diagnostic_capabilities": [
            "Point-of-Care Ultrasound (POCUS)",
            "Emergency blood gas analysis",
            "Rapid bedside trauma radiography",
        ],
        "availability_status": "available",
        "duty_shift": "day",
    },
    {
        "doctor_id": "doc_synth_005",
        "display_name": "Dr. Neha Joshi",
        "full_name": "Dr. Neha Joshi",
        "email": "synth.neha.joshi@demo.medico.in",
        "phone_number": "9100000005",
        "is_synthetic": 1,
        "record_source": "synthetic_demo",
        "verification_status": "unverified_demo",
        "primary_specialty": "Paediatrics",
        "secondary_specialties": ["Neonatology", "Pediatric Intensive Care"],
        "qualifications": [
            {"cadre": "primary_mbbs", "title": "MBBS", "institution": "MGM Medical College Indore", "year": 2014},
            {"cadre": "postgraduate_md_ms_dnb", "title": "MD Paediatrics", "institution": "PGI Chandigarh", "year": 2018},
            {"cadre": "diploma_fellowship", "title": "Fellowship in Neonatology", "institution": "Fernandez Hospital Hyderabad", "year": 2020},
        ],
        "years_of_experience": 10,
        "practice_environment": "tertiary_hospital",
        "facility_affiliation_ids": ["indore_hospital_005", "indore_hospital_003"],
        "clinical_capabilities": [
            "Pediatric Advanced Life Support (PALS)",
            "Pediatric airway management and nebulization",
            "Neonatal/pediatric vascular access and fluid resuscitation",
        ],
        "procedure_capabilities": [
            "Neonatal Endotracheal Intubation",
            "Umbilical venous and arterial catheterization",
            "Surfactant administration via LISA/INSURE",
            "Pediatric Lumbar Puncture",
        ],
        "emergency_capabilities": [
            "Pediatric seizure termination protocols",
            "Emergency high-flow nasal cannula stabilization",
            "Anaphylaxis emergency pediatric management",
        ],
        "critical_care_capabilities": [
            "Neonatal ICU (NICU) Level III care",
            "High-frequency oscillatory ventilation (HFOV)",
            "Targeted neonatal echocardiography",
        ],
        "diagnostic_capabilities": [
            "Neurosonogram (cranial ultrasound in neonates)",
            "Pediatric blood gas and acid-base interpretation",
        ],
        "availability_status": "available",
        "duty_shift": "day",
    },
    {
        "doctor_id": "doc_synth_006",
        "display_name": "Dr. Imran Khan",
        "full_name": "Dr. Imran Khan",
        "email": "synth.imran.khan@demo.medico.in",
        "phone_number": "9100000006",
        "is_synthetic": 1,
        "record_source": "synthetic_demo",
        "verification_status": "unverified_demo",
        "primary_specialty": "Neurology",
        "secondary_specialties": ["Stroke Medicine", "Neurocritical Care"],
        "qualifications": [
            {"cadre": "primary_mbbs", "title": "MBBS", "institution": "GMC Bhopal", "year": 2011},
            {"cadre": "postgraduate_md_ms_dnb", "title": "MD General Medicine", "institution": "GRMC Gwalior", "year": 2015},
            {"cadre": "super_specialty_dm_mch", "title": "DM Neurology", "institution": "NIMHANS Bengaluru", "year": 2019},
        ],
        "years_of_experience": 13,
        "practice_environment": "tertiary_hospital",
        "facility_affiliation_ids": ["indore_hospital_006", "indore_hospital_001"],
        "clinical_capabilities": [
            "Rapid neurological assessment (NIHSS)",
            "Intravenous thrombolysis eligibility screening",
            "Airway and blood pressure management in acute stroke",
            "Status epilepticus emergency control",
        ],
        "procedure_capabilities": [
            "Lumbar Puncture with CSF manometry",
            "Therapeutic plasma exchange coordination in GBS/myasthenia",
        ],
        "emergency_capabilities": [
            "Hyperacute stroke code activation",
            "Emergency hyperosmolar therapy for brain edema",
        ],
        "critical_care_capabilities": [
            "Neuro-ICU intracranial pressure (ICP) surveillance",
            "Targeted temperature management post-cardiac arrest",
        ],
        "diagnostic_capabilities": [
            "Emergency non-contrast CT and CT-Angiography reading",
            "Diffusion MRI interpretation",
            "Bedside EEG interpretation",
            "Transcranial Doppler (TCD)",
        ],
        "availability_status": "available",
        "duty_shift": "day",
    },
    {
        "doctor_id": "doc_synth_007",
        "display_name": "Dr. Kavita Deshmukh",
        "full_name": "Dr. Kavita Deshmukh",
        "email": "synth.kavita.deshmukh@demo.medico.in",
        "phone_number": "9100000007",
        "is_synthetic": 1,
        "record_source": "synthetic_demo",
        "verification_status": "unverified_demo",
        "primary_specialty": "Pathology",
        "secondary_specialties": ["Transfusion Medicine", "Hematology"],
        "qualifications": [
            {"cadre": "primary_mbbs", "title": "MBBS", "institution": "GMC Nagpur", "year": 2013},
            {"cadre": "postgraduate_md_ms_dnb", "title": "MD Pathology", "institution": "Tata Memorial Hospital Mumbai", "year": 2017},
        ],
        "years_of_experience": 11,
        "practice_environment": "tertiary_hospital",
        "facility_affiliation_ids": ["indore_hospital_007", "indore_hospital_004"],
        "clinical_capabilities": [
            "Blood bank component cross-matching",
            "Massive transfusion protocol release management",
            "Acute hemolytic reaction emergency investigation",
        ],
        "procedure_capabilities": [
            "Therapeutic leukapheresis and plasmapheresis",
            "Bone marrow aspiration and trephine biopsy",
        ],
        "emergency_capabilities": [
            "Emergency uncrossed blood release protocol",
            "Stat coagulation panel turnaround (INR, aPTT, Fibrinogen)",
        ],
        "critical_care_capabilities": [
            "Thromboelastography (TEG/ROTEM) guided resuscitation",
        ],
        "diagnostic_capabilities": [
            "High-throughput automated biochemistry and hematology",
            "Peripheral blood smear examination",
        ],
        "availability_status": "available",
        "duty_shift": "day",
    },

    # --- SECONDARY & GENERAL HOSPITALS (indore_hospital_010 to 029) ---
    {
        "doctor_id": "doc_synth_010",
        "display_name": "Dr. Amit Banerjee",
        "full_name": "Dr. Amit Banerjee",
        "email": "synth.amit.banerjee@demo.medico.in",
        "phone_number": "9100000010",
        "is_synthetic": 1,
        "record_source": "synthetic_demo",
        "verification_status": "unverified_demo",
        "primary_specialty": "Cardiology",
        "secondary_specialties": ["Non-Invasive Cardiology"],
        "qualifications": [
            {"cadre": "primary_mbbs", "title": "MBBS", "institution": "Medical College Kolkata", "year": 2015},
            {"cadre": "postgraduate_md_ms_dnb", "title": "MD General Medicine", "institution": "IPGMER Kolkata", "year": 2019},
        ],
        "years_of_experience": 9,
        "practice_environment": "secondary_hospital",
        "facility_affiliation_ids": ["indore_hospital_010"],
        "clinical_capabilities": [
            "Emergency cardiac resuscitation",
            "12-lead ECG rhythm interpretation",
            "Acute thrombolysis and hemodynamic stabilization",
        ],
        "procedure_capabilities": [
            "Pericardiocentesis (emergency aspiration)",
        ],
        "emergency_capabilities": [
            "Cardioversion and defibrillation",
            "Thrombolytic therapy with Streptokinase/Tenecteplase",
        ],
        "critical_care_capabilities": [
            "Intermediate cardiac care monitoring",
        ],
        "diagnostic_capabilities": [
            "2D Echocardiography",
            "ECG and Troponin analysis",
        ],
        "availability_status": "available",
        "duty_shift": "day",
    },
    {
        "doctor_id": "doc_synth_012",
        "display_name": "Dr. Meenakshi Sundaram",
        "full_name": "Dr. Meenakshi Sundaram",
        "email": "synth.meenakshi.s@demo.medico.in",
        "phone_number": "9100000012",
        "is_synthetic": 1,
        "record_source": "synthetic_demo",
        "verification_status": "unverified_demo",
        "primary_specialty": "General Surgery",
        "secondary_specialties": ["Laparoscopic Surgery", "Trauma Surgery"],
        "qualifications": [
            {"cadre": "primary_mbbs", "title": "MBBS", "institution": "Madras Medical College", "year": 2012},
            {"cadre": "postgraduate_md_ms_dnb", "title": "MS General Surgery", "institution": "Stanley Medical College", "year": 2016},
        ],
        "years_of_experience": 12,
        "practice_environment": "secondary_hospital",
        "facility_affiliation_ids": ["indore_hospital_012", "indore_hospital_018"],
        "clinical_capabilities": [
            "Emergency exploratory laparotomy",
            "Surgical trauma stabilization",
            "Acute appendicitis and hollow viscus perforation repair",
        ],
        "procedure_capabilities": [
            "Emergency laparotomy for abdominal hemorrhage",
            "Laparoscopic appendectomy and cholecystectomy",
            "Inguinal hernia repair with mesh",
            "Wound debridement and laceration repair",
        ],
        "emergency_capabilities": [
            "Intercostal drain insertion",
            "Surgical tracheostomy",
        ],
        "critical_care_capabilities": [
            "Surgical ICU postoperative management",
        ],
        "diagnostic_capabilities": [
            "Abdominal ultrasound FAST scan",
        ],
        "availability_status": "available",
        "duty_shift": "day",
    },
    {
        "doctor_id": "doc_synth_015",
        "display_name": "Dr. Sunita Rao",
        "full_name": "Dr. Sunita Rao",
        "email": "synth.sunita.rao@demo.medico.in",
        "phone_number": "9100000015",
        "is_synthetic": 1,
        "record_source": "synthetic_demo",
        "verification_status": "unverified_demo",
        "primary_specialty": "General medicine",
        "secondary_specialties": ["Diabetology", "Infectious Disease"],
        "qualifications": [
            {"cadre": "primary_mbbs", "title": "MBBS", "institution": "Osmania Medical College Hyderabad", "year": 2014},
            {"cadre": "postgraduate_md_ms_dnb", "title": "MD General Medicine", "institution": "Gandhi Medical College Hyderabad", "year": 2018},
        ],
        "years_of_experience": 10,
        "practice_environment": "secondary_hospital",
        "facility_affiliation_ids": ["indore_hospital_015"],
        "clinical_capabilities": [
            "Primary clinical examination and differential diagnosis",
            "Management of endemic febrile illnesses",
            "Long-term glycemic control evaluation",
            "Hypertensive crisis management",
        ],
        "procedure_capabilities": [
            "Pleural tap and paracentesis",
        ],
        "emergency_capabilities": [
            "Diabetic ketoacidosis (DKA) insulin protocol management",
            "Anaphylaxis emergency treatment",
        ],
        "critical_care_capabilities": [
            "High dependency unit step-down monitoring",
        ],
        "diagnostic_capabilities": [
            "Laboratory diagnostic profiling (CBC, LFT, RFT, HbA1c)",
        ],
        "availability_status": "available",
        "duty_shift": "day",
    },
    {
        "doctor_id": "doc_synth_018",
        "display_name": "Dr. Vikramaditya Rathore",
        "full_name": "Dr. Vikramaditya Rathore",
        "email": "synth.vikram.rathore@demo.medico.in",
        "phone_number": "9100000018",
        "is_synthetic": 1,
        "record_source": "synthetic_demo",
        "verification_status": "unverified_demo",
        "primary_specialty": "Orthopaedics",
        "secondary_specialties": ["Spine Care", "Trauma"],
        "qualifications": [
            {"cadre": "primary_mbbs", "title": "MBBS", "institution": "SMS Medical College Jaipur", "year": 2013},
            {"cadre": "postgraduate_md_ms_dnb", "title": "MS Orthopaedics", "institution": "SNMC Jodhpur", "year": 2017},
        ],
        "years_of_experience": 11,
        "practice_environment": "secondary_hospital",
        "facility_affiliation_ids": ["indore_hospital_018"],
        "clinical_capabilities": [
            "Closed reduction and casting of complex limb fractures",
            "Tendon repair and soft-tissue reconstruction",
        ],
        "procedure_capabilities": [
            "Intramedullary interlocking nailing for femur/tibia",
            "External fixation of open compound fractures",
        ],
        "emergency_capabilities": [
            "Dislocation reduction under sedation",
            "Compartment pressure measurement",
        ],
        "critical_care_capabilities": [
            "Post-operative orthopedic care",
        ],
        "diagnostic_capabilities": [
            "Radiological bone assessment",
        ],
        "availability_status": "available",
        "duty_shift": "day",
    },

    # --- MULTISPECIALTY CLINICS (indore_healthcare_030 to 040) ---
    {
        "doctor_id": "doc_synth_031",
        "display_name": "Dr. Fatima Sheikh",
        "full_name": "Dr. Fatima Sheikh",
        "email": "synth.fatima.sheikh@demo.medico.in",
        "phone_number": "9100000031",
        "is_synthetic": 1,
        "record_source": "synthetic_demo",
        "verification_status": "unverified_demo",
        "primary_specialty": "Paediatrics",
        "secondary_specialties": ["Child Growth & Nutrition"],
        "qualifications": [
            {"cadre": "primary_mbbs", "title": "MBBS", "institution": "MGM Medical College Indore", "year": 2016},
            {"cadre": "diploma_fellowship", "title": "DCH (Diploma in Child Health)", "institution": "MGM Medical College Indore", "year": 2019},
        ],
        "years_of_experience": 8,
        "practice_environment": "multispecialty_clinic",
        "facility_affiliation_ids": ["indore_healthcare_031", "indore_healthcare_032"],
        "clinical_capabilities": [
            "Outpatient pediatric growth monitoring",
            "Immunization schedules and vaccine administration",
            "Treatment of common pediatric respiratory infections and diarrhea",
        ],
        "procedure_capabilities": [
            "Pediatric nebulization",
            "Oral rehydration therapy administration",
        ],
        "emergency_capabilities": [
            "Basic pediatric resuscitation and referral stabilization",
        ],
        "critical_care_capabilities": [],
        "diagnostic_capabilities": [
            "Anthropometric nutritional grading",
        ],
        "availability_status": "available",
        "duty_shift": "day",
    },
    {
        "doctor_id": "doc_synth_035",
        "display_name": "Dr. Alok Nath Mukherjee",
        "full_name": "Dr. Alok Nath Mukherjee",
        "email": "synth.alok.mukherjee@demo.medico.in",
        "phone_number": "9100000035",
        "is_synthetic": 1,
        "record_source": "synthetic_demo",
        "verification_status": "unverified_demo",
        "primary_specialty": "General medicine",
        "secondary_specialties": ["Hypertension", "Geriatric Medicine"],
        "qualifications": [
            {"cadre": "primary_mbbs", "title": "MBBS", "institution": "Calcutta National Medical College", "year": 2008},
            {"cadre": "postgraduate_md_ms_dnb", "title": "MD General Medicine", "institution": "R.G. Kar Medical College", "year": 2012},
        ],
        "years_of_experience": 16,
        "practice_environment": "multispecialty_clinic",
        "facility_affiliation_ids": ["indore_healthcare_035"],
        "clinical_capabilities": [
            "Outpatient chronic disease management",
            "Elderly multi-morbidity polypharmacy review",
            "Cardiovascular risk assessment",
        ],
        "procedure_capabilities": [
            "Peripheral vein cannulation",
        ],
        "emergency_capabilities": [
            "Basic Life Support (BLS)",
        ],
        "critical_care_capabilities": [],
        "diagnostic_capabilities": [
            "ECG interpretation",
            "Point-of-care capillary glucose testing",
        ],
        "availability_status": "available",
        "duty_shift": "day",
    },

    # --- SMALL GENERAL CLINICS (indore_healthcare_041 to 045) ---
    {
        "doctor_id": "doc_synth_041",
        "display_name": "Dr. Sandeep Yadav",
        "full_name": "Dr. Sandeep Yadav",
        "email": "synth.sandeep.yadav@demo.medico.in",
        "phone_number": "9100000041",
        "is_synthetic": 1,
        "record_source": "synthetic_demo",
        "verification_status": "unverified_demo",
        "primary_specialty": "General Practice",
        "secondary_specialties": ["Community Health", "Family Medicine"],
        "qualifications": [
            {"cadre": "primary_mbbs", "title": "MBBS", "institution": "MGM Medical College Indore", "year": 2016},
        ],
        "years_of_experience": 8,
        "practice_environment": "independent_clinic",
        "facility_affiliation_ids": ["indore_healthcare_041"],
        "clinical_capabilities": [
            "Primary care triage and symptom assessment",
            "Treatment of common viral fevers, URI, gastroenteritis",
            "Management of uncomplicated hypertension and diabetes",
            "Wound dressings and minor suturing",
        ],
        "procedure_capabilities": [
            "Minor skin abscess incision and drainage",
            "Peripheral IV cannulation and fluid administration",
            "Removal of superficial foreign bodies",
        ],
        "emergency_capabilities": [
            "Basic Life Support (BLS)",
            "First aid stabilization prior to hospital referral",
        ],
        "critical_care_capabilities": [],
        "diagnostic_capabilities": [
            "Blood glucose fingerstick testing",
            "Urine dipstick analysis",
            "Rapid antigen tests (Malaria/Dengue)",
        ],
        "availability_status": "available",
        "duty_shift": "day",
    },
    {
        "doctor_id": "doc_synth_042",
        "display_name": "Dr. Rajesh Gupta",
        "full_name": "Dr. Rajesh Gupta",
        "email": "synth.rajesh.gupta@demo.medico.in",
        "phone_number": "9100000042",
        "is_synthetic": 1,
        "record_source": "synthetic_demo",
        "verification_status": "unverified_demo",
        "primary_specialty": "General Practice",
        "secondary_specialties": ["Family Medicine"],
        "qualifications": [
            {"cadre": "primary_mbbs", "title": "MBBS", "institution": "GMC Jabalpur", "year": 2015},
        ],
        "years_of_experience": 9,
        "practice_environment": "independent_clinic",
        "facility_affiliation_ids": ["indore_healthcare_042"],
        "clinical_capabilities": [
            "Routine health check-ups and screening",
            "Primary clinical diagnosis of infectious fevers",
            "Prescription of essential oral medications",
        ],
        "procedure_capabilities": [
            "Simple wound care and aseptic dressings",
        ],
        "emergency_capabilities": [
            "Oxygen cannula administration and prompt transfer referral",
        ],
        "critical_care_capabilities": [],
        "diagnostic_capabilities": [
            "Rapid diagnostic point-of-care testing",
        ],
        "availability_status": "available",
        "duty_shift": "day",
    },
    {
        "doctor_id": "doc_synth_045",
        "display_name": "Dr. Suresh Chandran",
        "full_name": "Dr. Suresh Chandran",
        "email": "synth.suresh.chandran@demo.medico.in",
        "phone_number": "9100000045",
        "is_synthetic": 1,
        "record_source": "synthetic_demo",
        "verification_status": "unverified_demo",
        "primary_specialty": "General Practice",
        "secondary_specialties": ["Public Health"],
        "qualifications": [
            {"cadre": "primary_mbbs", "title": "MBBS", "institution": "Calicut Medical College", "year": 2017},
        ],
        "years_of_experience": 7,
        "practice_environment": "independent_clinic",
        "facility_affiliation_ids": ["indore_healthcare_045"],
        "clinical_capabilities": [
            "Basic outpatient consultation and follow-up",
            "Chronic medication refill reviews",
            "Triage for tertiary medical center escalation",
        ],
        "procedure_capabilities": [
            "Subcutaneous and intramuscular injections",
        ],
        "emergency_capabilities": [
            "Basic primary stabilization",
        ],
        "critical_care_capabilities": [],
        "diagnostic_capabilities": [
            "Blood pressure manual sphygmomanometer check",
        ],
        "availability_status": "available",
        "duty_shift": "day",
    },
]


def calculate_synthetic_doctor_score(doctor: Dict[str, Any]) -> Dict[str, Any]:
    """
    Computes unified 4-pillar capability score for synthetic profiles.
    Pillar 1: Base Expertise (max 30)
    Pillar 2: Clinical Experience (max 30)
    Pillar 3: Clinical Volume & Impact (max 25)
    Pillar 4: Professional Standing (max 15)
    """
    quals = doctor.get("qualifications", [])
    has_super = any(q.get("cadre") == "super_specialty_dm_mch" for q in quals)
    has_pg = any(q.get("cadre") == "postgraduate_md_ms_dnb" for q in quals)
    has_dip = any(q.get("cadre") == "diploma_fellowship" for q in quals)

    # 1. Base Expertise (30 max)
    if has_super:
        base_exp = 30.0
    elif has_pg:
        base_exp = 25.0
    elif has_dip:
        base_exp = 20.0
    else:
        base_exp = 15.0

    # 2. Clinical Experience (30 max: 1.5 pts / yr)
    yoe = doctor.get("years_of_experience", 5)
    exp_score = min(30.0, yoe * 1.5)

    # 3. Clinical Volume (25 max: normalized for clinic 2000 vs hospital 3000)
    env = doctor.get("practice_environment", "tertiary_hospital")
    is_clinic = "clinic" in env
    target_vol = 2000.0 if is_clinic else 3000.0
    # Plausible annual workload
    annual_vol = 2400 if is_clinic else 3200
    vol_score = min(25.0, (annual_vol / target_vol) * 25.0)

    # 4. Standing (15 max)
    standing_score = 10.0 if not is_clinic else 5.0

    total_score = round(base_exp + exp_score + vol_score + standing_score, 1)

    return {
        "baseExpertiseScore": base_exp,
        "clinicalExperienceScore": exp_score,
        "clinicalVolumeScore": vol_score,
        "professionalStandingScore": standing_score,
        "totalCapabilityScore": total_score,
        "isProvisional": True,
        "scoringVersion": "1.0.0",
        "calculatedAt": datetime.now(timezone.utc).isoformat(),
    }
