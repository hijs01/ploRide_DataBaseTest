import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cabrider/globalvariable.dart';
import 'package:cabrider/helpers/requesthelper.dart';

class HelperMethods{
  static Future<String> findCordinateAddress(Position position) async{

    String placeAddress = "";
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult != ConnectivityResult.mobile && connectivityResult != ConnectivityResult.wifi){
      return placeAddress;
    }

    String url = "https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=$mapKey";

    var response = await RequestHelper.getRequest(url);

    if(response != "failed" && response['results'] != null && response['results'].length > 0){
      placeAddress = response['results'][0]['formatted_address'];
    }

    return placeAddress; 


  }
}