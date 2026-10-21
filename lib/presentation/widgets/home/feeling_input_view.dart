import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'home_design_frame.dart';

class FeelingInputView extends StatelessWidget {
  const FeelingInputView({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.displayName,
    required this.onSubmit,
    required this.onMicrophone,
    required this.onSettings,
    required this.onChanged,
    this.error,
    this.canRetry = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String? displayName;
  final VoidCallback? onSubmit;
  final VoidCallback onMicrophone;
  final VoidCallback? onSettings;
  final ValueChanged<String> onChanged;
  final String? error;
  final bool canRetry;

  @override
  Widget build(BuildContext context) {
    return HomeDesignFrame(
      background: 'bg_home.png',
      bottomAction: _ShareButton(onPressed: onSubmit),
      children: [
        const Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, 0.4, 0.7],
                  colors: [
                    Color(0x8CFBF5EF),
                    Color(0x26FBF5EF),
                    Color(0x00FBF5EF),
                  ],
                ),
              ),
            ),
          ),
        ),
        HomeHeader(displayName: displayName, onSettings: onSettings),
        Positioned(
          left: 20,
          top: 170,
          width: 336,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '今日はどんな気分ですか？',
                  style: homeTextStyle(
                    28,
                    const Color(0xFF4E3B36),
                    weight: FontWeight.w900,
                    height: 41 / 28,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'How are you feeling today?',
                style: homeTextStyle(
                  14,
                  const Color(0xFF6B5550),
                  height: 20 / 14,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 26,
          top: 236.32,
          width: 150,
          child: Transform.rotate(
            angle: -6 * math.pi / 180,
            alignment: Alignment.topLeft,
            child: Text(
              '話してもいいよ。\n話さなくてもいいよ。',
              style: homeTextStyle(
                15,
                const Color(0xFFB86E74),
                height: 1.6,
                font: 'Yomogi',
              ),
            ),
          ),
        ),
        Positioned(
          left: 140,
          top: 217,
          width: 230,
          height: 135,
          child: Image.asset(
            '${homeAssetPath}pet_group.png',
            semanticLabel: '猫、犬、うさぎ、イルカ',
          ),
        ),
        Positioned(
          left: 20,
          top: 338,
          width: 350,
          height: 268,
          child: Container(
            key: const Key('feeling-input-card'),
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 14),
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
            child: Column(
              children: [
                SizedBox(
                  height: 170,
                  child: TextField(
                    key: const Key('feeling-input'),
                    controller: controller,
                    focusNode: focusNode,
                    onChanged: onChanged,
                    enabled: onSubmit != null,
                    expands: true,
                    minLines: null,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textAlignVertical: TextAlignVertical.top,
                    style: homeTextStyle(
                      16,
                      const Color(0xFF5F4A45),
                      height: 1.75,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isCollapsed: true,
                      contentPadding: EdgeInsets.zero,
                      hintText: '思っていることを、そのまま書いてみてね。\nWrite whatever is on your mind.',
                      hintStyle: homeTextStyle(
                        16,
                        const Color(0xFF9A8580),
                        height: 1.75,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 54,
                  child: Row(
                    children: [
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '声でも話せるよ · Or use your voice',
                          style: homeTextStyle(
                            12,
                            const Color(0xFF7A635C),
                            height: 17 / 12,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 54,
                        height: 54,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Original export includes the clipped left shadow
                            // from Figma's 54px Voice row (18px visual outset).
                            Positioned(
                              left: -18,
                              top: 0,
                              width: 72,
                              height: 54,
                              child: Image.asset(
                                '${homeAssetPath}mic_button.png',
                                excludeFromSemantics: true,
                              ),
                            ),
                            Positioned.fill(
                              child: IconButton(
                                key: const Key('home-microphone'),
                                tooltip: '音声入力（準備中）',
                                onPressed: onMicrophone,
                                icon: const SizedBox.shrink(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (error != null)
          Positioned(
            left: 24,
            right: 24,
            top: 618,
            child: Semantics(
              liveRegion: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    error!,
                    style: homeTextStyle(14, const Color(0xFF9A3544)),
                  ),
                  if (canRetry)
                    TextButton(onPressed: onSubmit, child: const Text('再試行')),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ShareButton extends StatelessWidget {
  const _ShareButton({required this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(29),
        gradient: const LinearGradient(
          colors: [Color(0xFFD97C84), Color(0xFFBF5D67)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x4DBF5C66),
            offset: Offset(0, 10),
            blurRadius: 24,
          ),
        ],
      ),
      child: SizedBox(
        height: 58,
        child: TextButton(
          key: const Key('share-feeling'),
          onPressed: onPressed,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            shape: const StadiumBorder(),
            foregroundColor: Colors.white,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '気持ちを伝える',
                style: homeTextStyle(
                  17,
                  Colors.white,
                  weight: FontWeight.w700,
                  height: 25 / 17,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '· Share',
                style: homeTextStyle(
                  13,
                  Colors.white,
                  weight: FontWeight.w500,
                  height: 19 / 13,
                ),
              ),
              const SizedBox(width: 8),
              Image.asset(
                '${homeAssetPath}share_heart.png',
                width: 18,
                height: 18,
                excludeFromSemantics: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
