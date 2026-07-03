class AuthLinks {
  const AuthLinks._();

  static const passwordResetScheme = 'id.koperasi.kasirpos';
  static const passwordResetHost = 'reset-password';
  static const passwordResetUrl = '$passwordResetScheme://$passwordResetHost';

  static bool isPasswordReset(Uri uri) {
    return uri.scheme == passwordResetScheme && uri.host == passwordResetHost;
  }
}
