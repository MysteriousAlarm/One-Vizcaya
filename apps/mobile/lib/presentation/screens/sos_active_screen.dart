import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/toast_utils.dart';
import '../../data/services/sos_service.dart';
import '../../domain/models/sos_alert.dart';

/// Shown while a citizen's SOS is active — reassures them their live location is
/// being shared, lets them call the hotline, and lets them stand the alert down.
class SosActiveScreen extends StatelessWidget {
  final String alertId;
  const SosActiveScreen({super.key, required this.alertId});

  Future<void> _call() async {
    final uri = Uri(scheme: 'tel', path: AppConstants.pdrrmoHotline);
    try {
      if (!await launchUrl(uri)) {
        ToastUtils.showError('Could not open the dialer. Call ${AppConstants.pdrrmoHotline}.');
      }
    } catch (_) {
      ToastUtils.showError('Call ${AppConstants.pdrrmoHotline} for emergencies.');
    }
  }

  Future<void> _standDown(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End emergency?'),
        content: const Text(
            'This stops sharing your live location with responders. Only do this '
            'if you are safe or it was a false alarm.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep active')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("I'm safe now"),
          ),
        ],
      ),
    );
    if (ok == true) {
      await sosService.cancelActive();
      if (context.mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // don't let a back-swipe silently abandon the beacon
      child: Scaffold(
        backgroundColor: const Color(0xFFB71C1C),
        body: SafeArea(
          child: StreamBuilder<SosAlert>(
            stream: sosService.watch(alertId),
            builder: (context, snap) {
              final alert = snap.data;
              final dispatched = alert?.status == SosStatus.dispatched;
              final hasFix = alert?.lat != null && alert?.lng != null;
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    const Icon(Icons.sos_rounded, color: Colors.white, size: 64),
                    const SizedBox(height: 12),
                    Text(
                      dispatched ? 'Help is on the way' : 'Emergency active',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: const AlwaysStoppedAnimation(Colors.white),
                            value: hasFix ? null : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            hasFix
                                ? 'Your live location is being shared with responders'
                                : 'Getting your location…',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (hasFix)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Location shared',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13)),
                            const SizedBox(height: 4),
                            Text(
                              '${alert!.lat!.toStringAsFixed(6)}, ${alert.lng!.toStringAsFixed(6)}'
                              '${alert.accuracy != null ? '  ·  ±${alert.accuracy!.round()} m' : ''}',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12),
                            ),
                            if (alert.barangay != null &&
                                alert.barangay!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  'Brgy. ${alert.barangay}, ${alert.municipality}',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12),
                                ),
                              ),
                          ],
                        ),
                      ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _call,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFFB71C1C),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      icon: const Icon(Icons.call),
                      label: Text('Call ${AppConstants.pdrrmoHotlineLabel}'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => _standDown(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text("I'm safe now — end emergency"),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
