import 'package:flutter/material.dart';
import 'package:cabrider/screens/mainpage.dart';
import 'package:cabrider/screens/homepage.dart';
import 'package:cabrider/screens/settings_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class TaxiInfoPage extends StatefulWidget {
  static const String id = 'taxiinfo';

  @override
  _TaxiInfoPageState createState() => _TaxiInfoPageState();
}

class _TaxiInfoPageState extends State<TaxiInfoPage> {
  int _selectedIndex = 2; // 현재 Chat 탭이 선택됨

  // 채팅방 목록을 저장할 변수 추가
  List<Map<String, dynamic>> _chatRooms = [];
  bool _isLoadingChatRooms = false;
  String _errorMessage = '';
  StreamSubscription? _chatRoomsSubscription;

  @override
  void initState() {
    super.initState();
    _loadUserChatRooms();
  }

  @override
  void dispose() {
    _chatRoomsSubscription?.cancel();
    super.dispose();
  }

  // 사용자의 채팅방 목록을 가져오는 함수
  Future<void> _loadUserChatRooms() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _errorMessage = '로그인이 필요합니다';
        _isLoadingChatRooms = false;
      });
      return;
    }

    setState(() {
      _isLoadingChatRooms = true;
      _errorMessage = '';
    });

    try {
      // 사용자의 채팅방 목록 구독
      _chatRoomsSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('chatRooms')
          .orderBy('joined_at', descending: true)
          .snapshots()
          .listen(
            (snapshot) async {
              List<Map<String, dynamic>> chatRooms = [];

              for (var doc in snapshot.docs) {
                Map<String, dynamic> data = doc.data();
                String chatRoomCollection = data['chat_room_collection'] ?? '';
                String chatRoomId = data['chat_room_id'] ?? '';

                if (chatRoomCollection.isNotEmpty && chatRoomId.isNotEmpty) {
                  try {
                    // 채팅방 정보 가져오기
                    DocumentSnapshot chatRoomDoc =
                        await FirebaseFirestore.instance
                            .collection(chatRoomCollection)
                            .doc(chatRoomId)
                            .get();

                    if (chatRoomDoc.exists) {
                      Map<String, dynamic> chatRoomData =
                          chatRoomDoc.data() as Map<String, dynamic>;

                      // 채팅방 정보와 경로 등 필요한 정보 저장
                      chatRooms.add({
                        'id': chatRoomId,
                        'collection': chatRoomCollection,
                        'data': chatRoomData,
                        'last_message': chatRoomData['last_message'] ?? '대화 없음',
                        'member_count': chatRoomData['member_count'] ?? 0,
                        'ride_date': chatRoomData['ride_date_timestamp'],
                      });
                    }
                  } catch (e) {
                    print('채팅방 정보 가져오기 오류: $e');
                  }
                }
              }

              if (mounted) {
                setState(() {
                  _chatRooms = chatRooms;
                  _isLoadingChatRooms = false;
                });
              }
            },
            onError: (e) {
              print('채팅방 목록 가져오기 오류: $e');
              if (mounted) {
                setState(() {
                  _errorMessage = '채팅방 정보를 불러올 수 없습니다';
                  _isLoadingChatRooms = false;
                });
              }
            },
          );
    } catch (e) {
      print('채팅방 구독 오류: $e');
      if (mounted) {
        setState(() {
          _errorMessage = '채팅방 정보를 불러올 수 없습니다: $e';
          _isLoadingChatRooms = false;
        });
      }
    }
  }

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
          title: Text('내 채팅방', style: TextStyle(color: Colors.white)),
          automaticallyImplyLeading: false, // 뒤로가기 버튼 제거
        ),
        body: SingleChildScrollView(
          physics: BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 채팅방 섹션만 표시
                if (_isLoadingChatRooms)
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                      border: Border.all(
                        color:
                            isDarkMode ? Colors.grey[800]! : Colors.grey[200]!,
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              accentColor,
                            ),
                            strokeWidth: 3,
                          ),
                          SizedBox(height: 12),
                          Text(
                            '채팅방 목록을 불러오는 중...',
                            style: TextStyle(
                              color: textColor.withOpacity(0.7),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_errorMessage.isNotEmpty)
                  Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                      border: Border.all(
                        color:
                            isDarkMode ? Colors.grey[800]! : Colors.grey[200]!,
                        width: 1,
                      ),
                    ),
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red, size: 24),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage,
                            style: TextStyle(color: textColor, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_chatRooms.isEmpty)
                  Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                      border: Border.all(
                        color:
                            isDarkMode ? Colors.grey[800]! : Colors.grey[200]!,
                        width: 1,
                      ),
                    ),
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          color: accentColor.withOpacity(0.7),
                          size: 40,
                        ),
                        SizedBox(height: 12),
                        Text(
                          '채팅방이 없습니다',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '택시 예약을 완료하면 자동으로 채팅방이 생성됩니다',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: textColor.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Column(
                    children:
                        _chatRooms.map((chatRoom) {
                          // 채팅방 정보 추출
                          Timestamp? rideDate = chatRoom['ride_date'];
                          DateTime? rideDatetime = rideDate?.toDate();
                          String formattedDate = '날짜 정보 없음';

                          if (rideDatetime != null) {
                            formattedDate =
                                '${rideDatetime.year}년 ${rideDatetime.month}월 ${rideDatetime.day}일';
                            String period =
                                rideDatetime.hour < 12 ? '오전' : '오후';
                            int hour = rideDatetime.hour % 12;
                            if (hour == 0) hour = 12;
                            String formattedTime =
                                '$period $hour:${rideDatetime.minute.toString().padLeft(2, '0')}';
                            formattedDate += ' $formattedTime';
                          }

                          // 채팅방 컬렉션에 따라 아이콘 결정
                          IconData routeIcon;
                          String routeText;

                          if (chatRoom['collection'] == 'psuToAirport') {
                            routeIcon = Icons.flight_takeoff;
                            routeText = 'PSU → 공항';
                          } else if (chatRoom['collection'] == 'airportToPsu') {
                            routeIcon = Icons.flight_land;
                            routeText = '공항 → PSU';
                          } else {
                            routeIcon = Icons.sync_alt;
                            routeText = '일반 경로';
                          }

                          return Container(
                            margin: EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                              border: Border.all(
                                color:
                                    isDarkMode
                                        ? Colors.grey[800]!
                                        : Colors.grey[200]!,
                                width: 1,
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  // 채팅방으로 이동하는 로직 (나중에 구현)
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('채팅방 기능은 추후 업데이트 예정입니다'),
                                      backgroundColor: accentColor,
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: accentColor.withOpacity(
                                                0.15,
                                              ),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              routeIcon,
                                              color: accentColor,
                                              size: 20,
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                routeText,
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: textColor,
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                formattedDate,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color:
                                                      isDarkMode
                                                          ? Colors.grey[400]
                                                          : Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                          Spacer(),
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: accentColor.withOpacity(
                                                0.15,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              '${chatRoom['member_count'] ?? 0}명',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: accentColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 40.0,
                                          top: 8,
                                        ),
                                        child: Text(
                                          chatRoom['last_message'] ?? '메시지 없음',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: textColor.withOpacity(0.8),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                  ),
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
}
