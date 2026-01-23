import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthProvider with ChangeNotifier {
  User? _currentUser;
  bool _isLoading = true;

  // GoogleSignIn ob'ektini yaratish
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
  );

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;

  AuthProvider() {
    _init();
  }

  Future<void> _init() async {
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      try {
        _currentUser = user;
        if (user != null) {
          await _updateOnlineStatus(true);
        }
      } catch (e) {
        debugPrint("Auth Init Error: $e");
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    });
  }

  // 1. Google orqali kirish
  Future<UserCredential?> signInWithGoogle() async {
    try {
      _isLoading = true;
      notifyListeners();

      // signIn() metodini chaqirish
      final dynamic googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        _isLoading = false;
        notifyListeners();
        return null;
      }

      // Authentication ma'lumotlarini olish
      final dynamic googleAuth = await googleUser.authentication;

      // Credential yaratish
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      if (userCredential.additionalUserInfo?.isNewUser ?? false) {
        await _createFirestoreUser(userCredential.user!);
      }

      return userCredential;
    } catch (e) {
      debugPrint("Google Auth Error: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _createFirestoreUser(User user) async {
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'username': user.displayName ?? 'Foydalanuvchi',
      'email': user.email,
      'createdAt': FieldValue.serverTimestamp(),
      'bio': 'SafeChat orqali muloqotda',
      'avatar': user.photoURL ?? '',
      'online': true,
      'lastActive': FieldValue.serverTimestamp(),
      'fcmToken': '',
      'role': 'user',
      'isBlocked': false,
    });
  }

  // 2. Email orqali kirish
  Future<void> signIn(String email, String password) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      debugPrint("Login xatosi: $e");
      rethrow;
    }
  }

  // 3. Ro'yxatdan o'tish
  Future<void> signUp(String email, String password, String username) async {
    try {
      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(credential.user!.uid)
          .set({
        'uid': credential.user!.uid,
        'username': username,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'bio': 'SafeChat orqali muloqotda',
        'avatar': '',
        'online': true,
        'lastActive': FieldValue.serverTimestamp(),
        'fcmToken': '',
        'role': 'user',
        'isBlocked': false,
      });
    } catch (e) {
      debugPrint("Ro'yxatdan o'tish xatosi: $e");
      rethrow;
    }
  }

  // 4. Profilni yangilash
  Future<void> updateProfile(
      {String? username, String? bio, String? avatar}) async {
    if (_currentUser == null) return;
    try {
      final updates = <String, dynamic>{};
      if (username != null) updates['username'] = username;
      if (bio != null) updates['bio'] = bio;
      if (avatar != null) updates['avatar'] = avatar;

      if (updates.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser!.uid)
            .update(updates);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Profilni yangilashda xato: $e");
      rethrow;
    }
  }

  // 5. Chiqish
  Future<void> signOut() async {
    try {
      await _updateOnlineStatus(false);

      // isSignedIn xatosini yo'qotish uchun dynamic tekshiruv
      final dynamic googleSignInInstance = _googleSignIn;
      final bool isSigned = await googleSignInInstance.isSignedIn();

      if (isSigned) {
        await googleSignInInstance.signOut();
      }

      await FirebaseAuth.instance.signOut();
      notifyListeners();
    } catch (e) {
      debugPrint("Chiqishda xato: $e");
    }
  }

  // 6. Online status
  Future<void> _updateOnlineStatus(bool online) async {
    if (_currentUser == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .update({
        'online': online,
        'lastActive': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Status yangilashda xato: $e");
    }
  }
}
