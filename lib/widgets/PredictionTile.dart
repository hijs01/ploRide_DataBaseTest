import 'package:TAGO/brand_colors.dart';
import 'package:TAGO/widgets/ProgressDialog.dart';
import 'package:flutter/material.dart';
import 'package:TAGO/datamodels/prediction.dart';
import 'package:TAGO/helpers/requesthelper.dart';
import 'package:TAGO/datamodels/address.dart';
import 'package:TAGO/dataprovider/appdata.dart';
import 'package:provider/provider.dart';
import 'package:TAGO/globalvariable.dart';

class PredictionTile extends StatelessWidget {
  final Prediction prediction;
  final bool isPickup;

  const PredictionTile({
    super.key,
    required this.prediction,
    this.isPickup = false,
  });

  void getPlaceDetails(String placeId, context) async {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder:
          (BuildContext context) =>
              const ProgressDialog(status: 'Please wait...'),
    );

    String url =
        'https://maps.googleapis.com/maps/api/place/details/json?placeid=$placeId&key=$mapKey';

    var response = await RequestHelper.getRequest(url);

    Navigator.pop(context);

    if (response == 'failed') {
      return;
    }

    if (response['status'] == 'OK') {
      Address thisPlace = Address(
        placeName: response['result']['name'],
        placeId: placeId,
        latitude: response['result']['geometry']['location']['lat'],
        longitude: response['result']['geometry']['location']['lng'],
        placeFormattedAddress: response['result']['formatted_address'],
      );

      if (isPickup) {
        Provider.of<AppData>(
          context,
          listen: false,
        ).updatePickupAddress(thisPlace);
      } else {
        Provider.of<AppData>(
          context,
          listen: false,
        ).updateDestinationAddress(thisPlace);
      }

      print(thisPlace.placeName);

      Navigator.pop(context, 'getDirection');
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      // FlatButton 대신 TextButton 사용
      onPressed: () {
        getPlaceDetails(prediction.placeId, context);
      },
      style: TextButton.styleFrom(padding: EdgeInsets.zero),
      child: Container(
        child: Column(
          children: <Widget>[
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                const Icon(Icons.location_on, color: BrandColors.colorDimText),
                // OMIcons.locationON 대신에 Icons.location_on 사용
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        prediction.mainText,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        prediction.secondaryText,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: BrandColors.colorDimText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
