import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});
  static const String id = 'mainpage';

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  Completer<GoogleMapController> _controller = Completer();
  late GoogleMapController mapController;
  bool _mapLoaded = false;

  static const CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(37.42796133580664, -122.085749655962),
    zoom: 14.4746,
  );

  // 현재 위치 변수 추가
  Position? currentPosition;

  // 위치 권한 요청 함수
  Future<void> _checkLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 위치 서비스가 활성화되어 있는지 확인
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // 위치 서비스가 비활성화되어 있으면 사용자에게 알림
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('위치 서비스가 비활성화되어 있습니다. 설정에서 활성화해주세요.')),
      );
      return;
    }

    // 위치 권한 확인
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // 권한이 거부되었으면 요청
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // 권한이 다시 거부되면 사용자에게 알림
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('위치 권한이 거부되었습니다.')));
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // 권한이 영구적으로 거부되었으면 사용자에게 알림
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('위치 권한이 영구적으로 거부되었습니다. 설정에서 변경해주세요.')),
      );
      return;
    }

    // 권한이 허용되었으면 현재 위치 가져오기
    _getCurrentLocation();
  }

  // 현재 위치 가져오기
  void _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        currentPosition = position;
      });

      // 현재 위치로 카메라 이동
      LatLng latLng = LatLng(position.latitude, position.longitude);
      CameraPosition cameraPosition = CameraPosition(target: latLng, zoom: 14);
      mapController.animateCamera(
        CameraUpdate.newCameraPosition(cameraPosition),
      );
    } catch (e) {
      print('위치를 가져오는 중 오류 발생: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    // 앱 시작 시 위치 권한 확인
    _checkLocationPermission();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Main Page', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.black,
      ),
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            Container(
              height: MediaQuery.of(context).size.height,
              width: MediaQuery.of(context).size.width,
              child: GoogleMap(
                mapType: MapType.normal,
                myLocationButtonEnabled: true,
                myLocationEnabled: true,
                zoomControlsEnabled: true,
                zoomGesturesEnabled: true,
                initialCameraPosition: _kGooglePlex,
                onMapCreated: (GoogleMapController controller) {
                  _controller.complete(controller);
                  mapController = controller;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
