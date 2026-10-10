"""
SMART Referral - Central Authoritative Database Layer
Manages SQLite connection, schema migration, synthetic hospital seeding,
revision increments, conflict detection, and audit logging.
"""

import json
import os
import sqlite3
import uuid
from datetime import datetime, timezone
from typing import Dict, Any, List, Tuple

DB_DIR = os.path.dirname(os.path.abspath(__file__))
DB_PATH = os.path.join(DB_DIR, "central_healthcare.db")
SCHEMA_PATH = os.path.join(DB_DIR, "schema.sql")
JSON_SEED_PATH = os.path.join(os.path.dirname(DB_DIR), "assets", "data", "indore_hospitals_synthetic_clinics.json")


def get_db_connection():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


def init_database():
    """Initializes schema and seeds default dataset if empty."""
    os.makedirs(DB_DIR, exist_ok=True)
    conn = get_db_connection()
    with open(SCHEMA_PATH, "r", encoding="utf-8") as f:
        conn.executescript(f.read())

    # Migrate columns if doctor_profiles or facility_resource_inventory already existed without new columns
    _migrate_doctor_profiles_columns(conn)
    _migrate_facility_resources_columns(conn)
    _migrate_gemini_and_offline_tables(conn)

    # Seed roles if empty
    cur = conn.cursor()
    cur.execute("SELECT COUNT(*) FROM roles_and_permissions")
    if cur.fetchone()[0] == 0:
        _seed_roles(conn)

    # Seed hospitals if empty
    cur.execute("SELECT COUNT(*) FROM healthcare_facilities")
    if cur.fetchone()[0] == 0:
        _seed_facilities_from_json(conn)

    # Seed condition requirements, facility inventory, extended infrastructure, and synthetic doctors
    _seed_condition_capability_requirements(conn)
    _seed_facility_resource_inventory(conn)
    _seed_facility_extended_infrastructure(conn)
    _seed_synthetic_doctors(conn)
    _seed_clinical_tags(conn)

    conn.commit()
    conn.close()
    print("[CentralDB] Database schema initialized, migrated, and verified.")


def _seed_roles(conn):
    roles = [
        ("admin", "System Administrator", "Full authority over facility records and verification", 1, 1, 1, 1),
        ("district_officer", "District Health Officer", "Can verify facilities and edit capabilities", 1, 1, 1, 1),
        ("hospital_duty_officer", "Hospital Duty Officer", "Can report live bed and ICU operational status", 0, 0, 1, 1),
        ("clinician", "Primary Care Clinician", "Can report local observations and trigger referrals", 0, 0, 1, 0),
        ("public_read", "Public / Offline Client", "Read-only access to cached facilities", 0, 0, 0, 0),
    ]
    conn.executemany(
        """
        INSERT INTO roles_and_permissions 
        (role_id, role_name, description, can_modify_facilities, can_modify_verification, can_update_operational_status, can_view_audit_logs)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """,
        roles,
    )


def _seed_facilities_from_json(conn):
    if not os.path.exists(JSON_SEED_PATH):
        print(f"[CentralDB] Warning: Seed file {JSON_SEED_PATH} not found.")
        return

    with open(JSON_SEED_PATH, "r", encoding="utf-8") as f:
        data = json.load(f)

    facilities = data.get("hospitals", []) or data.get("facilities", [])
    now_str = datetime.now(timezone.utc).isoformat()

    for idx, item in enumerate(facilities, start=1):
        fac_id = item.get("id") or f"indore_hospital_{idx:03d}"
        name = item.get("name", "Healthcare Facility")
        addr_obj = item.get("address", {})
        if isinstance(addr_obj, dict):
            address = addr_obj.get("full_address") or f"{addr_obj.get('street', '')}, Indore, MP"
        else:
            address = str(addr_obj)

        coords = item.get("coordinates") or {}
        lat = coords.get("latitude") or (22.7196 + (idx * 0.003) - 0.05)
        lon = coords.get("longitude") or (75.8577 + (idx * 0.003) - 0.05)

        fac_type = item.get("facility_type") or "general_hospital"
        tags = json.dumps(item.get("tags") or ["General Healthcare"])

        fac_spec = item.get("facilities") or {}
        emergency_care = 1 if fac_spec.get("emergency_services", {}).get("value") is True else 0
        icu_avail = 1 if fac_spec.get("icu", {}).get("value") is True else 0
        bed_cap = fac_spec.get("bed_capacity") or 25

        # Insert master facility
        conn.execute(
            """
            INSERT OR REPLACE INTO healthcare_facilities 
            (facility_id, name, address, latitude, longitude, facility_type, emergency_care, icu_available,
             current_capacity, bed_availability, operating_status, tags, is_verified, is_simulated_data,
             data_source, revision, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                fac_id,
                name,
                address,
                lat,
                lon,
                fac_type,
                emergency_care,
                icu_avail,
                0.75,
                bed_cap,
                "Operational",
                tags,
                1,
                1,
                "Indore Health Network Central Registry",
                1,
                now_str,
                now_str,
            ),
        )

        # Insert services
        specs = item.get("specialties_reported") or ["General Medicine"]
        for spec in specs:
            conn.execute(
                """
                INSERT INTO facility_services (facility_id, service_name, service_category, is_active, revision, updated_at)
                VALUES (?, ?, ?, 1, 1, ?)
                """,
                (fac_id, spec, "Specialty", now_str),
            )

        # Insert capabilities
        treatments = item.get("treatments_reported") or ["Emergency Care"]
        for tr in treatments:
            conn.execute(
                """
                INSERT INTO facility_capabilities (facility_id, capability_name, capability_type, is_available, revision, updated_at)
                VALUES (?, ?, 'treatment', 1, 1, ?)
                """,
                (fac_id, tr, now_str),
            )

        # Insert operational status
        conn.execute(
            """
            INSERT OR REPLACE INTO facility_operational_status 
            (facility_id, operating_status, general_beds_available, icu_beds_available, operating_theaters_available,
             ambulance_available, current_capacity, emergency_department_open, last_reported_at, reported_by_user,
             freshness_ttl_seconds, is_verified_live, revision)
            VALUES (?, 'Operational', ?, ?, ?, 1, 0.75, ?, ?, 'Central Admin', 1800, 1, 1)
            """,
            (fac_id, bed_cap, 4 if icu_avail else 0, 2 if emergency_care else 0, emergency_care, now_str),
        )

        # Verification record
        ver_obj = item.get("verification") or {}
        ver_status = ver_obj.get("overall_status") or "verified_by_authority"
        conn.execute(
            """
            INSERT INTO facility_verification_records
            (facility_id, verified_by_user, verification_tier, verification_method, verification_date, notes, is_active)
            VALUES (?, 'Chief Medical Officer Indore', 'District Health Authority', 'Central Registry Inspection', ?, ?, 1)
            """,
            (fac_id, now_str, f"Status: {ver_status}"),
        )

    print(f"[CentralDB] Successfully seeded {len(facilities)} authoritative Indore healthcare facilities.")


def _migrate_doctor_profiles_columns(conn):
    cur = conn.cursor()
    existing_cols = {r[1] for r in cur.execute("PRAGMA table_info(doctor_profiles)").fetchall()}
    new_cols = [
        ("is_synthetic", "INTEGER NOT NULL DEFAULT 0"),
        ("record_source", "TEXT NOT NULL DEFAULT 'registration'"),
        ("primary_specialty", "TEXT"),
        ("secondary_specialties", "TEXT DEFAULT '[]'"),
        ("clinical_capabilities", "TEXT DEFAULT '[]'"),
        ("procedure_capabilities", "TEXT DEFAULT '[]'"),
        ("emergency_capabilities", "TEXT DEFAULT '[]'"),
        ("critical_care_capabilities", "TEXT DEFAULT '[]'"),
        ("diagnostic_capabilities", "TEXT DEFAULT '[]'"),
        ("normalized_capability_score", "REAL DEFAULT 0.0"),
        ("score_breakdown", "TEXT DEFAULT '{}'"),
        ("score_last_calculated_at", "TEXT"),
    ]
    for col_name, col_def in new_cols:
        if col_name not in existing_cols:
            cur.execute(f"ALTER TABLE doctor_profiles ADD COLUMN {col_name} {col_def}")


def _migrate_facility_resources_columns(conn):
    """Safely adds missing structured equipment & technology columns to facility_resource_inventory."""
    cur = conn.cursor()
    tbl_exists = cur.execute("SELECT count(*) FROM sqlite_master WHERE type='table' AND name='facility_resource_inventory'").fetchone()[0]
    if not tbl_exists:
        return

    existing_cols = {r[1] for r in cur.execute("PRAGMA table_info(facility_resource_inventory)").fetchall()}
    new_cols = [
        ("resource_id", "TEXT"),
        ("resource_category", "TEXT NOT NULL DEFAULT 'diagnostic_and_imaging'"),
        ("model_spec", "TEXT"),
        ("quantity_installed", "INTEGER NOT NULL DEFAULT 1"),
        ("quantity_operational", "INTEGER NOT NULL DEFAULT 1"),
        ("quantity_out_of_service", "INTEGER NOT NULL DEFAULT 0"),
        ("operational_status", "TEXT NOT NULL DEFAULT 'operational'"),
        ("location_in_facility", "TEXT NOT NULL DEFAULT 'Main Clinical Block'"),
        ("ownership_type", "TEXT NOT NULL DEFAULT 'in_house_owned'"),
        ("service_delivery", "TEXT NOT NULL DEFAULT 'in_house'"),
        ("turnaround_time_hours", "INTEGER NOT NULL DEFAULT 0"),
        ("availability_schedule", "TEXT NOT NULL DEFAULT '24/7'"),
        ("last_maintenance_date", "TEXT"),
        ("next_maintenance_date", "TEXT"),
        ("operator_requirements", "TEXT NOT NULL DEFAULT 'Trained Clinical Staff'"),
        ("verification_status", "TEXT NOT NULL DEFAULT 'verified'"),
        ("verified_by", "TEXT NOT NULL DEFAULT 'Hospital Administrator'"),
        ("evidence_document_name", "TEXT"),
        ("notes", "TEXT"),
        ("record_source", "TEXT NOT NULL DEFAULT 'Facility Infrastructure Audit'"),
        ("created_at", "TEXT"),
        ("updated_at", "TEXT"),
    ]
    for col_name, col_def in new_cols:
        if col_name not in existing_cols:
            cur.execute(f"ALTER TABLE facility_resource_inventory ADD COLUMN {col_name} {col_def}")

    # Backfill timestamps & resource_id if empty
    cur.execute("UPDATE facility_resource_inventory SET created_at = datetime('now') WHERE created_at IS NULL")
    cur.execute("UPDATE facility_resource_inventory SET updated_at = datetime('now') WHERE updated_at IS NULL")
    cur.execute("UPDATE facility_resource_inventory SET resource_id = 'res_' || inventory_id WHERE resource_id IS NULL OR resource_id = ''")

    # Re-categorize resources to appropriate 7 categories
    category_map = {
        "ecg": "diagnostic_and_imaging",
        "ct": "diagnostic_and_imaging",
        "mri": "diagnostic_and_imaging",
        "x-ray": "diagnostic_and_imaging",
        "ultrasound": "diagnostic_and_imaging",
        "pathology": "laboratory_and_pathology",
        "biochemistry": "laboratory_and_pathology",
        "lab": "laboratory_and_pathology",
        "ventilat": "critical_care_and_life_support",
        "defibrillator": "critical_care_and_life_support",
        "monitor": "critical_care_and_life_support",
        "bipap": "critical_care_and_life_support",
        "respiratory": "critical_care_and_life_support",
        "icu": "critical_care_and_life_support",
        "theater": "surgical_and_theatre",
        "theatre": "surgical_and_theatre",
        "surgery": "surgical_and_theatre",
        "c-section": "surgical_and_theatre",
        "trauma": "emergency_and_trauma",
        "emergency": "emergency_and_trauma",
        "oxygen": "emergency_and_trauma",
        "cath": "specialized_treatment",
        "cardiology": "specialized_treatment",
        "dialysis": "specialized_treatment",
        "phototherapy": "specialized_treatment",
        "warmer": "specialized_treatment",
        "tele": "telemedicine_and_digital_health",
        "emr": "telemedicine_and_digital_health",
    }
    for kw, cat in category_map.items():
        cur.execute(
            "UPDATE facility_resource_inventory SET resource_category = ? WHERE LOWER(resource_name) LIKE ? AND resource_category = 'diagnostic_and_imaging'",
            (cat, f"%{kw}%"),
        )

    # Safely create indexes after columns exist
    cur.execute("CREATE INDEX IF NOT EXISTS idx_inventory_cat ON facility_resource_inventory(resource_category)")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_inventory_res_id ON facility_resource_inventory(resource_id)")

    # Ensure facility_departments columns exist
    dept_exists = cur.execute("SELECT count(*) FROM sqlite_master WHERE type='table' AND name='facility_departments'").fetchone()[0]
    if dept_exists:
        dept_cols = {r[1] for r in cur.execute("PRAGMA table_info(facility_departments)").fetchall()}
        if "specialist_coverage" not in dept_cols:
            cur.execute("ALTER TABLE facility_departments ADD COLUMN specialist_coverage TEXT NOT NULL DEFAULT 'on_site'")
        if "care_levels_json" not in dept_cols:
            cur.execute("ALTER TABLE facility_departments ADD COLUMN care_levels_json TEXT NOT NULL DEFAULT '[\"outpatient\", \"inpatient\", \"emergency\"]'")


def _seed_condition_capability_requirements(conn):
    try:
        from condition_capabilities import CLINICAL_CONDITIONS
    except ImportError:
        import sys
        sys.path.insert(0, DB_DIR)
        from condition_capabilities import CLINICAL_CONDITIONS

    cur = conn.cursor()
    cur.execute("SELECT COUNT(*) FROM condition_capability_requirements")
    if cur.fetchone()[0] == 0:
        for cond_key, cdef in CLINICAL_CONDITIONS.items():
            conn.execute(
                """
                INSERT OR REPLACE INTO condition_capability_requirements (
                    condition_key, condition_name, urgency_level, required_specialties,
                    essential_doctor_capabilities, essential_equipment,
                    emergency_stabilization_required, critical_care_required,
                    supporting_capabilities, acceptable_referral_fallback,
                    required_data_freshness_hours, capability_rationales
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    cond_key,
                    cdef["condition_name"],
                    cdef["urgency_level"],
                    json.dumps(cdef.get("required_specialties", [])),
                    json.dumps(cdef.get("essential_doctor_capabilities", [])),
                    json.dumps(cdef.get("essential_equipment", [])),
                    1 if cdef.get("emergency_stabilization_required") else 0,
                    1 if cdef.get("critical_care_required") else 0,
                    json.dumps(cdef.get("supporting_capabilities", [])),
                    cdef.get("acceptable_referral_fallback", ""),
                    cdef.get("required_data_freshness_hours", 24),
                    json.dumps(cdef.get("capability_rationales", {})),
                ),
            )
        print("[CentralDB] Seeded 8 clinical condition capability requirements.")


def _seed_facility_resource_inventory(conn):
    cur = conn.cursor()
    cur.execute("SELECT COUNT(*) FROM facility_resource_inventory")
    if cur.fetchone()[0] == 0:
        now_str = datetime.now(timezone.utc).isoformat()
        facs = cur.execute("SELECT facility_id, name, facility_type, emergency_care, icu_available, tags FROM healthcare_facilities").fetchall()
        for f in facs:
            fid = f["facility_id"]
            ftype = f["facility_type"] or ""
            tags = json.loads(f["tags"]) if f["tags"] else []
            tags_lower = [t.lower() for t in tags]

            resources = [
                ("diagnostics", "Pathology & Biochemistry Lab", 1, "operational"),
                ("service", "General Medicine", 1, "operational"),
                ("equipment", "Basic Diagnostic Kit", 1, "operational"),
            ]

            if f["emergency_care"]:
                resources.append(("service", "24/7 Emergency Care", 1, "operational"))
                resources.append(("equipment", "12-Lead ECG", 1, "operational"))
                resources.append(("equipment", "Defibrillator", 1, "operational"))
                resources.append(("equipment", "Emergency Oxygen", 1, "operational"))

            if f["icu_available"]:
                resources.append(("service", "Intensive Care Unit (ICU)", 1, "operational"))
                resources.append(("equipment", "ICU Mechanical Ventilation", 1, "operational"))
                resources.append(("equipment", "Multiparameter Patient Monitor", 1, "operational"))

            is_tertiary = any(k in ftype for k in ["super_speciality", "medical_college", "multispecialty_hospital"]) or any("tertiary" in t or "super" in t for t in tags_lower)

            if any("cath" in t or "cardiac" in t for t in tags_lower) or fid in ["indore_hospital_001", "indore_hospital_003", "indore_hospital_005", "indore_hospital_008", "indore_hospital_015"]:
                resources.append(("equipment", "Cath Lab / Cardiac", 1, "operational"))
                resources.append(("service", "Interventional Cardiology", 1, "operational"))

            if any("ct" in t or "radiology" in t or "mri" in t for t in tags_lower) or is_tertiary or fid in ["indore_hospital_001", "indore_hospital_002", "indore_hospital_003", "indore_hospital_006", "indore_hospital_008", "indore_hospital_010"]:
                resources.append(("equipment", "16-Slice CT Scanner", 1, "operational"))
                resources.append(("diagnostics", "CT Scan", 1, "operational"))

            if any("blood bank" in t for t in tags_lower) or fid in ["indore_hospital_001", "indore_hospital_003", "indore_hospital_005", "indore_hospital_008"]:
                resources.append(("service", "24/7 Blood Bank", 1, "operational"))

            if any("trauma" in t for t in tags_lower) or is_tertiary:
                resources.append(("service", "Trauma Care", 1, "operational"))
                resources.append(("service", "Operating Theater", 1, "operational"))

            if any("obstetric" in t or "delivery" in t or "maternity" in t or "gynae" in t for t in tags_lower) or fid in ["indore_hospital_002", "indore_hospital_003", "indore_hospital_009", "indore_healthcare_035"]:
                resources.append(("service", "Emergency C-Section", 1, "operational"))
                resources.append(("service", "Obstetrics & Gynaecology", 1, "operational"))

            if any("pediatric" in t or "child" in t for t in tags_lower) or is_tertiary:
                resources.append(("service", "Paediatrics", 1, "operational"))
                resources.append(("equipment", "Pediatric Respiratory Support", 1, "operational"))

            for rtype, rname, is_pres, op_stat in resources:
                conn.execute(
                    """
                    INSERT INTO facility_resource_inventory (facility_id, resource_type, resource_name, is_present, operational_status, last_verified_at)
                    VALUES (?, ?, ?, ?, ?, ?)
                    """,
                    (fid, rtype, rname, is_pres, op_stat, now_str)
                )
        print("[CentralDB] Seeded facility resource inventory for all authoritative facilities.")


