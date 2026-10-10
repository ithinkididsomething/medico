-- ============================================================================
-- SMART Referral Central Authoritative Healthcare Database Schema
-- Version: 1.0.0
-- Supports: Multi-facility registry, revision-based sync, operational freshness,
-- audit trails, and role-based authorization.
-- ============================================================================

PRAGMA foreign_keys = ON;

-- 1. Roles and Permissions Table
CREATE TABLE IF NOT EXISTS roles_and_permissions (
    role_id TEXT PRIMARY KEY,
    role_name TEXT NOT NULL,
    description TEXT,
    can_modify_facilities INTEGER NOT NULL DEFAULT 0,
    can_modify_verification INTEGER NOT NULL DEFAULT 0,
    can_update_operational_status INTEGER NOT NULL DEFAULT 1,
    can_view_audit_logs INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- 2. Master Healthcare Facilities Table
CREATE TABLE IF NOT EXISTS healthcare_facilities (
    facility_id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    address TEXT NOT NULL,
    latitude REAL NOT NULL,
    longitude REAL NOT NULL,
    facility_type TEXT NOT NULL,
    emergency_care INTEGER NOT NULL DEFAULT 0,
    icu_available INTEGER NOT NULL DEFAULT 0,
    current_capacity REAL NOT NULL DEFAULT 0.0,
    bed_availability INTEGER NOT NULL DEFAULT 0,
    operating_status TEXT NOT NULL DEFAULT 'Operational',
    tags TEXT NOT NULL DEFAULT '[]', -- JSON array of tags
    is_verified INTEGER NOT NULL DEFAULT 0,
    verification_tier TEXT NOT NULL DEFAULT 'District Health Authority',
    is_simulated_data INTEGER NOT NULL DEFAULT 0,
    data_source TEXT NOT NULL DEFAULT 'Indore Health Network Registry',
    revision INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    deleted_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_facilities_revision ON healthcare_facilities(revision);
CREATE INDEX IF NOT EXISTS idx_facilities_updated_at ON healthcare_facilities(updated_at);
CREATE INDEX IF NOT EXISTS idx_facilities_emergency ON healthcare_facilities(emergency_care);

-- 3. Facility Clinical Services Table
CREATE TABLE IF NOT EXISTS facility_services (
    service_id INTEGER PRIMARY KEY AUTOINCREMENT,
    facility_id TEXT NOT NULL,
    service_name TEXT NOT NULL,
    service_category TEXT NOT NULL DEFAULT 'Clinical Specialty',
    is_active INTEGER NOT NULL DEFAULT 1,
    revision INTEGER NOT NULL DEFAULT 1,
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (facility_id) REFERENCES healthcare_facilities(facility_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_services_facility ON facility_services(facility_id);
CREATE INDEX IF NOT EXISTS idx_services_name ON facility_services(service_name);

-- 4. Facility Equipment and Capabilities Table
CREATE TABLE IF NOT EXISTS facility_capabilities (
    capability_id INTEGER PRIMARY KEY AUTOINCREMENT,
    facility_id TEXT NOT NULL,
    capability_name TEXT NOT NULL,
    capability_type TEXT NOT NULL DEFAULT 'treatment', -- 'diagnostic' or 'treatment'
    is_available INTEGER NOT NULL DEFAULT 1,
    revision INTEGER NOT NULL DEFAULT 1,
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (facility_id) REFERENCES healthcare_facilities(facility_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_capabilities_facility ON facility_capabilities(facility_id);

-- 5. Time-Sensitive Operational Status Table
CREATE TABLE IF NOT EXISTS facility_operational_status (
    status_id INTEGER PRIMARY KEY AUTOINCREMENT,
    facility_id TEXT NOT NULL UNIQUE,
    operating_status TEXT NOT NULL DEFAULT 'Operational', -- 'Operational', 'Busy', 'Diverting', 'Closed'
    general_beds_available INTEGER NOT NULL DEFAULT 0,
    icu_beds_available INTEGER NOT NULL DEFAULT 0,
    operating_theaters_available INTEGER NOT NULL DEFAULT 0,
    ambulance_available INTEGER NOT NULL DEFAULT 1,
    current_capacity REAL NOT NULL DEFAULT 0.0,
    emergency_department_open INTEGER NOT NULL DEFAULT 1,
    last_reported_at TEXT NOT NULL DEFAULT (datetime('now')),
    reported_by_user TEXT NOT NULL DEFAULT 'Duty Medical Officer',
    freshness_ttl_seconds INTEGER NOT NULL DEFAULT 1800, -- 30 minutes TTL
    is_verified_live INTEGER NOT NULL DEFAULT 0,
    revision INTEGER NOT NULL DEFAULT 1,
    FOREIGN KEY (facility_id) REFERENCES healthcare_facilities(facility_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_operational_facility ON facility_operational_status(facility_id);
CREATE INDEX IF NOT EXISTS idx_operational_last_reported ON facility_operational_status(last_reported_at);

-- 6. Facility Verification Records Table
CREATE TABLE IF NOT EXISTS facility_verification_records (
    record_id INTEGER PRIMARY KEY AUTOINCREMENT,
    facility_id TEXT NOT NULL,
    verified_by_user TEXT NOT NULL,
    verification_tier TEXT NOT NULL DEFAULT 'District Health Authority',
    verification_method TEXT NOT NULL DEFAULT 'Government Registry & On-site Audit',
    verification_date TEXT NOT NULL DEFAULT (datetime('now')),
    expires_at TEXT,
    notes TEXT,
    is_active INTEGER NOT NULL DEFAULT 1,
    FOREIGN KEY (facility_id) REFERENCES healthcare_facilities(facility_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_verification_facility ON facility_verification_records(facility_id);

-- 7. Sync Metadata Table (Device cursor and changelog)
CREATE TABLE IF NOT EXISTS sync_metadata (
    device_id TEXT PRIMARY KEY,
    last_sync_revision INTEGER NOT NULL DEFAULT 0,
    last_sync_timestamp TEXT NOT NULL DEFAULT (datetime('now')),
    app_version TEXT NOT NULL DEFAULT '1.0.0',
    client_ip TEXT
);

-- 8. Audit Logs Table
CREATE TABLE IF NOT EXISTS audit_logs (
    log_id INTEGER PRIMARY KEY AUTOINCREMENT,
    facility_id TEXT,
    action TEXT NOT NULL, -- 'CREATE', 'UPDATE_CAPABILITY', 'UPDATE_STATUS', 'VERIFY', 'SYNC_PUSH'
    actor_id TEXT NOT NULL DEFAULT 'anonymous',
    actor_role TEXT NOT NULL DEFAULT 'clinician',
    changes_json TEXT NOT NULL DEFAULT '{}',
    ip_address TEXT,
    timestamp TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_audit_facility ON audit_logs(facility_id);
CREATE INDEX IF NOT EXISTS idx_audit_timestamp ON audit_logs(timestamp);

-- ============================================================================
-- DOCTOR REGISTRATION, CREDENTIALING, AND VERIFICATION TABLES
-- ============================================================================

-- 9. Doctor Profiles Table
CREATE TABLE IF NOT EXISTS doctor_profiles (
    doctor_id TEXT PRIMARY KEY,
    user_id TEXT UNIQUE,
    full_name TEXT NOT NULL,
    display_name TEXT,
    email TEXT NOT NULL UNIQUE,
    phone_number TEXT NOT NULL UNIQUE,
    preferred_language TEXT NOT NULL DEFAULT 'English',
    profile_photo_url TEXT,
    primary_practice_environment TEXT NOT NULL,
    total_experience_years INTEGER NOT NULL DEFAULT 0,
    current_designation TEXT NOT NULL,
    department TEXT,
    years_at_current_facility INTEGER NOT NULL DEFAULT 0,
    years_independent_practice INTEGER DEFAULT 0,
    previous_affiliations TEXT DEFAULT '[]',
    annual_patient_volume INTEGER DEFAULT 0,
    followup_experience_summary TEXT,
    procedure_experience_summary TEXT,
    teaching_research_summary TEXT,
    association_memberships TEXT DEFAULT '[]',
    government_schemes_summary TEXT,
    verification_status TEXT NOT NULL DEFAULT 'pending', -- 'pending', 'verified', 'rejected', 'needs_more_info', 'unverified_demo'
    rejection_reason TEXT,
    is_synthetic INTEGER NOT NULL DEFAULT 0,
    record_source TEXT NOT NULL DEFAULT 'registration', -- 'synthetic_demo', 'registration'
    primary_specialty TEXT,
    secondary_specialties TEXT DEFAULT '[]',
    clinical_capabilities TEXT DEFAULT '[]',
    procedure_capabilities TEXT DEFAULT '[]',
    emergency_capabilities TEXT DEFAULT '[]',
    critical_care_capabilities TEXT DEFAULT '[]',
    diagnostic_capabilities TEXT DEFAULT '[]',
    normalized_capability_score REAL DEFAULT 0.0,
    score_breakdown TEXT DEFAULT '{}',
    score_last_calculated_at TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_doctors_email ON doctor_profiles(email);
CREATE INDEX IF NOT EXISTS idx_doctors_phone ON doctor_profiles(phone_number);
CREATE INDEX IF NOT EXISTS idx_doctors_status ON doctor_profiles(verification_status);

-- 10. Doctor Qualifications Table
CREATE TABLE IF NOT EXISTS doctor_qualifications (
    qualification_id INTEGER PRIMARY KEY AUTOINCREMENT,
    doctor_id TEXT NOT NULL,
    qualification_type TEXT NOT NULL, -- 'primary_mbbs', 'postgraduate_md_ms_dnb', 'super_specialty_dm_mch', 'diploma_fellowship'
    qualification_name TEXT NOT NULL,
    institution TEXT NOT NULL,
    completion_year INTEGER NOT NULL,
    primary_specialty TEXT NOT NULL,
    additional_specialties TEXT DEFAULT '[]',
    certifications TEXT DEFAULT '[]',
    is_verified INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (doctor_id) REFERENCES doctor_profiles(doctor_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_qualifications_doctor ON doctor_qualifications(doctor_id);

-- 11. Doctor Registrations Table
CREATE TABLE IF NOT EXISTS doctor_registrations (
    registration_id INTEGER PRIMARY KEY AUTOINCREMENT,
    doctor_id TEXT NOT NULL UNIQUE,
    council_name TEXT NOT NULL, -- NMC, State Medical Council
    registration_number TEXT NOT NULL UNIQUE,
    registration_year INTEGER NOT NULL,
    registration_status TEXT NOT NULL DEFAULT 'active',
    is_verified INTEGER NOT NULL DEFAULT 0,
    verified_at TEXT,
    verified_by TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (doctor_id) REFERENCES doctor_profiles(doctor_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_reg_num ON doctor_registrations(registration_number);
CREATE INDEX IF NOT EXISTS idx_reg_doctor ON doctor_registrations(doctor_id);

-- 12. Doctor Facility Affiliations Table
CREATE TABLE IF NOT EXISTS doctor_facility_affiliations (
    affiliation_id INTEGER PRIMARY KEY AUTOINCREMENT,
    doctor_id TEXT NOT NULL,
    facility_id TEXT NOT NULL,
    facility_name TEXT NOT NULL,
    designation TEXT NOT NULL,
    years_at_facility INTEGER NOT NULL DEFAULT 0,
    is_primary INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (doctor_id) REFERENCES doctor_profiles(doctor_id) ON DELETE CASCADE,
    FOREIGN KEY (facility_id) REFERENCES healthcare_facilities(facility_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_affiliations_doctor ON doctor_facility_affiliations(doctor_id);
CREATE INDEX IF NOT EXISTS idx_affiliations_facility ON doctor_facility_affiliations(facility_id);

-- 13. Doctor Capabilities Table
CREATE TABLE IF NOT EXISTS doctor_capabilities (
    capability_id INTEGER PRIMARY KEY AUTOINCREMENT,
    doctor_id TEXT NOT NULL,
    capability_key TEXT NOT NULL,
    capability_label TEXT NOT NULL,
    is_claimed INTEGER NOT NULL DEFAULT 1,
    is_verified INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (doctor_id) REFERENCES doctor_profiles(doctor_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_doc_capabilities ON doctor_capabilities(doctor_id);

-- 14. Doctor Evidence Documents Table
CREATE TABLE IF NOT EXISTS doctor_evidence_documents (
    document_id TEXT PRIMARY KEY,
    doctor_id TEXT NOT NULL,
    document_type TEXT NOT NULL, -- 'registration_certificate', 'qualification_degree', 'experience_letter', 'empanelment_letter'
    file_name TEXT NOT NULL,
    file_size_bytes INTEGER NOT NULL,
    mime_type TEXT NOT NULL,
    storage_path TEXT NOT NULL,
    sha256_hash TEXT NOT NULL,
    verification_status TEXT NOT NULL DEFAULT 'pending',
    uploaded_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (doctor_id) REFERENCES doctor_profiles(doctor_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_documents_doctor ON doctor_evidence_documents(doctor_id);

-- 15. Doctor Verification Records Table
CREATE TABLE IF NOT EXISTS doctor_verification_records (
    record_id INTEGER PRIMARY KEY AUTOINCREMENT,
    doctor_id TEXT NOT NULL,
    reviewer_id TEXT NOT NULL,
    review_decision TEXT NOT NULL, -- 'approved', 'rejected', 'requested_info'
    rejection_reason TEXT,
    review_notes TEXT,
    reviewed_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (doctor_id) REFERENCES doctor_profiles(doctor_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_doc_verif_record ON doctor_verification_records(doctor_id);

-- 16. Doctor Capability Scores Table (4-Pillar Normalized Algorithm)
CREATE TABLE IF NOT EXISTS doctor_capability_scores (
    score_id INTEGER PRIMARY KEY AUTOINCREMENT,
    doctor_id TEXT NOT NULL UNIQUE,
    base_expertise_score REAL NOT NULL DEFAULT 0.0,      -- Max 30%
    clinical_experience_score REAL NOT NULL DEFAULT 0.0, -- Max 30%
    clinical_volume_score REAL NOT NULL DEFAULT 0.0,     -- Max 25%
    professional_standing_score REAL NOT NULL DEFAULT 0.0, -- Max 15%
    total_capability_score REAL NOT NULL DEFAULT 0.0,    -- Max 100%
    is_provisional INTEGER NOT NULL DEFAULT 1,
    scoring_version TEXT NOT NULL DEFAULT '1.0.0',
    calculated_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (doctor_id) REFERENCES doctor_profiles(doctor_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_doc_scores ON doctor_capability_scores(doctor_id);

-- 17. Doctor Audit Logs Table
CREATE TABLE IF NOT EXISTS doctor_audit_logs (
    log_id INTEGER PRIMARY KEY AUTOINCREMENT,
    doctor_id TEXT NOT NULL,
    action TEXT NOT NULL,
    actor_id TEXT NOT NULL,
    actor_role TEXT NOT NULL,
    details_json TEXT NOT NULL DEFAULT '{}',
    timestamp TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_doc_audit ON doctor_audit_logs(doctor_id);

-- 18. Idempotency Keys (for retry prevention)
CREATE TABLE IF NOT EXISTS idempotency_keys (
    key TEXT PRIMARY KEY,
    response_json TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- ============================================================================
-- CONDITION-SPECIFIC HIERARCHICAL RANKING & SYNTHETIC DATA TABLES
-- ============================================================================

-- 19. Condition Capability Requirements Table
CREATE TABLE IF NOT EXISTS condition_capability_requirements (
    condition_key TEXT PRIMARY KEY,
    condition_name TEXT NOT NULL,
    urgency_level TEXT NOT NULL, -- 'immediate', 'urgent', 'standard', 'routine'
    required_specialties TEXT NOT NULL DEFAULT '[]', -- JSON array
    essential_doctor_capabilities TEXT NOT NULL DEFAULT '[]', -- JSON array
    essential_equipment TEXT NOT NULL DEFAULT '[]', -- JSON array
    emergency_stabilization_required INTEGER NOT NULL DEFAULT 1,
    critical_care_required INTEGER NOT NULL DEFAULT 0,
    supporting_capabilities TEXT NOT NULL DEFAULT '[]', -- JSON array
    acceptable_referral_fallback TEXT NOT NULL,
    required_data_freshness_hours INTEGER NOT NULL DEFAULT 24,
    capability_rationales TEXT NOT NULL DEFAULT '{}' -- JSON object
);

CREATE INDEX IF NOT EXISTS idx_condition_urgency ON condition_capability_requirements(urgency_level);

-- 20. Facility Resource Inventory Table
CREATE TABLE IF NOT EXISTS facility_resource_inventory (
    inventory_id INTEGER PRIMARY KEY AUTOINCREMENT,
    facility_id TEXT NOT NULL,
    resource_id TEXT,
    resource_type TEXT NOT NULL, -- 'equipment', 'service', 'diagnostics'
    resource_category TEXT NOT NULL DEFAULT 'diagnostic_and_imaging', -- 'diagnostic_and_imaging', 'critical_care_and_life_support', 'surgical_and_theatre', 'emergency_and_trauma', 'laboratory_and_pathology', 'specialized_treatment', 'telemedicine_and_digital_health'
    resource_name TEXT NOT NULL,
    model_spec TEXT,
    quantity_installed INTEGER NOT NULL DEFAULT 1,
    quantity_operational INTEGER NOT NULL DEFAULT 1,
    quantity_out_of_service INTEGER NOT NULL DEFAULT 0,
    operational_status TEXT NOT NULL DEFAULT 'operational', -- 'operational', 'limited_capacity', 'maintenance', 'decommissioned'
    location_in_facility TEXT NOT NULL DEFAULT 'Main Clinical Block',
    ownership_type TEXT NOT NULL DEFAULT 'in_house_owned', -- 'in_house_owned', 'leased', 'partner_onsite', 'outsourced_offsite'
    service_delivery TEXT NOT NULL DEFAULT 'in_house', -- 'in_house', 'outsourced'
    turnaround_time_hours INTEGER NOT NULL DEFAULT 0,
    availability_schedule TEXT NOT NULL DEFAULT '24/7', -- '24/7', 'daytime_only', 'on_call', 'scheduled_batches'
    last_maintenance_date TEXT,
    next_maintenance_date TEXT,
    operator_requirements TEXT NOT NULL DEFAULT 'Trained Clinical Staff',
    verification_status TEXT NOT NULL DEFAULT 'verified', -- 'verified', 'pending', 'self_reported'
    verified_by TEXT NOT NULL DEFAULT 'Hospital Administrator',
    evidence_document_name TEXT,
    notes TEXT,
    record_source TEXT NOT NULL DEFAULT 'Facility Infrastructure Audit',
    is_present INTEGER NOT NULL DEFAULT 1,
    last_verified_at TEXT NOT NULL DEFAULT (datetime('now')),
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (facility_id) REFERENCES healthcare_facilities(facility_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_inventory_facility ON facility_resource_inventory(facility_id);
CREATE INDEX IF NOT EXISTS idx_inventory_name ON facility_resource_inventory(resource_name);

-- 21. Doctor Availability Records Table
CREATE TABLE IF NOT EXISTS doctor_availability_records (
    availability_id INTEGER PRIMARY KEY AUTOINCREMENT,
    doctor_id TEXT NOT NULL,
    facility_id TEXT NOT NULL,
    is_on_duty INTEGER NOT NULL DEFAULT 1,
    duty_shift TEXT NOT NULL DEFAULT 'day', -- 'day', 'night', 'on_call', 'unavailable'
    status TEXT NOT NULL DEFAULT 'available', -- 'available', 'unavailable', 'unknown', 'outdated'
    reported_at TEXT NOT NULL DEFAULT (datetime('now')),
    expires_at TEXT,
    FOREIGN KEY (doctor_id) REFERENCES doctor_profiles(doctor_id) ON DELETE CASCADE,
    FOREIGN KEY (facility_id) REFERENCES healthcare_facilities(facility_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_doc_avail_doctor ON doctor_availability_records(doctor_id);
CREATE INDEX IF NOT EXISTS idx_doc_avail_facility ON doctor_availability_records(facility_id);

-- 22. Facility Condition Capabilities Table
CREATE TABLE IF NOT EXISTS facility_condition_capabilities (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    facility_id TEXT NOT NULL,
    condition_key TEXT NOT NULL,
    is_technically_eligible INTEGER NOT NULL DEFAULT 0,
    eligibility_status TEXT NOT NULL DEFAULT 'unknown', -- 'eligible', 'ineligible', 'unknown'
    technical_suitability_score REAL NOT NULL DEFAULT 0.0,
    confirmed_capabilities TEXT NOT NULL DEFAULT '[]',
    missing_essential_capabilities TEXT NOT NULL DEFAULT '[]',
    unknown_capabilities TEXT NOT NULL DEFAULT '[]',
    last_evaluated_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (facility_id) REFERENCES healthcare_facilities(facility_id) ON DELETE CASCADE,
    FOREIGN KEY (condition_key) REFERENCES condition_capability_requirements(condition_key) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_fac_cond_facility ON facility_condition_capabilities(facility_id);
CREATE INDEX IF NOT EXISTS idx_fac_cond_condition ON facility_condition_capabilities(condition_key);

-- 23. Ranking Configuration Table
CREATE TABLE IF NOT EXISTS ranking_configuration (
    config_id TEXT PRIMARY KEY DEFAULT 'default',
    priority_1_name TEXT NOT NULL DEFAULT 'Technical and Infrastructural Capability',
    priority_2_name TEXT NOT NULL DEFAULT 'Current Availability',
    priority_3_name TEXT NOT NULL DEFAULT 'Travel Distance and Time',
    stale_threshold_hours INTEGER NOT NULL DEFAULT 4,
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- 24. Synthetic Doctor Seed Metadata Table
CREATE TABLE IF NOT EXISTS synthetic_doctor_seed_metadata (
    seed_id TEXT PRIMARY KEY,
    seed_timestamp TEXT NOT NULL DEFAULT (datetime('now')),
    total_synthetic_doctors INTEGER NOT NULL DEFAULT 0,
    is_active INTEGER NOT NULL DEFAULT 1
);

-- ============================================================================
-- 25. Emergency Quick Referral System Tables
-- ============================================================================

-- Emergency Referrals Master Table
CREATE TABLE IF NOT EXISTS emergency_referrals (
    referral_id TEXT PRIMARY KEY,
    patient_identifier TEXT NOT NULL,
    patient_name TEXT,
    patient_age INTEGER,
    patient_sex TEXT,
    presenting_complaint TEXT NOT NULL,
    emergency_category TEXT NOT NULL,
    red_flag_symptoms TEXT NOT NULL DEFAULT '[]', -- JSON array
    symptom_onset_time TEXT,
    vitals_pulse INTEGER,
    vitals_bp_systolic INTEGER,
    vitals_bp_diastolic INTEGER,
    vitals_spo2 INTEGER,
    vitals_resp_rate INTEGER,
    vitals_temp REAL,
    consciousness_level TEXT DEFAULT 'Alert',
    allergies TEXT,
    medications_history TEXT,
    immediate_treatment_given TEXT,
    ambulance_status TEXT NOT NULL DEFAULT 'not_dispatched',
    ambulance_dispatch_time TEXT,
    ambulance_vehicle_number TEXT,
    ambulance_service_type TEXT DEFAULT '108 EMTS',
    ambulance_eta_minutes INTEGER,
    referring_clinician_id TEXT NOT NULL,
    referring_clinician_name TEXT NOT NULL,
    referring_facility_name TEXT NOT NULL,
    referring_callback_phone TEXT NOT NULL,
    receiving_facility_id TEXT NOT NULL,
    receiving_facility_name TEXT NOT NULL,
    receiving_department TEXT DEFAULT 'Emergency Department',
    intended_doctor_id TEXT,
    intended_doctor_name TEXT,
    recommendation_override_reason TEXT,
    clinical_notes TEXT,
    current_version INTEGER NOT NULL DEFAULT 1,
    workflow_status TEXT NOT NULL DEFAULT 'emergency_created',
    cancellation_reason TEXT,
    delivery_status TEXT NOT NULL DEFAULT 'not_sent',
    response_status TEXT NOT NULL DEFAULT 'no_response_yet',
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    is_offline_synced INTEGER NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_em_ref_workflow ON emergency_referrals(workflow_status);
CREATE INDEX IF NOT EXISTS idx_em_ref_delivery ON emergency_referrals(delivery_status);
CREATE INDEX IF NOT EXISTS idx_em_ref_response ON emergency_referrals(response_status);
CREATE INDEX IF NOT EXISTS idx_em_ref_receiving_fac ON emergency_referrals(receiving_facility_id);
CREATE INDEX IF NOT EXISTS idx_em_ref_created_at ON emergency_referrals(created_at);

-- Emergency Referral Versions / Amendments Table
CREATE TABLE IF NOT EXISTS emergency_referral_versions (
    version_id INTEGER PRIMARY KEY AUTOINCREMENT,
    referral_id TEXT NOT NULL,
    version_number INTEGER NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    created_by_id TEXT NOT NULL,
    created_by_name TEXT NOT NULL,
    amendment_reason TEXT NOT NULL,
    changed_fields TEXT NOT NULL DEFAULT '[]', -- JSON array of field names
    snapshot_data TEXT NOT NULL, -- Full JSON snapshot of referral
    sent_to_receiving_team INTEGER NOT NULL DEFAULT 0,
    sent_at TEXT,
    FOREIGN KEY (referral_id) REFERENCES emergency_referrals(referral_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_em_ver_referral ON emergency_referral_versions(referral_id);

-- Emergency Referral Delivery Attempts Table
CREATE TABLE IF NOT EXISTS emergency_referral_deliveries (
    delivery_id INTEGER PRIMARY KEY AUTOINCREMENT,
    referral_id TEXT NOT NULL,
    version_number INTEGER NOT NULL DEFAULT 1,
    channel TEXT NOT NULL, -- 'email', 'clinical_message', 'sms_alert', 'whatsapp_direct'
    recipient_address TEXT NOT NULL,
    recipient_name TEXT,
    subject_or_preview TEXT NOT NULL,
    message_body TEXT NOT NULL,
    delivery_status TEXT NOT NULL, -- 'queued', 'sent_to_provider', 'delivered', 'failed'
    provider_message_id TEXT,
    error_message TEXT,
    attempted_at TEXT NOT NULL DEFAULT (datetime('now')),
    delivered_at TEXT,
    FOREIGN KEY (referral_id) REFERENCES emergency_referrals(referral_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_em_del_referral ON emergency_referral_deliveries(referral_id);

-- Emergency Referral Acknowledgements Table
CREATE TABLE IF NOT EXISTS emergency_referral_acknowledgements (
    ack_id INTEGER PRIMARY KEY AUTOINCREMENT,
    referral_id TEXT NOT NULL,
    response_status TEXT NOT NULL, -- 'acknowledged', 'accepted', 'declined', 'alternative_destination_requested'
    responder_name TEXT NOT NULL,
    responder_role TEXT NOT NULL,
    alternative_facility_id TEXT,
    notes TEXT,
    responded_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (referral_id) REFERENCES emergency_referrals(referral_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_em_ack_referral ON emergency_referral_acknowledgements(referral_id);

-- Ambulance Dispatch Records Table
CREATE TABLE IF NOT EXISTS ambulance_dispatch_records (
    dispatch_id INTEGER PRIMARY KEY AUTOINCREMENT,
    referral_id TEXT NOT NULL,
    dispatch_status TEXT NOT NULL,
    service_type TEXT NOT NULL DEFAULT '108 EMTS',
    vehicle_number TEXT,
    driver_contact TEXT,
    paramedic_contact TEXT,
    dispatched_at TEXT NOT NULL DEFAULT (datetime('now')),
    estimated_arrival_minutes INTEGER,
    actual_arrival_at TEXT,
    notes TEXT,
    FOREIGN KEY (referral_id) REFERENCES emergency_referrals(referral_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_amb_disp_referral ON ambulance_dispatch_records(referral_id);

-- Emergency Referral Audit Trail Table
CREATE TABLE IF NOT EXISTS emergency_referral_audit_logs (
    log_id INTEGER PRIMARY KEY AUTOINCREMENT,
    referral_id TEXT NOT NULL,
    actor_id TEXT NOT NULL,
    actor_name TEXT NOT NULL,
    action TEXT NOT NULL,
    details TEXT NOT NULL,
    timestamp TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (referral_id) REFERENCES emergency_referrals(referral_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_em_audit_referral ON emergency_referral_audit_logs(referral_id);

-- ============================================================================
-- 26. Facility Resources, Infrastructure, Capacity & Staff Management Tables
-- ============================================================================

-- Facility Profiles and Administrative Registry
CREATE TABLE IF NOT EXISTS facility_profiles (
    facility_id TEXT PRIMARY KEY,
    contact_number TEXT,
    official_email TEXT,
    opening_hours TEXT NOT NULL DEFAULT '24/7',
    operating_days TEXT NOT NULL DEFAULT 'All Days',
    license_number TEXT,
    registration_authority TEXT,
    admin_user_id TEXT,
    admin_name TEXT,
    emergency_services_detail TEXT,
    departments_json TEXT NOT NULL DEFAULT '[]',
    profile_completion_percentage INTEGER NOT NULL DEFAULT 85,
    last_verified_at TEXT,
    verification_status TEXT NOT NULL DEFAULT 'verified',
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (facility_id) REFERENCES healthcare_facilities(facility_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_fac_prof_id ON facility_profiles(facility_id);

-- Facility Staff and Doctor Affiliations
CREATE TABLE IF NOT EXISTS facility_staff_affiliations (
    affiliation_id TEXT PRIMARY KEY,
    facility_id TEXT NOT NULL,
    doctor_id TEXT,
    staff_name TEXT NOT NULL,
    staff_role TEXT NOT NULL DEFAULT 'doctor', -- 'doctor', 'nurse', 'radiographer', 'lab_technician', 'emergency_medic', 'pharmacist'
    department TEXT NOT NULL,
    designation TEXT NOT NULL,
    primary_specialty TEXT,
    qualifications_json TEXT NOT NULL DEFAULT '[]',
    capabilities_json TEXT NOT NULL DEFAULT '[]',
    working_days TEXT NOT NULL DEFAULT 'Mon-Sat',
    shift_timing TEXT NOT NULL DEFAULT 'Day (09:00 - 17:00)',
    emergency_duty_participating INTEGER NOT NULL DEFAULT 1,
    is_currently_practising INTEGER NOT NULL DEFAULT 1,
    verification_status TEXT NOT NULL DEFAULT 'verified', -- 'verified', 'pending', 'rejected', 'unverified'
    missing_documentation_notes TEXT,
    is_active INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (facility_id) REFERENCES healthcare_facilities(facility_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_staff_fac ON facility_staff_affiliations(facility_id);
CREATE INDEX IF NOT EXISTS idx_staff_doc ON facility_staff_affiliations(doctor_id);

-- Detailed Facility Departments
CREATE TABLE IF NOT EXISTS facility_departments (
    department_id TEXT PRIMARY KEY,
    facility_id TEXT NOT NULL,
    department_name TEXT NOT NULL,
    specialties_json TEXT NOT NULL DEFAULT '[]',
    services_json TEXT NOT NULL DEFAULT '[]',
    operational_days TEXT NOT NULL DEFAULT 'Mon-Sun',
    operating_hours TEXT NOT NULL DEFAULT '24 Hours',
    appointment_mode TEXT NOT NULL DEFAULT 'Walk-in & Appointment',
    emergency_available INTEGER NOT NULL DEFAULT 1,
    specialist_coverage TEXT NOT NULL DEFAULT 'on_site', -- 'on_site', 'on_call', 'not_available'
    care_levels_json TEXT NOT NULL DEFAULT '["outpatient", "inpatient", "emergency"]',
    head_of_department TEXT,
    is_operational INTEGER NOT NULL DEFAULT 1,
    temporary_closure_reason TEXT,
    last_updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (facility_id) REFERENCES healthcare_facilities(facility_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_dept_fac ON facility_departments(facility_id);

-- Facility Capacity and Bed Distribution Records
CREATE TABLE IF NOT EXISTS facility_capacity_records (
    capacity_id TEXT PRIMARY KEY,
    facility_id TEXT NOT NULL,
    category TEXT NOT NULL, -- 'general_inpatient', 'emergency_bays', 'icu_beds', 'hdu_beds', 'pediatric_beds', 'maternity_beds', 'isolation_beds', 'operating_theatres', 'observation_bays'
    category_label TEXT NOT NULL,
    installed_capacity INTEGER NOT NULL DEFAULT 0,
    operational_capacity INTEGER NOT NULL DEFAULT 0,
    occupied_capacity INTEGER NOT NULL DEFAULT 0,
    available_capacity INTEGER NOT NULL DEFAULT 0,
    source TEXT NOT NULL DEFAULT 'Daily Census Update',
    last_updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (facility_id) REFERENCES healthcare_facilities(facility_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_cap_fac ON facility_capacity_records(facility_id);

-- Facility Supporting Infrastructure
CREATE TABLE IF NOT EXISTS facility_supporting_infrastructure (
    facility_id TEXT PRIMARY KEY,
    ambulance_arrangements TEXT NOT NULL DEFAULT 'On-site Dedicated 108 ALS Ambulance',
    blood_bank_access TEXT NOT NULL DEFAULT '24/7 Licensed In-House Blood Bank',
    pharmacy_available TEXT NOT NULL DEFAULT '24/7 In-House Dispensing Pharmacy',
    oxygen_infrastructure TEXT NOT NULL DEFAULT 'Liquid Medical Oxygen (LMO) Storage Tank with Central Pipeline',
    power_backup TEXT NOT NULL DEFAULT 'Dual 250kVA Diesel Generator Auto-Switching Backup',
    isolation_capability TEXT NOT NULL DEFAULT 'Dedicated Negative Pressure Airborne Isolation Ward',
    infection_control TEXT NOT NULL DEFAULT 'NABH Standard Hospital Infection Control Committee (HICC)',
    referral_partnerships TEXT NOT NULL DEFAULT 'Indore District Emergency Health Network Empaneled',
    telemedicine_capability TEXT NOT NULL DEFAULT 'Real-Time Tele-ICU and Video Consult Gateway',
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (facility_id) REFERENCES healthcare_facilities(facility_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_supp_fac ON facility_supporting_infrastructure(facility_id);

-- Facility Resource Verification Records
CREATE TABLE IF NOT EXISTS facility_resource_verification_records (
    verification_id TEXT PRIMARY KEY,
    facility_id TEXT NOT NULL,
    resource_id TEXT NOT NULL,
    reviewed_by TEXT NOT NULL,
    reviewer_role TEXT NOT NULL,
    decision TEXT NOT NULL, -- 'approved', 'rejected', 'more_info_needed'
    evidence_notes TEXT,
    verified_at TEXT NOT NULL DEFAULT (datetime('now')),
    reverification_due_date TEXT,
    FOREIGN KEY (facility_id) REFERENCES healthcare_facilities(facility_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_res_verif_fac ON facility_resource_verification_records(facility_id);

-- ============================================================================
-- 15. Gemini Symptom Analysis, Custom Tags & Offline Synchronization Tables
-- ============================================================================

-- Patient Symptom Analysis Records (Gemini & Offline Fallback)
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
    assessment_source TEXT NOT NULL DEFAULT 'offline_rules', -- 'gemini', 'offline_rules', 'clinician_override'
    model_version TEXT DEFAULT 'gemini-1.5-flash',
    ruleset_version TEXT DEFAULT 'indore-clinical-safety-v1',
    reasoning TEXT NOT NULL,
    red_flags_json TEXT NOT NULL DEFAULT '[]',
    missing_information_json TEXT NOT NULL DEFAULT '[]',
    follow_up_questions_json TEXT NOT NULL DEFAULT '[]',
    clinician_review_status TEXT NOT NULL DEFAULT 'unreviewed', -- 'unreviewed', 'confirmed', 'overridden'
    reviewed_by TEXT,
    clinician_notes TEXT,
    override_reason TEXT,
    sync_status TEXT NOT NULL DEFAULT 'synchronized',
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_symptom_assessments_patient ON symptom_assessments(patient_id);
CREATE INDEX IF NOT EXISTS idx_symptom_assessments_source ON symptom_assessments(assessment_source);
CREATE INDEX IF NOT EXISTS idx_symptom_assessments_urgency ON symptom_assessments(urgency_level);

-- Clinician and Built-in Custom Clinical Tags
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
);

CREATE INDEX IF NOT EXISTS idx_tags_category ON custom_clinical_tags(category);
CREATE INDEX IF NOT EXISTS idx_tags_builtin ON custom_clinical_tags(is_builtin);

-- Offline Synchronization Queue & Idempotency Audit
CREATE TABLE IF NOT EXISTS offline_sync_queue (
    queue_id TEXT PRIMARY KEY,
    entity_type TEXT NOT NULL, -- 'assessment', 'tag', 'referral', 'capacity'
    entity_id TEXT NOT NULL,
    action TEXT NOT NULL, -- 'create', 'update', 'delete'
    payload_json TEXT NOT NULL,
    idempotency_key TEXT NOT NULL UNIQUE,
    status TEXT NOT NULL DEFAULT 'completed', -- 'pending', 'processing', 'completed', 'conflict', 'failed'
    retry_count INTEGER NOT NULL DEFAULT 0,
    last_error TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    synced_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_sync_queue_status ON offline_sync_queue(status);
CREATE INDEX IF NOT EXISTS idx_sync_queue_idempotency ON offline_sync_queue(idempotency_key);

-- Referral Lifecycle & Verification Tracking (7 Distinct States)
CREATE TABLE IF NOT EXISTS referral_lifecycle_tracking (
    referral_id TEXT PRIMARY KEY,
    patient_id TEXT NOT NULL,
    receiving_facility_id TEXT NOT NULL,
    current_state TEXT NOT NULL DEFAULT 'assessment_saved',
    -- 1. assessment_saved
    -- 2. referral_draft_saved_locally
    -- 3. referral_queued_for_transmission
    -- 4. referral_successfully_sent
    -- 5. delivery_confirmed
    -- 6. receiving_facility_acknowledged
    -- 7. ambulance_dispatched
    is_ambulance_dispatched INTEGER NOT NULL DEFAULT 0,
    ambulance_dispatch_source TEXT,
    ambulance_dispatched_at TEXT,
    delivery_confirmed_at TEXT,
    facility_acknowledged_at TEXT,
    facility_acknowledged_by TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (receiving_facility_id) REFERENCES healthcare_facilities(facility_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_ref_lifecycle_patient ON referral_lifecycle_tracking(patient_id);
CREATE INDEX IF NOT EXISTS idx_ref_lifecycle_state ON referral_lifecycle_tracking(current_state);



