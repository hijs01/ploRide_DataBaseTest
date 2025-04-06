import 'package:flutter/material.dart';
import 'package:cabrider/screens/mainpage.dart';
import 'package:cabrider/screens/homepage.dart';
import 'package:cabrider/screens/settings_page.dart';

class TaxiInfoPage extends StatefulWidget {
  static const String id = 'taxiinfo';

  @override
  _TaxiInfoPageState createState() => _TaxiInfoPageState();
}

class _TaxiInfoPageState extends State<TaxiInfoPage> {
  int _selectedIndex = 2; // 현재 Chat 탭이 선택됨

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
        } else if (index == 3) {
          // Profile 탭으로 이동
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder:
                  (context, animation, secondaryAnimation) => SettingsPage(),
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
    final cardColor = isDarkMode ? Color(0xFF1E1E1E) : Colors.white;
    final accentColor = Color(0xFF3F51B5); // 인디고 색상

    return WillPopScope(
      onWillPop: () async {
        // 뒤로가기 버튼 누를 때 HomePage로 이동
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => HomePage(),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
        // 시스템 뒤로가기 동작 방지
        return false;
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: accentColor,
          title: Text('택시 정보', style: TextStyle(color: Colors.white)),
          automaticallyImplyLeading: false, // 뒤로가기 버튼 제거
        ),
        body: SingleChildScrollView(
          physics: BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 택시 타입 세션
                _buildSectionTitle('택시 유형', textColor),
                SizedBox(height: 12),

                _buildTaxiTypeCard(
                  context: context,
                  title: '일반 택시',
                  subtitle: '일반적인 택시 서비스',
                  description: '기본적인 택시 서비스로, 4인승 차량을 이용합니다.',
                  imageAsset: 'images/taxi.png',
                  price: '기본요금 3,800원',
                  backgroundColor: cardColor,
                  isDarkMode: isDarkMode,
                  textColor: textColor,
                  accentColor: accentColor,
                ),

                SizedBox(height: 16),

                _buildTaxiTypeCard(
                  context: context,
                  title: '모범 택시',
                  subtitle: '고급 택시 서비스',
                  description: '전문 기사와 깨끗한 차량을 통해 더 나은 서비스를 제공합니다.',
                  imageAsset: 'images/taxi.png',
                  price: '기본요금 6,500원',
                  backgroundColor: cardColor,
                  isDarkMode: isDarkMode,
                  textColor: textColor,
                  accentColor: accentColor,
                ),

                SizedBox(height: 16),

                _buildTaxiTypeCard(
                  context: context,
                  title: '대형 택시',
                  subtitle: '다수의 승객을 위한 택시',
                  description: '6-8명의 승객을 수용할 수 있는 대형 택시입니다.',
                  imageAsset: 'images/taxi.png',
                  price: '기본요금 8,000원',
                  backgroundColor: cardColor,
                  isDarkMode: isDarkMode,
                  textColor: textColor,
                  accentColor: accentColor,
                ),

                SizedBox(height: 30),

                // 택시 요금 정보 섹션
                _buildSectionTitle('요금 정보', textColor),
                SizedBox(height: 12),

                _buildInfoCard(
                  title: '기본 요금',
                  content: """• 일반 택시: 3,800원 (2km)
• 모범 택시: 6,500원 (3km)
• 대형 택시: 8,000원 (3km)

※ 심야 할증(00:00~04:00): 20% 추가
※ 시계외 할증: 20% 추가""",
                  backgroundColor: cardColor,
                  textColor: textColor,
                  accentColor: accentColor,
                  isDarkMode: isDarkMode,
                ),

                SizedBox(height: 16),

                _buildInfoCard(
                  title: '거리 요금',
                  content: """• 일반 택시: 100원/142m
• 모범 택시: 200원/164m
• 대형 택시: 300원/164m""",
                  backgroundColor: cardColor,
                  textColor: textColor,
                  accentColor: accentColor,
                  isDarkMode: isDarkMode,
                ),

                SizedBox(height: 16),

                _buildInfoCard(
                  title: '시간 요금',
                  content: """• 일반 택시: 100원/35초
• 모범 택시: 200원/39초
• 대형 택시: 300원/39초""",
                  backgroundColor: cardColor,
                  textColor: textColor,
                  accentColor: accentColor,
                  isDarkMode: isDarkMode,
                ),

                SizedBox(height: 30),

                // 이용 방법 섹션
                _buildSectionTitle('이용 방법', textColor),
                SizedBox(height: 12),

                _buildHowToUseCard(
                  step: '1',
                  title: '목적지 입력',
                  description: '앱에서 출발지와 목적지를 입력하세요.',
                  icon: Icons.location_on,
                  backgroundColor: cardColor,
                  textColor: textColor,
                  accentColor: accentColor,
                  isDarkMode: isDarkMode,
                ),

                SizedBox(height: 12),

                _buildHowToUseCard(
                  step: '2',
                  title: '택시 유형 선택',
                  description: '이용하고 싶은 택시 유형을 선택하세요.',
                  icon: Icons.local_taxi,
                  backgroundColor: cardColor,
                  textColor: textColor,
                  accentColor: accentColor,
                  isDarkMode: isDarkMode,
                ),

                SizedBox(height: 12),

                _buildHowToUseCard(
                  step: '3',
                  title: '기사 확인 및 탑승',
                  description: '배정된 기사 정보를 확인하고 탑승하세요.',
                  icon: Icons.person,
                  backgroundColor: cardColor,
                  textColor: textColor,
                  accentColor: accentColor,
                  isDarkMode: isDarkMode,
                ),

                SizedBox(height: 12),

                _buildHowToUseCard(
                  step: '4',
                  title: '결제',
                  description: '목적지 도착 후 앱이나 현금으로 결제하세요.',
                  icon: Icons.payment,
                  backgroundColor: cardColor,
                  textColor: textColor,
                  accentColor: accentColor,
                  isDarkMode: isDarkMode,
                ),

                SizedBox(height: 30),

                // 자주 묻는 질문
                _buildSectionTitle('자주 묻는 질문', textColor),
                SizedBox(height: 12),

                _buildFAQItem(
                  question: '택시를 예약할 수 있나요?',
                  answer: '네, 앱에서 최대 7일 전까지 택시를 예약할 수 있습니다.',
                  backgroundColor: cardColor,
                  textColor: textColor,
                  accentColor: accentColor,
                  isDarkMode: isDarkMode,
                ),

                SizedBox(height: 8),

                _buildFAQItem(
                  question: '결제 방법은 어떤 것이 있나요?',
                  answer: '신용카드, 계좌이체, 현금 등 다양한 결제 방법을 지원합니다.',
                  backgroundColor: cardColor,
                  textColor: textColor,
                  accentColor: accentColor,
                  isDarkMode: isDarkMode,
                ),

                SizedBox(height: 8),

                _buildFAQItem(
                  question: '취소 수수료가 있나요?',
                  answer: '5분 이내 취소는 무료이며, 이후에는 수수료가 부과될 수 있습니다.',
                  backgroundColor: cardColor,
                  textColor: textColor,
                  accentColor: accentColor,
                  isDarkMode: isDarkMode,
                ),

                SizedBox(height: 40),
              ],
            ),
          ),
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
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildTaxiTypeCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String description,
    required String imageAsset,
    required String price,
    required Color backgroundColor,
    required bool isDarkMode,
    required Color textColor,
    required Color accentColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isDarkMode ? Colors.grey[800]! : Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    imageAsset,
                    width: 70,
                    height: 70,
                    fit: BoxFit.cover,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color:
                              isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        price,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              description,
              style: TextStyle(fontSize: 14, color: textColor.withOpacity(0.8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String content,
    required Color backgroundColor,
    required Color textColor,
    required Color accentColor,
    required bool isDarkMode,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isDarkMode ? Colors.grey[800]! : Colors.grey[200]!,
          width: 1,
        ),
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
          SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: textColor.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHowToUseCard({
    required String step,
    required String title,
    required String description,
    required IconData icon,
    required Color backgroundColor,
    required Color textColor,
    required Color accentColor,
    required bool isDarkMode,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isDarkMode ? Colors.grey[800]! : Colors.grey[200]!,
          width: 1,
        ),
      ),
      padding: EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accentColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                step,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: accentColor, size: 22),
                    SizedBox(width: 8),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: textColor.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQItem({
    required String question,
    required String answer,
    required Color backgroundColor,
    required Color textColor,
    required Color accentColor,
    required bool isDarkMode,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isDarkMode ? Colors.grey[800]! : Colors.grey[200]!,
          width: 1,
        ),
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.help_outline, color: accentColor, size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  question,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 30.0),
            child: Text(
              answer,
              style: TextStyle(fontSize: 14, color: textColor.withOpacity(0.8)),
            ),
          ),
        ],
      ),
    );
  }
}
