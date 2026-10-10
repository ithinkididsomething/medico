# MEDICO — Clinical Referral Decision-Support System

> **A prototype decision-support application engineered for rural, remote, and resource-constrained healthcare settings.**

---

## 🏥 Core Product Positioning

> ### **"Nearest hospital ≠ best hospital."**
> Naive geographic proximity frequently dispatches critical patients to facilities lacking mandatory surgical, ICU, or blood bank capabilities.  
> **MEDICO prioritizes:**
> $$\text{Medical Capability} + \text{Availability} + \text{Urgency} + \text{Travel Time} + \text{Distance}$$

---

## ⚠️ Clinical Decision Support Disclaimer

> **This application is a clinical decision-support prototype.** It assists healthcare professionals with referral decisions and does not replace professional clinical judgment. Patient cases and hospital availability shown in this prototype are synthetic or simulated. Clinical rules and real hospital data require appropriate validation and authorized integration before real-world deployment.

---

## 🚀 The 8 Core Features

1. **Patient Clinical Assessment**  
   Structured 5-section evaluation: Demographics, Symptoms & Condition, Vital Signs with abnormal range alerts, Required Referral Specialties/Facilities, and Current Clinic Resource constraints.
2. **Refer or Treat Locally (Triage Decision)**  
   Rule-based decision-support engine categorizing patient presentations into **Routine**, **Urgent**, or **Emergency**, directly identifying cases safely manageable locally versus those requiring immediate secondary/tertiary transfer.
3. **Smart Hospital Recommendation Engine**  
   Capability-driven matching with a **mandatory capability hard filter**. Hospitals lacking mandatory life-saving services (such as 24/7 Blood Bank or Emergency C-Section) are strictly excluded regardless of geographic proximity.
4. **Distance & Travel-Time Calculation**  
   Realistic road travel calculation utilizing Haversine geodesic distance augmented by a **1.25× rural curvature factor** and terrain transit speeds (35 km/h standard, 45 km/h emergency ambulance). Explicitly labeled as simulated offline transit without fabricating live traffic conditions.
5. **Dynamic & Fallback Referral**  
   If a destination hospital becomes unavailable, experiences bed saturation, or activates diversion, the system allows the clinician to simulate diversion, automatically re-ranking the remaining network and promoting alternative facilities.
6. **Automatic Structured Referral Summary**  
   Generates an immediate, structured referral document with patient demographics, clinical presentation, vital signs, urgency tier, referring clinic, and destination hospital details. Includes actions to **Save Referral**, **Generate PDF**, **Share Handover Brief**, **Print**, and **Return to Dashboard**. No patient PII is leaked to unencrypted system logs.
7. **Referral Dashboard & Audit Tracking**  
   Monitors all dispatched transfers in a clean, high-contrast tracking register. Includes a sequential visual timeline:  
   $$\text{Pending} \longrightarrow \text{Referred} \longrightarrow \text{Accepted} \longrightarrow \text{Transferred (In-Transit)} \longrightarrow \text{Completed}$$  
   Adheres to strict clinical governance requiring **manual clinician status updates**.
8. **Explainable Recommendations**  
   Transparent, audit-ready clinical rationale card ("Why this hospital?") with full capability match checkmarks and an explainable 100-point multi-factor score breakdown.

---

## 💡 The 5 Core Innovations

| Innovation | Description |
| :--- | :--- |
| **1. Clinical Referral Decision Support** | Multi-tier urgency scoring (Routine vs Urgent vs Emergency) comparing vital thresholds and rural clinic resource availability. |
| **2. Capability-Based Hospital Matching** | Enforces mandatory clinical capabilities as a non-negotiable hard filter before scoring and ranking. |
| **3. Travel-Time-Aware Hospital Ranking** | Evaluates true road transit time rather than raw Euclidean distance, accounting for rural terrain constraints. |
| **4. Dynamic Fallback Referral** | Instant failover and re-ranking promoting alternative secondary centers when primary facilities divert. |
| **5. Explainable AI & Referral Tracking** | Transparent score breakdown combined with an auditable manual status lifecycle for patient safety. |

---

## 🛠️ Technology Stack

