import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cabrider/globalvariable.dart';

class FCMHelper {
  // FCM 토큰을 Firestore에 저장
  static Future<void> updateDriverFcmToken() async {
    // Firebase Messaging 인스턴스 확인
    final FirebaseMessaging fcm = FirebaseMessaging.instance;

    // 현재 FCM 토큰 가져오기
    String? token = await fcm.getToken();

    // 토큰과 사용자 ID가 유효한지 확인
    if (token != null && currentFirebaseUser != null) {
      // drivers 컬렉션에 토큰 저장
      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(currentFirebaseUser!.uid)
          .set({
        'fcm_token': token,
        'last_updated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));  // merge: true로 설정하여 기존 데이터 유지
      
      print('드라이버 FCM 토큰 저장 완료: $token');

      // FCM 토큰 갱신 리스너 설정
      fcm.onTokenRefresh.listen((newToken) async {
        await FirebaseFirestore.instance
            .collection('drivers')
            .doc(currentFirebaseUser!.uid)
            .set({
          'fcm_token': newToken,
          'last_updated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        print('드라이버 FCM 토큰 갱신됨: $newToken');
      });
    } else {
      print('FCM 토큰 저장 실패: 토큰 또는 사용자 ID가 없습니다.');
    }
  }
}
