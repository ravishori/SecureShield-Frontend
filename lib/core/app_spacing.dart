import 'package:flutter/material.dart';

/// Consistent spacing system based on 4px grid.
/// Use these instead of magic numbers throughout the app.
class Sp {
  Sp._();
  static const double xs   = 4;
  static const double sm   = 8;
  static const double md   = 12;
  static const double lg   = 16;
  static const double xl   = 20;
  static const double xxl  = 24;
  static const double xxxl = 32;
  static const double huge = 48;

  // Common vertical/horizontal gap widgets
  static const Widget gapXs   = SizedBox(height: xs);
  static const Widget gapSm   = SizedBox(height: sm);
  static const Widget gapMd   = SizedBox(height: md);
  static const Widget gapLg   = SizedBox(height: lg);
  static const Widget gapXl   = SizedBox(height: xl);
  static const Widget gapXxl  = SizedBox(height: xxl);
  static const Widget gapXxxl = SizedBox(height: xxxl);

  static const Widget hGapXs  = SizedBox(width: xs);
  static const Widget hGapSm  = SizedBox(width: sm);
  static const Widget hGapMd  = SizedBox(width: md);
  static const Widget hGapLg  = SizedBox(width: lg);
  static const Widget hGapXl  = SizedBox(width: xl);
}

/// Border radius constants
class Radii {
  Radii._();
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double full = 999;

  static BorderRadius get smAll  => BorderRadius.circular(sm);
  static BorderRadius get mdAll  => BorderRadius.circular(md);
  static BorderRadius get lgAll  => BorderRadius.circular(lg);
  static BorderRadius get xlAll  => BorderRadius.circular(xl);
  static BorderRadius get card   => BorderRadius.circular(14);
}
