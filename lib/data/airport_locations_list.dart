import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:TAGO/dataprovider/appdata.dart';
import 'package:TAGO/datamodels/address.dart';

class AirportLocationsList extends StatelessWidget {
  final bool isDarkMode;
  final Function(Address) onLocationSelected;
  final Function(String) updateTextField;

  const AirportLocationsList({
    Key? key,
    required this.isDarkMode,
    required this.onLocationSelected,
    required this.updateTextField,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subTextColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];

    // 공항 위치 리스트
    final airportLocations = [
      {
        'name': 'Harrisburg International Airport (MDT)',
        'address': '1 Terminal Dr, Middletown, PA 17057',
        'lat': 40.193432,
        'lng': -76.763680,
      },
      {
        'name': 'University Park Airport (SCE)',
        'address': '2535 Fox Hill Rd, State College, PA 16803',
        'lat': 40.851120,
        'lng': -77.848553,
      },
      {
        'name': 'Pittsburgh International Airport (PIT)',
        'address': '1000 Airport Blvd, Pittsburgh, PA 15231',
        'lat': 40.491457,
        'lng': -80.232530,
      },
      {
        'name': 'Philadelphia International Airport (PHL)',
        'address': '8000 Essington Ave, Philadelphia, PA 19153',
        'lat': 39.872399,
        'lng': -75.242142,
      },
      {
        'name': 'Baltimore/Washington Airport (BWI)',
        'address': 'Baltimore, MD 21240',
        'lat': 39.177402,
        'lng': -76.668314,
      },
      {
        'name': 'Newark Liberty Airport (EWR)',
        'address': '3 Brewster Rd, Newark, NJ 07114',
        'lat': 40.689531,
        'lng': -74.174462,
      },
      {
        'name': 'John F. Kennedy Airport (JFK)',
        'address': 'Queens, NY 11430',
        'lat': 40.641766,
        'lng': -73.780968,
      },
    ];

    return ListView.builder(
      itemCount: airportLocations.length,
      itemBuilder: (context, index) {
        final location = airportLocations[index];

        return ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          onTap: () {
            // 목적지 주소로 저장
            Address destinationAddress = Address(
              placeName: location['name'] as String,
              placeFormattedAddress: location['address'] as String,
              latitude: location['lat'] as double,
              longitude: location['lng'] as double,
              placeId: 'airport_${index}', // 임의의 placeId 생성
            );

            // 목적지 주소 저장
            Provider.of<AppData>(
              context,
              listen: false,
            ).updateDestinationAddress(destinationAddress);

            // 텍스트 필드 업데이트
            updateTextField(location['name'] as String);

            // 위치와 함께 선택 완료 콜백 호출
            onLocationSelected(destinationAddress);
          },
          leading: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Color(0xFF3F51B5).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.flight, color: Color(0xFF3F51B5)),
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
