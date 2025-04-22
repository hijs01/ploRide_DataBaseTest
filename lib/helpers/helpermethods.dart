import 'dart:math';
import 'dart:convert';

import 'package:TAGO/datamodels/address.dart';
import 'package:TAGO/datamodels/directiondetails.dart';
import 'package:TAGO/dataprovider/appdata.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:TAGO/globalvariable.dart';
import 'package:TAGO/helpers/requesthelper.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:TAGO/datamodels/user.dart';
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
      DocumentSnapshot userDoc =
          await FirebaseFirestore.instance
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
      // Firestore에서 드라이버 정보 확인
      DocumentSnapshot driverDoc =
          await FirebaseFirestore.instance
              .collection('drivers')
              .doc(driverId)
              .get();

      if (!driverDoc.exists) {
        print('드라이버를 찾을 수 없습니다');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('드라이버를 찾을 수 없습니다'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      final driverData = driverDoc.data() as Map<String, dynamic>;
      if (!driverData.containsKey('token')) {
        print('드라이버의 FCM 토큰을 찾을 수 없습니다');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('드라이버의 FCM 토큰을 찾을 수 없습니다'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      print('드라이버 데이터 확인: ${driverDoc.data()}');

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
    } catch (e) {
      print('드라이버 알림 저장 중 오류 발생: $e');
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

  // FCM 토큰을 Firestore에 저장
  static Future<void> updateDriverFcmToken() async {
    // Firebase Messaging 인스턴스 확인
    final FirebaseMessaging fcm = FirebaseMessaging.instance;

    // 현재 FCM 토큰 가져오기
    String? token = await fcm.getToken();
    print('새로 생성된 FCM 토큰: $token');

    // 토큰과 사용자 ID가 유효한지 확인
    if (token != null && currentFirebaseUser != null) {
      try {
        // 라이더 앱이므로 users 컬렉션에 토큰 저장 (drivers가 아님)
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentFirebaseUser!.uid)
            .set({
              'token': token,
              'last_updated': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

        print('사용자 FCM 토큰 저장 완료: $token');
        print('저장된 사용자 ID: ${currentFirebaseUser!.uid}');

        // 저장 후 확인
        final doc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(currentFirebaseUser!.uid)
                .get();
        print('저장 후 확인: ${doc.data()}');

        // FCM 토큰 갱신 리스너 설정
        fcm.onTokenRefresh.listen((newToken) async {
          print('토큰 갱신됨: $newToken');
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentFirebaseUser!.uid)
              .set({
                'token': newToken,
                'last_updated': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
          print('사용자 FCM 토큰 갱신됨: $newToken');
        });
      } catch (e) {
        print('토큰 저장 중 오류 발생: $e');
      }
    } else {
      print('FCM 토큰 저장 실패: 토큰 또는 사용자 ID가 없습니다.');
      print('토큰: $token');
      print('사용자 ID: ${currentFirebaseUser?.uid}');
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

  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // 지구 반지름 (km)

    // 위도/경도를 라디안으로 변환
    double lat1Rad = lat1 * (pi / 180);
    double lon1Rad = lon1 * (pi / 180);
    double lat2Rad = lat2 * (pi / 180);
    double lon2Rad = lon2 * (pi / 180);

    // 위도/경도 차이
    double dLat = lat2Rad - lat1Rad;
    double dLon = lon2Rad - lon1Rad;

    // Haversine 공식
    double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(dLon / 2) * sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    double distance = earthRadius * c;

    return distance;
  }
}
