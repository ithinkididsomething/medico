import 'enums.dart';

/// Explicit clinical capability profile representing capability status across
/// all 8 patient condition categories.
///
/// Distinguishes confirmed capability, confirmed unavailability, and unverified/unknown data.
/// Unknown data is NOT treated as available.
class HospitalCapabilityProfile {
  final CapabilityStatus lifeSavingEmergency;
  final CapabilityStatus cardiacCapability;
  final CapabilityStatus strokeNeuroCapability;
  final CapabilityStatus traumaOperativeCapability;
  final CapabilityStatus bloodBankAvailability;
  final CapabilityStatus icuAvailability;
  final CapabilityStatus obstetricEmergencyCapability;
  final CapabilityStatus operationTheatreAvailability;
  final CapabilityStatus pediatricEmergencyCapability;
  final CapabilityStatus pediatricIcuAvailability;
  final CapabilityStatus orthopaedicCapability;

  const HospitalCapabilityProfile({
    this.lifeSavingEmergency = CapabilityStatus.unknown,
    this.cardiacCapability = CapabilityStatus.unknown,
    this.strokeNeuroCapability = CapabilityStatus.unknown,
    this.traumaOperativeCapability = CapabilityStatus.unknown,
    this.bloodBankAvailability = CapabilityStatus.unknown,
    this.icuAvailability = CapabilityStatus.unknown,
    this.obstetricEmergencyCapability = CapabilityStatus.unknown,
    this.operationTheatreAvailability = CapabilityStatus.unknown,
    this.pediatricEmergencyCapability = CapabilityStatus.unknown,
    this.pediatricIcuAvailability = CapabilityStatus.unknown,
    this.orthopaedicCapability = CapabilityStatus.unknown,
  });

  const HospitalCapabilityProfile.empty() : this();

  CapabilityStatus getCapability(String capabilityKey) {
    switch (capabilityKey) {
      case 'lifeSavingEmergency':
        return lifeSavingEmergency;
      case 'cardiacCapability':
        return cardiacCapability;
      case 'strokeNeuroCapability':
        return strokeNeuroCapability;
      case 'traumaOperativeCapability':
        return traumaOperativeCapability;
      case 'bloodBankAvailability':
        return bloodBankAvailability;
      case 'icuAvailability':
        return icuAvailability;
      case 'obstetricEmergencyCapability':
        return obstetricEmergencyCapability;
      case 'operationTheatreAvailability':
        return operationTheatreAvailability;
      case 'pediatricEmergencyCapability':
        return pediatricEmergencyCapability;
      case 'pediatricIcuAvailability':
        return pediatricIcuAvailability;
      case 'orthopaedicCapability':
        return orthopaedicCapability;
      default:
        return CapabilityStatus.unknown;
    }
  }

  HospitalCapabilityProfile copyWith({
    CapabilityStatus? lifeSavingEmergency,
    CapabilityStatus? cardiacCapability,
    CapabilityStatus? strokeNeuroCapability,
    CapabilityStatus? traumaOperativeCapability,
    CapabilityStatus? bloodBankAvailability,
    CapabilityStatus? icuAvailability,
    CapabilityStatus? obstetricEmergencyCapability,
    CapabilityStatus? operationTheatreAvailability,
    CapabilityStatus? pediatricEmergencyCapability,
    CapabilityStatus? pediatricIcuAvailability,
    CapabilityStatus? orthopaedicCapability,
  }) {
    return HospitalCapabilityProfile(
      lifeSavingEmergency: lifeSavingEmergency ?? this.lifeSavingEmergency,
      cardiacCapability: cardiacCapability ?? this.cardiacCapability,
      strokeNeuroCapability: strokeNeuroCapability ?? this.strokeNeuroCapability,
      traumaOperativeCapability: traumaOperativeCapability ?? this.traumaOperativeCapability,
      bloodBankAvailability: bloodBankAvailability ?? this.bloodBankAvailability,
      icuAvailability: icuAvailability ?? this.icuAvailability,
      obstetricEmergencyCapability: obstetricEmergencyCapability ?? this.obstetricEmergencyCapability,
      operationTheatreAvailability: operationTheatreAvailability ?? this.operationTheatreAvailability,
      pediatricEmergencyCapability: pediatricEmergencyCapability ?? this.pediatricEmergencyCapability,
      pediatricIcuAvailability: pediatricIcuAvailability ?? this.pediatricIcuAvailability,
      orthopaedicCapability: orthopaedicCapability ?? this.orthopaedicCapability,
    );
  }

  Map<String, dynamic> toMap() => {
        'lifeSavingEmergency': lifeSavingEmergency.name,
        'cardiacCapability': cardiacCapability.name,
        'strokeNeuroCapability': strokeNeuroCapability.name,
        'traumaOperativeCapability': traumaOperativeCapability.name,
        'bloodBankAvailability': bloodBankAvailability.name,
        'icuAvailability': icuAvailability.name,
        'obstetricEmergencyCapability': obstetricEmergencyCapability.name,
        'operationTheatreAvailability': operationTheatreAvailability.name,
        'pediatricEmergencyCapability': pediatricEmergencyCapability.name,
        'pediatricIcuAvailability': pediatricIcuAvailability.name,
        'orthopaedicCapability': orthopaedicCapability.name,
      };

  factory HospitalCapabilityProfile.fromMap(Map<String, dynamic> map) {
    CapabilityStatus parse(String? key) {
      if (key == null) return CapabilityStatus.unknown;
      return CapabilityStatus.values.firstWhere(
        (c) => c.name == key,
        orElse: () => CapabilityStatus.unknown,
      );
    }

    return HospitalCapabilityProfile(
      lifeSavingEmergency: parse(map['lifeSavingEmergency'] as String?),
      cardiacCapability: parse(map['cardiacCapability'] as String?),
      strokeNeuroCapability: parse(map['strokeNeuroCapability'] as String?),
      traumaOperativeCapability: parse(map['traumaOperativeCapability'] as String?),
      bloodBankAvailability: parse(map['bloodBankAvailability'] as String?),
      icuAvailability: parse(map['icuAvailability'] as String?),
      obstetricEmergencyCapability: parse(map['obstetricEmergencyCapability'] as String?),
      operationTheatreAvailability: parse(map['operationTheatreAvailability'] as String?),
      pediatricEmergencyCapability: parse(map['pediatricEmergencyCapability'] as String?),
      pediatricIcuAvailability: parse(map['pediatricIcuAvailability'] as String?),
      orthopaedicCapability: parse(map['orthopaedicCapability'] as String?),
    );
  }
}
