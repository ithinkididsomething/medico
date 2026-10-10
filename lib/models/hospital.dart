import 'enums.dart';
import 'hospital_availability.dart';
import 'hospital_capability_profile.dart';

/// Strongly typed Hospital model representing a secondary or tertiary referral center.
class Hospital {
  final String hospitalId;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final List<String> specialties;
  final bool emergencyCare;
  final bool icuAvailable;
  final List<String> diagnosticFacilities;
  final List<String> treatmentCapabilities;
  final double currentCapacity; // 0.0 to 1.0 (e.g. 0.72 = 72% occupancy)
  final int bedAvailability;
  final String operatingStatus; // e.g. "Operational", "Diverting", "Limited Services"
  final DateTime availabilityLastUpdated;
  final HospitalAvailability? availability;
  final HospitalCapabilityProfile? capabilityProfile;
  final bool isSimulatedData;
  final String dataSource;
  final List<String> tags;
  final String? facilityType;
  final int revision;
  final bool isVerified;
  final String verificationTier;

  const Hospital({
    required this.hospitalId,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.specialties,
    required this.emergencyCare,
    required this.icuAvailable,
    required this.diagnosticFacilities,
    required this.treatmentCapabilities,
    required this.currentCapacity,
    required this.bedAvailability,
    required this.operatingStatus,
    required this.availabilityLastUpdated,
    this.tags = const [],
    this.facilityType,
    this.availability,
    this.capabilityProfile,
    this.isSimulatedData = true,
    this.dataSource = 'Regional Health Network Registry',
    this.revision = 1,
    this.isVerified = true,
    this.verificationTier = 'Tier 1',
  });

  /// Returns true if dynamic availability data is older than the freshness threshold (default 60 minutes).
  bool isAvailabilityOutdated([Duration maxAge = const Duration(minutes: 60)]) {
    final age = DateTime.now().difference(availabilityLastUpdated);
    return age > maxAge;
  }

  /// Inferred or explicit capability profile across all 8 condition categories.
  HospitalCapabilityProfile get effectiveCapabilityProfile {
    if (capabilityProfile != null) return capabilityProfile!;

    final hasEmergCare = emergencyCare;
    final hasIcu = icuAvailable;

    final hasCardiac = hasSpecialty('Cardiology') ||
        hasFacility('Cath Lab') ||
        hasFacility('PCI') ||
        hasFacility('Echocardiography');

    final hasNeuro = (hasSpecialty('Neurosurgery') || hasSpecialty('Neurology')) &&
        (hasFacility('CT') || hasFacility('MRI') || hasFacility('Craniotomy'));

    final hasTrauma = (hasSpecialty('Orthopedics & Trauma Surgery') ||
            hasSpecialty('Trauma') ||
            hasFacility('Polytrauma') ||
            hasFacility('Trauma') ||
            hasFacility('Fracture')) &&
        (hasEmergCare || hasIcu);

    final hasBlood = hasFacility('Blood Bank') || hasFacility('transfusion');

    final hasObstetric = hasSpecialty('Obstetrics') &&
        (hasFacility('C-Section') || hasFacility('Obstetric') || hasFacility('Cesarean'));

    final hasOt = (availability?.operatingTheatersAvailable ?? 0) > 0 ||
        hasFacility('Surgery') ||
        hasFacility('C-Section') ||
        hasFacility('Laparoscopic');

    final hasPediatric = hasSpecialty('Pediatrics') || hasSpecialty('Neonatology');

    final hasPicu = (hasSpecialty('Neonatology (NICU)') ||
            hasSpecialty('Pediatric Intensive Care') ||
            hasFacility('NICU') ||
            hasFacility('PICU') ||
            hasFacility('Incubator')) &&
        hasIcu;

    final hasOrtho = hasSpecialty('Orthopedics') || hasFacility('Fracture');

    return HospitalCapabilityProfile(
      lifeSavingEmergency: hasEmergCare ? CapabilityStatus.confirmed : CapabilityStatus.unavailable,
      cardiacCapability: hasCardiac ? CapabilityStatus.confirmed : CapabilityStatus.unavailable,
      strokeNeuroCapability: hasNeuro ? CapabilityStatus.confirmed : CapabilityStatus.unavailable,
      traumaOperativeCapability: hasTrauma ? CapabilityStatus.confirmed : CapabilityStatus.unavailable,
      bloodBankAvailability: hasBlood ? CapabilityStatus.confirmed : CapabilityStatus.unavailable,
      icuAvailability: hasIcu ? CapabilityStatus.confirmed : CapabilityStatus.unavailable,
      obstetricEmergencyCapability: hasObstetric ? CapabilityStatus.confirmed : CapabilityStatus.unavailable,
      operationTheatreAvailability: hasOt ? CapabilityStatus.confirmed : CapabilityStatus.unavailable,
      pediatricEmergencyCapability: hasPediatric ? CapabilityStatus.confirmed : CapabilityStatus.unavailable,
      pediatricIcuAvailability: hasPicu ? CapabilityStatus.confirmed : CapabilityStatus.unavailable,
      orthopaedicCapability: hasOrtho ? CapabilityStatus.confirmed : CapabilityStatus.unavailable,
    );
  }

