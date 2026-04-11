import 'package:connectrpc/connect.dart';

/// Extracts a user-friendly error message from an exception.
///
/// Handles Connect RPC errors, converting codes and messages into
/// readable descriptions. Falls back to the raw error for unknown types.
String friendlyError(Object error) {
  if (error is ConnectException) {
    final msg = error.message;

    // Duplicate key / unique constraint
    if (msg.contains('duplicate key') || msg.contains('already exists')) {
      return 'A record with this identifier already exists. '
          'Please use a different code or name.';
    }

    // Validation errors
    if (error.code == Code.invalidArgument) {
      return 'Some fields are invalid: $msg';
    }

    // Permission denied
    if (error.code == Code.permissionDenied) {
      return 'You do not have permission to perform this action.';
    }

    // Not found
    if (error.code == Code.notFound) {
      return 'The requested resource was not found.';
    }

    // Auth errors
    if (error.code == Code.unauthenticated) {
      return 'Your session has expired. Please log in again.';
    }

    // Internal / unknown
    if (error.code == Code.internal) {
      return 'An internal error occurred. Please try again or contact support.';
    }

    return msg;
  }

  final s = error.toString();

  // Common patterns
  if (s.contains('duplicate key') || s.contains('unique constraint')) {
    return 'A record with this identifier already exists.';
  }
  if (s.contains('SocketException') || s.contains('network')) {
    return 'Network error. Please check your connection and try again.';
  }
  if (s.contains('timeout')) {
    return 'Request timed out. Please try again.';
  }

  return 'An unexpected error occurred. Please try again.';
}
