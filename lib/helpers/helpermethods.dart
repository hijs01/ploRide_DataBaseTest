import 'dart:math';

import 'package:cabrider/datamodels/address.dart';
import 'package:cabrider/datamodels/directiondetails.dart';
import 'package:cabrider/dataprovider/appdata.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cabrider/globalvariable.dart';
import 'package:cabrider/helpers/requesthelper.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_database/firebase_database.dart';
import 'package:cabrider/datamodels/user.dart';

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

    DatabaseReference userRef = FirebaseDatabase.instance.ref().child(
      'users/$userID',
    );
    print('Firebase 참조 경로: users/$userID');

    try {
      final event = await userRef.once();
      print('Firebase 응답 받음');

      if (event.snapshot.value != null) {
        print('사용자 데이터 존재함');
        currentUserInfo = User.fromSnapshot(event.snapshot);
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
}
