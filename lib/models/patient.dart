import 'enums.dart';

/// Strongly typed Patient model capturing clinical presentation and vital signs.
class Patient {
  final String patientId;
  final int age;
  final Sex sex;
  final String mainComplaint;
  final List<String> symptoms;
  final String injuryOrIllnessDetails;
  final String clinicalFindings;
  final int? heartRate; // beats per minute (bpm)
  final int? systolicBP; // mmHg
  final int? diastolicBP; // mmHg
  final int? respiratoryRate; // breaths per minute
  final double? oxygenSaturation; // SpO2 percentage (e.g. 96.0)
  final double? temperature; // Celsius (e.g. 37.2)
  final String requiredSpecialty;
  final DateTime createdAt;
  final PatientConditionCategory? conditionCategory;

  const Patient({
    required this.patientId,
    required this.age,
    required this.sex,
    required this.mainComplaint,
    required this.symptoms,
    required this.injuryOrIllnessDetails,
    required this.clinicalFindings,
    this.heartRate,
    this.systolicBP,
    this.diastolicBP,
    this.respiratoryRate,
    this.oxygenSaturation,
    this.temperature,
    required this.requiredSpecialty,
    required this.createdAt,
    this.conditionCategory,
  });

  /// Blood pressure representation string (e.g., "120/80 mmHg" or "Not recorded").
  String get formattedBloodPressure {
    if (systolicBP != null && diastolicBP != null) {
      return '$systolicBP/$diastolicBP mmHg';
    } else if (systolicBP != null) {
      return '$systolicBP/- mmHg';
    }
    return 'Not recorded';
  }

  /// True if any essential vital signs cross clinical warning thresholds.
  bool get hasAbnormalVitals {
    if (heartRate != null && (heartRate! < 50 || heartRate! > 120)) return true;
    if (systolicBP != null && (systolicBP! < 90 || systolicBP! > 160)) return true;
    if (diastolicBP != null && (diastolicBP! < 60 || diastolicBP! > 100)) return true;
    if (respiratoryRate != null && (respiratoryRate! < 12 || respiratoryRate! > 26)) return true;
    if (oxygenSaturation != null && oxygenSaturation! < 92.0) return true;
    if (temperature != null && (temperature! < 35.5 || temperature! > 38.5)) return true;
    return false;
  }

  Patient copyWith({
    String? patientId,
    int? age,
    Sex? sex,
    String? mainComplaint,
    List<String>? symptoms,
    String? injuryOrIllnessDetails,
    String? clinicalFindings,
    int? heartRate,
    int? systolicBP,
    int? diastolicBP,
    int? respiratoryRate,
    double? oxygenSaturation,
    double? temperature,
    String? requiredSpecialty,
    DateTime? createdAt,
    PatientConditionCategory? conditionCategory,
  }) {
    return Patient(
      patientId: patientId ?? this.patientId,
      age: age ?? this.age,
      sex: sex ?? this.sex,
      mainComplaint: mainComplaint ?? this.mainComplaint,
      symptoms: symptoms ?? List.from(this.symptoms),
      injuryOrIllnessDetails: injuryOrIllnessDetails ?? this.injuryOrIllnessDetails,
      clinicalFindings: clinicalFindings ?? this.clinicalFindings,
      heartRate: heartRate ?? this.heartRate,
      systolicBP: systolicBP ?? this.systolicBP,
      diastolicBP: diastolicBP ?? this.diastolicBP,
      respiratoryRate: respiratoryRate ?? this.respiratoryRate,
      oxygenSaturation: oxygenSaturation ?? this.oxygenSaturation,
      temperature: temperature ?? this.temperature,
      requiredSpecialty: requiredSpecialty ?? this.requiredSpecialty,
      createdAt: createdAt ?? this.createdAt,
      conditionCategory: conditionCategory ?? this.conditionCategory,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'patientId': patientId,
      'age': age,
      'sex': sex.name,
      'mainComplaint': mainComplaint,
      'symptoms': symptoms,
      'injuryOrIllnessDetails': injuryOrIllnessDetails,
      'clinicalFindings': clinicalFindings,
      'heartRate': heartRate,
      'systolicBP': systolicBP,
      'diastolicBP': diastolicBP,
      'respiratoryRate': respiratoryRate,
      'oxygenSaturation': oxygenSaturation,
      'temperature': temperature,
      'requiredSpecialty': requiredSpecialty,
      'createdAt': createdAt.toIso8601String(),
      'conditionCategory': conditionCategory?.name,
    };
  }

  factory Patient.fromMap(Map<String, dynamic> map) {
    return Patient(
      patientId: map['patientId'] as String,
      age: (map['age'] as num).toInt(),
      sex: Sex.fromString(map['sex'] as String),
      mainComplaint: map['mainComplaint'] as String? ?? '',
      symptoms: (map['symptoms'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      injuryOrIllnessDetails: map['injuryOrIllnessDetails'] as String? ?? '',
      clinicalFindings: map['clinicalFindings'] as String? ?? '',
      heartRate: (map['heartRate'] as num?)?.toInt(),
      systolicBP: (map['systolicBP'] as num?)?.toInt(),
      diastolicBP: (map['diastolicBP'] as num?)?.toInt(),
      respiratoryRate: (map['respiratoryRate'] as num?)?.toInt(),
      oxygenSaturation: (map['oxygenSaturation'] as num?)?.toDouble(),
      temperature: (map['temperature'] as num?)?.toDouble(),
      requiredSpecialty: map['requiredSpecialty'] as String? ?? 'General Medicine',
      createdAt: DateTime.parse(map['createdAt'] as String),
      conditionCategory: map['conditionCategory'] != null
          ? PatientConditionCategory.fromString(map['conditionCategory'] as String)
          : null,
    );
  }

  @override
  String toString() =>
      'Patient($patientId, Age: $age, Sex: ${sex.displayName}, Complaint: "$mainComplaint")';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Patient &&
          runtimeType == other.runtimeType &&
          patientId == other.patientId;

  @override
  int get hashCode => patientId.hashCode;
}
