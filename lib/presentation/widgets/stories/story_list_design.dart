import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../domain/stories/story_draft.dart';

const storyAssetPath = 'assets/images/story_list/';
const storyPaper = Color(0xFFFBF5EF);
const storyInk = Color(0xFF4E3B36);
const storyBody = Color(0xFF5F4A45);
const storyMuted = Color(0xFF7A635C);
const storyPink = Color(0xFFBF5D67);

TextStyle storyText(
  double size, {
  Color color = storyInk,
  FontWeight weight = FontWeight.w400,
  double height = 1.5,
}) => TextStyle(
  fontFamily: 'Zen Maru Gothic',
  fontSize: size,
  fontWeight: weight,
  height: height,
  color: color,
);

Widget storyIcon(String name, double size, {Color? color}) => SvgPicture.asset(
  '$storyAssetPath$name.svg',
  width: size,
  height: size,
  excludeFromSemantics: true,
  colorFilter: color == null ? null : ColorFilter.mode(color, BlendMode.srcIn),
);

/// Original 109:25/125/225/325 frames. Geometry is in Figma logical pixels.
/// Variant tints were checked against the original reference PNGs.
class StoryPetDesign {
  const StoryPetDesign({
    required this.pet,
    required this.chip,
    required this.heading,
    required this.english,
    required this.message,
    required this.messageEnglish,
    required this.petBounds,
    required this.chipColor,
    required this.tileColor,
    required this.pawColor,
  });

  final StoryPet pet;
  final String chip;
  final String heading;
  final String english;
  final String message;
  final String messageEnglish;
  final Rect petBounds;
  final Color chipColor;
  final Color tileColor;
  final Color pawColor;

  String get background {
    final extension = pet == StoryPet.cat ? 'jpg' : 'png';
    return '${storyAssetPath}bg_${pet.name}.$extension';
  }

  String get artwork => '${storyAssetPath}pet_${pet.name}.png';

  static StoryPetDesign forPet(StoryPet pet) => switch (pet) {
    StoryPet.cat => const StoryPetDesign(
      pet: StoryPet.cat,
      chip: 'ねこのラジオ · Cat',
      heading: 'さみしい夜も、\nとなりにいるよ',
      english: 'I’m right here with you.',
      message: '今日は少しさみしい気持ちなんだね。ねこと一緒に、ゆっくり聴こう。',
      messageEnglish:
          'Feeling a little lonely today. Let’s listen together, slowly.',
      petBounds: Rect.fromLTWH(41, 100, 114, 150),
      chipColor: Color(0xFFA24C56),
      tileColor: Color(0xFFFBE1E1),
      pawColor: Color(0xFFE8949A),
    ),
    StoryPet.rabbit => const StoryPetDesign(
      pet: StoryPet.rabbit,
      chip: 'うさぎのラジオ · Rabbit',
      heading: 'ゆっくりで、\nだいじょうぶ',
      english: 'Take it slow — you’re okay.',
      message: '心がそわそわしているみたい。うさぎと一緒に、深呼吸しよう。',
      messageEnglish: 'Your heart feels restless. Let’s breathe together.',
      petBounds: Rect.fromLTWH(52, 90, 92, 160),
      chipColor: Color(0xFFA8506A),
      tileColor: Color(0xFFFBE4EA),
      pawColor: Color(0xFFE39BB0),
    ),
    StoryPet.dog => const StoryPetDesign(
      pet: StoryPet.dog,
      chip: 'いぬのラジオ · Dog',
      heading: 'きみの気持ち、\nぜんぶ聞かせて',
      english: 'Tell me everything.',
      message: '強い気持ちがあふれているね。いぬと一緒に、ひと息つこう。',
      messageEnglish: 'Big feelings today. Let’s take a breath together.',
      petBounds: Rect.fromLTWH(33, 100, 130, 150),
      chipColor: Color(0xFF8A5A2B),
      tileColor: Color(0xFFFBE8D3),
      pawColor: Color(0xFFD9A46F),
    ),
    StoryPet.dolphin => const StoryPetDesign(
      pet: StoryPet.dolphin,
      chip: 'イルカのラジオ · Dolphin',
      heading: 'おだやかな波に、\nゆられよう',
      english: 'Let the calm waves carry you.',
      message: '今の気持ちを、そのまま大切にしよう。イルカと海のおはなしへ。',
      messageEnglish: 'Let’s keep this feeling close. Off to the sea together.',
      petBounds: Rect.fromLTWH(53, 94, 90, 156),
      chipColor: Color(0xFF3F5F94),
      tileColor: Color(0xFFE1ECFA),
      pawColor: Color(0xFF7E9BCB),
    ),
  };
}

class StoryGradientButton extends StatelessWidget {
  const StoryGradientButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.height = 36,
    this.semanticLabel,
    this.buttonKey,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final double height;
  final String? semanticLabel;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height / 2),
        gradient: const LinearGradient(colors: [Color(0xFFD97C84), storyPink]),
        boxShadow: const [
          BoxShadow(
            color: Color(0x47BF5D67),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: TextButton(
        key: buttonKey,
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          minimumSize: Size(0, height),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: const StadiumBorder(),
        ),
        child: child,
      ),
    ),
  );
}
