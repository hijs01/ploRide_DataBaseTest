// 섹션7 31강 코드

import 'package:cabrider/brand_colors.dart';
import 'package:cabrider/dataprovider/appdata.dart';
import 'package:cabrider/globalvariable.dart'; // globalvariable 강의에선 이거 임포트 돼있길래 일단 써놨음
import 'package:cabrider/helpers/requesthelper.dart';
import 'package:cabrider/widgets/PredictionTile.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; //provider 임포트인데 그전 강의에서 설치하는듯? 그전 강의에 없는거면 임포트 주소 바꾸기
import 'package:cabrider/datamodels/prediction.dart';
import 'package:cabrider/widgets/BrandDivider.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  var pickupController = TextEditingController();
  var destinationController = TextEditingController();

  var focusDestination = FocusNode();

  bool focused = false;

  void setFocus() {
    if (!focused) {
      FocusScope.of(context).requestFocus(focusDestination);
      focused = true;
    }
  }

  List<Prediction> destinationPredictionList = [];

  void searchPlace(String placeName) async {
    if (placeName.length > 1) {
      String url =
          'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$placeName&key=$mapKey&sessiontoken=123254251&components=country:us';
      var response = await RequestHelper.getRequest(
        url,
      ); // RequestHelper인데 그전강의에서 설치할듯?

      if (response == 'failed') {
        return;
      }
      if (response['status'] == 'OK') {
        var predictionJson = response['predictions'];
        var thisList =
            (predictionJson as List)
                .map((e) => Prediction.fromJson(e))
                .toList();

        setState(() {
          destinationPredictionList = thisList;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    setFocus();

    String address =
        Provider.of<AppData>(context).pickupAddress?.placeFormattedAddress ??
        '';
    pickupController.text = address;

    return Scaffold(
      body: Column(
        children: <Widget>[
          Container(
            height: 218,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 5.0,
                  spreadRadius: 0.5,
                  offset: Offset(0.7, 0.7),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.only(
                left: 24,
                top: 48,
                right: 24,
                bottom: 20,
              ),
              child: Column(
                children: <Widget>[
                  SizedBox(height: 5),
                  Stack(
                    children: <Widget>[
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                        },
                        child: Icon(Icons.arrow_back),
                      ),
                      Center(
                        child: Text(
                          'Set Destination',
                          style: TextStyle(
                            fontSize: 20,
                            fontFamily: 'Brand-Bold',
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 18),

                  Row(
                    children: <Widget>[
                      Image.asset('images/pickicon.png', height: 16, width: 16),

                      SizedBox(width: 18),

                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: BrandColors.colorLightGrayFair,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(2.0),
                            child: TextField(
                              controller: pickupController,
                              decoration: InputDecoration(
                                hintText: 'Pickup Location',
                                fillColor: BrandColors.colorLightGrayFair,
                                filled: true,
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.only(
                                  left: 10,
                                  top: 8,
                                  bottom: 8,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 10),

                  Row(
                    children: <Widget>[
                      Image.asset('images/desticon.png', height: 16, width: 16),

                      SizedBox(width: 18),

                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: BrandColors.colorLightGrayFair,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(2.0),
                            child: TextField(
                              onChanged: (value) {
                                searchPlace(value);
                              },
                              focusNode: focusDestination,
                              controller: destinationController,
                              decoration: InputDecoration(
                                hintText: 'Where to?',
                                fillColor: BrandColors.colorLightGrayFair,
                                filled: true,
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.only(
                                  left: 10,
                                  top: 8,
                                  bottom: 8,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          (destinationPredictionList.isNotEmpty)
              ? Padding(
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: ListView.separated(
                  padding: EdgeInsets.all(0),
                  itemBuilder: (context, index) {
                    return PredictionTile(
                      prediction: destinationPredictionList[index],
                    );
                  },
                  separatorBuilder:
                      (BuildContext context, int index) => BrandDivider(),
                  itemCount: destinationPredictionList.length,
                  shrinkWrap: true,
                  physics: ClampingScrollPhysics(),
                ),
              )
              : Container(),
        ],
      ),
    );
  }
}
