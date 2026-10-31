import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const authAssetPath = 'assets/images/auth/';
const authInk = Color(0xFF4E3B36);
const authMuted = Color(0xFF7A635C);
const authPink = Color(0xFFBF5D67);

TextStyle authText(
  double size, {
  Color color = authInk,
  FontWeight weight = FontWeight.w400,
  double height = 1.45,
  String font = 'Zen Maru Gothic',
  double? letterSpacing,
}) => TextStyle(
  fontFamily: font,
  fontSize: size,
  color: color,
  fontWeight: weight,
  height: height,
  letterSpacing: letterSpacing,
);

Widget authImage(String name, {String? label}) => Image.asset(
  '$authAssetPath$name',
  fit: BoxFit.cover,
  semanticLabel: label,
  excludeFromSemantics: label == null,
);

Widget authIcon(String name, double size, {double? height}) => SvgPicture.asset(
  '$authAssetPath$name',
  width: size,
  height: height ?? size,
  excludeFromSemantics: true,
);

/// Original 390x844 Figma composition. Cards grow for validation errors and
/// larger text; the whole page scrolls above the keyboard instead of clipping.
class AuthDesignPage extends StatelessWidget {
  const AuthDesignPage({
    super.key,
    required this.cardTop,
    required this.child,
    this.header = const [],
    this.background = 'bg_auth.png',
    this.cardPaddingTop = 26,
    this.overlays = const [],
  });
  final double cardTop;
  final double cardPaddingTop;
  final Widget child;
  final String background;
  final List<Widget> header;
  final List<Widget> overlays;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFFBF5EF),
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: SingleChildScrollView(
            key: const Key('auth-page-scroll'),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    '$authAssetPath$background',
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                  ),
                ),
                const Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0, .4, .7],
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
                ...header,
                Padding(
                  padding: EdgeInsets.fromLTRB(14, cardTop, 14, 20),
                  child: Container(
                    key: const Key('auth-form-card'),
                    constraints: BoxConstraints(minHeight: 824 - cardTop),
                    padding: EdgeInsets.fromLTRB(22, cardPaddingTop, 22, 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(34),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x24966E63),
                          offset: Offset(0, 16),
                          blurRadius: 40,
                        ),
                      ],
                    ),
                    child: IntrinsicHeight(child: child),
                  ),
                ),
                ...overlays,
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class AuthLogo extends StatelessWidget {
  const AuthLogo({super.key, this.registration = false});
  final bool registration;
  @override
  Widget build(BuildContext context) {
    final wordWidth = registration ? 151.0 : 177.7;
    final wordHeight = registration ? 64.0 : 75.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: wordWidth,
          height: wordHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Text(
                'Yorisoi',
                style: authText(
                  registration ? 44 : 52,
                  color: const Color(0xFF5A4038),
                  weight: FontWeight.w900,
                ),
              ),
              Positioned(
                left: registration ? 130 : 153.55,
                top: registration ? -4 : -4.6,
                child: authIcon(
                  registration ? 'heart_registration.svg' : 'heart_login.svg',
                  registration ? 20 : 23,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: registration ? 2 : 6),
        Text(
          'こころに、そっとよりそう',
          maxLines: 1,
          style: authText(
            registration ? 13 : 14,
            color: const Color(0xFF5F4A45),
            weight: FontWeight.w500,
            letterSpacing: registration ? 2.86 : 3.08,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Always here for you.',
          style: authText(11, color: authMuted, letterSpacing: 1.54),
        ),
        if (!registration) ...[
          const SizedBox(height: 12),
          Transform.rotate(
            angle: -3 * math.pi / 180,
            child: Text(
              'おかえり、待ってたよ ♡',
              style: authText(
                15,
                color: const Color(0xFFC27A7F),
                font: 'Yomogi',
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class AuthTitle extends StatelessWidget {
  const AuthTitle(
    this.japanese,
    this.english, {
    super.key,
    this.center = false,
    this.size = 22,
  });
  final String japanese;
  final String english;
  final bool center;
  final double size;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: center
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start,
    children: [
      Text(
        japanese,
        style: authText(size, weight: FontWeight.w900),
        textAlign: center ? TextAlign.center : TextAlign.start,
      ),
      const SizedBox(height: 2),
      Text(english, style: authText(12, color: authMuted)),
    ],
  );
}

class AuthField extends StatelessWidget {
  const AuthField({
    super.key,
    this.fieldKey,
    required this.label,
    required this.english,
    required this.hint,
    this.icon = 'lock.svg',
    this.controller,
    this.validator,
    this.enabled = true,
    this.obscure = false,
    this.onChanged,
    this.keyboardType,
  });
  final Key? fieldKey;
  final String label, english, hint, icon;
  final TextEditingController? controller;
  final FormFieldValidator<String>? validator;
  final bool enabled, obscure;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: label,
              style: authText(
                12,
                color: const Color(0xFF5F4A45),
                weight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: ' · $english',
              style: authText(12, color: authMuted, weight: FontWeight.w500),
            ),
          ],
        ),
      ),
      const SizedBox(height: 5),
      Semantics(
        label: label,
        child: TextFormField(
          key: fieldKey,
          controller: controller,
          validator: validator,
          enabled: enabled,
          obscureText: obscure,
          onChanged: onChanged,
          keyboardType: keyboardType,
          autocorrect: false,
          enableSuggestions: !obscure,
          style: authText(15),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: const Color(0xFFFDF9F6),
            hintText: hint,
            hintStyle: authText(15, color: const Color(0xFF9A8580)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 43.5,
              minHeight: 48,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13),
              child: authIcon(icon, 18),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(
                color: Color(0xFFF1E6DF),
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(
                color: Color(0xFFF1E6DF),
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: authPink, width: 1.5),
            ),
            errorMaxLines: 3,
            errorStyle: authText(12, color: const Color(0xFF9A3544)),
          ),
        ),
      ),
    ],
  );
}

class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.japanese,
    required this.english,
    required this.onPressed,
    this.busy = false,
    this.busyLabel = '処理中...',
  });
  final String japanese, english, busyLabel;
  final VoidCallback? onPressed;
  final bool busy;
  @override
  Widget build(BuildContext context) => Container(
    height: 56,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      gradient: const LinearGradient(colors: [Color(0xFFD97C84), authPink]),
      boxShadow: const [
        BoxShadow(
          color: Color(0x4DBF5C66),
          offset: Offset(0, 10),
          blurRadius: 24,
        ),
      ],
    ),
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        disabledBackgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        foregroundColor: Colors.white,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy) ...[
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              busy ? busyLabel : japanese,
              style: authText(17, color: Colors.white, weight: FontWeight.w700),
            ),
            if (!busy) ...[
              const SizedBox(width: 8),
              Text(
                '· $english',
                style: authText(
                  13,
                  color: Colors.white,
                  weight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class AuthLink extends StatelessWidget {
  const AuthLink(this.text, {super.key, required this.onPressed, this.prefix});
  final String text;
  final String? prefix;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      foregroundColor: authPink,
      minimumSize: const Size(0, 19),
      padding: EdgeInsets.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: authText(13, color: authPink, weight: FontWeight.w700),
    ),
    child: Text.rich(
      TextSpan(
        children: [
          if (prefix != null)
            TextSpan(
              text: prefix,
              style: authText(13, color: const Color(0xFF6B5550)),
            ),
          TextSpan(
            text: text,
            style: authText(13, color: authPink, weight: FontWeight.w700),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    ),
  );
}

class RecoveryHeader extends StatelessWidget {
  const RecoveryHeader({super.key, required this.step, required this.onBack});
  final int step;
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned(
        left: 18,
        top: 54,
        width: 46,
        height: 46,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x24966E63),
                offset: Offset(0, 6),
                blurRadius: 16,
              ),
            ],
          ),
          child: IconButton(
            onPressed: onBack,
            tooltip: 'ログインに戻る',
            icon: authIcon('back.svg', 21),
          ),
        ),
      ),
      Positioned(
        right: 18,
        top: 61,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .8),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              for (var i = 1; i <= 3; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: authIcon(
                    i <= step ? 'paw_active.svg' : 'paw_idle.svg',
                    14,
                  ),
                ),
              Text(
                '$step / 3',
                style: authText(11, color: authMuted, weight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
