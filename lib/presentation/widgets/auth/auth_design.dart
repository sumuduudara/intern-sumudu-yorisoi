import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const authAssets = 'assets/images/auth/';
const authInk = Color(0xFF5F4A45);
const authMuted = Color(0xFF7A635C);
const authPink = Color(0xFFBF5D67);

TextStyle authText(
  double size, {
  Color color = authInk,
  FontWeight weight = FontWeight.w400,
  double? height,
}) => TextStyle(
  fontFamily: 'Zen Maru Gothic',
  fontSize: size,
  color: color,
  fontWeight: weight,
  height: height ?? 1.45,
);

/// Auth-only composition. The product's global Material theme is untouched.
/// At 390 x 844, hero and card origins match Figma; forms grow when necessary.
class AuthDesignFrame extends StatelessWidget {
  const AuthDesignFrame({super.key, required this.signUp, required this.child});
  final bool signUp;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFFBF5EF),
    body: LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(390.0, constraints.maxWidth);
        final scale = width / 390;
        final safeTop = MediaQuery.paddingOf(context).top;
        final safeBottom = MediaQuery.paddingOf(context).bottom;
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: width,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: math.max(
                    844 * scale + safeTop + safeBottom,
                    constraints.maxHeight,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.asset(
                        '${authAssets}bg_${signUp ? 'signup' : 'login'}.jpg',
                        fit: BoxFit.cover,
                        excludeFromSemantics: true,
                      ),
                    ),
                    const Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x8CFBF5EF),
                              Color(0x26FBF5EF),
                              Color(0x00FBF5EF),
                            ],
                            stops: [0, 0.4, 0.7],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: safeTop + (signUp ? 58 : 84) * scale,
                      left: (signUp ? 101 : 94) * scale,
                      child: SizedBox(
                        width: (signUp ? 188 : 202) * scale,
                        height: (signUp ? 103 : 156.0763) * scale,
                        child: FittedBox(child: AuthBrand(signUp: signUp)),
                      ),
                    ),
                    Positioned(
                      top: safeTop + (signUp ? 172 : 262) * scale,
                      left: (signUp ? 57 : 45) * scale,
                      child: Image.asset(
                        '${authAssets}pets_group.png',
                        width: (signUp ? 276 : 300) * scale,
                        height: (signUp ? 162 : 176) * scale,
                        fit: BoxFit.contain,
                        semanticLabel: '猫、犬、うさぎ、イルカ',
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        14 * scale,
                        safeTop + (signUp ? 286 : 384) * scale,
                        14 * scale,
                        20 * scale + safeBottom,
                      ),
                      child: Container(
                        key: const Key('auth-form-card'),
                        constraints: BoxConstraints(
                          minHeight: signUp ? 538 : 440,
                        ),
                        padding: EdgeInsets.fromLTRB(
                          22,
                          signUp ? 24 : 26,
                          22,
                          20,
                        ),
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
                        child: child,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// Figma wordmark/taglines use bundled fonts, not an opaque screenshot patch.
class AuthBrand extends StatelessWidget {
  const AuthBrand({super.key, required this.signUp});
  final bool signUp;
  @override
  Widget build(BuildContext context) => Semantics(
    label: signUp
        ? 'Yorisoi。こころに、そっとよりそう。Always here for you.'
        : 'Yorisoi。こころに、そっとよりそう。おかえり、待ってたよ。',
    child: ExcludeSemantics(
      child: MediaQuery.withNoTextScaling(
        child: SizedBox(
          key: const Key('auth-brand'),
          width: signUp ? 188 : 202,
          height: signUp ? 103 : 156.0763,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                left: signUp ? 18.5 : 12.15,
                top: 0,
                child: Text(
                  'Yorisoi',
                  style: authText(
                    signUp ? 44 : 52,
                    color: const Color(0xFF5A4038),
                    weight: FontWeight.w900,
                    height: signUp ? 64 / 44 : 75 / 52,
                  ),
                ),
              ),
              Positioned(
                left: signUp ? 148.5 : 165.7,
                top: signUp ? -4 : -4.6,
                child: SvgPicture.asset(
                  '${authAssets}heart_${signUp ? 'signup' : 'login'}.svg',
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: signUp ? 66 : 81,
                child: Text(
                  'こころに、そっとよりそう',
                  textAlign: TextAlign.center,
                  softWrap: false,
                  style: authText(
                    signUp ? 13 : 14,
                    weight: FontWeight.w500,
                    height: signUp ? 19 / 13 : 20 / 14,
                  ).copyWith(letterSpacing: signUp ? 2.86 : 3.08),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: signUp ? 87 : 103,
                child: Text(
                  'Always here for you.',
                  textAlign: TextAlign.center,
                  style: authText(
                    11,
                    color: authMuted,
                    height: 16 / 11,
                  ).copyWith(letterSpacing: 1.54),
                ),
              ),
              if (!signUp)
                Positioned(
                  left: 13.54,
                  top: 134.1,
                  child: Transform.rotate(
                    angle: -3 * math.pi / 180,
                    alignment: Alignment.topLeft,
                    child: const Text(
                      'おかえり、待ってたよ ♡',
                      style: TextStyle(
                        fontFamily: 'Yomogi',
                        fontSize: 15,
                        height: 22 / 15,
                        color: Color(0xFFC27A7F),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class AuthHeading extends StatelessWidget {
  const AuthHeading({super.key, required this.signUp});
  final bool signUp;
  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.end,
    runSpacing: 8,
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            signUp ? 'はじめまして' : 'おかえりなさい',
            style: authText(
              23,
              color: const Color(0xFF4E3B36),
              weight: FontWeight.w900,
              height: 33 / 23,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            signUp ? 'Create your account' : 'Welcome back',
            style: authText(12, color: authMuted, height: 17 / 12),
          ),
        ],
      ),
      if (signUp)
        Padding(
          padding: const EdgeInsets.only(right: 2, bottom: 2),
          child: Transform.rotate(
            angle: -5 * math.pi / 180,
            child: const Text(
              'よろしくね ♡',
              style: TextStyle(
                fontFamily: 'Yomogi',
                fontSize: 14,
                color: Color(0xFFC27A7F),
              ),
            ),
          ),
        ),
    ],
  );
}

class AuthField extends StatelessWidget {
  const AuthField({
    super.key,
    required this.fieldKey,
    required this.label,
    required this.english,
    required this.hint,
    required this.icon,
    required this.enabled,
    this.controller,
    this.validator,
    this.obscure = false,
    this.email = false,
    this.autofillHints,
  });
  final Key fieldKey;
  final String label, english, hint, icon;
  final bool enabled, obscure, email;
  final TextEditingController? controller;
  final FormFieldValidator<String>? validator;
  final Iterable<String>? autofillHints;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(
              text: ' · $english',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: authMuted,
              ),
            ),
          ],
        ),
        style: authText(12, height: 17 / 12),
      ),
      const SizedBox(height: 5),
      TextFormField(
        key: fieldKey,
        controller: controller,
        enabled: enabled,
        obscureText: obscure,
        cursorColor: authPink,
        keyboardType: email ? TextInputType.emailAddress : TextInputType.text,
        autocorrect: false,
        enableSuggestions: !obscure,
        autofillHints: autofillHints,
        style: authText(15, height: 22 / 15),
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: authText(
            15,
            color: const Color(0xFF9A8580),
            height: 22 / 15,
          ),
          filled: true,
          fillColor: const Color(0xFFFDF9F6),
          isDense: true,
          contentPadding: const EdgeInsets.fromLTRB(14, 13, 16, 13),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 14, right: 10),
            child: SvgPicture.asset(
              '$authAssets$icon.svg',
              excludeFromSemantics: true,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 42,
            maxWidth: 42,
          ),
          border: _border(const Color(0xFFF1E6DF)),
          enabledBorder: _border(const Color(0xFFF1E6DF)),
          disabledBorder: _border(const Color(0xFFF1E6DF)),
          focusedBorder: _border(authPink),
          errorBorder: _border(authPink),
          focusedErrorBorder: _border(authPink),
          errorStyle: authText(12, color: authPink),
          errorMaxLines: 4,
        ),
      ),
    ],
  );

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(18),
    borderSide: BorderSide(color: color, width: 1.5),
  );
}

