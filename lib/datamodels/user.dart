import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:TAGO/globalvariable.dart';
import 'dart:io';

class User {
  late String fullName;
  late String email;
  late String phone;
  late String id;

  User({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.id,
  });

  // // Realtime Database용 생성자
  // User.fromSnapshot(DataSnapshot snapshot) {
  //   id = snapshot.key ?? '';
  //   Map<dynamic, dynamic> values = snapshot.value as Map<dynamic, dynamic>;
  //   phone = values['phone']?.toString() ?? '';
  //   fullName = values['fullname']?.toString() ?? '';
  //   email = values['email']?.toString() ?? '';

  //   print('Firebase에서 받은 데이터:');
  //   print('id: $id');
  //   print('phone: $phone');
  //   print('fullName: $fullName');
  //   print('email: $email');
  // }

  // Firestore용 생성자
  User.fromFirestore(DocumentSnapshot doc) {
    id = doc.id;
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    phone = data['phone']?.toString() ?? '';
    fullName = data['fullname']?.toString() ?? '';
    email = data['email']?.toString() ?? '';

    print('Firestore에서 받은 데이터:');
    print('id: $id');
    print('phone: $phone');
    print('fullName: $fullName');
    print('email: $email');
  }

  // FCM 토큰 업데이트 - Firestore 사용
  Future<void> updateFcmToken() async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(id).update({
          'fcm_token': token,
          'token_updated_at': FieldValue.serverTimestamp(),
          'platform': Platform.isIOS ? 'ios' : 'android',
        });
        print('FCM 토큰이 성공적으로 업데이트되었습니다: $token');
      }
    } catch (e) {
      print('FCM 토큰 업데이트 중 오류 발생: $e');
    }
  }
}
