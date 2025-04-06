import 'package:flutter/material.dart';

/// 앱의 테마 관련 유틸리티 클래스
class AppThemes {
  // 텍스트 색상 가져오기
  static Color getTextColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.white : Colors.black87;
  }

  // 부제목/레이블 색상 가져오기
  static Color getSubtitleColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.grey[400]! : Colors.grey[600]!;
  }

  // 배경 색상 가져오기
  static Color getBackgroundColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Color(0xFF121212) : Colors.white;
  }

  // 카드 색상 가져오기
  static Color getCardColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Color(0xFF1E1E1E) : Colors.white;
  }

  // 구분선 색상 가져오기
  static Color getDividerColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.grey[800]! : Colors.grey[300]!;
  }
}
