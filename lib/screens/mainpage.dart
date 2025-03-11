import 'package:flutter/material.dart';
import 'package:cabrider/dataprovider/appdata.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:cabrider/brand_colors.dart';
import 'package:outline_material_icons/outline_material_icons.dart';
import 'dart:io' show Platform;
import 'package:cabrider/helpers/helpermethods.dart';
import 'package:cabrider/styles/styles.dart';
import 'package:cabrider/widgets/BrandDivider.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cabrider/screens/searchpage.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});
  static const String id = 'mainpage';

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  double searchSheetHeight = (Platform.isIOS) ? 300 : 275;

  final Completer<GoogleMapController> _controller = Completer();
  late GoogleMapController mapController;
  final bool _mapLoaded = false;

  double mapBottomPadding = 0;

  static const CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(37.42796133580664, -122.085749655962),
    zoom: 14.4746,
  );

  // 현재 위치 변수 추가
  Position? currentPosition;
  void SetupPositionLocator() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );
      print('현재 위치: ${position.latitude}, ${position.longitude}'); // 디버깅용 로그

      setState(() {
        currentPosition = position;
      });

      LatLng pos = LatLng(position.latitude, position.longitude);
      CameraPosition cp = CameraPosition(target: pos, zoom: 14);

      // 지도 이동이 성공했는지 확인
      try {
        await mapController.animateCamera(CameraUpdate.newCameraPosition(cp));
        print('지도 이동 성공: ${pos.latitude}, ${pos.longitude}');

        // 현재 카메라 위치 확인
        final cameraPosition = await mapController.getLatLng(
          ScreenCoordinate(x: 0, y: 0),
        );
        print(
          '현재 카메라 위치: ${cameraPosition.latitude}, ${cameraPosition.longitude}',
        );
      } catch (e) {
        print('지도 이동 실패: $e');
      }

      String address = await HelperMethods.findCordinateAddress(
        position,
        context,
      );
      print('현재 주소: $address');
    } catch (e) {
      print('위치 설정 중 오류 발생: $e');
    }
  }

  // 위치 권한 요청 함수
  Future<void> _checkLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    try {
      // 위치 서비스가 활성화되어 있는지 확인
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      print('위치 서비스 활성화 상태: $serviceEnabled'); // 디버깅용 로그

      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('위치 서비스가 비활성화되어 있습니다. 설정에서 활성화해주세요.')),
        );
        return;
      }

      // 위치 권한 확인
      permission = await Geolocator.checkPermission();
      print('현재 위치 권한 상태: $permission'); // 디버깅용 로그

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        print('위치 권한 요청 결과: $permission'); // 디버깅용 로그

        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('위치 권한이 거부되었습니다.')));
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('위치 권한이 영구적으로 거부되었습니다. 설정에서 변경해주세요.')),
        );
        return;
      }

      // 권한이 허용되었으면 위치 설정 시작
      SetupPositionLocator();
    } catch (e) {
      print('위치 권한 확인 중 오류 발생: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    // 앱 시작 시 약간의 지연 후 위치 권한 확인
    Future.delayed(const Duration(seconds: 1), () {
      _checkLocationPermission();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: Container(
        width: 250,
        color: Colors.white,
        child: Drawer(
          child: ListView(
            padding: EdgeInsets.all(0),
            children: [
              Container(
                color: Colors.white,
                height: 160,
                child: DrawerHeader(
                  decoration: BoxDecoration(color: Colors.white),
                  child: Row(
                    children: [
                      Image.asset(
                        'images/user_icon.png',
                        height: 60,
                        width: 60,
                      ),
                      SizedBox(width: 15),

                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'John Doe',
                            style: TextStyle(
                              fontSize: 20,
                              fontFamily: 'Brand-Bold',
                            ),
                          ),
                          SizedBox(height: 5),
                          Text('View Profile'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              BrandDivider(),

              SizedBox(height: 10),

              ListTile(
                leading: Icon(OMIcons.cardGiftcard),
                title: Text('Free Rides', style: kDrawerHeaderStyle),
              ),

              ListTile(
                leading: Icon(OMIcons.creditCard),
                title: Text('Payment', style: kDrawerHeaderStyle),
              ),

              ListTile(
                leading: Icon(OMIcons.history),
                title: Text('Ride History', style: kDrawerHeaderStyle),
              ),

              ListTile(
                leading: Icon(OMIcons.contactSupport),
                title: Text('Support', style: kDrawerHeaderStyle),
              ),

              ListTile(
                leading: Icon(OMIcons.info),
                title: Text('About', style: kDrawerHeaderStyle),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            SizedBox(
              height: MediaQuery.of(context).size.height,
              width: MediaQuery.of(context).size.width,
              child: GoogleMap(
                padding: EdgeInsets.only(bottom: mapBottomPadding),
                mapType: MapType.normal,
                myLocationButtonEnabled: true,
                myLocationEnabled: true,
                zoomControlsEnabled: true,
                zoomGesturesEnabled: true,
                initialCameraPosition: _kGooglePlex,
                compassEnabled: true,
                tiltGesturesEnabled: true,
                rotateGesturesEnabled: true,
                trafficEnabled: false,
                onMapCreated: (GoogleMapController controller) async {
                  _controller.complete(controller);
                  mapController = controller;

                  setState(() {
                    mapBottomPadding = (Platform.isAndroid) ? 280 : 270;
                  });

                  await Future.delayed(const Duration(milliseconds: 200));
                  SetupPositionLocator();
                },
              ),
            ),

            /// Menu Button
            Positioned(
              top: 14,
              left: 20,
              child: GestureDetector(
                onTap: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 5.0,
                        spreadRadius: 0.5,
                        offset: Offset(0.7, 0.7),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 20,
                    child: Icon(Icons.menu, color: Colors.black87),
                  ),
                ),
              ),
            ),

            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: searchSheetHeight,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(15),
                    topRight: Radius.circular(15),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 15,
                      spreadRadius: 0.5,
                      offset: Offset(0.7, 0.7),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 18,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 5),
                      Text('Nice to see you!', style: TextStyle(fontSize: 10)),
                      Text(
                        'Where are you going?',
                        style: TextStyle(
                          fontSize: 18,
                          fontFamily: 'Brand-Bold',
                        ),
                      ),
                      SizedBox(height: 20),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            // pushNamed 대신 push를 사용
                            context,
                            MaterialPageRoute(
                              builder: (context) => SearchPage(),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
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
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                Icon(Icons.search, color: Colors.blueAccent),
                                SizedBox(width: 10),
                                Text('Search Destination'),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 22),

                      Row(
                        children: [
                          Icon(OMIcons.home, color: BrandColors.colorDimText),
                          SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                Provider.of<AppData>(
                                      context,
                                    ).pickupAddress?.placeName ??
                                    'Add Home',
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Your residential address',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: BrandColors.colorDimText,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 10),

                      BrandDivider(),
                      SizedBox(height: 16),

                      Row(
                        children: [
                          Icon(
                            OMIcons.workOutline,
                            color: BrandColors.colorDimText,
                          ),
                          SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Add Work'),
                              SizedBox(height: 3),
                              Text(
                                'Your office address',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: BrandColors.colorDimText,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
