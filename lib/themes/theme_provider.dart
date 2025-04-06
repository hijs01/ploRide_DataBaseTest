import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 앱의 테마 상태를 관리하는 Provider 클래스
class ThemeProvider extends ChangeNotifier {
  // 테마 모드 저장 키
  static const THEME_KEY = 'theme_mode';

  // 다크 모드 상태
  bool _isDarkMode = false;

  // 다크 모드 여부
  bool get isDarkMode => _isDarkMode;

  // 현재 테마 가져오기
  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  // 생성자 - 초기화 진행
  ThemeProvider() {
    _loadThemeFromPrefs();
  }

  // Shared Preferences에서 테마 설정 불러오기
  void _loadThemeFromPrefs() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool(THEME_KEY) ?? false;
      notifyListeners();
    } catch (e) {
      print('테마 설정 로드 오류: $e');
    }
  }

  // 테마 전환 함수
  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    _saveThemeToPrefs();
    notifyListeners();
  }

  // Shared Preferences에 테마 설정 저장
  void _saveThemeToPrefs() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.setBool(THEME_KEY, _isDarkMode);
    } catch (e) {
      print('테마 설정 저장 오류: $e');
    }
  }
}