def _seed_facility_extended_infrastructure(conn):
    """
    Seeds comprehensive baseline infrastructure, capacity, departments, staff,
    and 7-category medical equipment across all 45 preloaded healthcare facilities.
    """
    cur = conn.cursor()
    now_str = datetime.now(timezone.utc).isoformat()
    facs = cur.execute(
        "SELECT facility_id, name, facility_type, address, latitude, longitude, emergency_care, icu_available, bed_availability, tags FROM healthcare_facilities"
    ).fetchall()

    for f in facs:
        fid = f["facility_id"]
        fname = f["name"]
        ftype = f["facility_type"] or ""
        tags = json.loads(f["tags"]) if f["tags"] else []
        tags_lower = [t.lower() for t in tags]
        tot_beds = max(20, int(f["bed_availability"] or 25))
        has_em = bool(f["emergency_care"])
        has_icu = bool(f["icu_available"])
        is_tertiary = any(k in ftype for k in ["super_speciality", "medical_college", "multispecialty_hospital"]) or any("tertiary" in t or "super" in t for t in tags_lower) or tot_beds > 100

        # 1. Profile
        prof_exists = cur.execute("SELECT 1 FROM facility_profiles WHERE facility_id = ?", (fid,)).fetchone()
        if not prof_exists:
            dept_names = ["Emergency & Trauma", "General Medicine", "General Surgery", "Paediatrics", "Obstetrics & Gynaecology", "Radiology", "Pathology"]
            if has_icu:
                dept_names.append("Intensive Care Unit (ICU)")
            if any("card" in t for t in tags_lower):
                dept_names.append("Cardiology")
            if any("neuro" in t for t in tags_lower):
                dept_names.append("Neurology & Neurosurgery")
            if any("ortho" in t for t in tags_lower):
                dept_names.append("Orthopaedics")

            cur.execute(
                """
                INSERT OR REPLACE INTO facility_profiles (
                    facility_id, contact_number, official_email, opening_hours, operating_days,
                    license_number, registration_authority, admin_user_id, admin_name,
                    emergency_services_detail, departments_json, profile_completion_percentage,
                    last_verified_at, verification_status, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    fid,
                    "+91 731 2894000",
                    f"admin.{fid.lower()}@mp.health.gov.in",
                    "24 Hours (Round the Clock)" if has_em else "08:00 - 20:00 (Extended OPD)",
                    "All Days (Monday - Sunday)",
                    f"MP-DHS-REG-2026-{fid.replace('indore_', '').upper()}",
                    "Madhya Pradesh Directorate of Health Services / NABH Quality Council of India",
                    f"admin_{fid}",
                    f"Medical Superintendent / Administrator ({fname[:25]})",
                    "24/7 Level-1/2 Emergency Resuscitation & Acute Triage Unit" if has_em else "Daytime Outpatient Emergency Stabilization & Basic Triage",
                    json.dumps(dept_names),
                    94,
                    now_str,
                    "verified",
                    now_str,
                    now_str,
                ),
            )

        # 2. Supporting Infrastructure
        supp_exists = cur.execute("SELECT 1 FROM facility_supporting_infrastructure WHERE facility_id = ?", (fid,)).fetchone()
        if not supp_exists:
            cur.execute(
                """
                INSERT OR REPLACE INTO facility_supporting_infrastructure (
                    facility_id, ambulance_arrangements, blood_bank_access, pharmacy_available,
                    oxygen_infrastructure, power_backup, isolation_capability, infection_control,
                    referral_partnerships, telemedicine_capability, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    fid,
                    "Dedicated 108 Advanced Life Support (ALS) Ambulance Stationed on Site" if has_em else "108 Emergency Ambulance On-Call Network Linkage",
                    "24/7 Licensed In-House Blood Bank with Component Separation (PRBC, FFP, Platelets)" if is_tertiary else "District Blood Bank Indore Linkage (30-min Emergency Delivery)",
                    "24/7 Registered In-House Pharmacy with Full Essential & Emergency Formulary",
                    "Cryogenic Liquid Medical Oxygen (LMO) Storage Tank (10 KL) + Duplex Pipeline Manifold" if is_tertiary else "Dual High-Pressure Oxygen Manifold (20 D-Cylinders) + 10 Concentrators",
                    "Dual 500 kVA Diesel Generators with Automatic Mains Failure (AMF) Switching + Online UPS" if is_tertiary else "125 kVA Diesel Generator with Auto-Switching + 10 kVA UPS",
                    "6 Negative Pressure Airborne Infection Isolation Rooms (AIIR) with HEPA Filtration" if is_tertiary else "4-Bed Dedicated Isolation Ward with Barrier Nursing",
                    "NABH Certified Hospital Infection Prevention & Control Committee (HICC) Audited",
                    "Ayushman Bharat PM-JAY Empaneled & MP State Emergency Healthcare Network Member",
                    "Real-Time Tele-ICU Command Console & PACS High-Resolution Radiology Link",
                    now_str,
                ),
            )

        # 3. Capacity Records
        cap_count = cur.execute("SELECT COUNT(*) FROM facility_capacity_records WHERE facility_id = ?", (fid,)).fetchone()[0]
        if cap_count == 0:
            gen_inst = max(6, int(tot_beds * 0.60))
            gen_oper = max(5, int(tot_beds * 0.55))
            gen_occ = max(3, int(tot_beds * 0.42))

            em_inst = max(2, int(tot_beds * 0.08)) if has_em else 2
            em_oper = em_inst
            em_occ = max(1, int(em_inst * 0.6))

            icu_inst = max(2, int(tot_beds * 0.12)) if has_icu else 0
            icu_oper = max(2, int(tot_beds * 0.10)) if has_icu else 0
            icu_occ = max(1, int(icu_inst * 0.70)) if has_icu else 0

            hdu_inst = max(2, int(tot_beds * 0.06)) if has_icu else 0
            hdu_oper = max(2, int(tot_beds * 0.05)) if has_icu else 0
            hdu_occ = max(1, int(hdu_inst * 0.60)) if has_icu else 0

            ped_inst = max(2, int(tot_beds * 0.08))
            ped_oper = max(2, int(tot_beds * 0.07))
            ped_occ = max(1, int(ped_inst * 0.50))

            mat_inst = max(2, int(tot_beds * 0.08))
            mat_oper = max(2, int(tot_beds * 0.07))
            mat_occ = max(1, int(mat_inst * 0.50))

            iso_inst = max(1, int(tot_beds * 0.03))
            iso_oper = iso_inst
            iso_occ = max(0, int(iso_inst * 0.3))

            ot_inst = max(1, int(tot_beds * 0.02)) if is_tertiary else (1 if "hospital" in ftype else 0)
            ot_oper = ot_inst
            ot_occ = max(0, ot_inst - 1) if ot_inst > 1 else 0

            dial_inst = max(4, int(tot_beds * 0.03)) if is_tertiary else 0
            dial_oper = dial_inst
            dial_occ = max(2, int(dial_inst * 0.65)) if dial_inst > 0 else 0

            capacity_defs = [
                ("general_inpatient", "General Inpatient Ward", gen_inst, gen_oper, gen_occ),
                ("emergency_bays", "Emergency & Trauma Bays", em_inst, em_oper, em_occ),
                ("icu_beds", "Intensive Care Unit (ICU)", icu_inst, icu_oper, icu_occ),
                ("hdu_beds", "High Dependency Unit (HDU)", hdu_inst, hdu_oper, hdu_occ),
                ("pediatric_beds", "Pediatric Ward & PICU", ped_inst, ped_oper, ped_occ),
                ("maternity_beds", "Maternity & Labour Ward", mat_inst, mat_oper, mat_occ),
                ("isolation_beds", "Negative Pressure / Isolation Beds", iso_inst, iso_oper, iso_occ),
                ("operating_theatres", "Operating Theatres (Major & Minor)", ot_inst, ot_oper, ot_occ),
                ("dialysis_stations", "Hemodialysis Stations", dial_inst, dial_oper, dial_occ),
            ]

            for cat, lbl, inst, oper, occ in capacity_defs:
                avail = max(0, oper - occ)
                cur.execute(
                    """
                    INSERT INTO facility_capacity_records (
                        capacity_id, facility_id, category, category_label,
                        installed_capacity, operational_capacity, occupied_capacity, available_capacity,
                        source, last_updated_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (f"cap_{fid}_{cat}", fid, cat, lbl, inst, oper, occ, avail, "Automated Baseline Census", now_str),
                )

        # 4. Departments
        dept_count = cur.execute("SELECT COUNT(*) FROM facility_departments WHERE facility_id = ?", (fid,)).fetchone()[0]
        if dept_count == 0:
            standard_depts = [
                ("Emergency Department", ["Emergency Medicine", "Trauma Triage"], ["24/7 Resuscitation", "Acute Care"], "24 Hours", 1),
                ("General Medicine", ["Internal Medicine", "Geriatrics"], ["OPD", "Inpatient Rounds"], "08:00 - 20:00", 0),
                ("General Surgery", ["General Surgery", "Laparoscopy"], ["Elective OT", "Emergency Laparotomy"], "24 Hours" if has_em else "09:00 - 17:00", 1 if has_em else 0),
                ("Obstetrics & Gynaecology", ["Obstetrics", "Gynaecology"], ["Antenatal Clinic", "Labour Ward", "C-Section"], "24 Hours" if has_em else "09:00 - 17:00", 1 if has_em else 0),
                ("Paediatrics & Neonatology", ["General Paediatrics", "Neonatal Care"], ["Immunization", "SNCU", "Pediatric Inpatient"], "24 Hours" if has_em else "09:00 - 17:00", 1 if has_em else 0),
                ("Radiology & Imaging", ["Radiography", "Ultrasonography", "CT Scan"], ["X-Ray", "Color Doppler", "CT Scan"], "24 Hours" if has_em else "09:00 - 18:00", 1 if has_em else 0),
                ("Pathology & Clinical Lab", ["Biochemistry", "Haematology", "Microbiology"], ["Complete Blood Count", "Electrolytes", "Cross-Match"], "24 Hours" if has_em else "08:00 - 18:00", 1 if has_em else 0),
            ]
            if has_icu:
                standard_depts.append(("Intensive Care Unit", ["Critical Care Medicine", "Pulmonology"], ["Mechanical Ventilation", "Continuous Monitoring"], "24 Hours", 1))

            for dname, dspecs, dservs, dhours, dem in standard_depts:
                cur.execute(
                    """
                    INSERT INTO facility_departments (
                        department_id, facility_id, department_name, specialties_json,
                        services_json, operational_days, operating_hours, appointment_mode,
                        emergency_available, head_of_department, is_operational, last_updated_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        f"dept_{fid}_{dname.lower().replace(' ', '_')[:12]}",
                        fid,
                        dname,
                        json.dumps(dspecs),
                        json.dumps(dservs),
                        "Mon-Sun",
                        dhours,
                        "Walk-in & Appointment",
                        dem,
                        f"HOD {dname} ({fname[:20]})",
                        1,
                        now_str,
                    ),
                )

        # 5. Staff Affiliations
        staff_count = cur.execute("SELECT COUNT(*) FROM facility_staff_affiliations WHERE facility_id = ?", (fid,)).fetchone()[0]
        if staff_count == 0:
            staff_presets = [
                ("Duty Emergency Officer", "doctor", "Emergency Department", "Consultant Emergency Physician", "Emergency Medicine", ["MBBS", "MD Emergency Medicine"], "24/7 Rotational", 1),
                ("Sister In-Charge", "nurse", "Critical Care / Wards", "Senior Nursing Supervisor Grade I", "Critical Care Nursing", ["B.Sc Nursing", "Critical Care Fellowship"], "Day/Night Shifts", 1),
                ("Chief Imaging Technologist", "radiographer", "Radiology & Imaging", "Senior Radiographer", "Medical Imaging", ["B.Sc Radiography"], "Rotational & On-Call", 1 if has_em else 0),
                ("Medical Laboratory Technologist", "lab_technician", "Pathology & Clinical Lab", "Chief Technical Officer (Lab)", "Pathology & Biochemistry", ["M.Sc Medical Lab Technology"], "Day & On-Call", 1 if has_em else 0),
            ]
            for sname, srole, sdept, sdesig, sspec, squal, stime, sem in staff_presets:
                cur.execute(
                    """
                    INSERT INTO facility_staff_affiliations (
                        affiliation_id, facility_id, staff_name, staff_role,
                        department, designation, primary_specialty, qualifications_json,
                        capabilities_json, working_days, shift_timing, emergency_duty_participating,
                        is_currently_practising, verification_status, is_active, created_at, updated_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        f"aff_{fid}_{srole[:4]}_{uuid.uuid4().hex[:6]}",
                        fid,
                        f"{sname} ({fname[:20]})",
                        srole,
                        sdept,
                        sdesig,
                        sspec,
                        json.dumps(squal),
                        json.dumps(["ACLS Certified", "Clinical Triage"]),
                        "Mon-Sun (Rotational)",
                        stime,
                        sem,
                        1,
                        "verified",
                        1,
                        now_str,
                        now_str,
                    ),
                )

        # 6. Detailed 7-Category Equipment & Technology Inventory
        inv_count = cur.execute("SELECT COUNT(*) FROM facility_resource_inventory WHERE facility_id = ?", (fid,)).fetchone()[0]
        if inv_count < 8:
            equipment_defs = [
                # 1. Diagnostic and Imaging
                ("12-Lead Digital ECG Machine", "diagnostic_and_imaging", "GE Healthcare MAC 2000", 2, 2, 0, "Emergency & Cardiology OPD", "in_house_owned", "in_house", 0, "24/7", "Trained Clinical Staff", "verified"),
                ("Color Doppler Ultrasound Scanner", "diagnostic_and_imaging", "Philips Affiniti 70 Ultrasound", 1, 1, 0, "Radiology Suite Room 4", "in_house_owned", "in_house", 0, "Daytime & On-Call", "requires_radiologist", "verified"),
                ("Digital Radiography (DR) X-Ray 500mA", "diagnostic_and_imaging", "Siemens Multix Impact 500mA", 1, 1, 0, "Central Radiology Ground Floor", "in_house_owned", "in_house", 0, "24/7", "technician_operated", "verified"),
                # 2. Critical Care and Life Support
                ("BiPAP / CPAP Non-Invasive Ventilator", "critical_care_and_life_support", "ResMed Stellar 150 System", 2, 2, 0, "HDU & Emergency Ward", "in_house_owned", "in_house", 0, "24/7", "Trained Clinical Staff", "verified"),
                ("Biphasic Defibrillator with Pacer", "critical_care_and_life_support", "Zoll R Series Plus Defibrillator", 2, 2, 0, "Resuscitation Bay & ICU", "in_house_owned", "in_house", 0, "24/7", "Trained Clinical Staff", "verified"),
                ("Multiparameter Patient Vital Signs Monitor", "critical_care_and_life_support", "Mindray BeneVision N12 (5-Lead/SpO2/NIBP/Temp)", 4, 4, 0, "Emergency Resuscitation & ICU", "in_house_owned", "in_house", 0, "24/7", "nurse_operated", "verified"),
                # 3. Surgical and Theatre
                ("Double-Door High-Pressure Steam Autoclave", "surgical_and_theatre", "Tuttnauer 5075ELV Pre/Post Vacuum", 1, 1, 0, "Central Sterile Services Dept (CSSD)", "in_house_owned", "in_house", 0, "24/7", "technician_operated", "verified"),
                ("High-Frequency Electrosurgical Unit (Cautery)", "surgical_and_theatre", "Medtronic Covidien Force FX-C", 1, 1, 0, "Operation Theatre 1", "in_house_owned", "in_house", 0, "Scheduled & Emergency", "requires_anaesthetist", "verified"),
                # 4. Emergency and Trauma
                ("Level-1/2 Trauma Resuscitation Bays", "emergency_and_trauma", "Indore District Standardized Resuscitation Suite", 2, 2, 0, "Emergency Department Bay 1 & 2", "in_house_owned", "in_house", 0, "24/7", "Trained Clinical Staff", "verified"),
                ("Rigid Spine Board & Cervical Collar Kit", "emergency_and_trauma", "Ferno Millennia Immobilization Kit", 3, 3, 0, "Ambulance Receiving Bay", "in_house_owned", "in_house", 0, "24/7", "Trained Clinical Staff", "verified"),
                # 5. Laboratory and Pathology
                ("Automated 5-Part Haematology Analyzer", "laboratory_and_pathology", "Sysmex XN-350 Automated Blood Counter", 1, 1, 0, "Central Pathology Lab", "in_house_owned", "in_house", 0, "24/7", "technician_operated", "verified"),
                ("Fully Automated Biochemistry Analyzer", "laboratory_and_pathology", "Roche Cobas c311 Chemistry System", 1, 1, 0, "Biochemistry Division", "in_house_owned", "in_house", 0, "24/7", "technician_operated", "verified"),
                ("Point-of-Care Rapid Cardiac Biomarker Kit", "laboratory_and_pathology", "Abbott i-STAT 1 System (Troponin I / CK-MB)", 1, 1, 0, "Emergency Triage Station", "in_house_owned", "in_house", 0, "24/7", "nurse_operated", "verified"),
                # 6. Specialized Treatment
                ("Infant Radiant Warmer with Phototherapy", "specialized_treatment", "Phoenix Medical NWS 101 Infant System", 2, 2, 0, "Labour Room & Neonatal Bay", "in_house_owned", "in_house", 0, "24/7", "nurse_operated", "verified"),
                # 7. Telemedicine and Digital Health
                ("Tele-ICU Video Consultation Command Console", "telemedicine_and_digital_health", "Philips eICU Video Gateway Terminal", 1, 1, 0, "Telemedicine Hub", "in_house_owned", "in_house", 0, "24/7", "Trained Clinical Staff", "verified"),
                ("FHIR EMR & Central Referral Link Station", "telemedicine_and_digital_health", "MEDICO Smart Referral Terminal v2.4", 2, 2, 0, "Administrative Desk & Triage", "in_house_owned", "in_house", 0, "24/7", "Trained Clinical Staff", "verified"),
            ]

            if has_icu or is_tertiary:
                equipment_defs.extend([
                    ("ICU Advanced Mechanical Ventilator", "critical_care_and_life_support", "Hamilton-C3 Intensive Care Ventilator", 4, 3, 1, "ICU Bed 1-4", "in_house_owned", "in_house", 0, "24/7", "requires_anaesthetist", "verified"),
                    ("Arterial Blood Gas (ABG) & Electrolyte Analyzer", "critical_care_and_life_support", "Radiometer ABL90 FLEX PLUS", 1, 1, 0, "ICU Point-of-Care Lab", "in_house_owned", "in_house", 0, "24/7", "technician_operated", "verified"),
                    ("Anaesthesia Workstation with Multi-Gas Monitor", "surgical_and_theatre", "Dräger Fabius GS Premium Suite", 2, 2, 0, "Major Operation Theatres", "in_house_owned", "in_house", 0, "24/7", "requires_anaesthetist", "verified"),
                    ("High-Definition Laparoscopy Tower", "surgical_and_theatre", "Karl Storz Image1 S 4K System", 1, 1, 0, "Minimally Invasive OT", "in_house_owned", "in_house", 0, "Scheduled & Emergency", "requires_anaesthetist", "verified"),
                ])

            if is_tertiary:
                equipment_defs.extend([
                    ("16-Slice Spiral CT Scanner", "diagnostic_and_imaging", "Siemens Somatom go.Now 16-Slice", 1, 1, 0, "Emergency CT Suite Ground Floor", "in_house_owned", "in_house", 0, "24/7", "requires_radiologist", "verified"),
                    ("Hemodialysis Machine with Online HDF", "specialized_treatment", "Fresenius 5008S CorDiax Hemodialysis", 6, 6, 0, "Dialysis Unit 2nd Floor", "in_house_owned", "in_house", 0, "24/7", "technician_operated", "verified"),
                    ("Flat-Panel Digital Cardiac Cath Lab", "specialized_treatment", "Philips Azurion 7 Biplane Angiography", 1, 1, 0, "Cardiac Intervention Center", "in_house_owned", "in_house", 0, "24/7", "requires_radiologist", "verified"),
                ])

            for eq_name, cat, model, q_inst, q_oper, q_out, loc, own, deliv, tat, sched, op_req, ver_stat in equipment_defs:
                res_id = f"res_{fid}_{cat[:4]}_{uuid.uuid4().hex[:6]}"
                cur.execute(
                    """
                    INSERT INTO facility_resource_inventory (
                        facility_id, resource_id, resource_type, resource_category, resource_name,
                        model_spec, quantity_installed, quantity_operational, quantity_out_of_service,
                        operational_status, location_in_facility, ownership_type, service_delivery,
                        turnaround_time_hours, availability_schedule, last_maintenance_date,
                        next_maintenance_date, operator_requirements, verification_status,
                        verified_by, evidence_document_name, notes, record_source,
                        is_present, last_verified_at, created_at, updated_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        fid,
                        res_id,
                        "equipment",
                        cat,
                        eq_name,
                        model,
                        q_inst,
                        q_oper,
                        q_out,
                        "operational",
                        loc,
                        own,
                        deliv,
                        tat,
                        sched,
                        "2026-08-01",
                        "2027-02-01",
                        op_req,
                        ver_stat,
                        "NABH Lead Auditor",
                        f"CERT_{cat[:3].upper()}_2026.pdf",
                        "Fully calibrated and certified under active Annual Maintenance Contract (AMC).",
                        "State Healthcare Infrastructure Survey",
                        1,
                        now_str,
                        now_str,
                        now_str,
                    ),
                )

    print("[CentralDB] Successfully seeded extended infrastructure, capacity, departments, staff, and equipment for all 45 facilities.")


