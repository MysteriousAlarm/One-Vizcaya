import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/services/notification_feed.dart';
import '../state/municipality_state.dart';

/// Bell icon with an unread badge (PANaHON-style). Watches the merged
/// notification feed and shows how many items arrived since the inbox was last
/// opened. Tapping opens the inbox and clears the badge on return.
class NotificationBell extends StatefulWidget {
  final Color iconColor;
  const NotificationBell({super.key, required this.iconColor});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  StreamSubscription<List<FeedItem>>? _sub;
  List<FeedItem> _items = [];
  DateTime _lastSeen = DateTime.fromMillisecondsSinceEpoch(0);
  String? _municipality;

  @override
  void initState() {
    super.initState();
    _municipality = oneVizcayaState.selectedMunicipality.value;
    oneVizcayaState.selectedMunicipality.addListener(_onMuniChanged);
    _init();
  }

  Future<void> _init() async {
    _lastSeen = await getLastSeen();
    _subscribe();
    if (mounted) setState(() {});
  }

  void _onMuniChanged() {
    if (oneVizcayaState.selectedMunicipality.value != _municipality) {
      _municipality = oneVizcayaState.selectedMunicipality.value;
      _subscribe();
    }
  }

  void _subscribe() {
    _sub?.cancel();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _sub = notificationFeedStream(uid, _municipality ?? '').listen((items) {
      if (mounted) setState(() => _items = items);
    });
  }

  int get _unread => _items.where((i) => i.time.isAfter(_lastSeen)).length;

  Future<void> _open() async {
    await Navigator.of(context).pushNamed('/notifications');
    // Opening the inbox marks the feed seen; refresh so the badge clears.
    _lastSeen = await getLastSeen();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    oneVizcayaState.selectedMunicipality.removeListener(_onMuniChanged);
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = _unread;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(Icons.notifications_outlined,
              color: widget.iconColor, size: 22),
          tooltip: 'Notifications',
          onPressed: _open,
        ),
        if (count > 0)
          Positioned(
            right: 5,
            top: 5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFD32F2F),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: Colors.white, width: 1.2),
              ),
              child: Text(
                count > 9 ? '9+' : '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