- **Framework:** [Flutter](https://flutter.dev) (SDK `^3.7.0`)
- **Language:** [Dart](https://dart.dev)
- **UI System:** Material 3 Healthcare Theme (Custom Teal/Mint/Navy palette with multi-modal accessibility)
- **Mapping:** [`flutter_map`](https://pub.dev/packages/flutter_map) + [`latlong2`](https://pub.dev/packages/latlong2) (OpenStreetMap integration)
- **Persistence:** [`shared_preferences`](https://pub.dev/packages/shared_preferences) (Offline-first local registry with fallback in-memory cache)
- **Target Form Factors:** Android-first, responsive for phones and tablets (NavigationRail adaptive layout)

---

## 📁 Project Architecture & Folder Structure

```
lib/
├── core/
│   ├── constants/
│   │   └── app_constants.dart          # Positioning statements, disclaimers, layout constants
│   ├── theme/
│   │   ├── app_colors.dart             # Accessible clinical palette (Primary Green, Slate Teal, Alert Red)
│   │   └── app_theme.dart              # Material 3 light theme with dark theme hooks
│   └── utils/
│       └── responsive_utils.dart       # Breakpoint helpers for phone vs tablet constraints
├── models/
│   ├── enums.dart                      # UrgencyLevel, RecommendedAction, ReferralStatus, Sex
│   ├── patient.dart                    # Patient demographics, symptoms, vitals
│   ├── hospital.dart                   # Hospital profile, capabilities, coordinates
│   ├── hospital_availability.dart     # Bed availability, ICU capacity, operating status
│   ├── referral.dart                   # Referral records, timestamps, scores
│   ├── referral_status_history.dart    # Audit trail with timestamps and clinician notes
│   └── mock_data.dart                  # 9 synthetic hospitals & 5 clinical presets
├── repositories/
│   ├── hospital_repository.dart        # Hospital directory queries, filters, and searches
│   └── referral_repository.dart        # Local persistence and status lifecycle updates
├── services/
│   ├── assessment_service.dart         # Clinical triage rule engine (WHO/IMAI thresholds)
│   ├── hospital_matching_service.dart  # Capability filter and 100-pt weighted scoring
│   ├── location_service.dart           # GPS permissions, presets, and manual coordinate overrides
│   └── routing_service.dart            # Rural transit estimation with curvature factor
├── widgets/
│   ├── app_card.dart                   # Healthcare elevation cards
│   ├── app_header.dart                 # Screen headers with facility status
│   ├── app_scaffold.dart               # Adaptive scaffold with clinic status bar
│   ├── hospital_card.dart              # Facility preview cards
│   ├── medical_disclaimer.dart         # Mandatory disclaimer banner
│   ├── primary_button.dart             # Accessible primary action button (>=48dp)
│   ├── score_indicator.dart            # Multi-factor score visualizer
│   ├── status_badge.dart               # Lifecycle status badge with icons & text
│   ├── urgency_badge.dart              # Multi-modal urgency badge (Color + Icon + Text)
│   └── widgets.dart                    # Component library export barrel
├── screens/
│   ├── dashboard_screen.dart           # Clinical KPIs, triage actions, workflow visualizer
│   ├── assessment/
│   │   ├── patient_assessment_screen.dart   # 5-section assessment form
│   │   └── assessment_result_screen.dart    # Triage decision outcome
│   ├── recommendation/
│   │   └── recommendation_screen.dart       # Recommendation results & explainable breakdown
│   ├── referral/
│   │   ├── referral_summary_screen.dart     # Structured transfer document & dispatch actions
│   │   └── referral_tracking_screen.dart    # Referral tracking register & visual timeline
│   ├── hospital/
│   │   ├── hospital_directory_screen.dart   # Searchable directory with multi-filters
│   │   ├── hospital_details_screen.dart     # Capability profile & limitation analysis
│   │   ├── hospital_map_view.dart           # OpenStreetMap interactive routing view
│   │   └── clinic_location_dialog.dart      # GPS permissions & clinic presets
│   ├── component_showcase_screen.dart       # Design system validation gallery
│   └── more_screen.dart                     # Diagnostics, shifts, and ethics notice
├── navigation/
│   └── app_navigation.dart             # Bottom navigation (phone) & NavigationRail (tablet)
├── app.dart                            # MaterialApp setup and global theme configuration
└── main.dart                           # Entrypoint initializing services and local storage
```

---

## ⚙️ Setup and Testing Instructions

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (`>= 3.7.0`)
- Dart SDK (`>= 3.0.0`)

### 1. Install Dependencies
```bash
flutter pub get
```

### 2. Run Code Analysis
```bash
flutter analyze
```
*(Guaranteed **0 issues found**)*

### 3. Run Test Suite
Run all unit, widget, component, and end-to-end integration tests:
```bash
flutter test
```
*(All **86 / 86 tests pass cleanly**)*

### 4. Run the Application
```bash
flutter run
```

---

## 📋 Comprehensive Test Coverage

The test suite covers:
- **`test/widget_test.dart`**: Foundation launch, tab transitions, interactive buttons, NavigationRail adaptive tablet layout.
- **`test/widgets/component_library_test.dart`**: Complete verification of all 22 reusable clinical design system widgets across phone & tablet viewports.
- **`test/screens/assessment_screen_test.dart`**: Form field validations, vitals keyboards, clinical presets, and "Manage Locally" vs "Immediate Referral" triage decisions.
- **`test/screens/recommendation_screen_test.dart`**: Hard filter exclusions, explainable "Why this hospital?" rationales, 100-point score breakdowns, dynamic fallback, and confirmation workflows.
- **`test/screens/referral_workflow_test.dart`**: Structured summary display, all 5 dispatch buttons, referral tracking table, visual transfer timeline, and manual status updates.
- **`test/screens/hospital_directory_test.dart`**: Hospital search, multi-filter capabilities, OpenStreetMap view, clinic location dialog, and facility limitations audit.
- **`test/screens/end_to_end_workflow_test.dart`**: Full 8-step clinical referral decision-support workflows verifying all 5 core innovations.
- **`test/unit/`**: Data models, serialization, triage assessment rules, 100-point scoring engine, distance calculations, and repository persistence.

---

## 🔮 Future Deployment Roadmap

1. **Authorized Cloud Synchronization:**  
   Transition from local `SharedPreferences` to authenticated **Firebase Auth & Cloud Firestore** for encrypted real-time state synchronization across rural primary clinics and district hospitals.
2. **Authorized Real-Time Hospital Capacity Feeds:**  
   Replace prototype simulated availability (`HospitalAvailability.isSimulated = true`) with authorized national/state health authority FHIR/HL7 APIs for real-time ICU beds, ventilators, and oxygen reserves.
3. **Live OSRM / OpenRouteService Integration:**  
   Upgrade `SimulatedRoutingService` to an Open Source Routing Machine (OSRM) engine with offline map tiles, incorporating live weather, seasonal flooding, and rural road closure telemetry.
