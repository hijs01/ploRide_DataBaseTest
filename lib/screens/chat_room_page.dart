import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ChatRoomPage extends StatefulWidget {
  final String chatRoomId;
  final String chatRoomName;

  const ChatRoomPage({
    Key? key,
    required this.chatRoomId,
    required this.chatRoomName,
  }) : super(key: key);

  @override
  _ChatRoomPageState createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _messageController = TextEditingController();
  String? _currentUserId;
  List<Map<String, dynamic>> _messages = [];
  Map<String, String> _userNames = {};
  List<String> _roomMembers = [];

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    _loadMessages();
    _loadRoomMembers();
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

  void _loadMessages() {
    _firestore
        .collection('psuToAirport')
        .doc(widget.chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .listen((snapshot) async {
          final List<Map<String, dynamic>> messageList = [];

          for (var doc in snapshot.docs) {
            final data = doc.data();
            final senderId = data['senderId'] ?? data['sender_id'] ?? '';
            String senderName = data['sender_name'] ?? '';

            // 시스템 메시지가 아니고 사용자 이름이 없는 경우 이름 가져오기
            if (senderId != 'system' && senderName.isEmpty) {
              senderName = await _getUserName(senderId);
            }

            messageList.add({
              'id': doc.id,
              'text': data['text'] ?? '',
              'senderId': senderId,
              'senderName': senderName,
              'timestamp': data['timestamp'],
              'type': data['type'] ?? 'user',
            });
          }

          setState(() {
            _messages = messageList;
          });
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

      _messageController.clear();
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
      appBar: AppBar(
        backgroundColor: accentColor,
        title: Text(widget.chatRoomName, style: TextStyle(color: Colors.white)),
        automaticallyImplyLeading: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(16),
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
                          color: isDarkMode ? Colors.white70 : Colors.black87,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment:
                      isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    if (!isMe)
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0, bottom: 2.0),
                        child: Text(
                          message['senderName'] ?? '알 수 없는 사용자',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ),
                    Row(
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
                                (message['senderName'] ?? '?')
                                    .substring(0, 1)
                                    .toUpperCase(),
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        Flexible(
                          child: Container(
                            margin: EdgeInsets.only(top: 2, bottom: 2),
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
                        if (formattedTime.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(left: 4, bottom: 4),
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
                  ],
                );
              },
            ),
          ),
          Container(
            padding: EdgeInsets.all(8),
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
                    decoration: InputDecoration(
                      hintText: '메시지를 입력하세요...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor:
                          isDarkMode ? Colors.grey[800] : Colors.grey[200],
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    style: TextStyle(color: textColor),
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
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}