  /// True if hospital possesses the specific medical specialty.
  bool hasSpecialty(String specialty) {
    return specialties.any(
      (s) => s.toLowerCase().contains(specialty.toLowerCase()),
    );
  }

  /// True if hospital provides the required diagnostic or treatment facility.
  bool hasFacility(String facility) {
    final lower = facility.toLowerCase();
    return diagnosticFacilities.any((f) => _matchesFacility(f.toLowerCase(), lower)) ||
        treatmentCapabilities.any((t) => _matchesFacility(t.toLowerCase(), lower));
  }

  static bool _matchesFacility(String hospitalFacility, String query) {
    if (hospitalFacility.contains(query) || query.contains(hospitalFacility)) {
      return true;
    }
    if (query.contains('blood') && (hospitalFacility.contains('blood') || hospitalFacility.contains('transfusion'))) {
      return true;
    }
    if ((query.contains('c-section') || query.contains('cesarean') || query.contains('obstetric')) &&
        (hospitalFacility.contains('c-section') ||
            hospitalFacility.contains('cesarean') ||
            hospitalFacility.contains('obstetric'))) {
      return true;
    }
    if ((query.contains('ventilator') || query.contains('ventilation')) &&
        (hospitalFacility.contains('ventilator') || hospitalFacility.contains('ventilation'))) {
      return true;
    }
    if (query.contains('x-ray') && hospitalFacility.contains('x-ray')) {
      return true;
    }
    if (query.contains('ct') && hospitalFacility.contains('ct')) {
      return true;
    }
    if (query.contains('fracture') && hospitalFacility.contains('fracture')) {
      return true;
    }
    return false;
  }

  /// True if hospital possesses the specific tag.
  bool hasTag(String tag) {
    final lower = tag.toLowerCase();
    return tags.any((t) => t.toLowerCase().contains(lower));
  }

  /// Primary display tag (e.g., 'Super Speciality', 'Government CHC', etc.)
  String get primaryTag {
    if (tags.isNotEmpty) return tags.first;
    if (facilityType != null && facilityType!.isNotEmpty) {
      return facilityType!.replaceAll('_', ' ').toUpperCase();
    }
    return emergencyCare ? '24/7 Emergency' : 'Healthcare Facility';
  }

  Hospital copyWith({
    String? hospitalId,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    List<String>? specialties,
    bool? emergencyCare,
    bool? icuAvailable,
    List<String>? diagnosticFacilities,
    List<String>? treatmentCapabilities,
    double? currentCapacity,
    int? bedAvailability,
    String? operatingStatus,
    DateTime? availabilityLastUpdated,
    HospitalAvailability? availability,
    HospitalCapabilityProfile? capabilityProfile,
    bool? isSimulatedData,
    String? dataSource,
    List<String>? tags,
    String? facilityType,
    int? revision,
    bool? isVerified,
    String? verificationTier,
  }) {
    return Hospital(
      hospitalId: hospitalId ?? this.hospitalId,
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      specialties: specialties ?? List.from(this.specialties),
      emergencyCare: emergencyCare ?? this.emergencyCare,
      icuAvailable: icuAvailable ?? this.icuAvailable,
      diagnosticFacilities:
          diagnosticFacilities ?? List.from(this.diagnosticFacilities),
      treatmentCapabilities:
          treatmentCapabilities ?? List.from(this.treatmentCapabilities),
      currentCapacity: currentCapacity ?? this.currentCapacity,
      bedAvailability: bedAvailability ?? this.bedAvailability,
      operatingStatus: operatingStatus ?? this.operatingStatus,
      availabilityLastUpdated:
          availabilityLastUpdated ?? this.availabilityLastUpdated,
      availability: availability ?? this.availability,
      capabilityProfile: capabilityProfile ?? this.capabilityProfile,
      isSimulatedData: isSimulatedData ?? this.isSimulatedData,
      dataSource: dataSource ?? this.dataSource,
      tags: tags ?? List.from(this.tags),
      facilityType: facilityType ?? this.facilityType,
      revision: revision ?? this.revision,
      isVerified: isVerified ?? this.isVerified,
      verificationTier: verificationTier ?? this.verificationTier,
    );
  }

