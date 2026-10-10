import '../models/mock_data.dart';
import '../models/patient.dart';

/// Repository interface for patient record management.
abstract class PatientRepository {
  Future<List<Patient>> getAllPatients();
  Future<Patient?> getPatientById(String id);
  Future<void> savePatient(Patient patient);
  Future<bool> deletePatient(String id);
}

/// In-memory repository implementation initialized with synthetic patient cases.
class InMemoryPatientRepository implements PatientRepository {
  final Map<String, Patient> _storage = {};

  InMemoryPatientRepository({bool preloadMockData = true}) {
    if (preloadMockData) {
      for (final patient in MockClinicalData.samplePatients) {
        _storage[patient.patientId] = patient;
      }
    }
  }

  @override
  Future<List<Patient>> getAllPatients() async {
    return _storage.values.toList();
  }

  @override
  Future<Patient?> getPatientById(String id) async {
    return _storage[id];
  }

  @override
  Future<void> savePatient(Patient patient) async {
    _storage[patient.patientId] = patient;
  }

  @override
  Future<bool> deletePatient(String id) async {
    return _storage.remove(id) != null;
  }
}
