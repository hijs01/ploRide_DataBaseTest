import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:easy_localization/easy_localization.dart';

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
  String? _driverName;
  final Map<String, String> _systemMessageCache = {};
  StreamSubscription? _membersSubscription;

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
    _loadDriverInfo();

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

      if (querySnapshot.docs.isNotEmpty) {
        _lastDocument = querySnapshot.docs.last;
        _hasMoreMessages = querySnapshot.docs.length >= _messageLimit;

        // 메시지를 시간순으로 정렬
        final newMessages = querySnapshot.docs.reversed.toList();

        // 사용자 정보 일괄 로드
        await _loadUserNames(newMessages);

        setState(() {
          _messages = newMessages;
          _isLoading = false;
        });

        // 메시지 로드 후 스크롤을 최신 메시지로 이동
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      } else {
        setState(() {
          _isLoading = false;
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

  // 멤버 목록 실시간 업데이트 리스너
  void _setupMembersListener() {
    _membersSubscription = _firestore
        .collection(widget.chatRoomCollection)
        .doc(widget.chatRoomId)
        .snapshots()
        .listen((snapshot) {
          if (!mounted) return; // 위젯이 dispose된 경우 setState 호출하지 않음

          if (!snapshot.exists) return;

          final data = snapshot.data();
          if (data != null && data.containsKey('members')) {
            final List<String> members = List<String>.from(data['members']);
            print('멤버 목록 업데이트: $members');
            if (mounted) {
              // 한번 더 확인
              setState(() {
                _roomMembers = members;
              });
            }
          }
        });
  }

  // 로컬 알림 표시 메서드 수정
  Future<void> _showLocalNotification(
    String title,
    String body,
    String chatRoomId,
  ) async {
    try {
      print('로컬 알림 표시 시도: $title - $body');

      // Android 알림 설정
      final androidDetails = AndroidNotificationDetails(
        'chat_messages',
        'Chat Messages',
        channelDescription: 'Notifications for new chat messages',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
      );
      print('Android 알림 설정 완료');

      // iOS 알림 설정
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        badgeNumber: 1,
      );
      print('iOS 알림 설정 완료');

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // 알림 표시
      await flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecond,
        title,
        body,
        details,
        payload: chatRoomId,
      );

      print('로컬 알림 표시 완료');
    } catch (e) {
      print('로컬 알림 표시 중 오류 발생: $e');
    }
  }

  // 다른 채팅방 멤버들에게 알림 보내기 메서드 수정
  Future<void> _sendNotificationToOtherMembers(String messageText) async {
    if (!mounted) return;

    try {
      print('=== FCM 알림 전송 시작 ===');

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

      // 운전자 포함하여 모든 멤버의 토큰 수집
      List<String> tokens = [];

      // 1. 운전자 토큰 수집
      if (roomData['driver_id'] != null) {
        final driverDoc =
            await _firestore
                .collection('drivers')
                .doc(roomData['driver_id'])
                .get();

        if (driverDoc.exists) {
          final driverToken = driverDoc.get('token');
          if (driverToken != null && driverToken.isNotEmpty) {
            tokens.add(driverToken);
            print('운전자 토큰 추가: $driverToken');
          }
        }
      }

      // 2. 일반 사용자 토큰 수집
      final members = List<String>.from(roomData['members'] ?? []);
      for (String userId in members) {
        if (userId != _currentUserId) {
          // 현재 사용자 제외
          final userDoc =
              await _firestore.collection('users').doc(userId).get();

          if (userDoc.exists) {
            // fcm_token이나 token 필드 모두 확인
            String? userToken = userDoc.get('fcm_token');
            if (userToken == null || userToken.isEmpty) {
              userToken = userDoc.get('token');
            }

            if (userToken != null && userToken.isNotEmpty) {
              tokens.add(userToken);
              print('사용자 토큰 추가: $userToken (사용자: $userId)');
            }
          }
        }
      }

      if (tokens.isEmpty) {
        print('전송할 토큰이 없습니다.');
        return;
      }

      print('수집된 토큰 목록: $tokens');

      // 발신자 정보 가져오기
      String senderName = '알 수 없는 사용자';
      try {
        // 먼저 drivers 컬렉션에서 확인
        final driverDoc =
            await _firestore.collection('drivers').doc(_currentUserId).get();

        if (driverDoc.exists) {
          senderName = driverDoc.data()?['fullname'] ?? '알 수 없는 사용자';
        } else {
          // drivers에 없으면 users 컬렉션에서 확인
          final userDoc =
              await _firestore.collection('users').doc(_currentUserId).get();

          if (userDoc.exists) {
            senderName = userDoc.data()?['fullname'] ?? '알 수 없는 사용자';
          }
        }
      } catch (e) {
        print('발신자 정보 조회 중 오류: $e');
      }

      print('발신자 이름: $senderName');

      // Cloud Function 호출
      final response = await http.post(
        Uri.parse(
          'https://us-central1-geetaxi-aa379.cloudfunctions.net/sendChatNotification',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'tokens': tokens,
          'notification': {
            'title': '새 메시지',
            'body': '$senderName: $messageText',
            'sound': 'default',
          },
          'data': {
            'type': 'chat_message',
            'chatRoomId': widget.chatRoomId,
            'chatRoomCollection': widget.chatRoomCollection,
            'senderId': _currentUserId,
            'senderName': senderName,
            'messageText': messageText,
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            'badge': '1',
          },
          'android': {
            'priority': 'high',
            'notification': {
              'channel_id': 'chat_messages',
              'priority': 'max',
              'default_sound': true,
              'default_vibrate_timings': true,
            },
          },
          'apns': {
            'headers': {'apns-priority': '10'},
            'payload': {
              'aps': {'sound': 'default', 'badge': 1, 'content-available': 1},
            },
          },
        }),
      );

      print('FCM 응답: ${response.statusCode} - ${response.body}');

      // 앱이 포그라운드 상태일 때만 로컬 알림 표시
      if (mounted && await _isAppInForeground()) {
        await _showLocalNotification(
          '새 메시지',
          '$senderName: $messageText',
          widget.chatRoomId,
        );
      }
    } catch (e, stackTrace) {
      print('알림 전송 중 오류 발생: $e');
      print('스택 트레이스: $stackTrace');
    }
  }

  // 앱이 포그라운드 상태인지 확인
  Future<bool> _isAppInForeground() async {
    if (Platform.isIOS) {
      return true; // iOS에서는 항상 true 반환
    }
    return true; // Android에서도 일단 true 반환 (필요시 실제 상태 체크 로직 추가)
  }

  // 채팅방 문서 변경 감지 설정
  void _setupChatRoomListener() {
    String? previousLastMessage;

    _chatRoomSubscription = _firestore
        .collection(widget.chatRoomCollection)
        .doc(widget.chatRoomId)
        .snapshots()
        .listen((snapshot) async {
          if (!mounted || !snapshot.exists) return;

          final data = snapshot.data();
          if (data != null) {
            // lastMessage 변경 확인
            String? currentLastMessage = data['lastMessage'] as String?;
            String? senderId = data['last_message_sender_id'] as String?;

            if (currentLastMessage != null &&
                currentLastMessage != previousLastMessage &&
                senderId != _currentUserId) {
              previousLastMessage = currentLastMessage;

              // FCM 알림 전송
              await _sendFCMNotification(
                currentLastMessage,
                senderId ?? '',
                '알 수 없는 사용자',
              );
            }

            if (mounted) {
              setState(() {
                _chatRoomData = data;

                // 드라이버 정보 업데이트
                if (data['driver_id'] != null) {
                  _firestore
                      .collection('drivers')
                      .doc(data['driver_id'])
                      .get()
                      .then((driverDoc) {
                        if (mounted && driverDoc.exists) {
                          setState(() {
                            _driverName =
                                driverDoc.data()?['fullname'] ?? '알 수 없는 사용자';
                          });
                        }
                      });
                } else {
                  _driverName = null;
                }
              });
            }
          }
        });
  }

  // FCM 알림 전송 메서드
  Future<void> _sendFCMNotification(
    String messageText,
    String senderId,
    String senderName,
  ) async {
    try {
      print('=== FCM 알림 전송 시작 ===');
      print('메시지: $messageText');
      print('발신자 ID: $senderId');

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

      // 토큰 수집
      List<String> tokens = [];

      // 1. 운전자 토큰 수집
      if (roomData['driver_id'] != null && roomData['driver_id'] != senderId) {
        final driverDoc =
            await _firestore
                .collection('drivers')
                .doc(roomData['driver_id'])
                .get();

        if (driverDoc.exists) {
          final driverToken = driverDoc.get('token');
          if (driverToken != null && driverToken.isNotEmpty) {
            tokens.add(driverToken);
            print('운전자 토큰 추가: $driverToken');
          }
        }
      }

      // 2. 일반 사용자 토큰 수집
      final members = List<String>.from(roomData['members'] ?? []);
      for (String userId in members) {
        if (userId != senderId) {
          final userDoc =
              await _firestore.collection('users').doc(userId).get();

          if (userDoc.exists) {
            String? userToken = userDoc.get('fcm_token');
            if (userToken == null || userToken.isEmpty) {
              userToken = userDoc.get('token');
            }

            if (userToken != null && userToken.isNotEmpty) {
              tokens.add(userToken);
              print('사용자 토큰 추가: $userToken (사용자: $userId)');
            }
          }
        }
      }

      if (tokens.isEmpty) {
        print('전송할 토큰이 없습니다.');
        return;
      }

      print('수집된 토큰 목록: $tokens');

      // Cloud Function 호출
      final response = await http.post(
        Uri.parse(
          'https://us-central1-geetaxi-aa379.cloudfunctions.net/sendChatNotification',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'tokens': tokens,
          'notification': {
            'title': '새 메시지',
            'body': messageText,
            'sound': 'default',
            'badge': 1,
          },
          'data': {
            'type': 'chat_message',
            'chatRoomId': widget.chatRoomId,
            'chatRoomCollection': widget.chatRoomCollection,
            'senderId': senderId,
            'messageText': messageText,
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          },
          'android': {
            'priority': 'high',
            'notification': {
              'channel_id': 'chat_messages',
              'priority': 'max',
              'default_sound': true,
              'default_vibrate_timings': true,
            },
          },
          'apns': {
            'headers': {'apns-priority': '10', 'apns-push-type': 'background'},
            'payload': {
              'aps': {
                'alert': {'title': '새 메시지', 'body': messageText},
                'sound': 'default',
                'badge': 1,
                'content-available': 1,
                'mutable-content': 1,
              },
            },
          },
        }),
      );

      print('FCM 응답: ${response.statusCode} - ${response.body}');

      // 앱이 포그라운드 상태일 때만 로컬 알림 표시
      if (mounted && await _isAppInForeground()) {
        await _showLocalNotification('새 메시지', messageText, widget.chatRoomId);
      }
    } catch (e, stackTrace) {
      print('알림 전송 중 오류 발생: $e');
      print('스택 트레이스: $stackTrace');
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
    final systemMessageColor =
        isDarkMode ? Color(0xFF1C1C1E) : Color(0xFFE5E5EA);
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
              // 포커스 노드에서 포커스를 명시적으로 해제
              _focusNode.unfocus();
              // 약간의 지연 후 Drawer를 엽니다
              Future.delayed(Duration(milliseconds: 50), () {
                _scaffoldKey.currentState?.openEndDrawer();
              });
            },
          ),
        ],
      ),
      endDrawer: Drawer(
        child: GestureDetector(
          onTap: () {
            // Drawer 내부를 터치했을 때 키보드를 닫습니다
            FocusScope.of(context).unfocus();
            _focusNode.unfocus();
          },
          child: Container(
            color: isDarkMode ? Color(0xFF1C1C1E) : Color(0xFFF2F2F7),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 16,
                    bottom: 16,
                  ),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Color(0xFF2C2C2E) : Colors.white,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            isDarkMode
                                ? Colors.black12
                                : Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.close,
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Expanded(
                            child: Text(
                              'app.chat.room.drawer.title'.tr(),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          SizedBox(width: 48), // 균형을 위한 빈 공간
                        ],
                      ),
                      SizedBox(height: 8),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      FocusScope.of(context).unfocus();
                      _focusNode.unfocus();
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
                              'app.chat.room.drawer.error_loading'.tr(),
                              style: TextStyle(
                                color:
                                    isDarkMode
                                        ? Colors.white70
                                        : Colors.black54,
                              ),
                            ),
                          );
                        }

                        if (!snapshot.hasData) {
                          return Center(child: CircularProgressIndicator());
                        }

                        try {
                          final data =
                              snapshot.data!.data() as Map<String, dynamic>;
                          final users = data['members'] as List<dynamic>? ?? [];
                          final driver = data['driver_id'] as String? ?? '';

                          return SingleChildScrollView(
                            child: Column(
                              children: [
                                // 드라이버 섹션
                                Container(
                                  margin: EdgeInsets.fromLTRB(16, 16, 16, 8),
                                  padding: EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color:
                                        isDarkMode
                                            ? Color(0xFF2C2C2E)
                                            : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color:
                                          isDarkMode
                                              ? Color(0xFF3A3A3C)
                                              : Color(0xFFE5E5EA),
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.drive_eta,
                                            color:
                                                isDarkMode
                                                    ? Colors.white70
                                                    : Colors.black54,
                                            size: 18,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'app.chat.room.drawer.driver'.tr(),
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  isDarkMode
                                                      ? Colors.white
                                                      : Colors.black,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 12),
                                      FutureBuilder<String>(
                                        future: _getUserName(driver),
                                        builder: (context, snapshot) {
                                          return Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 20,
                                                backgroundColor:
                                                    isDarkMode
                                                        ? Color(0xFF3A3A3C)
                                                        : Color(0xFFE5E5EA),
                                                child: Icon(
                                                  Icons.person,
                                                  color:
                                                      isDarkMode
                                                          ? Colors.white70
                                                          : Colors.black54,
                                                ),
                                              ),
                                              SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  snapshot.data ??
                                                      'app.chat.room.drawer.loading'
                                                          .tr(),
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    color:
                                                        isDarkMode
                                                            ? Colors.white
                                                            : Colors.black,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),

                                // 라이더 섹션
                                Container(
                                  margin: EdgeInsets.fromLTRB(16, 8, 16, 8),
                                  padding: EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color:
                                        isDarkMode
                                            ? Color(0xFF2C2C2E)
                                            : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color:
                                          isDarkMode
                                              ? Color(0xFF3A3A3C)
                                              : Color(0xFFE5E5EA),
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.people_outline,
                                            color:
                                                isDarkMode
                                                    ? Colors.white70
                                                    : Colors.black54,
                                            size: 18,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'app.chat.room.drawer.riders'.tr(),
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  isDarkMode
                                                      ? Colors.white
                                                      : Colors.black,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 12),
                                      if (users.isEmpty)
                                        Center(
                                          child: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Text(
                                              'No riders yet',
                                              style: TextStyle(
                                                color:
                                                    isDarkMode
                                                        ? Colors.white70
                                                        : Colors.black54,
                                              ),
                                            ),
                                          ),
                                        )
                                      else
                                        Column(
                                          children: List.generate(users.length, (
                                            index,
                                          ) {
                                            final userId = users[index];
                                            final companionCount =
                                                data['user_companion_counts']?[userId] ??
                                                0;
                                            final luggageCount =
                                                data['user_luggage_counts']?[userId] ??
                                                0;

                                            return FutureBuilder<String>(
                                              future: _getUserName(userId),
                                              builder: (context, snapshot) {
                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        bottom: 12.0,
                                                      ),
                                                  child: Row(
                                                    children: [
                                                      CircleAvatar(
                                                        radius: 20,
                                                        backgroundColor:
                                                            isDarkMode
                                                                ? Color(
                                                                  0xFF3A3A3C,
                                                                )
                                                                : Color(
                                                                  0xFFE5E5EA,
                                                                ),
                                                        child: Text(
                                                          (snapshot.data ?? '?')
                                                              .substring(0, 1)
                                                              .toUpperCase(),
                                                          style: TextStyle(
                                                            color:
                                                                isDarkMode
                                                                    ? Colors
                                                                        .white
                                                                    : Colors
                                                                        .black,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                      SizedBox(width: 12),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              snapshot.data ??
                                                                  'app.chat.room.drawer.loading'
                                                                      .tr(),
                                                              style: TextStyle(
                                                                fontSize: 16,
                                                                color:
                                                                    isDarkMode
                                                                        ? Colors
                                                                            .white
                                                                        : Colors
                                                                            .black,
                                                              ),
                                                            ),
                                                            if (companionCount >
                                                                    0 ||
                                                                luggageCount >
                                                                    0 ||
                                                                true)
                                                              Row(
                                                                children: [
                                                                  Container(
                                                                    padding: EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          8,
                                                                      vertical:
                                                                          2,
                                                                    ),
                                                                    decoration: BoxDecoration(
                                                                      color:
                                                                          isDarkMode
                                                                              ? Color(
                                                                                0xFF3A3A3C,
                                                                              )
                                                                              : Color(
                                                                                0xFFE5E5EA,
                                                                              ),
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                            10,
                                                                          ),
                                                                    ),
                                                                    child: Row(
                                                                      mainAxisSize:
                                                                          MainAxisSize
                                                                              .min,
                                                                      children: [
                                                                        Icon(
                                                                          Icons
                                                                              .people_rounded,
                                                                          size:
                                                                              14,
                                                                          color:
                                                                              isDarkMode
                                                                                  ? Colors.white70
                                                                                  : Colors.black54,
                                                                        ),
                                                                        SizedBox(
                                                                          width:
                                                                              4,
                                                                        ),
                                                                        Text(
                                                                          '${companionCount + 1}',
                                                                          style: TextStyle(
                                                                            color:
                                                                                isDarkMode
                                                                                    ? Colors.white70
                                                                                    : Colors.black54,
                                                                            fontSize:
                                                                                12,
                                                                            fontWeight:
                                                                                FontWeight.w500,
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                  if (luggageCount >
                                                                      0) ...[
                                                                    SizedBox(
                                                                      width: 8,
                                                                    ),
                                                                    Container(
                                                                      padding: EdgeInsets.symmetric(
                                                                        horizontal:
                                                                            8,
                                                                        vertical:
                                                                            2,
                                                                      ),
                                                                      decoration: BoxDecoration(
                                                                        color:
                                                                            isDarkMode
                                                                                ? Color(
                                                                                  0xFF3A3A3C,
                                                                                )
                                                                                : Color(
                                                                                  0xFFE5E5EA,
                                                                                ),
                                                                        borderRadius:
                                                                            BorderRadius.circular(
                                                                              10,
                                                                            ),
                                                                      ),
                                                                      child: Row(
                                                                        mainAxisSize:
                                                                            MainAxisSize.min,
                                                                        children: [
                                                                          Icon(
                                                                            Icons.luggage_rounded,
                                                                            size:
                                                                                14,
                                                                            color:
                                                                                isDarkMode
                                                                                    ? Colors.white70
                                                                                    : Colors.black54,
                                                                          ),
                                                                          SizedBox(
                                                                            width:
                                                                                4,
                                                                          ),
                                                                          Text(
                                                                            '$luggageCount',
                                                                            style: TextStyle(
                                                                              color:
                                                                                  isDarkMode
                                                                                      ? Colors.white70
                                                                                      : Colors.black54,
                                                                              fontSize:
                                                                                  12,
                                                                              fontWeight:
                                                                                  FontWeight.w500,
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ],
                                                              ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            );
                                          }),
                                        ),
                                    ],
                                  ),
                                ),

                                // 가격 정보 섹션
                                Container(
                                  margin: EdgeInsets.fromLTRB(16, 8, 16, 8),
                                  padding: EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color:
                                        isDarkMode
                                            ? Color(0xFF2C2C2E)
                                            : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color:
                                          isDarkMode
                                              ? Color(0xFF3A3A3C)
                                              : Color(0xFFE5E5EA),
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.payments_outlined,
                                            color:
                                                isDarkMode
                                                    ? Colors.white70
                                                    : Colors.black54,
                                            size: 18,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'app.chat.room.drawer.total_price'
                                                .tr(),
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  isDarkMode
                                                      ? Colors.white
                                                      : Colors.black,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            data['member_count'] <= 2
                                                ? '\$500'
                                                : data['member_count'] == 3
                                                ? '\$440'
                                                : '\$500',
                                            style: TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color:
                                                  isDarkMode
                                                      ? Colors.white
                                                      : Colors.black,
                                            ),
                                          ),
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  isDarkMode
                                                      ? Color(0xFF3A3A3C)
                                                      : Color(0xFFE5E5EA),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              context.locale.languageCode ==
                                                      'ko'
                                                  ? '${data['member_count']}명 기준'
                                                  : 'Based on ${data['member_count']} people',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color:
                                                    isDarkMode
                                                        ? Colors.white70
                                                        : Colors.black54,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // 나가기 버튼
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    8,
                                    16,
                                    16,
                                  ),
                                  child: ElevatedButton(
                                    onPressed: () => _showExitDialog(context),
                                    style: ElevatedButton.styleFrom(
                                      minimumSize: Size(double.infinity, 50),
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text(
                                      'app.chat.room.drawer.leave_room'.tr(),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        } catch (e) {
                          print('Error loading chat room data: $e');
                          return Center(
                            child: Text(
                              'app.chat.room.drawer.error_loading'.tr(),
                              style: TextStyle(
                                color:
                                    isDarkMode
                                        ? Colors.white70
                                        : Colors.black54,
                              ),
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
                      return _buildSystemMessage(
                        messageData['text'],
                        messageData,
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
                            child: FutureBuilder<String>(
                              future: _getMessageSenderName(
                                messageData['sender_id'],
                              ),
                              builder: (context, snapshot) {
                                return Text(
                                  snapshot.data ?? '로딩 중...',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        isDarkMode
                                            ? Colors.white70
                                            : Colors.black54,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.left,
                                );
                              },
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
                                  child: GestureDetector(
                                    onTap: () {
                                      _showReportDialog(
                                        context,
                                        messageData['sender_id'],
                                      );
                                    },
                                    child: CircleAvatar(
                                      radius: 16,
                                      backgroundColor:
                                          isDarkMode
                                              ? Color(0xFF3A3A3C)
                                              : Color(0xFFE5E5EA),
                                      child: FutureBuilder<String>(
                                        future: _getMessageSenderName(
                                          messageData['sender_id'],
                                        ),
                                        builder: (context, snapshot) {
                                          return FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Center(
                                              child: Padding(
                                                padding: EdgeInsets.all(4),
                                                child: Text(
                                                  (snapshot.data ?? '?')
                                                      .substring(0, 1)
                                                      .toUpperCase(),
                                                  style: TextStyle(
                                                    color:
                                                        isDarkMode
                                                            ? Colors.white
                                                            : Colors.black,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    height: 1,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
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
                                    color: isMe ? myMessageColor : messageColor,
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(16),
                                      topRight: Radius.circular(16),
                                      bottomLeft: Radius.circular(
                                        isMe ? 16 : 4,
                                      ),
                                      bottomRight: Radius.circular(
                                        isMe ? 4 : 16,
                                      ),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            isDarkMode
                                                ? Colors.black.withOpacity(0.2)
                                                : Colors.black.withOpacity(
                                                  0.05,
                                                ),
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
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Color(0xFF2C2C2E) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color:
                              isDarkMode
                                  ? Color(0xFF3A3A3C)
                                  : Color(0xFFE5E5EA),
                          width: 0.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                isDarkMode
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
                          hintText: 'app.chat.room.type'.tr(),
                          hintStyle: TextStyle(
                            color: isDarkMode ? Colors.white60 : Colors.black38,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 4),
                          isDense: true,
                        ),
                        style: TextStyle(color: textColor, fontSize: 15),
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
                        color:
                            _messageController.text.trim().isEmpty
                                ? (isDarkMode ? Colors.white38 : Colors.black38)
                                : sendButtonColor,
                        size: 24,
                      ),
                      onPressed:
                          _messageController.text.trim().isEmpty
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
    _membersSubscription?.cancel();
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

      // 드라이버 ID가 변경되었을 때 드라이버 정보 다시 로드
      if (data['driver_id'] != null) {
        _loadDriverInfo();
      }
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
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;

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
      departure = departure.split(' ')[0].toUpperCase();
    }

    if (destination.toLowerCase().contains('airport') ||
        destination.toLowerCase().contains('newark') ||
        destination.toLowerCase().contains('jfk') ||
        destination.toLowerCase().contains('lga')) {
      destination = destination.split(' ')[0].toUpperCase();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            departure,
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Icon(
            Icons.arrow_forward,
            size: 16,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        Flexible(
          child: Text(
            destination,
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            overflow: TextOverflow.ellipsis,
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
                    final userCompanionCount =
                        roomData['user_companion_counts']?[user.uid] ?? 0;

                    // 멤버 목록에서 제거
                    currentMembers.remove(user.uid);

                    // 업데이트할 데이터 준비
                    Map<String, dynamic> updateData = {
                      'members': currentMembers,
                      'updatedAt': FieldValue.serverTimestamp(),
                    };

                    // 수화물 수 업데이트
                    if (currentLuggageCount > 0 && userLuggageCount > 0) {
                      updateData['luggage_count_total'] =
                          currentLuggageCount - userLuggageCount;
                    }

                    // 사용자의 수화물 정보와 동반자 정보 제거
                    updateData['user_luggage_counts.${user.uid}'] =
                        FieldValue.delete();
                    updateData['user_companion_counts.${user.uid}'] =
                        FieldValue.delete();

                    // 총 멤버 수 재계산 (실제 멤버 + 남은 동반자)
                    Map<String, int> remainingCompanionCounts =
                        Map<String, int>.from(
                          roomData['user_companion_counts'] ?? {},
                        );
                    remainingCompanionCounts.remove(user.uid);
                    int totalCompanions = remainingCompanionCounts.values.fold(
                      0,
                      (sum, count) => sum + count,
                    );
                    int newMemberCount =
                        currentMembers.length + totalCompanions;
                    updateData['member_count'] = newMemberCount;

                    // available_for_driver 상태 업데이트
                    updateData['available_for_driver'] = (newMemberCount == 4);

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

                    // 여정 상태를 'cancelled'로 업데이트
                    final tripDoc =
                        await _firestore
                            .collection(widget.chatRoomCollection)
                            .doc(widget.chatRoomId)
                            .get();

                    if (tripDoc.exists) {
                      final tripData = tripDoc.data();
                      if (tripData != null) {
                        // 원본 여정 문서의 ID를 가져옴
                        final originalTripId = tripData['original_trip_id'];
                        if (originalTripId != null) {
                          // 원본 여정 문서의 상태를 'cancelled'로 업데이트
                          await _firestore
                              .collection(widget.chatRoomCollection)
                              .doc(originalTripId)
                              .update({
                                'status': 'cancelled',
                                'cancelled_at': FieldValue.serverTimestamp(),
                                'cancelled_by': user.uid,
                              });
                        }
                      }
                    }

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

  Future<void> _initializeNotifications() async {
    try {
      print('알림 초기화 시작');
      flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

      // Android 설정
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      print('Android 설정 완료');

      // iOS 설정
      final darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      print('iOS 설정 완료');

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
      print('알림 플러그인 초기화 완료');

      // iOS 권한 요청
      if (Platform.isIOS) {
        print('iOS 권한 요청 시작');
        final bool? result = await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true);
        print('iOS 권한 요청 결과: $result');
      }

      print('알림 초기화 완료');
    } catch (e) {
      print('알림 초기화 중 오류 발생: $e');
    }
  }

  // 드라이버 정보를 로드하는 메서드 수정
  Future<void> _loadDriverInfo() async {
    try {
      print('드라이버 정보 로드 시작');
      final chatRoomDoc =
          await _firestore
              .collection(widget.chatRoomCollection)
              .doc(widget.chatRoomId)
              .get();

      if (chatRoomDoc.exists) {
        final data = chatRoomDoc.data();
        print('채팅방 데이터: $data');
        if (data != null && data['driver_id'] != null) {
          print('드라이버 ID: ${data['driver_id']}');
          final driverDoc =
              await _firestore
                  .collection('drivers')
                  .doc(data['driver_id'])
                  .get();

          if (driverDoc.exists) {
            print('드라이버 문서 데이터: ${driverDoc.data()}');
            setState(() {
              _driverName = driverDoc.data()?['fullname'] ?? '알 수 없는 사용자';
              print('설정된 드라이버 이름: $_driverName');
            });
          } else {
            print('드라이버 문서가 존재하지 않습니다.');
          }
        } else {
          print('채팅방에 driver_id가 없습니다.');
        }
      } else {
        print('채팅방 문서가 존재하지 않습니다.');
      }
    } catch (e) {
      print('드라이버 정보 로드 오류: $e');
    }
  }

  Future<String> _getMessageSenderName(String senderId) async {
    if (senderId.isEmpty) {
      return '알 수 없는 사용자';
    }

    if (_userNames.containsKey(senderId)) {
      return _userNames[senderId]!;
    }

    try {
      // 먼저 drivers 컬렉션에서 확인
      final driverDoc =
          await _firestore.collection('drivers').doc(senderId).get();
      if (driverDoc.exists) {
        final driverData = driverDoc.data();
        final driverName = driverData?['fullname'] ?? '알 수 없는 사용자';
        _userNames[senderId] = driverName;
        return driverName;
      }

      // drivers 컬렉션에 없으면 users 컬렉션에서 확인
      final userDoc = await _firestore.collection('users').doc(senderId).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        final userName = userData?['fullname'] ?? '알 수 없는 사용자';
        _userNames[senderId] = userName;
        return userName;
      }
    } catch (e) {
      print('메시지 발신자 이름 조회 오류: $e');
    }

    return '알 수 없는 사용자';
  }

  Future<String> _getSystemMessageKey(
    String text,
    Map<String, dynamic> messageData,
  ) async {
    // 캐시된 메시지가 있으면 반환
    if (_systemMessageCache.containsKey(text)) {
      return _systemMessageCache[text]!;
    }

    String translatedMessage = text;

    if (text.contains('님이 그룹에 참여했습니다')) {
      String userName = text.substring(0, text.indexOf('님이')).trim();
      try {
        final userQuery =
            await _firestore
                .collection('users')
                .where('fullname', isEqualTo: userName)
                .get();

        if (userQuery.docs.isNotEmpty) {
          String userId = userQuery.docs.first.id;
          String actualName = await _getUserName(userId);
          translatedMessage = 'app.chat.room.system.member_joined'.tr();
          translatedMessage = translatedMessage.replaceAll(
            '\$fullname',
            actualName,
          );
        }
      } catch (e) {
        print('Error finding user: $e');
      }
    } else if (text.contains('님이 그룹에서 나갔습니다')) {
      String userName = text.substring(0, text.indexOf('님이')).trim();
      try {
        final userQuery =
            await _firestore
                .collection('users')
                .where('fullname', isEqualTo: userName)
                .get();

        if (userQuery.docs.isNotEmpty) {
          String userId = userQuery.docs.first.id;
          String actualName = await _getUserName(userId);
          translatedMessage = 'app.chat.room.system.member_left'.tr();
          translatedMessage = translatedMessage.replaceAll(
            '\$fullname',
            actualName,
          );
        }
      } catch (e) {
        print('Error finding user: $e');
      }
    } else if (text.contains('요청을 수락했습니다')) {
      translatedMessage = 'app.chat.room.system.driver_accepted'.tr();
    } else if (text.contains('픽업 위치에 도착했습니다')) {
      translatedMessage = 'app.chat.room.system.driver_arrived'.tr();
    } else if (text.contains('여행이 시작되었습니다')) {
      translatedMessage = 'app.chat.room.system.ride_started'.tr();
    } else if (text.contains('여행이 완료되었습니다')) {
      translatedMessage = 'app.chat.room.system.ride_completed'.tr();
    } else if (text.contains('여행이 취소되었습니다')) {
      translatedMessage = 'app.chat.room.system.ride_cancelled'.tr();
    } else if (text.contains('그룹이 생성되었습니다')) {
      translatedMessage = 'app.chat.room.system.group_created'.tr();
    } else if (text.contains('그룹이 해체되었습니다')) {
      translatedMessage = 'app.chat.room.system.group_disbanded'.tr();
    } else if (text == 'app.chat.room.system.driver_accepted') {
      translatedMessage = 'app.chat.room.system.driver_accepted'.tr();
    } else if (text == 'app.chat.room.system.chat_room_created') {
      translatedMessage = 'app.chat.room.system.chat_room_created'.tr();
    }

    // 번역된 메시지를 캐시에 저장
    _systemMessageCache[text] = translatedMessage;
    return translatedMessage;
  }

  // 시스템 메시지 위젯 생성
  Widget _buildSystemMessage(String text, Map<String, dynamic> messageData) {
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    final systemMessageColor =
        isDarkMode ? Color(0xFF1C1C1E) : Color(0xFFE5E5EA);

    // 캐시된 메시지가 있으면 바로 표시
    if (_systemMessageCache.containsKey(text)) {
      return Container(
        width: double.infinity,
        margin: EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: systemMessageColor,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Text(
              _systemMessageCache[text]!,
              style: TextStyle(
                color: isDarkMode ? Colors.white70 : Colors.black87,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ),
        ),
      );
    }

    // 캐시된 메시지가 없는 경우에만 FutureBuilder 사용
    return FutureBuilder<String>(
      future: _getSystemMessageKey(text, messageData),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: double.infinity,
            margin: EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: systemMessageColor,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  text,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white70 : Colors.black87,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                ),
              ),
            ),
          );
        }
        return Container(
          width: double.infinity,
          margin: EdgeInsets.symmetric(vertical: 10),
          child: Center(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: systemMessageColor,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                snapshot.data ?? text,
                style: TextStyle(
                  color: isDarkMode ? Colors.white70 : Colors.black87,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ),
          ),
        );
      },
    );
  }

  void _showReportDialog(BuildContext context, String userId) {
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    final isKorean = context.locale.languageCode == 'ko';

    // 사용자 이름 불러오기
    _getUserName(userId).then((userName) {
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text(
                isKorean ? '사용자 신고' : 'Report User',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isKorean
                        ? '\'$userName\' 님을 신고하시겠습니까?'
                        : 'Would you like to report \'$userName\'?',
                    style: TextStyle(
                      fontSize: 18,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    isKorean ? '취소' : 'Cancel',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDarkMode ? Colors.white : Colors.black54,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // 첫 번째 다이얼로그 닫기
                    Navigator.pop(context);

                    // 이메일 안내 다이얼로그 표시
                    _showReportInstructionDialog(context, userName);
                  },
                  child: Text(
                    isKorean ? '신고' : 'Report',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              backgroundColor: isDarkMode ? Color(0xFF2C2C2E) : Colors.white,
            ),
      );
    });
  }

  void _showReportInstructionDialog(BuildContext context, String userName) {
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    final isKorean = context.locale.languageCode == 'ko';

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              isKorean ? '신고 안내' : 'Report Instructions',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            content: Text(
              isKorean
                  ? '유저를 신고하려면 비속어 채팅 등 비정상적인 활동 스크린샷을 찍어 ploride.dev@gmail.com 으로 보내주세요'
                  : 'To report a user, please take a screenshot of inappropriate activities such as abusive messages and send it to ploride.dev@gmail.com',
              style: TextStyle(
                fontSize: 17,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  isKorean ? '확인' : 'OK',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.blue,
                  ),
                ),
              ),
            ],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            backgroundColor: isDarkMode ? Color(0xFF2C2C2E) : Colors.white,
          ),
    );
  }

  // 메시지 전송 메서드
  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    setState(() {
      _isSending = true;
    });

    final messageText = _messageController.text.trim();
    _messageController.clear();

    try {
      // 메시지 전송
      await _firestore
          .collection(widget.chatRoomCollection)
          .doc(widget.chatRoomId)
          .collection('messages')
          .add({
            'text': messageText,
            'sender_id': _currentUserId,
            'timestamp': FieldValue.serverTimestamp(),
            'type': 'user',
          });

      // 채팅방 마지막 메시지 정보 업데이트
      await _firestore
          .collection(widget.chatRoomCollection)
          .doc(widget.chatRoomId)
          .update({
            'lastMessage': messageText,
            'last_message': messageText,
            'last_message_time': FieldValue.serverTimestamp(),
            'last_message_sender_id': _currentUserId,
            'timestamp': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        setState(() {
          _isSending = false;
        });
        // 스크롤을 아래로 이동
        _scrollToBottom();
      }
    } catch (e) {
      print('메시지 전송 중 오류 발생: $e');
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }
}
