"""
SMART Referral - Centralized Authoritative Backend Server
Provides standard REST API and incremental synchronization endpoints
for connected Flutter clients across all devices.
Zero external dependencies (pure Python standard library).
"""

import json
import os
import sys
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

# Ensure local backend module imports
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import database
import hierarchical_ranking
import condition_capabilities
import gemini_service
import clinical_rules

PORT = int(os.environ.get("PORT", 8000))
HOST = os.environ.get("HOST", "0.0.0.0")


class CentralSyncApiHandler(BaseHTTPRequestHandler):
    server_version = "SmartReferralCentralAPI/1.0.0"

    def _set_cors_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
        self.send_header(
            "Access-Control-Allow-Headers",
            "Content-Type, Authorization, X-Client-Id, X-Idempotency-Key, If-None-Match",
        )
        self.send_header("Access-Control-Max-Age", "86400")

    def _send_json_response(self, status_code, data):
        self.send_response(status_code)
        self._set_cors_headers()
        self.send_header("Content-Type", "application/json; charset=utf-8")
        body = json.dumps(data, indent=2).encode("utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        self.send_response(HTTPStatus.NO_CONTENT)
        self._set_cors_headers()
        self.end_headers()

    def _parse_auth(self):
        auth_header = self.headers.get("Authorization", "")
        if auth_header.startswith("Bearer "):
            token = auth_header[7:].strip()
            # Simple demo auth tokens
            if "admin" in token.lower():
                return "admin_user", "admin"
            if "officer" in token.lower() or "doctor" in token.lower():
                return "duty_officer", "hospital_duty_officer"
            return "clinician_user", "clinician"
        return "anonymous_client", "public_read"

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/")
        query = parse_qs(parsed.query)

        # 1. Health check
        if path == "" or path == "/api/v1/health":
            self._send_json_response(
                HTTPStatus.OK,
                {
                    "status": "healthy",
                    "service": "smart-referral-central-backend",
                    "version": "1.0.0",
                    "database": "sqlite-authoritative",
                    "facilitiesCount": len(database.get_all_facilities()),
                    "authoritativeFacilitiesCount": len(database.get_all_facilities()),
                },
            )
            return

        # 2. Roles
        if path == "/api/v1/roles":
            conn = database.get_db_connection()
            roles = [dict(r) for r in conn.execute("SELECT * FROM roles_and_permissions").fetchall()]
            conn.close()
            self._send_json_response(HTTPStatus.OK, {"roles": roles})
            return

        # 3. Audit Logs
        if path == "/api/v1/audit-logs":
            limit = int(query.get("limit", [50])[0])
            logs = database.get_audit_logs(limit=limit)
            self._send_json_response(HTTPStatus.OK, {"logs": logs, "count": len(logs)})
            return

        # 4. Sync Pull (Incremental Synchronization cursor)
        if path == "/api/v1/sync/pull":
            since_rev = int(query.get("since_revision", [0])[0])
            limit = int(query.get("limit", [200])[0])
            sync_data = database.sync_pull(since_revision=since_rev, limit=limit)
            self._send_json_response(HTTPStatus.OK, sync_data)
            return

        # 5. Facilities List
        if path == "/api/v1/facilities":
            since_rev = int(query.get("since_revision", [0])[0])
            q_term = query.get("query", [None])[0]
            specialty = query.get("specialty", [None])[0]
            tag = query.get("tag", [None])[0]
            emergency_only = query.get("emergency_only", ["0"])[0].lower() in ["1", "true"]
            limit = int(query.get("limit", [100])[0])
            offset = int(query.get("offset", [0])[0])

            facilities = database.get_all_facilities(
                since_revision=since_rev,
                query=q_term,
                specialty=specialty,
                tag=tag,
                emergency_only=emergency_only,
                limit=limit,
                offset=offset,
            )

            conn = database.get_db_connection()
            max_rev_row = conn.execute("SELECT MAX(revision) as max_rev FROM healthcare_facilities").fetchone()
            latest_rev = max_rev_row["max_rev"] or 1
            conn.close()

            self._send_json_response(
                HTTPStatus.OK,
                {
                    "facilities": facilities,
                    "count": len(facilities),
                    "serverRevision": latest_rev,
                },
            )
            return

        # 6. Facility Doctors (/api/v1/facilities/<id>/doctors)
        if path.startswith("/api/v1/facilities/") and path.endswith("/doctors"):
            parts = path.split("/")
            fac_id = parts[4]
            include_synth = query.get("include_synthetic", ["0"])[0].lower() in ["1", "true"]
            docs = database.get_doctors_by_facility(fac_id, include_synthetic=include_synth)
            self._send_json_response(
                HTTPStatus.OK,
                {
                    "facilityId": fac_id,
                    "doctors": docs,
                    "count": len(docs),
                    "isSyntheticIncluded": include_synth,
                },
            )
            return

        # Facility Resources & Infrastructure Complete (/api/v1/facilities/<id>/resources)
        if path.startswith("/api/v1/facilities/") and path.endswith("/resources"):
            parts = path.split("/")
            fac_id = parts[4]
            data = database.get_facility_resources_complete(fac_id)
            if data:
                self._send_json_response(HTTPStatus.OK, {"status": "success", "data": data})
            else:
                self._send_json_response(HTTPStatus.NOT_FOUND, {"error": f"Facility {fac_id} not found"})
            return

        # Facility Capacity Distribution (/api/v1/facilities/<id>/capacity)
        if path.startswith("/api/v1/facilities/") and path.endswith("/capacity"):
            parts = path.split("/")
            fac_id = parts[4]
            cap = database.get_facility_capacity(fac_id)
            self._send_json_response(HTTPStatus.OK, {"status": "success", "facilityId": fac_id, "capacity": cap})
            return

        # Facility Detailed Profile (/api/v1/facilities/<id>/profile)
        if path.startswith("/api/v1/facilities/") and path.endswith("/profile"):
            parts = path.split("/")
            fac_id = parts[4]
            prof = database.get_facility_profile_detailed(fac_id)
            self._send_json_response(HTTPStatus.OK, {"status": "success", "facilityId": fac_id, "data": prof})
            return

        # Facility Staff & Doctor Affiliations (/api/v1/facilities/<id>/staff)
        if path.startswith("/api/v1/facilities/") and path.endswith("/staff"):
            parts = path.split("/")
            fac_id = parts[4]
            staff = database.get_facility_staff_affiliations(fac_id)
            self._send_json_response(HTTPStatus.OK, {"status": "success", "facilityId": fac_id, "staff": staff})
            return

        # Facility Departments (/api/v1/facilities/<id>/departments)
        if path.startswith("/api/v1/facilities/") and path.endswith("/departments"):
            parts = path.split("/")
            fac_id = parts[4]
            depts = database.get_facility_departments(fac_id)
            self._send_json_response(HTTPStatus.OK, {"status": "success", "facilityId": fac_id, "departments": depts})
            return

        # 7. Facility Details by ID (/api/v1/facilities/<id>)
        if path.startswith("/api/v1/facilities/"):
            fac_id = path.replace("/api/v1/facilities/", "").strip()
            fac = database.get_facility_by_id(fac_id)
            if fac:
                self._send_json_response(HTTPStatus.OK, {"facility": fac})
            else:
                self._send_json_response(HTTPStatus.NOT_FOUND, {"error": f"Facility {fac_id} not found"})
            return

        # 8. Clinical Conditions Requirements (/api/v1/conditions & /api/v1/conditions/<key>)
        if path == "/api/v1/conditions":
            conds = database.get_condition_requirements()
            self._send_json_response(HTTPStatus.OK, {"conditions": conds, "count": len(conds)})
            return

        if path.startswith("/api/v1/conditions/"):
            ckey = path.replace("/api/v1/conditions/", "").strip()
            cond = database.get_condition_requirements(ckey)
            if cond:
                self._send_json_response(HTTPStatus.OK, {"condition": cond})
            else:
                self._send_json_response(HTTPStatus.NOT_FOUND, {"error": f"Condition {ckey} not found"})
            return

        # 9. Doctor List & Details
        if path == "/api/v1/doctors":
            st = query.get("status", [None])[0]
            sp = query.get("specialty", [None])[0]
            include_synth = query.get("include_synthetic", ["0"])[0].lower() in ["1", "true"]
            limit = int(query.get("limit", [100])[0])
            doctors = database.list_doctors(status=st, specialty=sp, include_synthetic=include_synth, limit=limit)
            self._send_json_response(
                HTTPStatus.OK,
                {
                    "doctors": doctors,
                    "count": len(doctors),
                    "isSyntheticIncluded": include_synth,
                },
            )
            return

        if path.startswith("/api/v1/doctors/"):
            doc_id = path.replace("/api/v1/doctors/", "").strip()
            # If authorized reviewer, show unmasked profile; otherwise public sanitized
            is_pub = (actor_role not in ["admin", "district_officer"])
            doc = database.get_doctor_by_id(doc_id, is_public=is_pub)
            if doc:
                self._send_json_response(HTTPStatus.OK, {"doctor": doc})
            else:
                self._send_json_response(HTTPStatus.NOT_FOUND, {"error": f"Doctor {doc_id} not found"})
            return

        # 8. Emergency Referrals List & Detail
        if path == "/api/v1/emergency-referrals":
            wf_status = query.get("status", [None])[0]
            limit = int(query.get("limit", [100])[0])
            referrals = database.get_all_emergency_referrals(workflow_status=wf_status, limit=limit)
            self._send_json_response(HTTPStatus.OK, {"referrals": referrals, "count": len(referrals)})
            return

        if path.startswith("/api/v1/emergency-referrals/"):
            ref_id = path.replace("/api/v1/emergency-referrals/", "").strip()
            referral = database.get_emergency_referral(ref_id)
            if referral:
                self._send_json_response(HTTPStatus.OK, {"referral": referral})
            else:
                self._send_json_response(HTTPStatus.NOT_FOUND, {"error": f"Emergency referral {ref_id} not found"})
            return

        # 9. Clinical Tags (/api/v1/tags)
        if path == "/api/v1/tags":
            tags = database.get_all_clinical_tags()
            self._send_json_response(HTTPStatus.OK, {"tags": tags, "count": len(tags)})
            return

        # 10. Symptom Assessment by ID (/api/v1/assessments/<id>)
        if path.startswith("/api/v1/assessments/"):
            asmt_id = path.replace("/api/v1/assessments/", "").strip()
            asmt = database.get_symptom_assessment(asmt_id)
            if asmt:
                self._send_json_response(HTTPStatus.OK, {"assessment": asmt})
            else:
                self._send_json_response(HTTPStatus.NOT_FOUND, {"error": f"Assessment {asmt_id} not found"})
            return

        # 11. Patient Assessments History (/api/v1/patients/<id>/assessments)
        if path.startswith("/api/v1/patients/") and path.endswith("/assessments"):
            patient_id = path.split("/")[4]
            asmts = database.get_patient_assessments(patient_id)
            self._send_json_response(HTTPStatus.OK, {"assessments": asmts, "count": len(asmts)})
            return

        # 12. Referral Delivery Lifecycle State (/api/v1/referrals/<id>/lifecycle)
        if path.startswith("/api/v1/referrals/") and path.endswith("/lifecycle"):
            ref_id = path.split("/")[4]
            lifecycle = database.get_referral_lifecycle(ref_id)
            if lifecycle:
                self._send_json_response(HTTPStatus.OK, {"lifecycle": lifecycle})
            else:
                self._send_json_response(HTTPStatus.NOT_FOUND, {"error": f"Lifecycle for {ref_id} not found"})
            return

        self._send_json_response(HTTPStatus.NOT_FOUND, {"error": "Endpoint not found"})

    def do_POST(self):
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/")
        actor_id, actor_role = self._parse_auth()

        content_len = int(self.headers.get("Content-Length", 0))
        body_bytes = self.rfile.read(content_len) if content_len > 0 else b"{}"
        try:
            body_json = json.loads(body_bytes.decode("utf-8")) if body_bytes else {}
        except Exception as e:
            self._send_json_response(HTTPStatus.BAD_REQUEST, {"error": f"Invalid JSON payload: {e}"})
            return

        # 1. Sync Push (/api/v1/sync/push)
        if path == "/api/v1/sync/push":
            client_id = self.headers.get("X-Client-Id") or body_json.get("clientId") or "unknown_client"
            idempotency_key = self.headers.get("X-Idempotency-Key") or body_json.get("idempotencyKey")
            changes = body_json.get("changes", [])

            resp, err = database.sync_push(
                client_id=client_id,
                changes=changes,
                idempotency_key=idempotency_key,
                actor_id=actor_id,
                actor_role=actor_role,
            )
            if err:
                self._send_json_response(HTTPStatus.BAD_REQUEST, {"error": err})
            else:
                self._send_json_response(HTTPStatus.OK, resp)
            return

        # 2. Doctor Registration (/api/v1/doctors/register)
        if path == "/api/v1/doctors/register":
            doc, err = database.register_doctor(body_json, actor_id=actor_id)
            if err:
                self._send_json_response(HTTPStatus.BAD_REQUEST, {"error": err})
            else:
                self._send_json_response(HTTPStatus.CREATED, {"status": "success", "doctor": doc})
            return

        # 3. Hierarchical Condition-Specific Referral Ranking (/api/v1/referrals/hierarchical-rank)
        if path == "/api/v1/referrals/hierarchical-rank":
            condition_key = body_json.get("conditionKey") or body_json.get("condition_key")
            if not condition_key:
                self._send_json_response(HTTPStatus.BAD_REQUEST, {"error": "Missing required field 'conditionKey'"})
                return

            lat = float(body_json.get("latitude", 22.7196))
            lon = float(body_json.get("longitude", 75.8577))
            include_synth = bool(body_json.get("includeSynthetic", False) or body_json.get("include_synthetic", False))

            try:
                ranked_result = hierarchical_ranking.rank_facilities_hierarchical(
                    condition_key=condition_key,
                    clinic_latitude=lat,
                    clinic_longitude=lon,
                    include_synthetic=include_synth,
                )
                self._send_json_response(HTTPStatus.OK, ranked_result)
            except Exception as e:
                self._send_json_response(HTTPStatus.INTERNAL_SERVER_ERROR, {"error": f"Ranking computation error: {str(e)}"})
            return

        # 4. Create Emergency Referral (/api/v1/emergency-referrals)
        if path == "/api/v1/emergency-referrals":
            clinician_name = body_json.get("referringClinicianName") or body_json.get("referring_clinician_name") or "Dr. Parth Saxena"
            ref, err = database.create_emergency_referral(body_json, actor_id=actor_id, actor_name=clinician_name)
            if err:
                self._send_json_response(HTTPStatus.BAD_REQUEST, {"error": err})
            else:
                self._send_json_response(HTTPStatus.CREATED, {"status": "success", "referral": ref})
            return

        # 5. Add Emergency Referral Clinical Amendment (/api/v1/emergency-referrals/<id>/versions)
        if path.startswith("/api/v1/emergency-referrals/") and path.endswith("/versions"):
            ref_id = path.split("/")[4]
            reason = body_json.get("amendmentReason") or body_json.get("amendment_reason") or "Clinical observations and vitals update"
            clinician_name = body_json.get("editorName") or body_json.get("editor_name") or "Dr. Parth Saxena"
            ref, err = database.add_emergency_referral_version(ref_id, body_json, actor_id=actor_id, actor_name=clinician_name, amendment_reason=reason)
            if err:
                self._send_json_response(HTTPStatus.BAD_REQUEST, {"error": err})
            else:
                self._send_json_response(HTTPStatus.OK, {"status": "success", "referral": ref})
            return

        # 6. Update Ambulance Dispatch (/api/v1/emergency-referrals/<id>/dispatch)
        if path.startswith("/api/v1/emergency-referrals/") and path.endswith("/dispatch"):
            ref_id = path.split("/")[4]
            clinician_name = body_json.get("actorName") or "Dr. Parth Saxena"
            ref, err = database.update_ambulance_dispatch(ref_id, body_json, actor_id=actor_id, actor_name=clinician_name)
            if err:
                self._send_json_response(HTTPStatus.BAD_REQUEST, {"error": err})
            else:
                self._send_json_response(HTTPStatus.OK, {"status": "success", "referral": ref})
            return

        # 7. Send Emergency Referral via Channel (/api/v1/emergency-referrals/<id>/send)
        if path.startswith("/api/v1/emergency-referrals/") and path.endswith("/send"):
            ref_id = path.split("/")[4]
            channel = body_json.get("channel", "email")
            recipient_address = body_json.get("recipientAddress") or body_json.get("recipient_address")
            recipient_name = body_json.get("recipientName") or body_json.get("recipient_name")
            notes = body_json.get("notes")
            clinician_name = body_json.get("senderName") or "Dr. Parth Saxena"
            ref, err = database.send_emergency_referral(
                referral_id=ref_id,
                channel=channel,
                recipient_address=recipient_address,
                recipient_name=recipient_name,
                custom_notes=notes,
                actor_id=actor_id,
                actor_name=clinician_name,
            )
            if err:
                self._send_json_response(HTTPStatus.BAD_REQUEST, {"error": err})
            else:
                self._send_json_response(HTTPStatus.OK, {"status": "success", "referral": ref})
            return

        # 8. Record Emergency Acknowledgement (/api/v1/emergency-referrals/<id>/acknowledge)
        if path.startswith("/api/v1/emergency-referrals/") and path.endswith("/acknowledge"):
            ref_id = path.split("/")[4]
            resp_status = body_json.get("responseStatus") or body_json.get("response_status") or "acknowledged"
            responder_name = body_json.get("responderName") or body_json.get("responder_name") or "Duty Emergency Physician"
            responder_role = body_json.get("responderRole") or body_json.get("responder_role") or "Emergency Physician"
            alt_fac = body_json.get("alternativeFacilityId") or body_json.get("alternative_facility_id")
            notes = body_json.get("notes")
            ref, err = database.record_emergency_acknowledgement(
                referral_id=ref_id,
                response_status=resp_status,
                responder_name=responder_name,
                responder_role=responder_role,
                alternative_facility_id=alt_fac,
                notes=notes,
            )
            if err:
                self._send_json_response(HTTPStatus.BAD_REQUEST, {"error": err})
            else:
                self._send_json_response(HTTPStatus.OK, {"status": "success", "referral": ref})
            return

        # 9. Record Handover (/api/v1/emergency-referrals/<id>/handover)
        if path.startswith("/api/v1/emergency-referrals/") and path.endswith("/handover"):
            ref_id = path.split("/")[4]
            clinician_name = body_json.get("actorName") or "Dr. Parth Saxena"
            notes = body_json.get("notes")
            ref, err = database.record_emergency_handover(ref_id, actor_id=actor_id, actor_name=clinician_name, notes=notes)
            if err:
                self._send_json_response(HTTPStatus.BAD_REQUEST, {"error": err})
            else:
                self._send_json_response(HTTPStatus.OK, {"status": "success", "referral": ref})
            return

        # 10. Add Facility Resource (/api/v1/facilities/<id>/resources)
        if path.startswith("/api/v1/facilities/") and path.endswith("/resources"):
            parts = path.split("/")
            fac_id = parts[4]
            item, err = database.add_facility_resource(fac_id, body_json, actor_id=actor_id, actor_role=actor_role)
            if err:
                code = HTTPStatus.FORBIDDEN if "Unauthorized" in err else HTTPStatus.BAD_REQUEST
                self._send_json_response(code, {"error": err})
            else:
                self._send_json_response(HTTPStatus.CREATED, {"status": "success", "resource": item})
            return

        # 11. Add Staff Affiliation (/api/v1/facilities/<id>/staff)
        if path.startswith("/api/v1/facilities/") and path.endswith("/staff"):
            parts = path.split("/")
            fac_id = parts[4]
            staff, err = database.add_facility_staff_affiliation(fac_id, body_json, actor_id=actor_id, actor_role=actor_role)
            if err:
                code = HTTPStatus.FORBIDDEN if "Unauthorized" in err else HTTPStatus.BAD_REQUEST
                self._send_json_response(code, {"error": err})
            else:
                self._send_json_response(HTTPStatus.CREATED, {"status": "success", "staff": staff})
            return

        # 12. Verify Facility Resource (/api/v1/facilities/<id>/verify-resource)
        if path.startswith("/api/v1/facilities/") and path.endswith("/verify-resource"):
            parts = path.split("/")
            fac_id = parts[4]
            res_id = body_json.get("resource_id") or body_json.get("resourceId")
            decision = body_json.get("decision", "approved")
            notes = body_json.get("notes")
            reverif = body_json.get("reverification_due_date")
            item, err = database.verify_facility_resource(fac_id, res_id, decision=decision, reviewer_id=actor_id, reviewer_role=actor_role, notes=notes, reverification_due_date=reverif)
            if err:
                code = HTTPStatus.FORBIDDEN if "Unauthorized" in err else HTTPStatus.BAD_REQUEST
                self._send_json_response(code, {"error": err})
            else:
                self._send_json_response(HTTPStatus.OK, {"status": "success", "resource": item})
            return

        # 12b. Add Clinical Department (/api/v1/facilities/<id>/departments)
        if path.startswith("/api/v1/facilities/") and path.endswith("/departments"):
            parts = path.split("/")
            fac_id = parts[4]
            dept, err = database.add_facility_department(fac_id, body_json, actor_id=actor_id, actor_role=actor_role)
            if err:
                code = HTTPStatus.FORBIDDEN if "Unauthorized" in err else HTTPStatus.BAD_REQUEST
                self._send_json_response(code, {"error": err})
            else:
                self._send_json_response(HTTPStatus.CREATED, {"status": "success", "department": dept})
            return

        # 13. Gemini Symptom Analysis (/api/v1/gemini/analyze-symptoms)
        if path == "/api/v1/gemini/analyze-symptoms":
            free_text = body_json.get("free_text") or body_json.get("description") or ""
            vitals = body_json.get("vitals") or {}
            selected_tags = body_json.get("selected_tags") or []
            patient_age = body_json.get("age")
            patient_sex = body_json.get("sex")
            client_offline = bool(body_json.get("offline", False))

            analysis = gemini_service.analyze_patient_presentation(
                free_text=free_text,
                vitals=vitals,
                selected_tags=selected_tags,
                patient_age=patient_age,
                patient_sex=patient_sex,
                client_offline=client_offline,
            )

            if body_json.get("save") is True or body_json.get("save_assessment") is True:
                asmt_record = database.save_symptom_assessment({
                    **analysis,
                    "patient_id": body_json.get("patient_id", "PAT-AUTO"),
                    "free_text_description": free_text,
                })
                self._send_json_response(HTTPStatus.OK, {"status": "success", "analysis": analysis, "saved_record": asmt_record})
            else:
                self._send_json_response(HTTPStatus.OK, {"status": "success", "analysis": analysis})
            return

        # 14. Create / Register Clinical Tag (/api/v1/tags)
        if path == "/api/v1/tags":
            name = body_json.get("name")
            if not name:
                self._send_json_response(HTTPStatus.BAD_REQUEST, {"error": "Missing required field 'name'"})
                return
            category = body_json.get("category", "general")
            created_by = body_json.get("created_by") or actor_id
            is_builtin = int(body_json.get("is_builtin", 0))
            is_ai_suggested = int(body_json.get("is_ai_suggested", 0))

            tag, err = database.add_clinical_tag(name, category, created_by, is_builtin, is_ai_suggested)
            if err:
                self._send_json_response(HTTPStatus.BAD_REQUEST, {"error": err})
            else:
                self._send_json_response(HTTPStatus.CREATED, {"status": "success", "tag": tag})
            return

        # 15. Offline Batch Sync Queue (/api/v1/sync/queue)
        if path == "/api/v1/sync/queue":
            items = body_json.get("items", [])
            res = database.process_offline_sync_batch(items)
            self._send_json_response(HTTPStatus.OK, res)
            return

        # 16. Update Referral Delivery Lifecycle (/api/v1/referrals/<id>/lifecycle)
        if path.startswith("/api/v1/referrals/") and path.endswith("/lifecycle"):
            ref_id = path.split("/")[4]
            new_state = body_json.get("state") or body_json.get("current_state")
            patient_id = body_json.get("patient_id", "PAT-UNSPECIFIED")
            facility_id = body_json.get("receiving_facility_id", "indore_hospital_001")
            is_amb = bool(body_json.get("is_ambulance_dispatched", False))
            amb_source = body_json.get("ambulance_source")
            facility_ack = body_json.get("facility_acknowledged_by")

            rec, err = database.update_referral_lifecycle(
                referral_id=ref_id,
                patient_id=patient_id,
                receiving_facility_id=facility_id,
                new_state=new_state,
                is_ambulance_dispatched=is_amb,
                ambulance_source=amb_source,
                facility_acknowledged_by=facility_ack,
            )
            if err:
                self._send_json_response(HTTPStatus.BAD_REQUEST, {"error": err})
            else:
                self._send_json_response(HTTPStatus.OK, {"status": "success", "lifecycle": rec})
            return

        # 17. Save Symptom Assessment (/api/v1/assessments)
        if path == "/api/v1/assessments":
            rec = database.save_symptom_assessment(body_json)
            self._send_json_response(HTTPStatus.CREATED, {"status": "success", "assessment": rec})
            return

        self._send_json_response(HTTPStatus.NOT_FOUND, {"error": "Endpoint not found"})

    def do_PUT(self):
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/")
        actor_id, actor_role = self._parse_auth()

        content_len = int(self.headers.get("Content-Length", 0))
        body_bytes = self.rfile.read(content_len) if content_len > 0 else b"{}"
        try:
            body_json = json.loads(body_bytes.decode("utf-8")) if body_bytes else {}
        except Exception as e:
            self._send_json_response(HTTPStatus.BAD_REQUEST, {"error": f"Invalid JSON payload: {e}"})
            return

        # 1. Update Operational Status (/api/v1/facilities/<id>/status)
        if path.startswith("/api/v1/facilities/") and path.endswith("/status"):
            parts = path.split("/")
            fac_id = parts[4]
            updated_fac, err = database.update_operational_status(
                facility_id=fac_id,
                status_data=body_json,
                actor_id=actor_id,
                actor_role=actor_role,
            )
            if err:
                self._send_json_response(HTTPStatus.BAD_REQUEST, {"error": err})
            else:
                self._send_json_response(
                    HTTPStatus.OK,
                    {
                        "status": "success",
                        "facility": updated_fac,
                        "serverRevision": updated_fac["revision"],
                    },
                )
            return

        # 2. Doctor Verification Review (/api/v1/doctors/<id>/verify)
        if path.startswith("/api/v1/doctors/") and path.endswith("/verify"):
            parts = path.split("/")
            doc_id = parts[4]
            decision = body_json.get("decision", "")
            reason = body_json.get("reason")
            notes = body_json.get("notes")

            doc, err = database.verify_doctor(
                doctor_id=doc_id,
                decision=decision,
                reviewer_id=actor_id,
                reviewer_role=actor_role,
                reason=reason,
                notes=notes,
            )
            if err:
                code = HTTPStatus.FORBIDDEN if "Unauthorized" in err else HTTPStatus.BAD_REQUEST
                self._send_json_response(code, {"error": err})
            else:
                self._send_json_response(HTTPStatus.OK, {"status": "success", "doctor": doc})
            return

        # 3. Update Facility Resource (/api/v1/facilities/<id>/resources/<resource_id>)
        if path.startswith("/api/v1/facilities/") and "/resources/" in path:
            parts = path.split("/")
            fac_id = parts[4]
            res_id = parts[6]
            item, err = database.update_facility_resource(fac_id, res_id, body_json, actor_id=actor_id, actor_role=actor_role)
            if err:
                code = HTTPStatus.FORBIDDEN if "Unauthorized" in err else HTTPStatus.BAD_REQUEST
                self._send_json_response(code, {"error": err})
            else:
                self._send_json_response(HTTPStatus.OK, {"status": "success", "resource": item})
            return

        # 4. Update Facility Capacity (/api/v1/facilities/<id>/capacity)
        if path.startswith("/api/v1/facilities/") and path.endswith("/capacity"):
            parts = path.split("/")
            fac_id = parts[4]
            cap_records = body_json.get("capacity") or body_json
            if isinstance(cap_records, dict):
                cap_records = [cap_records]
            cap, err = database.update_facility_capacity(fac_id, cap_records, actor_id=actor_id, actor_role=actor_role)
            if err:
                code = HTTPStatus.FORBIDDEN if "Unauthorized" in err else HTTPStatus.BAD_REQUEST
                self._send_json_response(code, {"error": err})
            else:
                self._send_json_response(HTTPStatus.OK, {"status": "success", "capacity": cap})
            return

        # 5. Update Facility Profile & Supporting Infrastructure (/api/v1/facilities/<id>/profile)
        if path.startswith("/api/v1/facilities/") and path.endswith("/profile"):
            parts = path.split("/")
            fac_id = parts[4]
            data, err = database.update_facility_profile(fac_id, body_json, actor_id=actor_id, actor_role=actor_role)
            if err:
                code = HTTPStatus.FORBIDDEN if "Unauthorized" in err else HTTPStatus.BAD_REQUEST
                self._send_json_response(code, {"error": err})
            else:
                self._send_json_response(HTTPStatus.OK, {"status": "success", "data": data})
            return

        # 6. Update Staff Affiliation (/api/v1/facilities/<id>/staff/<affil_id>)
        if path.startswith("/api/v1/facilities/") and "/staff/" in path:
            parts = path.split("/")
            fac_id = parts[4]
            affil_id = parts[6]
            staff, err = database.update_facility_staff_affiliation(fac_id, affil_id, body_json, actor_id=actor_id, actor_role=actor_role)
            if err:
                code = HTTPStatus.FORBIDDEN if "Unauthorized" in err else HTTPStatus.BAD_REQUEST
                self._send_json_response(code, {"error": err})
            else:
                self._send_json_response(HTTPStatus.OK, {"status": "success", "staff": staff})
            return

        # 7. Update Clinical Department (/api/v1/facilities/<id>/departments/<dept_id>)
        if path.startswith("/api/v1/facilities/") and "/departments/" in path:
            parts = path.split("/")
            fac_id = parts[4]
            dept_id = parts[6]
            dept, err = database.update_facility_department(fac_id, dept_id, body_json, actor_id=actor_id, actor_role=actor_role)
            if err:
                code = HTTPStatus.FORBIDDEN if "Unauthorized" in err else HTTPStatus.BAD_REQUEST
                self._send_json_response(code, {"error": err})
            else:
                self._send_json_response(HTTPStatus.OK, {"status": "success", "department": dept})
            return

        self._send_json_response(HTTPStatus.NOT_FOUND, {"error": "Endpoint not found"})

    def do_DELETE(self):
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/")
        actor_id, actor_role = self._parse_auth()

        # Delete / Decommission Facility Resource (/api/v1/facilities/<id>/resources/<resource_id>)
        if path.startswith("/api/v1/facilities/") and "/resources/" in path:
            parts = path.split("/")
            fac_id = parts[4]
            res_id = parts[6]
            ok, err = database.delete_facility_resource(fac_id, res_id, actor_id=actor_id, actor_role=actor_role)
            if err:
                code = HTTPStatus.FORBIDDEN if "Unauthorized" in err else HTTPStatus.BAD_REQUEST
                self._send_json_response(code, {"error": err})
            else:
                self._send_json_response(HTTPStatus.OK, {"status": "success", "deleted": True})
            return

        # Deactivate Staff Affiliation (/api/v1/facilities/<id>/staff/<affil_id>)
        if path.startswith("/api/v1/facilities/") and "/staff/" in path:
            parts = path.split("/")
            fac_id = parts[4]
            affil_id = parts[6]
            ok, err = database.delete_facility_staff_affiliation(fac_id, affil_id, actor_id=actor_id, actor_role=actor_role)
            if err:
                code = HTTPStatus.FORBIDDEN if "Unauthorized" in err else HTTPStatus.BAD_REQUEST
                self._send_json_response(code, {"error": err})
            else:
                self._send_json_response(HTTPStatus.OK, {"status": "success", "deleted": True})
            return

        # Delete Clinical Department (/api/v1/facilities/<id>/departments/<dept_id>)
        if path.startswith("/api/v1/facilities/") and "/departments/" in path:
            parts = path.split("/")
            fac_id = parts[4]
            dept_id = parts[6]
            ok, err = database.delete_facility_department(fac_id, dept_id, actor_id=actor_id, actor_role=actor_role)
            if err:
                code = HTTPStatus.FORBIDDEN if "Unauthorized" in err else HTTPStatus.BAD_REQUEST
                self._send_json_response(code, {"error": err})
            else:
                self._send_json_response(HTTPStatus.OK, {"status": "success", "deleted": True})
            return

        # Delete / Deactivate Clinical Tag (/api/v1/tags/<tag_id>)
        if path.startswith("/api/v1/tags/"):
            tag_id = path.replace("/api/v1/tags/", "").strip()
            database.delete_clinical_tag(tag_id)
            self._send_json_response(HTTPStatus.OK, {"status": "success", "deleted": True})
            return

        self._send_json_response(HTTPStatus.NOT_FOUND, {"error": "Endpoint not found"})


def run_server():
    database.init_database()
    server_address = (HOST, PORT)
    httpd = ThreadingHTTPServer(server_address, CentralSyncApiHandler)
    print(f"=================================================================")
    print(f"  SMART Referral Central Sync Backend Server")
    print(f"  Listening on http://{HOST}:{PORT}")
    print(f"  Health Check: http://localhost:{PORT}/api/v1/health")
    print(f"  Facilities:   http://localhost:{PORT}/api/v1/facilities")
    print(f"  Sync Pull:    http://localhost:{PORT}/api/v1/sync/pull")
    print(f"=================================================================")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down server...")
        httpd.server_close()


if __name__ == "__main__":
    run_server()
