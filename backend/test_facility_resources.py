import unittest
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import database


class TestFacilityResourcesBackend(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        database.init_database()
        cls.facility_id = "indore_hospital_001"

    def test_01_get_facility_resources_complete(self):
        res = database.get_facility_resources_complete(self.facility_id)
        self.assertIsNotNone(res)
        self.assertEqual(res["facility_id"], self.facility_id)
        self.assertIn("profile", res)
        self.assertIn("supporting_infrastructure", res)
        self.assertIn("capacity", res)
        self.assertIn("inventory", res)
        self.assertIn("departments", res)
        self.assertIn("staff", res)
        self.assertIn("summary", res)
        self.assertGreaterEqual(len(res["inventory"]), 8)
        self.assertGreaterEqual(len(res["capacity"]), 8)

    def test_02_all_45_facilities_have_resources(self):
        facilities = database.get_all_facilities()
        self.assertEqual(len(facilities), 45, "Must preserve all 45 preloaded Indore healthcare facilities")
        for fac in facilities:
            fid = fac["hospitalId"]
            res = database.get_facility_resources_complete(fid)
            self.assertIsNotNone(res, f"Facility {fid} should have complete resources")
            self.assertGreater(len(res["capacity"]), 0, f"Facility {fid} should have capacity records")

    def test_03_crud_facility_resource(self):
        # 1. Add Resource
        item_data = {
            "resource_name": "Test Portable Ultrasound Unit",
            "resource_category": "diagnostic_and_imaging",
            "model_spec": "Sonosite Edge II",
            "quantity_installed": 2,
            "quantity_operational": 2,
            "quantity_out_of_service": 0,
            "operational_status": "operational",
            "location_in_facility": "Emergency Room Triage",
            "ownership_type": "in_house_owned",
            "service_delivery": "in_house",
            "availability_schedule": "24/7",
            "operator_requirements": "requires_radiologist",
        }
        item, err = database.add_facility_resource(self.facility_id, item_data, actor_id="admin_user", actor_role="admin")
        self.assertIsNone(err)
        self.assertIsNotNone(item)
        res_id = item["resource_id"]
        self.assertEqual(item["resource_name"], "Test Portable Ultrasound Unit")

        # 2. Update Resource
        update_data = {
            "quantity_operational": 1,
            "quantity_out_of_service": 1,
            "operational_status": "limited_capacity",
            "notes": "Transducer undergoing routine maintenance",
        }
        updated, err = database.update_facility_resource(self.facility_id, res_id, update_data, actor_id="admin_user", actor_role="admin")
        self.assertIsNone(err)
        self.assertEqual(updated["quantity_operational"], 1)
        self.assertEqual(updated["operational_status"], "limited_capacity")

        # 3. Verify Resource
        verified, err = database.verify_facility_resource(
            self.facility_id, res_id, decision="approved", reviewer_id="auditor_test", reviewer_role="district_officer", notes="Calibration verified"
        )
        self.assertIsNone(err)
        self.assertEqual(verified["verification_status"], "verified")

        # 4. Decommission / Delete Resource
        deleted, err = database.delete_facility_resource(self.facility_id, res_id, actor_id="admin_user", actor_role="admin")
        self.assertIsNone(err)
        self.assertTrue(deleted)

    def test_04_capacity_update_and_synchronization(self):
        new_capacity = [
            {"category": "general_inpatient", "installed_capacity": 100, "operational_capacity": 90, "occupied_capacity": 60},
            {"category": "icu_beds", "installed_capacity": 20, "operational_capacity": 18, "occupied_capacity": 12},
            {"category": "emergency_bays", "installed_capacity": 10, "operational_capacity": 10, "occupied_capacity": 4},
        ]
        cap, err = database.update_facility_capacity(self.facility_id, new_capacity, actor_id="duty_officer", actor_role="hospital_duty_officer")
        self.assertIsNone(err)
        self.assertIsNotNone(cap)

        # Check that facility profile / live status reflects synchronized availability
        fac = database.get_facility_by_id(self.facility_id)
        # General: 90 - 60 = 30; ICU: 18 - 12 = 6; Emergency: 10 - 4 = 6; Total beds available: 30 + 6 + 6 = 42
        self.assertGreater(fac["bedAvailability"], 0)
        self.assertEqual(fac["operationalStatus"]["icuBedsAvailable"], 6)

    def test_05_authorization_enforcement(self):
        # Attempting modification by unauthenticated or unauthorized public client should be blocked
        item_data = {"resource_name": "Unauthorized Equipment", "resource_category": "emergency_and_trauma"}
        item, err = database.add_facility_resource(self.facility_id, item_data, actor_id="guest_client", actor_role="public_read")
        self.assertIsNotNone(err)
        self.assertIn("Unauthorized", err)

        # Non-auditor trying to verify resource should be blocked
        ver, err = database.verify_facility_resource(self.facility_id, "res_any", reviewer_id="clinician_user", reviewer_role="clinician")
        self.assertIsNotNone(err)
        self.assertIn("Unauthorized", err)

    def test_06_department_crud_and_management(self):
        # 1. Fetch existing departments
        depts = database.get_facility_departments(self.facility_id)
        self.assertGreater(len(depts), 0)
        self.assertTrue(any(d["department_name"] == "Emergency Department" for d in depts))

        # 2. Add New Clinical Department
        new_dept = {
            "department_name": "Cardiology & Interventional Cath Suite",
            "specialties": ["Interventional Cardiology", "Electrophysiology"],
            "services": ["Coronary Angiography", "Primary PCI", "Pacemaker Implantation"],
            "operational_days": "Mon-Sun",
            "operating_hours": "24 Hours",
            "appointment_mode": "Walk-in & Appointment",
            "emergency_available": True,
            "specialist_coverage": "on_site",
            "care_levels": ["outpatient", "inpatient", "day_care", "emergency"],
            "head_of_department": "Dr. Rajesh Sharma, MD DM Cardiology",
            "is_operational": True,
        }
        added, err = database.add_facility_department(self.facility_id, new_dept, actor_id="admin_user", actor_role="admin")
        self.assertIsNone(err)
        self.assertIsNotNone(added)
        dept_id = added["department_id"]
        self.assertEqual(added["department_name"], "Cardiology & Interventional Cath Suite")
        self.assertEqual(added["specialist_coverage"], "on_site")

        # 3. Update Department (e.g. temporary closure / maintenance restriction)
        updated, err = database.update_facility_department(
            self.facility_id,
            dept_id,
            {
                "is_operational": 0,
                "temporary_closure_reason": "Cath Lab bi-plane detector scheduled software calibration (4 hours)",
            },
            actor_id="admin_user",
            actor_role="admin",
        )
        self.assertIsNone(err)
        self.assertEqual(updated["is_operational"], 0)
        self.assertEqual(updated["temporary_closure_reason"], "Cath Lab bi-plane detector scheduled software calibration (4 hours)")

        # 4. Delete / Cleanup Department
        ok, err = database.delete_facility_department(self.facility_id, dept_id, actor_id="admin_user", actor_role="admin")
        self.assertIsNone(err)
        self.assertTrue(ok)

    def test_07_audit_trail_and_data_provenance(self):
        # Verify that verification records are properly recorded with actor, role, decision, timestamp
        res = database.get_facility_resources_complete(self.facility_id)
        verif = res.get("verification_records", [])
        self.assertGreater(len(verif), 0)
        first_verif = verif[0]
        self.assertIn("verified_at", first_verif)
        self.assertIn("reviewed_by", first_verif)
        self.assertIn("decision", first_verif)


if __name__ == "__main__":
    unittest.main()
