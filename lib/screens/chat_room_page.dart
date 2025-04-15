import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class ChatRoomPage extends StatefulWidget {
  final String chatRoomId;
  final String chatRoomName;
  final String chatRoomCollection;

  const ChatRoomPage({
    super.key,
    required this.chatRoomId,
    required this.chatRoomName,
    this.chatRoomCollection = 'psuToAirport',
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String? _currentUserId;
  Map<String, dynamic>? _chatRoomData;
  bool _isLoading = true;
  bool _isSending = false;
  StreamSubscription? _chatRoomSubscription;
  StreamSubscription? _messagesSubscription;
  List<QueryDocumentSnapshot> _messages = [];
  final Map<String, String> _userNames = {};
  List<String> _roomMembers = [];
  String? _pickupAddress;
  String? _destinationAddress;
  bool _hasMoreMessages = true;
  DocumentSnapshot? _lastDocument;
  static const int _messageLimit = 20;

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    _loadInitialMessages();
    _loadRoomMembers();
    _loadChatRoomData();
    _setupRealtimeUpdates();

    // 키보드 상태 변경 감지를 위해 observer 등록
    WidgetsBinding.instance.addObserver(this);

    // 포커스 변경 감지
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        // 포커스를 받으면 즉시 스크롤을 아래로 이동
        _scrollToBottom();
      }
    });

    // 스크롤 리스너 추가
    _scrollController.addListener(_onScroll);
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
              .collection(widget.chatRoomCollection)
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
    if (userId.isEmpty) {
      return '알 수 없는 사용자';
    }

    if (_userNames.containsKey(userId)) {
      return _userNames[userId]!;
    }

    try {
      // 먼저 drivers 컬렉션에서 확인
      final driverDoc = await _firestore.collection('drivers').doc(userId).get();
      if (driverDoc.exists) {
        final driverData = driverDoc.data();
        final driverName = driverData?['fullname'] ?? '알 수 없는 사용자';
        _userNames[userId] = driverName;
        return driverName;
      }

      // drivers 컬렉션에 없으면 users 컬렉션에서 확인
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

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _loadMoreMessages();
    }
  }

  Future<void> _loadInitialMessages() async {
    try {
      final querySnapshot =
          await _firestore
              .collection(widget.chatRoomCollection)
              .doc(widget.chatRoomId)
              .collection('messages')
              .orderBy('timestamp', descending: true)
              .limit(_messageLimit)
              .get();

      if (querySnapshot.docs.isNotEmpty) {
        _lastDocument = querySnapshot.docs.last;
        _hasMoreMessages = querySnapshot.docs.length >= _messageLimit;

        // 메시지를 시간순으로 정렬
        final messages = querySnapshot.docs.reversed.toList();

        // 사용자 정보 일괄 로드
        await _loadUserNames(messages);

        setState(() {
          _messages = messages;
          _isLoading = false;
        });

        // 새 메시지가 추가될 때마다 스크롤을 아래로 이동
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
      }
    } catch (e) {
      print('Error loading initial messages: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreMessages() async {
    if (!_hasMoreMessages || _isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final querySnapshot =
          await _firestore
              .collection(widget.chatRoomCollection)
              .doc(widget.chatRoomId)
              .collection('messages')
              .orderBy('timestamp', descending: true)
              .startAfterDocument(_lastDocument!)
              .limit(_messageLimit)
              .get();

      if (querySnapshot.docs.isNotEmpty) {
        _lastDocument = querySnapshot.docs.last;
        _hasMoreMessages = querySnapshot.docs.length >= _messageLimit;

        // 메시지를 시간순으로 정렬
        final newMessages = querySnapshot.docs.reversed.toList();

        // 사용자 정보 일괄 로드
        await _loadUserNames(newMessages);

        setState(() {
          _messages.insertAll(0, newMessages);
          _isLoading = false;
        });
      } else {
        setState(() {
          _hasMoreMessages = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading more messages: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUserNames(List<QueryDocumentSnapshot> messages) async {
    final Set<String> userIds = {};

    // 메시지에서 사용자 ID 수집
    for (var doc in messages) {
      final data = doc.data() as Map<String, dynamic>;
      final senderId = data['sender_id'] ?? '';
      if (senderId != 'system' &&
          senderId.isNotEmpty &&
          !_userNames.containsKey(senderId)) {
        userIds.add(senderId);
      }
    }

    if (userIds.isEmpty) return;

    try {
      // 일괄 사용자 정보 조회
      final userDocs = await Future.wait(
        userIds.map(
          (userId) => _firestore.collection('users').doc(userId).get(),
        ),
      );

      for (var doc in userDocs) {
        if (doc.exists) {
          final userData = doc.data();
          _userNames[doc.id] = userData?['fullname'] ?? '알 수 없는 사용자';
        }
      }
    } catch (e) {
      print('Error loading user names: $e');
    }
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

    // 메시지 전송 전에 텍스트 필드 초기화
    _messageController.clear();

    final message = {
      'text': messageText,
      'sender_id': _currentUserId,
      'sender_name': senderName,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'user',
    };

    try {
      await _firestore
          .collection(widget.chatRoomCollection)
          .doc(widget.chatRoomId)
          .collection('messages')
          .add(message);

      // 마지막 메시지 업데이트
      try {
        await _firestore
            .collection(widget.chatRoomCollection)
            .doc(widget.chatRoomId)
            .update({
              'lastMessage': messageText,
              'last_message': messageText,
              'last_message_time': FieldValue.serverTimestamp(),
              'timestamp': FieldValue.serverTimestamp(),
            });
        print('메시지 업데이트 성공: last_message = $messageText');
      } catch (e) {
        print('메시지 업데이트 실패: $e');
      }

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
      key: _scaffoldKey,
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: accentColor,
        title: _buildAppBarTitle(),
        automaticallyImplyLeading: true,
        actions: [
          IconButton(
            icon: Icon(Icons.menu),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
      ),
      endDrawer: Drawer(
        child: Column(
          children: [
            AppBar(title: Text('채팅방 정보'), automaticallyImplyLeading: false),
            Expanded(
              child: StreamBuilder<DocumentSnapshot>(
                stream: _firestore
                    .collection(widget.chatRoomCollection)
                    .doc(widget.chatRoomId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    print('StreamBuilder error: ${snapshot.error}');
                    return Center(
                      child: Text(
                        '채팅방 정보를 불러오는 중 오류가 발생했습니다.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }

                  try {
                    final data = snapshot.data!.data() as Map<String, dynamic>;
                    final users = data['members'] as List<dynamic>? ?? [];
                    final driver = data['driver_id'] as String? ?? '';

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            '참여자 목록',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        FutureBuilder<String>(
                          future: _getUserName(driver),
                          builder: (context, snapshot) {
                            return ListTile(
                              leading: CircleAvatar(child: Icon(Icons.person)),
                              title: Text('드라이버'),
                              subtitle: Text(snapshot.data ?? '로딩 중...'),
                            );
                          },
                        ),
                        Divider(),
                        Expanded(
                          child: ListView.builder(
                            itemCount: users.length,
                            itemBuilder: (context, index) {
                              return FutureBuilder<String>(
                                future: _getUserName(users[index]),
                                builder: (context, snapshot) {
                                  return ListTile(
                                    leading: CircleAvatar(
                                      child: Icon(Icons.person),
                                    ),
                                    title: Text('승객 ${index + 1}'),
                                    subtitle: Text(snapshot.data ?? '로딩 중...'),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        // 예상 가격 표시
                        Container(
                          padding: EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '예상 가격',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                users.length <= 2 ? '\$500' : 
                                users.length == 3 ? '\$440' : '\$500',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: accentColor,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '${users.length}명 기준',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: ElevatedButton(
                            onPressed: () => _showExitDialog(context),
                            style: ElevatedButton.styleFrom(
                              minimumSize: Size(double.infinity, 50),
                            ),
                            child: Text('채팅방 나가기'),
                          ),
                        ),
                      ],
                    );
                  } catch (e) {
                    print('Error loading chat room data: $e');
                    return Center(
                      child: Text(
                        '채팅방 정보를 불러오는 중 오류가 발생했습니다.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
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
                    final messageData = message.data() as Map<String, dynamic>;
                    final isMe = messageData['sender_id'] == _currentUserId;
                    final isSystem =
                        messageData['sender_id'] == 'system' ||
                        messageData['type'] == 'system';
                    final timestamp = messageData['timestamp'] as Timestamp?;
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
                            messageData['text'] ?? '',
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
                              left: 5.0,
                              bottom: 1.0,
                              top: 4.0,
                            ),
                            child: Text(
                              messageData['sender_name'] ?? '알 수 없는 사용자',
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    isDarkMode
                                        ? Colors.white70
                                        : Colors.black54,
                              ),
                              textAlign: TextAlign.left,
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
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(4),
                                          child: Text(
                                            (messageData['sender_name'] ?? '?')
                                                .substring(0, 1)
                                                .toUpperCase(),
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              height: 1,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              if (isMe)
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
                              Flexible(
                                child: Container(
                                  margin: EdgeInsets.only(
                                    top: 2,
                                    bottom: 2,
                                    left: isMe ? 0 : 4,
                                    right: isMe ? 0 : 4,
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
                                    messageData['text'],
                                    style: TextStyle(
                                      color: isMe ? Colors.white : textColor,
                                    ),
                                  ),
                                ),
                              ),
                              if (!isMe)
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
    _messageController.dispose();
    _scrollController.dispose();
    // 리스너 정리
    if (_chatRoomSubscription != null) {
      _chatRoomSubscription!.cancel();
    }
    if (_messagesSubscription != null) {
      _messagesSubscription!.cancel();
    }
    _focusNode.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // setState 호출을 안전하게 만드는 헬퍼 메서드
  void _safeSetState(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  // 메시지 전송 후 상태 업데이트
  void _updateAfterMessageSend() {
    _safeSetState(() {
      _isSending = false;
    });
  }

  // 채팅방 상태 업데이트
  void _updateChatRoomState(Map<String, dynamic> data) {
    _safeSetState(() {
      _chatRoomData = data;
      _isLoading = false;
    });
  }

  // 메시지 목록 업데이트
  void _updateMessages(List<QueryDocumentSnapshot> messages) {
    _safeSetState(() {
      _messages = messages;
      _isLoading = false;
    });
  }

  // 채팅방 데이터 로드
  Future<void> _loadChatRoomData() async {
    try {
      final roomDoc =
          await _firestore
              .collection(widget.chatRoomCollection)
              .doc(widget.chatRoomId)
              .get();

      if (roomDoc.exists) {
        final data = roomDoc.data();
        if (data != null) {
          setState(() {
            _chatRoomData = data;

            // 픽업 정보와 목적지 정보 가져오기
            if (data.containsKey('pickup_info')) {
              final pickupInfo = data['pickup_info'] as Map<String, dynamic>;
              _pickupAddress = pickupInfo['address'] as String?;
            }

            if (data.containsKey('destination_info')) {
              final destInfo = data['destination_info'] as Map<String, dynamic>;
              _destinationAddress = destInfo['address'] as String?;
            }
          });
        }
      }
    } catch (e) {
      print('Error loading chat room data: $e');
    }
  }

  Widget _buildAppBarTitle() {
    // 채팅방 이름에서 출발지와 목적지를 추출
    String departure = '';
    String destination = '';

    // '_'로 분리 시도
    List<String> parts = widget.chatRoomName.split('_');

    if (parts.length >= 2) {
      // '_'로 분리된 경우
      departure = parts[0];
      destination = parts[1];
    } else {
      // '_'로 분리되지 않은 경우
      // 채팅방 컬렉션에 따라 기본값 설정
      if (widget.chatRoomCollection == 'psuToAirport') {
        departure = _pickupAddress ?? 'PSU';
        destination = _destinationAddress ?? '공항';
      } else if (widget.chatRoomCollection == 'airportToPsu') {
        departure = _pickupAddress ?? '공항';
        destination = _destinationAddress ?? 'PSU';
      } else {
        // 기본값
        departure = _pickupAddress ?? '출발지';
        destination = _destinationAddress ?? '목적지';
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            departure,
            style: TextStyle(color: Colors.white, fontSize: 14),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Icon(Icons.arrow_forward, color: Colors.white, size: 16),
        ),
        Flexible(
          child: Text(
            destination,
            style: TextStyle(color: Colors.white, fontSize: 14),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  void _setupRealtimeUpdates() {
    _messagesSubscription = _firestore
        .collection(widget.chatRoomCollection)
        .doc(widget.chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) async {
          if (snapshot.docs.isNotEmpty) {
            final latestMessage = snapshot.docs.first;
            final latestMessageData = latestMessage.data();
            final latestTimestamp =
                latestMessageData['timestamp'] as Timestamp?;

            // 현재 메시지 목록의 마지막 메시지와 비교
            if (_messages.isEmpty ||
                (latestTimestamp != null &&
                    latestTimestamp.millisecondsSinceEpoch >
                        (_messages.last.data()
                                as Map<String, dynamic>)['timestamp']
                            .millisecondsSinceEpoch)) {
              // 새로운 메시지가 있는 경우
              final newMessage = latestMessage;
              await _loadUserNames([newMessage]);

              setState(() {
                _messages.add(newMessage);
              });

              // 새 메시지가 추가될 때 스크롤을 아래로 이동
              _scrollToBottom();
            }
          }
        });
  }

  void _showExitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('채팅방 나가기'),
        content: Text('채팅방을 나가시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final user = _auth.currentUser;
                if (user == null) {
                  Navigator.pop(context);
                  return;
                }

                // 사용자의 이름 가져오기
                final userDoc = await _firestore.collection('users').doc(user.uid).get();
                final userName = userDoc.data()?['fullname'] ?? '알 수 없는 사용자';

                // 시스템 메시지 추가
                await _firestore
                    .collection(widget.chatRoomCollection)
                    .doc(widget.chatRoomId)
                    .collection('messages')
                    .add({
                      'text': '$userName님이 그룹에서 나갔습니다.',
                      'sender_id': 'system',
                      'type': 'system',
                      'timestamp': FieldValue.serverTimestamp(),
                    });

                // 채팅방 멤버 목록에서 제거 및 수화물/멤버 수 업데이트
                final roomDoc = await _firestore
                    .collection(widget.chatRoomCollection)
                    .doc(widget.chatRoomId)
                    .get();

                if (!roomDoc.exists) {
                  print('채팅방이 존재하지 않습니다.');
                  Navigator.pop(context);
                  Navigator.pop(context);
                  return;
                }

                final roomData = roomDoc.data();
                if (roomData == null) {
                  print('채팅방 데이터가 null입니다.');
                  Navigator.pop(context);
                  Navigator.pop(context);
                  return;
                }

                final currentMembers = List<String>.from(roomData['members'] ?? []);
                final currentLuggageCount = roomData['luggage_count_total'] ?? 0;
                final userLuggageCount = roomData['user_luggage_counts']?[user.uid] ?? 0;

                // 멤버 목록에서 제거
                currentMembers.remove(user.uid);

                // 업데이트할 데이터 준비
                Map<String, dynamic> updateData = {
                  'members': currentMembers,
                  'member_count': currentMembers.length,
                  'updatedAt': FieldValue.serverTimestamp(),
                };

                // 수화물 수 업데이트
                if (currentLuggageCount > 0 && userLuggageCount > 0) {
                  updateData['luggage_count_total'] = currentLuggageCount - userLuggageCount;
                }

                // 사용자의 수화물 정보 제거
                updateData['user_luggage_counts.${user.uid}'] = FieldValue.delete();

                // 채팅방 정보 업데이트
                await _firestore
                    .collection(widget.chatRoomCollection)
                    .doc(widget.chatRoomId)
                    .update(updateData);

                // 사용자의 채팅방 목록에서 제거
                await _firestore
                    .collection('users')
                    .doc(user.uid)
                    .collection('chatRooms')
                    .doc(widget.chatRoomId)
                    .delete();

                // 사용자의 채팅방 목록에서도 제거 (users 컬렉션의 chatRooms 필드)
                await _firestore.collection('users').doc(user.uid).update({
                  'chatRooms': FieldValue.arrayRemove([widget.chatRoomId]),
                });

                // 멤버가 0명이 되면 채팅방 삭제
                if (currentMembers.isEmpty) {
                  try {
                    // 채팅방의 모든 메시지 삭제
                    final messagesSnapshot = await _firestore
                        .collection(widget.chatRoomCollection)
                        .doc(widget.chatRoomId)
                        .collection('messages')
                        .get();

                    // 모든 메시지 삭제
                    for (var doc in messagesSnapshot.docs) {
                      await doc.reference.delete();
                    }

                    // 채팅방 문서 삭제
                    await _firestore
                        .collection(widget.chatRoomCollection)
                        .doc(widget.chatRoomId)
                        .delete();

                    print('채팅방이 성공적으로 삭제되었습니다.');
                  } catch (e) {
                    print('채팅방 삭제 중 오류 발생: $e');
                  }
                }

                // 다이얼로그 닫기
                Navigator.pop(context);

                // 채팅방 화면 닫고 채팅방 목록으로 이동
                Navigator.pop(context); // 채팅방 화면 닫기
                Navigator.pushReplacementNamed(context, 'chat'); // ChatPage로 이동
              } catch (e) {
                print('채팅방 나가기 오류: $e');
                Navigator.pop(context); // 오류가 발생해도 다이얼로그는 닫기
              }
            },
            child: Text('나가기', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
