import 'package:yorisoi/domain/emotions/emotion_analysis_result.dart';
import 'package:yorisoi/services/emotion/emotion_analysis_service.dart';

class FakeEmotionAnalyzer implements EmotionAnalyzer {
  FakeEmotionAnalyzer(this.answer);

  final Future<EmotionAnalysisResult> Function(String text) answer;
  final List<String> inputs = [];

  @override
  Future<EmotionAnalysisResult> analyze(String input) {
    inputs.add(input);
    return answer(input);
  }
}
