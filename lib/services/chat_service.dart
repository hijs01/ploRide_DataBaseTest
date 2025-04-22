import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String serverKey = '425631894947'; // FCM 발신자 ID

  Future<void> sendMessage({
    required String chatRoomId,
    required String message,
    required String senderName,
    required String collectionName,
  }) async {
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final timestamp = FieldValue.serverTimestamp();

    // 메시지 저장
    await _firestore
        .collection(collectionName)
        .doc(chatRoomId)
        .collection('messages')
        .add({
          'message': message,
          'senderId': currentUserId,
          'senderName': senderName,
          'timestamp': timestamp,
        });

    // 채팅방 정보 업데이트
    await _firestore.collection(collectionName).doc(chatRoomId).update({
      'lastMessage': message,
      'last_message': message,
      'lastMessageTime': timestamp,
      'last_message_time': timestamp,
      'last_message_sender_id': currentUserId,
      'last_message_sender_name': senderName,
    });

    // 채팅방의 다른 멤버들에게 푸시 알림 전송
    await _sendPushNotifications(
      chatRoomId: chatRoomId,
      message: message,
      senderName: senderName,
      collectionName: collectionName,
      currentUserId: currentUserId,
    );
  }

  Future<void> _sendPushNotifications({
    required String chatRoomId,
    required String message,
    required String senderName,
    required String collectionName,
    required String currentUserId,
  }) async {
    // 채팅방 정보 가져오기
    final chatRoom =
        await _firestore.collection(collectionName).doc(chatRoomId).get();

    if (!chatRoom.exists) return;

    final data = chatRoom.data() as Map<String, dynamic>;
    final List<String> members = List<String>.from(data['members'] ?? []);
    final String? driverId = data['driver_id'] as String?;

    // 운전자 포함 모든 멤버의 FCM 토큰 가져오기
    final List<String> recipientIds = [...members];
    if (driverId != null) recipientIds.add(driverId);

    // 현재 사용자 제외
    recipientIds.remove(currentUserId);

    for (String userId in recipientIds) {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) continue;

      final userData = userDoc.data() as Map<String, dynamic>;
      final String? fcmToken = userData['fcm_token'] as String?;

      if (fcmToken != null) {
        await _sendFcmMessage(
          token: fcmToken,
          title: senderName,
          body: message,
          data: {
            'chatRoomId': chatRoomId,
            'collectionName': collectionName,
            'senderId': currentUserId,
          },
        );
      }
    }
  }

  Future<void> _sendFcmMessage({
    required String token,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$serverKey',
        },
        body: jsonEncode({
          'notification': {'title': title, 'body': body, 'sound': 'default'},
          'data': data,
          'to': token,
          'priority': 'high',
        }),
      );
    } catch (e) {
      print('푸시 알림 전송 실패: $e');
    }
  }
}
