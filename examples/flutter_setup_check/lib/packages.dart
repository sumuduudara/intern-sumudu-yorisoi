import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:just_audio/just_audio.dart';

class PackageCheck {
  const PackageCheck(this.name, this.purpose, this.sdkType);
  final String name;
  final String purpose;
  final Type sdkType;
}

// References are compiled, but no service instances/network/microphone are used.
final packageChecks = <PackageCheck>[
  PackageCheck('firebase_core', 'Firebase初期化', Firebase),
  PackageCheck('firebase_auth', '認証', FirebaseAuth),
  PackageCheck('firebase_ai', '感情分析候補', FirebaseAI),
  PackageCheck('firebase_app_check', '不正アクセス対策', FirebaseAppCheck),
  PackageCheck('speech_to_text', '短い音声入力', SpeechToText),
  PackageCheck('cloud_firestore', '構造化データ', FirebaseFirestore),
  PackageCheck('firebase_storage', '保存先候補・課金なしでは使用しない', FirebaseStorage),
  PackageCheck('just_audio', '音声再生', AudioPlayer),
];
