import 'package:cloud_firestore/cloud_firestore.dart';

/// Lifecycle of an emergency SOS.
enum SosStatus { active, dispatched, resolved, cancelled }

SosStatus sosStatusFromString(String? v) {
  switch (v) {
    case 'dispatched':
      return SosStatus.dispatched;
    case 'resolved':
      return SosStatus.resolved;
    case 'cancelled':
      return SosStatus.cancelled;
    case 'active':
    default:
      return SosStatus.active;
  }
}

extension SosStatusX on SosStatus {
  String get key => switch (this) {
        SosStatus.active => 'active',
        SosStatus.dispatched => 'dispatched',
        SosStatus.resolved => 'resolved',
        SosStatus.cancelled => 'cancelled',
      };

  String get label => switch (this) {
        SosStatus.active => 'Active',
        SosStatus.dispatched => 'Responders dispatched',
        SosStatus.resolved => 'Resolved',
        SosStatus.cancelled => 'Cancelled',
      };
}

/// A live emergency beacon: created the instant a citizen presses SOS, then its
/// location is updated in place while the emergency is active so responders can
/// be dispatched to the person's exact, current position.
class SosAlert {
  final String id;
  final String uid;
  final String name;
  final String phone;
  final String municipality;
  final String? barangay;
  final double? lat;
  final double? lng;
  final double? accuracy;
  final SosStatus status;
  final String? note;
  final bool tracking;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? dispatchedBy;
  final String? resolvedBy;

  const SosAlert({
    required this.id,
    required this.uid,
    required this.name,
    required this.phone,
    required this.municipality,
    this.barangay,
    this.lat,
    this.lng,
    this.accuracy,
    this.status = SosStatus.active,
    this.note,
    this.tracking = false,
    this.createdAt,
    this.updatedAt,
    this.dispatchedBy,
    this.resolvedBy,
  });

  bool get isOpen =>
      status == SosStatus.active || status == SosStatus.dispatched;

  /// A universal Google Maps link to the reported position — opening it shows
  /// the address + lets a responder navigate, no in-app map required.
  String? get mapsUrl => (lat != null && lng != null)
      ? 'https://www.google.com/maps/search/?api=1&query=$lat,$lng'
      : null;

  factory SosAlert.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    DateTime? ts(dynamic v) => v is Timestamp ? v.toDate() : null;
    double? d(dynamic v) => v is num ? v.toDouble() : null;
    return SosAlert(
      id: doc.id,
      uid: (data['uid'] as String?) ?? '',
      name: (data['name'] as String?) ?? 'Unknown',
      phone: (data['phone'] as String?) ?? '',
      municipality: (data['municipality'] as String?) ?? '',
      barangay: (data['barangay'] as String?)?.isEmpty == true
          ? null
          : data['barangay'] as String?,
      lat: d(data['lat']),
      lng: d(data['lng']),
      accuracy: d(data['accuracy']),
      status: sosStatusFromString(data['status'] as String?),
      note: data['note'] as String?,
      tracking: (data['tracking'] as bool?) ?? false,
      createdAt: ts(data['createdAt']),
      updatedAt: ts(data['updatedAt']),
      dispatchedBy: data['dispatchedBy'] as String?,
      resolvedBy: data['resolvedBy'] as String?,
    );
  }
}
