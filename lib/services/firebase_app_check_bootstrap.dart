import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

/// Debug attestation is deliberately restricted to opt-in localhost Web runs.
bool shouldUseLocalAppCheckDebug({
  required bool enabled,
  required bool isWeb,
  required bool isDebug,
  required Uri origin,
}) {
  return enabled &&
      isWeb &&
      isDebug &&
      (origin.scheme == 'http' || origin.scheme == 'https') &&
      const {'localhost', '127.0.0.1', '::1', '[::1]'}.contains(origin.host);
}

/// Call after Firebase.initializeApp and before creating Firebase AI clients.
/// Trust the generated token in Firebase Console; never put it in source code.
/// Production attestation requires separate provider configuration.
Future<void> initializeLocalAppCheck() async {
  if (!shouldUseLocalAppCheckDebug(
    enabled: const bool.fromEnvironment('YORISOI_APP_CHECK_DEBUG'),
    isWeb: kIsWeb,
    isDebug: kDebugMode,
    origin: Uri.base,
  )) {
    return;
  }

  await FirebaseAppCheck.instance.activate(providerWeb: WebDebugProvider());
}
