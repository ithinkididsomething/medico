import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';
import '../models/symptom_analysis.dart';
import '../services/gemini_analysis_service.dart';
import '../services/offline_assessment_storage_service.dart';

/// Clinical decision-support widget providing Google Gemini symptom analysis
/// with automatic offline deterministic rule fallback, red-flag detection,
/// custom tag management, and clinician review/override capability.
class GeminiSymptomAnalysisCard extends StatefulWidget {
  final TextEditingController freeTextController;
  final TextEditingController? systolicBPController;
  final TextEditingController? diastolicBPController;
  final TextEditingController? heartRateController;
  final TextEditingController? respiratoryRateController;
  final TextEditingController? oxygenSaturationController;
  final TextEditingController? temperatureController;
  final TextEditingController? mainComplaintController;
  final TextEditingController? injuryDetailsController;
  final TextEditingController? clinicalFindingsController;
  final String patientId;
  final int? patientAge;
  final String? patientSex;
  final Set<String> selectedTags;
  final SymptomAnalysisResult? initialResult;
  final ValueChanged<SymptomAnalysisResult>? onResultUpdated;
  final void Function(
    List<String> extractedSymptoms,
    List<String> suggestedTags,
    ClinicalUrgencyTier urgency,
    ReferralLevel referral,
  )? onApplySymptoms;
  final void Function(SymptomAnalysisResult result)? onApplyAnalysis;
  final VoidCallback? onEmergencyTrigger;

  const GeminiSymptomAnalysisCard({
    super.key,
    required this.freeTextController,
    this.systolicBPController,
    this.diastolicBPController,
    this.heartRateController,
    this.respiratoryRateController,
    this.oxygenSaturationController,
    this.temperatureController,
    this.mainComplaintController,
    this.injuryDetailsController,
    this.clinicalFindingsController,
    this.patientId = 'PAT-UNSPECIFIED',
    this.patientAge,
    this.patientSex,
    required this.selectedTags,
    this.initialResult,
    this.onResultUpdated,
    this.onApplySymptoms,
    this.onApplyAnalysis,
    this.onEmergencyTrigger,
  });

  @override
  State<GeminiSymptomAnalysisCard> createState() => _GeminiSymptomAnalysisCardState();
}

class _GeminiSymptomAnalysisCardState extends State<GeminiSymptomAnalysisCard> {
  final GeminiAnalysisService _geminiService = GeminiAnalysisService.instance;
  final OfflineAssessmentStorageService _storage = OfflineAssessmentStorageService.instance;

  SymptomAnalysisResult? _currentResult;
  bool _isLoading = false;
  List<ClinicianCustomTag> _availableTags = [];

  @override
  void initState() {
    super.initState();
    _currentResult = widget.initialResult;
    _loadTags();
    _checkStatus();
    _geminiService.addListener(_onServiceChanged);
    _storage.addListener(_loadTags);
  }

