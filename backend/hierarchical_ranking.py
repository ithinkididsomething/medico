"""
Three-Level Hierarchical Hospital Referral Ranking Engine.

Enforces the strict clinical priority order:
Priority 1: Technical and infrastructural capability
Priority 2: Current availability
Priority 3: Travel distance and time

Ineligible facilities missing essential capabilities are strictly excluded and can
never outrank equipped facilities due to proximity or high general doctor scores.
"""

import math
from typing import List, Dict, Any, Optional
from datetime import datetime, timezone
import database
from condition_capabilities import CLINICAL_CONDITIONS, get_condition_definition


def haversine_distance_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculates great-circle distance between two GPS coordinates in kilometers."""
    radius_earth_km = 6371.0
    d_lat = math.radians(lat2 - lat1)
    d_lon = math.radians(lon2 - lon1)
    a = (math.sin(d_lat / 2) ** 2 +
         math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) *
         math.sin(d_lon / 2) ** 2)
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return round(radius_earth_km * c, 2)


def estimate_transit_time_minutes(distance_km: float, is_emergency: bool = False) -> int:
    """Estimates urban road transit time assuming realistic driving speeds."""
    # Emergency ambulance averages ~40 km/h with 3 min dispatch latency; standard driving ~28 km/h + 5 min latency
    speed_kmh = 40.0 if is_emergency else 28.0
    latency_mins = 3 if is_emergency else 5
    transit_mins = int(math.ceil((distance_km / speed_kmh) * 60.0)) + latency_mins
    return max(5, transit_mins)


def evaluate_facility_technical_capability(
    facility: Dict[str, Any],
    condition_def: Dict[str, Any],
    facility_doctors: List[Dict[str, Any]],
    facility_inventory: List[Dict[str, Any]],
) -> Dict[str, Any]:
    """
    Priority 1: Technical and Infrastructural Capability Evaluation.
    Stage A: Essential-capability eligibility ('eligible', 'ineligible', 'unknown').
    Stage B: Condition-specific technical suitability score (0-100).
    """
    req_specialties = [s.lower() for s in condition_def.get("required_specialties", [])]
    essential_equip = [e.lower() for e in condition_def.get("essential_equipment", [])]
    emergency_req = condition_def.get("emergency_stabilization_required", False)
    critical_care_req = condition_def.get("critical_care_required", False)

    # 1. Gather facility specialties
    fac_specialties = [s.lower() for s in facility.get("specialties", [])]
    # Add affiliated doctors' specialties
    for doc in facility_doctors:
        if doc.get("primary_specialty"):
            fac_specialties.append(str(doc["primary_specialty"]).lower())
        for sec in (doc.get("secondary_specialties") or []):
            if sec:
                fac_specialties.append(str(sec).lower())

    # 2. Gather facility capabilities & inventory
    fac_caps = [c.lower() for c in facility.get("capabilities", [])]
    fac_diagnostics = [d.lower() for d in facility.get("diagnosticFacilities", [])]
    fac_treatments = [t.lower() for t in facility.get("treatmentCapabilities", [])]
    fac_tags = [tg.lower() for tg in facility.get("tags", [])]
    inventory_items = [i.get("resource_name", "").lower() for i in facility_inventory if i.get("is_present", 1) == 1]

    all_facility_resources = set(fac_caps + fac_diagnostics + fac_treatments + fac_tags + inventory_items)

    confirmed_capabilities: List[str] = []
    missing_essential_capabilities: List[str] = []
    unknown_capabilities: List[str] = []

    # Check specialties match
    specialty_matched = any(
        any(req in fac_spec for fac_spec in fac_specialties)
        for req in req_specialties
    ) if req_specialties else True

    if not specialty_matched:
        missing_essential_capabilities.append(
            f"Required medical specialty missing ({', '.join(condition_def.get('required_specialties', []))})"
        )
    else:
        confirmed_capabilities.append("Relevant medical specialty available")

    # Check essential equipment & diagnostics
    for equip in essential_equip:
        # Check if equipment exists in facility resources
        is_found = False
        for res in all_facility_resources:
            if equip in res or res in equip:
                is_found = True
                break
        if not is_found:
            # Check specific resource synonyms
            if "ct" in equip and any("ct" in r for r in all_facility_resources):
                is_found = True
            elif "cath" in equip and any("cath" in r for r in all_facility_resources):
                is_found = True
            elif "blood" in equip and any("blood" in r for r in all_facility_resources):
                is_found = True
            elif "emergency" in equip and facility.get("emergencyCare"):
                is_found = True
            elif "ecg" in equip and any(k in r for r in all_facility_resources for k in ["ecg", "cardiac", "pathology"]):
                is_found = True
            elif "c-section" in equip and any(k in r for r in all_facility_resources for k in ["c-section", "cesarean", "obstetric", "gynae"]):
                is_found = True
            elif "pediatric respiratory" in equip and any(k in r for r in all_facility_resources for k in ["pediatric", "icu", "ventilator"]):
                is_found = True

        if is_found:
            confirmed_capabilities.append(equip.title())
        else:
            missing_essential_capabilities.append(equip.title())

    # Check emergency care
    if emergency_req:
        if not facility.get("emergencyCare", False) and not any("emergency" in r for r in all_facility_resources):
            missing_essential_capabilities.append("24/7 Emergency Care")
        else:
            confirmed_capabilities.append("24/7 Emergency Care")

    # Check critical care (ICU)
    if critical_care_req:
        if not facility.get("icuAvailable", False) and not any("icu" in r for r in all_facility_resources):
            missing_essential_capabilities.append("ICU / Critical Care Mechanical Ventilation")
        else:
            confirmed_capabilities.append("ICU Critical Care")

    # Determine Stage A eligibility
    if missing_essential_capabilities:
        eligibility_status = "ineligible"
        is_eligible = False
    elif unknown_capabilities:
        eligibility_status = "unknown"
        is_eligible = False
    else:
        eligibility_status = "eligible"
        is_eligible = True

    # Stage B: Technical Suitability Score (0.0 to 100.0)
    # Specialty Match: 30 pts max
    specialty_score = 30.0 if specialty_matched else 0.0
    
    # Infrastructure & Equipment Match: 40 pts max
    total_equip = len(essential_equip) + len(condition_def.get("supporting_capabilities", []))
    if total_equip > 0:
        matched_equip_count = len(confirmed_capabilities)
        equip_score = min(40.0, (matched_equip_count / total_equip) * 40.0)
    else:
        equip_score = 40.0

    # Doctor Capabilities Score: 30 pts max
    # Derived from matching doctors' normalized capability score
    matching_doc_scores = [
        d.get("normalized_capability_score", 0.0) or (d.get("capabilityScore", {}).get("total_capability_score", 0.0) if isinstance(d.get("capabilityScore"), dict) else 0.0)
        for d in facility_doctors
        if any(req in (str(d.get("primary_specialty") or "").lower()) for req in req_specialties)
    ]
    if matching_doc_scores:
        avg_doc_score = max(matching_doc_scores) # Peak expert capability
        doc_score = min(30.0, (avg_doc_score / 100.0) * 30.0)
    else:
        doc_score = 15.0 if specialty_matched else 0.0 # Base credit if facility lists specialty

    technical_suitability_score = round(specialty_score + equip_score + doc_score, 1)

    return {
        "is_eligible": is_eligible,
        "eligibility_status": eligibility_status,
        "technical_suitability_score": technical_suitability_score,
        "confirmed_capabilities": list(set(confirmed_capabilities)),
        "missing_essential_capabilities": missing_essential_capabilities,
        "unknown_capabilities": unknown_capabilities,
        "specialty_score": specialty_score,
        "equipment_score": equip_score,
        "doctor_score": doc_score,
    }


def evaluate_facility_current_availability(
    facility: Dict[str, Any],
    condition_def: Dict[str, Any],
    operational_status_record: Optional[Dict[str, Any]],
    facility_doctors: List[Dict[str, Any]],
) -> Dict[str, Any]:
    """
    Priority 2: Current Availability Evaluation.
    Evaluates operational status, emergency department open status, available beds,
    and matching on-duty doctors.
    Distinguishes: 'available', 'unavailable', 'unknown', 'outdated'.
    """
    op_status = facility.get("operatingStatus", "Operational")
    bed_avail = facility.get("bedAvailability", 0)
    emergency_open = facility.get("emergencyCare", False)
    icu_avail = facility.get("icuAvailable", False)

    # Use live time-stamped operational record if present
    is_outdated = False
    last_reported_str = None
    if operational_status_record:
        op_status = operational_status_record.get("operating_status", op_status)
        bed_avail = operational_status_record.get("general_beds_available", bed_avail)
        emergency_open = bool(operational_status_record.get("emergency_department_open", emergency_open))
        icu_beds = operational_status_record.get("icu_beds_available", 0)
        last_reported_str = operational_status_record.get("last_reported_at")
        
        # Check freshness TTL
        if last_reported_str:
            try:
                dt = datetime.fromisoformat(last_reported_str.replace("Z", "+00:00"))
                age_seconds = (datetime.now(timezone.utc) - dt).total_seconds()
                ttl = operational_status_record.get("freshness_ttl_seconds", 14400) # 4 hours
                if age_seconds > ttl:
                    is_outdated = True
            except Exception:
                pass

    req_emergency = condition_def.get("emergency_stabilization_required", False)
    req_critical = condition_def.get("critical_care_required", False)

    # Classification
    if op_status in ["Closed", "Diverting"]:
        status = "unavailable"
        reason = f"Facility status is {op_status}."
    elif req_emergency and not emergency_open:
        status = "unavailable"
        reason = "Emergency Department is currently diverted or closed."
    elif req_critical and not icu_avail:
        status = "unavailable"
        reason = "ICU / CCU critical-care beds currently full or unavailable."
    elif is_outdated:
        status = "outdated"
        reason = f"Operational availability status is older than TTL ({last_reported_str}). Requires manual phone confirmation."
    elif op_status in ["Operational", "Busy"]:
        status = "available"
        reason = f"Operational with confirmed bed capacity ({bed_avail} beds available)."
    else:
        status = "unknown"
        reason = "Operational status cannot be verified from central registry."

    return {
        "status": status,
        "operating_status": op_status,
        "general_beds_available": bed_avail,
        "emergency_department_open": emergency_open,
        "is_outdated": is_outdated,
        "last_reported_at": last_reported_str,
        "reason": reason,
    }


def rank_facilities_hierarchical(
    condition_key: str,
    clinic_latitude: float,
    clinic_longitude: float,
    include_synthetic: bool = False,
) -> Dict[str, Any]:
    """
    Main Hierarchical Ranking Implementation.
    Ranks 45 facilities according to:
    Priority 1: Technical Capability -> Priority 2: Availability -> Priority 3: Travel Distance/Time.
    """
    condition_def = get_condition_definition(condition_key)
    facilities = database.get_all_facilities()
    all_doctors = database.get_all_doctors(include_synthetic=include_synthetic)
    
    # Pre-index doctors by facility
    doc_by_fac: Dict[str, List[Dict[str, Any]]] = {}
    for d in all_doctors:
        for aff in d.get("affiliations", []):
            fid = aff.get("facility_id")
            if fid:
                doc_by_fac.setdefault(fid, []).append(d)

    # Get operational status records
    conn = database.get_db_connection()
    op_records = {
        r["facility_id"]: dict(r)
        for r in conn.execute("SELECT * FROM facility_operational_status").fetchall()
    }
    inv_records: Dict[str, List[Dict[str, Any]]] = {}
    for r in conn.execute("SELECT * FROM facility_resource_inventory").fetchall():
        inv_records.setdefault(r["facility_id"], []).append(dict(r))
    conn.close()

    is_emergency = condition_def.get("urgency_level") in ["immediate", "urgent"]

    group1_suitable_available: List[Dict[str, Any]] = []
    group2_suitable_unconfirmed: List[Dict[str, Any]] = []
    group_excluded_ineligible: List[Dict[str, Any]] = []

    for fac in facilities:
        fac_id = fac["hospitalId"]
        fac_docs = doc_by_fac.get(fac_id, [])
        fac_inv = inv_records.get(fac_id, [])
        op_rec = op_records.get(fac_id)

        # 1. Geographic distance and travel time
        lat = fac.get("latitude", 22.7196)
        lon = fac.get("longitude", 75.8577)
        dist_km = haversine_distance_km(clinic_latitude, clinic_longitude, lat, lon)
        transit_time_min = estimate_transit_time_minutes(dist_km, is_emergency=is_emergency)

        # 2. Priority 1: Technical & Infrastructural Capability
        tech_eval = evaluate_facility_technical_capability(fac, condition_def, fac_docs, fac_inv)

        # 3. Priority 2: Current Availability
        avail_eval = evaluate_facility_current_availability(fac, condition_def, op_rec, fac_docs)

        entry = {
            "facility_id": fac_id,
            "facility_name": fac["name"],
            "address": fac.get("address", ""),
            "facility_type": fac.get("facilityType", "general_hospital"),
            "distance_km": dist_km,
            "transit_time_minutes": transit_time_min,
            "technical_evaluation": tech_eval,
            "availability_evaluation": avail_eval,
            "affiliated_doctors_count": len(fac_docs),
            "is_simulated_data": fac.get("isSimulatedData", False),
        }

        # 4. Grouping based on Lexicographic Priority Hierarchy
        if not tech_eval["is_eligible"]:
            entry["status_label"] = "Essential capability missing"
            entry["recommendation_tier"] = "Tier 3: Ineligible"
            entry["why_ranked_summary"] = (
                f"Excluded from recommendations for {condition_def['condition_name']}: "
                f"Confirmed missing essential capabilities ({'; '.join(tech_eval['missing_essential_capabilities'])}). "
                f"Proximity ({dist_km} km) cannot override missing clinical infrastructure."
            )
            group_excluded_ineligible.append(entry)
        elif avail_eval["status"] == "available":
            entry["status_label"] = "Suitable — availability confirmed"
            entry["recommendation_tier"] = "Tier 1: Recommended"
            entry["why_ranked_summary"] = (
                f"Ranked for {condition_def['condition_name']}: Technically eligible (score {tech_eval['technical_suitability_score']}/100) "
                f"with confirmed active availability ({avail_eval['general_beds_available']} beds available). "
                f"Estimated road transit: {dist_km} km (~{transit_time_min} mins)."
            )
            group1_suitable_available.append(entry)
        else:
            entry["status_label"] = "Suitable — availability requires confirmation" if avail_eval["status"] != "outdated" else "Operational status outdated"
            entry["recommendation_tier"] = "Tier 2: Conditional"
            entry["why_ranked_summary"] = (
                f"Technically eligible (score {tech_eval['technical_suitability_score']}/100), but availability is {avail_eval['status']}. "
                f"{avail_eval['reason']} Recommend direct telephone verification before transport."
            )
            group2_suitable_unconfirmed.append(entry)

    # 5. Sorting within groups:
    # Priority 1: Technical Suitability Score (descending)
    # Priority 2: Availability (beds/operational)
    # Priority 3: Travel Distance / Time (ascending)
    def sort_key(item: Dict[str, Any]):
        tech_score = item["technical_evaluation"]["technical_suitability_score"]
        dist = item["distance_km"]
        # Invert tech_score for ascending sort, then distance ascending
        return (-tech_score, dist)

    group1_suitable_available.sort(key=sort_key)
    group2_suitable_unconfirmed.sort(key=sort_key)
    group_excluded_ineligible.sort(key=lambda x: x["distance_km"]) # Sort excluded by distance for clinician awareness

    # Assign sequential ranks across eligible groups
    current_rank = 1
    for item in group1_suitable_available:
        item["rank"] = current_rank
        current_rank += 1
    for item in group2_suitable_unconfirmed:
        item["rank"] = current_rank
        current_rank += 1
    for item in group_excluded_ineligible:
        item["rank"] = None # Ineligible facilities do not get a positive recommendation rank

    all_ranked = group1_suitable_available + group2_suitable_unconfirmed

    return {
        "condition_key": condition_key,
        "condition_name": condition_def["condition_name"],
        "urgency_level": condition_def["urgency_level"],
        "ranking_hierarchy": [
            "Priority 1: Technical and infrastructural capability (Essential gate)",
            "Priority 2: Current availability (Operational & Bed capacity)",
            "Priority 3: Travel distance and time (Transit optimization)",
        ],
        "total_evaluated_facilities": len(facilities),
        "eligible_facilities_count": len(all_ranked),
        "confirmed_available_count": len(group1_suitable_available),
        "unconfirmed_availability_count": len(group2_suitable_unconfirmed),
        "excluded_ineligible_count": len(group_excluded_ineligible),
        "ranked_recommendations": all_ranked,
        "excluded_facilities": group_excluded_ineligible,
        "fallback_protocol": condition_def["acceptable_referral_fallback"],
        "evaluated_at": datetime.now(timezone.utc).isoformat(),
        "is_synthetic_data_included": include_synthetic,
        "data_notice": "SIMULATED DATA — NOT FOR CLINICAL DECISIONS" if include_synthetic else "OFFICIAL HEALTHCARE REGISTRY",
    }
