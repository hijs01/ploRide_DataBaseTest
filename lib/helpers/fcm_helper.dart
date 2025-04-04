import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cabrider/globalvariable.dart';

class FCMHelper {
  // 드라이버에게 알림 보내기
  static Future<void> sendNotificationToDriver(String driverId, {
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      // 드라이버 문서에서 token 가져오기
      final driverDoc = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(driverId)
          .get();

      if (!driverDoc.exists) {
        print('드라이버를 찾을 수 없습니다.');
        return;
      }

      final driverData = driverDoc.data();
      final driverToken = driverData?['token'] as String?;

      if (driverToken == null) {
        print('드라이버의 FCM 토큰을 찾을 수 없습니다.');
        return;
      }

      // Cloud Functions를 통해 알림 전송
      // 실제 알림 전송은 Firebase Cloud Functions에서 처리
      print('드라이버 토큰 확인: $driverToken');
      print('알림 전송 준비 완료');
    } catch (e) {
      print('알림 전송 준비 중 오류 발생: $e');
    }
  }
}
