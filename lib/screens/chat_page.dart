import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cabrider/screens/homepage.dart';
import 'package:cabrider/screens/settings_page.dart';
import 'package:cabrider/screens/chat_room_page.dart';
import 'package:intl/intl.dart';

class ChatPage extends StatefulWidget {
  static const String id = 'chat';

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

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    _loadChatRooms();
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
      final snapshot = await _firestore.collection('psuToAirport').get();
      final chatRooms =
          snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'name': doc.id.toUpperCase(),
              'origin': data['origin'] ?? 'PSU',
              'destination': data['destination'] ?? '공항',
              'memberCount': data['memberCount'] ?? 1,
              'maxMembers': data['maxMembers'] ?? 4,
              'isConfirmed': data['isConfirmed'] ?? false,
              'departureTime': data['departureTime'] ?? Timestamp.now(),
              'lastMessage': data['lastMessage'] ?? '',
              'timestamp': data['timestamp'] ?? Timestamp.now(),
              'hasNewMessages': data['hasNewMessages'] ?? false,
              'lastReadMessageId': data['lastReadMessageId'] ?? '',
            };
          }).toList();

      setState(() {
        _chatRooms = chatRooms;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading chat rooms: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      if (index != _selectedIndex) {
        if (index == 0 || index == 1) {
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
    final backgroundColor = isDarkMode ? Color(0xFF121212) : Color(0xFFF5F5F5);
    final cardColor = isDarkMode ? Color(0xFF1E1E1E) : Colors.white;
    final accentColor = Color(0xFF3F51B5);
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
          backgroundColor: accentColor,
          title: Text(
            '채팅방',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          elevation: 0,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: Icon(Icons.refresh, color: Colors.white),
              onPressed: _loadChatRooms,
            ),
          ],
        ),
        body:
            _isLoading
                ? Center(child: CircularProgressIndicator())
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
                        '채팅방이 없습니다',
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
            BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
            BottomNavigationBarItem(icon: Icon(Icons.history), label: '히스토리'),
            BottomNavigationBarItem(icon: Icon(Icons.chat), label: '채팅'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: '프로필'),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: accentColor,
          unselectedItemColor: isDarkMode ? Colors.grey[600] : Colors.grey,
          backgroundColor: isDarkMode ? Color(0xFF1E1E1E) : Colors.white,
          showSelectedLabels: true,
          showUnselectedLabels: true,
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
    final formattedDate = DateFormat('M월 d일').format(departureTime);
    final formattedTime = DateFormat('HH:mm').format(departureTime);

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
                  ),
            ),
          );
        },
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // 확정 여부 표시
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
                      chatRoom['isConfirmed'] ? '확정됨' : '미확정',
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

                  // 출발 시간 표시
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: textColor.withOpacity(0.7),
                  ),
                  SizedBox(width: 4),
                  Text(
                    '$formattedDate $formattedTime',
                    style: TextStyle(
                      color: textColor.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),

                  Spacer(),

                  // 인원 표시
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${chatRoom['memberCount']}/${chatRoom['maxMembers']}명',
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

              // 경로 정보
              Row(
                children: [
                  Icon(Icons.location_on, color: accentColor, size: 20),
                  SizedBox(width: 8),
                  Text(
                    '${chatRoom['origin']} → ${chatRoom['destination']}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 12),

              // 마지막 메시지 정보
              Row(
                children: [
                  Expanded(
                    child: Text(
                      chatRoom['lastMessage'] ?? '대화가 시작되지 않았습니다',
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
                    _formatTimestamp(chatRoom['timestamp']),
                    style: TextStyle(
                      color: textColor.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),

                  // 새 메시지 표시
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
      return '${difference.inDays}일 전';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}시간 전';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}분 전';
    } else {
      return '방금';
    }
  }
}
