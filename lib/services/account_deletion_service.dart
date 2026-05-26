import 'package:firebase_auth/firebase_auth.dart';

class AccountDeletionService {
  const AccountDeletionService._();

  static Future<void> deleteCurrentAccount({
    required String password,
  }) async {
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;

    if (user == null) {
      throw StateError('You must be signed in to delete your account.');
    }

    final email = user.email?.trim();
    if (email == null || email.isEmpty) {
      throw StateError(
        'This account does not have an email address. Please sign in again and try deleting the account.',
      );
    }

    final cleanPassword = password.trim();
    if (cleanPassword.isEmpty) {
      throw StateError('Please enter your password to delete your account.');
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: cleanPassword,
    );

    // Reauthenticate first because Firebase requires a recent login before
    // deleting an account.
    final userCredential = await user.reauthenticateWithCredential(credential);

    final reauthedUser = userCredential.user ?? auth.currentUser;
    if (reauthedUser == null) {
      throw StateError('Could not confirm the signed-in user.');
    }

    // This is the only required step for letting the same email sign up again.
    // Do not delete Firestore documents here; changing Firestore streams while
    // the profile route is still mounted can trigger Flutter's
    // _dependents.isEmpty assertion on some devices.
    await reauthedUser.delete();
  }
}
