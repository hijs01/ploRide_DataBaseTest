import 'package:flutter/material.dart';
import 'package:cabrider/screens/mainpage.dart';
import 'package:cabrider/screens/searchpage.dart';
import 'package:cabrider/screens/settings_page.dart';
import 'package:cabrider/screens/chat_page.dart';
import 'package:cabrider/screens/history_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class HomePage extends StatefulWidget {
  static const String id = 'home';

  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  Map<String, dynamic>? latestRideData;
  bool isLoading = true;
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _fetchLatestRideData();
    _getUserInfo();
  }

  Future<void> _getUserInfo() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
            
        if (userDoc.exists) {
          final userData = userDoc.data();
          setState(() {
            _userName = userData?['fullname'] ?? 
                       userData?['name'] ?? 
                       currentUser.email!.split('@')[0];
          });
          print('User fullname: $_userName'); // 디버깅을 위한 로그 추가
        } else {
          setState(() {
            _userName = currentUser.email!.split('@')[0];
          });
        }
      } catch (e) {
        print('Error fetching user info: $e');
        setState(() {
          _userName = currentUser.email!.split('@')[0];
        });
      }
    }
  }

  Future<void> _fetchLatestRideData() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null) {
        final historySnapshot =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser.uid)
                .collection('history')
                .orderBy('timestamp', descending: true)
                .limit(1)
                .get();

        if (historySnapshot.docs.isNotEmpty) {
          setState(() {
            latestRideData = historySnapshot.docs.first.data();
            isLoading = false;
          });
        } else {
          setState(() {
            isLoading = false;
          });
        }
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching latest ride data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      if (index == 0) {
        // 홈 탭 유지
      } else if (index == 1) {
        // History 페이지로 이동 (애니메이션 없음)
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder:
                (context, animation, secondaryAnimation) => HistoryPage(),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
      } else if (index == 2) {
        // Chat 페이지로 이동 (애니메이션 없음)
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => ChatPage(),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
      } else if (index == 3) {
        // Profile 페이지로 이동 (애니메이션 없음)
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;

    // 각 탭에 해당하는 화면 위젯들
    final List<Widget> pages = [
      HomeContent(isDarkMode: isDarkMode, latestRideData: latestRideData),
      Center(
        child: Text(
          'No rides to be updated',
          style: TextStyle(
            fontSize: 18,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
      ),
      ChatPage(),
      SettingsPage(useScaffold: false), // Scaffold 없이 내용만 표시
    ];

    // 현재 탭에 따라 AppBar를 다르게 표시
    PreferredSizeWidget? appBar;
    Widget body;

    if (_selectedIndex == 3) {
      // Settings 탭일 때는 AppBar 없음 (SettingsPage가 자체 AppBar 포함)
      appBar = null;
      // SettingsPage를 직접 사용하는 대신 간단한 Container로 감싸 렌더링
      body = Container(child: pages[_selectedIndex]);
    } else if (_selectedIndex <= 1) {
      // Home, In Progress 탭일 때
      appBar = PreferredSize(
        preferredSize: Size.fromHeight(160),
        child: Container(
          color: isDarkMode ? Colors.black : Colors.white,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TAGO',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3F51B5), // 인디고 색상
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '안녕하세요, $_userName님',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      Text(
                        '어디로 가시나요?',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      body = Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            color: isDarkMode ? Colors.black : Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SearchPage()),
                    );
                  },
                  child: AbsorbPointer(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDarkMode ? Color(0xFF212121) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color:
                                isDarkMode
                                    ? Colors.black.withOpacity(0.3)
                                    : Colors.grey.withOpacity(0.3),
                            spreadRadius: 1,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                        border: Border.all(
                          color:
                              isDarkMode
                                  ? Colors.grey[800]!
                                  : Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12.0,
                          horizontal: 4.0,
                        ),
                        child: Row(
                          children: [
                            SizedBox(width: 16),
                            Container(
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Color(0xFF3F51B5).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.search,
                                color: Color(0xFF3F51B5),
                                size: 26,
                              ),
                            ),
                            SizedBox(width: 16),
                            Text(
                              '탑승 정보 입력하기',
                              style: TextStyle(
                                fontSize: 18,
                                color:
                                    isDarkMode
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: pages[0], // 항상 첫 번째 페이지만 표시
          ),
        ],
      );
    } else {
      // TaxiInfo 탭일 때 (Index 2)
      appBar = PreferredSize(
        preferredSize: Size.fromHeight(160),
        child: Container(
          color: isDarkMode ? Colors.black : Colors.white,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'PLORIDE',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3F51B5), // 인디고 색상
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '안녕하세요, $_userName님',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      Text(
                        '어디로 가시나요?',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      body = pages[0]; // TaxiInfo 탭일 때는 HomeContent 표시
    }

    // WillPopScope 추가하여 뒤로가기 동작 제어
    return WillPopScope(
      onWillPop: () async {
        // 이미 홈 탭에 있으면 앱 종료를 허용
        if (_selectedIndex == 0) {
          return true;
        }

        // 다른 탭에 있으면 홈 탭으로 이동
        setState(() {
          _selectedIndex = 0;
        });

        // 뒤로가기 이벤트 소비 (앱 종료 방지)
        return false;
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        appBar: appBar,
        drawer: Drawer(
          backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                height: 160,
                child: DrawerHeader(
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.black : Colors.white,
                  ),
                  child: Row(
                    children: [
                      Image.asset(
                        'images/user_icon.png',
                        height: 60,
                        width: 60,
                      ),
                      SizedBox(width: 15),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _userName,
                            style: TextStyle(
                              fontSize: 20,
                              fontFamily: 'Brand-Bold',
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'View Profile',
                            style: TextStyle(
                              color:
                                  isDarkMode
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              ListTile(
                leading: Icon(
                  Icons.home,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
                title: Text(
                  'Home',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                onTap: () {
                  //수정1
                  Navigator.pushReplacementNamed(context, MainPage.id);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.card_giftcard,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
                title: Text(
                  'Free Rides',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(
                  Icons.credit_card,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
                title: Text(
                  'Payments',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(
                  Icons.history,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
                title: Text(
                  'Ride History',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(
                  Icons.support,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
                title: Text(
                  'Support',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(
                  Icons.info,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
                title: Text(
                  'About',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
        body: body, // IndexedStack를 제거하고 직접 body 변수 사용
        bottomNavigationBar: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
            BottomNavigationBarItem(icon: Icon(Icons.history), label: '히스토리'),
            BottomNavigationBarItem(icon: Icon(Icons.chat), label: '채팅'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: '프로필'),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: isDarkMode ? Colors.white : Colors.blue,
          unselectedItemColor: isDarkMode ? Colors.grey[600] : Colors.grey,
          backgroundColor: isDarkMode ? Colors.black : Colors.white,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}

// 홈 탭의 컨텐츠를 위한 별도의 위젯
class HomeContent extends StatelessWidget {
  final bool isDarkMode;
  final Map<String, dynamic>? latestRideData;

  const HomeContent({Key? key, required this.isDarkMode, this.latestRideData})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 색상 설정
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subTextColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];
    final cardColor = isDarkMode ? Color(0xFF1E1E1E) : Colors.white;
    final cardBorderColor = isDarkMode ? Colors.grey[800] : Colors.grey[300];
    final accentColor = Color(0xFF3F51B5); // 인디고 색상

    return SingleChildScrollView(
      physics: BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 20),

            // 예약된 탑승 정보 (있는 경우)
            latestRideData != null
                ? Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: accentColor.withOpacity(0.3),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    color: cardColor,
                  ),
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            color: accentColor,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            '예약된 탑승',
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            width: 40,
                            child: Column(
                              children: [
                                Icon(
                                  Icons.circle,
                                  color: Colors.green,
                                  size: 12,
                                ),
                                Container(
                                  width: 1,
                                  height: 30,
                                  color:
                                      isDarkMode
                                          ? Colors.grey[700]
                                          : Colors.grey[400],
                                ),
                                Icon(
                                  Icons.location_on,
                                  color: Colors.red,
                                  size: 12,
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  latestRideData!['pickup'] ?? '출발지 정보 없음',
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 15,
                                  ),
                                ),
                                SizedBox(height: 16),
                                Text(
                                  latestRideData!['destination'] ?? '도착지 정보 없음',
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Divider(
                        color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatTimestamp(latestRideData!['timestamp']),
                            style: TextStyle(color: subTextColor, fontSize: 13),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(
                                latestRideData!['status'] ?? '',
                              ).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              latestRideData!['status'] ?? '상태 정보 없음',
                              style: TextStyle(
                                color: _getStatusColor(
                                  latestRideData!['status'] ?? '',
                                ),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
                : SizedBox(), // 데이터가 없으면 표시하지 않음

            SizedBox(height: 40),

            // 프로모션 배너
            Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accentColor, Color(0xFF5C6BC0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.local_offer, color: Colors.white, size: 32),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 17),
                        Text(
                          'PLO와 함께',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'PLO와 함께할 용사 구합니다',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final Uri url = Uri.parse(
                        'https://www.instagram.com/psu_plo?utm_source=ig_web_button_share_sheet&igsh=ZDNlZDc0MzIxNw==',
                      );
                      try {
                        await launchUrl(
                          url,
                          mode: LaunchMode.externalApplication,
                        );
                      } catch (e) {
                        print('URL을 열 수 없습니다: $e');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: accentColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(
                      'ㄱㄱ?',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // 상태에 따른 색상 반환
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'canceled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // 타임스탬프 포맷 메서드
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '날짜 정보 없음';

    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else {
      return '날짜 정보 없음';
    }

    return '${date.year}년 ${date.month}월 ${date.day}일 ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  // 인기 목적지 카드 위젯
  Widget _buildDestinationCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color cardColor,
    Color? borderColor,
    Color textColor,
    Color? subTextColor,
    Color accentColor,
  ) {
    return GestureDetector(
      onTap: () {
        // 목적지 선택 처리
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => SearchPage()),
        );
      },
      child: Container(
        width: 160,
        margin: EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor ?? Colors.transparent),
        ),
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: accentColor, size: 24),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: subTextColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 최근 이동 경로 카드 위젯
  Widget _buildRecentRideCard(
    String title,
    String date,
    String price,
    Color cardColor,
    Color? borderColor,
    Color textColor,
    Color? subTextColor,
    Color accentColor,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor ?? Colors.transparent),
      ),
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.history, color: accentColor, size: 20),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                SizedBox(height: 4),
                Text(date, style: TextStyle(fontSize: 12, color: subTextColor)),
              ],
            ),
          ),
          Text(
            price,
            style: TextStyle(fontWeight: FontWeight.bold, color: accentColor),
          ),
        ],
      ),
    );
  }

  // 추천 패키지 카드 위젯
  Widget _buildPackageCard(
    String title,
    String description,
    IconData icon,
    Color cardColor,
    Color? borderColor,
    Color textColor,
    Color? subTextColor,
    Color accentColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor ?? Colors.transparent),
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: accentColor, size: 20),
          ),
          SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: textColor,
              fontSize: 15,
            ),
          ),
          SizedBox(height: 6),
          Text(
            description,
            style: TextStyle(fontSize: 12, color: subTextColor, height: 1.4),
          ),
        ],
      ),
    );
  }
}
