import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_pos_koperasi/core/config/auth_links.dart';

void main() {
  test('password reset callback uses the registered Android deep link', () {
    final uri = Uri.parse('${AuthLinks.passwordResetUrl}?code=example');

    expect(AuthLinks.isPasswordReset(uri), isTrue);
    expect(AuthLinks.passwordResetUrl, 'id.koperasi.kasirpos://reset-password');
  });

  test('unrelated links are not treated as password recovery', () {
    expect(
        AuthLinks.isPasswordReset(Uri.parse('https://example.com')), isFalse);
  });
}
