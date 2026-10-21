import 'dart:math' as math;

import 'package:flutter/material.dart';

const homeAssetPath = 'assets/images/home/';
const homePaper = Color(0xFFFBF5EF);

TextStyle homeTextStyle(
  double size,
  Color color, {
  FontWeight weight = FontWeight.w400,
  double? height,
  String font = 'Zen Maru Gothic',
}) => TextStyle(
  fontFamily: font,
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: height,
);

/// Figma uses a 390 × 844 canvas. Keep that composition on desktop, scale
/// proportionally on narrower screens, and scroll when the keyboard is open.
class HomeDesignFrame extends StatelessWidget {
  const HomeDesignFrame({
    super.key,
    required this.background,
    required this.children,
    this.bottomAction,
  });

  final String background;
  final List<Widget> children;
  final Widget? bottomAction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(390.0, constraints.maxWidth);
        final scale = width / 390;
        final height = math.max(844.0, constraints.maxHeight / scale);
        return ColoredBox(
          color: homePaper,
          child: Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              child: SizedBox(
                width: width,
                height: height * scale,
                child: FittedBox(
                  fit: BoxFit.fill,
                  child: SizedBox(
                    width: 390,
                    height: height,
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Positioned.fill(
                          child: Image.asset(
                            '$homeAssetPath$background',
                            fit: BoxFit.fill,
                            excludeFromSemantics: true,
                          ),
                        ),
                        ...children,
                        if (bottomAction != null)
                          Positioned(
                            left: 20,
                            right: 20,
                            bottom: 30,
                            child: bottomAction!,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.displayName,
    required this.onSettings,
    this.loading = false,
  });

  final String? displayName;
  final VoidCallback? onSettings;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final name = displayName?.trim();
    final hasName = name != null && name.isNotEmpty;
    return Stack(
      children: [
        Positioned(
          left: 20,
          top: 58,
          width: 89.8,
          height: 38,
          child: Image.asset(
            '${homeAssetPath}yorisoi_logo.png',
            semanticLabel: 'Yorisoi',
          ),
        ),
        // Figma's exported shadow extends 16px left and 10px above the
        // 46px button. Keep its original PNG and a separate 46px hit target.
        Positioned(
          left: 308,
          top: 44,
          width: 78,
          height: 78,
          child: IgnorePointer(
            child: Opacity(
              opacity: loading ? 0.5 : 1,
              child: Image.asset(
                '${homeAssetPath}settings_button.png',
                excludeFromSemantics: true,
              ),
            ),
          ),
        ),
        Positioned(
          left: 324,
          top: 54,
          width: 46,
          height: 46,
          child: IconButton(
            key: const Key('home-settings'),
            tooltip: '設定',
            onPressed: onSettings,
            icon: const SizedBox.shrink(),
          ),
        ),
        Positioned(
          left: 20,
          top: 124,
          right: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasName ? 'こんばんは、$nameさん' : 'こんばんは',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: homeTextStyle(
                  15,
                  const Color(0xFF5F4A45),
                  weight: FontWeight.w700,
                  height: 22 / 15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                hasName ? 'Good evening, $name' : 'Good evening',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: homeTextStyle(
                  12,
                  const Color(0xFF7A635C),
                  height: 17 / 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
