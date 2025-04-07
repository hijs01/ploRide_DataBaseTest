import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async'; // StreamSubscription을 위해 추가

class ChatRoomPage extends StatefulWidget {
  final String chatRoomId;
  final String chatRoomName;

  const ChatRoomPage({
    super.key,
    required this.chatRoomId,
    required this.chatRoomName,
  });

  @override
  _ChatRoomPageState createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage>
    with WidgetsBindingObserver {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  String? _currentUserId;
  List<Map<String, dynamic>> _messages = [];
  final Map<String, String> _userNames = {};
  List<String> _roomMembers = [];
  bool _disposed = false; // 위젯 dispose 상태 체크
  StreamSubscription? _messageSubscription; // 메시지 스트림 구독 관리

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    _loadMessages();
    _loadRoomMembers();

    // 키보드 상태 변경 감지를 위해 observer 등록
    WidgetsBinding.instance.addObserver(this);

    // 포커스 변경 감지
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        // 포커스를 받으면 즉시 스크롤을 아래로 이동
        _scrollToBottom();
      }
    });
  }

  @override
  void setState(VoidCallback fn) {
    if (!_disposed && mounted) {
      super.setState(fn);
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // 키보드가 나타날 때 스크롤을 아래로 이동
    if (MediaQuery.of(context).viewInsets.bottom > 0) {
      // 키보드가 나타났을 때
      _scrollToBottom();
    }
  }

  void _getCurrentUser() {
    final user = _auth.currentUser;
    if (user != null) {
      setState(() {
        _currentUserId = user.uid;
      });
    }
  }

  // 채팅방 멤버 목록 로드
  Future<void> _loadRoomMembers() async {
    try {
      final roomDoc =
          await _firestore
              .collection('psuToAirport')
              .doc(widget.chatRoomId)
              .get();

      if (roomDoc.exists) {
        final data = roomDoc.data();
        if (data != null && data.containsKey('members')) {
          setState(() {
            _roomMembers = List<String>.from(data['members']);
          });
        }
      }
    } catch (e) {
      print('Error loading room members: $e');
    }
  }

  Future<String> _getUserName(String userId) async {
    if (_userNames.containsKey(userId)) {
      return _userNames[userId]!;
    }

    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        final userName = userData?['fullname'] ?? '알 수 없는 사용자';
        _userNames[userId] = userName;
        return userName;
      }
    } catch (e) {
      print('사용자 이름 조회 오류: $e');
    }

    return '알 수 없는 사용자';
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  void _loadMessages() {
    _messageSubscription?.cancel(); // 기존 구독 취소

    _messageSubscription = _firestore
        .collection('psuToAirport')
        .doc(widget.chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .listen((snapshot) async {
          if (!mounted || _disposed) return; // 위젯이 dispose된 경우 리턴

          final List<Map<String, dynamic>> messageList = [];

          for (var doc in snapshot.docs) {
            final data = doc.data();
            final senderId = data['senderId'] ?? data['sender_id'] ?? '';
            String senderName = '';

            // 시스템 메시지가 아닌 경우 사용자 이름 가져오기
            if (senderId != 'system') {
              try {
                final userDoc =
                    await _firestore.collection('users').doc(senderId).get();
                if (userDoc.exists) {
                  final userData = userDoc.data();
                  senderName = userData?['fullname'] ?? '알 수 없는 사용자';
                }
              } catch (e) {
                print('사용자 이름 조회 오류: $e');
                senderName = '알 수 없는 사용자';
              }
            }

            // 시스템 메시지인 경우 텍스트에서 사용자 이름을 실제 이름으로 대체
            String messageText = data['text'] ?? '';
            if (senderId == 'system' && messageText.contains('님이 그룹에 참여했습니다')) {
              final userId = data['userId'] ?? '';
              if (userId.isNotEmpty) {
                try {
                  final userDoc =
                      await _firestore.collection('users').doc(userId).get();
                  if (userDoc.exists) {
                    final userData = userDoc.data();
                    final fullname = userData?['fullname'] ?? '알 수 없는 사용자';
                    messageText = messageText.replaceAll('이름 없음', fullname);
                  }
                } catch (e) {
                  print('시스템 메시지 사용자 이름 조회 오류: $e');
                }
              }
            }

            messageList.add({
              'id': doc.id,
              'text': messageText,
              'senderId': senderId,
              'senderName': senderName,
              'timestamp': data['timestamp'],
              'type': data['type'] ?? 'user',
              'userId': data['userId'],
            });
          }

          if (mounted && !_disposed) {
            setState(() {
              _messages = messageList;
            });

            // 새 메시지가 추가될 때마다 스크롤을 아래로 이동
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_disposed) {
                _scrollToBottom();
              }
            });
          }
        });
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final dateTime = timestamp.toDate();
    return DateFormat('HH:mm').format(dateTime);
  }

  // 다른 채팅방 멤버들에게 알림 보내기
  Future<void> _sendNotificationToOtherMembers(String messageText) async {
    try {
      // 현재 사용자는 제외하고 알림 보내기
      final otherMembers =
          _roomMembers.where((uid) => uid != _currentUserId).toList();

      if (otherMembers.isEmpty) return;

      final user = _auth.currentUser;
      String senderName = user?.displayName ?? '알 수 없는 사용자';

      // 사용자 프로필에서 이름 가져오기
      try {
        final userDoc =
            await _firestore.collection('users').doc(_currentUserId).get();
        if (userDoc.exists) {
          final userData = userDoc.data();
          senderName = userData?['fullname'] ?? senderName;
        }
      } catch (e) {
        print('사용자 이름 조회 오류: $e');
      }

      // Cloud Function을 호출하여 알림 전송
      final url =
          'https://us-central1-geetaxi-aa379.cloudfunctions.net/sendChatNotification';

      final requestData = {
        'chatRoomId': widget.chatRoomId,
        'chatRoomName': widget.chatRoomName,
        'messageText': messageText,
        'senderName': senderName,
        'senderId': _currentUserId,
        'receiverIds': otherMembers,
      };

      final response = await http.post(
        Uri.parse(url),
        body: jsonEncode(requestData),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        print('채팅 알림 전송 성공');
      } else {
        print('채팅 알림 전송 실패: ${response.statusCode}, ${response.body}');
      }
    } catch (e) {
      print('채팅 알림 전송 중 오류 발생: $e');
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final messageText = _messageController.text.trim();
    final user = _auth.currentUser;
    final displayName = user?.displayName ?? '알 수 없는 사용자';

    // 메시지 전송 전에 텍스트 필드 초기화
    _messageController.clear();

    final message = {
      'text': messageText,
      'senderId': _currentUserId,
      'sender_name': displayName,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'user',
    };

    try {
      await _firestore
          .collection('psuToAirport')
          .doc(widget.chatRoomId)
          .collection('messages')
          .add(message);

      // 마지막 메시지 업데이트
      await _firestore.collection('psuToAirport').doc(widget.chatRoomId).update(
        {'lastMessage': messageText, 'timestamp': FieldValue.serverTimestamp()},
      );

      // 다른 멤버들에게 알림 전송
      await _sendNotificationToOtherMembers(messageText);

      // 메시지 전송 후 스크롤을 아래로 이동
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      print('Error sending message: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final backgroundColor = isDarkMode ? Colors.black : Colors.white;
    final messageColor = isDarkMode ? Color(0xFF1E1E1E) : Colors.white;
    final accentColor = Color(0xFF3F51B5);
    final systemMessageColor = isDarkMode ? Colors.grey[800] : Colors.grey[300];

    return Scaffold(
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: accentColor,
        title: Text(widget.chatRoomName, style: TextStyle(color: Colors.white)),
        automaticallyImplyLeading: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  // 키보드를 닫기 위해 포커스를 해제
                  FocusScope.of(context).unfocus();
                },
                child: ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: 8,
                  ),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    final isMe = message['senderId'] == _currentUserId;
                    final isSystem =
                        message['senderId'] == 'system' ||
                        message['type'] == 'system';
                    final timestamp = message['timestamp'] as Timestamp?;
                    final formattedTime = _formatTimestamp(timestamp);

                    if (isSystem) {
                      // 시스템 메시지 UI
                      return Center(
                        child: Container(
                          margin: EdgeInsets.symmetric(vertical: 10),
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: systemMessageColor,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Text(
                            message['text'],
                            style: TextStyle(
                              color:
                                  isDarkMode ? Colors.white70 : Colors.black87,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    }

                    return Column(
                      crossAxisAlignment:
                          isMe
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                      children: [
                        if (!isMe)
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 8.0,
                              bottom: 2.0,
                            ),
                            child: Text(
                              message['senderName'] ?? '알 수 없는 사용자',
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    isDarkMode
                                        ? Colors.white70
                                        : Colors.black54,
                              ),
                            ),
                          ),
                        Container(
                          margin: EdgeInsets.only(
                            bottom: isMe ? 4 : 8,
                            right: isMe ? 0 : 0,
                            left: isMe ? 0 : 0,
                          ),
                          child: Row(
                            mainAxisAlignment:
                                isMe
                                    ? MainAxisAlignment.end
                                    : MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (!isMe)
                                Container(
                                  margin: EdgeInsets.only(right: 4),
                                  child: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: Colors.grey[400],
                                    child: Text(
                                      _getInitials(
                                        message['senderName'] ?? '?',
                                      ),
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ),
                              if (isMe && formattedTime.isNotEmpty)
                                Padding(
                                  padding: EdgeInsets.only(right: 2, bottom: 2),
                                  child: Text(
                                    formattedTime,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color:
                                          isDarkMode
                                              ? Colors.white54
                                              : Colors.black54,
                                    ),
                                  ),
                                ),
                              if (isMe)
                                SizedBox(
                                  width: 40,
                                ), // 자신의 메시지를 오른쪽으로 더 밀기 위한 공간
                              Flexible(
                                child: Container(
                                  margin: EdgeInsets.only(
                                    top: 2,
                                    bottom: 2,
                                    left: isMe ? 0 : 4,
                                    right: isMe ? 0 : 0,
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isMe ? accentColor : messageColor,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    message['text'],
                                    style: TextStyle(
                                      color: isMe ? Colors.white : textColor,
                                    ),
                                  ),
                                ),
                              ),
                              if (!isMe && formattedTime.isNotEmpty)
                                Padding(
                                  padding: EdgeInsets.only(left: 2, bottom: 2),
                                  child: Text(
                                    formattedTime,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color:
                                          isDarkMode
                                              ? Colors.white54
                                              : Colors.black54,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDarkMode ? Color(0xFF1E1E1E) : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      focusNode: _focusNode,
                      decoration: InputDecoration(
                        hintText: '메시지를 입력하세요...',
                        hintStyle: TextStyle(
                          color: isDarkMode ? Colors.white70 : Colors.grey[600],
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor:
                            isDarkMode ? Colors.grey[800] : Colors.grey[200],
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        isDense: true,
                      ),
                      style: TextStyle(color: textColor),
                      onTap: () {
                        // 텍스트 필드 터치 시 즉시 스크롤을 아래로 이동
                        _scrollToBottom();
                      },
                    ),
                  ),
                  SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: accentColor,
                    child: IconButton(
                      icon: Icon(Icons.send, color: Colors.white),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _messageSubscription?.cancel(); // 메시지 스트림 구독 취소
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 사용자 이름의 이니셜을 반환하는 헬퍼 함수
  String _getInitials(String name) {
    if (name.isEmpty || name == '?') return '?';
    return name.substring(0, 1).toUpperCase();
  }
}
