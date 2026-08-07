import 'package:flutter/material.dart';

class AppText extends StatelessWidget {
  const AppText(
    this.value, {
    super.key,
    this.fontSize = 14,
    this.fontWeight = FontWeight.w600,
    this.color = const Color(0xFF0E1A48),
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.height,
  });

  final String value;
  final double fontSize;
  final FontWeight fontWeight;
  final Color color;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height ?? 1.35,
      ),
    );
  }
}