def _seed_synthetic_doctors(conn):
    try:
        from synthetic_doctors_dataset import SYNTHETIC_DOCTORS, calculate_synthetic_doctor_score
    except ImportError:
        import sys
        sys.path.insert(0, DB_DIR)
        from synthetic_doctors_dataset import SYNTHETIC_DOCTORS, calculate_synthetic_doctor_score

    cur = conn.cursor()
    cur.execute("SELECT COUNT(*) FROM synthetic_doctor_seed_metadata WHERE is_active = 1")
    if cur.fetchone()[0] == 0:
        now_str = datetime.now(timezone.utc).isoformat()
        total_seeded = 0
        for doc in SYNTHETIC_DOCTORS:
            doc_id = doc["doctor_id"]
            scores = calculate_synthetic_doctor_score(doc)

            existing = conn.execute("SELECT doctor_id FROM doctor_profiles WHERE doctor_id = ?", (doc_id,)).fetchone()
            if not existing:
                conn.execute(
                    """
                    INSERT INTO doctor_profiles (
                        doctor_id, full_name, display_name, email, phone_number,
                        preferred_language, primary_practice_environment, total_experience_years,
                        current_designation, department, years_at_current_facility,
                        is_synthetic, record_source, verification_status,
                        primary_specialty, secondary_specialties,
                        clinical_capabilities, procedure_capabilities, emergency_capabilities,
                        critical_care_capabilities, diagnostic_capabilities,
                        normalized_capability_score, score_breakdown, score_last_calculated_at,
                        created_at, updated_at
                    ) VALUES (
                        ?, ?, ?, ?, ?,
                        'English', ?, ?,
                        ?, ?, ?,
                        1, 'synthetic_demo', 'unverified_demo',
                        ?, ?,
                        ?, ?, ?,
                        ?, ?,
                        ?, ?, ?,
                        ?, ?
                    )
                    """,
                    (
                        doc_id,
                        doc.get("full_name") or doc.get("display_name"),
                        doc.get("display_name"),
                        doc.get("email"),
                        doc.get("phone_number"),
                        doc.get("practice_environment", "tertiary_hospital"),
                        doc.get("years_of_experience", 5),
                        "Senior Consultant" if doc.get("years_of_experience", 5) > 10 else "Consultant",
                        doc.get("primary_specialty"),
                        min(5, doc.get("years_of_experience", 5)),
                        doc.get("primary_specialty"),
                        json.dumps(doc.get("secondary_specialties", [])),
                        json.dumps(doc.get("clinical_capabilities", [])),
                        json.dumps(doc.get("procedure_capabilities", [])),
                        json.dumps(doc.get("emergency_capabilities", [])),
                        json.dumps(doc.get("critical_care_capabilities", [])),
                        json.dumps(doc.get("diagnostic_capabilities", [])),
                        scores["totalCapabilityScore"],
                        json.dumps(scores),
                        scores["calculatedAt"],
                        now_str,
                        now_str,
                    ),
                )

                for q in doc.get("qualifications", []):
                    conn.execute(
                        """
                        INSERT INTO doctor_qualifications (
                            doctor_id, qualification_type, qualification_name, institution,
                            completion_year, primary_specialty, is_verified, created_at
                        ) VALUES (?, ?, ?, ?, ?, ?, 0, ?)
                        """,
                        (
                            doc_id,
                            q.get("cadre", "primary_mbbs"),
                            q.get("title", "MBBS"),
                            q.get("institution", "Medical College"),
                            q.get("year", 2015),
                            doc.get("primary_specialty", "General Medicine"),
                            now_str,
                        ),
                    )

                conn.execute(
                    """
                    INSERT OR IGNORE INTO doctor_registrations (
                        doctor_id, council_name, registration_number, registration_year,
                        registration_status, is_verified, created_at
                    ) VALUES (?, 'Madhya Pradesh Medical Council', ?, ?, 'active', 0, ?)
                    """,
                    (doc_id, f"SYNTH-{doc_id.upper()}", 2015, now_str),
                )

                for fid in doc.get("facility_affiliation_ids", []):
                    fac_row = conn.execute("SELECT name FROM healthcare_facilities WHERE facility_id = ?", (fid,)).fetchone()
                    fname = fac_row["name"] if fac_row else "Healthcare Facility"
                    conn.execute(
                        """
                        INSERT INTO doctor_facility_affiliations (
                            doctor_id, facility_id, facility_name, designation, years_at_facility, is_primary, created_at
                        ) VALUES (?, ?, ?, 'Consultant', 3, 1, ?)
                        """,
                        (doc_id, fid, fname, now_str),
                    )

                for c in doc.get("clinical_capabilities", []):
                    conn.execute(
                        """
                        INSERT INTO doctor_capabilities (doctor_id, capability_key, capability_label, is_claimed, is_verified, created_at)
                        VALUES (?, ?, ?, 1, 0, ?)
                        """,
                        (doc_id, c.lower().replace(" ", "_"), c, now_str),
                    )

                conn.execute(
                    """
                    INSERT OR REPLACE INTO doctor_capability_scores (
                        doctor_id, base_expertise_score, clinical_experience_score,
                        clinical_volume_score, professional_standing_score, total_capability_score,
                        is_provisional, scoring_version, calculated_at
                    ) VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?)
                    """,
                    (
                        doc_id,
                        scores["baseExpertiseScore"],
                        scores["clinicalExperienceScore"],
                        scores["clinicalVolumeScore"],
                        scores["professionalStandingScore"],
                        scores["totalCapabilityScore"],
                        scores["scoringVersion"],
                        scores["calculatedAt"],
                    ),
                )

                for fid in doc.get("facility_affiliation_ids", []):
                    conn.execute(
                        """
                        INSERT INTO doctor_availability_records (
                            doctor_id, facility_id, is_on_duty, duty_shift, status, reported_at
                        ) VALUES (?, ?, 1, ?, ?, ?)
                        """,
                        (doc_id, fid, doc.get("duty_shift", "day"), doc.get("availability_status", "available"), now_str),
                    )

                total_seeded += 1

        conn.execute(
            """
            INSERT OR REPLACE INTO synthetic_doctor_seed_metadata (seed_id, seed_timestamp, total_synthetic_doctors, is_active)
            VALUES ('default_synthetic_seed', ?, ?, 1)
            """,
            (now_str, total_seeded),
        )
        print(f"[CentralDB] Seeded {total_seeded} synthetic Indian doctors linked to facilities.")


# -----------------------------------------------------------------------------
# Query & Read Operations
# -----------------------------------------------------------------------------


def get_all_facilities(since_revision=0, query=None, specialty=None, tag=None, emergency_only=False, limit=100, offset=0):
    conn = get_db_connection()
    sql = """
        SELECT f.*, 
               o.operating_status AS live_operating_status,
               o.general_beds_available AS live_beds,
               o.icu_beds_available AS live_icu_beds,
               o.ambulance_available AS live_ambulance,
               o.current_capacity AS live_capacity,
               o.emergency_department_open AS live_emergency_open,
               o.last_reported_at AS operational_last_reported_at,
               o.freshness_ttl_seconds
        FROM healthcare_facilities f
        LEFT JOIN facility_operational_status o ON f.facility_id = o.facility_id
        WHERE f.revision > ?
    """
    params = [since_revision]

    if query:
        sql += " AND (f.name LIKE ? OR f.address LIKE ?)"
        q_term = f"%{query}%"
        params.extend([q_term, q_term])

    if emergency_only:
        sql += " AND f.emergency_care = 1"

    sql += " ORDER BY f.revision ASC, f.name ASC LIMIT ? OFFSET ?"
    params.extend([limit, offset])

    rows = conn.execute(sql, params).fetchall()
    facilities = []

    for r in rows:
        fac = _row_to_facility_dict(conn, r)
        if specialty and specialty.lower() not in [s.lower() for s in fac["specialties"]]:
            continue
        if tag and tag.lower() not in [t.lower() for t in fac["tags"]]:
            continue
        facilities.append(fac)

    conn.close()
    return facilities


def get_facility_by_id(facility_id):
    conn = get_db_connection()
    row = conn.execute(
        """
        SELECT f.*, 
               o.operating_status AS live_operating_status,
               o.general_beds_available AS live_beds,
               o.icu_beds_available AS live_icu_beds,
               o.ambulance_available AS live_ambulance,
               o.current_capacity AS live_capacity,
               o.emergency_department_open AS live_emergency_open,
               o.last_reported_at AS operational_last_reported_at,
               o.freshness_ttl_seconds
        FROM healthcare_facilities f
        LEFT JOIN facility_operational_status o ON f.facility_id = o.facility_id
        WHERE f.facility_id = ?
        """,
        (facility_id,),
    ).fetchone()

    if not row:
        conn.close()
        return None

    fac = _row_to_facility_dict(conn, row)
    conn.close()
    return fac


def _row_to_facility_dict(conn, r):
    fac_id = r["facility_id"]
    # Services / Specialties
    services = [
        s["service_name"]
        for s in conn.execute(
            "SELECT service_name FROM facility_services WHERE facility_id = ? AND is_active = 1",
            (fac_id,),
        ).fetchall()
    ]
    # Capabilities & Diagnostics
    caps = conn.execute(
        "SELECT capability_name, capability_type FROM facility_capabilities WHERE facility_id = ? AND is_available = 1",
        (fac_id,),
    ).fetchall()
    treatments = [c["capability_name"] for c in caps if c["capability_type"] == "treatment"]
    diagnostics = [c["capability_name"] for c in caps if c["capability_type"] == "diagnostic"]

    # Freshness calculation
    now = datetime.now(timezone.utc)
    is_outdated = False
    reported_at_str = r["operational_last_reported_at"]
    ttl = r["freshness_ttl_seconds"] or 1800
    if reported_at_str:
        try:
            reported_at = datetime.fromisoformat(reported_at_str.replace("Z", "+00:00"))
            age_seconds = (now - reported_at).total_seconds()
            if age_seconds > ttl:
                is_outdated = True
        except Exception:
            is_outdated = False

    tags = []
    try:
        tags = json.loads(r["tags"])
    except Exception:
        tags = []

    return {
        "hospitalId": fac_id,
        "name": r["name"],
        "address": r["address"],
        "latitude": r["latitude"],
        "longitude": r["longitude"],
        "facilityType": r["facility_type"],
        "emergencyCare": bool(r["emergency_care"]),
        "icuAvailable": bool(r["icu_available"]),
        "currentCapacity": r["live_capacity"] if r["live_capacity"] is not None else r["current_capacity"],
        "bedAvailability": r["live_beds"] if r["live_beds"] is not None else r["bed_availability"],
        "operatingStatus": r["live_operating_status"] or r["operating_status"],
        "tags": tags,
        "specialties": services,
        "treatmentCapabilities": treatments,
        "diagnosticFacilities": diagnostics,
        "isVerified": bool(r["is_verified"]),
        "verificationTier": r["verification_tier"],
        "isSimulatedData": bool(r["is_simulated_data"]),
        "dataSource": r["data_source"],
        "revision": r["revision"],
        "updatedAt": r["updated_at"],
        "operationalStatus": {
            "operatingStatus": r["live_operating_status"] or r["operating_status"],
            "generalBedsAvailable": r["live_beds"] if r["live_beds"] is not None else r["bed_availability"],
            "icuBedsAvailable": r["live_icu_beds"] or 0,
            "ambulanceAvailable": bool(r["live_ambulance"]) if r["live_ambulance"] is not None else True,
            "emergencyDepartmentOpen": bool(r["live_emergency_open"]) if r["live_emergency_open"] is not None else bool(r["emergency_care"]),
            "currentCapacity": r["live_capacity"] if r["live_capacity"] is not None else r["current_capacity"],
            "lastReportedAt": r["operational_last_reported_at"] or r["updated_at"],
            "freshnessTtlSeconds": ttl,
            "isOutdated": is_outdated,
        },
    }


# -----------------------------------------------------------------------------
# Write, Sync & Conflict Operations
# -----------------------------------------------------------------------------


def update_operational_status(facility_id, status_data, actor_id="unknown", actor_role="clinician"):
    conn = get_db_connection()
    now_str = datetime.now(timezone.utc).isoformat()

    # Verify facility exists
    fac = conn.execute("SELECT revision FROM healthcare_facilities WHERE facility_id = ?", (facility_id,)).fetchone()
    if not fac:
        conn.close()
        return None, "Facility not found"

    new_rev = fac["revision"] + 1

    conn.execute(
        """
        UPDATE healthcare_facilities
        SET revision = ?, updated_at = ?,
            operating_status = COALESCE(?, operating_status),
            bed_availability = COALESCE(?, bed_availability),
            current_capacity = COALESCE(?, current_capacity)
        WHERE facility_id = ?
        """,
        (
            new_rev,
            now_str,
            status_data.get("operatingStatus"),
            status_data.get("generalBedsAvailable"),
            status_data.get("currentCapacity"),
            facility_id,
        ),
    )

    conn.execute(
        """
        INSERT OR REPLACE INTO facility_operational_status
        (facility_id, operating_status, general_beds_available, icu_beds_available, 
         operating_theaters_available, ambulance_available, current_capacity, 
         emergency_department_open, last_reported_at, reported_by_user, freshness_ttl_seconds, is_verified_live, revision)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?)
        """,
        (
            facility_id,
            status_data.get("operatingStatus", "Operational"),
            status_data.get("generalBedsAvailable", 0),
            status_data.get("icuBedsAvailable", 0),
            status_data.get("operatingTheatersAvailable", 0),
            1 if status_data.get("ambulanceAvailable", True) else 0,
            status_data.get("currentCapacity", 0.7),
            1 if status_data.get("emergencyDepartmentOpen", True) else 0,
            now_str,
            actor_id,
            status_data.get("freshnessTtlSeconds", 1800),
            new_rev,
        ),
    )

    # Log audit record
    conn.execute(
        """
        INSERT INTO audit_logs (facility_id, action, actor_id, actor_role, changes_json, timestamp)
        VALUES (?, 'UPDATE_OPERATIONAL_STATUS', ?, ?, ?, ?)
        """,
        (facility_id, actor_id, actor_role, json.dumps(status_data), now_str),
    )

    conn.commit()
    conn.close()
    return get_facility_by_id(facility_id), None


def sync_pull(since_revision=0, limit=200):
    """Returns incremental changes since client's last known revision."""
    conn = get_db_connection()
    # Get highest current server revision
    max_rev_row = conn.execute("SELECT MAX(revision) as max_rev FROM healthcare_facilities").fetchone()
    current_server_revision = max_rev_row["max_rev"] or 0

    facilities = get_all_facilities(since_revision=since_revision, limit=limit)
    conn.close()

    return {
        "serverRevision": current_server_revision,
        "sinceRevision": since_revision,
        "count": len(facilities),
        "hasMore": len(facilities) == limit,
        "facilities": facilities,
        "syncTimestamp": datetime.now(timezone.utc).isoformat(),
    }


def sync_push(client_id, changes, idempotency_key=None, actor_id="clinician", actor_role="clinician"):
    """
    Processes batch changes uploaded by a client device.
    Supports idempotency keys, checks revision conflicts, and logs audit entries.
    """
    conn = get_db_connection()

    # Check idempotency
    if idempotency_key:
        cached = conn.execute("SELECT response_json FROM idempotency_keys WHERE key = ?", (idempotency_key,)).fetchone()
        if cached:
            conn.close()
            return json.loads(cached["response_json"]), None

    results = []
    conflicts = []

    for change in changes:
        fac_id = change.get("facilityId")
        op = change.get("operation", "UPDATE_STATUS")
        client_rev = change.get("clientRevision", 0)
        payload = change.get("payload", {})

        cur_fac = conn.execute("SELECT revision FROM healthcare_facilities WHERE facility_id = ?", (fac_id,)).fetchone()
        if not cur_fac:
            conflicts.append({
                "facilityId": fac_id,
                "error": "Facility not found on server",
                "clientRevision": client_rev,
            })
            continue

        server_rev = cur_fac["revision"]

        # Conflict Detection: If server revision is strictly ahead of client base revision
        # and non-idempotent field modified
        if client_rev > 0 and server_rev > client_rev:
            conflicts.append({
                "facilityId": fac_id,
                "error": "Revision conflict: server has newer authoritative updates",
                "serverRevision": server_rev,
                "clientRevision": client_rev,
                "resolution": "server_wins_stale_discarded",
            })
            continue

        if op == "UPDATE_STATUS":
            updated_fac, err = update_operational_status(fac_id, payload, actor_id=actor_id, actor_role=actor_role)
            if err:
                conflicts.append({"facilityId": fac_id, "error": err})
            else:
                results.append({"facilityId": fac_id, "status": "applied", "newRevision": updated_fac["revision"]})

    max_rev_row = conn.execute("SELECT MAX(revision) as max_rev FROM healthcare_facilities").fetchone()
    latest_server_revision = max_rev_row["max_rev"] or 0

    response_data = {
        "status": "success",
        "clientId": client_id,
        "processedCount": len(results),
        "conflicts": conflicts,
        "results": results,
        "serverRevision": latest_server_revision,
        "syncTimestamp": datetime.now(timezone.utc).isoformat(),
    }

    if idempotency_key:
        conn.execute(
            "INSERT OR REPLACE INTO idempotency_keys (key, response_json) VALUES (?, ?)",
            (idempotency_key, json.dumps(response_data)),
        )
        conn.commit()

    conn.close()
    return response_data, None


