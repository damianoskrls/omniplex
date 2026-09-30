import 'package:flutter/material.dart';

/// OmniPlex brand fill.
/// linear-gradient(194.63deg, #4452D8 16.11%, #4B50D3 24.62%, #5D49C5 36.55%,
/// #7B3EAD 50.51%, #A4308D 65.88%, #C52473 76.51%)
const kBrandGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  transform: GradientRotation(3.396),
  colors: [
    Color(0xFF4452D8),
    Color(0xFF4B50D3),
    Color(0xFF5D49C5),
    Color(0xFF7B3EAD),
    Color(0xFFA4308D),
    Color(0xFFC52473),
  ],
  stops: [0.1611, 0.2462, 0.3655, 0.5051, 0.6588, 0.7651],
);

const kBrandShadow = Color(0xFF7B3EAD);