class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.english,
    required this.busyLabel,
    required this.busy,
    required this.onPressed,
  });
  final String label, english, busyLabel;
  final bool busy;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Container(
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
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: ElevatedButton(
        key: const Key('auth-submit'),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 56),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 2,
          children: [
            if (busy)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            Text(
              busy ? busyLabel : label,
              style: authText(
                17,
                color: Colors.white,
                weight: FontWeight.w700,
                height: 25 / 17,
              ),
            ),
            if (!busy && english.isNotEmpty)
              Text(
                '· $english',
                style: authText(
                  13,
                  color: Colors.white,
                  weight: FontWeight.w500,
                  height: 19 / 13,
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class AuthSwitchLink extends StatelessWidget {
  const AuthSwitchLink({
    super.key,
    required this.signUp,
    required this.onPressed,
  });
  final bool signUp;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => TextButton(
    key: const Key('auth-switch'),
    onPressed: onPressed,
    style: TextButton.styleFrom(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: signUp
                ? 'アカウントをお持ちの方 · Have an account? '
                : 'はじめての方 · New here? ',
          ),
          TextSpan(
            text: signUp ? 'ログイン' : '新規登録 · Sign up',
            style: const TextStyle(
              color: authPink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      style: authText(13, color: const Color(0xFF6B5550), height: 19 / 13),
    ),
  );
}
