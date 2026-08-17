import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../../domain/models/sos_alert.dart';

/// Drives the emergency SOS beacon: creates an alert the instant SOS is pressed,
/// then streams the citizen's live location into it so responders always have
/// the person's current position.
///
/// Connectivity handling (per requirement): the device GPS keeps producing
/// fixes even with no signal, and Firestore's offline write queue coalesces
/// repeated updates to the SAME document — so when the connection drops we keep
/// the last-known position pending (a de-facto "one-shot") and the newest fix
/// flushes automatically the moment the connection is stable again, resuming
/// live tracking without any manual step.
class SosService {
  static final SosService _instance = SosService._internal();
  factory SosService() => _instance;
  SosService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  StreamSubscription<Position>? _posSub;
  String? _activeAlertId;
  DateTime? _lastWrite;

  String? get activeAlertId => _activeAlertId;
  bool get hasActive => _activeAlertId != null;

  // Don't hammer Firestore: at most one location write every few seconds (the
  // stream still fires more often for a responsive local UI).
  static const _minWriteGap = Duration(seconds: 4);

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('sos_alerts');

  /// Create the alert with an immediate best-effort fix, then begin live
  /// tracking. Returns the new alert id (or null if not signed in).
  Future<String?> startEmergency({String? note}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    // Don't let a double-tap (or an already-running emergency) create duplicate
    // beacons — reuse the one that's already live.
    if (_activeAlertId != null) return _activeAlertId;

    // Profile for name / phone / scope so responders know who + where.
    String name = user.displayName ?? '', phone = user.phoneNumber ?? '';
    String municipality = '', barangay = '';
    try {
      final profile = await _db.collection('users').doc(user.uid).get();
      final d = profile.data() ?? {};
      name = (d['name'] as String?)?.isNotEmpty == true ? d['name'] as String : name;
      phone = (d['phoneNumber'] as String?)?.isNotEmpty == true
          ? d['phoneNumber'] as String
          : phone;
      municipality = (d['municipality'] as String?) ?? '';
      barangay = (d['barangay'] as String?) ?? '';
    } catch (_) {}

    final fix = await _bestEffortFix();

    final doc = await _col.add({
      'uid': user.uid,
      'name': name,
      'phone': phone,
      'municipality': municipality,
      'barangay': barangay,
      'lat': fix?.latitude,
      'lng': fix?.longitude,
      'accuracy': fix?.accuracy,
      'status': 'active',
      'tracking': true,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _activeAlertId = doc.id;
    _startTracking(doc.id);
    return doc.id;
  }

  /// A quick fix now, falling back to the last-known position if a fresh GPS
  /// lock is slow — never block the SOS on a perfect fix.
  Future<Position?> _bestEffortFix() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return await Geolocator.getLastKnownPosition();
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return await Geolocator.getLastKnownPosition();
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } catch (_) {
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  void _startTracking(String alertId) {
    _posSub?.cancel();
    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 8, // metres moved before an update
      ),
    ).listen(
      (pos) => _pushLocation(alertId, pos),
      onError: (e) => debugPrint('SOS position stream error: $e'),
    );
  }

  Future<void> _pushLocation(String alertId, Position pos) async {
    final now = DateTime.now();
    if (_lastWrite != null && now.difference(_lastWrite!) < _minWriteGap) return;
    _lastWrite = now;
    // Fire-and-forget: if offline this is queued and coalesced by Firestore.
    unawaited(_col.doc(alertId).set({
      'lat': pos.latitude,
      'lng': pos.longitude,
      'accuracy': pos.accuracy,
      'tracking': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).catchError((e) {
      debugPrint('SOS location write failed (queued if offline): $e');
    }));
  }

  /// The citizen ends their own emergency (safe now / false alarm).
  Future<void> cancelActive() async {
    final id = _activeAlertId;
    _stopTracking();
    if (id == null) return;
    try {
      await _col.doc(id).set({
        'status': 'cancelled',
        'tracking': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('SOS cancel failed: $e');
    }
    _activeAlertId = null;
  }

  void _stopTracking() {
    _posSub?.cancel();
    _posSub = null;
    _lastWrite = null;
  }

  /// Live stream of a single alert (for the citizen's active screen).
  Stream<SosAlert> watch(String alertId) =>
      _col.doc(alertId).snapshots().map(SosAlert.fromFirestore);

  // ── Admin: open emergencies, scoped to the acting admin's tier ────────────
  Stream<List<SosAlert>> watchProvincialOpen() => _mapAlerts(
        _col
            .where('status', whereIn: ['active', 'dispatched'])
            .orderBy('createdAt', descending: true)
            .limit(100),
      );

  Stream<List<SosAlert>> watchMunicipalOpen(String municipality) => _mapAlerts(
        _col
            .where('municipality', isEqualTo: municipality)
            .where('status', whereIn: ['active', 'dispatched'])
            .orderBy('createdAt', descending: true)
            .limit(100),
      );

  Stream<List<SosAlert>> watchBarangayOpen(
    String municipality,
    String barangay,
  ) =>
      _mapAlerts(
        _col
            .where('municipality', isEqualTo: municipality)
            .where('barangay', isEqualTo: barangay)
            .where('status', whereIn: ['active', 'dispatched'])
            .orderBy('createdAt', descending: true)
            .limit(100),
      );

  Stream<List<SosAlert>> _mapAlerts(Query<Map<String, dynamic>> q) =>
      q.snapshots().map((s) => s.docs.map(SosAlert.fromFirestore).toList());

  /// Operator confirms the SOS is real (after calling/messaging the person).
  /// Recorded for accountability; dispatch should follow a verification.
  Future<void> verify(String alertId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    await _col.doc(alertId).set({
      'verified': true,
      'verifiedBy': uid,
      'verifiedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Admin marks responders dispatched.
  Future<void> dispatch(String alertId) => setStatus(alertId, SosStatus.dispatched);

  /// Close an alert with a disposition: a genuine 'resolved', an honest
  /// 'false_alarm', or deliberate 'abuse' (which feeds the abuser flag).
  Future<void> resolveWith(String alertId, String disposition) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    await _col.doc(alertId).set({
      'status': 'resolved',
      'disposition': disposition,
      'resolvedBy': uid,
      'resolvedAt': FieldValue.serverTimestamp(),
      'tracking': false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Admin marks responders dispatched / the emergency resolved.
  Future<void> setStatus(String alertId, SosStatus status) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    await _col.doc(alertId).set({
      'status': status.key,
      if (status == SosStatus.dispatched) 'dispatchedBy': uid,
      if (status == SosStatus.dispatched)
        'dispatchedAt': FieldValue.serverTimestamp(),
      if (status == SosStatus.resolved) 'resolvedBy': uid,
      if (status == SosStatus.resolved)
        'resolvedAt': FieldValue.serverTimestamp(),
      if (status == SosStatus.resolved) 'tracking': false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

final sosService = SosService();
