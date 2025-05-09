import 'package:flutter/material.dart';
import 'package:TAGO/screens/mainpage.dart';
import 'package:TAGO/screens/searchpage.dart';
import 'package:TAGO/screens/settings_page.dart';
import 'package:TAGO/screens/chat_page.dart';
import 'package:TAGO/screens/history_page.dart';
import 'package:TAGO/screens/chat_room_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  static const String id = 'home';

  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  String _username = '';
  Set<String> _shownPopups = {};
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isListenerSetup = false;

  @override
  void initState() {
    super.initState();
    _getUserInfo();
    _loadShownPopups();
  }

  // SharedPreferences에서 이미 표시된 팝업 목록 로드
  Future<void> _loadShownPopups() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? shownPopupsJson = prefs.getString('shown_popups');

      print('SharedPreferences 상태:');
      print('- shownPopupsJson: $shownPopupsJson');

      if (shownPopupsJson != null) {
        final List<dynamic> decodedList = json.decode(shownPopupsJson);
        setState(() {
          _shownPopups = Set<String>.from(decodedList);
        });
        print('로드된 팝업 목록: $_shownPopups');
      } else {
        print('저장된 팝업 목록이 없음');
        setState(() {
          _shownPopups = {};
        });
      }

      if (mounted) {
        setupChatRoomListener();
        _isListenerSetup = true;
      }
    } catch (e) {
      print('팝업 목록 로드 오류: $e');
      setState(() {
        _shownPopups = {};
      });
    }
  }

  // SharedPreferences에 팝업 목록 저장
  Future<void> _saveShownPopups() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encodedList = json.encode(_shownPopups.toList());
      await prefs.setString('shown_popups', encodedList);
      print('팝업 목록 저장됨: $_shownPopups');
    } catch (e) {
      print('팝업 목록 저장 오류: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 홈페이지에 있을 때만 리스너 설정 (팝업 목록 로드 후에만)
    if (_selectedIndex == 0 && !_isListenerSetup && _shownPopups.isNotEmpty) {
      setupChatRoomListener();
      _isListenerSetup = true;
    }
  }

  @override
  void didUpdateWidget(HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 탭이 변경될 때 리스너 설정/해제 (팝업 목록 로드 후에만)
    if (_selectedIndex == 0 && !_isListenerSetup && _shownPopups.isNotEmpty) {
      setupChatRoomListener();
      _isListenerSetup = true;
    }
  }

  Future<void> _getUserInfo() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data();
          setState(() {
            _username = userData?['fullname'] ?? 'app.guest'.tr();
          });
        }
      }
    } catch (e) {
      print('사용자 정보 로드 중 오류: $e');
      setState(() {
        _username = 'app.guest'.tr();
      });
    }
  }

  // 채팅방 리스너 설정 함수를 public으로 변경
  Future<void> setupChatRoomListener() async {
    print('채팅방 리스너 설정 시작');
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('사용자가 로그인되어 있지 않음');
      return;
    }

    try {
      QuerySnapshot chatRooms =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('chatRooms')
              .orderBy('joined_at', descending: true)
              .limit(1)
              .get();

      if (chatRooms.docs.isEmpty) {
        print('채팅방이 없음');
        return;
      }

      Map<String, dynamic> chatRoomData =
          chatRooms.docs.first.data() as Map<String, dynamic>;
      String chatRoomCollection = chatRoomData['chat_room_collection'] ?? '';
      String chatRoomId = chatRoomData['chat_room_id'] ?? '';

      print('채팅방 정보:');
      print('- collection: $chatRoomCollection');
      print('- id: $chatRoomId');

      if ((chatRoomCollection == 'psuToAirport' ||
              chatRoomCollection == 'airportToPsu') &&
          chatRoomId.isNotEmpty) {
        DocumentSnapshot chatRoomDoc =
            await FirebaseFirestore.instance
                .collection(chatRoomCollection)
                .doc(chatRoomId)
                .get();

        if (!chatRoomDoc.exists) {
          print('채팅방 문서가 존재하지 않음');
          return;
        }

        Map<String, dynamic> data = chatRoomDoc.data() as Map<String, dynamic>;
        List<dynamic> members = data['members'] ?? [];

        if (!members.contains(user.uid)) {
          print('사용자가 채팅방 멤버가 아님');
          return;
        }

        print('채팅방 리스너 설정: $chatRoomCollection/$chatRoomId');

        FirebaseFirestore.instance
            .collection(chatRoomCollection)
            .doc(chatRoomId)
            .snapshots()
            .listen(
              (documentSnapshot) async {
                if (!documentSnapshot.exists) {
                  print('채팅방 문서가 삭제됨');
                  return;
                }

                Map<String, dynamic> data =
                    documentSnapshot.data() as Map<String, dynamic>;
                bool driverAccepted = data['driver_accepted'] ?? false;
                String driverId = data['driver_id'] ?? '';
                bool chatActivated = data['chat_activated'] ?? false;
                List<dynamic> members = data['members'] ?? [];

                print('채팅방 상태 업데이트:');
                print('- driverAccepted: $driverAccepted');
                print('- chatActivated: $chatActivated');
                print('- members: $members');
                print('- current user: ${user.uid}');
                print('- shown popups: $_shownPopups');

                if (driverAccepted &&
                    mounted &&
                    !_shownPopups.contains(chatRoomId) &&
                    members.contains(user.uid)) {
                  print('팝업 표시 조건 충족');

                  // 지연 시간을 1초로 줄임
                  await Future.delayed(Duration(seconds: 1));

                  if (!mounted || _shownPopups.contains(chatRoomId)) {
                    print('팝업 표시 조건이 변경됨');
                    return;
                  }

                  print('팝업 표시 시작');

                  if (!mounted) return;

                  // 채팅방 활성화 처리 및 시스템 메시지 추가
                  if (!chatActivated) {
                    print('채팅방 활성화 처리 시작');
                    // 원본 채팅방 문서에 chat_activated 필드 업데이트
                    await FirebaseFirestore.instance
                        .collection(chatRoomCollection)
                        .doc(chatRoomId)
                        .update({'chat_activated': true, 'chat_visible': true});

                    // 채팅방의 모든 멤버 가져오기
                    DocumentSnapshot roomSnapshot =
                        await FirebaseFirestore.instance
                            .collection(chatRoomCollection)
                            .doc(chatRoomId)
                            .get();

                    if (roomSnapshot.exists) {
                      Map<String, dynamic> roomData =
                          roomSnapshot.data() as Map<String, dynamic>;
                      List<dynamic> members = roomData['members'] ?? [];

                      // 각 멤버의 채팅방 정보 업데이트
                      for (String memberId in members) {
                        String memberSafeDocId =
                            "${chatRoomCollection}_$chatRoomId".replaceAll(
                              '/',
                              '_',
                            );

                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(memberId)
                            .collection('chatRooms')
                            .doc(memberSafeDocId)
                            .update({
                              'driver_accepted': true,
                              'driver_id': driverId,
                              'chat_visible': true,
                            });
                      }

                      // 채팅방에 시스템 메시지 추가 (중복 방지를 위해 이전 메시지 확인)
                      QuerySnapshot existingMessages =
                          await FirebaseFirestore.instance
                              .collection(chatRoomCollection)
                              .doc(chatRoomId)
                              .collection('messages')
                              .where(
                                'text',
                                isEqualTo:
                                    'app.chat.room.system.driver_accepted',
                              )
                              .get();

                      if (existingMessages.docs.isEmpty) {
                        await FirebaseFirestore.instance
                            .collection(chatRoomCollection)
                            .doc(chatRoomId)
                            .collection('messages')
                            .add({
                              'text': 'app.chat.room.system.driver_accepted',
                              'sender_id': 'system',
                              'sender_name': '시스템',
                              'timestamp': FieldValue.serverTimestamp(),
                              'type': 'system',
                            });
                        print('시스템 메시지 추가됨: 드라이버 수락');
                      } else {
                        print('이미 시스템 메시지가 존재함: 드라이버 수락');
                      }
                    }
                  }

                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) {
                      return AlertDialog(
                        title: Text(
                          'app.chat.room.system.driver_accepted_title'.tr(),
                        ),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('app.chat.room.system.driver_accepted'.tr()),
                            SizedBox(height: 16),
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        color: Colors.green,
                                        size: 16,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          data['pickup_info']?['address'] ??
                                              'app.chat.room.system.no_pickup_location'
                                                  .tr(),
                                          style: TextStyle(fontSize: 14),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        color: Colors.red,
                                        size: 16,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          data['destination_info']?['address'] ??
                                              'app.chat.room.system.no_destination'
                                                  .tr(),
                                          style: TextStyle(fontSize: 14),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today,
                                        color: Colors.blue,
                                        size: 16,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        data['ride_date'] != null
                                            ? DateFormat(
                                              context.locale.languageCode ==
                                                      'ko'
                                                  ? 'yyyy년 MM월 dd일'
                                                  : 'MMMM dd, yyyy',
                                            ).format(
                                              (data['ride_date'] as Timestamp)
                                                  .toDate(),
                                            )
                                            : 'app.chat.room.system.no_date_info'
                                                .tr(),
                                        style: TextStyle(fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'app.chat.room.system.check_trip_details'.tr(),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: Text('app.common.later'.tr()),
                          ),
                          TextButton(
                            onPressed: () async {
                              Navigator.pop(context);

                              DocumentSnapshot chatRoomDoc =
                                  await FirebaseFirestore.instance
                                      .collection(chatRoomCollection)
                                      .doc(chatRoomId)
                                      .get();

                              if (chatRoomDoc.exists) {
                                Map<String, dynamic> data =
                                    chatRoomDoc.data() as Map<String, dynamic>;
                                String chatRoomName =
                                    data['chat_room_name'] ??
                                    'app.chat.room.default_name'.tr();

                                if (!mounted) return;

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => ChatRoomPage(
                                          chatRoomId: chatRoomId,
                                          chatRoomName: chatRoomName,
                                          chatRoomCollection:
                                              chatRoomCollection,
                                        ),
                                  ),
                                );
                              }
                            },
                            child: Text(
                              'app.chat.room.enter_chat_room'.tr(),
                              style: const TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );

                  setState(() {
                    _shownPopups.add(chatRoomId);
                  });
                  await _saveShownPopups();
                  print('팝업 표시 완료 및 저장됨');
                }
              },
              onError: (error) {
                print('채팅방 리스너 오류: $error');
              },
            );
      }
    } catch (e) {
      print('채팅방 리스너 설정 오류: $e');
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
      SettingsPage(useScaffold: false),
    ];

    // 현재 탭에 따라 AppBar를 다르게 표시
    PreferredSizeWidget? appBar;
    Widget body;

    if (_selectedIndex == 3) {
      appBar = null;
      body = Container(child: pages[_selectedIndex]);
    } else if (_selectedIndex <= 1) {
      appBar = PreferredSize(
        preferredSize: Size.fromHeight(200),
        child: Container(
          color: isDarkMode ? Colors.black : Colors.white,
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3F51B5),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'app.home.welcome_prefix'.tr() +
                            ' $_username' +
                            'app.home.welcome_suffix'.tr(),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'app.home.find_ride'.tr(),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
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
                              'app.home.find_ride'.tr(),
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
        preferredSize: Size.fromHeight(180),
        child: Container(
          color: isDarkMode ? Colors.black : Colors.white,
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                          fontSize: 32,
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
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'app.home.welcome_prefix'.tr() +
                            ' $_username' +
                            'app.home.welcome_suffix'.tr(),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'app.home.find_ride'.tr(),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
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
              SizedBox(
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
                            _username,
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
                  'app.home.find_ride'.tr(),
                  style: TextStyle(
                    fontSize: 16,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                onTap: () {
                  Navigator.pushReplacementNamed(context, MainPage.id);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.card_giftcard,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
                title: Text(
                  'app.home.free_rides'.tr(),
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
                  'app.home.payments'.tr(),
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
                  'app.home.ride_history'.tr(),
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
                  'app.support'.tr(),
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
                  'app.about'.tr(),
                  style: TextStyle(
                    fontSize: 16,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
        body: body,
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

  const HomeContent({super.key, required this.isDarkMode});

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

      // psuToAirport 여정 로드
      final psuToAirportSnapshot =
          await _firestore
              .collection('psuToAirport')
              .where('members', arrayContains: currentUser.uid)
              .get();

      // airportToPsu 여정 로드
      final airportToPsuSnapshot =
          await _firestore
              .collection('airportToPsu')
              .where('members', arrayContains: currentUser.uid)
              .get();

      // 두 컬렉션의 결과를 합치고 시간순으로 정렬
      List<Map<String, dynamic>> allTrips = [];

      allTrips.addAll(
        psuToAirportSnapshot.docs.map(
          (doc) => {...doc.data(), 'id': doc.id, 'collection': 'psuToAirport'},
        ),
      );

      allTrips.addAll(
        airportToPsuSnapshot.docs.map(
          (doc) => {...doc.data(), 'id': doc.id, 'collection': 'airportToPsu'},
        ),
      );

      // ride_date 기준으로 정렬 (히스토리 페이지와 동일하게)
      allTrips.sort((a, b) {
        Timestamp aTime = a['ride_date'] as Timestamp;
        Timestamp bTime = b['ride_date'] as Timestamp;
        return bTime.compareTo(aTime);
      });

      print('전체 여정 수: ${allTrips.length}');
      print('PSU → Airport 여정 수: ${psuToAirportSnapshot.docs.length}');
      print('Airport → PSU 여정 수: ${airportToPsuSnapshot.docs.length}');

      if (allTrips.isEmpty) {
        print('이용 내역이 없습니다');
        setState(() {
          _reservedTrip = null;
          _isLoading = false;
        });
        return;
      }

      // 가장 최근의 여정 선택 (취소 여부와 관계없이)
      print('가장 최근 여정 선택: ${allTrips.first}');
      setState(() {
        _reservedTrip = allTrips.first;
        _isLoading = false;
      });
    } catch (e) {
      print('예약된 탑승 정보를 가져오는 중 오류 발생: $e');
      setState(() {
        _reservedTrip = null;
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
                          'app.home.recent_rides'.tr(),
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
                        SizedBox(
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
                                _reservedTrip!['pickup_info']?['address'] ??
                                    'app.home.pickup_location'.tr(),
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 15,
                                ),
                              ),
                              SizedBox(height: 16),
                              Text(
                                _reservedTrip!['destination_info']?['address'] ??
                                    'app.home.destination'.tr(),
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
                        Text(
                          _formatDateTime(_reservedTrip!['ride_date']),
                          style: TextStyle(
                            color: textColor.withOpacity(0.7),
                            fontSize: 12,
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
                                  'app.home.status.${_reservedTrip!['status']}'
                                      .tr(),
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
              )
            else
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
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.orange, size: 24),
                    SizedBox(width: 12),
                    Text(
                      'app.home.no_recent_rides'.tr(),
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
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
                          context.locale.languageCode == 'ko'
                              ? 'PLO 와 함께할 용사'
                              : 'Join PLO Gang',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          context.locale.languageCode == 'ko'
                              ? 'PLO 와 함께할 기회 바로 지금입니다.'
                              : 'Your chance to join PLO is now.',
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
                      context.locale.languageCode == 'ko' ? 'ㄱㄱ?' : 'Join',
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
    if (timestamp == null) return 'app.home.no_date_info'.tr();

    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      final locale = context.locale.languageCode;

      if (locale == 'ko') {
        return '${date.year}년 ${date.month}월 ${date.day}일 ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      } else {
        // 영어 형식으로 날짜 변환
        final months = [
          'January',
          'February',
          'March',
          'April',
          'May',
          'June',
          'July',
          'August',
          'September',
          'October',
          'November',
          'December',
        ];
        String period = date.hour < 12 ? 'AM' : 'PM';
        int hour = date.hour % 12;
        if (hour == 0) hour = 12;

        return '${months[date.month - 1]} ${date.day}, ${date.year} ${hour}:${date.minute.toString().padLeft(2, '0')} $period';
      }
    }

    return 'app.home.no_date_info'.tr();
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

  String _getStatusTranslation(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return 'app.home.status.accepted'.tr();
      case 'completed':
        return 'app.home.status.completed'.tr();
      case 'pending':
        return 'app.home.status.pending'.tr();
      case 'canceled':
      case 'cancelled':
        return 'app.home.status.cancelled'.tr();
      case '확정됨':
        return 'app.home.status.confirmed'.tr();
      case '드라이버의 수락을 기다리는 중':
        return 'app.home.status.waiting'.tr();
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
      case '확정됨':
        return Colors.green;
      case 'completed':
      case '완료됨':
        return Colors.green;
      case 'pending':
      case '대기중':
        return Colors.orange;
      case 'canceled':
      case 'cancelled':
      case '취소됨':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Icon _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
      case '확정됨':
        return Icon(Icons.check_circle, color: Colors.green, size: 12);
      case 'completed':
      case '완료됨':
        return Icon(Icons.done, color: Colors.green, size: 12);
      case 'pending':
      case '대기중':
        return Icon(Icons.schedule, color: Colors.orange, size: 12);
      case 'canceled':
      case 'cancelled':
      case '취소됨':
        return Icon(Icons.cancel, color: Colors.red, size: 12);
      default:
        return Icon(Icons.help_outline, color: Colors.grey, size: 12);
    }
  }

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
