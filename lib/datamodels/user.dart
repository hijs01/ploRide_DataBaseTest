import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cabrider/globalvariable.dart';

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

  User.fromSnapshot(DataSnapshot snapshot) {
    id = snapshot.key ?? '';
    Map<dynamic, dynamic> values = snapshot.value as Map<dynamic, dynamic>;
    phone = values['phone']?.toString() ?? '';
    fullName = values['fullname']?.toString() ?? '';
    email = values['email']?.toString() ?? '';

    print('Firebase에서 받은 데이터:');
    print('id: $id');
    print('phone: $phone');
    print('fullName: $fullName');
    print('email: $email');
  }

  static Future<void> updateFcmToken() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        DatabaseReference tokenRef = FirebaseDatabase.instance.ref().child(
          'users/${currentUser.uid}/fcm_token',
        );
        await tokenRef.set(token);
        print('FCM 토큰이 업데이트되었습니다: $token');
      }
    }
  }
}