  /// Returns updated Hospital using latest HospitalAvailability snapshot.
  Hospital withAvailability(HospitalAvailability update) {
    return copyWith(
      currentCapacity: update.currentCapacity,
      bedAvailability: update.totalBedsAvailable,
      operatingStatus: update.operatingStatus,
      emergencyCare: update.emergencyDepartmentOpen,
      icuAvailable: update.hasIcuBed,
      availabilityLastUpdated: update.availabilityLastUpdated,
      availability: update,
      isSimulatedData: update.isSimulated,
      dataSource: update.dataSource,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hospitalId': hospitalId,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'specialties': specialties,
      'emergencyCare': emergencyCare,
      'icuAvailable': icuAvailable,
      'diagnosticFacilities': diagnosticFacilities,
      'treatmentCapabilities': treatmentCapabilities,
      'currentCapacity': currentCapacity,
      'bedAvailability': bedAvailability,
      'operatingStatus': operatingStatus,
      'availabilityLastUpdated': availabilityLastUpdated.toIso8601String(),
      'availability': availability?.toMap(),
      'capabilityProfile': capabilityProfile?.toMap(),
      'isSimulatedData': isSimulatedData,
      'dataSource': dataSource,
      'tags': tags,
      'facilityType': facilityType,
      'revision': revision,
      'isVerified': isVerified,
      'verificationTier': verificationTier,
    };
  }

