import 'package:firebase_core/firebase_core.dart';

// Supply client configuration at run time, outside the repository.
FirebaseOptions localFirebaseOptions() {
  const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  const appId = String.fromEnvironment('FIREBASE_APP_ID');
  const sender = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  const project = String.fromEnvironment('FIREBASE_PROJECT_ID');
  if ([apiKey, appId, sender, project].any((value) => value.isEmpty)) {
    throw StateError('Missing Firebase client configuration; see README.');
  }
  const bundle = String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID');
  const domain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  return FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: sender,
    projectId: project,
    iosBundleId: bundle.isEmpty ? null : bundle,
    authDomain: domain.isEmpty ? null : domain,
  );
}
