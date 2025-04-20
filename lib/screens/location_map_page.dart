import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cabrider/datamodels/address.dart';
import 'package:cabrider/brand_colors.dart';
import 'package:easy_localization/easy_localization.dart';

class LocationMapPage extends StatefulWidget {
  final Address address;
  final bool isPickup;
  final Function onConfirm;

  const LocationMapPage({
    Key? key,
    required this.address,
    required this.isPickup,
    required this.onConfirm,
  }) : super(key: key);

  @override
  _LocationMapPageState createState() => _LocationMapPageState();
}

class _LocationMapPageState extends State<LocationMapPage> {
  late GoogleMapController mapController;
  Set<Marker> _markers = {};
  final Color primaryColor = Color(0xFF3F51B5);

  @override
  void initState() {
    super.initState();
    // 마커 초기화
    _setMarker();
  }

  void _setMarker() {
    // 위치 좌표가 없으면 마커를 추가하지 않음
    if (widget.address.latitude == null || widget.address.longitude == null) {
      return;
    }

    setState(() {
      _markers.add(
        Marker(
          markerId: MarkerId('location_marker'),
          position: LatLng(widget.address.latitude!, widget.address.longitude!),
          infoWindow: InfoWindow(
            title: widget.address.placeName ?? '선택한 위치',
            snippet: widget.address.placeFormattedAddress ?? '',
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // 위치 좌표가 없으면 오류 메시지 표시
    if (widget.address.latitude == null || widget.address.longitude == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('app.search.location_map.title_error'.tr()),
          backgroundColor: primaryColor
        ),
        body: Center(child: Text('app.search.location_map.invalid_location'.tr())),
      );
    }

    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    final backgroundColor = isDarkMode ? Colors.black : Colors.white;
    final textColor = isDarkMode ? Colors.white : BrandColors.colorTextDark;
    final cardColor = isDarkMode ? Color(0xFF202020) : Colors.white;
    final borderColor = isDarkMode ? Colors.grey[800] : Colors.grey[300];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        title: Text(
          widget.isPickup 
            ? 'app.search.location_map.title_pickup'.tr()
            : 'app.search.location_map.title_destination'.tr(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Stack(
        children: [
          // 구글 지도 컨테이너
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(0),
              border: Border.all(
                color: borderColor ?? Colors.transparent,
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(0),
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(
                    widget.address.latitude!,
                    widget.address.longitude!,
                  ),
                  zoom: 16,
                ),
                markers: _markers,
                mapType: MapType.normal,
                myLocationEnabled: true,
                zoomControlsEnabled: false,
                zoomGesturesEnabled: true,
                myLocationButtonEnabled: true,
                onMapCreated: (GoogleMapController controller) {
                  mapController = controller;

                  // 다크 모드일 경우 지도 스타일 변경
                  if (isDarkMode) {
                    // 다크 모드 스타일 적용 (필요시 구현)
                  }
                },
              ),
            ),
          ),

          // 위치 정보 카드
          Positioned(
            bottom: 90,
            left: 20,
            right: 20,
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: borderColor ?? Colors.transparent,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        isDarkMode
                            ? Colors.black.withOpacity(0.3)
                            : Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          widget.isPickup
                              ? Icons.location_on
                              : Icons.location_city,
                          color: primaryColor,
                          size: 24,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.address.placeName ?? '선택한 위치',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: textColor,
                                letterSpacing: 0.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            SizedBox(height: 4),
                            Text(
                              widget.address.placeFormattedAddress ?? '',
                              style: TextStyle(
                                color:
                                    isDarkMode
                                        ? Colors.grey[300]
                                        : BrandColors.colorTextSemiLight,
                                fontSize: 14,
                                letterSpacing: 0.1,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 확인 버튼
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  widget.onConfirm();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'app.search.location_map.confirm'.tr(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
