import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:TAGO/screens/homepage.dart';
import 'package:TAGO/screens/settings_page.dart';
import 'package:TAGO/screens/chat_room_page.dart';
import 'package:TAGO/screens/history_page.dart';
import 'package:intl/intl.dart';
import 'dart:async'; // StreamSubscription을 위한 임포트 추가
import 'package:TAGO/themes/app_themes.dart'; // 앱 테마 가져오기
import 'package:easy_localization/easy_localization.dart';

class ChatPage extends StatefulWidget {
  static const String id = 'chat';

  const ChatPage({super.key});

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  int _selectedIndex = 2; // 현재 Chat 탭이 선택됨
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _currentUserId;
  List<Map<String, dynamic>> _chatRooms = [];
  bool _isLoading = true;
  final List<StreamSubscription> _chatRoomSubscriptions = [];

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    _loadChatRooms();
  }

  @override
  void dispose() {
    // 모든 구독 취소
    for (var subscription in _chatRoomSubscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  void _getCurrentUser() {
    final user = _auth.currentUser;
    if (user != null) {
      setState(() {
        _currentUserId = user.uid;
      });
    }
  }

  Future<void> _loadChatRooms() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (_currentUserId == null) {
        // 사용자 ID가 없으면 로드하지 않음
        setState(() {
          _isLoading = false;
          _chatRooms = [];
        });
        return;
      }

      // 기존 구독 취소
      for (var subscription in _chatRoomSubscriptions) {
        subscription.cancel();
      }
      _chatRoomSubscriptions.clear();

      // driver_accepted가 true이거나 chat_visible이 true인 항목을 가져옴
      final querySnapshot =
          await _firestore
              .collection('users')
              .doc(_currentUserId)
              .collection('chatRooms')
              .get();

      List<Map<String, dynamic>> userChatRooms = [];
      List<Future<void>> processingFutures = [];

      // 각 채팅방에 대한 세부 정보 로드
      for (var doc in querySnapshot.docs) {
        final data = doc.data();

        String chatRoomCollection = data['chat_room_collection'] ?? '';
        String chatRoomId = data['chat_room_id'] ?? '';

        if (chatRoomCollection.isEmpty || chatRoomId.isEmpty) {
          continue; // 필수 정보가 없으면 스킵
        }

        // 실시간 업데이트를 위한 스트림 설정
        var chatRoomStream =
            _firestore
                .collection(chatRoomCollection)
                .doc(chatRoomId)
                .snapshots();

        var subscription = chatRoomStream.listen((docSnapshot) {
          if (docSnapshot.exists) {
            _processRoomUpdate(docSnapshot, data);
          }
        });

        _chatRoomSubscriptions.add(subscription);

        // 초기 데이터도 처리
        processingFutures.add(_processRoom(data));
      }

      // 모든 채팅방 처리 완료 대기
      await Future.wait(processingFutures);

      // 업데이트하지 않으면 로딩 상태만 변경
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('채팅방 로드 오류: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 채팅방 문서 스냅샷 업데이트 처리
  void _processRoomUpdate(
    DocumentSnapshot docSnapshot,
    Map<String, dynamic> userRoomData,
  ) {
    if (!mounted) return;

    try {
      if (!docSnapshot.exists) return;

      final chatRoomData = docSnapshot.data() as Map<String, dynamic>;
      final String chatRoomId = docSnapshot.id;
      final String chatRoomCollection =
          userRoomData['chat_room_collection'] ?? '';

      // 사용자가 실제로 해당 채팅방의 멤버인지 확인
      List<dynamic> members = chatRoomData['members'] ?? [];
      if (!members.contains(_currentUserId)) {
        // 사용자가 멤버가 아니면 채팅방을 표시하지 않음
        setState(() {
          _chatRooms.removeWhere(
            (room) =>
                room['id'] == chatRoomId &&
                room['collection'] == chatRoomCollection,
          );
        });
        return;
      }

      // driver_accepted 또는 chat_visible이 true인지 확인
      bool isVisible =
          chatRoomData['driver_accepted'] == true ||
          chatRoomData['chat_visible'] == true;

      if (isVisible) {
        // 채팅방 데이터 구성 및 업데이트
        Map<String, dynamic> chatRoomInfo = _buildChatRoomInfo(
          chatRoomId,
          chatRoomCollection,
          chatRoomData,
          userRoomData,
        );

        // 기존 채팅방 목록에서 동일한 ID를 가진 채팅방이 있는지 확인
        int existingIndex = _chatRooms.indexWhere(
          (room) =>
              room['id'] == chatRoomId &&
              room['collection'] == chatRoomCollection,
        );

        setState(() {
          if (existingIndex >= 0) {
            // 기존 채팅방 업데이트
            _chatRooms[existingIndex] = chatRoomInfo;
          } else {
            // 새 채팅방 추가
            _chatRooms.add(chatRoomInfo);
          }

          // 마지막 메시지 시간 기준으로 정렬 (최신순)
          _chatRooms.sort((a, b) {
            final aTime = (a['timestamp'] as Timestamp).toDate();
            final bTime = (b['timestamp'] as Timestamp).toDate();
            return bTime.compareTo(aTime); // 내림차순 정렬 (최신이 위로)
          });
        });
      } else {
        // 표시되지 않아야 하는 채팅방은 목록에서 제거
        setState(() {
          _chatRooms.removeWhere(
            (room) =>
                room['id'] == chatRoomId &&
                room['collection'] == chatRoomCollection,
          );
        });
      }
    } catch (e) {
      print('채팅방 업데이트 처리 오류: $e');
    }
  }

  // 초기 채팅방 목록 처리
  Future<void> _processRoom(Map<String, dynamic> userRoomData) async {
    try {
      String chatRoomCollection = userRoomData['chat_room_collection'] ?? '';
      String chatRoomId = userRoomData['chat_room_id'] ?? '';

      // 원본 채팅방 정보 가져오기
      final chatRoomDoc =
          await _firestore.collection(chatRoomCollection).doc(chatRoomId).get();

      if (chatRoomDoc.exists) {
        final chatRoomData = chatRoomDoc.data() as Map<String, dynamic>;

        // 사용자가 실제로 해당 채팅방의 멤버인지 확인
        List<dynamic> members = chatRoomData['members'] ?? [];
        if (!members.contains(_currentUserId)) {
          // 사용자가 멤버가 아니면 채팅방을 표시하지 않음
          return;
        }

        // driver_accepted 또는 chat_visible이 true인지 확인
        bool isVisible =
            chatRoomData['driver_accepted'] == true ||
            chatRoomData['chat_visible'] == true;

        if (isVisible) {
          // 채팅방 데이터 구성
          Map<String, dynamic> chatRoomInfo = _buildChatRoomInfo(
            chatRoomId,
            chatRoomCollection,
            chatRoomData,
            userRoomData,
          );

          if (mounted) {
            setState(() {
              // 기존에 같은 ID를 가진 채팅방이 있는지 확인하고 업데이트 또는 추가
              int existingIndex = _chatRooms.indexWhere(
                (room) =>
                    room['id'] == chatRoomId &&
                    room['collection'] == chatRoomCollection,
              );

              if (existingIndex >= 0) {
                _chatRooms[existingIndex] = chatRoomInfo;
              } else {
                _chatRooms.add(chatRoomInfo);
              }

              // 마지막 메시지 시간 기준으로 정렬 (최신순)
              _chatRooms.sort((a, b) {
                final aTime = (a['timestamp'] as Timestamp).toDate();
                final bTime = (b['timestamp'] as Timestamp).toDate();
                return bTime.compareTo(aTime); // 내림차순 정렬 (최신이 위로)
              });
            });
          }
        }
      }
    } catch (e) {
      print('채팅방 세부 정보 로드 오류: $e');
    }
  }

  // 채팅방 정보 구성 헬퍼 함수
  Map<String, dynamic> _buildChatRoomInfo(
    String chatRoomId,
    String chatRoomCollection,
    Map<String, dynamic> chatRoomData,
    Map<String, dynamic> userRoomData,
  ) {
    // 기본 채팅방 데이터 구성
    Map<String, dynamic> chatRoomInfo = {
      'id': chatRoomId,
      'collection': chatRoomCollection,
      'name': chatRoomId.split('_').first.toUpperCase(), // ID의 첫 부분을 대문자로
      'origin': chatRoomCollection == 'psuToAirport' ? 'PSU' : '공항',
      'destination': chatRoomCollection == 'psuToAirport' ? '공항' : 'PSU',
      'memberCount': chatRoomData['member_count'] ?? 0,
      'maxMembers': 4,
      'isConfirmed': chatRoomData['driver_accepted'] ?? false,
      'departureTime': chatRoomData['ride_date_timestamp'] ?? Timestamp.now(),
      'lastMessage': chatRoomData['last_message'] ?? '',
      'timestamp': chatRoomData['last_message_time'] ?? Timestamp.now(),
      'hasNewMessages': false, // 기본값
      'chat_visible':
          chatRoomData['chat_visible'] ?? userRoomData['chat_visible'] ?? false,
      'driver_accepted':
          chatRoomData['driver_accepted'] ??
          userRoomData['driver_accepted'] ??
          false,
    };

    // 출발지와 목적지 정보 설정
    if (chatRoomData.containsKey('pickup_info') &&
        chatRoomData.containsKey('destination_info')) {
      final pickupInfo = chatRoomData['pickup_info'] as Map<String, dynamic>;
      final destInfo = chatRoomData['destination_info'] as Map<String, dynamic>;

      String pickupAddress = pickupInfo['address'] as String? ?? '출발지';
      String destAddress = destInfo['address'] as String? ?? '목적지';

      chatRoomInfo['origin'] = pickupAddress;
      chatRoomInfo['destination'] = destAddress;
    }

    return chatRoomInfo;
  }

  void _onItemTapped(int index) {
    setState(() {
      if (index != _selectedIndex) {
        if (index == 0 || index == 1) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder:
                  (context, animation, secondaryAnimation) =>
                      index == 0 ? HomePage() : HistoryPage(),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ),
          );
        } else if (index == 3) {
          Navigator.pushReplacement(
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
    final accentColor = Color(0xFF3F51B5); // 인디고 색상으로 통일
    final secondaryColor = Color(0xFF8BC34A);

    return WillPopScope(
      onWillPop: () async {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => HomePage(),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
        return false;
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: isDarkMode ? Colors.black : Colors.white,
          title: Text(
            'app.chat.title'.tr(),
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          elevation: 0,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: Icon(
                Icons.refresh,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
              onPressed: _loadChatRooms,
            ),
          ],
        ),
        body:
            _isLoading
                ? Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                  ),
                )
                : _chatRooms.isEmpty
                ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 64,
                        color: textColor.withOpacity(0.5),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'app.chat.no_chats'.tr(),
                        style: TextStyle(
                          fontSize: 18,
                          color: textColor.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                )
                : ListView.builder(
                  itemCount: _chatRooms.length,
                  padding: EdgeInsets.symmetric(vertical: 8),
                  itemBuilder: (context, index) {
                    final chatRoom = _chatRooms[index];
                    return _buildChatRoomCard(
                      context,
                      chatRoom,
                      cardColor,
                      textColor,
                      accentColor,
                      secondaryColor,
                    );
                  },
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

  Widget _buildChatRoomCard(
    BuildContext context,
    Map<String, dynamic> chatRoom,
    Color cardColor,
    Color textColor,
    Color accentColor,
    Color secondaryColor,
  ) {
    final departureTime = (chatRoom['departureTime'] as Timestamp).toDate();
    final formattedDate = DateFormat('MMM d', 'en_US').format(departureTime);
    final formattedTime = DateFormat('HH:mm').format(departureTime);

    // Pre-translate strings to avoid issues
    final membersText = 'app.chat.members'.tr();
    final acceptedText = 'app.chat.status.accepted'.tr();
    final pendingText = 'app.chat.status.pending'.tr();
    final pickupText = 'app.chat.pickup'.tr();
    final dropoffText = 'app.chat.dropoff'.tr();
    final noMessagesText = 'app.chat.no_messages'.tr();
    final timeAgoText = _formatTimestamp(chatRoom['timestamp']);

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: cardColor,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => ChatRoomPage(
                    chatRoomId: chatRoom['id'],
                    chatRoomName: chatRoom['name'],
                    chatRoomCollection: chatRoom['collection'],
                  ),
            ),
          );
        },
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row with status and time
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Status badge
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color:
                          chatRoom['isConfirmed']
                              ? secondaryColor
                              : Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      chatRoom['isConfirmed'] ? acceptedText : pendingText,
                      style: TextStyle(
                        color:
                            chatRoom['isConfirmed']
                                ? Colors.white
                                : textColor.withOpacity(0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),

                  // Time information - simplified
                  Text(
                    '$formattedDate $formattedTime',
                    style: TextStyle(
                      color: textColor.withOpacity(0.7),
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),

                  Spacer(),

                  // Member count
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${chatRoom['memberCount']}/${chatRoom['maxMembers']}$membersText',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.trip_origin, color: accentColor, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$pickupText: ${chatRoom['origin']}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on, color: accentColor, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$dropoffText: ${chatRoom['destination']}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      chatRoom['lastMessage'] ?? noMessagesText,
                      style: TextStyle(
                        color: textColor.withOpacity(0.7),
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    timeAgoText,
                    style: TextStyle(
                      color: textColor.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                  if (chatRoom['hasNewMessages'] == true)
                    Container(
                      margin: EdgeInsets.only(left: 8),
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final messageTime = timestamp.toDate();
    final difference = now.difference(messageTime);

    if (difference.inDays > 0) {
      return 'app.chat.time_ago.days_ago'.tr(
        args: [difference.inDays.toString()],
        namedArgs: {'days': difference.inDays.toString()},
      );
    } else if (difference.inHours > 0) {
      return 'app.chat.time_ago.hours_ago'.tr(
        args: [difference.inHours.toString()],
        namedArgs: {'hours': difference.inHours.toString()},
      );
    } else if (difference.inMinutes > 0) {
      return 'app.chat.time_ago.minutes_ago'.tr(
        args: [difference.inMinutes.toString()],
        namedArgs: {'minutes': difference.inMinutes.toString()},
      );
    } else {
      return 'app.chat.time_ago.just_now'.tr();
    }
  }
}
