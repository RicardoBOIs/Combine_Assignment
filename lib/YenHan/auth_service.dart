import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_sign_in/google_sign_in.dart';

ValueNotifier<AuthService> authService = ValueNotifier(AuthService());
class AuthService{
  final FirebaseAuth firebaseAuth = FirebaseAuth.instance;

  User? get currentUser => firebaseAuth.currentUser;

  Stream<User?> get authStateChanges => firebaseAuth.authStateChanges();

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return await firebaseAuth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential?> loginWithGoogle() async{
    try{
      final googleUser = await GoogleSignIn().signIn();

      final googleAuth= await googleUser?.authentication;

      final cred=GoogleAuthProvider.credential(
          idToken:googleAuth?.idToken,accessToken: googleAuth?.accessToken
      );

      return await firebaseAuth.signInWithCredential(cred);
    } catch(e){
      print(e.toString());
    }
    return null;
  }
  Future<UserCredential> createAccount({
    required String email,
    required String password,
  }) async {
    // Create the user account
    UserCredential userCred = await firebaseAuth
        .createUserWithEmailAndPassword(email: email, password: password);

    // Send verification email
    if (!userCred.user!.emailVerified) {
      await userCred.user!.sendEmailVerification();

      // Wait for email verification
      bool isVerified = false;
      while (!isVerified) {
        // Reload user to get updated verification status
        await userCred.user!.reload();

        // Get fresh user data
        User? currentUser = firebaseAuth.currentUser;

        if (currentUser != null && currentUser.emailVerified) {
          isVerified = true;
        } else {
          // Wait before checking again (e.g., 2 seconds)
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }

    return userCred;
  }

  Future<void> signOut() async{
    await firebaseAuth.signOut();
  }
  
  Future<void> resetPassword({
    required String email,
}) async {
    await firebaseAuth.sendPasswordResetEmail(email: email);
    
  }

  Future<void> updateUsername({
    required String username,
}) async{
    await currentUser!.updateDisplayName(username);
  }

  Future<void> deleteAccount({
    required String email,
    required String password,
}) async {
    AuthCredential credential =
        EmailAuthProvider.credential(email: email, password: password);
    await currentUser!.reauthenticateWithCredential(credential);
    await currentUser!.delete();
    await firebaseAuth.signOut();
  }
}