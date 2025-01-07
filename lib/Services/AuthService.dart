import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  Future<String?> registration ({
    required String email,
    required String password,
  }) async {
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return 'Success';
    }
    on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        return 'The Password provided is too weak';
      }
      else if (e.code == 'email=already-in-use') {
        return 'The account already exists for that email';
      }
      else {
        return e.message;
      }
    }
    catch (e) {
      return e.toString();
    }
  }

  Future<String?> login ({
    required String email,
    required String password,
  }) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
      return 'Success';
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        return 'No user forund for that email';
      } else if (e.code == 'wrong-password') {
        return 'Wrong password provided for that user';
      }
      else {
        return e.message;
      }
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> logout () async {
    try {
      await FirebaseAuth.instance.signOut();
      await signOutWithGoogle();
      return 'Success';
    }
    catch (e) {
      return e.toString();
    }
  }

  Future<UserCredential> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    final GoogleSignInAuthentication? googleAuth = await googleUser?.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth?.accessToken,
      idToken: googleAuth?.idToken,
    );
    return await FirebaseAuth.instance.signInWithCredential(credential);
  }

  Future<void> signOutWithGoogle() async {
    await GoogleSignIn().signOut();
  }
}