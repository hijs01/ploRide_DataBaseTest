import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cabrider/dataprovider/appdata.dart';
import 'package:cabrider/datamodels/address.dart';
import 'package:cabrider/screens/mainpage.dart';

class PsuLocationsList extends StatelessWidget {
  final bool isDarkMode;
  final Function(Address) onLocationSelected;

  const PsuLocationsList({
    Key? key,
    required this.isDarkMode,
    required this.onLocationSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subTextColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];

    // PSU 위치 리스트
    final psuLocations = [
      {
        'name': 'Penn State University - HUB',
        'address': 'Hetzel Union Building, University Park, PA 16802',
        'lat': 40.798431,
        'lng': -77.859728,
      },
      {
        'name': 'Penn State University - Pollock Commons',
        'address': 'Pollock Commons, University Park, PA 16802',
        'lat': 40.800735,
        'lng': -77.865509,
      },
      {
        'name': 'Penn State University - East Halls',
        'address': 'East Halls, University Park, PA 16802',
        'lat': 40.806178,
        'lng': -77.855179,
      },
      {
        'name': 'Penn State University - North Halls',
        'address': 'North Halls, University Park, PA 16802',
        'lat': 40.806847,
        'lng': -77.865033,
      },
      {
        'name': 'Penn State University - West Halls',
        'address': 'West Halls, University Park, PA 16802',
        'lat': 40.801917,
        'lng': -77.867226,
      },
      {
        'name': 'Penn State University - South Halls',
        'address': 'South Halls, University Park, PA 16802',
        'lat': 40.793833,
        'lng': -77.863107,
      },
      {
        'name': 'Penn State University - IST Building',
        'address':
            'Information Sciences & Technology Building, University Park, PA 16802',
        'lat': 40.794758,
        'lng': -77.867096,
      },
      {
        'name': 'Penn State University - Beaver Stadium',
        'address': 'Beaver Stadium, University Park, PA 16802',
        'lat': 40.812106,
        'lng': -77.856178,
      },
    ];

    return ListView.builder(
      itemCount: psuLocations.length,
      itemBuilder: (context, index) {
        final location = psuLocations[index];

        return ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          onTap: () {
            // 픽업 주소로 저장
            Address pickupAddress = Address(
              placeName: location['name'] as String,
              placeFormattedAddress: location['address'] as String,
              latitude: location['lat'] as double,
              longitude: location['lng'] as double,
              placeId: 'psu_${index}', // 임의의 placeId 생성
            );

            // 임시 주소로 저장
            Provider.of<AppData>(
              context,
              listen: false,
            ).updateTempPickupAddress(pickupAddress);

            // 선택한 위치 정보를 콜백 함수로 전달
            onLocationSelected(pickupAddress);
          },
          leading: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Color(0xFF3F51B5).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.location_on, color: Color(0xFF3F51B5)),
          ),
          title: Text(
            location['name'] as String,
            style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
          ),
          subtitle: Text(
            location['address'] as String,
            style: TextStyle(color: subTextColor, fontSize: 13),
          ),
        );
      },
    );
  }
}
