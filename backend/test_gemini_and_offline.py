"""
Unit & Integration Test Suite for Gemini Symptom Analysis,
Deterministic Offline Fallback Rules, Custom Clinical Tags, and Sync Queue.
"""

import unittest
import database
import clinical_rules
import gemini_service


class TestGeminiAndOffline(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        database.init_database()

    def test_01_mandatory_red_flags_trigger_level_1(self):
        # Postpartum hemorrhage
        res = clinical_rules.evaluate_clinical_presentation(
            free_text="Patient delivered 1 hour ago, excessive postpartum hemorrhage, active bleeding",
            vitals={"heart_rate": 120, "systolic_bp": 90},
        )
        self.assertEqual(res["urgency_level"], 1)
        self.assertEqual(res["referral_level"], "Referral D")
        self.assertTrue(res["is_emergency"])
        self.assertGreater(len(res["red_flags"]), 0)

        # Hypoxia SpO2 < 90%
        res_hypoxia = clinical_rules.evaluate_clinical_presentation(
            free_text="Difficulty breathing, cough",
            vitals={"spo2": 86, "heart_rate": 110},
        )
        self.assertEqual(res_hypoxia["urgency_level"], 1)
        self.assertEqual(res_hypoxia["referral_level"], "Referral D")
        self.assertTrue(res_hypoxia["is_emergency"])
        self.assertTrue(any("SpO2" in rf for rf in res_hypoxia["red_flags"]))

    def test_02_ambiguous_or_missing_info_never_reassuring_low_urgency(self):
        # Very brief note with missing vitals must not be Level 4
        res = clinical_rules.evaluate_clinical_presentation(
            free_text="Feeling dizzy and sick",
            vitals={},
        )
        self.assertNotEqual(res["urgency_level"], 4, "Ambiguous note with missing vitals must NOT be Level 4")
        self.assertTrue(len(res["missing_information"]) >= 2)

    def test_03_stable_mild_case_routine(self):
        res = clinical_rules.evaluate_clinical_presentation(
            free_text="Mild ankle pain since yesterday after walking, no swelling, no fracture",
            vitals={"systolic_bp": 120, "heart_rate": 72, "spo2": 98, "temp": 37.0},
        )
        self.assertEqual(res["urgency_level"], 4)
        self.assertEqual(res["referral_level"], "Referral A")
        self.assertFalse(res["is_emergency"])

    def test_04_gemini_service_safety_override(self):
        # Even if simulated or without API key, it should safely catch red flags
        res = gemini_service.analyze_patient_presentation(
            free_text="Sudden crushing chest pain radiating to left arm with sweating",
            vitals={"spo2": 89, "heart_rate": 138, "systolic_bp": 80},
            client_offline=True,
        )
        self.assertEqual(res["urgency_level"], 1)
        self.assertEqual(res["referral_level"], "Referral D")
        self.assertTrue(res["is_emergency"])
        self.assertEqual(res["assessment_source"], "offline_rules")

    def test_05_clinical_tags_crud(self):
        tags = database.get_all_clinical_tags()
        self.assertGreaterEqual(len(tags), 8, "Built-in clinical tags should be seeded")
        
        # Add new custom tag
        new_tag, err = database.add_clinical_tag(name="Rural Snakebite Protocol", category="toxicology", created_by="Dr. Ananya")
        self.assertIsNone(err)
        self.assertEqual(new_tag["name"], "Rural Snakebite Protocol")
        
        # Verify it shows in list
        tags_after = database.get_all_clinical_tags()
        self.assertTrue(any(t["name"] == "Rural Snakebite Protocol" for t in tags_after))

        # Soft delete
        database.delete_clinical_tag(new_tag["tag_id"])
        tags_deleted = database.get_all_clinical_tags()
        self.assertFalse(any(t["tag_id"] == new_tag["tag_id"] for t in tags_deleted))

    def test_06_idempotent_offline_sync_queue(self):
        import uuid
        idem_key = f"test_idem_key_{uuid.uuid4().hex}"
        batch = [
            {
                "idempotency_key": idem_key,
                "entity_type": "tag",
                "entity_id": f"tag_test_{uuid.uuid4().hex[:6]}",
                "action": "create",
                "payload": {"name": f"Test Synced Tag {uuid.uuid4().hex[:6]}", "category": "general"},
            }
        ]
        res1 = database.process_offline_sync_batch(batch)
        self.assertEqual(res1["processed_count"], 1)
        self.assertEqual(res1["skipped_count"], 0)

        # Resend exact batch (idempotency check)
        res2 = database.process_offline_sync_batch(batch)
        self.assertEqual(res2["processed_count"], 0)
        self.assertEqual(res2["skipped_count"], 1)

    def test_07_referral_lifecycle_tracking(self):
        import uuid
        ref_id = f"REF-TEST-{uuid.uuid4().hex[:8]}"
        pat_id = f"PAT-TEST-{uuid.uuid4().hex[:8]}"
        fac_id = "indore_hospital_001"

        # 1. assessment_saved
        rec, err = database.update_referral_lifecycle(ref_id, pat_id, fac_id, "assessment_saved")
        self.assertIsNone(err)
        self.assertEqual(rec["current_state"], "assessment_saved")
        self.assertEqual(rec["is_ambulance_dispatched"], 0)

        # 2. referral_draft_saved_locally
        rec2, _ = database.update_referral_lifecycle(ref_id, pat_id, fac_id, "referral_draft_saved_locally")
        self.assertEqual(rec2["current_state"], "referral_draft_saved_locally")

        # 3. referral_queued_for_transmission
        rec3, _ = database.update_referral_lifecycle(ref_id, pat_id, fac_id, "referral_queued_for_transmission")
        self.assertEqual(rec3["current_state"], "referral_queued_for_transmission")

        # 4. referral_successfully_sent
        rec4, _ = database.update_referral_lifecycle(ref_id, pat_id, fac_id, "referral_successfully_sent")
        self.assertEqual(rec4["current_state"], "referral_successfully_sent")

        # 5. ambulance_dispatched
        rec5, _ = database.update_referral_lifecycle(
            ref_id, pat_id, fac_id, "ambulance_dispatched",
            is_ambulance_dispatched=True, ambulance_source="108 Indore Central"
        )
        self.assertEqual(rec5["is_ambulance_dispatched"], 1)
        self.assertIsNotNone(rec5["ambulance_dispatched_at"])

    def test_08_extract_structured_facts_from_complex_text(self):
        text = "Patient has fever for two days, breathing difficulty, SpO2 88%, pulse 120 bpm and BP 90/60 mmHg."
        res = clinical_rules.evaluate_clinical_presentation(free_text=text)

        # Must extract vitals accurately
        vitals = res["extracted_vitals"]
        self.assertEqual(vitals.get("spo2"), 88.0)
        self.assertEqual(vitals.get("pulse"), 120)
        self.assertEqual(vitals.get("systolic_bp"), 90)
        self.assertEqual(vitals.get("diastolic_bp"), 60)
        self.assertEqual(res["duration"], "two days")

        # Must detect symptoms as separate items, not raw text dump
        self.assertIn("Fever", res["extracted_symptoms"])
        self.assertIn("Breathing difficulty", res["extracted_symptoms"])

        # Must trigger Level 1 Immediate Emergency without false clinician_required undetermined flag
        self.assertEqual(res["urgency_level"], 1)
        self.assertEqual(res["referral_level"], "Referral D")
        self.assertTrue(res["is_emergency"])
        self.assertFalse(res["is_undetermined"], "Complete emergency presentation must NOT be marked undetermined")
        self.assertEqual(res["analysis_status"], "safety_escalation")

    def test_09_gemini_status_differentiates_technical_from_clinical(self):
        # When no API key is provided, gemini_service returns technical status authentication_error
        res = gemini_service.analyze_patient_presentation(
            free_text="Patient has fever for two days, breathing difficulty, SpO2 88%, pulse 120 bpm and BP 90/60 mmHg.",
            client_offline=False,
        )
        self.assertFalse(res["gemini_available"])
        self.assertEqual(res["analysis_status"], "authentication_error")
        self.assertEqual(res["urgency_level"], 1)
        self.assertFalse(res["is_undetermined"])
        self.assertIn("No API key", res["source_label"])

    def test_10_malformed_json_fallback_handling(self):
        # Testing fallback output sanitizer directly
        fallback_data = clinical_rules.evaluate_clinical_presentation("Patient coughing with mild fever")
        sanitized = gemini_service._validate_and_sanitize_gemini_output(
            {"invalid_field": 123},
            fallback=fallback_data
        )
        self.assertIn("extracted_symptoms", sanitized)
        self.assertEqual(sanitized["urgency_level"], fallback_data["urgency_level"])


if __name__ == "__main__":
    unittest.main()
