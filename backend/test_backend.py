"""
Automated unit tests for Central Backend database and synchronization logic.
"""

import json
import os
import sys
import unittest
import urllib.request
import urllib.error

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import database
import hierarchical_ranking


class BackendDatabaseTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        database.init_database()
        conn = database.get_db_connection()
        conn.execute("DELETE FROM doctor_profiles WHERE email LIKE 'dr.ananya.sharma%'")
        conn.commit()
        conn.close()

    def test_01_facilities_seeded(self):
        facs = database.get_all_facilities()
        self.assertGreaterEqual(len(facs), 45, "Should have at least 45 facilities seeded.")
        first = facs[0]
        self.assertIn("hospitalId", first)
        self.assertIn("name", first)
        self.assertIn("specialties", first)
        self.assertIn("operationalStatus", first)

    def test_02_search_facilities(self):
        apollo = database.get_all_facilities(query="Apollo")
        self.assertGreaterEqual(len(apollo), 1)
        self.assertEqual(apollo[0]["hospitalId"], "indore_hospital_001")

    def test_03_filter_by_specialty(self):
        cardio = database.get_all_facilities(specialty="Cardiology")
        self.assertGreaterEqual(len(cardio), 1)
        for c in cardio:
            self.assertTrue(any("cardio" in s.lower() for s in c["specialties"]))

    def test_04_update_operational_status(self):
        fac_id = "indore_hospital_001"
        initial = database.get_facility_by_id(fac_id)
        init_rev = initial["revision"]

        update_payload = {
            "operatingStatus": "Busy",
            "generalBedsAvailable": 14,
            "icuBedsAvailable": 2,
            "currentCapacity": 0.91,
        }
        updated, err = database.update_operational_status(
            fac_id,
            update_payload,
            actor_id="Dr. Saxena",
            actor_role="hospital_duty_officer",
        )
        self.assertIsNone(err)
        self.assertIsNotNone(updated)
        self.assertEqual(updated["operatingStatus"], "Busy")
        self.assertEqual(updated["bedAvailability"], 14)
        self.assertEqual(updated["revision"], init_rev + 1)

    def test_05_sync_pull_incremental(self):
        pull_all = database.sync_pull(since_revision=0)
        self.assertIn("serverRevision", pull_all)
        self.assertGreaterEqual(pull_all["count"], 45)

        # Pull with high revision should return zero or few changed facilities
        pull_high = database.sync_pull(since_revision=pull_all["serverRevision"])
        self.assertEqual(pull_high["count"], 0)

    def test_06_sync_push_and_idempotency(self):
        fac_id = "indore_hospital_002"
        fac = database.get_facility_by_id(fac_id)
        current_rev = fac["revision"]

        changes = [
            {
                "facilityId": fac_id,
                "operation": "UPDATE_STATUS",
                "clientRevision": current_rev,
                "payload": {
                    "operatingStatus": "Operational",
                    "generalBedsAvailable": 42,
                    "icuBedsAvailable": 6,
                },
            }
        ]

        resp1, err = database.sync_push(
            client_id="tablet_clinic_01",
            changes=changes,
            idempotency_key="idemp_key_101",
            actor_id="Nurse In-Charge",
        )
        self.assertIsNone(err)
        self.assertEqual(resp1["processedCount"], 1)

        # Duplicate push with same idempotency key
        resp2, err2 = database.sync_push(
            client_id="tablet_clinic_01",
            changes=changes,
            idempotency_key="idemp_key_101",
            actor_id="Nurse In-Charge",
        )
        self.assertIsNone(err2)
        self.assertEqual(resp1, resp2, "Idempotent response must match exactly")

    def test_07_audit_logs(self):
        logs = database.get_audit_logs(limit=10)
        self.assertGreaterEqual(len(logs), 1)
        self.assertIn("action", logs[0])
        self.assertIn("timestamp", logs[0])

    def test_08_doctor_registration_and_provisional_score(self):
        doc_data = {
            "fullName": "Dr. Ananya Sharma",
            "displayName": "Dr. A. Sharma",
            "email": "dr.ananya.sharma@example.com",
            "phoneNumber": "9826011223",
            "medicalRegNumber": "MPMC-54321",
            "councilName": "Madhya Pradesh Medical Council",
            "registrationYear": 2017,
            "primaryQualificationType": "postgraduate_md_ms_dnb",
            "primaryQualificationName": "MD General Medicine",
            "awardingInstitution": "MGM Medical College, Indore",
            "completionYear": 2017,
            "primarySpecialty": "Internal Medicine",
            "primaryPracticeEnvironment": "tertiary_hospital",
            "facilityId": "indore_hospital_001",
            "totalExperienceYears": 9,
            "annualPatientVolume": 3200,
            "associationMemberships": ["Indian Medical Association", "Association of Physicians of India"],
            "governmentSchemesSummary": "Ayushman Bharat / PM-JAY Empaneled Consultant",
            "capabilities": ["General consultation", "Emergency stabilization", "Diabetes management"],
        }

        doctor, err = database.register_doctor(doc_data)
        self.assertIsNone(err)
        self.assertIsNotNone(doctor)
        self.assertEqual(doctor["full_name"], "Dr. Ananya Sharma")
        # Newly registered doctor remains unverified
        self.assertEqual(doctor["verification_status"], "pending")
        self.assertIn("capabilityScore", doctor)

        scores = doctor["capabilityScore"]
        # Base: MD = 25.0, Exp: 9 * 1.5 = 13.5, Vol: 3200 > 3000 = 25.0, Standing: IMA(5) + API(5) + PM-JAY(5) = 15.0
        self.assertEqual(scores["base_expertise_score"], 25.0)
        self.assertEqual(scores["clinical_experience_score"], 13.5)
        self.assertEqual(scores["clinical_volume_score"], 25.0)
        self.assertEqual(scores["professional_standing_score"], 15.0)
        self.assertEqual(scores["total_capability_score"], 78.5)
        self.assertEqual(scores["is_provisional"], 1)

    def test_09_duplicate_doctor_prevention(self):
        duplicate_data = {
            "fullName": "Dr. Duplicate Test",
            "email": "dr.ananya.sharma@example.com",  # Duplicate email
            "phoneNumber": "9800000000",
            "medicalRegNumber": "MPMC-99999",
            "councilName": "Madhya Pradesh Medical Council",
            "primaryQualificationName": "MBBS",
            "primarySpecialty": "General Practice",
            "primaryPracticeEnvironment": "independent_clinic",
        }
        doc, err = database.register_doctor(duplicate_data)
        self.assertIsNone(doc)
        self.assertIn("already registered", err)

    def test_10_fair_normalized_scoring_clinic_vs_hospital(self):
        # Clinic doctor with high continuity of care and community workload
        clinic_doctor = {
            "primaryQualificationType": "primary_mbbs",
            "primaryPracticeEnvironment": "independent_clinic",
            "totalExperienceYears": 10,
            "annualPatientVolume": 2200,
            "associationMemberships": ["Indian Medical Association"],
            "governmentSchemesSummary": "CM Sanjeevani Clinic Doctor",
        }
        score = database.calculate_doctor_capability_score(clinic_doctor)
        # Base: 15, Exp: 15, Volume: 25.0 (>= 2000 clinic visits), Standing: 5 + 5 = 10
        self.assertEqual(score["baseExpertiseScore"], 15.0)
        self.assertEqual(score["clinicalExperienceScore"], 15.0)
        self.assertEqual(score["clinicalVolumeScore"], 25.0)
        self.assertEqual(score["professionalStandingScore"], 10.0)
        self.assertEqual(score["totalCapabilityScore"], 65.0)

    def test_11_doctor_verification_by_admin_and_rejection_of_self_approval(self):
        doc = database.get_doctor_by_id("doc_", is_public=False)
        # Find Ananya
        conn = database.get_db_connection()
        row = conn.execute("SELECT doctor_id FROM doctor_profiles WHERE email = ?", ("dr.ananya.sharma@example.com",)).fetchone()
        conn.close()
        doc_id = row["doctor_id"]

        # Doctor cannot approve themselves (clinician role fails)
        _, err = database.verify_doctor(doc_id, "approved", reviewer_id=doc_id, reviewer_role="doctor")
        self.assertIn("Unauthorized", err)

        # Official admin approves
        verified_doc, err2 = database.verify_doctor(doc_id, "approved", reviewer_id="admin_dho_01", reviewer_role="admin")
        self.assertIsNone(err2)
        self.assertEqual(verified_doc["verification_status"], "verified")
        self.assertEqual(verified_doc["capabilityScore"]["is_provisional"], 0)

    def test_12_privacy_masking_on_public_profiles(self):
        conn = database.get_db_connection()
        row = conn.execute("SELECT doctor_id FROM doctor_profiles WHERE email = ?", ("dr.ananya.sharma@example.com",)).fetchone()
        conn.close()
        doc_id = row["doctor_id"]

        public_view = database.get_doctor_by_id(doc_id, is_public=True)
        self.assertNotIn("documents", public_view)
        self.assertTrue("******" in public_view["phoneNumber"])

    def test_13_authoritative_45_facilities_integrity(self):
        """Verify authoritative facility count is exactly 45 and ID ranges are preserved."""
        facs = database.get_all_facilities()
        self.assertEqual(len(facs), 45, "Must have exactly 45 authoritative healthcare facilities.")

        ids = [f["hospitalId"] for f in facs]
        self.assertEqual(len(ids), len(set(ids)), "Facility IDs must be strictly unique.")

        # Verify indore_hospital_001 to 020
        for i in range(1, 21):
            expected_id = f"indore_hospital_{i:03d}"
            self.assertIn(expected_id, ids, f"Missing expected hospital ID: {expected_id}")

        # Verify indore_healthcare_021 to 045
        for i in range(21, 46):
            expected_id = f"indore_healthcare_{i:03d}"
            self.assertIn(expected_id, ids, f"Missing expected clinic/center ID: {expected_id}")

    def test_14_synthetic_data_isolation(self):
        """Verify strict data isolation: synthetic profiles excluded from production queries."""
        real_docs = database.get_all_doctors(include_synthetic=False)
        for doc in real_docs:
            self.assertNotEqual(doc.get("is_synthetic"), 1, "Production query must never return synthetic doctor.")
            self.assertNotEqual(doc.get("record_source"), "synthetic_demo")

        synthetic_docs = database.get_all_doctors(include_synthetic=True)
        synthetic_only = [d for d in synthetic_docs if d.get("is_synthetic") == 1]
        self.assertEqual(len(synthetic_only), 16, "Must have exactly 16 synthetic clinicians seeded.")

        for s_doc in synthetic_only:
            self.assertEqual(s_doc.get("record_source"), "synthetic_demo")
            self.assertEqual(s_doc.get("verification_status"), "unverified_demo")
            self.assertIn("SIMULATED DATA", s_doc.get("data_notice", ""))

    def test_15_condition_capability_requirements(self):
        """Verify all 8 clinical conditions have defined technical capability requirements."""
        conditions = database.get_condition_requirements()
        self.assertEqual(len(conditions), 8, "Must support all 8 condition keys.")

        expected_keys = [
            "suspected_heart_attack",
            "suspected_stroke",
            "major_trauma",
            "pediatric_respiratory_distress",
            "pregnancy_danger_signs",
            "severe_sepsis",
            "acute_respiratory_distress",
            "diabetes_followup",
        ]
        for key in expected_keys:
            req = database.get_condition_requirements(key)
            self.assertIsNotNone(req, f"Missing requirements for condition: {key}")
            self.assertIn("condition_name", req)
            self.assertIn("essential_equipment", req)
            self.assertIn("required_specialties", req)

    def test_16_hierarchical_ranking_essential_gating(self):
        """Verify Priority 1 technical capability gate prevents unqualified nearby clinics from outranking equipped tertiary hospitals."""
        # Indore central coordinates
        lat, lng = 22.7196, 75.8577
        res = hierarchical_ranking.rank_facilities_hierarchical(
            "suspected_heart_attack",
            lat,
            lng,
            include_synthetic=False,
        )

        self.assertIn("ranked_recommendations", res)
        self.assertIn("excluded_facilities", res)
        self.assertGreaterEqual(len(res["ranked_recommendations"]), 1)

        # Apollo Hospitals Indore should be ranked #1 for heart attack due to Cath Lab + Cardiology
        top_rec = res["ranked_recommendations"][0]
        self.assertEqual(top_rec["rank"], 1)
        self.assertIn("Apollo", top_rec["facility_name"])

        # Check that excluded facilities have explicit missing capability reasons
        for excluded in res["excluded_facilities"]:
            eval_info = excluded["technical_evaluation"]
            self.assertFalse(eval_info["is_eligible"])
            self.assertGreater(len(eval_info["missing_essential_capabilities"]), 0)

    def test_17_hierarchical_ranking_all_8_conditions(self):
        """Verify hierarchical ranking evaluates cleanly across all 8 condition keys."""
        condition_keys = [
            "suspected_heart_attack",
            "suspected_stroke",
            "major_trauma",
            "pediatric_respiratory_distress",
            "pregnancy_danger_signs",
            "severe_sepsis",
            "acute_respiratory_distress",
            "diabetes_followup",
        ]
        lat, lng = 22.7196, 75.8577

        for key in condition_keys:
            res = hierarchical_ranking.rank_facilities_hierarchical(
                key,
                lat,
                lng,
                include_synthetic=True,
            )
            self.assertEqual(res["condition_key"], key)
            self.assertEqual(res["total_evaluated_facilities"], 45)
            self.assertEqual(len(res["ranking_hierarchy"]), 3)
            total = len(res["ranked_recommendations"]) + len(res["excluded_facilities"])
            self.assertEqual(total, 45, f"All 45 facilities must be accounted for condition {key}.")

    def test_18_server_http_endpoints(self):
        """Verify backend HTTP REST API endpoints live on http://localhost:8000."""
        # 1. Health check
        req = urllib.request.Request("http://localhost:8000/api/v1/health")
        with urllib.request.urlopen(req, timeout=5) as response:
            self.assertEqual(response.status, 200)
            data = json.loads(response.read().decode())
            self.assertEqual(data.get("status"), "healthy")
            self.assertEqual(data.get("authoritativeFacilitiesCount"), 45)

        # 2. Conditions list
        req = urllib.request.Request("http://localhost:8000/api/v1/conditions")
        with urllib.request.urlopen(req, timeout=5) as response:
            self.assertEqual(response.status, 200)
            data = json.loads(response.read().decode())
            self.assertEqual(data.get("count"), 8)

        # 3. Doctors list for facility
        req = urllib.request.Request("http://localhost:8000/api/v1/facilities/indore_hospital_001/doctors?include_synthetic=true")
        with urllib.request.urlopen(req, timeout=5) as response:
            self.assertEqual(response.status, 200)
            data = json.loads(response.read().decode())
            self.assertIn("doctors", data)
            self.assertGreaterEqual(data.get("count"), 1)

        # 4. Hierarchical referral rank POST
        rank_payload = json.dumps({
            "condition_key": "suspected_heart_attack",
            "latitude": 22.7196,
            "longitude": 75.8577,
            "include_synthetic": False
        }).encode("utf-8")
        req = urllib.request.Request(
            "http://localhost:8000/api/v1/referrals/hierarchical-rank",
            data=rank_payload,
            headers={"Content-Type": "application/json"}
        )
        with urllib.request.urlopen(req, timeout=5) as response:
            self.assertEqual(response.status, 200)
            data = json.loads(response.read().decode())
            self.assertEqual(data.get("condition_key"), "suspected_heart_attack")
            self.assertIn("ranked_recommendations", data)
            self.assertEqual(data["ranked_recommendations"][0]["rank"], 1)


if __name__ == "__main__":
    unittest.main()
