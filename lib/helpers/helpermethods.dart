import 'package:cabrider/datamodels/address.dart';
import 'package:cabrider/dataprovider/appdata.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cabrider/globalvariable.dart';
import 'package:cabrider/helpers/requesthelper.dart';
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
      placeAddress = response['results'][0]['formatted_address'];

      Address pickupAddress = Address(
        placeName: placeAddress,
        latitude: position.latitude,
        longitude: position.longitude,
        placeId: response['results'][0]['place_id'],
        placeFormattedAddress: placeAddress,
      );

      Provider.of<AppData>(
        context,
        listen: false,
      ).updatePickupAddress(pickupAddress);
    }

    return placeAddress;
  }
}