def get_audit_logs(limit=50):
    conn = get_db_connection()
    rows = conn.execute(
        "SELECT * FROM audit_logs ORDER BY log_id DESC LIMIT ?",
        (limit,),
    ).fetchall()
    logs = [dict(r) for r in rows]
    conn.close()
    return logs


# ============================================================================
# DOCTOR REGISTRATION, CAPABILITY SCORING, AND CREDENTIALING LOGIC
# ============================================================================

def calculate_doctor_capability_score(data):
    """
    4-Pillar Fair Normalized Capability Score Algorithm:
    - Base Expertise: Max 30%
    - Clinical Experience: Max 30%
    - Clinical Volume and Impact: Max 25% (normalized fairly for clinic vs hospital)
    - Professional Standing: Max 15%
    """
    # 1. Base Expertise (Max 30)
    qual_type = str(data.get("primaryQualificationType") or "primary_mbbs").lower()
    base_expertise = 15.0  # Baseline MBBS
    if any(k in qual_type for k in ["super_specialty", "dm", "mch", "fellowship"]):
        base_expertise = 30.0
    elif any(k in qual_type for k in ["postgraduate", "md", "ms", "dnb"]):
        base_expertise = 25.0
    elif "mbbs" in qual_type:
        base_expertise = 15.0

    # 2. Clinical Experience (Max 30)
    years = float(data.get("totalExperienceYears") or 0)
    experience_score = min(30.0, years * 1.5)

    # 3. Clinical Volume and Impact (Max 25)
    practice_env = str(data.get("primaryPracticeEnvironment") or "").lower()
    annual_volume = float(data.get("annualPatientVolume") or 0)
    is_hospital = any(h in practice_env for h in ["hospital", "tertiary", "medical_college"])

    if is_hospital:
        # Hospital caseload normalization
        if annual_volume >= 3000:
            volume_score = 25.0
        elif annual_volume >= 1500:
            volume_score = 20.0
        elif annual_volume >= 500:
            volume_score = 15.0
        else:
            volume_score = min(25.0, 10.0 + (years * 0.5))
    else:
        # Clinic / Primary Care normalization (continuity, chronic disease, community)
        if annual_volume >= 2000:
            volume_score = 25.0
        elif annual_volume >= 1000:
            volume_score = 20.0
        else:
            volume_score = min(25.0, 12.0 + (years * 0.6))

    # 4. Professional Standing (Max 15)
    standing_score = 0.0
    associations = data.get("associationMemberships") or []
    if isinstance(associations, str):
        try:
            associations = json.loads(associations)
        except Exception:
            associations = [associations] if associations else []
    if associations:
        standing_score += min(10.0, len(associations) * 5.0)

    if data.get("governmentSchemesSummary"):
        standing_score += 5.0
    if data.get("teachingResearchSummary"):
        standing_score += 5.0
    standing_score = min(15.0, standing_score)

    total_score = round(base_expertise + experience_score + volume_score + standing_score, 1)
    total_score = min(100.0, max(0.0, total_score))

    return {
        "baseExpertiseScore": round(base_expertise, 1),
        "clinicalExperienceScore": round(experience_score, 1),
        "clinicalVolumeScore": round(volume_score, 1),
        "professionalStandingScore": round(standing_score, 1),
        "totalCapabilityScore": total_score,
        "isProvisional": True,
    }


def register_doctor(data, actor_id="registration_portal"):
    """
    Registers a new doctor profile with validations, duplicate prevention,
    and calculates provisional capability score. Never marks as verified on registration.
    """
    # 1. Validation of Required Fields
    required_fields = [
        ("fullName", "Full Legal Name"),
        ("email", "Email Address"),
        ("phoneNumber", "Mobile Number"),
        ("medicalRegNumber", "Medical Registration Number"),
        ("councilName", "Registering Medical Council"),
        ("primaryQualificationName", "Primary Medical Qualification"),
        ("primarySpecialty", "Primary Specialty"),
        ("primaryPracticeEnvironment", "Primary Practice Environment"),
    ]
    for key, label in required_fields:
        if not data.get(key) or not str(data.get(key)).strip():
            return None, f"Required field missing: {label}"

    email = str(data["email"]).strip().lower()
    phone = str(data["phoneNumber"]).strip()
    reg_num = str(data["medicalRegNumber"]).strip().upper()

    conn = get_db_connection()

    # 2. Duplicate Detection
    if conn.execute("SELECT 1 FROM doctor_profiles WHERE email = ?", (email,)).fetchone():
        conn.close()
        return None, f"Email '{email}' is already registered with another doctor account."

    if conn.execute("SELECT 1 FROM doctor_profiles WHERE phone_number = ?", (phone,)).fetchone():
        conn.close()
        return None, f"Mobile number '{phone}' is already registered with another doctor account."

    if conn.execute("SELECT 1 FROM doctor_registrations WHERE registration_number = ?", (reg_num,)).fetchone():
        conn.close()
        return None, f"Medical registration number '{reg_num}' is already registered."

    import uuid
    doctor_id = f"doc_{int(datetime.now(timezone.utc).timestamp())}_{uuid.uuid4().hex[:6]}"
    now_iso = datetime.now(timezone.utc).isoformat()

    try:
        # 3. Insert Doctor Profile (Pending verification)
        conn.execute(
            """
            INSERT INTO doctor_profiles (
                doctor_id, user_id, full_name, display_name, email, phone_number,
                preferred_language, profile_photo_url, primary_practice_environment,
                total_experience_years, current_designation, department,
                years_at_current_facility, years_independent_practice,
                previous_affiliations, annual_patient_volume,
                followup_experience_summary, procedure_experience_summary,
                teaching_research_summary, association_memberships,
                government_schemes_summary, verification_status, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', ?, ?)
            """,
            (
                doctor_id,
                data.get("userId") or doctor_id,
                data["fullName"].strip(),
                data.get("displayName") or data["fullName"].strip(),
                email,
                phone,
                data.get("preferredLanguage") or "English",
                data.get("profilePhotoUrl"),
                data["primaryPracticeEnvironment"],
                int(data.get("totalExperienceYears") or 0),
                data.get("currentDesignation") or "Consultant",
                data.get("department") or data["primarySpecialty"],
                int(data.get("yearsAtCurrentFacility") or 0),
                int(data.get("yearsIndependentPractice") or 0),
                json.dumps(data.get("previousAffiliations") or []),
                int(data.get("annualPatientVolume") or 0),
                data.get("followupExperienceSummary"),
                data.get("procedureExperienceSummary"),
                data.get("teachingResearchSummary"),
                json.dumps(data.get("associationMemberships") or []),
                data.get("governmentSchemesSummary"),
                now_iso,
                now_iso,
            ),
        )

        # 4. Insert Primary Qualification
        add_specs = data.get("additionalSpecialties") or []
        certs = data.get("certifications") or []
        conn.execute(
            """
            INSERT INTO doctor_qualifications (
                doctor_id, qualification_type, qualification_name, institution,
                completion_year, primary_specialty, additional_specialties,
                certifications, is_verified, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, ?)
            """,
            (
                doctor_id,
                data.get("primaryQualificationType") or "primary_mbbs",
                data["primaryQualificationName"].strip(),
                data.get("awardingInstitution") or "Recognized Medical University",
                int(data.get("completionYear") or 2018),
                data["primarySpecialty"].strip(),
                json.dumps(add_specs if isinstance(add_specs, list) else [add_specs]),
                json.dumps(certs if isinstance(certs, list) else [certs]),
                now_iso,
            ),
        )

        # 5. Insert Medical Registration
        conn.execute(
            """
            INSERT INTO doctor_registrations (
                doctor_id, council_name, registration_number, registration_year,
                registration_status, is_verified, created_at
            ) VALUES (?, ?, ?, ?, 'active', 0, ?)
            """,
            (
                doctor_id,
                data["councilName"].strip(),
                reg_num,
                int(data.get("registrationYear") or 2018),
                now_iso,
            ),
        )

        # 6. Insert Facility Affiliation (Linked to existing healthcare_facilities)
        facility_id = data.get("facilityId")
        facility_name = data.get("facilityName") or "Independent Medical Center"
        if facility_id:
            fac_row = conn.execute("SELECT name FROM healthcare_facilities WHERE facility_id = ?", (facility_id,)).fetchone()
            if fac_row:
                facility_name = fac_row["name"]

        conn.execute(
            """
            INSERT INTO doctor_facility_affiliations (
                doctor_id, facility_id, facility_name, designation,
                years_at_facility, is_primary, created_at
            ) VALUES (?, ?, ?, ?, ?, 1, ?)
            """,
            (
                doctor_id,
                facility_id or "independent_practice",
                facility_name,
                data.get("currentDesignation") or "Consultant",
                int(data.get("yearsAtCurrentFacility") or 0),
                now_iso,
            ),
        )

        # 7. Insert Clinical Capabilities
        capabilities = data.get("capabilities") or []
        if isinstance(capabilities, list):
            for cap in capabilities:
                cap_key = cap if isinstance(cap, str) else cap.get("key", "")
                cap_label = cap if isinstance(cap, str) else cap.get("label", cap_key)
                conn.execute(
                    """
                    INSERT INTO doctor_capabilities (
                        doctor_id, capability_key, capability_label, is_claimed, is_verified, created_at
                    ) VALUES (?, ?, ?, 1, 0, ?)
                    """,
                    (doctor_id, cap_key, cap_label, now_iso),
                )

        # 8. Insert Evidence Documents
        documents = data.get("documents") or []
        for doc in documents:
            doc_id = doc.get("id") or f"doc_file_{uuid.uuid4().hex[:8]}"
            conn.execute(
                """
                INSERT INTO doctor_evidence_documents (
                    document_id, doctor_id, document_type, file_name, file_size_bytes,
                    mime_type, storage_path, sha256_hash, verification_status, uploaded_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'pending', ?)
                """,
                (
                    doc_id,
                    doctor_id,
                    doc.get("documentType") or "registration_certificate",
                    doc.get("fileName") or "certificate.pdf",
                    int(doc.get("fileSizeBytes") or 1024),
                    doc.get("mimeType") or "application/pdf",
                    doc.get("storagePath") or f"secure_vault/doctors/{doctor_id}/{doc_id}",
                    doc.get("sha256Hash") or uuid.uuid4().hex,
                    now_iso,
                ),
            )

        # 9. Calculate and Insert Fair Normalized Capability Score
        scores = calculate_doctor_capability_score(data)
        conn.execute(
            """
            INSERT INTO doctor_capability_scores (
                doctor_id, base_expertise_score, clinical_experience_score,
                clinical_volume_score, professional_standing_score, total_capability_score,
                is_provisional, scoring_version, calculated_at
            ) VALUES (?, ?, ?, ?, ?, ?, 1, '1.0.0', ?)
            """,
            (
                doctor_id,
                scores["baseExpertiseScore"],
                scores["clinicalExperienceScore"],
                scores["clinicalVolumeScore"],
                scores["professionalStandingScore"],
                scores["totalCapabilityScore"],
                now_iso,
            ),
        )

        # 10. Audit Log
        conn.execute(
            """
            INSERT INTO doctor_audit_logs (doctor_id, action, actor_id, actor_role, details_json, timestamp)
            VALUES (?, 'REGISTER', ?, 'doctor_applicant', ?, ?)
            """,
            (
                doctor_id,
                actor_id,
                json.dumps({"regNumber": reg_num, "email": email, "score": scores["totalCapabilityScore"]}),
                now_iso,
            ),
        )

        conn.commit()

    except Exception as e:
        conn.rollback()
        conn.close()
        return None, f"Database registration failed: {str(e)}"

    conn.close()
    return get_doctor_by_id(doctor_id, is_public=False), None


def get_doctor_by_id(doctor_id, is_public=True):
    """Fetches full doctor profile and sanitizes sensitive data for public queries."""
    conn = get_db_connection()
    doc_row = conn.execute("SELECT * FROM doctor_profiles WHERE doctor_id = ?", (doctor_id,)).fetchone()
    if not doc_row:
        conn.close()
        return None

    doc = dict(doc_row)
    doc_id = doc["doctor_id"]

    # Qualifications
    quals = [dict(r) for r in conn.execute("SELECT * FROM doctor_qualifications WHERE doctor_id = ?", (doc_id,)).fetchall()]
    # Registrations
    reg = conn.execute("SELECT * FROM doctor_registrations WHERE doctor_id = ?", (doc_id,)).fetchone()
    # Affiliations
    affils = [dict(r) for r in conn.execute("SELECT * FROM doctor_facility_affiliations WHERE doctor_id = ?", (doc_id,)).fetchall()]
    # Capabilities
    caps = [dict(r) for r in conn.execute("SELECT * FROM doctor_capabilities WHERE doctor_id = ?", (doc_id,)).fetchall()]
    # Scores
    score_row = conn.execute("SELECT * FROM doctor_capability_scores WHERE doctor_id = ?", (doc_id,)).fetchone()
    # Verification Records
    verif_rows = [dict(r) for r in conn.execute("SELECT * FROM doctor_verification_records WHERE doctor_id = ? ORDER BY record_id DESC", (doc_id,)).fetchall()]

    # Evidence documents (privacy protected)
    docs = []
    if not is_public:
        docs = [dict(r) for r in conn.execute("SELECT document_id, document_type, file_name, file_size_bytes, mime_type, verification_status, uploaded_at FROM doctor_evidence_documents WHERE doctor_id = ?", (doc_id,)).fetchall()]

    conn.close()

    # Parse JSON fields if strings
    for field in ["secondary_specialties", "clinical_capabilities", "procedure_capabilities", "emergency_capabilities", "critical_care_capabilities", "diagnostic_capabilities", "previous_affiliations", "association_memberships"]:
        if isinstance(doc.get(field), str):
            try:
                doc[field] = json.loads(doc[field])
            except Exception:
                pass

    if doc.get("is_synthetic"):
        doc["is_synthetic"] = bool(doc["is_synthetic"])
        doc["isSimulatedDataNotice"] = "SIMULATED DATA — NOT FOR CLINICAL DECISIONS"
        doc["data_notice"] = "SIMULATED DATA — NOT FOR CLINICAL DECISIONS"
    else:
        doc["is_synthetic"] = False
        doc["data_notice"] = None

    # Privacy Protection for Public Views
    if is_public:
        # Mask phone number
        raw_phone = doc.get("phone_number", "")
        if len(raw_phone) >= 10:
            doc["phoneNumber"] = raw_phone[:2] + "******" + raw_phone[-2:]
        else:
            doc["phoneNumber"] = "******"
        # Mask registration cert paths
        doc.pop("rejection_reason", None)
    else:
        doc["phoneNumber"] = doc.get("phone_number")

    doc["qualifications"] = quals
    doc["registration"] = dict(reg) if reg else None
    doc["affiliations"] = affils
    doc["capabilities"] = caps
    doc["capabilityScore"] = dict(score_row) if score_row else None
    doc["verificationHistory"] = verif_rows
    if not is_public:
        doc["documents"] = docs

    return doc


def verify_doctor(doctor_id, decision, reviewer_id, reviewer_role="admin", reason=None, notes=None):
    """
    Authorized verifier review. Doctors CANNOT verify their own accounts.
    Decision: 'approved', 'rejected', 'requested_info'
    """
    if reviewer_role not in ["admin", "district_officer"]:
        return None, "Unauthorized: Only official District Health Officers or System Administrators may verify credentials."

    conn = get_db_connection()
    doc_row = conn.execute("SELECT * FROM doctor_profiles WHERE doctor_id = ?", (doctor_id,)).fetchone()
    if not doc_row:
        conn.close()
        return None, f"Doctor {doctor_id} not found."

    status_map = {
        "approved": "verified",
        "rejected": "rejected",
        "requested_info": "needs_more_info",
    }
    new_status = status_map.get(decision.lower())
    if not new_status:
        conn.close()
        return None, f"Invalid decision '{decision}'. Must be 'approved', 'rejected', or 'requested_info'."

    now_iso = datetime.now(timezone.utc).isoformat()

    conn.execute(
        """
        UPDATE doctor_profiles 
        SET verification_status = ?, rejection_reason = ?, updated_at = ?
        WHERE doctor_id = ?
        """,
        (new_status, reason if new_status != "verified" else None, now_iso, doctor_id),
    )

    if new_status == "verified":
        conn.execute(
            "UPDATE doctor_registrations SET is_verified = 1, verified_at = ?, verified_by = ? WHERE doctor_id = ?",
            (now_iso, reviewer_id, doctor_id),
        )
        conn.execute(
            "UPDATE doctor_qualifications SET is_verified = 1 WHERE doctor_id = ?",
            (doctor_id,),
        )
        conn.execute(
            "UPDATE doctor_capability_scores SET is_provisional = 0 WHERE doctor_id = ?",
            (doctor_id,),
        )

    # Insert Review Record
    conn.execute(
        """
        INSERT INTO doctor_verification_records (doctor_id, reviewer_id, review_decision, rejection_reason, review_notes, reviewed_at)
        VALUES (?, ?, ?, ?, ?, ?)
        """,
        (doctor_id, reviewer_id, decision, reason, notes, now_iso),
    )

    # Audit Log
    conn.execute(
        """
        INSERT INTO doctor_audit_logs (doctor_id, action, actor_id, actor_role, details_json, timestamp)
        VALUES (?, 'VERIFY_DECISION', ?, ?, ?, ?)
        """,
        (doctor_id, reviewer_id, reviewer_role, json.dumps({"decision": decision, "status": new_status, "reason": reason}), now_iso),
    )

    conn.commit()
    conn.close()
    return get_doctor_by_id(doctor_id, is_public=False), None


def list_doctors(status=None, specialty=None, include_synthetic=False, limit=100):
    conn = get_db_connection()
    sql = "SELECT doctor_id FROM doctor_profiles WHERE 1=1"
    params = []
    if status:
        sql += " AND verification_status = ?"
        params.append(status.lower())
    if specialty:
        sql += " AND (primary_specialty LIKE ? OR secondary_specialties LIKE ?)"
        params.append(f"%{specialty}%")
        params.append(f"%{specialty}%")
    if not include_synthetic:
        sql += " AND is_synthetic = 0"
    sql += " ORDER BY created_at DESC LIMIT ?"
    params.append(limit)

    rows = conn.execute(sql, params).fetchall()
    conn.close()
    return [get_doctor_by_id(r["doctor_id"], is_public=True) for r in rows]


def get_all_doctors(include_synthetic=False, limit=500):
    """Fetches all doctors, respecting synthetic data isolation."""
    conn = get_db_connection()
    sql = "SELECT doctor_id FROM doctor_profiles WHERE 1=1"
    params = []
    if not include_synthetic:
        sql += " AND is_synthetic = 0"
    sql += " ORDER BY created_at DESC LIMIT ?"
    params.append(limit)

    rows = conn.execute(sql, params).fetchall()
    conn.close()
    return [get_doctor_by_id(r["doctor_id"], is_public=True) for r in rows]


