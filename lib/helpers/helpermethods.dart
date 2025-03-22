import 'dart:math';
import 'dart:convert';

import 'package:cabrider/datamodels/address.dart';
import 'package:cabrider/datamodels/directiondetails.dart';
import 'package:cabrider/dataprovider/appdata.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cabrider/globalvariable.dart';
import 'package:cabrider/helpers/requesthelper.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_database/firebase_database.dart';
import 'package:cabrider/datamodels/user.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_geofire/flutter_geofire.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HelperMethods {
  static void getCurrentUserInfo() async {
    print('getCurrentUserInfo 시작');
    currentFirebaseUser = auth.FirebaseAuth.instance.currentUser;

    if (currentFirebaseUser == null) {
      print('로그인되어 있지 않습니다.');
      return;
    }

    print('현재 로그인된 사용자 ID: ${currentFirebaseUser!.uid}');
    String userID = currentFirebaseUser!.uid;

    try {
      // Firestore에서 사용자 데이터 조회
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userID)
          .get();
      
      print('Firestore 응답 받음');

      if (userDoc.exists) {
        print('사용자 데이터 존재함');
        currentUserInfo = User.fromFirestore(userDoc);
        print('사용자 정보 로드 완료:');
        print('- 이름: ${currentUserInfo?.fullName}');
        print('- 이메일: ${currentUserInfo?.email}');
        print('- 전화번호: ${currentUserInfo?.phone}');
      } else {
        print('사용자 정보를 찾을 수 없습니다.');
      }
    } catch (e) {
      print('사용자 정보 조회 중 오류 발생: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  static Future<String> findCordinateAddress(
    Position position,
    BuildContext context,
  ) async {
    String placeAddress = "";

    // 네트워크 연결 상태 확인
    var connectivityResult = await Connectivity().checkConnectivity();
    print('네트워크 연결 상태: $connectivityResult');

    if (connectivityResult == ConnectivityResult.none) {
      print('네트워크 연결이 없습니다.');
      // 사용자에게 네트워크 오류 알림
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('네트워크 연결을 확인해주세요.'),
          duration: Duration(seconds: 3),
        ),
      );
      return placeAddress;
    }

    String url =
        "https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=$mapKey";

    print('Geocoding API 요청 URL: $url');

    try {
      var response = await RequestHelper.getRequest(url);
      print('Geocoding API 응답: $response');

      if (response == "failed") {
        print('Geocoding API 요청 실패');
        // 사용자에게 API 오류 알림
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('주소 정보를 가져오는데 실패했습니다. 잠시 후 다시 시도해주세요.'),
            duration: Duration(seconds: 3),
          ),
        );
        return placeAddress;
      }

      if (response != "failed" &&
          response['results'] != null &&
          response['results'].length > 0) {
        var result = response['results'][0];
        placeAddress = result['formatted_address'];

        print('받아온 전체 주소: $placeAddress');

        // 주소의 주요 부분 추출 (더 간단한 표시용)
        String placeName = "";
        if (result['address_components'] != null) {
          for (var component in result['address_components']) {
            var types = component['types'];
            print('주소 컴포넌트: ${component['long_name']} (타입: $types)');
            if (types.contains('sublocality_level_1') ||
                types.contains('locality') ||
                types.contains('sublocality')) {
              placeName = component['long_name'];
              print('선택된 placeName: $placeName');
              break;
            }
          }
        }

        // placeName이 비어있으면 전체 주소 사용
        if (placeName.isEmpty) {
          placeName = placeAddress;
          print('placeName이 비어있어 전체 주소를 사용: $placeName');
        }

        Address pickupAddress = Address(
          placeName: placeName,
          latitude: position.latitude,
          longitude: position.longitude,
          placeId: result['place_id'],
          placeFormattedAddress: placeAddress,
        );

        print('생성된 Address 객체:');
        print('- placeName: ${pickupAddress.placeName}');
        print(
          '- placeFormattedAddress: ${pickupAddress.placeFormattedAddress}',
        );
        print('- placeId: ${pickupAddress.placeId}');

        Provider.of<AppData>(
          context,
          listen: false,
        ).updatePickupAddress(pickupAddress);
      } else {
        print('Geocoding API 응답에 결과가 없습니다.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('주소 정보를 찾을 수 없습니다.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('API 요청 중 오류 발생: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('주소 정보를 가져오는 중 오류가 발생했습니다.'),
          duration: Duration(seconds: 3),
        ),
      );
    }

    return placeAddress;
  }

  static Future<Directiondetails?> getDirectionDetails(
    LatLng startPosition,
    LatLng endPosition,
  ) async {
    String url =
        "https://maps.googleapis.com/maps/api/directions/json?origin=${startPosition.latitude},${startPosition.longitude}&destination=${endPosition.latitude},${endPosition.longitude}&key=$mapKey";

    var response = await RequestHelper.getRequest(url);

    if (response == "failed") {
      return null;
    }

    return Directiondetails(
      distanceText: response['routes'][0]['legs'][0]['distance']['text'],
      distanceValue: response['routes'][0]['legs'][0]['distance']['value'],
      durationText: response['routes'][0]['legs'][0]['duration']['text'],
      durationValue: response['routes'][0]['legs'][0]['duration']['value'],
      encodedPoints: response['routes'][0]['overview_polyline']['points'],
    );
  }

  static int estimateFares(Directiondetails details) {
    double baseFare = 3;
    double distanceFare = (details.distanceValue / 1000) * 0.3;
    double timeFare = (details.durationValue / 60) * 0.2;

    double totalFare = baseFare + distanceFare + timeFare;

    return totalFare.truncate();
  }

  static double generateRandomNumber(int max) {
    var randomGenerator = Random();
    int randInt = randomGenerator.nextInt(max);
    return randInt.toDouble();
  }

  static Future<void> sendNotification({
    required String driverId,
    required BuildContext context,
    required String? ride_id,
  }) async {
    if (ride_id == null) {
      print('ride_id가 null입니다');
      return;
    }

    var destination =
        Provider.of<AppData>(context, listen: false).destinationAddress;
    var pickup = Provider.of<AppData>(context, listen: false).pickupAddress;

    // 알림 전송 정보 로깅
    print('===== 드라이버 알림 정보 =====');
    print('드라이버 ID: $driverId');
    print('픽업 지점: ${pickup?.placeName}');
    print('목적지: ${destination?.placeName}');
    print('라이드 ID: $ride_id');
    print('============================');

    // 드라이버 상태 확인
    try {
      // 1. Firestore에서 드라이버 정보 확인
      DocumentSnapshot driverDoc = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(driverId)
          .get();

      if (!driverDoc.exists) {
        print('경고: 드라이버 ID $driverId에 해당하는 데이터가 없습니다!');

        // 드라이버 문서 생성 시도
        await FirebaseFirestore.instance.collection('drivers').doc(driverId).set({
          'newtrip': ride_id,
          'created_at': FieldValue.serverTimestamp(),
        });
        print('드라이버 문서를 새로 생성했습니다: drivers/$driverId');
      } else {
        print('드라이버 데이터 확인: ${driverDoc.data()}');
      }

      // 2. 드라이버에게 알림 저장
      Map<String, dynamic> notificationData = {
        'ride_id': ride_id,
        'pickup_address': pickup?.placeName ?? '',
        'destination_address': destination?.placeName ?? '',
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
        'read': false,
      };

      // Firestore에 알림 저장
      DocumentReference notificationRef = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(driverId)
          .collection('notifications')
          .add(notificationData);
      
      print('Firestore에 알림 저장 완료: ${notificationRef.id}');

      // 3. 드라이버 문서에 새 알림 정보 업데이트
      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(driverId)
          .update({
        'has_new_notification': true,
        'last_notification': notificationData,
        'last_notification_time': FieldValue.serverTimestamp(),
      });
      
      print('드라이버 문서 업데이트 완료');
    } catch (e) {
      print('드라이버 알림 저장 중 오류 발생: $e');
    }

    // Firebase Cloud Function을 호출하여 드라이버에게 알림 전송
    try {
      // Cloud Function URL
      String url =
          'https://us-central1-geetaxi-aa379.cloudfunctions.net/sendPushToDriver';

      // 요청 데이터 준비
      Map<String, dynamic> requestData = {
        'driverId': driverId,
        'rideId': ride_id,
        'pickup_address': pickup?.placeName ?? '',
        'destination_address': destination?.placeName ?? '',
      };

      print('Cloud Function 호출: $url');
      print('요청 데이터: $requestData');

      // HTTP POST 요청 보내기
      var response = await http.post(
        Uri.parse(url),
        body: jsonEncode(requestData),
        headers: {'Content-Type': 'application/json'},
      );

      print('응답 상태 코드: ${response.statusCode}');
      print('응답 내용: ${response.body}');

      if (response.statusCode == 200) {
        // 성공 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('드라이버에게 요청이 전송되었습니다'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        // 오류 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('드라이버 알림 전송에 실패했습니다'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('HTTP 요청 중 오류 발생: $e');
      // 오류 메시지 표시
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('네트워크 오류로 알림 전송에 실패했습니다'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // 문제가 되는 함수들 주석 처리
  /*
  static void disableHomTabLocationUpdates() {
    homeTabPositionStream?.pause();
    Geofire.removeLocation(currentFirebaseUser!.uid);
  }

  static void enableHomTabLocationUpdates() {
    homeTabPositionStream?.resume();
    Geofire.setLocation(
      currentFirebaseUser!.uid,
      currentPosition!.latitude,
      currentPosition!.longitude,
    );
  }
  */

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

  // ProgressDialog 관련 함수 주석 처리
  /*
  static void showProgressDialog(context) {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder:
          (BuildContext context) =>
              const ProgressDialog(status: "Please wait..."),
    );
  }
  */
}
