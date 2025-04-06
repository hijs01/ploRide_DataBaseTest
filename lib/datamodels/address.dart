import 'package:flutter/material.dart';

/// Address 클래스
/// 주의: latitude, longitude, placeName, placeId, placeFormattedAddress는
/// null일 수 있으므로 사용 시 null 체크 또는 null-aware 연산자(??)를 사용해야 합니다.
class Address {
  String? placeName;
  String? placeFormattedAddress;
  String? placeId;
  double? latitude;
  double? longitude;

  Address({
    this.placeName,
    this.placeFormattedAddress,
    this.placeId,
    this.latitude,
    this.longitude,
  });
}
