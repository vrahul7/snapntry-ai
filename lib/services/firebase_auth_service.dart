import 'dart:async';
import '../models/user_model.dart';

class FirebaseAuthService {
  // Singleton instance
  static final FirebaseAuthService _instance = FirebaseAuthService._internal();
  factory FirebaseAuthService() => _instance;
  FirebaseAuthService._internal();

  UserModel? _currentUser;
  final _authStateController = StreamController<UserModel?>.broadcast();

  UserModel? get currentUser => _currentUser;
  Stream<UserModel?> get authStateChanges => _authStateController.stream;

  Future<UserModel?> signInWithEmailAndPassword(String email, String password) async {
    // Mimic API delay
    await Future.delayed(const Duration(milliseconds: 1200));

    if (email.contains('@') && password.length >= 6) {
      _currentUser = UserModel(
        uid: 'mock_uid_12345',
        email: email,
        companyName: 'Acme Corporates Ltd.',
        contactName: 'John Doe',
        role: 'Premium Partner',
        credits: 250,
      );
      _authStateController.add(_currentUser);
      return _currentUser;
    }
    throw Exception('Invalid email credentials or password too short.');
  }

  Future<void> signOut() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _currentUser = null;
    _authStateController.add(null);
  }
}
