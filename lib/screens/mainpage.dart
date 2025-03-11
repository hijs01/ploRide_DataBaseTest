import 'package:cabrider/globalvariable.dart';
import 'package:cabrider/widgets/ProgressDialog.dart';
import 'package:cabrider/widgets/TaxiButton.dart';
import 'package:flutter/material.dart';
import 'package:cabrider/dataprovider/appdata.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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
import 'package:cabrider/datamodels/directiondetails.dart';
import 'package:cabrider/datamodels/address.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});
  static const String id = 'mainpage';

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  double searchSheetHeight = (Platform.isIOS) ? 300 : 275;
  double rideDetailsSheetHeight = 0;
  double requestingSheetHeight = 0;
  


  final Completer<GoogleMapController> _controller = Completer();
  late GoogleMapController mapController;
  final bool _mapLoaded = false;

  double mapBottomPadding = 0;

  final List<LatLng> polylineCoordinates = [];
  final Set<Polyline> _polylines = {};
  final Set<Marker> _Markers = {};
  final Set<Circle> _Circles = {};

  bool drawerCanOpen = true;

  void showDetailSheet() async {
    await getDirection();

    setState(() {
      searchSheetHeight = 0;
      rideDetailsSheetHeight = (Platform.isAndroid) ? 235 : 260;
      mapBottomPadding = (Platform.isAndroid) ? 240 : 230;
      drawerCanOpen = false;
    });
  }

  // 현재 위치 변수 추가
  Position? currentPosition;

  Directiondetails? tripDirectionDetails;
  void SetupPositionLocator() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );
      print('현재 위치: ${position.latitude}, ${position.longitude}');

      setState(() {
        currentPosition = position;
      });

      LatLng pos = LatLng(position.latitude, position.longitude);
      CameraPosition cp = CameraPosition(target: pos, zoom: 14);

      try {
        await mapController.animateCamera(CameraUpdate.newCameraPosition(cp));
        print('지도 이동 성공: ${pos.latitude}, ${pos.longitude}');

        final cameraPosition = await mapController.getLatLng(
          ScreenCoordinate(x: 0, y: 0),
        );
        print(
          '현재 카메라 위치: ${cameraPosition.latitude}, ${cameraPosition.longitude}',
        );
      } catch (e) {
        print('지도 이동 실패: $e');
      }

      // 실제 주소 변환 결과를 사용
      String address = await HelperMethods.findCordinateAddress(
        position,
        context,
      );
      print('현재 주소: $address');

      // 현재 pickup 주소 확인
      var currentPickup =
          Provider.of<AppData>(context, listen: false).pickupAddress;
      print('현재 pickup 주소 상태: ${currentPickup?.placeName ?? "null"}');

      if (currentPickup == null) {
        // pickup 주소가 없으면 현재 위치로 설정
        var newPickupAddress = Address(
          placeName: address,
          latitude: position.latitude,
          longitude: position.longitude,
          placeId: '', // 여기서는 빈 값으로 설정
          placeFormattedAddress: address,
        );

        Provider.of<AppData>(
          context,
          listen: false,
        ).updatePickupAddress(newPickupAddress);
        print('Pickup 주소 새로 설정됨:');
        print('- placeName: ${newPickupAddress.placeName}');
        print(
          '- placeFormattedAddress: ${newPickupAddress.placeFormattedAddress}',
        );
      }
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
                initialCameraPosition: googlePlex,
                compassEnabled: true,
                tiltGesturesEnabled: true,
                rotateGesturesEnabled: true,
                trafficEnabled: false,
                polylines: _polylines,
                markers: _Markers,
                circles: _Circles,
                onMapCreated: (GoogleMapController controller) async {
                  _controller.complete(controller);
                  mapController = controller;

                  setState(() {
                    mapBottomPadding = (Platform.isAndroid) ? 280 : 270;
                  });

                  await Future.delayed(const Duration(milliseconds: 200));
                  SetupPositionLocator();
                },
                onTap: (_) {
                  // 지도를 탭했을 때 InfoWindow가 닫히지 않도록
                },
              ),
            ),

            /// Menu Button
            Positioned(
              top: 14,
              left: 20,
              child: GestureDetector(
                onTap: () {
                  if (drawerCanOpen) {
                    _scaffoldKey.currentState?.openDrawer();
                  } else {
                    resetApp();
                  }
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
                    child: Icon(
                      (drawerCanOpen) ? Icons.menu : Icons.arrow_back,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
            ),

            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedSize(
                duration: new Duration(milliseconds: 150),
                curve: Curves.easeIn,
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
                        Text(
                          'Nice to see you!',
                          style: TextStyle(fontSize: 10),
                        ),
                        Text(
                          'Where are you going?',
                          style: TextStyle(
                            fontSize: 18,
                            fontFamily: 'Brand-Bold',
                          ),
                        ),
                        SizedBox(height: 20),
                        GestureDetector(
                          onTap: () async {
                            var response = await Navigator.push(
                              // pushNamed 대신 push를 사용
                              context,
                              MaterialPageRoute(
                                builder: (context) => SearchPage(),
                              ),
                            );
                            if (response == 'getDirection') {
                              showDetailSheet();
                            }
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
            ),

            Positioned(
              left: 0,
              right: 0,
              bottom: -1,
              child: AnimatedSize(
                duration: new Duration(milliseconds: 150),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(15),
                      topRight: Radius.circular(15),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 15.0,
                        spreadRadius: 0.5,
                        offset: Offset(0.7, 0.7),
                      ),
                    ],
                  ),
                  height: rideDetailsSheetHeight,
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Column(
                      children: <Widget>[
                        Container(
                          width: double.infinity,
                          color: BrandColors.colorAccent1,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: <Widget>[
                                Image.asset(
                                  'images/taxi.png',
                                  height: 70,
                                  width: 70,
                                ),
                                SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      'Taxi',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontFamily: 'Brand-Bold',
                                      ),
                                    ),
                                    Text(
                                      (tripDirectionDetails != null)
                                          ? tripDirectionDetails!.distanceText
                                          : '',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: BrandColors.colorTextLight,
                                      ),
                                    ),
                                  ],
                                ),
                                Expanded(child: Container()),
                                Text(
                                  (tripDirectionDetails != null)
                                      ? '\$${HelperMethods.estimateFares(tripDirectionDetails!)}'
                                      : '',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontFamily: 'Brand-Bold',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        SizedBox(height: 22),

                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Icon(
                                FontAwesomeIcons.moneyBillAlt,
                                size: 18,
                                color: BrandColors.colorTextLight,
                              ),
                              SizedBox(width: 16),
                              Text('Cash'),
                              SizedBox(width: 5),
                              Icon(
                                Icons.keyboard_arrow_down,
                                size: 16,
                                color: BrandColors.colorTextLight,
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 22),

                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: TaxiButton(
                            text: 'REQUEST CAB',
                            color: BrandColors.colorGreen,
                            onPressed: () {},
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            Positioned(
              left: 0,
              right: 0,
              child: AnimatedSize(
                curve: Curves.easeIn,
                duration: Duration(milliseconds: 150),
                child: Container(
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
                      )
                    ],
                  ),
                  height: 250,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                        child: Column(
                          children: [
                            SizedBox(height: 20),
                            Container(
                              height: 50,
                              width: 50,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(width: 1.0, color: BrandColors.colorLightGrayFair),
                              ),
                              child: Icon(Icons.close, size: 25),
                            ),
                            SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              child: Text(
                                'Cancel ride',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
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

  Future<void> getDirection() async {
    var pickup = Provider.of<AppData>(context, listen: false).pickupAddress;
    var destination =
        Provider.of<AppData>(context, listen: false).destinationAddress;

    print('Pickup: ${pickup?.placeName}');
    print('Destination: ${destination?.placeName}');

    if (pickup == null || destination == null) {
      print('Pickup or destination is null');
      return;
    }

    var pickLatLng = LatLng(pickup.latitude, pickup.longitude);
    var destinationLatLng = LatLng(destination.latitude, destination.longitude);

    showDialog(
      barrierDismissible: false,
      context: context,
      builder:
          (BuildContext context) =>
              const ProgressDialog(status: "Please wait..."),
    );

    var thisDetails = await HelperMethods.getDirectionDetails(
      pickLatLng,
      destinationLatLng,
    );

    setState(() {
      tripDirectionDetails = thisDetails;
    });

    Navigator.pop(context);

    if (thisDetails == null || thisDetails.encodedPoints.isEmpty) {
      print('No direction details or empty encoded points');
      return;
    }

    print('Encoded Points: ${thisDetails.encodedPoints}');

    polylineCoordinates.clear();

    PolylinePoints polylinePoints = PolylinePoints();
    List<PointLatLng> results = polylinePoints.decodePolyline(
      thisDetails.encodedPoints,
    );

    print('Decoded points count: ${results.length}');

    if (results.isNotEmpty) {
      for (var point in results) {
        polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      }
    }

    _polylines.clear();

    setState(() {
      Polyline polyline = Polyline(
        polylineId: const PolylineId('polyid'),
        color: const Color.fromARGB(255, 95, 109, 237),
        points: polylineCoordinates,
        jointType: JointType.round,
        width: 4,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        geodesic: true,
      );
      _polylines.add(polyline);
      print(
        'Polyline added to set. Points count: ${polylineCoordinates.length}',
      );
    });

    try {
      // Fit the polyline into the map view
      LatLngBounds bounds;
      if (pickLatLng.latitude > destinationLatLng.latitude &&
          pickLatLng.longitude > destinationLatLng.longitude) {
        bounds = LatLngBounds(
          southwest: destinationLatLng,
          northeast: pickLatLng,
        );
      } else if (pickLatLng.longitude > destinationLatLng.longitude) {
        bounds = LatLngBounds(
          southwest: LatLng(pickLatLng.latitude, destinationLatLng.longitude),
          northeast: LatLng(destinationLatLng.latitude, pickLatLng.longitude),
        );
      } else if (pickLatLng.latitude > destinationLatLng.latitude) {
        bounds = LatLngBounds(
          southwest: LatLng(destinationLatLng.latitude, pickLatLng.longitude),
          northeast: LatLng(pickLatLng.latitude, destinationLatLng.longitude),
        );
      } else {
        bounds = LatLngBounds(
          southwest: pickLatLng,
          northeast: destinationLatLng,
        );
      }

      await mapController.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 70),
      );
      print('Camera animated to show route');
    } catch (e) {
      print('Error animating camera: $e');
    }

    // Clear existing markers first
    _Markers.clear();
    _Circles.clear();

    // Create markers with InfoWindow
    final pickupMarker = Marker(
      markerId: const MarkerId('pickup'),
      position: pickLatLng,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      infoWindow: InfoWindow(
        title: pickup.placeName,
        snippet: pickup.placeFormattedAddress,
      ),
      visible: true,
    );

    final destinationMarker = Marker(
      markerId: const MarkerId('destination'),
      position: destinationLatLng,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: InfoWindow(
        title: destination.placeName,
        snippet: destination.placeFormattedAddress,
      ),
      visible: true,
    );

    // Add markers
    setState(() {
      _Markers.add(pickupMarker);
      _Markers.add(destinationMarker);
    });

    // 마커 정보창 표시를 위한 지연
    await Future.delayed(const Duration(milliseconds: 300));

    // 마커 탭 시뮬레이션을 위한 함수
    void _simulateMarkerTap() {
      setState(() {
        // 마커를 다시 생성하여 InfoWindow가 표시되도록 함
        _Markers.clear();

        final updatedPickupMarker = Marker(
          markerId: const MarkerId('pickup'),
          position: pickLatLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: InfoWindow(
            title: pickup.placeName,
            snippet: pickup.placeFormattedAddress,
          ),
          visible: true,
        );

        final updatedDestinationMarker = Marker(
          markerId: const MarkerId('destination'),
          position: destinationLatLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: destination.placeName,
            snippet: destination.placeFormattedAddress,
          ),
          visible: true,
        );

        _Markers.add(updatedPickupMarker);
        _Markers.add(updatedDestinationMarker);
      });
    }

    // 마커 탭 시뮬레이션 실행
    _simulateMarkerTap();

    // Add circles
    Circle pickupCircle = Circle(
      circleId: const CircleId('pickup'),
      strokeColor: Colors.green,
      strokeWidth: 3,
      radius: 12,
      center: pickLatLng,
      fillColor: BrandColors.colorGreen,
    );

    Circle destinationCircle = Circle(
      circleId: const CircleId('destination'),
      strokeColor: BrandColors.colorAccentPurple,
      strokeWidth: 3,
      radius: 12,
      center: destinationLatLng,
      fillColor: BrandColors.colorAccentPurple,
    );

    setState(() {
      _Circles.add(pickupCircle);
      _Circles.add(destinationCircle);
    });
  }

  resetApp() {
    setState(() {
      polylineCoordinates.clear();
      _polylines.clear();
      _Markers.clear();
      _Circles.clear();
      rideDetailsSheetHeight = 0;
      searchSheetHeight = (Platform.isAndroid) ? 275 : 300;
      mapBottomPadding = (Platform.isAndroid) ? 280 : 270;
      drawerCanOpen = true;
    });

    SetupPositionLocator();
  }
}