def get_doctors_by_facility(facility_id, include_synthetic=False):
    """Fetches all doctors affiliated with a specific facility."""
    conn = get_db_connection()
    sql = """
        SELECT DISTINCT d.doctor_id 
        FROM doctor_profiles d
        JOIN doctor_facility_affiliations a ON d.doctor_id = a.doctor_id
        WHERE a.facility_id = ?
    """
    params = [facility_id]
    if not include_synthetic:
        sql += " AND d.is_synthetic = 0"
    sql += " ORDER BY d.full_name ASC"

    rows = conn.execute(sql, params).fetchall()
    conn.close()
    return [get_doctor_by_id(r["doctor_id"], is_public=True) for r in rows]


def get_condition_requirements(condition_key=None):
    """Fetches clinical requirements for conditions."""
    conn = get_db_connection()
    if condition_key:
        row = conn.execute("SELECT * FROM condition_capability_requirements WHERE condition_key = ?", (condition_key,)).fetchone()
        conn.close()
        if not row:
            from condition_capabilities import get_condition_definition
            return get_condition_definition(condition_key)
        res = dict(row)
        for field in ["required_specialties", "essential_doctor_capabilities", "essential_equipment", "supporting_capabilities", "capability_rationales"]:
            if res.get(field) and isinstance(res[field], str):
                try:
                    res[field] = json.loads(res[field])
                except Exception:
                    pass
        return res
    else:
        rows = conn.execute("SELECT * FROM condition_capability_requirements ORDER BY urgency_level ASC").fetchall()
        conn.close()
        res_list = []
        for r in rows:
            d = dict(r)
            for field in ["required_specialties", "essential_doctor_capabilities", "essential_equipment", "supporting_capabilities", "capability_rationales"]:
                if d.get(field) and isinstance(d[field], str):
                    try:
                        d[field] = json.loads(d[field])
                    except Exception:
                        pass
            res_list.append(d)
        return res_list


# ============================================================================
# Emergency Quick Referral System Backend Operations
# ============================================================================

def get_emergency_referral_raw(conn, referral_id):
    """Internal helper to get raw row as dict."""
    row = conn.execute("SELECT * FROM emergency_referrals WHERE referral_id = ?", (referral_id,)).fetchone()
    if not row:
        return None
    d = dict(row)
    if d.get("red_flag_symptoms") and isinstance(d["red_flag_symptoms"], str):
        try:
            d["red_flag_symptoms"] = json.loads(d["red_flag_symptoms"])
        except Exception:
            pass
    return d


def get_emergency_referral(referral_id, conn=None):
    """Fetches full emergency referral with versions, deliveries, dispatch, and audit trail."""
    should_close = False
    if conn is None:
        conn = get_db_connection()
        should_close = True

    try:
        ref = get_emergency_referral_raw(conn, referral_id)
        if not ref:
            return None

        # Fetch versions
        version_rows = conn.execute(
            "SELECT * FROM emergency_referral_versions WHERE referral_id = ? ORDER BY version_number ASC",
            (referral_id,),
        ).fetchall()
        versions = []
        for vr in version_rows:
            vd = dict(vr)
            if vd.get("changed_fields") and isinstance(vd["changed_fields"], str):
                try:
                    vd["changed_fields"] = json.loads(vd["changed_fields"])
                except Exception:
                    pass
            if vd.get("snapshot_data") and isinstance(vd["snapshot_data"], str):
                try:
                    vd["snapshot_data"] = json.loads(vd["snapshot_data"])
                except Exception:
                    pass
            versions.append(vd)
        ref["versions"] = versions

        # Fetch deliveries
        delivery_rows = conn.execute(
            "SELECT * FROM emergency_referral_deliveries WHERE referral_id = ? ORDER BY attempted_at DESC",
            (referral_id,),
        ).fetchall()
        ref["deliveries"] = [dict(dr) for dr in delivery_rows]

        # Fetch acknowledgements
        ack_rows = conn.execute(
            "SELECT * FROM emergency_referral_acknowledgements WHERE referral_id = ? ORDER BY responded_at DESC",
            (referral_id,),
        ).fetchall()
        ref["acknowledgements"] = [dict(ar) for ar in ack_rows]

        # Fetch dispatch records
        dispatch_rows = conn.execute(
            "SELECT * FROM ambulance_dispatch_records WHERE referral_id = ? ORDER BY dispatched_at DESC",
            (referral_id,),
        ).fetchall()
        ref["dispatch_records"] = [dict(dp) for dp in dispatch_rows]

        # Fetch audit logs
        audit_rows = conn.execute(
            "SELECT * FROM emergency_referral_audit_logs WHERE referral_id = ? ORDER BY timestamp DESC",
            (referral_id,),
        ).fetchall()
        ref["audit_logs"] = [dict(al) for al in audit_rows]

        return ref
    finally:
        if should_close:
            conn.close()


def get_all_emergency_referrals(workflow_status=None, limit=100):
    """Lists emergency referrals, optionally filtered by workflow status."""
    conn = get_db_connection()
    if workflow_status:
        rows = conn.execute(
            "SELECT * FROM emergency_referrals WHERE workflow_status = ? ORDER BY created_at DESC LIMIT ?",
            (workflow_status, limit),
        ).fetchall()
    else:
        rows = conn.execute(
            "SELECT * FROM emergency_referrals ORDER BY created_at DESC LIMIT ?",
            (limit,),
        ).fetchall()
    conn.close()

    result = []
    for r in rows:
        d = dict(r)
        if d.get("red_flag_symptoms") and isinstance(d["red_flag_symptoms"], str):
            try:
                d["red_flag_symptoms"] = json.loads(d["red_flag_symptoms"])
            except Exception:
                pass
        result.append(d)
    return result


def create_emergency_referral(data, actor_id="doc_parth", actor_name="Dr. Parth Saxena"):
    """
    Creates an emergency referral record and its baseline version 1.
    Supports minimum essential clinical information.
    """
    import random
    conn = get_db_connection()
    now_str = datetime.now(timezone.utc).isoformat()

    referral_id = data.get("referral_id") or data.get("referralId")
    if not referral_id:
        rnd = random.randint(1000, 9999)
        referral_id = f"EMR-2026-{rnd}"

    patient_id = data.get("patient_identifier") or data.get("patientIdentifier") or f"PAT-EM-{random.randint(100, 999)}"
    presenting_complaint = data.get("presenting_complaint") or data.get("presentingComplaint") or "Emergency acute presentation"
    emergency_category = data.get("emergency_category") or data.get("emergencyCategory") or "GENERAL_EMERGENCY"

    red_flags = data.get("red_flag_symptoms") or data.get("redFlagSymptoms") or []
    red_flags_str = json.dumps(red_flags) if isinstance(red_flags, list) else str(red_flags)

    amb_status = data.get("ambulance_status") or data.get("ambulanceStatus") or "not_dispatched"
    dispatch_time = data.get("ambulance_dispatch_time") or data.get("ambulanceDispatchTime")
    if amb_status != "not_dispatched" and not dispatch_time:
        dispatch_time = now_str

    vehicle_num = data.get("ambulance_vehicle_number") or data.get("ambulanceVehicleNumber")
    service_type = data.get("ambulance_service_type") or data.get("ambulanceServiceType") or "108 EMTS"
    eta_mins = data.get("ambulance_eta_minutes") or data.get("ambulanceEtaMinutes")

    rec_fac_id = data.get("receiving_facility_id") or data.get("receivingFacilityId") or "indore_hospital_001"
    rec_fac_name = data.get("receiving_facility_name") or data.get("receivingFacilityName") or "Indore Apex Tertiary Hospital"
    rec_dept = data.get("receiving_department") or data.get("receivingDepartment") or "Emergency Department"

    intended_doc_id = data.get("intended_doctor_id") or data.get("intendedDoctorId")
    intended_doc_name = data.get("intended_doctor_name") or data.get("intendedDoctorName")
    override_reason = data.get("recommendation_override_reason") or data.get("recommendationOverrideReason")

    ref_clinician_id = data.get("referring_clinician_id") or data.get("referringClinicianId") or actor_id
    ref_clinician_name = data.get("referring_clinician_name") or data.get("referringClinicianName") or actor_name
    ref_fac_name = data.get("referring_facility_name") or data.get("referringFacilityName") or "Primary Health Centre Sector 4"
    ref_callback = data.get("referring_callback_phone") or data.get("referringCallbackPhone") or "+91 98260 12345"

    workflow_status = "in_transit" if amb_status in ["en_route_scene", "patient_loaded_in_transit"] else "emergency_created"

    try:
        conn.execute(
            """
            INSERT INTO emergency_referrals (
                referral_id, patient_identifier, patient_name, patient_age, patient_sex,
                presenting_complaint, emergency_category, red_flag_symptoms, symptom_onset_time,
                vitals_pulse, vitals_bp_systolic, vitals_bp_diastolic, vitals_spo2, vitals_resp_rate, vitals_temp,
                consciousness_level, allergies, medications_history, immediate_treatment_given,
                ambulance_status, ambulance_dispatch_time, ambulance_vehicle_number, ambulance_service_type, ambulance_eta_minutes,
                referring_clinician_id, referring_clinician_name, referring_facility_name, referring_callback_phone,
                receiving_facility_id, receiving_facility_name, receiving_department, intended_doctor_id, intended_doctor_name,
                recommendation_override_reason, clinical_notes, current_version, workflow_status, delivery_status, response_status,
                created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                referral_id, patient_id, data.get("patient_name") or data.get("patientName"),
                data.get("patient_age") or data.get("patientAge"),
                data.get("patient_sex") or data.get("patientSex"),
                presenting_complaint, emergency_category, red_flags_str,
                data.get("symptom_onset_time") or data.get("symptomOnsetTime"),
                data.get("vitals_pulse") or data.get("vitalsPulse"),
                data.get("vitals_bp_systolic") or data.get("vitalsBpSystolic"),
                data.get("vitals_bp_diastolic") or data.get("vitalsBpDiastolic"),
                data.get("vitals_spo2") or data.get("vitalsSpo2"),
                data.get("vitals_resp_rate") or data.get("vitalsRespRate"),
                data.get("vitals_temp") or data.get("vitalsTemp"),
                data.get("consciousness_level") or data.get("consciousnessLevel") or "Alert",
                data.get("allergies"), data.get("medications_history") or data.get("medicationsHistory"),
                data.get("immediate_treatment_given") or data.get("immediateTreatmentGiven"),
                amb_status, dispatch_time, vehicle_num, service_type, eta_mins,
                ref_clinician_id, ref_clinician_name, ref_fac_name, ref_callback,
                rec_fac_id, rec_fac_name, rec_dept, intended_doc_id, intended_doc_name,
                override_reason, data.get("clinical_notes") or data.get("clinicalNotes"),
                1, workflow_status, "not_sent", "no_response_yet",
                now_str, now_str,
            ),
        )

        snapshot = get_emergency_referral_raw(conn, referral_id)
        conn.execute(
            """
            INSERT INTO emergency_referral_versions (
                referral_id, version_number, created_at, created_by_id, created_by_name,
                amendment_reason, changed_fields, snapshot_data
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                referral_id, 1, now_str, ref_clinician_id, ref_clinician_name,
                "Initial emergency referral creation",
                json.dumps(["initial_creation"]),
                json.dumps(snapshot),
            ),
        )

        if amb_status != "not_dispatched":
            conn.execute(
                """
                INSERT INTO ambulance_dispatch_records (
                    referral_id, dispatch_status, service_type, vehicle_number, dispatched_at, estimated_arrival_minutes, notes
                ) VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    referral_id, amb_status, service_type, vehicle_num, dispatch_time, eta_mins,
                    data.get("dispatch_notes") or "Initial emergency ambulance dispatch recorded",
                ),
            )

        conn.execute(
            """
            INSERT INTO emergency_referral_audit_logs (
                referral_id, actor_id, actor_name, action, details, timestamp
            ) VALUES (?, ?, ?, ?, ?, ?)
            """,
            (
                referral_id, ref_clinician_id, ref_clinician_name,
                "CREATED",
                f"Emergency referral created for patient {patient_id} targeting {rec_fac_name}. Category: {emergency_category}.",
                now_str,
            ),
        )

        conn.commit()
    except Exception as e:
        conn.rollback()
        conn.close()
        return None, str(e)

    result = get_emergency_referral(referral_id, conn=conn)
    conn.close()
    return result, None


def add_emergency_referral_version(referral_id, updated_data, actor_id="doc_parth", actor_name="Dr. Parth Saxena", amendment_reason="Clinical observations and vitals update"):
    """
    Creates a new amendment version of an existing referral after dispatch.
    Preserves original submitted version and maintains an immutable audit trail.
    """
    conn = get_db_connection()
    now_str = datetime.now(timezone.utc).isoformat()

    current = get_emergency_referral_raw(conn, referral_id)
    if not current:
        conn.close()
        return None, f"Referral {referral_id} not found"

    new_version = current["current_version"] + 1

    # Detect changed fields
    changed_fields = []
    updatable_fields = [
        "presenting_complaint", "emergency_category", "red_flag_symptoms", "symptom_onset_time",
        "vitals_pulse", "vitals_bp_systolic", "vitals_bp_diastolic", "vitals_spo2", "vitals_resp_rate", "vitals_temp",
        "consciousness_level", "allergies", "medications_history", "immediate_treatment_given",
        "ambulance_status", "ambulance_dispatch_time", "ambulance_vehicle_number", "ambulance_eta_minutes",
        "receiving_facility_id", "receiving_facility_name", "receiving_department",
        "intended_doctor_id", "intended_doctor_name", "recommendation_override_reason", "clinical_notes",
    ]

    update_set = {}
    for f in updatable_fields:
        # Check camelCase and snake_case keys
        camel = "".join(w.capitalize() if i > 0 else w for i, w in enumerate(f.split("_")))
        val = updated_data.get(f) if f in updated_data else updated_data.get(camel)
        if val is not None:
            if f == "red_flag_symptoms" and isinstance(val, list):
                val = json.dumps(val)
            if str(val) != str(current.get(f)):
                changed_fields.append(f)
                update_set[f] = val

    if not changed_fields and "force" not in updated_data:
        changed_fields = ["supplementary_clinical_notes"]

    # Build SQL update query dynamically
    if update_set:
        update_set["current_version"] = new_version
        update_set["updated_at"] = now_str
        set_clause = ", ".join(f"{k} = ?" for k in update_set.keys())
        values = list(update_set.values()) + [referral_id]
        conn.execute(f"UPDATE emergency_referrals SET {set_clause} WHERE referral_id = ?", values)
    else:
        conn.execute(
            "UPDATE emergency_referrals SET current_version = ?, updated_at = ? WHERE referral_id = ?",
            (new_version, now_str, referral_id),
        )

    # Take new snapshot
    new_snapshot = get_emergency_referral_raw(conn, referral_id)

    # Insert into versions table
    conn.execute(
        """
        INSERT INTO emergency_referral_versions (
            referral_id, version_number, created_at, created_by_id, created_by_name,
            amendment_reason, changed_fields, snapshot_data
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            referral_id, new_version, now_str, actor_id, actor_name,
            amendment_reason, json.dumps(changed_fields), json.dumps(new_snapshot),
        ),
    )

    # Log audit
    conn.execute(
        """
        INSERT INTO emergency_referral_audit_logs (
            referral_id, actor_id, actor_name, action, details, timestamp
        ) VALUES (?, ?, ?, ?, ?, ?)
        """,
        (
            referral_id, actor_id, actor_name,
            "VERSION_AMENDED",
            f"Amendment Version {new_version} created. Reason: {amendment_reason}. Changed: {', '.join(changed_fields)}.",
            now_str,
        ),
    )

    conn.commit()
    result = get_emergency_referral(referral_id, conn=conn)
    conn.close()
    return result, None


def update_ambulance_dispatch(referral_id, dispatch_data, actor_id="doc_parth", actor_name="Dr. Parth Saxena"):
    """
    Updates ambulance status, dispatch timestamp, vehicle number, and ETA.
    """
    conn = get_db_connection()
    now_str = datetime.now(timezone.utc).isoformat()

    current = get_emergency_referral_raw(conn, referral_id)
    if not current:
        conn.close()
        return None, f"Referral {referral_id} not found"

    status = dispatch_data.get("ambulance_status") or dispatch_data.get("ambulanceStatus") or current["ambulance_status"]
    vehicle = dispatch_data.get("ambulance_vehicle_number") or dispatch_data.get("ambulanceVehicleNumber") or current["ambulance_vehicle_number"]
    eta = dispatch_data.get("ambulance_eta_minutes") or dispatch_data.get("ambulanceEtaMinutes")
    service = dispatch_data.get("ambulance_service_type") or dispatch_data.get("ambulanceServiceType") or current["ambulance_service_type"]
    notes = dispatch_data.get("notes") or f"Ambulance status updated to '{status}'"

    # Auto transition workflow status
    workflow_status = current["workflow_status"]
    if status in ["en_route_scene", "patient_loaded_in_transit"] and workflow_status in ["draft", "emergency_created"]:
        workflow_status = "in_transit"
    elif status == "arrived" and workflow_status in ["emergency_created", "in_transit"]:
        workflow_status = "patient_arrived"

    conn.execute(
        """
        UPDATE emergency_referrals SET
            ambulance_status = ?,
            ambulance_vehicle_number = ?,
            ambulance_service_type = ?,
            ambulance_eta_minutes = COALESCE(?, ambulance_eta_minutes),
            workflow_status = ?,
            updated_at = ?
        WHERE referral_id = ?
        """,
        (status, vehicle, service, eta, workflow_status, now_str, referral_id),
    )

    conn.execute(
        """
        INSERT INTO ambulance_dispatch_records (
            referral_id, dispatch_status, service_type, vehicle_number, dispatched_at, estimated_arrival_minutes, notes
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
        """,
        (referral_id, status, service, vehicle, now_str, eta, notes),
    )

    conn.execute(
        """
        INSERT INTO emergency_referral_audit_logs (
            referral_id, actor_id, actor_name, action, details, timestamp
        ) VALUES (?, ?, ?, ?, ?, ?)
        """,
        (referral_id, actor_id, actor_name, "DISPATCH_RECORDED", f"Ambulance dispatch updated: {status} ({vehicle or service}). ETA: {eta or 'unknown'} min.", now_str),
    )

    conn.commit()
    result = get_emergency_referral(referral_id, conn=conn)
    conn.close()
    return result, None