  factory Hospital.fromMap(Map<String, dynamic> map) {
    // Parse availability or operationalStatus if provided
    HospitalAvailability? avail;
    if (map['availability'] != null) {
      avail = HospitalAvailability.fromMap(
          Map<String, dynamic>.from(map['availability'] as Map));
    } else if (map['operationalStatus'] != null) {
      final op = Map<String, dynamic>.from(map['operationalStatus'] as Map);
      avail = HospitalAvailability(
        hospitalId: map['hospitalId'] as String,
        icuBedsAvailable: (op['icuBedsAvailable'] as num?)?.toInt() ?? 0,
        generalBedsAvailable: (op['generalBedsAvailable'] as num?)?.toInt() ?? (map['bedAvailability'] as num?)?.toInt() ?? 0,
        emergencyDepartmentOpen: op['emergencyDepartmentOpen'] as bool? ?? (map['emergencyCare'] as bool? ?? true),
        operatingTheatersAvailable: (op['operatingTheatersAvailable'] as num?)?.toInt() ?? 1,
        currentCapacity: (op['currentCapacity'] as num?)?.toDouble() ?? (map['currentCapacity'] as num?)?.toDouble() ?? 0.5,
        operatingStatus: op['operatingStatus'] as String? ?? (map['operatingStatus'] as String? ?? 'Operational'),
        availabilityLastUpdated: op['lastReportedAt'] != null
            ? DateTime.tryParse(op['lastReportedAt'] as String) ?? DateTime.now()
            : DateTime.now(),
        isSimulated: map['isSimulatedData'] as bool? ?? false,
        dataSource: map['dataSource'] as String? ?? 'Central Health API',
      );
    }

    DateTime lastUpdated = DateTime.now();
    if (map['availabilityLastUpdated'] != null) {
      lastUpdated = DateTime.tryParse(map['availabilityLastUpdated'] as String) ?? DateTime.now();
    } else if (map['updatedAt'] != null) {
      lastUpdated = DateTime.tryParse(map['updatedAt'] as String) ?? DateTime.now();
    }

    return Hospital(
      hospitalId: map['hospitalId'] as String,
      name: map['name'] as String,
      address: map['address'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      specialties: (map['specialties'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      emergencyCare: map['emergencyCare'] as bool? ?? true,
      icuAvailable: map['icuAvailable'] as bool? ?? false,
      diagnosticFacilities: (map['diagnosticFacilities'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      treatmentCapabilities: (map['treatmentCapabilities'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      currentCapacity: (map['currentCapacity'] as num).toDouble(),
      bedAvailability: (map['bedAvailability'] as num).toInt(),
      operatingStatus: map['operatingStatus'] as String? ?? 'Operational',
      availabilityLastUpdated: lastUpdated,
      availability: avail,
      capabilityProfile: map['capabilityProfile'] != null
          ? HospitalCapabilityProfile.fromMap(
              Map<String, dynamic>.from(map['capabilityProfile'] as Map))
          : null,
      isSimulatedData: map['isSimulatedData'] as bool? ?? true,
      dataSource: map['dataSource'] as String? ?? 'Regional Health Network Registry',
      tags: (map['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      facilityType: map['facilityType'] as String?,
      revision: (map['revision'] as num?)?.toInt() ?? 1,
      isVerified: map['isVerified'] as bool? ?? true,
      verificationTier: map['verificationTier'] as String? ?? 'Tier 1',
    );
  }

  /// Factory creating a Hospital from the synthetic Indore JSON schema.
  factory Hospital.fromIndoreJson(
    Map<String, dynamic> json, {
    double? defaultLat,
    double? defaultLng,
  }) {
    final hid = json['id'] as String;
    final name = json['name'] as String;

    String addressStr = 'Indore, Madhya Pradesh';
    final addrObj = json['address'];
    if (addrObj is Map) {
      addressStr = (addrObj['full_address'] ?? addrObj['street'] ?? 'Indore').toString();
    } else if (addrObj is String) {
      addressStr = addrObj;
    }

    final fac = json['facilities'] as Map<String, dynamic>? ?? {};
    bool boolFac(String key, bool fallback) {
      final item = fac[key];
      if (item is Map) {
        return item['value'] as bool? ?? fallback;
      } else if (item is bool) {
        return item;
      }
      return fallback;
    }

    final emergency = boolFac('emergency_services', true);
    final icu = boolFac('icu', false);
    final vent = boolFac('ventilator', false);
    final trauma = boolFac('trauma_care', false);
    final ct = boolFac('ct', false);
    final mri = boolFac('mri', false);
    final lab = boolFac('laboratory', false);
    final sono = boolFac('sonography', false);
    final xray = boolFac('x_ray', false);
    final bloodBank = boolFac('blood_bank', false);
    final ambulance = boolFac('ambulance', false);
    final bedCap = (fac['bed_capacity'] as num?)?.toInt() ?? 20;

    final diagnostics = <String>[];
    if (ct) diagnostics.add('16-Slice CT Scanner');
    if (mri) diagnostics.add('MRI Scanner');
    if (xray) diagnostics.add('Digital X-Ray');
    if (sono) diagnostics.add('Ultrasound / Sonography');
    if (lab) diagnostics.add('Pathology & Biochemistry Lab');
    if (bloodBank) diagnostics.add('24/7 Blood Bank');

    final treatments = <String>[];
    if (emergency) treatments.add('Emergency Resuscitation & Triage');
    if (icu) treatments.add('ICU Critical Care');
    if (vent) treatments.add('Mechanical Ventilation');
    if (trauma) treatments.add('Trauma Care & Stabilization');
    if (ambulance) treatments.add('Ambulance Dispatch');
    if (bloodBank) treatments.add('Blood Transfusion');

    final reportedTreatments = (json['treatments_reported'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    treatments.addAll(reportedTreatments);

    final reportedServices = (json['services_reported'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    treatments.addAll(reportedServices);

    final specialties = (json['specialties_reported'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final ftype = json['facility_type'] as String?;
    if (specialties.isEmpty) {
      if (ftype != null && ftype.contains('community_health_centre')) {
        specialties.addAll(['General Medicine', 'Obstetrics & Gynecology', 'Pediatrics']);
        treatments.add('Normal Vaginal Delivery');
      } else if (ftype != null && ftype.contains('primary_health_centre')) {
        specialties.addAll(['General Medicine', 'Preventive Care', 'Family Welfare']);
      } else {
        specialties.add('General Medicine');
      }
    }

    final tags = (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

    final availBeds = bedCap > 0 ? (bedCap * 0.18).round().clamp(1, 150) : 0;
    final capacity = bedCap > 0 ? ((bedCap - availBeds) / bedCap).clamp(0.50, 0.95) : 0.0;

    final lat = defaultLat ?? 22.7196;
    final lng = defaultLng ?? 75.8577;

    return Hospital(
      hospitalId: hid,
      name: name,
      address: addressStr,
      latitude: lat,
      longitude: lng,
      specialties: specialties,
      emergencyCare: emergency,
      icuAvailable: icu,
      diagnosticFacilities: diagnostics,
      treatmentCapabilities: treatments,
      currentCapacity: capacity,
      bedAvailability: availBeds,
      operatingStatus: 'Operational',
      availabilityLastUpdated: DateTime.now().subtract(const Duration(minutes: 10)),
      tags: tags,
      facilityType: ftype,
      isSimulatedData: true,
      dataSource: 'Indore Health Network Registry',
      availability: HospitalAvailability(
        hospitalId: hid,
        icuBedsAvailable: icu ? (availBeds > 3 ? (availBeds * 0.15).round().clamp(1, 12) : 1) : 0,
        generalBedsAvailable: availBeds,
        emergencyDepartmentOpen: emergency,
        operatingTheatersAvailable: (trauma || icu) ? 2 : 0,
        currentCapacity: capacity,
        operatingStatus: 'Operational',
        availabilityLastUpdated: DateTime.now().subtract(const Duration(minutes: 10)),
        isSimulated: true,
        dataSource: 'Indore Health Network Feed',
      ),
    );
  }

  @override
  String toString() => 'Hospital($hospitalId, "$name", Beds: $bedAvailability)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Hospital &&
          runtimeType == other.runtimeType &&
          hospitalId == other.hospitalId;

  @override
  int get hashCode => hospitalId.hashCode;
}
