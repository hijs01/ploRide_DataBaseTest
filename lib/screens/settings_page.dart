import 'package:flutter/material.dart';
import 'package:cabrider/screens/mainpage.dart';
import 'package:cabrider/screens/homepage.dart';
import 'package:cabrider/screens/chat_page.dart';
import 'package:flutter/cupertino.dart';

class SettingsPage extends StatefulWidget {
  static const String id = 'settings';
  final bool useScaffold; // Scaffold 사용 여부를 결정하는 파라미터

  const SettingsPage({Key? key, this.useScaffold = true}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool notificationsEnabled = true;
  bool darkModeEnabled = false;
  bool locationServiceEnabled = true;
  bool promotionsEnabled = true;
  int _selectedIndex = 3; // 현재 Profile 탭이 선택됨
  String selectedLanguage = '한국어';

  // 언어 옵션
  final List<String> languages = ['English', '한국어', '中文', '日本語', 'Español'];

  void _onItemTapped(int index) {
    setState(() {
      if (index != _selectedIndex) {
        if (index == 0 || index == 1) {
          // Home 또는 History 탭으로 이동
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder:
                  (context, animation, secondaryAnimation) => HomePage(),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ),
          );
        } else if (index == 2) {
          // Chat 탭으로 이동
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder:
                  (context, animation, secondaryAnimation) => ChatPage(),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ),
          );
        }
        _selectedIndex = index;
      }
    });
  }

  void _showLanguageModal() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Container(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Text(
                    '언어 선택',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Divider(),
                ...languages
                    .map(
                      (language) => ListTile(
                        title: Text(language),
                        trailing:
                            language == selectedLanguage
                                ? Icon(
                                  Icons.check,
                                  color: Theme.of(context).primaryColor,
                                )
                                : null,
                        onTap: () {
                          setState(() {
                            selectedLanguage = language;
                          });
                          Navigator.pop(context);
                        },
                      ),
                    )
                    .toList(),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark ||
        darkModeEnabled;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final backgroundColor = isDarkMode ? Color(0xFF121212) : Colors.white;
    final cardColor = isDarkMode ? Color(0xFF1E1E1E) : Colors.white;
    final shadowColor = isDarkMode ? Colors.transparent : Colors.black12;

    // 앱의 주요 색상 테마 - 앱 전체에서 사용되는 값과 일치하도록 수정
    final primaryColor = Color(0xFF3F51B5); // 원래 인디고 색상으로 되돌림
    final accentColor = Color(0xFF3F51B5); // 원래 인디고 색상으로 되돌림

    // 설정 페이지의 내용
    Widget content = Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: backgroundColor,
        title: Text(
          '설정',
          style: TextStyle(
            color: textColor,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        automaticallyImplyLeading: false, // 뒤로가기 버튼 제거
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: 16),
        children: [
          // 프로필 섹션 - 상단에 특별히 강조
          Container(
            margin: EdgeInsets.symmetric(vertical: 16),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [primaryColor, accentColor],
              ),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 50, color: primaryColor),
                ),
                SizedBox(height: 12),
                Text(
                  '국제 학생',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'student@university.edu',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () {},
                  child: Text('프로필 편집', style: TextStyle(color: Colors.white)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 국제 학생 특화 섹션
          _buildSectionCard(
            title: '국제 학생 서비스',
            icon: Icons.school,
            isDarkMode: isDarkMode,
            backgroundColor: cardColor,
            shadowColor: shadowColor,
            children: [
              _buildSettingItem(
                icon: Icons.language,
                title: '언어 설정',
                subtitle: '현재: $selectedLanguage',
                isDarkMode: isDarkMode,
                onTap: _showLanguageModal,
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: isDarkMode ? Colors.grey : Colors.grey[600],
                ),
              ),
              _buildSettingItem(
                icon: Icons.translate,
                title: '실시간 번역',
                subtitle: '택시 운전사와의 대화를 실시간으로 번역합니다',
                isDarkMode: isDarkMode,
                onTap: () {},
                trailing: Switch(
                  value: true,
                  onChanged: (value) {},
                  activeColor: primaryColor,
                ),
              ),
              _buildSettingItem(
                icon: Icons.school,
                title: '학생 할인',
                subtitle: '학생 신분증을 등록하여 할인을 받으세요',
                isDarkMode: isDarkMode,
                onTap: () {},
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: isDarkMode ? Colors.grey : Colors.grey[600],
                ),
              ),
            ],
          ),

          // 앱 설정 섹션
          _buildSectionCard(
            title: '앱 설정',
            icon: Icons.settings,
            isDarkMode: isDarkMode,
            backgroundColor: cardColor,
            shadowColor: shadowColor,
            children: [
              _buildSwitchItem(
                icon: Icons.notifications,
                title: '알림',
                subtitle: '푸시 알림을 켜거나 끕니다',
                value: notificationsEnabled,
                onChanged: (value) {
                  setState(() {
                    notificationsEnabled = value;
                  });
                },
                isDarkMode: isDarkMode,
                primaryColor: primaryColor,
              ),
              _buildSwitchItem(
                icon: Icons.dark_mode,
                title: '다크 모드',
                subtitle: '앱의 어두운 테마를 활성화합니다',
                value: darkModeEnabled,
                onChanged: (value) {
                  setState(() {
                    darkModeEnabled = value;
                  });
                },
                isDarkMode: isDarkMode,
                primaryColor: primaryColor,
              ),
              _buildSwitchItem(
                icon: Icons.location_on,
                title: '위치 서비스',
                subtitle: '앱의 위치 서비스를 활성화합니다',
                value: locationServiceEnabled,
                onChanged: (value) {
                  setState(() {
                    locationServiceEnabled = value;
                  });
                },
                isDarkMode: isDarkMode,
                primaryColor: primaryColor,
              ),
            ],
          ),

          // 결제 섹션
          _buildSectionCard(
            title: '결제',
            icon: Icons.payment,
            isDarkMode: isDarkMode,
            backgroundColor: cardColor,
            shadowColor: shadowColor,
            children: [
              _buildSettingItem(
                icon: Icons.credit_card,
                title: '결제 방법',
                subtitle: '신용카드 및 다른 결제 방법을 관리합니다',
                isDarkMode: isDarkMode,
                onTap: () {},
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: isDarkMode ? Colors.grey : Colors.grey[600],
                ),
              ),
              _buildSettingItem(
                icon: Icons.receipt_long,
                title: '영수증',
                subtitle: '이전 라이드의 영수증을 확인합니다',
                isDarkMode: isDarkMode,
                onTap: () {},
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: isDarkMode ? Colors.grey : Colors.grey[600],
                ),
              ),
            ],
          ),

          // 지원 섹션
          _buildSectionCard(
            title: '지원',
            icon: Icons.help_outline,
            isDarkMode: isDarkMode,
            backgroundColor: cardColor,
            shadowColor: shadowColor,
            children: [
              _buildSettingItem(
                icon: Icons.help,
                title: '도움말',
                subtitle: '자주 묻는 질문 및 도움말',
                isDarkMode: isDarkMode,
                onTap: () {},
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: isDarkMode ? Colors.grey : Colors.grey[600],
                ),
              ),
              _buildSettingItem(
                icon: Icons.support_agent,
                title: '고객 지원',
                subtitle: '문제가 있으면 문의하세요',
                isDarkMode: isDarkMode,
                onTap: () {},
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: isDarkMode ? Colors.grey : Colors.grey[600],
                ),
              ),
            ],
          ),

          // 기타 섹션
          _buildSectionCard(
            title: '기타',
            icon: Icons.more_horiz,
            isDarkMode: isDarkMode,
            backgroundColor: cardColor,
            shadowColor: shadowColor,
            children: [
              _buildSettingItem(
                icon: Icons.policy,
                title: '개인 정보 보호 정책',
                subtitle: '개인 정보가 어떻게 처리되는지 확인하세요',
                isDarkMode: isDarkMode,
                onTap: () {},
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: isDarkMode ? Colors.grey : Colors.grey[600],
                ),
              ),
              _buildSettingItem(
                icon: Icons.description,
                title: '이용 약관',
                subtitle: '앱 사용에 관한 약관을 읽어보세요',
                isDarkMode: isDarkMode,
                onTap: () {},
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: isDarkMode ? Colors.grey : Colors.grey[600],
                ),
              ),
              _buildSettingItem(
                icon: Icons.logout,
                title: '로그아웃',
                subtitle: '계정에서 로그아웃합니다',
                isDarkMode: isDarkMode,
                isDestructive: true,
                onTap: () {
                  // 로그아웃 처리
                },
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.red,
                ),
              ),
            ],
          ),

          // 앱 정보 섹션
          Container(
            margin: EdgeInsets.symmetric(vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primaryColor.withOpacity(0.1),
                  ),
                  child: Icon(
                    Icons.local_taxi,
                    size: 48.0,
                    color: primaryColor,
                  ),
                ),
                SizedBox(height: 12.0),
                Text(
                  'PLO RIDE',
                  style: TextStyle(
                    fontSize: 20.0,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                SizedBox(height: 4.0),
                Text(
                  '버전 1.0.0',
                  style: TextStyle(
                    fontSize: 14.0,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                SizedBox(height: 16.0),
                Text(
                  '© 2023 PLO 팀. All rights reserved.',
                  style: TextStyle(
                    fontSize: 12.0,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 30),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: ''),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: isDarkMode ? Colors.white : Colors.blue,
        unselectedItemColor: isDarkMode ? Colors.grey[600] : Colors.grey,
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        type: BottomNavigationBarType.fixed,
        onTap: _onItemTapped,
      ),
    );

    // useScaffold 파라미터에 따라 Scaffold를 사용할지 결정
    if (widget.useScaffold) {
      return WillPopScope(
        onWillPop: () async {
          // 뒤로가기 버튼 누를 때 HomePage로 이동
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder:
                  (context, animation, secondaryAnimation) => HomePage(),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ),
          );
          // 시스템 뒤로가기 동작 방지
          return false;
        },
        child: content,
      );
    } else {
      // Scaffold의 body를 직접 반환하기 위해 타입 캐스팅 사용
      final scaffold = content as Scaffold;
      return scaffold.body!;
    }
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required bool isDarkMode,
    required Color backgroundColor,
    required Color shadowColor,
    required List<Widget> children,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: shadowColor, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Color(0xFF536DFE).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 20, color: Color(0xFF536DFE)),
                ),
                SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ),
          Divider(thickness: 0.5),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDarkMode,
    required VoidCallback onTap,
    Widget? trailing,
    bool isDestructive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                size: 24,
                color:
                    isDestructive
                        ? Colors.red
                        : isDarkMode
                        ? Color(0xFF536DFE).withOpacity(0.8)
                        : Color(0xFF536DFE),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color:
                            isDestructive
                                ? Colors.red
                                : isDarkMode
                                ? Colors.white
                                : Colors.black,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              trailing ?? SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDarkMode,
    required Color primaryColor,
  }) {
    return _buildSettingItem(
      icon: icon,
      title: title,
      subtitle: subtitle,
      isDarkMode: isDarkMode,
      onTap: () {
        onChanged(!value);
      },
      trailing: CupertinoSwitch(
        value: value,
        onChanged: onChanged,
        activeColor: primaryColor,
        trackColor: isDarkMode ? Colors.grey[800] : Colors.grey[300],
      ),
    );
  }
}
