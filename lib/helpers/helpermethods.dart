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

class HelperMethods {
  static Future<String> findCordinateAddress(
    Position position,
    BuildContext context,
  ) async {
    String placeAddress = "";
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult != ConnectivityResult.mobile &&
        connectivityResult != ConnectivityResult.wifi) {
      return placeAddress;
    }

    String url =
        "https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=$mapKey";

    var response = await RequestHelper.getRequest(url);

    if (response != "failed" &&
        response['results'] != null &&
        response['results'].length > 0) {
      var result = response['results'][0];
      placeAddress = result['formatted_address'];
      
      // 주소의 주요 부분 추출 (더 간단한 표시용)
      String placeName = "";
      if (result['address_components'] != null) {
        for (var component in result['address_components']) {
          var types = component['types'];
          if (types.contains('sublocality_level_1') || 
              types.contains('locality') ||
              types.contains('sublocality')) {
            placeName = component['long_name'];
            break;
          }
        }
      }
      
      // placeName이 비어있으면 전체 주소 사용
      if (placeName.isEmpty) {
        placeName = placeAddress;
      }

      Address pickupAddress = Address(
        placeName: placeName,
        latitude: position.latitude,
        longitude: position.longitude,
        placeId: result['place_id'],
        placeFormattedAddress: placeAddress,
      );

      print('Pickup address updated - Name: $placeName, Full: $placeAddress');

      Provider.of<AppData>(
        context,
        listen: false,
      ).updatePickupAddress(pickupAddress);
    }

    return placeAddress;
  }

static Future<Directiondetails?> getDirectionDetails(LatLng startPosition, LatLng endPosition) async {
    String url = "https://maps.googleapis.com/maps/api/directions/json?origin=${startPosition.latitude},${startPosition.longitude}&destination=${endPosition.latitude},${endPosition.longitude}&key=$mapKey";

    var response = await RequestHelper.getRequest(url);

    if(response == "failed"){
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

}
