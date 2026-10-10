import 'package:flutter/material.dart';
import '../models/enums.dart';
import 'referral/referral_tracking_screen.dart';

/// Referrals tab screen presenting real-time transfer tracking and status updates.
class ReferralsScreen extends StatelessWidget {
  final ReferralFilterTag initialFilterTag;

  const ReferralsScreen({
    super.key,
    this.initialFilterTag = ReferralFilterTag.all,
  });

  @override
  Widget build(BuildContext context) {
    return ReferralTrackingScreen(
      initialFilterTag: initialFilterTag,
    );
  }
}
