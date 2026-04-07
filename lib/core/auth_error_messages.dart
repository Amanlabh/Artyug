import 'package:gotrue/gotrue.dart';

/// Maps Supabase / GoTrue errors to short, user-facing copy (no stack dumps).
String userFriendlyAuthMessage(Object error) {
  if (error is AuthException) {
    final code = error.code?.toLowerCase();
    if (code == 'invalid_credentials') {
      return 'Please enter the correct email and password.';
    }
    final msg = error.message.toLowerCase();
    if (msg.contains('invalid login') ||
        msg.contains('invalid email or password')) {
      return 'Please enter the correct email and password.';
    }
    return error.message;
  }

  final s = error.toString();
  if (s.contains('invalid_credentials') ||
      s.contains('Invalid login credentials')) {
    return 'Please enter the correct email and password.';
  }
  return s.replaceFirst(RegExp(r'^Exception:\s*'), '');
}
