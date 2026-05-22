import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

class FirebaseAuthService {
  // Singleton instance
  static final FirebaseAuthService _instance = FirebaseAuthService._internal();
  factory FirebaseAuthService() => _instance;
  FirebaseAuthService._internal() {
    _init();
  }

  UserModel? _currentUser;
  final _authStateController = StreamController<UserModel?>.broadcast();
  StreamSubscription<fb_auth.User?>? _fbAuthSubscription;

  UserModel? get currentUser => _currentUser;
  Stream<UserModel?> get authStateChanges => _authStateController.stream;

  bool get isFirebaseEnabled => Firebase.apps.isNotEmpty;

  void _init() {
    if (isFirebaseEnabled) {
      _fbAuthSubscription = fb_auth.FirebaseAuth.instance.authStateChanges().listen((fb_auth.User? fbUser) async {
        if (fbUser == null) {
          _currentUser = null;
          _authStateController.add(null);
        } else {
          try {
            final doc = await FirebaseFirestore.instance.collection('users').doc(fbUser.uid).get();
            if (doc.exists && doc.data() != null) {
              _currentUser = UserModel.fromMap(doc.data()!);
            } else {
              // Create default doc in firestore
              final newUser = UserModel(
                uid: fbUser.uid,
                email: fbUser.email ?? 'partner@acme.com',
                companyName: 'Acme Corporates Ltd.',
                contactName: fbUser.displayName ?? 'John Doe',
                role: 'Premium Partner',
                credits: 999999, // Unlimited credits B2B setting
              );
              await FirebaseFirestore.instance.collection('users').doc(fbUser.uid).set(newUser.toMap());
              _currentUser = newUser;
            }
          } catch (e) {
            debugPrint('Error fetching user profile from Firestore: $e');
            // Fallback to basic user mapping if firestore read fails
            _currentUser = UserModel(
              uid: fbUser.uid,
              email: fbUser.email ?? 'partner@acme.com',
              companyName: 'Acme Corporates Ltd.',
              contactName: fbUser.displayName ?? 'John Doe',
              role: 'Premium Partner',
              credits: 999999,
            );
          }
          _authStateController.add(_currentUser);
        }
      });
    }
  }

  Future<UserModel?> signInWithEmailAndPassword(String email, String password) async {
    if (isFirebaseEnabled) {
      try {
        fb_auth.UserCredential credential;
        try {
          credential = await fb_auth.FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
        } on fb_auth.FirebaseAuthException catch (authEx) {
          // Auto-register new users on first login attempt to make B2B demo frictionless
          try {
            credential = await fb_auth.FirebaseAuth.instance.createUserWithEmailAndPassword(
              email: email,
              password: password,
            );
          } catch (signupEx) {
            // If signup fails (e.g., because email is in use but password was wrong), throw the original auth error
            throw authEx;
          }
        }
        final fbUser = credential.user;
        if (fbUser != null) {
          // Fetch or create profile
          final doc = await FirebaseFirestore.instance.collection('users').doc(fbUser.uid).get();
          if (doc.exists && doc.data() != null) {
            _currentUser = UserModel.fromMap(doc.data()!);
          } else {
            _currentUser = UserModel(
              uid: fbUser.uid,
              email: fbUser.email ?? email,
              companyName: 'Acme Corporates Ltd.',
              contactName: fbUser.displayName ?? 'John Doe',
              role: 'Premium Partner',
              credits: 999999,
            );
            await FirebaseFirestore.instance.collection('users').doc(fbUser.uid).set(_currentUser!.toMap());
          }
          _authStateController.add(_currentUser);
          return _currentUser;
        }
        throw Exception('Sign in failed: no user credential returned.');
      } catch (e) {
        debugPrint('Firebase sign in error: $e');
        rethrow;
      }
    } else {
      // Mock mode fallback
      await Future.delayed(const Duration(milliseconds: 1200));
      if (email.contains('@') && password.length >= 6) {
        _currentUser = UserModel(
          uid: 'mock_uid_12345',
          email: email,
          companyName: 'Acme Corporates Ltd.',
          contactName: 'John Doe',
          role: 'Premium Partner',
          credits: 999999,
        );
        _authStateController.add(_currentUser);
        return _currentUser;
      }
      throw Exception('Invalid email credentials or password too short.');
    }
  }

  Future<void> signOut() async {
    if (isFirebaseEnabled) {
      await fb_auth.FirebaseAuth.instance.signOut();
    } else {
      await Future.delayed(const Duration(milliseconds: 500));
      _currentUser = null;
      _authStateController.add(null);
    }
  }

  void dispose() {
    _fbAuthSubscription?.cancel();
  }
}

