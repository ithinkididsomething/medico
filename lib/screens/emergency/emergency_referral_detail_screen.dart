import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../models/emergency_referral.dart';
import '../../repositories/emergency_referral_repository.dart';
import '../../services/emergency_referral_service.dart';

/// Detailed clinical overview and real-time command screen for an active emergency referral.
/// Supports post-dispatch versioned amendments, multi-channel transmission,
/// ambulance logistics updates, receiving-team response tracking, and clinical handover.
class EmergencyReferralDetailScreen extends StatefulWidget {
  final String referralId;

  const EmergencyReferralDetailScreen({
    super.key,
    required this.referralId,
  });

  @override
  State<EmergencyReferralDetailScreen> createState() => _EmergencyReferralDetailScreenState();
}

class _EmergencyReferralDetailScreenState extends State<EmergencyReferralDetailScreen> {
  EmergencyReferral? _referral;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReferral();
  }

  Future<void> _loadReferral({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    try {
      final ref = await EmergencyReferralRepository.instance.getReferralById(widget.referralId);
      if (mounted) {
        setState(() {
          _referral = ref;
          _isLoading = false;
          _errorMessage = ref == null ? 'Emergency Referral not found.' : null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load referral: $e';
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // AMBULANCE STATUS UPDATE
  // ---------------------------------------------------------------------------
  Future<void> _updateAmbulanceStatus(AmbulanceDispatchStatus newStatus) async {
    if (_referral == null) return;
    try {
      final updated = await EmergencyReferralRepository.instance.updateAmbulanceDispatch(
        referralId: _referral!.referralId,
        status: newStatus,
        vehicleNumber: _referral!.ambulanceVehicleNumber,
        etaMinutes: newStatus == AmbulanceDispatchStatus.arrived ? 0 : _referral!.ambulanceEtaMinutes,
        notes: 'Status transitioned to ${newStatus.label}',
      );
      setState(() => _referral = updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ambulance status updated to: ${newStatus.label}'),
            backgroundColor: AppColors.statusGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating ambulance: $e'), backgroundColor: AppColors.statusRed),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // POST-DISPATCH AMENDMENT DIALOG
  // ---------------------------------------------------------------------------
  void _showAmendmentDialog() {
    if (_referral == null) return;

    final pulseCtrl = TextEditingController(text: _referral!.vitalsPulse?.toString() ?? '');
    final sysCtrl = TextEditingController(text: _referral!.vitalsBpSystolic?.toString() ?? '');
    final diaCtrl = TextEditingController(text: _referral!.vitalsBpDiastolic?.toString() ?? '');
    final spo2Ctrl = TextEditingController(text: _referral!.vitalsSpo2?.toString() ?? '');
    final respCtrl = TextEditingController(text: _referral!.vitalsRespRate?.toString() ?? '');
    final treatmentCtrl = TextEditingController(text: _referral!.immediateTreatmentGiven ?? '');
    final reasonCtrl = TextEditingController(text: 'En-route vitals update and ongoing stabilization');
    String consciousness = _referral!.consciousnessLevel;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.edit_note, color: Color(0xFF0D7A68), size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Add Clinical Update (Version ${_referral!.currentVersion + 1})',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const Text(
                                'Appends amendment while preserving immutable Version 1',
                                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const Divider(height: 16),

                    const Text(
                      'Updated Vital Signs En-Route:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: pulseCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Pulse (bpm)', border: OutlineInputBorder(), isDense: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: sysCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'BP Sys', border: OutlineInputBorder(), isDense: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: diaCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'BP Dia', border: OutlineInputBorder(), isDense: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: spo2Ctrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'SpO2 (%)', border: OutlineInputBorder(), isDense: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: respCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Resp Rate', border: OutlineInputBorder(), isDense: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    const Text(
                      'Consciousness (AVPU):',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      children: ['Alert', 'Voice', 'Pain', 'Unresponsive'].map((lvl) {
                        final isSel = consciousness == lvl;
                        return ChoiceChip(
                          label: Text(lvl),
                          selected: isSel,
                          selectedColor: const Color(0xFF0D7A68),
                          labelStyle: TextStyle(color: isSel ? Colors.white : Colors.black87),
                          onSelected: (v) {
                            if (v) setModalState(() => consciousness = lvl);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: treatmentCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Pre-Hospital Treatment Given / Clinical Evolution',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: reasonCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Reason for Amendment (Audit Trail Requirement) *',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.save),
                        label: Text('SAVE CLINICAL VERSION ${_referral!.currentVersion + 1}'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D7A68),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () async {
                          final reason = reasonCtrl.text.trim();
                          if (reason.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please provide an amendment reason')),
                            );
                            return;
                          }

                          Navigator.pop(ctx);
                          final updateData = <String, dynamic>{
                            'vitalsPulse': int.tryParse(pulseCtrl.text.trim()),
                            'vitalsBpSystolic': int.tryParse(sysCtrl.text.trim()),
                            'vitalsBpDiastolic': int.tryParse(diaCtrl.text.trim()),
                            'vitalsSpo2': int.tryParse(spo2Ctrl.text.trim()),
                            'vitalsRespRate': int.tryParse(respCtrl.text.trim()),
                            'consciousnessLevel': consciousness,
                            'immediateTreatmentGiven': treatmentCtrl.text.trim(),
                          };

                          try {
                            final updated = await EmergencyReferralRepository.instance.addClinicalAmendment(
                              referralId: _referral!.referralId,
                              updateData: updateData,
                              amendmentReason: reason,
                            );
                            setState(() => _referral = updated);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Saved Version ${updated.currentVersion} successfully!'),
                                  backgroundColor: AppColors.statusGreen,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error saving amendment: $e'), backgroundColor: AppColors.statusRed),
                              );
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // SEND REFERRAL NOTIFICATION DIALOG
  // ---------------------------------------------------------------------------
  void _showSendNotificationDialog() {
    if (_referral == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.send_rounded, color: Color(0xFFDC2626)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Dispatch Clinical Referral Notification',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Text(
                'Transmit urgent clinical summary directly to receiving facility or doctor.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),

              // Email
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE0F2FE),
                  child: Icon(Icons.email, color: Color(0xFF0284C7)),
                ),
                title: const Text('Send Urgent Referral Email', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Official subject: URGENT EMERGENCY REFERRAL — [ID] — [Patient]'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _triggerSendNotification(channel: 'email', recipient: 'er-triage@indorehealth.gov.in');
                },
              ),
              const Divider(height: 8),

              // Direct Clinical Message
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFDCFCE7),
                  child: Icon(Icons.chat, color: Color(0xFF16A34A)),
                ),
                title: const Text('Direct Clinical In-App Message', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Real-time delivery to duty triage officer workstation'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _triggerSendNotification(channel: 'clinical_message', recipient: 'Duty Emergency Physician');
                },
              ),
              const Divider(height: 8),

              // SMS / WhatsApp Alert
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFEF3C7),
                  child: Icon(Icons.sms, color: Color(0xFFD97706)),
                ),
                title: const Text('Cellular SMS / WhatsApp Flash Alert', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('High-priority alert to facility on-call emergency phone'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _triggerSendNotification(channel: 'sms_alert', recipient: '+91 731 254 9999');
                },
              ),
              const SizedBox(height: 8),

              // Copy Clinical Summary
              Center(
                child: TextButton.icon(
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy Formatted Clinical Summary to Clipboard'),
                  onPressed: () {
                    final text = EmergencyReferralService.formatEmailBody(_referral!);
                    Clipboard.setData(ClipboardData(text: text));
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Clinical summary copied to clipboard!')),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _triggerSendNotification({required String channel, required String recipient}) async {
    try {
      final updated = await EmergencyReferralRepository.instance.sendReferralNotification(
        referralId: _referral!.referralId,
        channel: channel,
        recipientAddress: recipient,
        recipientName: 'Duty Emergency Reception',
        customNotes: 'Emergency patient en route with 108 EMTS',
      );
      setState(() => _referral = updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.done_all, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Dispatched via $channel to $recipient!')),
              ],
            ),
            backgroundColor: AppColors.statusGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error dispatching notification: $e'), backgroundColor: AppColors.statusRed),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // RECEIVING TEAM RESPONSE / ACKNOWLEDGEMENT DIALOG
  // ---------------------------------------------------------------------------
  void _showAcknowledgementDialog() {
    if (_referral == null) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.thumb_up_alt, color: Color(0xFF0D7A68)),
              SizedBox(width: 8),
              Text('Receiving Team Response', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: const Text(
            'Record the receiving emergency department’s response. '
            'Formal acceptance prepares the trauma/triage team and reserves the resuscitation bay.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D7A68), foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  final updated = await EmergencyReferralRepository.instance.recordAcknowledgement(
                    referralId: _referral!.referralId,
                    responseStatus: ReceivingResponseStatus.accepted,
                    responderName: 'Dr. Neha Agrawal',
                    responderRole: 'Senior Consultant, Emergency Medicine',
                    notes: 'Trauma bay prepared. Cath lab on standby.',
                  );
                  setState(() => _referral = updated);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Referral accepted by receiving hospital!'),
                        backgroundColor: AppColors.statusGreen,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error recording response: $e'), backgroundColor: AppColors.statusRed),
                    );
                  }
                }
              },
              child: const Text('ACCEPT PATIENT'),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // RECORD ARRIVAL & HANDOVER DIALOG
  // ---------------------------------------------------------------------------
  void _showHandoverDialog() {
    if (_referral == null) return;

    final docCtrl = TextEditingController(text: 'Dr. Vivek Sharma');
    final roleCtrl = TextEditingController(text: 'Chief Emergency Officer');
    final bedCtrl = TextEditingController(text: 'ICU Bed 04');
    final notesCtrl = TextEditingController(text: 'Vitals stable on arrival. Patient handed over to ICU team.');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Color(0xFF16A34A)),
              SizedBox(width: 8),
              Text('Clinical Handover Complete', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: docCtrl,
                  decoration: const InputDecoration(labelText: 'Receiving Physician Name *', isDense: true, border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: roleCtrl,
                  decoration: const InputDecoration(labelText: 'Receiving Physician Role', isDense: true, border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: bedCtrl,
                  decoration: const InputDecoration(labelText: 'Assigned Bay / Bed', isDense: true, border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Handover Notes', isDense: true, border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  final updated = await EmergencyReferralRepository.instance.recordHandover(
                    referralId: _referral!.referralId,
                    actorName: '${docCtrl.text.trim()} (${roleCtrl.text.trim()})',
                    notes: 'Assigned ${bedCtrl.text.trim()}. ${notesCtrl.text.trim()}',
                  );
                  setState(() => _referral = updated);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Handover completed and referral closed!'),
                        backgroundColor: AppColors.statusGreen,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error recording handover: $e'), backgroundColor: AppColors.statusRed),
                    );
                  }
                }
              },
              child: const Text('RECORD HANDOVER'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null || _referral == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Emergency Referral')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.statusRed),
              const SizedBox(height: 12),
              Text(_errorMessage ?? 'Referral not found'),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: () => _loadReferral(forceRefresh: true), child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final ref = _referral!;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF991B1B),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  ref.referralId,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('Version ${ref.currentVersion}', style: const TextStyle(fontSize: 10)),
                ),
              ],
            ),
            Text(
              ref.patientDisplayLabel,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Call Emergency 108',
            icon: const Icon(Icons.phone_in_talk),
            onPressed: () => EmergencyReferralService.launchAmbulanceCall(),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadReferral(forceRefresh: true),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Triple Status Indicator (Workflow, Delivery, Response)
          _buildTripleStatusBar(ref),
          const SizedBox(height: 14),

          // 2. Ambulance Logistics & Transit Controls
          _buildAmbulanceLogisticsCard(ref),
          const SizedBox(height: 14),

          // 3. Clinical Summary Card
          _buildClinicalSummaryCard(ref),
          const SizedBox(height: 14),

          // 4. Receiving Hospital & Destination Card
          _buildDestinationCard(ref),
          const SizedBox(height: 14),

          // 5. Version History & Audit Trail Viewer
          _buildVersionHistoryCard(ref),
          const SizedBox(height: 20),

          // 6. Action Control Row
          _buildActionControls(ref),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildTripleStatusBar(EmergencyReferral ref) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'LIVE STATUS PIPELINE',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // Workflow Status
                Expanded(
                  child: _buildStatusPill(
                    label: 'Workflow',
                    value: ref.workflowStatus.label,
                    color: _getWorkflowColor(ref.workflowStatus),
                    icon: Icons.alt_route,
                  ),
                ),
                const SizedBox(width: 6),
                // Delivery Status
                Expanded(
                  child: _buildStatusPill(
                    label: 'Delivery',
                    value: ref.deliveryStatus.label,
                    color: _getDeliveryColor(ref.deliveryStatus),
                    icon: Icons.send,
                  ),
                ),
                const SizedBox(width: 6),
                // Response Status
                Expanded(
                  child: _buildStatusPill(
                    label: 'Response',
                    value: ref.responseStatus.label,
                    color: _getResponseColor(ref.responseStatus),
                    icon: Icons.verified_user,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  Color _getWorkflowColor(EmergencyWorkflowStatus s) {
    switch (s) {
      case EmergencyWorkflowStatus.emergencyCreated:
        return const Color(0xFFD97706);
      case EmergencyWorkflowStatus.initialSent:
        return const Color(0xFF0284C7);
      case EmergencyWorkflowStatus.inTransit:
        return const Color(0xFF7C3AED);
      case EmergencyWorkflowStatus.patientArrived:
      case EmergencyWorkflowStatus.handoverCompleted:
        return const Color(0xFF16A34A);
      default:
        return const Color(0xFF64748B);
    }
  }

  Color _getDeliveryColor(EmergencyDeliveryStatus s) {
    switch (s) {
      case EmergencyDeliveryStatus.delivered:
        return const Color(0xFF16A34A);
      case EmergencyDeliveryStatus.sentToProvider:
      case EmergencyDeliveryStatus.sending:
        return const Color(0xFF0284C7);
      case EmergencyDeliveryStatus.queued:
        return const Color(0xFFD97706);
      case EmergencyDeliveryStatus.failed:
      case EmergencyDeliveryStatus.retryRequired:
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF64748B);
    }
  }

  Color _getResponseColor(ReceivingResponseStatus s) {
    switch (s) {
      case ReceivingResponseStatus.accepted:
        return const Color(0xFF16A34A);
      case ReceivingResponseStatus.acknowledged:
        return const Color(0xFF0284C7);
      case ReceivingResponseStatus.declined:
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFFD97706);
    }
  }

  Widget _buildAmbulanceLogisticsCard(EmergencyReferral ref) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.airport_shuttle, color: Color(0xFFD97706), size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Ambulance Transport Logistics',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                Text(
                  ref.ambulanceServiceType,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0D7A68)),
                ),
              ],
            ),
            const Divider(height: 16),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('STATUS', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                      Text(
                        ref.ambulanceStatus.label,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                ),
                if (ref.ambulanceVehicleNumber != null)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('VEHICLE REG', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                        Text(
                          ref.ambulanceVehicleNumber!,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                  ),
                if (ref.ambulanceEtaMinutes != null)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ETA', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                        Text(
                          '~${ref.ambulanceEtaMinutes} mins',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0284C7)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Rapid Status Buttons
            const Text('Transition Transit Stage:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (ref.ambulanceStatus != AmbulanceDispatchStatus.enRouteScene)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.navigation, size: 14),
                    label: const Text('En Route to Scene', style: TextStyle(fontSize: 11)),
                    onPressed: () => _updateAmbulanceStatus(AmbulanceDispatchStatus.enRouteScene),
                  ),
                if (ref.ambulanceStatus != AmbulanceDispatchStatus.patientLoadedInTransit)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white, minimumSize: const Size(0, 32)),
                    icon: const Icon(Icons.local_shipping, size: 14),
                    label: const Text('Patient Loaded', style: TextStyle(fontSize: 11)),
                    onPressed: () => _updateAmbulanceStatus(AmbulanceDispatchStatus.patientLoadedInTransit),
                  ),
                if (ref.ambulanceStatus != AmbulanceDispatchStatus.arrived)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white, minimumSize: const Size(0, 32)),
                    icon: const Icon(Icons.where_to_vote, size: 14),
                    label: const Text('Arrived Hospital', style: TextStyle(fontSize: 11)),
                    onPressed: () => _updateAmbulanceStatus(AmbulanceDispatchStatus.arrived),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClinicalSummaryCard(EmergencyReferral ref) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.medical_information, color: Color(0xFFDC2626), size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Clinical Presentation & Vitals', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(4)),
                  child: Text(
                    ref.emergencyCategory.label,
                    style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                ),
              ],
            ),
            const Divider(height: 16),

            Text(
              ref.presentingComplaint,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
            ),
            if (ref.symptomOnsetTime != null) ...[
              const SizedBox(height: 2),
              Text('Onset: ${ref.symptomOnsetTime}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            ],
            const SizedBox(height: 10),

            // Red Flags
            if (ref.redFlagSymptoms.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: ref.redFlagSymptoms.map((rf) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Text(
                      '🚨 $rf',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
            ],

            // Vitals
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('RECORDED VITAL SIGNS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                  const SizedBox(height: 4),
                  Text(
                    ref.formattedVitals,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
            ),

            if (ref.immediateTreatmentGiven != null) ...[
              const SizedBox(height: 8),
              Text(
                'Pre-hospital Care: ${ref.immediateTreatmentGiven}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDestinationCard(EmergencyReferral ref) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_hospital, color: Color(0xFF0D7A68), size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Receiving Healthcare Facility', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                Text(
                  ref.receivingDepartment,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0D7A68)),
                ),
              ],
            ),
            const Divider(height: 16),

            Text(
              ref.receivingFacilityName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 4),
            Text(
              'Target unit: ${ref.receivingDepartment}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            if (ref.recommendationOverrideReason != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Clinical Override Reason: ${ref.recommendationOverrideReason}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                ),
              ),
            ],
            const SizedBox(height: 8),

            Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.phone, size: 14),
                  label: const Text('Call Facility ER', style: TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D7A68),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 36),
                  ),
                  onPressed: () => EmergencyReferralService.launchPhoneCall('07312549999'),
                ),
                const SizedBox(width: 8),
                if (ref.responseStatus != ReceivingResponseStatus.accepted)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.verified, size: 14),
                    label: const Text('Record Acceptance', style: TextStyle(fontSize: 11)),
                    onPressed: _showAcknowledgementDialog,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionHistoryCard(EmergencyReferral ref) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ExpansionTile(
        initiallyExpanded: false,
        leading: const Icon(Icons.history, color: Color(0xFF64748B)),
        title: Text(
          'Version History & Audit Log (${ref.versions.length} Amendments)',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Current Version: ${ref.currentVersion} • Immutable Audit Trail',
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Version 1 Base entry
                ListTile(
                  dense: true,
                  leading: const CircleAvatar(
                    radius: 12,
                    backgroundColor: Color(0xFFE2E8F0),
                    child: Text('v1', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  title: const Text('Version 1: Initial Dispatch Record', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  subtitle: Text(
                    'Created at ${ref.createdAt.toLocal().toString().substring(0, 16)} by ${ref.referringClinicianName}',
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
                // Subsequent versions
                ...ref.versions.map((ver) {
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 12,
                      backgroundColor: const Color(0xFFDCFCE7),
                      child: Text('v${ver.versionNumber}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                    ),
                    title: Text(
                      'Version ${ver.versionNumber}: ${ver.amendmentReason}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    subtitle: Text(
                      'Edited by ${ver.createdByName} • Changed: ${ver.changedFields.join(", ")}',
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                }),
                const Divider(height: 12),

                // Deliveries log
                if (ref.deliveries.isNotEmpty) ...[
                  const Text('Delivery Attempts:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                  const SizedBox(height: 4),
                  ...ref.deliveries.map((del) {
                    return Text(
                      '• [${del.channel.toUpperCase()}] ${del.deliveryStatus} to ${del.recipientAddress} (${del.attemptedAt.toLocal().toString().substring(11, 16)})',
                      style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionControls(EmergencyReferral ref) {
    return Column(
      children: [
        // 1. Post-Dispatch Edit / Add Clinical Update
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.edit_note, color: Colors.white),
            label: const Text('EDIT / ADD CLINICAL UPDATE', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D7A68),
              foregroundColor: Colors.white,
              elevation: 2,
            ),
            onPressed: _showAmendmentDialog,
          ),
        ),
        const SizedBox(height: 10),

        // 2. Dispatch Notification (Email/SMS/Message)
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.send, color: Colors.white),
            label: const Text('TRANSMIT NOTIFICATION TO HOSPITAL', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626), // Urgent crimson
              foregroundColor: Colors.white,
              elevation: 2,
            ),
            onPressed: _showSendNotificationDialog,
          ),
        ),
        const SizedBox(height: 10),

        // 3. Record Handover (When arrived)
        if (ref.workflowStatus != EmergencyWorkflowStatus.handoverCompleted)
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.check_circle_outline, color: Color(0xFF16A34A)),
              label: const Text('RECORD ARRIVAL & CLINICAL HANDOVER', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF16A34A), width: 1.5),
              ),
              onPressed: _showHandoverDialog,
            ),
          ),
      ],
    );
  }
}