def send_emergency_referral(referral_id, channel="email", recipient_address=None, recipient_name=None, custom_notes=None, actor_id="doc_parth", actor_name="Dr. Parth Saxena"):
    """
    Dispatches referral notification via specified channel (Email, Clinical Messaging, SMS/WhatsApp).
    Simulates delivery provider transmission and updates delivery_status.
    """
    conn = get_db_connection()
    now_str = datetime.now(timezone.utc).isoformat()

    current = get_emergency_referral(referral_id, conn=conn)
    if not current:
        conn.close()
        return None, f"Referral {referral_id} not found"

    cur_ver = current["current_version"]
    recipient = recipient_address or f"emergency@{current['receiving_facility_id']}.health.gov.in"
    rec_name = recipient_name or f"{current['receiving_facility_name']} - {current['receiving_department']}"

    # Build clinical summary & subject
    subject = f"URGENT EMERGENCY REFERRAL — {referral_id} — {current['patient_identifier']}"
    
    # Body
    vitals_parts = []
    if current.get("vitals_pulse"): vitals_parts.append(f"HR: {current['vitals_pulse']} bpm")
    if current.get("vitals_bp_systolic") and current.get("vitals_bp_diastolic"): vitals_parts.append(f"BP: {current['vitals_bp_systolic']}/{current['vitals_bp_diastolic']} mmHg")
    if current.get("vitals_spo2"): vitals_parts.append(f"SpO2: {current['vitals_spo2']}%")
    if current.get("vitals_resp_rate"): vitals_parts.append(f"RR: {current['vitals_resp_rate']}/min")
    if current.get("vitals_temp"): vitals_parts.append(f"Temp: {current['vitals_temp']}°F")
    vitals_str = ", ".join(vitals_parts) if vitals_parts else "Pending en-route assessment"

    body = f"""================================================================================
CRITICAL EMERGENCY REFERRAL DISPATCH
================================================================================
Referral ID:         {referral_id} (Version {cur_ver})
Patient Identifier:  {current['patient_identifier']} ({current.get('patient_name') or 'Identity Pending'})
Age / Sex:           {current.get('patient_age') or 'Unknown'} / {current.get('patient_sex') or 'Unknown'}
Emergency Category:  {current['emergency_category']}
Presenting Complaint:{current['presenting_complaint']}
Consciousness Level: {current.get('consciousness_level') or 'Alert'}

VITAL SIGNS:
{vitals_str}

IMMEDIATE TREATMENT & FIRST AID:
{current.get('immediate_treatment_given') or 'Standard BLS support initiated'}

AMBULANCE LOGISTICS:
Status:              {current['ambulance_status'].upper()}
Service / Vehicle:   {current['ambulance_service_type']} ({current.get('ambulance_vehicle_number') or 'Unit Assigned'})
Estimated Arrival:   {current.get('ambulance_eta_minutes') or '15-20'} Minutes

REFERRING CLINICIAN:
Doctor:              {current['referring_clinician_name']} ({current['referring_facility_name']})
Emergency Callback:  {current['referring_callback_phone']}

DESTINATION:
Hospital:            {current['receiving_facility_name']}
Department:          {current['receiving_department']}

SECURE CLINICAL HANDOVER LINK:
https://smart-referral.health.gov.in/emergency/referrals/{referral_id}?token=EMR_SECURE_TOKEN_{cur_ver}

NOTICE:
Additional clinical observations and vital signs may follow via versioned updates while the patient is in transit.
================================================================================
"""
    if custom_notes:
        body += f"\nCLINICIAN UPDATE NOTE:\n{custom_notes}\n"

    # Provider message id
    prov_id = f"prov_msg_{channel}_{datetime.now().strftime('%Y%m%d%H%M%S')}_{referral_id}"

    # Record delivery
    conn.execute(
        """
        INSERT INTO emergency_referral_deliveries (
            referral_id, version_number, channel, recipient_address, recipient_name,
            subject_or_preview, message_body, delivery_status, provider_message_id, attempted_at, delivered_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            referral_id, cur_ver, channel, recipient, rec_name,
            subject, body, "sent_to_provider", prov_id, now_str, now_str,
        ),
    )

    # Update referral workflow status if was emergency_created
    new_workflow = current["workflow_status"]
    if new_workflow == "emergency_created":
        new_workflow = "initial_sent"

    conn.execute(
        """
        UPDATE emergency_referrals SET
            delivery_status = 'sent_to_provider',
            workflow_status = ?,
            updated_at = ?
        WHERE referral_id = ?
        """,
        (new_workflow, now_str, referral_id),
    )

    conn.execute(
        """
        UPDATE emergency_referral_versions SET
            sent_to_receiving_team = 1,
            sent_at = ?
        WHERE referral_id = ? AND version_number = ?
        """,
        (now_str, referral_id, cur_ver),
    )

    conn.execute(
        """
        INSERT INTO emergency_referral_audit_logs (
            referral_id, actor_id, actor_name, action, details, timestamp
        ) VALUES (?, ?, ?, ?, ?, ?)
        """,
        (
            referral_id, actor_id, actor_name,
            "SENT_" + channel.upper(),
            f"Referral Version {cur_ver} dispatched via {channel} to {rec_name} ({recipient}).",
            now_str,
        ),
    )

    conn.commit()
    result = get_emergency_referral(referral_id, conn=conn)
    conn.close()
    return result, None


def record_emergency_acknowledgement(referral_id, response_status="acknowledged", responder_name="Duty Emergency Officer", responder_role="Emergency Physician", alternative_facility_id=None, notes=None):
    """
    Records receiving team response (Acknowledged, Accepted, Declined, Alternative destination requested).
    """
    conn = get_db_connection()
    now_str = datetime.now(timezone.utc).isoformat()

    current = get_emergency_referral_raw(conn, referral_id)
    if not current:
        conn.close()
        return None, f"Referral {referral_id} not found"

    conn.execute(
        """
        INSERT INTO emergency_referral_acknowledgements (
            referral_id, response_status, responder_name, responder_role, alternative_facility_id, notes, responded_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
        """,
        (referral_id, response_status, responder_name, responder_role, alternative_facility_id, notes, now_str),
    )

    conn.execute(
        """
        UPDATE emergency_referrals SET
            response_status = ?,
            updated_at = ?
        WHERE referral_id = ?
        """,
        (response_status, now_str, referral_id),
    )

    conn.execute(
        """
        INSERT INTO emergency_referral_audit_logs (
            referral_id, actor_id, actor_name, action, details, timestamp
        ) VALUES (?, ?, ?, ?, ?, ?)
        """,
        (
            referral_id, responder_name, responder_role,
            "RESPONSE_" + response_status.upper(),
            f"Receiving team responded with status '{response_status}'. Notes: {notes or 'None'}.",
            now_str,
        ),
    )

    conn.commit()
    result = get_emergency_referral(referral_id, conn=conn)
    conn.close()
    return result, None


def record_emergency_handover(referral_id, actor_id="doc_parth", actor_name="Dr. Parth Saxena", notes=None):
    """
    Records arrival at destination and completion of clinical handover.
    """
    conn = get_db_connection()
    now_str = datetime.now(timezone.utc).isoformat()

    current = get_emergency_referral_raw(conn, referral_id)
    if not current:
        conn.close()
        return None, f"Referral {referral_id} not found"

    conn.execute(
        """
        UPDATE emergency_referrals SET
            workflow_status = 'handover_completed',
            ambulance_status = 'arrived',
            updated_at = ?
        WHERE referral_id = ?
        """,
        (now_str, referral_id),
    )

    conn.execute(
        """
        INSERT INTO emergency_referral_audit_logs (
            referral_id, actor_id, actor_name, action, details, timestamp
        ) VALUES (?, ?, ?, ?, ?, ?)
        """,
        (
            referral_id, actor_id, actor_name,
            "HANDOVER_COMPLETED",
            f"Clinical handover successfully completed at destination. Notes: {notes or 'Handover complete'}.",
            now_str,
        ),
    )

    conn.commit()
    result = get_emergency_referral(referral_id, conn=conn)
    conn.close()
    return result, None


# ============================================================================
# Facility Resources, Infrastructure, Capacity & Staff Management Operations
# ============================================================================

def is_authorized_for_facility(actor_id, actor_role, facility_id):
    """
    Verifies that the actor has permission to modify the given facility's infrastructure.
    Admins, district health officers, hospital duty officers, and the facility's registered admin are authorized.
    """
    if actor_role in ["admin", "district_officer", "hospital_duty_officer"]:
        return True, None

    conn = get_db_connection()
    prof = conn.execute("SELECT admin_user_id FROM facility_profiles WHERE facility_id = ?", (facility_id,)).fetchone()
    conn.close()
    if prof and prof["admin_user_id"] == actor_id:
        return True, None

    # Check if actor is affiliated staff for this facility
    conn = get_db_connection()
    aff = conn.execute(
        "SELECT 1 FROM facility_staff_affiliations WHERE facility_id = ? AND (doctor_id = ? OR affiliation_id = ?)",
        (facility_id, actor_id, actor_id),
    ).fetchone()
    conn.close()
    if aff:
        return True, None

    return False, f"Unauthorized: User '{actor_id}' with role '{actor_role}' is not authorized to edit facility '{facility_id}' resources."


def get_facility_resources_complete(facility_id):
    """
    Returns full comprehensive facility details including:
    - Facility profile & basic info
    - Supporting infrastructure (O2, power, blood bank, ambulance, isolation)
    - 7-category Medical equipment & technology inventory
    - Bed & operational capacity records
    - Active clinical departments
    - Staff & doctor affiliations
    - Audit & verification records
    """
    conn = get_db_connection()

    # 1. Base Facility Record
    fac_dict = get_facility_by_id(facility_id)
    if not fac_dict:
        conn.close()
        return None

    # 2. Profile
    prof_row = conn.execute("SELECT * FROM facility_profiles WHERE facility_id = ?", (facility_id,)).fetchone()
    prof_dict = dict(prof_row) if prof_row else {}
    if prof_dict.get("departments_json"):
        try:
            prof_dict["departments"] = json.loads(prof_dict["departments_json"])
        except Exception:
            prof_dict["departments"] = []

    # 3. Supporting Infrastructure
    supp_row = conn.execute("SELECT * FROM facility_supporting_infrastructure WHERE facility_id = ?", (facility_id,)).fetchone()
    supp_dict = dict(supp_row) if supp_row else {}

    # 4. Capacity Records
    cap_rows = conn.execute("SELECT * FROM facility_capacity_records WHERE facility_id = ? ORDER BY category", (facility_id,)).fetchall()
    capacity_list = [dict(r) for r in cap_rows]

    # 5. Departments
    dept_rows = conn.execute("SELECT * FROM facility_departments WHERE facility_id = ? ORDER BY department_name", (facility_id,)).fetchall()
    dept_list = []
    for d in dept_rows:
        dd = dict(d)
        for jk in ["specialties_json", "services_json", "care_levels_json"]:
            if dd.get(jk):
                try:
                    dd[jk.replace("_json", "")] = json.loads(dd[jk])
                except Exception:
                    dd[jk.replace("_json", "")] = []
            elif jk.replace("_json", "") not in dd:
                dd[jk.replace("_json", "")] = ["outpatient", "inpatient", "emergency"] if jk == "care_levels_json" else []
        if not dd.get("specialist_coverage"):
            dd["specialist_coverage"] = "on_site"
        dept_list.append(dd)

    # 6. Inventory Items (7 Categories)
    inv_rows = conn.execute(
        "SELECT * FROM facility_resource_inventory WHERE facility_id = ? ORDER BY resource_category, resource_name",
        (facility_id,),
    ).fetchall()
    inventory_list = [dict(r) for r in inv_rows]

    # 7. Staff & Doctor Affiliations
    staff_rows = conn.execute(
        "SELECT * FROM facility_staff_affiliations WHERE facility_id = ? AND is_active = 1 ORDER BY staff_role, staff_name",
        (facility_id,),
    ).fetchall()
    staff_list = []
    for s in staff_rows:
        sd = dict(s)
        for jk in ["qualifications_json", "capabilities_json"]:
            if sd.get(jk):
                try:
                    sd[jk.replace("_json", "")] = json.loads(sd[jk])
                except Exception:
                    sd[jk.replace("_json", "")] = []
        staff_list.append(sd)

    # 8. Verification & Audit Trail
    verif_rows = conn.execute(
        "SELECT * FROM facility_resource_verification_records WHERE facility_id = ? ORDER BY verified_at DESC",
        (facility_id,),
    ).fetchall()
    verif_list = [dict(r) for r in verif_rows]

    conn.close()

    # Compute summary indicators
    total_equip_installed = sum(i.get("quantity_installed", 1) for i in inventory_list)
    total_equip_operational = sum(i.get("quantity_operational", 1) for i in inventory_list if i.get("operational_status") == "operational")
    total_beds = sum(c.get("installed_capacity", 0) for c in capacity_list if c.get("category") not in ["operating_theatres", "dialysis_stations"])
    available_beds = sum(c.get("available_capacity", 0) for c in capacity_list if c.get("category") not in ["operating_theatres", "dialysis_stations"])
    icu_cap = next((c for c in capacity_list if c.get("category") == "icu_beds"), None)
    em_cap = next((c for c in capacity_list if c.get("category") == "emergency_bays"), None)

    return {
        "facility_id": facility_id,
        "facility": fac_dict,
        "profile": prof_dict,
        "supporting_infrastructure": supp_dict,
        "capacity": capacity_list,
        "departments": dept_list,
        "inventory": inventory_list,
        "staff": staff_list,
        "verification_records": verif_list,
        "summary": {
            "total_equipment_installed": total_equip_installed,
            "total_equipment_operational": total_equip_operational,
            "total_beds": total_beds or fac_dict.get("beds", 0),
            "available_beds": available_beds or fac_dict.get("available_beds", 0),
            "available_icu_beds": icu_cap.get("available_capacity", 0) if icu_cap else fac_dict.get("available_icu_beds", 0),
            "available_emergency_bays": em_cap.get("available_capacity", 0) if em_cap else 2,
            "is_emergency_ready": bool(fac_dict.get("emergency_care", 0)),
            "is_verified": prof_dict.get("verification_status") == "verified",
        },
    }


def add_facility_resource(facility_id, data, actor_id="admin_user", actor_role="admin"):
    """Adds a new medical equipment or technology item to the facility inventory."""
    auth_ok, auth_err = is_authorized_for_facility(actor_id, actor_role, facility_id)
    if not auth_ok:
        return None, auth_err

    conn = get_db_connection()
    now_str = datetime.now(timezone.utc).isoformat()
    res_id = data.get("resource_id") or f"res_{uuid.uuid4().hex[:8]}"

    conn.execute(
        """
        INSERT INTO facility_resource_inventory (
            facility_id, resource_id, resource_type, resource_category, resource_name,
            model_spec, quantity_installed, quantity_operational, quantity_out_of_service,
            operational_status, location_in_facility, ownership_type, service_delivery,
            turnaround_time_hours, availability_schedule, last_maintenance_date,
            next_maintenance_date, operator_requirements, verification_status,
            verified_by, evidence_document_name, notes, record_source,
            is_present, last_verified_at, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            facility_id,
            res_id,
            data.get("resource_type", "equipment"),
            data.get("resource_category", "diagnostic_and_imaging"),
            data.get("resource_name", "Medical Equipment"),
            data.get("model_spec", ""),
            int(data.get("quantity_installed", 1)),
            int(data.get("quantity_operational", 1)),
            int(data.get("quantity_out_of_service", 0)),
            data.get("operational_status", "operational"),
            data.get("location_in_facility", "Main Clinical Block"),
            data.get("ownership_type", "in_house_owned"),
            data.get("service_delivery", "in_house"),
            int(data.get("turnaround_time_hours", 0)),
            data.get("availability_schedule", "24/7"),
            data.get("last_maintenance_date", ""),
            data.get("next_maintenance_date", ""),
            data.get("operator_requirements", "Trained Clinical Staff"),
            data.get("verification_status", "verified"),
            actor_id,
            data.get("evidence_document_name", ""),
            data.get("notes", ""),
            "Facility Resources Management",
            1 if data.get("is_present", 1) else 0,
            now_str,
            now_str,
            now_str,
        ),
    )

    conn.execute(
        """
        INSERT INTO facility_resource_verification_records (
            verification_id, facility_id, resource_id, reviewed_by, reviewer_role, decision, evidence_notes, verified_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            f"verif_{uuid.uuid4().hex[:8]}",
            facility_id,
            res_id,
            actor_id,
            actor_role,
            "approved",
            f"Resource {data.get('resource_name')} registered by {actor_id}",
            now_str,
        ),
    )
    conn.commit()

    created_row = conn.execute("SELECT * FROM facility_resource_inventory WHERE resource_id = ?", (res_id,)).fetchone()
    conn.close()
    return dict(created_row) if created_row else None, None


def update_facility_resource(facility_id, resource_id, data, actor_id="admin_user", actor_role="admin"):
    """Updates an existing medical equipment or technology item in the inventory."""
    auth_ok, auth_err = is_authorized_for_facility(actor_id, actor_role, facility_id)
    if not auth_ok:
        return None, auth_err

    conn = get_db_connection()
    now_str = datetime.now(timezone.utc).isoformat()
    existing = conn.execute("SELECT * FROM facility_resource_inventory WHERE facility_id = ? AND resource_id = ?", (facility_id, resource_id)).fetchone()
    if not existing:
        conn.close()
        return None, f"Resource {resource_id} not found in facility {facility_id}"

    conn.execute(
        """
        UPDATE facility_resource_inventory SET
            resource_type = COALESCE(?, resource_type),
            resource_category = COALESCE(?, resource_category),
            resource_name = COALESCE(?, resource_name),
            model_spec = COALESCE(?, model_spec),
            quantity_installed = COALESCE(?, quantity_installed),
            quantity_operational = COALESCE(?, quantity_operational),
            quantity_out_of_service = COALESCE(?, quantity_out_of_service),
            operational_status = COALESCE(?, operational_status),
            location_in_facility = COALESCE(?, location_in_facility),
            ownership_type = COALESCE(?, ownership_type),
            service_delivery = COALESCE(?, service_delivery),
            turnaround_time_hours = COALESCE(?, turnaround_time_hours),
            availability_schedule = COALESCE(?, availability_schedule),
            last_maintenance_date = COALESCE(?, last_maintenance_date),
            next_maintenance_date = COALESCE(?, next_maintenance_date),
            operator_requirements = COALESCE(?, operator_requirements),
            verification_status = COALESCE(?, verification_status),
            evidence_document_name = COALESCE(?, evidence_document_name),
            notes = COALESCE(?, notes),
            is_present = COALESCE(?, is_present),
            updated_at = ?
        WHERE facility_id = ? AND resource_id = ?
        """,
        (
            data.get("resource_type"),
            data.get("resource_category"),
            data.get("resource_name"),
            data.get("model_spec"),
            data.get("quantity_installed"),
            data.get("quantity_operational"),
            data.get("quantity_out_of_service"),
            data.get("operational_status"),
            data.get("location_in_facility"),
            data.get("ownership_type"),
            data.get("service_delivery"),
            data.get("turnaround_time_hours"),
            data.get("availability_schedule"),
            data.get("last_maintenance_date"),
            data.get("next_maintenance_date"),
            data.get("operator_requirements"),
            data.get("verification_status"),
            data.get("evidence_document_name"),
            data.get("notes"),
            data.get("is_present"),
            now_str,
            facility_id,
            resource_id,
        ),
    )
    conn.commit()
    updated_row = conn.execute("SELECT * FROM facility_resource_inventory WHERE facility_id = ? AND resource_id = ?", (facility_id, resource_id)).fetchone()
    conn.close()
    return dict(updated_row) if updated_row else None, None


def delete_facility_resource(facility_id, resource_id, actor_id="admin_user", actor_role="admin"):
    """Decommissions a medical equipment item in facility inventory."""
    auth_ok, auth_err = is_authorized_for_facility(actor_id, actor_role, facility_id)
    if not auth_ok:
        return False, auth_err

    conn = get_db_connection()
    now_str = datetime.now(timezone.utc).isoformat()
    conn.execute(
        """
        UPDATE facility_resource_inventory SET
            operational_status = 'decommissioned',
            is_present = 0,
            quantity_operational = 0,
            quantity_out_of_service = quantity_installed,
            updated_at = ?
        WHERE facility_id = ? AND resource_id = ?
        """,
        (now_str, facility_id, resource_id),
    )
    conn.commit()
    conn.close()
    return True, None


def get_facility_capacity(facility_id):
    """Retrieves operational capacity records for a facility."""
    conn = get_db_connection()
    rows = conn.execute("SELECT * FROM facility_capacity_records WHERE facility_id = ? ORDER BY category", (facility_id,)).fetchall()
    conn.close()
    return [dict(r) for r in rows]


def update_facility_capacity(facility_id, capacity_records, actor_id="admin_user", actor_role="admin"):
    """
    Updates operational bed, theatre, and unit capacity for a facility.
    Synchronizes available beds and available ICU beds with the recommendation algorithm.
    """
    auth_ok, auth_err = is_authorized_for_facility(actor_id, actor_role, facility_id)
    if not auth_ok:
        return None, auth_err

    conn = get_db_connection()
    now_str = datetime.now(timezone.utc).isoformat()

    total_avail_beds = 0
    total_avail_icu = 0

    for rec in capacity_records:
        cat = rec.get("category")
        if not cat:
            continue
        label = rec.get("category_label") or cat.replace("_", " ").title()
        inst = int(rec.get("installed_capacity", 0))
        oper = int(rec.get("operational_capacity", inst))
        occ = int(rec.get("occupied_capacity", 0))
        avail = max(0, oper - occ)

        if cat not in ["operating_theatres", "dialysis_stations"]:
            total_avail_beds += avail
        if cat == "icu_beds":
            total_avail_icu += avail

        cap_id = f"cap_{facility_id}_{cat}"
        conn.execute(
            """
            INSERT OR REPLACE INTO facility_capacity_records (
                capacity_id, facility_id, category, category_label,
                installed_capacity, operational_capacity, occupied_capacity, available_capacity,
                source, last_updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (cap_id, facility_id, cat, label, inst, oper, occ, avail, f"Census update by {actor_id}", now_str),
        )

    # Synchronize healthcare_facilities table for ranking engine
    conn.execute(
        """
        UPDATE healthcare_facilities SET
            bed_availability = ?,
            updated_at = ?
        WHERE facility_id = ?
        """,
        (total_avail_beds, now_str, facility_id),
    )

    # Synchronize facility_operational_status
    conn.execute(
        """
        UPDATE facility_operational_status SET
            general_beds_available = ?,
            icu_beds_available = ?,
            last_reported_at = ?,
            reported_by_user = ?
        WHERE facility_id = ?
        """,
        (total_avail_beds, total_avail_icu, now_str, actor_id, facility_id),
    )

    conn.commit()
    rows = conn.execute("SELECT * FROM facility_capacity_records WHERE facility_id = ? ORDER BY category", (facility_id,)).fetchall()
    conn.close()
    return [dict(r) for r in rows], None


def get_facility_profile_detailed(facility_id):
    """Retrieves facility profile and supporting infrastructure."""
    conn = get_db_connection()
    prof_row = conn.execute("SELECT * FROM facility_profiles WHERE facility_id = ?", (facility_id,)).fetchone()
    supp_row = conn.execute("SELECT * FROM facility_supporting_infrastructure WHERE facility_id = ?", (facility_id,)).fetchone()
    conn.close()

    prof_dict = dict(prof_row) if prof_row else {}
    if prof_dict.get("departments_json"):
        try:
            prof_dict["departments"] = json.loads(prof_dict["departments_json"])
        except Exception:
            prof_dict["departments"] = []

    return {
        "facility_id": facility_id,
        "profile": prof_dict,
        "supporting_infrastructure": dict(supp_row) if supp_row else {},
    }


def update_facility_profile(facility_id, profile_data, actor_id="admin_user", actor_role="admin"):
    """Updates facility profile and supporting infrastructure."""
    auth_ok, auth_err = is_authorized_for_facility(actor_id, actor_role, facility_id)
    if not auth_ok:
        return None, auth_err

    conn = get_db_connection()
    now_str = datetime.now(timezone.utc).isoformat()

    conn.execute(
        """
        UPDATE facility_profiles SET
            contact_number = COALESCE(?, contact_number),
            official_email = COALESCE(?, official_email),
            opening_hours = COALESCE(?, opening_hours),
            operating_days = COALESCE(?, operating_days),
            license_number = COALESCE(?, license_number),
            registration_authority = COALESCE(?, registration_authority),
            admin_name = COALESCE(?, admin_name),
            emergency_services_detail = COALESCE(?, emergency_services_detail),
            departments_json = COALESCE(?, departments_json),
            updated_at = ?
        WHERE facility_id = ?
        """,
        (
            profile_data.get("contact_number"),
            profile_data.get("official_email"),
            profile_data.get("opening_hours"),
            profile_data.get("operating_days"),
            profile_data.get("license_number"),
            profile_data.get("registration_authority"),
            profile_data.get("admin_name"),
            profile_data.get("emergency_services_detail"),
            json.dumps(profile_data.get("departments", [])) if "departments" in profile_data else None,
            now_str,
            facility_id,
        ),
    )

    supp = profile_data.get("supporting_infrastructure") or profile_data
    if any(k in supp for k in ["ambulance_arrangements", "blood_bank_access", "pharmacy_available", "oxygen_infrastructure", "power_backup", "isolation_capability", "infection_control", "referral_partnerships", "telemedicine_capability"]):
        conn.execute(
            """
            UPDATE facility_supporting_infrastructure SET
                ambulance_arrangements = COALESCE(?, ambulance_arrangements),
                blood_bank_access = COALESCE(?, blood_bank_access),
                pharmacy_available = COALESCE(?, pharmacy_available),
                oxygen_infrastructure = COALESCE(?, oxygen_infrastructure),
                power_backup = COALESCE(?, power_backup),
                isolation_capability = COALESCE(?, isolation_capability),
                infection_control = COALESCE(?, infection_control),
                referral_partnerships = COALESCE(?, referral_partnerships),
                telemedicine_capability = COALESCE(?, telemedicine_capability),
                updated_at = ?
            WHERE facility_id = ?
            """,
            (
                supp.get("ambulance_arrangements"),
                supp.get("blood_bank_access"),
                supp.get("pharmacy_available"),
                supp.get("oxygen_infrastructure"),
                supp.get("power_backup"),
                supp.get("isolation_capability"),
                supp.get("infection_control"),
                supp.get("referral_partnerships"),
                supp.get("telemedicine_capability"),
                now_str,
                facility_id,
            ),
        )

    conn.commit()
    conn.close()
    return get_facility_resources_complete(facility_id), None


def get_facility_staff_affiliations(facility_id):
    """Retrieves staff and doctor affiliations for a facility."""
    conn = get_db_connection()
    rows = conn.execute(
        "SELECT * FROM facility_staff_affiliations WHERE facility_id = ? AND is_active = 1 ORDER BY staff_role, staff_name",
        (facility_id,),
    ).fetchall()
    conn.close()
    staff_list = []
    for r in rows:
        sd = dict(r)
        for jk in ["qualifications_json", "capabilities_json"]:
            if sd.get(jk):
                try:
                    sd[jk.replace("_json", "")] = json.loads(sd[jk])
                except Exception:
                    sd[jk.replace("_json", "")] = []
        staff_list.append(sd)
    return staff_list


def add_facility_staff_affiliation(facility_id, staff_data, actor_id="admin_user", actor_role="admin"):
    """Adds a clinical or technical personnel affiliation to the facility."""
    auth_ok, auth_err = is_authorized_for_facility(actor_id, actor_role, facility_id)
    if not auth_ok:
        return None, auth_err

    conn = get_db_connection()
    now_str = datetime.now(timezone.utc).isoformat()
    affil_id = staff_data.get("affiliation_id") or f"affil_{uuid.uuid4().hex[:8]}"

    conn.execute(
        """
        INSERT INTO facility_staff_affiliations (
            affiliation_id, facility_id, doctor_id, staff_name, staff_role,
            department, designation, primary_specialty, qualifications_json,
            capabilities_json, working_days, shift_timing, emergency_duty_participating,
            is_currently_practising, verification_status, missing_documentation_notes,
            is_active, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            affil_id,
            facility_id,
            staff_data.get("doctor_id"),
            staff_data.get("staff_name", "Clinical Staff"),
            staff_data.get("staff_role", "doctor"),
            staff_data.get("department", "General Medicine"),
            staff_data.get("designation", "Staff Physician"),
            staff_data.get("primary_specialty", "Internal Medicine"),
            json.dumps(staff_data.get("qualifications", [])),
            json.dumps(staff_data.get("capabilities", [])),
            staff_data.get("working_days", "Mon-Sat"),
            staff_data.get("shift_timing", "Day (09:00 - 17:00)"),
            1 if staff_data.get("emergency_duty_participating", True) else 0,
            1 if staff_data.get("is_currently_practising", True) else 0,
            staff_data.get("verification_status", "verified"),
            staff_data.get("missing_documentation_notes"),
            1,
            now_str,
            now_str,
        ),
    )
    conn.commit()
    row = conn.execute("SELECT * FROM facility_staff_affiliations WHERE affiliation_id = ?", (affil_id,)).fetchone()
    conn.close()
    return dict(row) if row else None, None


def update_facility_staff_affiliation(facility_id, affiliation_id, staff_data, actor_id="admin_user", actor_role="admin"):
    """Updates an existing staff affiliation."""
    auth_ok, auth_err = is_authorized_for_facility(actor_id, actor_role, facility_id)
    if not auth_ok:
        return None, auth_err

    conn = get_db_connection()
    now_str = datetime.now(timezone.utc).isoformat()
    conn.execute(
        """
        UPDATE facility_staff_affiliations SET
            staff_name = COALESCE(?, staff_name),
            staff_role = COALESCE(?, staff_role),
            department = COALESCE(?, department),
            designation = COALESCE(?, designation),
            primary_specialty = COALESCE(?, primary_specialty),
            working_days = COALESCE(?, working_days),
            shift_timing = COALESCE(?, shift_timing),
            emergency_duty_participating = COALESCE(?, emergency_duty_participating),
            is_currently_practising = COALESCE(?, is_currently_practising),
            verification_status = COALESCE(?, verification_status),
            updated_at = ?
        WHERE facility_id = ? AND affiliation_id = ?
        """,
        (
            staff_data.get("staff_name"),
            staff_data.get("staff_role"),
            staff_data.get("department"),
            staff_data.get("designation"),
            staff_data.get("primary_specialty"),
            staff_data.get("working_days"),
            staff_data.get("shift_timing"),
            staff_data.get("emergency_duty_participating"),
            staff_data.get("is_currently_practising"),
            staff_data.get("verification_status"),
            now_str,
            facility_id,
            affiliation_id,
        ),
    )
    conn.commit()
    row = conn.execute("SELECT * FROM facility_staff_affiliations WHERE facility_id = ? AND affiliation_id = ?", (facility_id, affiliation_id)).fetchone()
    conn.close()
    return dict(row) if row else None, None


def delete_facility_staff_affiliation(facility_id, affiliation_id, actor_id="admin_user", actor_role="admin"):
    """Deactivates a staff affiliation."""
    auth_ok, auth_err = is_authorized_for_facility(actor_id, actor_role, facility_id)
    if not auth_ok:
        return False, auth_err

    conn = get_db_connection()
    conn.execute(
        "UPDATE facility_staff_affiliations SET is_active = 0, is_currently_practising = 0 WHERE facility_id = ? AND affiliation_id = ?",
        (facility_id, affiliation_id),
    )
    conn.commit()
    conn.close()
    return True, None


def verify_facility_resource(facility_id, resource_id, decision="approved", reviewer_id="admin_user", reviewer_role="admin", notes=None, reverification_due_date=None):
    """Audits and records administrative verification for a medical resource."""
    if reviewer_role not in ["admin", "district_officer"]:
        return None, f"Unauthorized: Role '{reviewer_role}' cannot verify facility resources."

    conn = get_db_connection()
    now_str = datetime.now(timezone.utc).isoformat()
    new_status = "verified" if decision == "approved" else ("rejected" if decision == "rejected" else "pending")

    conn.execute(
        "UPDATE facility_resource_inventory SET verification_status = ?, verified_by = ?, last_verified_at = ? WHERE facility_id = ? AND resource_id = ?",
        (new_status, reviewer_id, now_str, facility_id, resource_id),
    )
    verif_id = f"verif_{uuid.uuid4().hex[:8]}"
    conn.execute(
        """
        INSERT INTO facility_resource_verification_records (
            verification_id, facility_id, resource_id, reviewed_by, reviewer_role, decision, evidence_notes, verified_at, reverification_due_date
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (verif_id, facility_id, resource_id, reviewer_id, reviewer_role, decision, notes or f"Decision {decision}", now_str, reverification_due_date),
    )
    conn.commit()
    row = conn.execute("SELECT * FROM facility_resource_inventory WHERE facility_id = ? AND resource_id = ?", (facility_id, resource_id)).fetchone()
    conn.close()
    return dict(row) if row else None, None


def get_facility_departments(facility_id):
    """Retrieves all clinical departments and specialized services for a facility."""
    conn = get_db_connection()
    dept_rows = conn.execute("SELECT * FROM facility_departments WHERE facility_id = ? ORDER BY department_name", (facility_id,)).fetchall()
    conn.close()
    dept_list = []
    for d in dept_rows:
        dd = dict(d)
        for jk in ["specialties_json", "services_json", "care_levels_json"]:
            if dd.get(jk):
                try:
                    dd[jk.replace("_json", "")] = json.loads(dd[jk])
                except Exception:
                    dd[jk.replace("_json", "")] = []
            elif jk.replace("_json", "") not in dd:
                dd[jk.replace("_json", "")] = ["outpatient", "inpatient", "emergency"] if jk == "care_levels_json" else []
        if not dd.get("specialist_coverage"):
            dd["specialist_coverage"] = "on_site"
        dept_list.append(dd)
    return dept_list


def add_facility_department(facility_id, dept_data, actor_id="admin_user", actor_role="admin"):
    """Adds a clinical department to a facility."""
    auth_ok, auth_err = is_authorized_for_facility(actor_id, actor_role, facility_id)
    if not auth_ok:
        return None, auth_err

    conn = get_db_connection()
    now_str = datetime.now(timezone.utc).isoformat()
    dept_id = dept_data.get("department_id") or f"dept_{facility_id}_{uuid.uuid4().hex[:8]}"

    conn.execute(
        """
        INSERT INTO facility_departments (
            department_id, facility_id, department_name, specialties_json,
            services_json, operational_days, operating_hours, appointment_mode,
            emergency_available, specialist_coverage, care_levels_json,
            head_of_department, is_operational, temporary_closure_reason, last_updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            dept_id,
            facility_id,
            dept_data.get("department_name", "Clinical Department"),
            json.dumps(dept_data.get("specialties", [])),
            json.dumps(dept_data.get("services", [])),
            dept_data.get("operational_days", "Mon-Sun"),
            dept_data.get("operating_hours", "24 Hours"),
            dept_data.get("appointment_mode", "Walk-in & Appointment"),
            1 if dept_data.get("emergency_available", True) else 0,
            dept_data.get("specialist_coverage", "on_site"),
            json.dumps(dept_data.get("care_levels", ["outpatient", "inpatient", "emergency"])),
            dept_data.get("head_of_department", f"HOD ({actor_id})"),
            1 if dept_data.get("is_operational", True) else 0,
            dept_data.get("temporary_closure_reason"),
            now_str,
        ),
    )
    conn.commit()
    row = conn.execute("SELECT * FROM facility_departments WHERE department_id = ?", (dept_id,)).fetchone()
    conn.close()
    if row:
        dd = dict(row)
        for jk in ["specialties_json", "services_json", "care_levels_json"]:
            if dd.get(jk):
                try:
                    dd[jk.replace("_json", "")] = json.loads(dd[jk])
                except Exception:
                    dd[jk.replace("_json", "")] = []
        return dd, None
    return None, "Failed to create department"


def update_facility_department(facility_id, department_id, dept_data, actor_id="admin_user", actor_role="admin"):
    """Updates an existing clinical department in a facility."""
    auth_ok, auth_err = is_authorized_for_facility(actor_id, actor_role, facility_id)
    if not auth_ok:
        return None, auth_err

    conn = get_db_connection()
    now_str = datetime.now(timezone.utc).isoformat()
    existing = conn.execute("SELECT * FROM facility_departments WHERE facility_id = ? AND department_id = ?", (facility_id, department_id)).fetchone()
    if not existing:
        conn.close()
        return None, f"Department {department_id} not found in facility {facility_id}"

    specs_json = json.dumps(dept_data["specialties"]) if "specialties" in dept_data else None
    servs_json = json.dumps(dept_data["services"]) if "services" in dept_data else None
    care_json = json.dumps(dept_data["care_levels"]) if "care_levels" in dept_data else None

    conn.execute(
        """
        UPDATE facility_departments SET
            department_name = COALESCE(?, department_name),
            specialties_json = COALESCE(?, specialties_json),
            services_json = COALESCE(?, services_json),
            operational_days = COALESCE(?, operational_days),
            operating_hours = COALESCE(?, operating_hours),
            appointment_mode = COALESCE(?, appointment_mode),
            emergency_available = COALESCE(?, emergency_available),
            specialist_coverage = COALESCE(?, specialist_coverage),
            care_levels_json = COALESCE(?, care_levels_json),
            head_of_department = COALESCE(?, head_of_department),
            is_operational = COALESCE(?, is_operational),
            temporary_closure_reason = COALESCE(?, temporary_closure_reason),
            last_updated_at = ?
        WHERE facility_id = ? AND department_id = ?
        """,
        (
            dept_data.get("department_name"),
            specs_json,
            servs_json,
            dept_data.get("operational_days"),
            dept_data.get("operating_hours"),
            dept_data.get("appointment_mode"),
            dept_data.get("emergency_available"),
            dept_data.get("specialist_coverage"),
            care_json,
            dept_data.get("head_of_department"),
            dept_data.get("is_operational"),
            dept_data.get("temporary_closure_reason"),
            now_str,
            facility_id,
            department_id,
        ),
    )
    conn.commit()
    row = conn.execute("SELECT * FROM facility_departments WHERE department_id = ?", (department_id,)).fetchone()
    conn.close()
    if row:
        dd = dict(row)
        for jk in ["specialties_json", "services_json", "care_levels_json"]:
            if dd.get(jk):
                try:
                    dd[jk.replace("_json", "")] = json.loads(dd[jk])
                except Exception:
                    dd[jk.replace("_json", "")] = []
        return dd, None
    return None, "Failed to update department"


def delete_facility_department(facility_id, department_id, actor_id="admin_user", actor_role="admin"):
    """Deletes or deactivates a clinical department."""
    auth_ok, auth_err = is_authorized_for_facility(actor_id, actor_role, facility_id)
    if not auth_ok:
        return False, auth_err

    conn = get_db_connection()
    conn.execute(
        "DELETE FROM facility_departments WHERE facility_id = ? AND department_id = ?",
        (facility_id, department_id),
    )
    conn.commit()
    conn.close()
    return True, None


# ============================================================================
# Gemini Symptom Analysis, Custom Tags, Sync Queue & Referral Lifecycle
# ============================================================================

def _migrate_gemini_and_offline_tables(conn):
    """Ensures Gemini symptom assessment, custom clinical tags, sync queue, and referral lifecycle tables exist."""
    cur = conn.cursor()
    cur.execute("""
    CREATE TABLE IF NOT EXISTS symptom_assessments (
        assessment_id TEXT PRIMARY KEY,
        patient_id TEXT NOT NULL,
        free_text_description TEXT NOT NULL,
        extracted_symptoms_json TEXT NOT NULL DEFAULT '[]',
        tags_json TEXT NOT NULL DEFAULT '[]',
        urgency_level INTEGER NOT NULL DEFAULT 4,
        urgency_label TEXT NOT NULL DEFAULT 'Level 4 — Routine Assessment',
        referral_level TEXT NOT NULL DEFAULT 'Referral A',
        referral_label TEXT NOT NULL DEFAULT 'Referral A — Local Clinic/Primary Care',
        assessment_source TEXT NOT NULL DEFAULT 'offline_rules',
        model_version TEXT DEFAULT 'gemini-1.5-flash',
        ruleset_version TEXT DEFAULT 'indore-clinical-safety-v1',
        reasoning TEXT NOT NULL,
        red_flags_json TEXT NOT NULL DEFAULT '[]',
        missing_information_json TEXT NOT NULL DEFAULT '[]',
        follow_up_questions_json TEXT NOT NULL DEFAULT '[]',
        clinician_review_status TEXT NOT NULL DEFAULT 'unreviewed',
        reviewed_by TEXT,
        clinician_notes TEXT,
        override_reason TEXT,
        sync_status TEXT NOT NULL DEFAULT 'synchronized',
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now'))
    )
    """)

    cur.execute("""
    CREATE TABLE IF NOT EXISTS custom_clinical_tags (
        tag_id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        category TEXT NOT NULL DEFAULT 'general',
        is_builtin INTEGER NOT NULL DEFAULT 0,
        is_ai_suggested INTEGER NOT NULL DEFAULT 0,
        created_by TEXT NOT NULL DEFAULT 'Clinician',
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now')),
        revision INTEGER NOT NULL DEFAULT 1,
        deleted_at TEXT
    )
    """)

    cur.execute("""
    CREATE TABLE IF NOT EXISTS offline_sync_queue (
        queue_id TEXT PRIMARY KEY,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        action TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        idempotency_key TEXT NOT NULL UNIQUE,
        status TEXT NOT NULL DEFAULT 'completed',
        retry_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        synced_at TEXT NOT NULL DEFAULT (datetime('now'))
    )
    """)

    cur.execute("""
    CREATE TABLE IF NOT EXISTS referral_lifecycle_tracking (
        referral_id TEXT PRIMARY KEY,
        patient_id TEXT NOT NULL,
        receiving_facility_id TEXT NOT NULL,
        current_state TEXT NOT NULL DEFAULT 'assessment_saved',
        is_ambulance_dispatched INTEGER NOT NULL DEFAULT 0,
        ambulance_dispatch_source TEXT,
        ambulance_dispatched_at TEXT,
        delivery_confirmed_at TEXT,
        facility_acknowledged_at TEXT,
        facility_acknowledged_by TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (receiving_facility_id) REFERENCES healthcare_facilities(facility_id) ON DELETE CASCADE
    )
    """)

    cur.execute("CREATE INDEX IF NOT EXISTS idx_symptom_assessments_patient ON symptom_assessments(patient_id)")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_tags_category ON custom_clinical_tags(category)")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_sync_queue_idempotency ON offline_sync_queue(idempotency_key)")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_ref_lifecycle_state ON referral_lifecycle_tracking(current_state)")


def _seed_clinical_tags(conn):
    """Seeds initial built-in clinical tags if not already present."""
    cur = conn.cursor()
    cur.execute("SELECT COUNT(*) FROM custom_clinical_tags WHERE is_builtin = 1")
    if cur.fetchone()[0] > 0:
        return

    builtin_tags = [
        ("Possible cardiac symptoms", "cardiac"),
        ("Breathing difficulty", "respiratory"),
        ("Neurological warning signs", "neurology"),
        ("Suspected infection", "infection"),
        ("Injury or trauma", "trauma"),
        ("Pregnancy-related concern", "obstetric"),
        ("Pediatric concern", "pediatric"),
        ("Diagnostic information missing", "general"),
        ("High fever / Sepsis risk", "infection"),
        ("Acute abdominal pain", "general"),
        ("Severe dehydration", "general"),
        ("Active hemorrhage", "trauma"),
        ("Hypertensive crisis", "cardiac"),
        ("Altered mental status", "neurology"),
        ("Orthopedic compound fracture", "trauma"),
    ]

    now_str = datetime.now(timezone.utc).isoformat()
    for name, cat in builtin_tags:
        tag_id = f"tag_builtin_{uuid.uuid4().hex[:8]}"
        cur.execute(
            """
            INSERT OR IGNORE INTO custom_clinical_tags (tag_id, name, category, is_builtin, is_ai_suggested, created_by, created_at, updated_at, revision)
            VALUES (?, ?, ?, 1, 0, 'Central Clinical Committee', ?, ?, 1)
            """,
            (tag_id, name, cat, now_str, now_str),
        )


def save_symptom_assessment(data: Dict[str, Any]) -> Dict[str, Any]:
    """Saves or updates a symptom assessment in the central database."""
    conn = get_db_connection()
    now_str = datetime.now(timezone.utc).isoformat()
    assessment_id = data.get("assessment_id") or f"asmt_{uuid.uuid4().hex[:10]}"
    patient_id = data.get("patient_id") or "PAT-UNSPECIFIED"

    extracted_symptoms_json = json.dumps(data.get("extracted_symptoms") or [])
    tags_json = json.dumps(data.get("suggested_tags") or data.get("tags") or [])
    red_flags_json = json.dumps(data.get("red_flags") or [])
    missing_info_json = json.dumps(data.get("missing_information") or [])
    follow_up_json = json.dumps(data.get("follow_up_questions") or [])

    conn.execute(
        """
        INSERT INTO symptom_assessments (
            assessment_id, patient_id, free_text_description, extracted_symptoms_json,
            tags_json, urgency_level, urgency_label, referral_level, referral_label,
            assessment_source, model_version, ruleset_version, reasoning, red_flags_json,
            missing_information_json, follow_up_questions_json, clinician_review_status,
            reviewed_by, clinician_notes, override_reason, sync_status, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(assessment_id) DO UPDATE SET
            free_text_description = excluded.free_text_description,
            extracted_symptoms_json = excluded.extracted_symptoms_json,
            tags_json = excluded.tags_json,
            urgency_level = excluded.urgency_level,
            urgency_label = excluded.urgency_label,
            referral_level = excluded.referral_level,
            referral_label = excluded.referral_label,
            assessment_source = excluded.assessment_source,
            reasoning = excluded.reasoning,
            red_flags_json = excluded.red_flags_json,
            missing_information_json = excluded.missing_information_json,
            follow_up_questions_json = excluded.follow_up_questions_json,
            clinician_review_status = excluded.clinician_review_status,
            reviewed_by = excluded.reviewed_by,
            clinician_notes = excluded.clinician_notes,
            override_reason = excluded.override_reason,
            sync_status = excluded.sync_status,
            updated_at = excluded.updated_at
        """,
        (
            assessment_id,
            patient_id,
            data.get("free_text_description") or data.get("free_text") or "",
            extracted_symptoms_json,
            tags_json,
            int(data.get("urgency_level", 4)),
            data.get("urgency_label", "Level 4 — Routine Assessment"),
            data.get("referral_level", "Referral A"),
            data.get("referral_label", "Referral A — Local Clinic/Primary Care"),
            data.get("assessment_source", "offline_rules"),
            data.get("model_version", "gemini-1.5-flash"),
            data.get("ruleset_version", "indore-clinical-safety-v1"),
            data.get("reasoning", "Assessment recorded."),
            red_flags_json,
            missing_info_json,
            follow_up_json,
            data.get("clinician_review_status", "unreviewed"),
            data.get("reviewed_by"),
            data.get("clinician_notes"),
            data.get("override_reason"),
            data.get("sync_status", "synchronized"),
            data.get("created_at") or now_str,
            now_str,
        ),
    )
    conn.commit()
    row = conn.execute("SELECT * FROM symptom_assessments WHERE assessment_id = ?", (assessment_id,)).fetchone()
    conn.close()
    return dict(row) if row else None


def get_symptom_assessment(assessment_id: str) -> Dict[str, Any]:
    """Retrieves a single symptom assessment by ID."""
    conn = get_db_connection()
    row = conn.execute("SELECT * FROM symptom_assessments WHERE assessment_id = ?", (assessment_id,)).fetchone()
    conn.close()
    return dict(row) if row else None


def get_patient_assessments(patient_id: str) -> List[Dict[str, Any]]:
    """Retrieves all symptom assessments for a given patient identifier."""
    conn = get_db_connection()
    rows = conn.execute(
        "SELECT * FROM symptom_assessments WHERE patient_id = ? ORDER BY created_at DESC", (patient_id,)
    ).fetchall()
    conn.close()
    return [dict(r) for r in rows]


def get_all_clinical_tags() -> List[Dict[str, Any]]:
    """Retrieves all active clinical tags (built-in and clinician created)."""
    conn = get_db_connection()
    rows = conn.execute(
        "SELECT * FROM custom_clinical_tags WHERE deleted_at IS NULL ORDER BY is_builtin DESC, name ASC"
    ).fetchall()
    conn.close()
    return [dict(r) for r in rows]


def add_clinical_tag(name: str, category: str = "general", created_by: str = "Clinician", is_builtin: int = 0, is_ai_suggested: int = 0) -> Tuple[Dict[str, Any], str]:
    """Creates or restores a clinical tag with input sanitization."""
    cleaned_name = name.strip()
    if len(cleaned_name) < 2 or len(cleaned_name) > 60:
        return None, "Tag name must be between 2 and 60 characters."

    conn = get_db_connection()
    now_str = datetime.now(timezone.utc).isoformat()
    existing = conn.execute("SELECT * FROM custom_clinical_tags WHERE LOWER(name) = LOWER(?)", (cleaned_name,)).fetchone()

    if existing:
        if existing["deleted_at"] is not None:
            conn.execute(
                "UPDATE custom_clinical_tags SET deleted_at = NULL, updated_at = ?, revision = revision + 1 WHERE tag_id = ?",
                (now_str, existing["tag_id"]),
            )
            conn.commit()
            updated = conn.execute("SELECT * FROM custom_clinical_tags WHERE tag_id = ?", (existing["tag_id"],)).fetchone()
            conn.close()
            return dict(updated), None
        conn.close()
        return dict(existing), None

    tag_id = f"tag_{uuid.uuid4().hex[:10]}"
    conn.execute(
        """
        INSERT INTO custom_clinical_tags (tag_id, name, category, is_builtin, is_ai_suggested, created_by, created_at, updated_at, revision)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1)
        """,
        (tag_id, cleaned_name, category, is_builtin, is_ai_suggested, created_by, now_str, now_str),
    )
    conn.commit()
    row = conn.execute("SELECT * FROM custom_clinical_tags WHERE tag_id = ?", (tag_id,)).fetchone()
    conn.close()
    return dict(row), None


def delete_clinical_tag(tag_id: str) -> bool:
    """Soft-deletes a custom tag."""
    conn = get_db_connection()
    now_str = datetime.now(timezone.utc).isoformat()
    conn.execute("UPDATE custom_clinical_tags SET deleted_at = ?, updated_at = ? WHERE tag_id = ?", (now_str, now_str, tag_id))
    conn.commit()
    conn.close()
    return True


def update_referral_lifecycle(
    referral_id: str,
    patient_id: str,
    receiving_facility_id: str,
    new_state: str,
    is_ambulance_dispatched: bool = False,
    ambulance_source: str = None,
    facility_acknowledged_by: str = None,
) -> Tuple[Dict[str, Any], str]:
    """Updates referral delivery lifecycle state enforcing strict safety truthfulness."""
    valid_states = [
        "assessment_saved",
        "referral_draft_saved_locally",
        "referral_queued_for_transmission",
        "referral_successfully_sent",
        "delivery_confirmed",
        "receiving_facility_acknowledged",
        "ambulance_dispatched",
    ]
    if new_state not in valid_states:
        return None, f"Invalid referral lifecycle state '{new_state}'."

    conn = get_db_connection()
    now_str = datetime.now(timezone.utc).isoformat()

    existing = conn.execute("SELECT * FROM referral_lifecycle_tracking WHERE referral_id = ?", (referral_id,)).fetchone()
    
    amb_time = now_str if (is_ambulance_dispatched or new_state == "ambulance_dispatched") else (existing["ambulance_dispatched_at"] if existing else None)
    del_time = now_str if new_state in ["delivery_confirmed", "receiving_facility_acknowledged"] else (existing["delivery_confirmed_at"] if existing else None)
    ack_time = now_str if new_state == "receiving_facility_acknowledged" else (existing["facility_acknowledged_at"] if existing else None)

    conn.execute(
        """
        INSERT INTO referral_lifecycle_tracking (
            referral_id, patient_id, receiving_facility_id, current_state, is_ambulance_dispatched,
            ambulance_dispatch_source, ambulance_dispatched_at, delivery_confirmed_at,
            facility_acknowledged_at, facility_acknowledged_by, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(referral_id) DO UPDATE SET
            current_state = excluded.current_state,
            is_ambulance_dispatched = CASE WHEN excluded.is_ambulance_dispatched = 1 THEN 1 ELSE referral_lifecycle_tracking.is_ambulance_dispatched END,
            ambulance_dispatch_source = COALESCE(excluded.ambulance_dispatch_source, referral_lifecycle_tracking.ambulance_dispatch_source),
            ambulance_dispatched_at = COALESCE(excluded.ambulance_dispatched_at, referral_lifecycle_tracking.ambulance_dispatched_at),
            delivery_confirmed_at = COALESCE(excluded.delivery_confirmed_at, referral_lifecycle_tracking.delivery_confirmed_at),
            facility_acknowledged_at = COALESCE(excluded.facility_acknowledged_at, referral_lifecycle_tracking.facility_acknowledged_at),
            facility_acknowledged_by = COALESCE(excluded.facility_acknowledged_by, referral_lifecycle_tracking.facility_acknowledged_by),
            updated_at = excluded.updated_at
        """,
        (
            referral_id,
            patient_id,
            receiving_facility_id,
            new_state,
            1 if (is_ambulance_dispatched or new_state == "ambulance_dispatched") else 0,
            ambulance_source,
            amb_time,
            del_time,
            ack_time,
            facility_acknowledged_by,
            now_str,
            now_str,
        ),
    )
    conn.commit()
    row = conn.execute("SELECT * FROM referral_lifecycle_tracking WHERE referral_id = ?", (referral_id,)).fetchone()
    conn.close()
    return dict(row), None


def get_referral_lifecycle(referral_id: str) -> Dict[str, Any]:
    """Fetches lifecycle state for a referral."""
    conn = get_db_connection()
    row = conn.execute("SELECT * FROM referral_lifecycle_tracking WHERE referral_id = ?", (referral_id,)).fetchone()
    conn.close()
    return dict(row) if row else None


def process_offline_sync_batch(items: List[Dict[str, Any]]) -> Dict[str, Any]:
    """Processes a batch of offline synchronized mutations with idempotency guarantees."""
    conn = get_db_connection()
    now_str = datetime.now(timezone.utc).isoformat()
    processed = []
    skipped = []

    for item in items:
        idempotency_key = item.get("idempotency_key")
        if not idempotency_key:
            idempotency_key = f"idem_{uuid.uuid4().hex}"

        existing = conn.execute("SELECT * FROM offline_sync_queue WHERE idempotency_key = ?", (idempotency_key,)).fetchone()
        if existing and existing["status"] == "completed":
            skipped.append({"idempotency_key": idempotency_key, "reason": "Already synchronized (idempotent)"})
            continue

        queue_id = item.get("queue_id") or f"queue_{uuid.uuid4().hex[:8]}"
        entity_type = item.get("entity_type", "assessment")
        entity_id = item.get("entity_id", "unspecified")
        action = item.get("action", "create")
        payload = item.get("payload") or {}

        try:
            if entity_type == "assessment":
                save_symptom_assessment(payload)
            elif entity_type == "tag":
                add_clinical_tag(
                    name=payload.get("name", "New Tag"),
                    category=payload.get("category", "general"),
                    created_by=payload.get("created_by", "Offline Clinician"),
                )
            elif entity_type == "referral":
                update_referral_lifecycle(
                    referral_id=payload.get("referral_id", entity_id),
                    patient_id=payload.get("patient_id", "PAT-OFFLINE"),
                    receiving_facility_id=payload.get("receiving_facility_id", "indore_hospital_001"),
                    new_state=payload.get("current_state", "referral_successfully_sent"),
                    is_ambulance_dispatched=payload.get("is_ambulance_dispatched", False),
                    ambulance_source=payload.get("ambulance_source"),
                )

            conn.execute(
                """
                INSERT INTO offline_sync_queue (queue_id, entity_type, entity_id, action, payload_json, idempotency_key, status, retry_count, created_at, synced_at)
                VALUES (?, ?, ?, ?, ?, ?, 'completed', 0, ?, ?)
                ON CONFLICT(idempotency_key) DO UPDATE SET status = 'completed', synced_at = excluded.synced_at
                """,
                (queue_id, entity_type, entity_id, action, json.dumps(payload), idempotency_key, now_str, now_str),
            )
            processed.append({"idempotency_key": idempotency_key, "entity_type": entity_type, "entity_id": entity_id, "status": "synced"})
        except Exception as e:
            conn.execute(
                """
                INSERT INTO offline_sync_queue (queue_id, entity_type, entity_id, action, payload_json, idempotency_key, status, retry_count, last_error, created_at, synced_at)
                VALUES (?, ?, ?, ?, ?, ?, 'failed', 1, ?, ?, ?)
                ON CONFLICT(idempotency_key) DO UPDATE SET status = 'failed', last_error = excluded.last_error, retry_count = offline_sync_queue.retry_count + 1
                """,
                (queue_id, entity_type, entity_id, action, json.dumps(payload), idempotency_key, str(e), now_str, now_str),
            )
            skipped.append({"idempotency_key": idempotency_key, "error": str(e)})

    conn.commit()
    conn.close()
    return {
        "status": "success",
        "processed_count": len(processed),
        "skipped_count": len(skipped),
        "processed": processed,
        "skipped": skipped,
        "server_time": now_str,
    }


