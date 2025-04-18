import 'package:flutter/material.dart';
import 'package:cabrider/screens/mainpage.dart';
import 'package:cabrider/screens/searchpage.dart';
import 'package:cabrider/screens/settings_page.dart';
import 'package:cabrider/screens/chat_page.dart';
import 'package:cabrider/screens/history_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  String _userName = ''; // 사용자 이름 저장 변수 추가

  @override
  void initState() {
    super.initState();
    _getUserInfo(); // 사용자 정보 가져오기
  }

  // 사용자 정보 가져오기 함수 추가
  void _getUserInfo() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && currentUser.email != null) {
      setState(() {
        _userName = currentUser.email!.split('@')[0]; // 이메일에서 @ 앞부분 추출
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
      HomeContent(isDarkMode: isDarkMode),
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
                        '안녕하세요, $_userName 님',
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
                        '안녕하세요, $_userName',
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
                            'User Name',
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
}

// 홈 탭의 컨텐츠를 위한 별도의 위젯
class HomeContent extends StatefulWidget {
  final bool isDarkMode;

  const HomeContent({Key? key, required this.isDarkMode}) : super(key: key);

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  Map<String, dynamic>? _reservedTrip;

  @override
  void initState() {
    super.initState();
    _loadReservedTrip();
  }

  // 예약된 탑승 정보를 가져오는 함수
  Future<void> _loadReservedTrip() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      print('사용자 ID: ${currentUser.uid}로 이용 내역 조회 시작');

      // 사용자의 히스토리에서 가장 최근의 라이드 데이터 가져오기 (상태 필터 제거)
      final historyQuery =
          await _firestore
              .collection('users')
              .doc(currentUser.uid)
              .collection('history')
              .orderBy('timestamp', descending: true)
              .limit(1)
              .get();

      print('조회된 문서 수: ${historyQuery.docs.length}');

      if (historyQuery.docs.isNotEmpty) {
        final tripData = historyQuery.docs.first.data();
        print('가져온 데이터: $tripData');

        setState(() {
          _reservedTrip = tripData;
          _isLoading = false;
        });
      } else {
        print('이용 내역이 없습니다');
        setState(() {
          _reservedTrip = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('예약된 탑승 정보를 가져오는 중 오류 발생: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 색상 설정
    final textColor = widget.isDarkMode ? Colors.white : Colors.black;
    final subTextColor =
        widget.isDarkMode ? Colors.grey[400] : Colors.grey[600];
    final cardColor = widget.isDarkMode ? Color(0xFF1E1E1E) : Colors.white;
    final cardBorderColor =
        widget.isDarkMode ? Colors.grey[800] : Colors.grey[300];
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
            if (_isLoading)
              Center(child: CircularProgressIndicator())
            else if (_reservedTrip != null)
              Container(
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
                          '최근 이용 내역',
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
                              Icon(Icons.circle, color: Colors.green, size: 12),
                              Container(
                                width: 1,
                                height: 30,
                                color:
                                    widget.isDarkMode
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
                                _reservedTrip!['pickup'] ?? '출발지 정보 없음',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 15,
                                ),
                              ),
                              SizedBox(height: 16),
                              Text(
                                _reservedTrip!['destination'] ?? '도착지 정보 없음',
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
                      color:
                          widget.isDarkMode
                              ? Colors.grey[800]
                              : Colors.grey[300],
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _formatDateTime(_reservedTrip!['timestamp']),
                            style: TextStyle(color: subTextColor, fontSize: 13),
                          ),
                        ),
                        if (_reservedTrip!.containsKey('status'))
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(
                                _reservedTrip!['status'],
                              ).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _getStatusColor(
                                  _reservedTrip!['status'],
                                ).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _getStatusIcon(_reservedTrip!['status']),
                                SizedBox(width: 4),
                                Text(
                                  _reservedTrip!['status'] ?? '상태 정보 없음',
                                  style: TextStyle(
                                    color: _getStatusColor(
                                      _reservedTrip!['status'],
                                    ),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

            SizedBox(height: 24),

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
                  Icon(Icons.shield, color: Colors.white, size: 32),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 16),
                        Text(
                          'PLO 와 함께할 용사',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'PLO 와 함께할 기회 바로 지금입니다.',
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
                      _launchPLOInstagram();
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

  // Timestamp를 포맷팅하는 함수
  String _formatDateTime(dynamic timestamp) {
    if (timestamp == null) return '날짜 정보 없음';

    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.year}년 ${date.month}월 ${date.day}일 ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }

    return '날짜 정보 없음';
  }

  // 요금 정보를 포맷팅하는 함수
  String _formatFare(dynamic fare) {
    if (fare == null) return '요금 정보 없음';

    if (fare is int || fare is double) {
      return '${fare.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원';
    } else if (fare is String) {
      try {
        final numericFare = int.parse(fare);
        return '${numericFare.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}원';
      } catch (e) {
        return fare;
      }
    }

    return '요금 정보 없음';
  }

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
      case '확정됨':
        return Colors.green;
      case '드라이버의 수락을 기다리는 중':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Icon _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return Icon(Icons.check_circle, color: Colors.blue);
      case 'completed':
        return Icon(Icons.done, color: Colors.green);
      case 'pending':
        return Icon(Icons.schedule, color: Colors.orange);
      case 'canceled':
        return Icon(Icons.cancel, color: Colors.red);
      case '확정됨':
        return Icon(Icons.check_circle, color: Colors.green);
      case '드라이버의 수락을 기다리는 중':
        return Icon(Icons.schedule, color: Colors.orange);
      default:
        return Icon(Icons.help_outline, color: Colors.grey);
    }
  }

  // Instagram URL을 열기 위한 함수
  Future<void> _launchPLOInstagram() async {
    final Uri instagramUrl = Uri.parse(
      'https://www.instagram.com/psu_plo?utm_source=ig_web_button_share_sheet&igsh=ZDNlZDc0MzIxNw==',
    );

    try {
      if (await canLaunchUrl(instagramUrl)) {
        await launchUrl(instagramUrl, mode: LaunchMode.externalApplication);
      } else {
        print('Instagram URL을 열 수 없습니다: $instagramUrl');
      }
    } catch (e) {
      print('URL 실행 중 오류 발생: $e');
    }
  }
}
