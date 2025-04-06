import 'package:flutter/material.dart';
import 'package:cabrider/screens/mainpage.dart';
import 'package:cabrider/screens/homepage.dart';
import 'package:cabrider/screens/taxi_info_page.dart';

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
                  (context, animation, secondaryAnimation) => TaxiInfoPage(),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ),
          );
        }
        _selectedIndex = index;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final backgroundColor = isDarkMode ? Colors.black : Colors.white;
    final accentColor = Color(0xFF3F51B5); // 인디고 색상

    // 설정 페이지의 내용
    Widget content = Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: accentColor,
        title: Text('설정', style: TextStyle(color: Colors.white)),
        automaticallyImplyLeading: false, // 뒤로가기 버튼 제거
      ),
      body: ListView(
        children: [
          // 개인 정보 섹션
          _buildSectionHeader('개인 정보', isDarkMode),
          _buildSettingItem(
            icon: Icons.person,
            title: '프로필 정보',
            subtitle: '개인 정보 및 연락처 정보를 관리합니다',
            isDarkMode: isDarkMode,
            onTap: () {},
          ),

          // 앱 설정 섹션
          _buildSectionHeader('앱 설정', isDarkMode),
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
          ),

          // 결제 섹션
          _buildSectionHeader('결제', isDarkMode),
          _buildSettingItem(
            icon: Icons.payment,
            title: '결제 방법',
            subtitle: '신용카드 및 다른 결제 방법을 관리합니다',
            isDarkMode: isDarkMode,
            onTap: () {},
          ),
          _buildSettingItem(
            icon: Icons.receipt_long,
            title: '영수증',
            subtitle: '이전 라이드의 영수증을 확인합니다',
            isDarkMode: isDarkMode,
            onTap: () {},
          ),

          // 지원 섹션
          _buildSectionHeader('지원', isDarkMode),
          _buildSettingItem(
            icon: Icons.help,
            title: '도움말',
            subtitle: '자주 묻는 질문 및 도움말',
            isDarkMode: isDarkMode,
            onTap: () {},
          ),
          _buildSettingItem(
            icon: Icons.support_agent,
            title: '고객 지원',
            subtitle: '문제가 있으면 문의하세요',
            isDarkMode: isDarkMode,
            onTap: () {},
          ),

          // 기타 섹션
          _buildSectionHeader('기타', isDarkMode),
          _buildSettingItem(
            icon: Icons.policy,
            title: '개인 정보 보호 정책',
            subtitle: '개인 정보가 어떻게 처리되는지 확인하세요',
            isDarkMode: isDarkMode,
            onTap: () {},
          ),
          _buildSettingItem(
            icon: Icons.description,
            title: '이용 약관',
            subtitle: '앱 사용에 관한 약관을 읽어보세요',
            isDarkMode: isDarkMode,
            onTap: () {},
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
          ),

          // 앱 정보 섹션
          _buildSectionHeader('앱 정보', isDarkMode),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.local_taxi, size: 48.0, color: accentColor),
                SizedBox(height: 8.0),
                Text(
                  'PLO RIDE',
                  style: TextStyle(
                    fontSize: 18.0,
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
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: isDarkMode ? Colors.white : Colors.blue,
        unselectedItemColor: isDarkMode ? Colors.grey[600] : Colors.grey,
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        showUnselectedLabels: true,
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

  Widget _buildSectionHeader(String title, bool isDarkMode) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: isDarkMode ? Color(0xFF3F51B5) : Color(0xFF3F51B5),
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDarkMode,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color:
            isDestructive
                ? Colors.red
                : isDarkMode
                ? Color(0xFF3F51B5).withOpacity(0.8)
                : Color(0xFF3F51B5),
      ),
      title: Text(
        title,
        style: TextStyle(
          color:
              isDestructive
                  ? Colors.red
                  : isDarkMode
                  ? Colors.white
                  : Colors.black,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _buildSwitchItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDarkMode,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color:
            isDarkMode ? Color(0xFF3F51B5).withOpacity(0.8) : Color(0xFF3F51B5),
      ),
      title: Text(
        title,
        style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Color(0xFF3F51B5),
      ),
    );
  }
}
