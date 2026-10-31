import 'package:flutter/material.dart';

import '../../domain/emotions/emotion_analysis_result.dart';
import '../widgets/home/home_design_frame.dart';

/// Receives only validated categories; no raw response or emotional text.
/// A future recommendation route can accept this same typed result.
class EmotionAnalysisResultScreen extends StatelessWidget {
  const EmotionAnalysisResultScreen({
    super.key,
    required this.result,
    this.displayName,
  });

  final EmotionAnalysisResult result;
  final String? displayName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HomeDesignFrame(
        background: 'bg_home.png',
        bottomAction: DecoratedBox(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(29)),
            gradient: LinearGradient(
              colors: [Color(0xFFD97C84), Color(0xFFBF5D67)],
            ),
          ),
          child: SizedBox(
            width: double.infinity,
            height: 58,
            child: TextButton(
              key: const Key('emotion-result-back'),
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: Text(
                '入力に戻る',
                style: homeTextStyle(17, Colors.white, weight: FontWeight.w700),
              ),
            ),
          ),
        ),
        children: [
          HomeHeader(displayName: displayName, onSettings: null),
          Positioned.fill(
            top: 146 + MediaQuery.textScalerOf(context).scale(39),
            bottom: 110,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Image.asset(
                    '${homeAssetPath}pet_group.png',
                    width: 230,
                    height: 135,
                    semanticLabel: '猫、犬、うさぎ、イルカ',
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x24966E63),
                          offset: Offset(0, 16),
                          blurRadius: 40,
                        ),
                      ],
                    ),
                    child: Semantics(
                      liveRegion: true,
                      child: Column(
                        children: [
                          Text(
                            '今の気持ち',
                            style: homeTextStyle(22, const Color(0xFF4E3B36)),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            '主な気持ち',
                            style: homeTextStyle(14, const Color(0xFF6B5550)),
                          ),
                          Text(
                            result.main.japanese,
                            key: const Key('main-emotion'),
                            style: homeTextStyle(
                              30,
                              const Color(0xFFB13852),
                              weight: FontWeight.w700,
                            ),
                          ),
                          if (result.secondary != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              'もう一つの気持ち',
                              style: homeTextStyle(14, const Color(0xFF6B5550)),
                            ),
                            Text(
                              result.secondary!.japanese,
                              key: const Key('secondary-emotion'),
                              style: homeTextStyle(22, const Color(0xFF6B5550)),
                            ),
                          ],
                          const SizedBox(height: 20),
                          Text(
                            'AIによる推定であり、医療上の診断ではありません。',
                            textAlign: TextAlign.center,
                            style: homeTextStyle(14, const Color(0xFF6B5550)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'ペットルームのおすすめは準備中です。',
                    textAlign: TextAlign.center,
                    style: homeTextStyle(14, const Color(0xFF6B5550)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
