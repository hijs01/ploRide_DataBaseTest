import 'package:flutter/material.dart';
import 'package:cabrider/datamodels/address.dart';

class AppData extends ChangeNotifier {
  Address? pickupAddress;
  Address? destinationAddress;
  int luggageCount = 1;
  DateTime? rideDate;
  TimeOfDay? rideTime;

  // 임시 위치 저장용 필드 추가
  Address? tempPickupAddress;
  bool isPickupConfirmed = false;

  void updatePickupAddress(Address pickup) {
    pickupAddress = pickup;
    notifyListeners();
  }

  void updateDestinationAddress(Address destination) {
    destinationAddress = destination;
    notifyListeners();
  }

  void updateLuggageCount(int count) {
    luggageCount = count;
    notifyListeners();
  }

  void updateRideDateTime(DateTime date, TimeOfDay time) {
    rideDate = date;
    rideTime = time;
    notifyListeners();
  }

  // 임시 픽업 주소 저장 메서드
  void updateTempPickupAddress(Address pickup) {
    tempPickupAddress = pickup;
    isPickupConfirmed = false;
    notifyListeners();
  }

  // 임시 픽업 주소를 실제 픽업 주소로 확정하는 메서드
  void confirmPickupAddress() {
    if (tempPickupAddress != null) {
      pickupAddress = tempPickupAddress;
      isPickupConfirmed = true;
      notifyListeners();
    }
  }
}
