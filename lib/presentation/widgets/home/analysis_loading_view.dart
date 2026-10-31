import 'package:flutter/material.dart';

import 'home_design_frame.dart';

/// Positions and assets were inspected separately in Figma frame 2:128 (03-A).
/// Shared by the live request flow and the explicit visual preview entrypoint.
class AnalysisLoadingView extends StatelessWidget {
  const AnalysisLoadingView({
    super.key,
    required this.message,
    required this.displayName,
    required this.onCancel,
    this.previewOnly = false,
  });

  final String message;
  final String? displayName;
  final VoidCallback onCancel;
  final bool previewOnly;

  @override
  Widget build(BuildContext context) {
    return HomeDesignFrame(
      background: 'bg_analysis_loading.png',
      bottomAction: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            previewOnly ? 'UIプレビュー：AI分析・おすすめ画面は未接続です。' : 'AIで気持ちを確認しています。',
            textAlign: TextAlign.center,
            style: homeTextStyle(12, const Color(0xFF6B5550)),
          ),
          TextButton(onPressed: onCancel, child: const Text('入力に戻る')),
        ],
      ),
      children: [
        HomeHeader(displayName: displayName, onSettings: null, loading: true),
        Positioned(
          left: 86,
          top: 182,
          width: 284,
          height: 44,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(22),
                topRight: Radius.circular(22),
                bottomLeft: Radius.circular(22),
                bottomRight: Radius.circular(6),
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x1F966E63),
                  offset: Offset(0, 8),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Text(
              message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: homeTextStyle(
                14,
                const Color(0xFF5F4A45),
                height: 20 / 14,
              ),
            ),
          ),
        ),
        Positioned(
          left: 45,
          top: 250,
          width: 300,
          height: 200,
          child: Image.asset(
            '${homeAssetPath}loading_glow.png',
            excludeFromSemantics: true,
          ),
        ),
        Positioned(
          left: 45,
          top: 262,
          width: 300,
          height: 176,
          child: Image.asset(
            '${homeAssetPath}loading_pet_group.png',
            semanticLabel: '猫、犬、うさぎ、イルカが待っています',
          ),
        ),
        Positioned(
          left: 130,
          top: 470,
          width: 130,
          height: 22,
          child: Image.asset(
            '${homeAssetPath}loading_paw_trail.png',
            excludeFromSemantics: true,
          ),
        ),
        Positioned(
          left: 77,
          top: 512,
          width: 300,
          child: Semantics(
            liveRegion: true,
            child: Column(
              children: [
                Text(
                  '気持ちを確認しています...',
                  maxLines: 1,
                  style: homeTextStyle(
                    20,
                    const Color(0xFF4E3B36),
                    weight: FontWeight.w900,
                    height: 29 / 20,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Taking a moment with your feelings…',
                  maxLines: 1,
                  style: homeTextStyle(
                    13,
                    const Color(0xFF6B5550),
                    height: 19 / 13,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'ちょっとだけ、待っててね ♡',
                  style: homeTextStyle(
                    15,
                    const Color(0xFFB86E74),
                    height: 22 / 15,
                    font: 'Yomogi',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
