import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cabrider/globalvariable.dart';

class FCMHelper {
  // FCM 토큰을 Firebase Database에 저장
  static Future<void> updateDriverFcmToken() async {
    // Firebase Messaging 인스턴스 확인
    final FirebaseMessaging fcm = FirebaseMessaging.instance;

    // 현재 FCM 토큰 가져오기
    String? token = await fcm.getToken();

    // 토큰과 사용자 ID가 유효한지 확인
    if (token != null && currentFirebaseUser != null) {
      // drivers/{driverId}/fcm_token 경로에 토큰 저장
      DatabaseReference tokenRef = FirebaseDatabase.instance.ref().child(
        'drivers/${currentFirebaseUser!.uid}/fcm_token',
      );

      await tokenRef.set(token);
      print('드라이버 FCM 토큰 저장 완료: $token');

      // FCM 토큰 갱신 리스너 설정
      fcm.onTokenRefresh.listen((newToken) {
        DatabaseReference newTokenRef = FirebaseDatabase.instance.ref().child(
          'drivers/${currentFirebaseUser!.uid}/fcm_token',
        );
        newTokenRef.set(newToken);
        print('드라이버 FCM 토큰 갱신됨: $newToken');
      });
    } else {
      print('FCM 토큰 저장 실패: 토큰 또는 사용자 ID가 없습니다.');
    }
  }
}
