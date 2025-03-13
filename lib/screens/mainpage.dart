import 'package:cabrider/datamodels/nearbydriver.dart';
import 'package:cabrider/globalvariable.dart';
import 'package:cabrider/helpers/firehelper.dart';
import 'package:cabrider/widgets/NoDriverDialog.dart';
import 'package:cabrider/widgets/ProgressDialog.dart';
import 'package:cabrider/widgets/TaxiButton.dart';
import 'package:flutter/material.dart';
import 'package:cabrider/dataprovider/appdata.dart';
import 'package:flutter_geofire/flutter_geofire.dart';
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
import 'package:animated_text_kit/animated_text_kit.dart';

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
  final Set<String> keysRetrieved = <String>{};

  DatabaseReference rideRef = FirebaseDatabase.instance.ref().child(
    'rideRequest',
  );

  // 로딩 애니메이션을 위한 컨트롤러 추가
  late AnimationController _loadingController;
  late Animation<double> _animation;

  final Completer<GoogleMapController> _controller = Completer();
  late GoogleMapController mapController;
  final bool _mapLoaded = false;

  double mapBottomPadding = 0;

  final List<LatLng> polylineCoordinates = [];
  final Set<Polyline> _polylines = {};
  final Set<Marker> _Markers = {};
  final Set<Circle> _Circles = {};

  late BitmapDescriptor nearbyIcon;

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

  void showRequestingSheet() async {
    await createRideRequest();

    setState(() {
      rideDetailsSheetHeight = 0;
      requestingSheetHeight = (Platform.isAndroid) ? 195 : 220;
      mapBottomPadding = (Platform.isAndroid) ? 200 : 190;
      drawerCanOpen = true;
    });
  }

  void createMarker() {
    ImageConfiguration imageConfiguration = createLocalImageConfiguration(
      context,
      size: Size(2, 2),
    );
    BitmapDescriptor.fromAssetImage(
      imageConfiguration,
      (Platform.isIOS) ? 'images/car_ios.png' : 'images/car_android.png',
    ).then((icon) {
      nearbyIcon = icon;
    });
  }

  // 현재 위치 변수 추가
  Position? currentPosition;

  Directiondetails? tripDirectionDetails;

  List<NearbyDriver> availableDrivers = [];

  bool nearbyDriverKeysLoaded = false;

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

      startGeofireListener();

      // 현재 pickup 주소 확인
      var currentPickup =
          Provider.of<AppData>(context, listen: false).pickupAddress;
      print(
        '현재 pickup 주소 상태: ${currentPickup?.placeFormattedAddress ?? "null"}',
      );

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
    // 로딩 애니메이션 컨트롤러 초기화
    _loadingController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    );

    // 애니메이션 설정
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _loadingController, curve: Curves.easeInOutSine),
    );

    // 애니메이션 반복 설정
    _loadingController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _loadingController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _loadingController.forward();
      }
    });

    _loadingController.forward();

    // 앱 시작 시 약간의 지연 후 위치 권한 확인
    Future.delayed(const Duration(seconds: 1), () {
      _checkLocationPermission();
    });
    HelperMethods.getCurrentUserInfo();
  }

  @override
  void dispose() {
    _loadingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    createMarker();
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

            //Requesting Sheet
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedSize(
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
                      ),
                    ],
                  ),
                  height: 250,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        SizedBox(height: 10),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 0,
                            vertical: 5,
                          ),
                          width: double.infinity,
                          child: Column(
                            children: [
                              Container(
                                width: 250,
                                child: Column(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.grey.withOpacity(0.2),
                                            blurRadius: 2,
                                            offset: Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: LinearProgressIndicator(
                                          backgroundColor: Colors.grey[200],
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.blue,
                                              ),
                                          minHeight: 6,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 15),
                              Text(
                                'Requesting a Ride...',
                                style: TextStyle(
                                  fontSize: 22.0,
                                  fontFamily: 'Brand-Bold',
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 50),

                        GestureDetector(
                          onTap: () {
                            cancelRequest();
                            resetApp();
                          },
                          child: Container(
                            height: 50,
                            width: 50,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(
                                width: 1.0,
                                color: BrandColors.colorLightGrayFair,
                              ),
                            ),
                            child: Icon(Icons.close, size: 25),
                          ),
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
                ),
              ),
            ),

            //Search Sheet
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
                                  // Provider.of<AppData>(
                                  //       context,
                                  //     ).pickupAddress?.placeFormattedAddress ??
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

            //Ride Details Sheet
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
                            onPressed: () {
                              showRequestingSheet();

                              availableDrivers = FireHelper.nearbyDriverList;

                              findDriver();
                            },
                          ),
                        ),
                      ],
                    ),
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

  void startGeofireListener() {
    if (currentPosition == null) {
      print('현재 위치가 null이어서 Geofire 리스너를 시작할 수 없습니다.');
      return;
    }

    print(
      'Geofire 리스너 시작: 위치(${currentPosition!.latitude}, ${currentPosition!.longitude}), 반경 20km',
    );
    Geofire.initialize('driversAvailable');

    Geofire.queryAtLocation(
      currentPosition!.latitude,
      currentPosition!.longitude,
      20,
    )?.listen((map) {
      if (map != null) {
        var callBack = map['callBack'];
        var key = map['key'];
        var lat = map['latitude'];
        var lng = map['longitude'];

        print('Geofire 이벤트: $callBack, 드라이버: $key, 위치: $lat, $lng');

        switch (callBack) {
          case Geofire.onKeyEntered:
            print('새 드라이버 발견: $key, 위치: $lat, $lng');
            NearbyDriver nearbyDriver = NearbyDriver(
              key: key,
              latitude: lat,
              longitude: lng,
            );

            FireHelper.nearbyDriverList.add(nearbyDriver);
            print('현재 가용 드라이버 수: ${FireHelper.nearbyDriverList.length}');

            if (nearbyDriverKeysLoaded) {
              updateDriversOnMap();
            }
            break;

          case Geofire.onKeyExited:
            print('드라이버 이탈: $key');
            FireHelper.removeFromList(key);
            updateDriversOnMap();
            break;

          case Geofire.onKeyMoved:
            print('드라이버 이동: $key, 새 위치: $lat, $lng');
            // 드라이버 위치 업데이트 로직 수정
            int index = FireHelper.nearbyDriverList.indexWhere(
              (driver) => driver.key == key,
            );
            if (index >= 0) {
              FireHelper.nearbyDriverList[index].latitude = lat;
              FireHelper.nearbyDriverList[index].longitude = lng;
            } else {
              print('경고: 이동한 드라이버 $key를 목록에서 찾을 수 없습니다.');
              FireHelper.nearbyDriverList.add(
                NearbyDriver(key: key, latitude: lat, longitude: lng),
              );
            }
            updateDriversOnMap();
            break;

          case Geofire.onGeoQueryReady:
            print(
              'Geofire 초기 데이터 로드 완료. 가용 드라이버 수: ${FireHelper.nearbyDriverList.length}',
            );
            nearbyDriverKeysLoaded = true;
            updateDriversOnMap();
            break;
        }
      }
    });
  }

  void updateDriversOnMap() {
    setState(() {
      _Markers.clear();
    });

    Set<Marker> tempMarkers = Set<Marker>();
    for (NearbyDriver driver in FireHelper.nearbyDriverList) {
      LatLng driverPosition = LatLng(driver.latitude, driver.longitude);
      Marker thisMarker = Marker(
        markerId: MarkerId('driver${driver.key}'),
        position: driverPosition,
        icon: nearbyIcon ?? BitmapDescriptor.defaultMarker,
        rotation: HelperMethods.generateRandomNumber(360),
      );
      tempMarkers.add(thisMarker);

      setState(() {
        _Markers.clear();
        _Markers.addAll(tempMarkers);
      });
    }
  }

  Future<void> createRideRequest() async {
    if (currentFirebaseUser == null) {
      print('로그인 상태 확인: currentFirebaseUser is null');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('로그인이 필요합니다.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    print('로그인 상태 확인: currentFirebaseUser.uid = ${currentFirebaseUser!.uid}');

    var pickup = Provider.of<AppData>(context, listen: false).pickupAddress;
    var destination =
        Provider.of<AppData>(context, listen: false).destinationAddress;

    print('pickup 주소: ${pickup?.placeName}');
    print('destination 주소: ${destination?.placeName}');

    if (pickup == null || destination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('출발지와 목적지를 모두 선택해주세요.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (currentUserInfo == null) {
      print('사용자 정보 확인: currentUserInfo is null');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('사용자 정보를 찾을 수 없습니다.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    print('사용자 정보 확인:');
    print('- 이름: ${currentUserInfo!.fullName}');
    print('- 전화번호: ${currentUserInfo!.phone}');

    if (tripDirectionDetails == null) {
      print('경로 정보 확인: tripDirectionDetails is null');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('경로 정보를 찾을 수 없습니다.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      Map pickupMap = {
        'latitude': pickup.latitude.toString(),
        'longitude': pickup.longitude.toString(),
      };

      Map destinationMap = {
        'latitude': destination.latitude.toString(),
        'longitude': destination.longitude.toString(),
      };

      Map rideMap = {
        'created_at': DateTime.now().toString(),
        'rider_name': currentUserInfo!.fullName,
        'rider_phone': currentUserInfo!.phone,
        'pickup_address': pickup.placeName,
        'destination_address': destination.placeName,
        'location': pickupMap,
        'destination': destinationMap,
        'payment_method': 'card',
        'driver_id': 'waiting',
        'status': 'pending',
        'user_id': currentFirebaseUser!.uid,
        'fare': HelperMethods.estimateFares(tripDirectionDetails!),
      };

      print('Firebase에 전송할 데이터:');
      print(rideMap);

      var newRideRef = await rideRef.push();
      print('생성된 ride reference: ${newRideRef.key}');
      await newRideRef.set(rideMap);
      print('Firebase에 데이터 전송 완료');
    } catch (e) {
      print('요청 생성 중 오류 발생: $e');
      print('Stack trace: ${StackTrace.current}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('요청 전송 중 오류가 발생했습니다. 다시 시도해주세요.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void cancelRequest() {
    rideRef.remove();
  }

  resetApp() {
    setState(() {
      polylineCoordinates.clear();
      _polylines.clear();
      _Markers.clear();
      _Circles.clear();
      rideDetailsSheetHeight = 0;
      requestingSheetHeight = 0;
      searchSheetHeight = (Platform.isAndroid) ? 275 : 300;
      mapBottomPadding = (Platform.isAndroid) ? 280 : 270;
      drawerCanOpen = true;
    });

    SetupPositionLocator();
  }

  void noDriverFound() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => const NoDriverDialog(),
    );
  }

  void findDriver() {
    if (availableDrivers.isEmpty) {
      print('사용 가능한 드라이버가 없습니다.');
      cancelRequest();
      resetApp();
      noDriverFound();
      return;
    }

    print('사용 가능한 드라이버 수: ${availableDrivers.length}');
    print('사용 가능한 드라이버 목록:');
    for (var driver in availableDrivers) {
      print(
        '- 드라이버 ID: ${driver.key}, 위치: ${driver.latitude}, ${driver.longitude}',
      );
    }

    var driver = availableDrivers[0];
    print('선택된 드라이버: ${driver.key}');

    // 드라이버에게 알림 전송
    notifyDriver(driver);

    // 다음 드라이버를 위해 목록에서 제거
    availableDrivers.removeAt(0);

    // 10초 후에도 응답이 없으면 다음 드라이버에게 알림
    Future.delayed(Duration(seconds: 10), () {
      // 드라이버 응답 확인
      DatabaseReference driverResponseRef = FirebaseDatabase.instance
          .ref()
          .child('rideRequest/${rideRef.key}/status');

      driverResponseRef.once().then((DatabaseEvent event) {
        if (event.snapshot.value == 'pending' && availableDrivers.isNotEmpty) {
          print('첫 번째 드라이버가 응답하지 않았습니다. 다음 드라이버에게 알림을 보냅니다.');
          findDriver();
        }
      });
    });
  }

  void notifyDriver(NearbyDriver driver) {
    // 드라이버 ID 로깅
    print('알림을 보낼 드라이버 ID: ${driver.key}');

    // 드라이버에게 직접 알림 전송
    HelperMethods.sendNotification(driver.key, context, rideRef.key);

    // 테스트용: 모든 가능한 경로에 알림 데이터 저장
    testAllNotificationPaths(driver.key, rideRef.key);
  }

  // 테스트용: 모든 가능한 경로에 알림 데이터 저장
  void testAllNotificationPaths(String driverId, String? rideId) async {
    if (rideId == null) return;

    try {
      print('===== 테스트: 모든 가능한 경로에 알림 데이터 저장 =====');

      // 1. drivers/{driverId}/newtrip 경로
      await FirebaseDatabase.instance
          .ref()
          .child('drivers/$driverId/newtrip')
          .set(rideId);
      print('1. drivers/$driverId/newtrip 경로에 저장 완료');

      // 2. drivers/{driverId}/newRequest 경로
      await FirebaseDatabase.instance
          .ref()
          .child('drivers/$driverId/newRequest')
          .set(rideId);
      print('2. drivers/$driverId/newRequest 경로에 저장 완료');

      // 3. driver_notifications/{driverId} 경로
      var notificationData = {
        'ride_id': rideId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'status': 'new',
      };
      await FirebaseDatabase.instance
          .ref()
          .child('driver_notifications/$driverId')
          .push()
          .set(notificationData);
      print('3. driver_notifications/$driverId 경로에 저장 완료');

      // 4. driversAvailable/{driverId}/notifications 경로
      await FirebaseDatabase.instance
          .ref()
          .child('driversAvailable/$driverId/notifications')
          .set(rideId);
      print('4. driversAvailable/$driverId/notifications 경로에 저장 완료');

      // 5. notifications/{driverId} 경로
      await FirebaseDatabase.instance
          .ref()
          .child('notifications/$driverId')
          .push()
          .set(notificationData);
      print('5. notifications/$driverId 경로에 저장 완료');

      print('===== 테스트 완료: 모든 가능한 경로에 알림 데이터 저장됨 =====');
    } catch (e) {
      print('테스트 중 오류 발생: $e');
    }
  }
}