  @override
  void didUpdateWidget(covariant GeminiSymptomAnalysisCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialResult != oldWidget.initialResult && widget.initialResult != null) {
      setState(() {
        _currentResult = widget.initialResult;
      });
    }
  }

  @override
  void dispose() {
    _geminiService.removeListener(_onServiceChanged);
    _storage.removeListener(_loadTags);
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  void _loadTags() {
    if (mounted) {
      setState(() {
        _availableTags = _storage.getAllTags();
      });
    }
  }

  Future<void> _checkStatus() async {
    await _geminiService.checkConnectivity();
  }

  int? _parseInt(TextEditingController? c) => int.tryParse(c?.text.trim() ?? '');
  double? _parseDouble(TextEditingController? c) => double.tryParse(c?.text.trim() ?? '');

  Future<void> _runAnalysis({bool forceOffline = false}) async {
    final text = widget.freeTextController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.statusAmber,
          content: Text('Please describe the patient presentation or clinical findings first.'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final res = await _geminiService.analyzePresentation(
        freeText: text,
        patientId: widget.patientId,
        systolicBP: _parseInt(widget.systolicBPController),
        diastolicBP: _parseInt(widget.diastolicBPController),
        heartRate: _parseInt(widget.heartRateController),
        oxygenSaturation: _parseDouble(widget.oxygenSaturationController),
        temperature: _parseDouble(widget.temperatureController),
        respiratoryRate: _parseInt(widget.respiratoryRateController),
        selectedTags: widget.selectedTags.toList(),
        age: widget.patientAge,
        sex: widget.patientSex,
        forceOffline: forceOffline,
      );

      if (mounted) {
        setState(() {
          _currentResult = res;
          _isLoading = false;
        });
        widget.onResultUpdated?.call(res);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.statusRed,
            content: Text('Error analyzing presentation: $e'),
          ),
        );
      }
    }
  }

  void _openAddCustomTagDialog() {
    final nameCtrl = TextEditingController();
    String category = 'general';

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: Row(
                children: const [
                  Icon(Icons.label_outline_rounded, color: AppColors.primaryGreen, size: 22),
                  SizedBox(width: 8),
                  Text('Add Custom Clinical Tag', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Create a clinician-defined tag. Saved offline and synced when network is available.',
                    style: TextStyle(fontSize: 12, color: AppColors.textNavyMuted),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tag Name *',
                      hintText: 'e.g. Nocturnal dyspnea, Epigastric burning',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(
                      labelText: 'Clinical Category',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'general', child: Text('General Clinical')),
                      DropdownMenuItem(value: 'cardiac', child: Text('Cardiovascular')),
                      DropdownMenuItem(value: 'respiratory', child: Text('Respiratory')),
                      DropdownMenuItem(value: 'maternal', child: Text('Maternal / Obstetric')),
                      DropdownMenuItem(value: 'pediatric', child: Text('Pediatric')),
                      DropdownMenuItem(value: 'trauma', child: Text('Trauma / Surgical')),
                      DropdownMenuItem(value: 'warning', child: Text('Warning / Danger Sign')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDlgState(() => category = val);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final tName = nameCtrl.text.trim();
                    if (tName.isEmpty) return;
                    final created = await _storage.createCustomTagOffline(tName, category: category);
                    if (mounted) {
                      setState(() {
                        widget.selectedTags.add(created.name);
                        _availableTags = _storage.getAllTags();
                      });
                    }
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  child: const Text('Save Tag'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openOverrideDialog() {
    if (_currentResult == null) return;
    ClinicalUrgencyTier newUrgency = _currentResult!.urgencyLevel;
    ReferralLevel newReferral = _currentResult!.referralLevel;
    final reasonCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: Row(
                children: const [
                  Icon(Icons.edit_note_rounded, color: AppColors.secondarySlateTeal, size: 22),
                  SizedBox(width: 8),
                  Text('Clinician Override', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 420,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLightMint,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Clinician clinical judgment supersedes AI and rule-based suggestions. Overrides are recorded for auditability.',
                            style: TextStyle(fontSize: 11, color: AppColors.primaryDarkGreen),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<ClinicalUrgencyTier>(
                          initialValue: newUrgency,
                          decoration: const InputDecoration(
                            labelText: 'New Urgency Tier *',
                            border: OutlineInputBorder(),
                          ),
                          items: ClinicalUrgencyTier.values.map((tier) {
                            return DropdownMenuItem(
                              value: tier,
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(color: tier.color, shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(tier.shortLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setDlgState(() => newUrgency = val);
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<ReferralLevel>(
                          initialValue: newReferral,
                          decoration: const InputDecoration(
                            labelText: 'New Referral Level *',
                            border: OutlineInputBorder(),
                          ),
                          items: ReferralLevel.values.map((ref) {
                            return DropdownMenuItem(
                              value: ref,
                              child: Text(ref.title, style: const TextStyle(fontSize: 12)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setDlgState(() => newReferral = val);
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: reasonCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Override Rationale (Required) *',
                            hintText: 'e.g. Clinical presentation is more severe than vital signs indicate',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a clinical rationale' : null,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: notesCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Additional Clinical Notes (Optional)',
                            hintText: 'e.g. Attending physician consulted; transport advised',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondarySlateTeal,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final overridden = _currentResult!.copyWithOverride(
                      newUrgency: newUrgency,
                      newReferral: newReferral,
                      reason: reasonCtrl.text.trim(),
                      notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                    );
                    await _storage.saveAssessmentLocally(overridden);
                    if (mounted) {
                      setState(() {
                        _currentResult = overridden;
                      });
                      widget.onResultUpdated?.call(overridden);
                    }
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  child: const Text('Apply Override'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _geminiService.status;
    final isOnline = status == GeminiConnectionStatus.onlineGeminiAvailable;
    final pendingCount = _storage.pendingQueueCount;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.3), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0D7A68), Color(0xFF14B8A6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Gemini AI Clinical Decision Support',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textNavyPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      'Assistive symptom analysis • Red-flag screening • Reliable offline fallback',
                      style: TextStyle(fontSize: 11, color: AppColors.textNavyMuted),
                    ),
                  ],
                ),
              ),
              _buildConnectivityPill(status),
            ],
          ),

          // Offline Queue Banner (if items are pending)
          if (pendingCount > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cloud_upload_outlined, size: 16, color: Color(0xFFB45309)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$pendingCount item(s) saved locally offline • queued for central sync',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                    ),
                  ),
                  if (_geminiService.isSyncingQueue)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFB45309)),
                    )
                  else
                    InkWell(
                      onTap: () => _geminiService.flushSyncQueue(),
                      child: const Text(
                        'Sync Now',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFB45309), decoration: TextDecoration.underline),
                      ),
                    ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Free text presentation field
          TextFormField(
            controller: widget.freeTextController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Clinical Free-Text Presentation (Patient / Attendant narrative) *',
              hintText: 'e.g. 32yo female with severe crushing chest pain since 2 hours, sweating, SpO2 88%, known hypertension...',
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.all(12),
              alignLabelWithHint: true,
              suffixIcon: widget.freeTextController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 16),
                      onPressed: () {
                        widget.freeTextController.clear();
                        setState(() {});
                      },
                    )
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),

          const SizedBox(height: 10),

          // Action row: Online Gemini & Offline Rules trigger
          Row(
            children: [
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : () => _runAnalysis(forceOffline: false),
                  icon: _isLoading
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.auto_awesome, size: 16),
                  label: Text(
                    isOnline ? 'Analyze with Gemini' : 'Analyze (Fallback)',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 40),
                    elevation: 1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : () => _runAnalysis(forceOffline: true),
                  icon: const Icon(Icons.offline_bolt_outlined, size: 15, color: AppColors.secondarySlateTeal),
                  label: const Text(
                    'Local Rules',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.secondarySlateTeal),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    side: const BorderSide(color: AppColors.secondarySlateTeal),
                  ),
                ),
              ),
            ],
          ),

          // Analysis Result Body
          if (_currentResult != null) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _buildResultContent(_currentResult!),
          ],
        ],
      ),
    );
  }

  Widget _buildConnectivityPill(GeminiConnectionStatus status) {
    Color bg;
    Color fg;
    IconData icon;

    switch (status) {
      case GeminiConnectionStatus.onlineGeminiAvailable:
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF166534);
        icon = Icons.check_circle_outline_rounded;
        break;
      case GeminiConnectionStatus.offlineLocalAssessment:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFF92400E);
        icon = Icons.cloud_off_rounded;
        break;
      case GeminiConnectionStatus.geminiUnavailableUsingRules:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF475569);
        icon = Icons.sync_problem_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
          ),
        ],
      ),
    );
  }

  void _applyToForm(SymptomAnalysisResult res) {
    // 1. Auto-fill vitals in controllers if empty
    if (widget.oxygenSaturationController != null &&
        widget.oxygenSaturationController!.text.trim().isEmpty &&
        res.extractedVitals.oxygenSaturation != null) {
      widget.oxygenSaturationController!.text = res.extractedVitals.oxygenSaturation!.toStringAsFixed(0);
    }
    if (widget.systolicBPController != null &&
        widget.systolicBPController!.text.trim().isEmpty &&
        res.extractedVitals.systolicBP != null) {
      widget.systolicBPController!.text = res.extractedVitals.systolicBP!.toString();
    }
    if (widget.diastolicBPController != null &&
        widget.diastolicBPController!.text.trim().isEmpty &&
        res.extractedVitals.diastolicBP != null) {
      widget.diastolicBPController!.text = res.extractedVitals.diastolicBP!.toString();
    }
    if (widget.heartRateController != null &&
        widget.heartRateController!.text.trim().isEmpty &&
        res.extractedVitals.heartRate != null) {
      widget.heartRateController!.text = res.extractedVitals.heartRate!.toString();
    }
    if (widget.respiratoryRateController != null &&
        widget.respiratoryRateController!.text.trim().isEmpty &&
        res.extractedVitals.respiratoryRate != null) {
      widget.respiratoryRateController!.text = res.extractedVitals.respiratoryRate!.toString();
    }
    if (widget.temperatureController != null &&
        widget.temperatureController!.text.trim().isEmpty &&
        res.extractedVitals.temperature != null) {
      widget.temperatureController!.text = res.extractedVitals.temperature!.toStringAsFixed(1);
    }
    if (widget.mainComplaintController != null &&
        widget.mainComplaintController!.text.trim().isEmpty &&
        res.extractedSymptoms.isNotEmpty) {
      widget.mainComplaintController!.text = res.extractedSymptoms.first;
    }
    if (widget.injuryDetailsController != null &&
        widget.injuryDetailsController!.text.trim().isEmpty) {
      final details = <String>[];
      if (res.duration != 'Unknown') details.add('Duration: ${res.duration}');
      if (res.onset != 'Unknown' && res.onset != 'unknown') details.add('Onset: ${res.onset}');
      if (res.relevantHistory.isNotEmpty) details.add('History: ${res.relevantHistory.join(", ")}');
      if (details.isNotEmpty) {
        widget.injuryDetailsController!.text = details.join(' | ');
      }
    }
    if (widget.clinicalFindingsController != null &&
        widget.clinicalFindingsController!.text.trim().isEmpty &&
        res.redFlags.isNotEmpty) {
      widget.clinicalFindingsController!.text = 'Warning signs: ${res.redFlags.join("; ")}';
    }

    // 2. Trigger parent callbacks
    widget.onApplyAnalysis?.call(res);
    widget.onApplySymptoms?.call(
      res.extractedSymptoms,
      res.suggestedTags,
      res.urgencyLevel,
      res.referralLevel,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppColors.primaryGreen,
        content: Text('Vitals, extracted symptoms & suggested tags applied to assessment form.'),
      ),
    );
  }

  Widget _buildTechnicalStatusBanner(SymptomAnalysisResult res) {
    String message;
    IconData icon;
    Color color;
    Color bg;

    switch (res.analysisStatus) {
      case 'authentication_error':
        message = 'Technical Notice: Gemini API authentication failure (invalid or unconfigured API key). Safe deterministic clinical triage rules applied.';
        icon = Icons.key_off_rounded;
        color = const Color(0xFFB45309);
        bg = const Color(0xFFFEF3C7);
        break;
      case 'rate_limited':
        message = 'Technical Notice: Gemini API rate limit reached. Fallback to deterministic clinical triage rules.';
        icon = Icons.speed_rounded;
        color = const Color(0xFFB45309);
        bg = const Color(0xFFFEF3C7);
        break;
      case 'timeout':
        message = 'Network Timeout: Gemini API did not respond within timeout limit. Safe local triage rules active.';
        icon = Icons.timer_off_outlined;
        color = const Color(0xFF475569);
        bg = const Color(0xFFF1F5F9);
        break;
      case 'service_unavailable':
        message = 'Service Notice: Remote Gemini service unreachable or offline. Local deterministic triage rules active.';
        icon = Icons.cloud_off_rounded;
        color = const Color(0xFF475569);
        bg = const Color(0xFFF1F5F9);
        break;
      case 'invalid_response':
        message = 'Technical Notice: Malformed response received from AI service. Deterministic local triage rules enforced.';
        icon = Icons.code_off_rounded;
        color = const Color(0xFFB45309);
        bg = const Color(0xFFFEF3C7);
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtractedVitalsCard(SymptomAnalysisResult res) {
    final v = res.extractedVitals;
    if (v.isEmpty) return const SizedBox.shrink();

    final chips = <Widget>[];
    if (v.oxygenSaturation != null) {
      chips.add(_buildVitalBadge(
        'SpO₂',
        '${v.oxygenSaturation!.toStringAsFixed(0)}%',
        v.oxygenSaturation! < 90 ? AppColors.statusRed : AppColors.primaryGreen,
      ));
    }
    if (v.systolicBP != null || v.diastolicBP != null) {
      final s = v.systolicBP != null ? '${v.systolicBP}' : '-';
      final d = v.diastolicBP != null ? '${v.diastolicBP}' : '-';
      final isHigh = (v.systolicBP ?? 0) > 140 || (v.diastolicBP ?? 0) > 90;
      final isLow = (v.systolicBP ?? 100) < 90;
      chips.add(_buildVitalBadge(
        'BP',
        '$s/$d mmHg',
        (isHigh || isLow) ? AppColors.statusAmber : AppColors.secondarySlateTeal,
      ));
    }
    if (v.heartRate != null) {
      chips.add(_buildVitalBadge(
        'Pulse',
        '${v.heartRate} bpm',
        (v.heartRate! > 100 || v.heartRate! < 50) ? AppColors.statusAmber : AppColors.secondarySlateTeal,
      ));
    }
    if (v.temperature != null) {
      chips.add(_buildVitalBadge(
        'Temp',
        '${v.temperature!.toStringAsFixed(1)}°C',
        v.temperature! >= 38.0 ? AppColors.statusAmber : AppColors.secondarySlateTeal,
      ));
    }
    if (v.respiratoryRate != null) {
      chips.add(_buildVitalBadge(
        'RR',
        '${v.respiratoryRate}/min',
        (v.respiratoryRate! > 24 || v.respiratoryRate! < 10) ? AppColors.statusAmber : AppColors.secondarySlateTeal,
      ));
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.monitor_heart_outlined, size: 14, color: AppColors.primaryGreen),
              SizedBox(width: 4),
              Text(
                'Extracted Clinical Vitals:',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primaryDarkGreen),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: chips,
          ),
        ],
      ),
    );
  }

  Widget _buildVitalBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
          Text(value, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textNavyPrimary)),
        ],
      ),
    );
  }

  Widget _buildResultContent(SymptomAnalysisResult res) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Provenance & Source Badge Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSourceBadge(res.source, res.modelVersion, res.rulesetVersion),
            Text(
              '${res.createdAt.hour.toString().padLeft(2, '0')}:${res.createdAt.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 10, color: AppColors.textNavyMuted),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Technical status banner (if API key missing or network failure occurred)
        _buildTechnicalStatusBanner(res),

        // 🚨 High-Contrast Red Flag Warning Banner
        if (res.redFlags.isNotEmpty || res.urgencyLevel == ClinicalUrgencyTier.level1ImmediateEmergency) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFF87171), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.warning_rounded, color: Color(0xFFDC2626), size: 18),
                    SizedBox(width: 6),
                    Text(
                      '🚨 MANDATORY CLINICAL RED FLAGS DETECTED',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF991B1B)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ...res.redFlags.map(
                  (rf) => Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '• $rf',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF7F1D1D)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: widget.onEmergencyTrigger,
                      icon: const Icon(Icons.flash_on, size: 14),
                      label: const Text('⚡ EMERGENCY REFERRAL (108 AMBULANCE)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Safety rule: Emergency urgency cannot be downgraded.',
                        style: TextStyle(fontSize: 9, fontStyle: FontStyle.italic, color: Color(0xFF991B1B)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        // Dual Badges: Urgency Tier & Referral Level
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: res.urgencyLevel.backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: res.urgencyLevel.color.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Urgency Tier', style: TextStyle(fontSize: 10, color: AppColors.textNavyMuted, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      res.isUndetermined
                          ? 'Urgency undetermined — clinician assessment required'
                          : res.urgencyLevel.title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: res.urgencyLevel.color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMutedLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.secondarySlateTeal.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Referral Level', style: TextStyle(fontSize: 10, color: AppColors.textNavyMuted, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      res.referralLevel.title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.secondarySlateTeal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Extracted Vitals Section (SpO2, BP, Pulse, Temp, RR)
        _buildExtractedVitalsCard(res),

        // Extracted Symptoms & Auto-populate Form Action
        if (res.extractedSymptoms.isNotEmpty || res.extractedVitals.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Extracted Clinical Symptoms (${res.extractedSymptoms.length}):',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textNavyPrimary),
              ),
              if (widget.onApplySymptoms != null || widget.onApplyAnalysis != null)
                InkWell(
                  onTap: () => _applyToForm(res),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(
                      'Apply to Assessment Form ➜',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primaryGreen),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: res.extractedSymptoms.map((s) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryLightMint,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.3)),
                ),
                child: Text(s, style: const TextStyle(fontSize: 11, color: AppColors.primaryDarkGreen, fontWeight: FontWeight.w600)),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
        ],

        // Missing Information & Suggested Follow-up Questions
        if (res.missingInformation.isNotEmpty || res.followUpQuestions.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (res.missingInformation.isNotEmpty) ...[
                  Row(
                    children: const [
                      Icon(Icons.help_outline_rounded, size: 14, color: AppColors.textNavyMuted),
                      SizedBox(width: 4),
                      Text('Missing Clinical Context:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textNavySecondary)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  ...res.missingInformation.map(
                    (m) => Text('  • $m', style: const TextStyle(fontSize: 10, color: AppColors.textNavySecondary)),
                  ),
                  const SizedBox(height: 4),
                ],
                if (res.followUpQuestions.isNotEmpty) ...[
                  Row(
                    children: const [
                      Icon(Icons.question_answer_outlined, size: 14, color: AppColors.primaryGreen),
                      SizedBox(width: 4),
                      Text('Suggested Follow-Up Questions:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primaryDarkGreen)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  ...res.followUpQuestions.map(
                    (q) => Text('  • $q', style: const TextStyle(fontSize: 10, color: AppColors.textNavyPrimary, fontStyle: FontStyle.italic)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        // Transparent Clinical Reasoning
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.psychology_alt_outlined, size: 14, color: AppColors.secondarySlateTeal),
                  SizedBox(width: 4),
                  Text('Transparent Clinical Rationale:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.secondarySlateTeal)),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                res.reasoning,
                style: const TextStyle(fontSize: 11, color: AppColors.textNavyPrimary),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Tags Section (Builtin + AI + Custom)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Clinical Category & Custom Tags:',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textNavyPrimary),
            ),
            InkWell(
              onTap: _openAddCustomTagDialog,
              child: Row(
                children: const [
                  Icon(Icons.add_circle_outline_rounded, size: 14, color: AppColors.primaryGreen),
                  SizedBox(width: 3),
                  Text('+ Add Custom Tag', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _buildTagsSelector(res),

        const SizedBox(height: 10),

        // Clinician Review & Override Control Bar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (res.isClinicianReviewed)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Clinician Status: ${res.clinicianReviewStatus.toUpperCase()}',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6B21A8)),
                ),
              )
            else
              const Text(
                'Status: Pending Clinician Review',
                style: TextStyle(fontSize: 10, color: AppColors.textNavyMuted, fontStyle: FontStyle.italic),
              ),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _openOverrideDialog,
                  icon: const Icon(Icons.edit_note, size: 15),
                  label: const Text('Override', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.secondarySlateTeal,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSourceBadge(AssessmentSource source, String model, String ruleset) {
    switch (source) {
      case AssessmentSource.gemini:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFE0F2FE),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF38BDF8)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome, size: 11, color: Color(0xFF0284C7)),
              const SizedBox(width: 4),
              Text(
                'AI suggestion — clinician review required ($model)',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0369A1)),
              ),
            ],
          ),
        );
      case AssessmentSource.offlineRules:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.shield_outlined, size: 11, color: Color(0xFF475569)),
              const SizedBox(width: 4),
              Text(
                'Offline rule-based assessment — not analyzed by Gemini',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
              ),
            ],
          ),
        );
      case AssessmentSource.clinicianOverride:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFF3E8FF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFC084FC)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.verified_user_outlined, size: 11, color: Color(0xFF7E22CE)),
              SizedBox(width: 4),
              Text(
                'Clinician Overridden',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6B21A8)),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildTagsSelector(SymptomAnalysisResult res) {
    // Combine suggested tags with available tags
    final allTagNames = <String>{};
    for (final t in res.suggestedTags) {
      allTagNames.add(t);
    }
    for (final t in _availableTags) {
      allTagNames.add(t.name);
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: allTagNames.take(15).map((tagName) {
        final isSelected = widget.selectedTags.contains(tagName);
        final isSuggested = res.suggestedTags.contains(tagName);
        final isCustom = _availableTags.any((t) => t.name == tagName && !t.isBuiltin);

        return FilterChip(
          selected: isSelected,
          showCheckmark: true,
          avatar: isSuggested
              ? const Icon(Icons.auto_awesome, size: 11, color: AppColors.primaryGreen)
              : isCustom
                  ? const Icon(Icons.person_outline, size: 11, color: AppColors.secondarySlateTeal)
                  : null,
          label: Text(tagName),
          labelStyle: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textNavyPrimary,
          ),
          selectedColor: isCustom ? AppColors.secondarySlateTeal : AppColors.primaryGreen,
          backgroundColor: AppColors.surfaceMutedLight,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                widget.selectedTags.add(tagName);
              } else {
                widget.selectedTags.remove(tagName);
              }
            });
          },
        );
      }).toList(),
    );
  }
}
