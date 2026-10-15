import 'package:firebase_ai/firebase_ai.dart';

const emotionCodes = {
  'sad',
  'lonely',
  'anxious',
  'stressed',
  'angry',
  'happy',
  'calm',
  'other',
};

String validateEmotion(String? text) {
  final value = text?.trim().toLowerCase();
  if (!emotionCodes.contains(value)) {
    throw const FormatException('Missing or invalid emotion code');
  }
  return value!;
}

Future<String> testYorisoiEmotion() async {
  final model = FirebaseAI.googleAI().generativeModel(
    model: 'gemini-3.5-flash-lite',
  );

  const prompt = '''
次の文章の感情を分類してください。

使用できる感情コード：
sad, lonely, anxious, stressed, angry, happy, calm, other

ルール：
- 最も近い感情を1つ選んでください。
- 感情コードだけを出力してください。
- 説明は不要です。

文章：「今日は友達と会えなくて、とても寂しいです。」
''';

  final response = await model
      .generateContent([Content.text(prompt)])
      .timeout(const Duration(seconds: 30));

  return validateEmotion(response.text);
}
