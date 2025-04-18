import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cabrider/globalvariable.dart';

class User {
  late String fullname;
  late String email;
  late String phone;
  late String id;

  User({
    required this.fullname,
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
    fullname = data['fullname']?.toString() ?? '';
    email = data['email']?.toString() ?? '';

    print('Firestore에서 받은 데이터:');
    print('id: $id');
    print('phone: $phone');
    print('fullname: $fullname');
    print('email: $email');
  }

  // FCM 토큰 업데이트 - Firestore 사용
  static Future<void> updateFcmToken() async {
    final currentUser = auth.FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        // Firestore에 토큰 저장
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .set({
          'fcm_token': token,
          'last_updated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));  // merge: true로 설정하여 기존 데이터 유지
        
        print('FCM 토큰이 Firestore에 업데이트되었습니다: $token');
      }
    }
  }
}
