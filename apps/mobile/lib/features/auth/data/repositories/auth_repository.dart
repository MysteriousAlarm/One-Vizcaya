import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/app_user.dart';

class AuthRepository {
  Future<UserRole> getUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return UserRole.citizen;

    final idTokenResult = await user.getIdTokenResult(true);
    final role = idTokenResult.claims?['role'] as String?;
    // Map every role claim (legacy 'admin' → provincialAdmin) via the shared parser.
    return AppUser.roleFromString(role);
  }

  Future<AppUser?> getCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final role = await getUserRole();
    return AppUser(
      uid: user.uid,
      name: user.displayName ?? '',
      phoneNumber: user.phoneNumber ?? '',
      municipality: '',
      role: role,
    );
  }
}
