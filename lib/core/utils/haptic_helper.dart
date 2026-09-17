import 'package:flutter/services.dart';

/// Feedback háptico sutil para interacciones clave.
class HapticHelper {
  HapticHelper._();

  static void light() => HapticFeedback.lightImpact();
  static void medium() => HapticFeedback.mediumImpact();
  static void selection() => HapticFeedback.selectionClick();
}