import 'package:flutter_test/flutter_test.dart';
import 'package:yorisoi/services/firebase_app_check_bootstrap.dart';

void main() {
  bool allowed({
    bool enabled = true,
    bool isWeb = true,
    bool isDebug = true,
    String url = 'http://localhost:8879',
  }) => shouldUseLocalAppCheckDebug(
    enabled: enabled,
    isWeb: isWeb,
    isDebug: isDebug,
    origin: Uri.parse(url),
  );

  test('permits explicitly enabled localhost Web debug runs', () {
    for (final host in ['localhost', '127.0.0.1', '[::1]']) {
      expect(allowed(url: 'http://$host:8879'), isTrue);
    }
  });

  test('never enables debug attestation implicitly or in release/native', () {
    expect(allowed(enabled: false), isFalse);
    expect(allowed(isWeb: false), isFalse);
    expect(allowed(isDebug: false), isFalse);
  });

  test('rejects public origins, deceptive hostnames and non-Web schemes', () {
    for (final url in [
      'https://yorisoi.example',
      'https://localhost.example',
      'https://127.0.0.1.example',
      'file:///localhost/index.html',
    ]) {
      expect(allowed(url: url), isFalse, reason: url);
    }
  });
}
