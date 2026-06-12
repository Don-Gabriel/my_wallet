import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

String friendlyErrorMessage(Object error) {
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'network-request-failed' =>
        'Could not connect. Check your internet connection.',
      'popup-closed-by-user' => 'Sign-in was cancelled.',
      'user-disabled' => 'This account has been disabled.',
      'invalid-email' => 'Enter a valid email address.',
      'invalid-credential' =>
        'Sign-in failed. Try Google or continue privately.',
      'wrong-password' => 'The password is incorrect.',
      'user-not-found' => 'No account was found for this sign-in method.',
      'email-already-in-use' => 'This account already exists.',
      'weak-password' => 'Use a stronger password with at least 8 characters.',
      'too-many-requests' =>
        'Too many attempts. Wait a moment, then try again.',
      'requires-recent-login' =>
        'Please sign out and sign in again before changing this.',
      'expired-action-code' => 'This security request expired. Try again.',
      'invalid-action-code' => 'This security request is invalid. Try again.',
      _ => error.message ?? 'Sign-in failed. Please try again.',
    };
  }

  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' =>
        'Cloud sync is blocked. Deploy Firestore rules and try again.',
      'unavailable' =>
        'Cloud sync is temporarily unavailable. Your network may be offline.',
      'not-found' => 'That item could not be found.',
      'already-exists' => 'That item already exists.',
      _ => error.message ?? 'Something went wrong with cloud sync.',
    };
  }

  return 'Something went wrong. Please try again.';
}

void showErrorSnackBar(BuildContext context, Object error) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(error))));
}
