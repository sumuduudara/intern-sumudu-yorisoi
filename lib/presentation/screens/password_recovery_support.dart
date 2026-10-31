import 'package:firebase_auth/firebase_auth.dart';

const resetEmailFeedback =
    '該当するアカウントがある場合は、パスワード再設定メールを送信しました。受信トレイと迷惑メールをご確認ください。';

String? validateRecoveryEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'メールアドレスを入力してください';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
    return '正しいメールアドレスを入力してください';
  }
  return null;
}

String recoveryError(Object error) {
  final code = error is FirebaseAuthException ? error.code : '';
  return switch (code) {
    'invalid-email' => '正しいメールアドレスを入力してください。',
    'expired-action-code' ||
    'invalid-action-code' => 'リンクの有効期限が切れているか、すでに使用されています。再設定リンクをもう一度送ってください。',
    'weak-password' => 'より安全なパスワードを入力してください。',
    'network-request-failed' => '通信に失敗しました。接続を確認して、もう一度お試しください。',
    'too-many-requests' => '試行回数が多すぎます。しばらく待ってからお試しください。',
    'operation-not-allowed' => '現在、パスワード再設定をご利用いただけません。',
    _ => 'パスワード再設定に失敗しました。しばらく待ってからもう一度お試しください。',
  };
}
