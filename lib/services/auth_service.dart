import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/firestore_schema.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db   = FirebaseFirestore.instance;

  // Ambil user yang sedang login
  User? get currentUser => _auth.currentUser;

  // Ambil UID (wajib login dulu)
  String get uid => _auth.currentUser!.uid;

  // Stream status login — dipakai di main.dart
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Register
  Future<UserCredential> register(String email, String password, String name) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email, password: password,
    );
    // Simpan profil ke Firestore
    await _db.collection(FSCollection.users).doc(cred.user!.uid).set({
      FSField.uid:         cred.user!.uid,
      FSField.email:       email,
      FSField.displayName: name,
      FSField.fcmToken:    '',
      FSField.createdAt:   FieldValue.serverTimestamp(),
    });
    return cred;
  }

  // Login
  Future<UserCredential> login(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email, password: password,
    );
  }

  // Logout
  Future<void> logout() async => await _auth.signOut();
}