import 'package:TAGO/datamodels/nearbydriver.dart';

class FireHelper {
  static List<NearbyDriver> nearbyDriverList = [];

  static void removeFromList(String key) {
    int index = nearbyDriverList.indexWhere((element) => element.key == key);
    nearbyDriverList.removeAt(index);
  }

  static void updateNearbyLocation(NearbyDriver nearbyDriver) {
    int index = nearbyDriverList.indexWhere(
      (element) => element.key == nearbyDriver.key,
    );
    nearbyDriverList[index].longitude = nearbyDriver.longitude;
    nearbyDriverList[index].latitude = nearbyDriver.latitude;
  }
}
