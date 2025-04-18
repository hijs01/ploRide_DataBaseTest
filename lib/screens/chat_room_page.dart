import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
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
    _initializeNotifications();
    _getCurrentUser();
    _loadInitialMessages();
    _loadRoomMembers();
    _loadChatRoomData();
    _setupRealtimeUpdates();
    _setupChatRoomListener();
    _setupMembersListener();

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
    
    // 메시지 컨트롤러에 리스너 추가
    _messageController.addListener(() {
      if (mounted) {
        setState(() {}); // 텍스트 필드 내용이 변경될 때마다 UI 업데이트
      }
    });
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // 키보드가 나타날 때 스크롤을 아래로 이동
    if (MediaQuery.of(context).viewInsets.bottom > 0) {
      // 키보드가 나타났을 때
      Future.delayed(Duration(milliseconds: 100), () {
        if (mounted) {
          _scrollToBottom(animate: false);
        }
      });
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
      print('채팅방 멤버 목록 로드 시작...');
      final roomDoc =
          await _firestore
              .collection(widget.chatRoomCollection)
              .doc(widget.chatRoomId)
              .get();

      if (roomDoc.exists) {
        final data = roomDoc.data();
        if (data != null && data.containsKey('members')) {
          final List<String> members = List<String>.from(data['members']);
          print('채팅방 멤버 목록: $members');
          setState(() {
            _roomMembers = members;
          });
        } else {
          print('채팅방에 members 필드가 없습니다.');
        }
      } else {
        print('채팅방 문서를 찾을 수 없습니다.');
      }
    } catch (e) {
      print('채팅방 멤버 목록 로드 중 오류: $e');
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
      final driverDoc =
          await _firestore.collection('drivers').doc(userId).get();
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

  void _scrollToBottom({bool animate = true}) {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      if (animate) {
        _scrollController.animateTo(
          maxScroll,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(maxScroll);
      }
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _loadMoreMessages();
    }
  }

  Future<void> _loadInitialMessages() async {
    if (!mounted) return;
    
    try {
      final querySnapshot =
          await _firestore
              .collection(widget.chatRoomCollection)
              .doc(widget.chatRoomId)
              .collection('messages')
              .orderBy('timestamp', descending: true)
              .limit(_messageLimit)
              .get();

      if (!mounted) return;

      if (querySnapshot.docs.isNotEmpty) {
        _lastDocument = querySnapshot.docs.last;
        _hasMoreMessages = querySnapshot.docs.length >= _messageLimit;

        // 메시지를 시간순으로 정렬
        final messages = querySnapshot.docs.reversed.toList();

        // 사용자 정보 일괄 로드
        await _loadUserNames(messages);

        if (!mounted) return;

        setState(() {
          _messages = messages;
          _isLoading = false;
        });

        // 새 메시지가 추가될 때마다 스크롤을 아래로 이동
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            // 약간의 지연 후 스크롤 실행
            Future.delayed(Duration(milliseconds: 100), () {
              if (mounted) {
                _scrollToBottom(animate: false);
              }
            });
          }
        });
      }
    } catch (e) {
      print('Error loading initial messages: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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

  // 멤버 목록 실시간 업데이트 리스너
  void _setupMembersListener() {
    _firestore
        .collection(widget.chatRoomCollection)
        .doc(widget.chatRoomId)
        .snapshots()
        .listen((snapshot) {
          if (!snapshot.exists) return;

          final data = snapshot.data();
          if (data != null && data.containsKey('members')) {
            final List<String> members = List<String>.from(data['members']);
            print('멤버 목록 업데이트: $members');
            setState(() {
              _roomMembers = members;
            });
          }
        });
  }

  // 로컬 알림 표시 메서드 수정
  Future<void> _showLocalNotification(String title, String message) async {
    try {
      const androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'chat_messages',
        'Chat Messages',
        channelDescription: 'Notifications for new chat messages',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
      );
      const iOSPlatformChannelSpecifics = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      const platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await flutterLocalNotificationsPlugin.show(
        0,
        title,
        message,
        platformChannelSpecifics,
      );
      print('로컬 알림 표시 완료: $title - $message');
    } catch (e) {
      print('로컬 알림 표시 중 오류 발생: $e');
    }
  }

  // 다른 채팅방 멤버들에게 알림 보내기 메서드 수정
  Future<void> _sendNotificationToOtherMembers(String messageText) async {
    try {
      print('=== 알림 전송 시작 ===');

      // 채팅방 정보 가져오기
      final roomDoc =
          await _firestore
              .collection(widget.chatRoomCollection)
              .doc(widget.chatRoomId)
              .get();

      if (!roomDoc.exists) {
        print('채팅방을 찾을 수 없습니다.');
        return;
      }

      final roomData = roomDoc.data()!;
      final String? driverId = roomData['driver_id'];

      print('채팅방 운전자 ID: $driverId');
      print('현재 사용자 ID: $_currentUserId');

      // 수신자 목록 생성 (멤버들 + 운전자)
      Set<String> receivers = Set<String>.from(_roomMembers);

      // 운전자가 있고, 멤버 목록에 없으면 추가
      if (driverId != null && !receivers.contains(driverId)) {
        receivers.add(driverId);
      }

      // 현재 사용자 제외
      receivers.remove(_currentUserId);

      final otherMembers = receivers.toList();
      print('수신자 목록: $otherMembers');

      if (otherMembers.isEmpty) {
        print('수신자가 없어 알림을 보내지 않습니다.');
        return;
      }

      // 발신자 이름 가져오기
      String senderName = '알 수 없는 사용자';
      try {
        final userDoc =
            await _firestore.collection('users').doc(_currentUserId).get();
        if (userDoc.exists) {
          senderName = userDoc.data()?['fullname'] ?? senderName;
        }
      } catch (e) {
        print('사용자 이름 조회 오류: $e');
      }

      // Cloud Function 호출
      final functionRegion = 'us-central1';
      final projectId = 'geetaxi-aa379';
      final url =
          'https://$functionRegion-$projectId.cloudfunctions.net/sendChatNotification';

      final requestData = {
        'chatRoomId': widget.chatRoomId,
        'chatRoomName': widget.chatRoomName,
        'messageText': messageText,
        'senderName': senderName,
        'senderId': _currentUserId,
        'receiverIds': otherMembers,
      };

      print('전송할 데이터: ${jsonEncode(requestData)}');

      final response = await http.post(
        Uri.parse(url),
        body: jsonEncode(requestData),
        headers: {'Content-Type': 'application/json'},
      );

      print('응답 상태 코드: ${response.statusCode}');
      print('응답 내용: ${response.body}');
    } catch (e) {
      print('채팅 알림 전송 중 오류 발생: $e');
    } finally {
      print('=== 알림 전송 종료 ===');
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    setState(() {
      _isSending = true; // 전송 중 상태 표시
    });

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
              'last_message_sender_id': _currentUserId,
              'last_message_sender_name': senderName,
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
    } finally {
      setState(() {
        _isSending = false; // 전송 완료 상태 표시
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final backgroundColor = isDarkMode ? Color(0xFF000000) : Color(0xFFF2F2F7);
    final messageColor = isDarkMode ? Color(0xFF2C2C2E) : Colors.white;
    final myMessageColor = isDarkMode ? Color(0xFF0055CC) : Color(0xFF0055CC);
    final systemMessageColor = isDarkMode ? Color(0xFF1C1C1E) : Color(0xFFE5E5EA);
    final inputBackgroundColor = isDarkMode ? Color(0xFF1C1C1E) : Colors.white;
    final accentColor = isDarkMode ? Color(0xFF0055CC) : Color(0xFF0055CC);
    final sendButtonColor = isDarkMode ? Color(0xFF007AFF) : Color(0xFF007AFF);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        title: _buildAppBarTitle(),
        automaticallyImplyLeading: true,
        elevation: 0,
        iconTheme: IconThemeData(
          color: isDarkMode ? Colors.white : Colors.black,
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.menu),
            onPressed: () {
              // Drawer를 열기 전에 키보드를 닫습니다
              FocusScope.of(context).unfocus();
              _scaffoldKey.currentState?.openEndDrawer();
            },
          ),
        ],
      ),
      endDrawer: Drawer(
        child: GestureDetector(
          onTap: () {
            // Drawer 내부를 터치했을 때 키보드를 닫습니다
            FocusScope.of(context).unfocus();
          },
          child: Container(
            color: isDarkMode ? Color(0xFF1C1C1E) : Color(0xFFF2F2F7),
            child: Column(
              children: [
                AppBar(
                  title: Text(
                    '채팅방 정보',
                    style: TextStyle(color: Colors.white),
                  ),
                  automaticallyImplyLeading: false,
                  backgroundColor: isDarkMode ? Color(0xFF1C1C1E) : Color(0xFFF2F2F7),
                  elevation: 0,
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      FocusScope.of(context).unfocus();
                    },
                    child: StreamBuilder<DocumentSnapshot>(
                      stream:
                          _firestore
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
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              FutureBuilder<String>(
                                future: _getUserName(driver),
                                builder: (context, snapshot) {
                                  return ListTile(
                                    leading: CircleAvatar(child: Icon(Icons.person)),
                                    title: Text(
                                      '드라이버',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    subtitle: Text(
                                      snapshot.data ?? '로딩 중...',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                  );
                                },
                              ),
                              Divider(color: Colors.white24),
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
                                          title: Text(
                                            '승객 ${index + 1}',
                                            style: TextStyle(color: Colors.white),
                                          ),
                                          subtitle: Text(
                                            snapshot.data ?? '로딩 중...',
                                            style: TextStyle(color: Colors.white70),
                                          ),
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
                                  color: isDarkMode ? Color(0xFF1C1C1E) : Color(0xFFF2F2F7),
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
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      users.length <= 2
                                          ? '\$500'
                                          : users.length == 3
                                          ? '\$440'
                                          : '\$500',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      '${users.length}명 기준',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.white70,
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
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Text(
                                    '채팅방 나가기',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
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
                ),
              ],
            ),
          ),
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
                            padding: const EdgeInsets.only(
                              left: 5.0,
                              bottom: 1.0,
                              top: 4.0,
                            ),
                            child: Text(
                              messageData['sender_name'] ?? '알 수 없는 사용자',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkMode ? Colors.white70 : Colors.black54,
                                fontWeight: FontWeight.w500,
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
                                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (!isMe)
                                Container(
                                  margin: EdgeInsets.only(right: 4),
                                  child: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: isDarkMode ? Color(0xFF3A3A3C) : Color(0xFFE5E5EA),
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
                                              color: isDarkMode ? Colors.white : Colors.black,
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
                                      color: isDarkMode ? Colors.white54 : Colors.black54,
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
                                    color: isMe ? myMessageColor : messageColor,
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(16),
                                      topRight: Radius.circular(16),
                                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                                      bottomRight: Radius.circular(isMe ? 4 : 16),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: isDarkMode 
                                            ? Colors.black.withOpacity(0.2) 
                                            : Colors.black.withOpacity(0.05),
                                        blurRadius: 4,
                                        offset: Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    messageData['text'],
                                    style: TextStyle(
                                      color: isMe ? Colors.white : textColor,
                                      fontSize: 15,
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
                                      color: isDarkMode ? Colors.white54 : Colors.black54,
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
                color: inputBackgroundColor,
                border: Border(
                  top: BorderSide(
                    color: isDarkMode ? Color(0xFF2C2C2E) : Color(0xFFE5E5EA),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Color(0xFF2C2C2E) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDarkMode ? Color(0xFF3A3A3C) : Color(0xFFE5E5EA),
                          width: 0.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isDarkMode 
                                ? Colors.black.withOpacity(0.1) 
                                : Colors.black.withOpacity(0.05),
                            blurRadius: 2,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _messageController,
                        focusNode: _focusNode,
                        decoration: InputDecoration(
                          hintText: '메시지를 입력하세요',
                          hintStyle: TextStyle(
                            color: isDarkMode ? Colors.white60 : Colors.black38,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 4),
                          isDense: true,
                        ),
                        style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                        ),
                        onSubmitted: (_) => _sendMessage(),
                        textInputAction: TextInputAction.send,
                      ),
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.only(right: 8),
                    child: IconButton(
                      icon: Icon(
                        Icons.send_rounded,
                        color: _messageController.text.trim().isEmpty
                            ? (isDarkMode ? Colors.white38 : Colors.black38)
                            : sendButtonColor,
                        size: 24,
                      ),
                      onPressed: _messageController.text.trim().isEmpty
                          ? null
                          : _sendMessage,
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
    final isDarkMode = MediaQuery.of(context).platformBrightness == Brightness.dark;
    
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

    // PSU 관련 주소 처리
    if (departure.toLowerCase().contains('penn state') || 
        departure.toLowerCase().contains('psu') ||
        departure.toLowerCase().contains('pittsburgh') ||
        departure.toLowerCase().contains('pollock')) {
      if (departure.contains('-')) {
        departure = departure.split('-')[1].trim();
      }
    }
    
    if (destination.toLowerCase().contains('penn state') || 
        destination.toLowerCase().contains('psu') ||
        destination.toLowerCase().contains('pittsburgh') ||
        destination.toLowerCase().contains('pollock')) {
      if (destination.contains('-')) {
        destination = destination.split('-')[1].trim();
      }
    }

    // 공항 코드 처리
    if (departure.toLowerCase().contains('airport') || 
        departure.toLowerCase().contains('newark') ||
        departure.toLowerCase().contains('jfk') ||
        departure.toLowerCase().contains('lga')) {
      if (departure.contains('(') && departure.contains(')')) {
        departure = departure.substring(
          departure.indexOf('(') + 1,
          departure.indexOf(')')
        ).trim();
      }
    }
    
    if (destination.toLowerCase().contains('airport') || 
        destination.toLowerCase().contains('newark') ||
        destination.toLowerCase().contains('jfk') ||
        destination.toLowerCase().contains('lga')) {
      if (destination.contains('(') && destination.contains(')')) {
        destination = destination.substring(
          destination.indexOf('(') + 1,
          destination.indexOf(')')
        ).trim();
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            departure,
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.visible,
            maxLines: 1,
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Icon(
            Icons.arrow_forward,
            color: isDarkMode ? Colors.white : Colors.black,
            size: 16,
          ),
        ),
        Flexible(
          child: Text(
            destination,
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.visible,
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
          if (!mounted) return;
          
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

              if (!mounted) return;

              setState(() {
                _messages.add(newMessage);
              });

              // 새 메시지가 추가될 때 스크롤을 아래로 이동
              _scrollToBottom(animate: true);
            }
          }
        });
  }

  void _showExitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
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
                    final userDoc =
                        await _firestore
                            .collection('users')
                            .doc(user.uid)
                            .get();
                    final userName =
                        userDoc.data()?['fullname'] ?? '알 수 없는 사용자';

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
                    final roomDoc =
                        await _firestore
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

                    final currentMembers = List<String>.from(
                      roomData['members'] ?? [],
                    );
                    final currentLuggageCount =
                        roomData['luggage_count_total'] ?? 0;
                    final userLuggageCount =
                        roomData['user_luggage_counts']?[user.uid] ?? 0;

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
                      updateData['luggage_count_total'] =
                          currentLuggageCount - userLuggageCount;
                    }

                    // 사용자의 수화물 정보 제거
                    updateData['user_luggage_counts.${user.uid}'] =
                        FieldValue.delete();

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
                        final messagesSnapshot =
                            await _firestore
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
                    Navigator.pushReplacementNamed(
                      context,
                      'chat',
                    ); // ChatPage로 이동
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

  // 채팅방 문서 변경 감지 설정
  void _setupChatRoomListener() {
    print('채팅방 리스너 설정...');
    _chatRoomSubscription = _firestore
        .collection(widget.chatRoomCollection)
        .doc(widget.chatRoomId)
        .snapshots()
        .listen((snapshot) async {
          if (!snapshot.exists) return;

          final data = snapshot.data() as Map<String, dynamic>;

          // lastMessage 필드 변경 감지
          final String lastMessage =
              data['lastMessage'] ?? data['last_message'] ?? '';

          if (lastMessage.isNotEmpty) {
            print('새 메시지 감지: $lastMessage');
            await _showLocalNotification('새 메시지', lastMessage);
          }
        });
  }

  Future<void> _initializeNotifications() async {
    try {
      flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

      // Android 설정
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );

      // iOS 설정
      final darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        notificationCategories: [
          DarwinNotificationCategory(
            'chat_messages',
            actions: [DarwinNotificationAction.plain('id_1', 'Action 1')],
            options: {DarwinNotificationCategoryOption.hiddenPreviewShowTitle},
          ),
        ],
      );

      // 초기화 설정 통합
      final initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      );

      // 플러그인 초기화
      await flutterLocalNotificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (details) {
          print('알림 탭: ${details.payload}');
        },
      );

      print('로컬 알림 초기화 완료');
    } catch (e) {
      print('로컬 알림 초기화 중 오류 발생: $e');
    }
  }
}
