import 'package:firebase_core/firebase_core.dart';

/// Helper to format raw exceptions and error objects into clean, user-friendly error messages.
class ErrorFormatter {
  ErrorFormatter._();

  /// Formats any error object [error] into a clean user-facing string.
  static String format(dynamic error) {
    if (error == null) return 'An unexpected error occurred.';

    if (error is FirebaseException) {
      return _formatFirebaseException(error);
    }

    String msg = error.toString().trim();

    // Strip common wrapper prefixes
    if (msg.startsWith('Exception: ')) {
      msg = msg.substring('Exception: '.length).trim();
    }
    if (msg.startsWith('Error: ')) {
      msg = msg.substring('Error: '.length).trim();
    }
    if (msg.startsWith('Bad state: ')) {
      msg = msg.substring('Bad state: '.length).trim();
    }

    // Check for raw firebase code tags like [cloud_firestore/permission-denied]
    final bracketMatch = RegExp(r'^\[[\w\-/]+\]\s*(.*)$').firstMatch(msg);
    if (bracketMatch != null) {
      final innerMsg = bracketMatch.group(1)?.trim();
      if (innerMsg != null && innerMsg.isNotEmpty) {
        return innerMsg;
      }
    }

    // Map common raw Firestore/Network error strings
    if (msg.contains('permission-denied') ||
        msg.contains('PERMISSION_DENIED')) {
      return 'Access denied: You do not have permission to perform this action.';
    }
    if (msg.contains('unavailable') ||
        msg.contains('network-request-failed') ||
        msg.contains('Failed to connect')) {
      return 'Network connection issue: Please check your internet connection.';
    }
    if (msg.contains('deadline-exceeded') || msg.contains('timeout')) {
      return 'The operation timed out. Please try again.';
    }

    return msg.isNotEmpty ? msg : 'An unexpected error occurred.';
  }

  static String _formatFirebaseException(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'Access denied: You do not have permission to perform this action.';
      case 'unavailable':
      case 'network-request-failed':
        return 'Network issue: Unable to connect to Firebase. Please check your connection.';
      case 'deadline-exceeded':
        return 'Request timed out. Please try again.';
      case 'not-found':
        return 'The requested resource was not found.';
      case 'already-exists':
        return 'A record with this information already exists.';
      case 'unauthenticated':
        return 'Your session has expired. Please log in again.';
      default:
        return e.message?.isNotEmpty == true
            ? e.message!
            : 'A database error occurred (${e.code}).';
    }
  }
}
