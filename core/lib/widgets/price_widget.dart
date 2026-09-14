// lib/core/widgets/price_widget.dart

import 'package:flutter/material.dart';

class PriceWidget extends StatelessWidget {
  final double price;
  final double fontSize;
  final Color color;
  final FontWeight fontWeight;
  final TextDecoration? decoration;

  const PriceWidget({
    super.key,
    required this.price,
    this.fontSize = 14,
    this.color = const Color(0xFFD32027),
    this.fontWeight = FontWeight.bold,
    this.decoration,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          price.toString(),
          style: TextStyle(
            fontSize: fontSize,
            color: color,
            fontWeight: fontWeight,
            fontFamily: 'Cairo',
            decoration: decoration,
          ),
        ),
        const SizedBox(width: 3),
        Image.asset(
          'assets/images/sar_symbol.png',
          height: fontSize,
          width: fontSize,
          color: color,
        ),
      ],
    );
  }
}
