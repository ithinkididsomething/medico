"""
Unit and Integration Tests for Emergency Quick Referral System
Verifies:
1. Schema initialization and table creation.
2. Initial emergency referral creation with minimum and full clinical data.
3. Ambulance dispatch tracking without blocking clinical referral.
4. Post-dispatch editing and versioning (immutable v1 preservation, v2 amendment).
5. Direct messaging & email delivery simulation with emergency subjects.
6. Receiving team acknowledgement and acceptance tracking.
7. Clinical handover completion.
8. Audit trail recording for every lifecycle event.
"""

import json
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import database


class TestEmergencyReferralBackend(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        database.init_database()

    def test_01_create_emergency_referral_minimum_info(self):
        """1. Can create an emergency referral with minimum essential information."""
        min_payload = {
            "referral_id": "EMR-TEST-MIN-001",
            "patient_identifier": "PAT-UNKNOWN-MALE-40",
            "presenting_complaint": "Acute severe crushing chest pain with diaphoresis",
            "emergency_category": "STEMI_CARDIAC",
            "receiving_facility_id": "indore_hospital_001",
            "receiving_facility_name": "Indore Apex Tertiary Hospital",
        }
        ref, err = database.create_emergency_referral(
            min_payload,
            actor_id="doc_parth",
            actor_name="Dr. Parth Saxena",
        )
        self.assertIsNone(err)
        self.assertIsNotNone(ref)
        self.assertEqual(ref["referral_id"], "EMR-TEST-MIN-001")
        self.assertEqual(ref["current_version"], 1)
        self.assertEqual(ref["workflow_status"], "emergency_created")
        self.assertEqual(ref["delivery_status"], "not_sent")
        self.assertEqual(ref["response_status"], "no_response_yet")
        self.assertEqual(len(ref["versions"]), 1)
        self.assertEqual(ref["versions"][0]["version_number"], 1)
        self.assertIn("initial_creation", ref["versions"][0]["changed_fields"])

    def test_02_create_emergency_referral_with_ambulance_dispatch(self):
        """2. Ambulance dispatch is recorded immediately without delay."""
        payload = {
            "referral_id": "EMR-TEST-AMB-002",
            "patient_identifier": "PAT-SIM-202",
            "patient_name": "Ramesh Verma",
            "patient_age": 54,
            "patient_sex": "Male",
            "presenting_complaint": "Sudden onset left-sided weakness and slurred speech",
            "emergency_category": "ACUTE_STROKE",
            "red_flag_symptoms": ["Facial asymmetry", "Arm drift", "Speech slurring"],
            "symptom_onset_time": "35 minutes ago",
            "vitals_pulse": 98,
            "vitals_bp_systolic": 178,
            "vitals_bp_diastolic": 104,
            "vitals_spo2": 97,
            "consciousness_level": "Alert",
            "immediate_treatment_given": "High flow oxygen, head elevated 30 degrees, blood glucose checked 128 mg/dL",
            "ambulance_status": "en_route_scene",
            "ambulance_service_type": "108 EMTS ALS",
            "ambulance_vehicle_number": "MP-09-AB-1088",
            "ambulance_eta_minutes": 12,
            "receiving_facility_id": "indore_hospital_003",
            "receiving_facility_name": "CHL Hospital Indore",
            "receiving_department": "Comprehensive Stroke Unit",
        }
        ref, err = database.create_emergency_referral(payload)
        self.assertIsNone(err)
        self.assertIsNotNone(ref)
        self.assertEqual(ref["workflow_status"], "in_transit")
        self.assertEqual(ref["ambulance_status"], "en_route_scene")
        self.assertEqual(len(ref["dispatch_records"]), 1)
        self.assertEqual(ref["dispatch_records"][0]["vehicle_number"], "MP-09-AB-1088")

    def test_03_post_dispatch_editing_and_versioning(self):
        """3. Post-dispatch editing creates version 2, preserves version 1, and records diff."""
        ref_id = "EMR-TEST-AMB-002"
        update_data = {
            "vitals_bp_systolic": 164,
            "vitals_bp_diastolic": 96,
            "vitals_pulse": 88,
            "clinical_notes": "Patient transferred into ALS ambulance. GCS 14/15. IV access 18G secured.",
            "ambulance_status": "patient_loaded_in_transit",
            "ambulance_eta_minutes": 8,
            "amendmentReason": "En-route vitals update & IV line establishment",
        }
        ref_v2, err = database.add_emergency_referral_version(
            referral_id=ref_id,
            updated_data=update_data,
            actor_id="doc_parth",
            actor_name="Dr. Parth Saxena",
            amendment_reason="En-route vitals update & IV line establishment",
        )
        self.assertIsNone(err)
        self.assertEqual(ref_v2["current_version"], 2)
        self.assertEqual(ref_v2["vitals_bp_systolic"], 164)
        self.assertEqual(len(ref_v2["versions"]), 2)

        # Verify version 1 preserved
        v1 = ref_v2["versions"][0]
        self.assertEqual(v1["version_number"], 1)
        v1_snapshot = v1["snapshot_data"]
        self.assertEqual(v1_snapshot["vitals_bp_systolic"], 178)

        # Verify version 2 diff
        v2 = ref_v2["versions"][1]
        self.assertEqual(v2["version_number"], 2)
        self.assertIn("vitals_bp_systolic", v2["changed_fields"])
        self.assertEqual(v2["amendment_reason"], "En-route vitals update & IV line establishment")

    def test_04_send_emergency_referral_channels(self):
        """4. Referral notification can be dispatched directly with official emergency subject."""
        ref_id = "EMR-TEST-AMB-002"

        # Email dispatch
        ref, err = database.send_emergency_referral(
            referral_id=ref_id,
            channel="email",
            recipient_address="stroke-code@chlhospital.org",
            recipient_name="CHL Emergency Stroke Triage",
            custom_notes="Code Stroke activated on arrival. Please prepare CT scanner.",
        )
        self.assertIsNone(err)
        self.assertEqual(ref["delivery_status"], "sent_to_provider")
        self.assertGreaterEqual(len(ref["deliveries"]), 1)
        delivery = ref["deliveries"][0]
        self.assertEqual(delivery["channel"], "email")
        self.assertIn("URGENT EMERGENCY REFERRAL", delivery["subject_or_preview"])
        self.assertIn("EMR-TEST-AMB-002", delivery["subject_or_preview"])
        self.assertIn("Code Stroke activated", delivery["message_body"])

        # Secure Clinical Messaging dispatch
        ref2, err2 = database.send_emergency_referral(
            referral_id=ref_id,
            channel="clinical_message",
            recipient_address="doc_neuro_on_duty",
            recipient_name="Dr. Neurologist on Duty",
        )
        self.assertIsNone(err2)
        self.assertEqual(len(ref2["deliveries"]), 2)

    def test_05_receiving_team_acknowledgement_and_acceptance(self):
        """5. Receiving team acknowledgement and acceptance are recorded explicitly."""
        ref_id = "EMR-TEST-AMB-002"
        ref, err = database.record_emergency_acknowledgement(
            referral_id=ref_id,
            response_status="accepted",
            responder_name="Dr. Anil Deshmukh",
            responder_role="Senior Neurologist",
            notes="Stroke team and CT console mobilized. Bed #3 ICU reserved.",
        )
        self.assertIsNone(err)
        self.assertEqual(ref["response_status"], "accepted")
        self.assertEqual(len(ref["acknowledgements"]), 1)
        ack = ref["acknowledgements"][0]
        self.assertEqual(ack["response_status"], "accepted")
        self.assertEqual(ack["responder_name"], "Dr. Anil Deshmukh")

    def test_06_clinical_handover_completion(self):
        """6. Clinical handover completes referral lifecycle."""
        ref_id = "EMR-TEST-AMB-002"
        ref, err = database.record_emergency_handover(
            referral_id=ref_id,
            actor_id="paramedic_rajesh",
            actor_name="Paramedic Rajesh Sharma",
            notes="Patient transferred to Stroke Resuscitation Bay. Primary handover signed.",
        )
        self.assertIsNone(err)
        self.assertEqual(ref["workflow_status"], "handover_completed")
        self.assertEqual(ref["ambulance_status"], "arrived")

    def test_07_full_audit_trail_integrity(self):
        """7. Preserves an audit trail for all events."""
        ref_id = "EMR-TEST-AMB-002"
        ref = database.get_emergency_referral(ref_id)
        actions = [log["action"] for log in ref["audit_logs"]]
        self.assertIn("CREATED", actions)
        self.assertIn("VERSION_AMENDED", actions)
        self.assertIn("SENT_EMAIL", actions)
        self.assertIn("SENT_CLINICAL_MESSAGE", actions)
        self.assertIn("RESPONSE_ACCEPTED", actions)
        self.assertIn("HANDOVER_COMPLETED", actions)


if __name__ == "__main__":
    unittest.main()
