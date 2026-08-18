import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../features/auth/domain/entities/app_user.dart';
import '../../core/utils/toast_utils.dart';

class RoleService {
  static final RoleService _instance = RoleService._internal();
  factory RoleService() => _instance;
  RoleService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Assigns [role] to [targetUid] following the #8 governance workflow:
  ///  - a super_admin writes the role directly;
  ///  - any lower admin instead files a NOMINATION (a roleRequests doc) that a
  ///    super_admin approves, after which the server applies it. Direct role
  ///    writes by non-super admins are rejected by the security rules, so this
  ///    routing is what keeps the button working for provincial/municipal admins.
  Future<void> assignRole(
    String targetUid,
    UserRole role, {
    String targetName = '',
    String? targetPhone,
    String? municipality,
    String? barangay,
  }) async {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null) {
      ToastUtils.showError('You must be signed in to assign roles.');
      return;
    }
    bool isSuper = false;
    try {
      final token = await current.getIdTokenResult();
      isSuper = token.claims?['role'] == 'super_admin';
    } catch (_) {}

    // municipality is relevant for the two town-scoped tiers; barangay only for
    // a barangay admin (cleared for every other role so no stale scope lingers).
    final muniScoped =
        role == UserRole.municipalAdmin || role == UserRole.barangayAdmin;
    final scopedMuni = muniScoped ? municipality : null;
    final scopedBrgy = role == UserRole.barangayAdmin ? (barangay ?? '') : null;

    try {
      if (isSuper) {
        final data = <String, dynamic>{
          'role': role.firestoreValue,
          // Always write barangay (null unless barangay admin) so a re-scoped
          // account never keeps an old grant.
          'barangay': scopedBrgy,
        };
        if (scopedMuni != null) data['municipality'] = scopedMuni;
        await _firestore
            .collection('users')
            .doc(targetUid)
            .set(data, SetOptions(merge: true));
        ToastUtils.showSuccess('Role updated to ${role.displayName}');
      } else {
        await _firestore.collection('roleRequests').add({
          'targetUid': targetUid,
          'targetName': targetName,
          'targetPhone': targetPhone,
          'requestedRole': role.firestoreValue,
          'municipality': scopedMuni,
          'barangay': scopedBrgy,
          'nominatedBy': current.uid,
          'nominatedByName': current.displayName ?? '',
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
        ToastUtils.showSuccess(
            'Nomination submitted — a super admin will approve it.');
      }
    } catch (e) {
      ToastUtils.showError('Failed to assign role: $e');
      rethrow;
    }
  }

  /// Stream of users ordered by name, for the role management tab. Capped so
  /// the live listener can't read the entire (growing) user base at once.
  Stream<QuerySnapshot> getUsersStream() {
    return _firestore
        .collection('users')
        .orderBy('name')
        .limit(500)
        .snapshots();
  }
}

final roleService = RoleService();
