import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

enum AuthStatus {
  uninitialized,
  authenticated,
  unauthenticated,
  authenticating,
}

// Mock user class for local-only mode
class MockUser {
  final String uid;
  final String? email;
  final String? displayName;
  final bool isAnonymous;
  
  MockUser({
    required this.uid,
    this.email,
    this.displayName,
    this.isAnonymous = false,
  });
}

class AuthProvider extends ChangeNotifier {
  AuthStatus _status = AuthStatus.unauthenticated;
  MockUser? _user;
  String? _errorMessage;
  bool _isNewUser = false;
  
  AuthStatus get status => _status;
  MockUser? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isNewUser => _isNewUser;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  
  AuthProvider() {
    _initializeAuth();
  }
  
  Future<void> _initializeAuth() async {
    // In local-only mode, start as unauthenticated
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
  
  // Sign in anonymously (mock implementation)
  Future<bool> signInAnonymously() async {
    try {
      _status = AuthStatus.authenticating;
      _errorMessage = null;
      notifyListeners();
      
      // Simulate network delay
      await Future.delayed(const Duration(milliseconds: 500));
      
      _user = MockUser(
        uid: 'anonymous_${DateTime.now().millisecondsSinceEpoch}',
        isAnonymous: true,
      );
      _status = AuthStatus.authenticated;
      _isNewUser = true;
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = 'Failed to sign in anonymously';
      notifyListeners();
      return false;
    }
  }
  
  // Sign in with email and password (mock implementation)
  Future<bool> signInWithEmail(String email, String password) async {
    try {
      _status = AuthStatus.authenticating;
      _errorMessage = null;
      notifyListeners();
      
      // Simulate network delay
      await Future.delayed(const Duration(seconds: 1));
      
      // Mock validation - accept any email/password for demo
      if (email.isNotEmpty && password.length >= 6) {
        _user = MockUser(
          uid: 'user_${email.hashCode}',
          email: email,
          displayName: email.split('@').first,
          isAnonymous: false,
        );
        _status = AuthStatus.authenticated;
        _isNewUser = false;
        notifyListeners();
        return true;
      } else {
        _status = AuthStatus.unauthenticated;
        _errorMessage = 'Invalid email or password';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = 'An unexpected error occurred';
      notifyListeners();
      return false;
    }
  }
  
  // Register with email and password (mock implementation)
  Future<bool> registerWithEmail(String email, String password, String displayName) async {
    try {
      _status = AuthStatus.authenticating;
      _errorMessage = null;
      notifyListeners();
      
      // Simulate network delay
      await Future.delayed(const Duration(seconds: 1));
      
      if (email.isNotEmpty && password.length >= 6 && displayName.isNotEmpty) {
        _user = MockUser(
          uid: 'user_${email.hashCode}',
          email: email,
          displayName: displayName,
          isAnonymous: false,
        );
        _status = AuthStatus.authenticated;
        _isNewUser = true;
        notifyListeners();
        return true;
      } else {
        _status = AuthStatus.unauthenticated;
        _errorMessage = 'Invalid registration data';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = 'An unexpected error occurred';
      notifyListeners();
      return false;
    }
  }
  
  // Reset password (mock implementation)
  Future<bool> resetPassword(String email) async {
    try {
      // Simulate network delay
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (email.isNotEmpty && email.contains('@')) {
        return true;
      } else {
        _errorMessage = 'Invalid email address';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Failed to send reset email';
      notifyListeners();
      return false;
    }
  }
  
  // Update user profile (mock implementation)
  Future<bool> updateProfile({String? displayName, String? photoURL}) async {
    if (_user == null) return false;
    
    try {
      // Simulate network delay
      await Future.delayed(const Duration(milliseconds: 500));
      
      _user = MockUser(
        uid: _user!.uid,
        email: _user!.email,
        displayName: displayName ?? _user!.displayName,
        isAnonymous: _user!.isAnonymous,
      );
      
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update profile';
      notifyListeners();
      return false;
    }
  }
  
  // Link anonymous account to email (mock implementation)
  Future<bool> linkAnonymousAccount(String email, String password) async {
    if (_user == null || !_user!.isAnonymous) return false;
    
    try {
      // Simulate network delay
      await Future.delayed(const Duration(seconds: 1));
      
      _user = MockUser(
        uid: _user!.uid,
        email: email,
        displayName: email.split('@').first,
        isAnonymous: false,
      );
      
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to link account';
      notifyListeners();
      return false;
    }
  }
  
  // Sign out
  Future<void> signOut() async {
    try {
      _user = null;
      _status = AuthStatus.unauthenticated;
      _isNewUser = false;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      developer.log('Sign out error: $e');
    }
  }
  
  // Delete account (mock implementation)
  Future<bool> deleteAccount() async {
    if (_user == null) return false;
    
    try {
      // Simulate network delay
      await Future.delayed(const Duration(milliseconds: 500));
      
      _user = null;
      _status = AuthStatus.unauthenticated;
      _isNewUser = false;
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete account';
      notifyListeners();
      return false;
    }
  }
  
  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}