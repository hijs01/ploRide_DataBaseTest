import 'dart:io' show Platform;
import 'package:TAGO/datamodels/nearbydriver.dart';
import 'package:TAGO/globalvariable.dart';
import 'package:TAGO/helpers/firehelper.dart';
import 'package:TAGO/widgets/NoDriverDialog.dart';
import 'package:TAGO/widgets/ProgressDialog.dart';
import 'package:TAGO/widgets/TaxiButton.dart';
import 'package:flutter/material.dart';
import 'package:TAGO/dataprovider/appdata.dart';
import 'package:flutter_geofire/flutter_geofire.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:TAGO/brand_colors.dart';
import 'package:outline_material_icons/outline_material_icons.dart';
import 'package:TAGO/helpers/helpermethods.dart';
import 'package:TAGO/styles/styles.dart';
import 'package:TAGO/widgets/BrandDivider.dart';
import 'package:TAGO/screens/searchpage.dart';
import 'package:TAGO/datamodels/directiondetails.dart';
import 'package:TAGO/datamodels/address.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:TAGO/data/psu_locations.dart'; // PSU 위치 데이터 임포트

class MainPage extends StatefulWidget {
  final bool showDirections;
  final bool showPickupLocation;
  final double? pickupLatitude;
  final double? pickupLongitude;

  const MainPage({
    super.key,
    this.showDirections = false,
    this.showPickupLocation = false,
    this.pickupLatitude,
    this.pickupLongitude,
  });

  static const String id = 'mainpage';

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  double searchSheetHeight = (Platform.isIOS) ? 300 : 275;
  double rideDetailsSheetHeight = 0;
  double requestingSheetHeight = 0;
  double tripsheetHeight = 0;

  final Set<String> keysRetrieved = <String>{};
  int driverRequestTimeout = 30;
  String status = '';
  String driverCarDetails = '';
  String driverFullName = '';
  String driverPhoneNumber = '';
  String tripStatusDisplay = 'Driver is Arriving';
  bool isRequestingLocationDetails = false;
  StreamSubscription<DocumentSnapshot>? rideSubscription;

  // Firestore 레퍼런스 설정
  CollectionReference rideRef = FirebaseFirestore.instance.collection(
    'rideRequests',
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

  String appState = "NORMAL";

  bool drawerCanOpen = true;

  Directiondetails? tripDirectionDetails;

  List<NearbyDriver> availableDrivers = [];

  bool nearbyDriverKeysLoaded = false;

  // 현재 요청의 Document Reference를 저장할 변수
  DocumentReference? currentRideRef;

  // 현재 위치 변수 추가
  Position? currentPosition;

  int luggageCount = 0; // 캐리어 개수 변수 추가

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

    // 라이드 요청이 성공적으로 생성되었는지 확인
    if (currentRideRef != null) {
      setState(() {
        rideDetailsSheetHeight = 0;
        requestingSheetHeight = (Platform.isAndroid) ? 195 : 220;
        mapBottomPadding = (Platform.isAndroid) ? 200 : 190;
        drawerCanOpen = true;
      });

      availableDrivers = FireHelper.nearbyDriverList;
      findDriver();
    } else {
      print('라이드 요청 생성 실패');
      resetApp();
    }
  }

  void showTripSheet() {
    setState(() {
      requestingSheetHeight = 0;
      tripsheetHeight = (Platform.isAndroid) ? 275 : 300;
      mapBottomPadding = (Platform.isAndroid) ? 280 : 270;
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

  void SetupPositionLocator() async {
    try {
      // AppData에서 임시 위치 확인
      var appData = Provider.of<AppData>(context, listen: false);

      // 먼저 현재 기기 위치 가져오기 (기본 위치로 사용)
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );
      print('현재 위치: ${position.latitude}, ${position.longitude}');

      setState(() {
        currentPosition = position;
      });

      LatLng pos;

      // 임시 픽업 위치가 있는 경우 해당 위치를 카메라 위치로 사용
      if (appData.tempPickupAddress != null) {
        // 임시 위치의 좌표로 지도 이동
        pos = LatLng(
          appData.tempPickupAddress!.latitude ?? position.latitude,
          appData.tempPickupAddress!.longitude ?? position.longitude,
        );

        // 임시 위치의 마커 추가
        _Markers.clear();
        _Markers.add(
          Marker(
            markerId: MarkerId('tempPickup'),
            position: pos,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen,
            ),
            infoWindow: InfoWindow(
              title: appData.tempPickupAddress!.placeName ?? 'New Pickup',
              snippet:
                  appData.tempPickupAddress!.placeFormattedAddress ??
                  'Pickup location',
            ),
          ),
        );
      } else {
        // 기존 방식대로 현재 위치 사용
        pos = LatLng(position.latitude, position.longitude);
      }

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

      // 주소 변환 작업은 실제 위치 확정 시에만 수행
      if (appData.tempPickupAddress == null || appData.isPickupConfirmed) {
        // 실제 주소 변환 결과를 사용
        String address = await HelperMethods.findCordinateAddress(
          position,
          context,
        );
        print('현재 주소: $address');

        // 현재 pickup 주소 확인
        var currentPickup = appData.pickupAddress;
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

          appData.updatePickupAddress(newPickupAddress);
          print('Pickup 주소 새로 설정됨:');
          print('- placeName: ${newPickupAddress.placeName}');
          print(
            '- placeFormattedAddress: ${newPickupAddress.placeFormattedAddress}',
          );
        }
      }

      startGeofireListener();
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

      // 지도가 로드된 후 임시 위치 확인
      Future.delayed(const Duration(seconds: 2), () {
        // 임시 위치가 있으면 마커 표시
        final appData = Provider.of<AppData>(context, listen: false);
        if (appData.tempPickupAddress != null && !appData.isPickupConfirmed) {
          updatePickupMarker();
        }
      });
    });

    HelperMethods.getCurrentUserInfo();
  }

  @override
  void dispose() {
    _loadingController.dispose();
    rideSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    createMarker();
    return Scaffold(
      key: _scaffoldKey,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(60), // AppBar 높이 조정
        child: AppBar(
          backgroundColor: Colors.black,
          elevation: 1,
          automaticallyImplyLeading: false, // 뒤로 가기 버튼 제거
          title: GestureDetector(
            onTap: () {
              _showPickupLocationListModal(); // 출발지 목록 모달 표시
            },
            child: Container(
              height: 40,
              padding: EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: Colors.grey.shade800,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade600, width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on, color: Colors.white, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Consumer<AppData>(
                      builder: (context, appData, child) {
                        return Text(
                          appData.pickupAddress?.placeName ?? "출발지 선택",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                  ),
                  Icon(Icons.arrow_drop_down, color: Colors.white),
                ],
              ),
            ),
          ),
        ),
      ),
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
                            currentUserInfo?.fullName ?? 'User',
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

                  // 임시 위치가 있는지 확인 후 처리
                  final appData = Provider.of<AppData>(context, listen: false);
                  if (appData.tempPickupAddress != null &&
                      !appData.isPickupConfirmed) {
                    // 임시 위치가 있으면 해당 위치의 마커 표시
                    updatePickupMarker();
                  } else {
                    // 임시 위치가 없으면 일반적인 위치 설정
                    SetupPositionLocator();
                  }
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
                  height: requestingSheetHeight,
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
                              SizedBox(
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
                        SizedBox(
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
                duration: Duration(milliseconds: 150),
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
                                builder:
                                    (context) => SearchPage(
                                      onLuggageCountChanged: updateLuggageCount,
                                    ),
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
                              setState(() {
                                appState = "REQUESTING";
                              });

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

            //Trip sheet
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedSize(
                duration: Duration(milliseconds: 150),
                curve: Curves.easeIn,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(15),
                      topRight: Radius.circular(15),
                    ),
                  ),
                  height: tripsheetHeight,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        SizedBox(height: 5),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              tripStatusDisplay,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                fontFamily: 'Brand-Bold',
                                color: BrandColors.colorTextDark,
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 20),

                        BrandDivider(),

                        SizedBox(height: 20),

                        Text(
                          driverCarDetails,
                          style: TextStyle(color: BrandColors.colorTextLight),
                        ),

                        Text(driverFullName, style: TextStyle(fontSize: 20)),

                        SizedBox(height: 20),

                        BrandDivider(),

                        SizedBox(height: 20),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  height: 50,
                                  width: 50,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(25),
                                    border: Border.all(
                                      width: 1,
                                      color: BrandColors.colorTextLight,
                                    ),
                                  ),
                                  child: Icon(Icons.call),
                                ),
                                SizedBox(height: 10),
                                Text('Call'),
                              ],
                            ),

                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  height: 50,
                                  width: 50,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(25),
                                    border: Border.all(
                                      width: 1,
                                      color: BrandColors.colorTextLight,
                                    ),
                                  ),
                                  child: Icon(Icons.list),
                                ),
                                SizedBox(height: 10),
                                Text('Details'),
                              ],
                            ),

                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  height: 50,
                                  width: 50,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(25),
                                    border: Border.all(
                                      width: 1,
                                      color: BrandColors.colorTextLight,
                                    ),
                                  ),
                                  child: Icon(OMIcons.clear),
                                ),
                                SizedBox(height: 10),
                                Text('Cancel'),
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

            // 출발 위치 확인 버튼
            Positioned(
              bottom: 300, // 다른 UI와 겹치지 않도록 위치 조정
              left: 0,
              right: 0,
              child: Consumer<AppData>(
                builder: (context, appData, child) {
                  // 임시 출발 위치가 있고 확정되지 않았을 때만 표시
                  if (appData.tempPickupAddress != null &&
                      !appData.isPickupConfirmed) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 10.0,
                              spreadRadius: 0.5,
                              offset: Offset(0.7, 0.7),
                            ),
                          ],
                        ),
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.location_on, color: Colors.blue),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '출발 위치 확인',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        appData.tempPickupAddress?.placeName ??
                                            '',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF3F51B5),
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () {
                                  // 임시 주소를 실제 주소로 확정
                                  Provider.of<AppData>(
                                    context,
                                    listen: false,
                                  ).confirmPickupAddress();

                                  // 기존 위치 설정 함수 호출
                                  SetupPositionLocator();

                                  // 필요한 UI 상태 업데이트
                                  setState(() {
                                    searchSheetHeight =
                                        (Platform.isAndroid) ? 275 : 300;
                                    mapBottomPadding =
                                        (Platform.isAndroid) ? 280 : 270;
                                  });
                                },
                                child: Text(
                                  '출발 위치로 설정',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  } else {
                    return SizedBox.shrink(); // 임시 위치가 없거나 이미 확정된 경우 표시하지 않음
                  }
                },
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

    var pickLatLng = LatLng(pickup.latitude ?? 0.0, pickup.longitude ?? 0.0);
    var destinationLatLng = LatLng(
      destination.latitude ?? 0.0,
      destination.longitude ?? 0.0,
    );

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
        title: pickup.placeName ?? 'Pickup',
        snippet: pickup.placeFormattedAddress ?? 'No address available',
      ),
      visible: true,
    );

    final destinationMarker = Marker(
      markerId: const MarkerId('destination'),
      position: destinationLatLng,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: InfoWindow(
        title: destination.placeName ?? 'Destination',
        snippet: destination.placeFormattedAddress ?? 'No address available',
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
    void simulateMarkerTap() {
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
            title: pickup.placeName ?? 'Pickup',
            snippet: pickup.placeFormattedAddress ?? 'No address available',
          ),
          visible: true,
        );

        final updatedDestinationMarker = Marker(
          markerId: const MarkerId('destination'),
          position: destinationLatLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: destination.placeName ?? 'Destination',
            snippet:
                destination.placeFormattedAddress ?? 'No address available',
          ),
          visible: true,
        );

        _Markers.add(updatedPickupMarker);
        _Markers.add(updatedDestinationMarker);
      });
    }

    // 마커 탭 시뮬레이션 실행
    simulateMarkerTap();

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
      print('현재 위치가 null이어서 리스너를 시작할 수 없습니다.');
      return;
    }

    print(
      'Firestore 드라이버 위치 리스너 시작: 위치(${currentPosition!.latitude}, ${currentPosition!.longitude})',
    );

    // Firestore에서 드라이버 위치 실시간 업데이트 구독
    FirebaseFirestore.instance.collection('driversAvailable').snapshots().listen((
      snapshot,
    ) {
      // 기존 드라이버 목록 초기화
      FireHelper.nearbyDriverList.clear();

      for (var doc in snapshot.docs) {
        try {
          // 드라이버 위치 데이터 가져오기
          Map<String, dynamic> data = doc.data();

          // driver_id 필드 확인
          String driverId = data['driver_id'] ?? doc.id;

          // position 객체에서 위치 데이터 확인
          if (data['position'] != null) {
            Map<String, dynamic> position = data['position'];
            double? lat = double.tryParse(
              position['latitude']?.toString() ?? '',
            );
            double? lng = double.tryParse(
              position['longitude']?.toString() ?? '',
            );

            if (lat != null && lng != null) {
              // 현재 위치와의 거리 계산 (20km 이내만 표시)
              double distance = HelperMethods.calculateDistance(
                currentPosition!.latitude,
                currentPosition!.longitude,
                lat,
                lng,
              );

              print(
                '드라이버 발견: $driverId, 위치: ($lat, $lng), 거리: ${distance.toStringAsFixed(2)}km',
              );

              if (distance <= 20) {
                // 20km 이내의 드라이버만 추가
                NearbyDriver nearbyDriver = NearbyDriver(
                  key: driverId,
                  latitude: lat,
                  longitude: lng,
                );

                FireHelper.nearbyDriverList.add(nearbyDriver);
                print('드라이버 추가됨: $driverId');
              }
            }
          } else {
            print('드라이버 위치 데이터 누락: $driverId');
            print('데이터 내용: $data');
          }
        } catch (e) {
          print('드라이버 데이터 처리 중 오류: ${doc.id}, 오류: $e');
          print('원본 데이터: ${doc.data()}');
        }
      }

      print('가용 드라이버 수: ${FireHelper.nearbyDriverList.length}');
      if (FireHelper.nearbyDriverList.isNotEmpty) {
        updateDriversOnMap();
      }
    });
  }

  void updateDriversOnMap() {
    setState(() {
      _Markers.clear();
    });

    Set<Marker> tempMarkers = <Marker>{};
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
      Map<String, dynamic> pickupMap = {
        'latitude': pickup.latitude.toString(),
        'longitude': pickup.longitude.toString(),
      };

      Map<String, dynamic> destinationMap = {
        'latitude': destination.latitude.toString(),
        'longitude': destination.longitude.toString(),
      };

      Map<String, dynamic> rideMap = {
        'created_at': FieldValue.serverTimestamp(),
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
        'luggage_count': luggageCount, // 캐리어 개수 추가
        'companion_count':
            Provider.of<AppData>(
              context,
              listen: false,
            ).companionCount, // 같이 타는 친구 수 추가
      };

      print('Firestore에 전송할 데이터:');
      print(rideMap);

      // Firestore에 라이드 요청 저장
      DocumentReference newRideRef = await FirebaseFirestore.instance
          .collection('rideRequests')
          .add(rideMap);

      // 현재 요청 참조 저장
      currentRideRef = newRideRef;

      print('생성된 ride reference: ${newRideRef.id}');

      // 실시간 업데이트 리스너 설정
      rideSubscription = newRideRef.snapshots().listen((
        DocumentSnapshot snapshot,
      ) {
        if (snapshot.exists) {
          Map<String, dynamic> rideData =
              snapshot.data() as Map<String, dynamic>;

          // 차량 정보 업데이트
          if (rideData['car_details'] != null) {
            setState(() {
              driverCarDetails = rideData['car_details'].toString();
            });
          }

          // 드라이버 정보 업데이트
          if (rideData['driver_name'] != null) {
            setState(() {
              driverFullName = rideData['driver_name'].toString();
            });
          }

          // 드라이버 전화번호 업데이트
          if (rideData['driver_phone'] != null) {
            setState(() {
              driverPhoneNumber = rideData['driver_phone'].toString();
            });
          }

          // 드라이버 위치 업데이트
          if (rideData['driver_location'] != null) {
            Map<String, dynamic> location =
                rideData['driver_location'] as Map<String, dynamic>;
            double driverLat = double.parse(location['latitude'].toString());
            double driverLng = double.parse(location['longitude'].toString());
            LatLng driverLocation = LatLng(driverLat, driverLng);

            if (rideData['status'] == 'accepted') {
              updateToPickup(driverLocation);
            } else if (rideData['status'] == 'ontrip') {
              updateToDestination(driverLocation);
            } else if (rideData['status'] == 'arrived') {
              setState(() {
                tripStatusDisplay = 'Driver has arrived';
              });
            }
          }

          // 상태 업데이트
          if (rideData['status'] != null) {
            setState(() {
              status = rideData['status'].toString();
            });
          }

          // accepted 상태일 때 trip sheet 표시
          if (status == 'accepted') {
            showTripSheet();
            removeGeofireMarkers();
          }
        }
      });
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

  void removeGeofireMarkers() {
    setState(() {
      _Markers.removeWhere((m) => m.markerId.value.contains('driver'));
    });
  }

  void updateToPickup(LatLng driverLocation) async {
    if (!isRequestingLocationDetails) {
      isRequestingLocationDetails = true;

      var positionLatLng = LatLng(
        currentPosition!.latitude,
        currentPosition!.longitude,
      );

      var thisDetails = await HelperMethods.getDirectionDetails(
        driverLocation,
        positionLatLng,
      );

      if (thisDetails == null) {
        return;
      }

      setState(() {
        tripStatusDisplay = 'Driver is Arriving - ${thisDetails.durationText}';
      });

      isRequestingLocationDetails = false;
    }
  }

  void updateToDestination(LatLng driverLocation) async {
    if (!isRequestingLocationDetails) {
      isRequestingLocationDetails = true;

      var destination =
          Provider.of<AppData>(context, listen: false).destinationAddress;

      var destinationLatLng = LatLng(
        destination!.latitude ?? 0.0,
        destination.longitude ?? 0.0,
      );

      var thisDetails = await HelperMethods.getDirectionDetails(
        driverLocation,
        destinationLatLng,
      );

      if (thisDetails == null) {
        return;
      }

      setState(() {
        tripStatusDisplay =
            'Driving to Destination - ${thisDetails.durationText}';
      });

      isRequestingLocationDetails = false;
    }
  }

  void cancelRequest() {
    // Firestore에서 현재 라이드 요청 삭제
    if (currentRideRef != null) {
      currentRideRef!
          .delete()
          .then((_) {
            print('라이드 요청 삭제 성공');
          })
          .catchError((error) {
            print('라이드 요청 삭제 실패: $error');
          });

      // 현재 요청 참조 초기화
      currentRideRef = null;
    }

    setState(() {
      appState = "NORMAL";
    });
  }

  resetApp() {
    setState(() {
      polylineCoordinates.clear();
      _polylines.clear();
      _Markers.clear();
      _Circles.clear();
      rideDetailsSheetHeight = 0;
      requestingSheetHeight = 0;
      tripsheetHeight = 0;
      searchSheetHeight = (Platform.isAndroid) ? 275 : 300;
      mapBottomPadding = (Platform.isAndroid) ? 280 : 270;
      drawerCanOpen = true;

      status = '';
      driverFullName = '';
      driverPhoneNumber = '';
      driverCarDetails = '';
      tripStatusDisplay = 'Driver is Arriving';
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

    // 현재 라이드 요청 ID 확인
    if (currentRideRef == null) {
      print('라이드 요청이 아직 생성되지 않았습니다.');
      return;
    }

    // 드라이버에게 알림 전송
    notifyDriver(driver);

    // 다음 드라이버를 위해 목록에서 제거
    availableDrivers.removeAt(0);

    // 10초 후에도 응답이 없으면 다음 드라이버에게 알림
    Future.delayed(Duration(seconds: 10), () {
      // Firestore에서 드라이버 응답 확인
      if (currentRideRef != null) {
        currentRideRef!.get().then((DocumentSnapshot snapshot) {
          if (snapshot.exists) {
            Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
            if (data['status'] == 'pending' && availableDrivers.isNotEmpty) {
              print('첫 번째 드라이버가 응답하지 않았습니다. 다음 드라이버에게 알림을 보냅니다.');
              findDriver();
            }
          }
        });
      }
    });
  }

  void notifyDriver(NearbyDriver driver) {
    // 드라이버 ID 로깅
    print('알림을 보낼 드라이버 ID: ${driver.key}');

    // 드라이버 문서 참조
    DocumentReference driverDocRef = FirebaseFirestore.instance
        .collection('drivers')
        .doc(driver.key);

    // 현재 라이드 요청 ID 저장
    String? rideId = currentRideRef?.id;

    // 드라이버 문서 업데이트
    driverDocRef
        .update({
          'newtrip': rideId,
          'last_notification_time': FieldValue.serverTimestamp(),
        })
        .then((_) {
          print('드라이버 문서 업데이트 완료: newtrip = $rideId');
        })
        .catchError((error) {
          print('드라이버 문서 업데이트 실패: $error');
        });

    // 드라이버에게 직접 알림 전송
    HelperMethods.sendNotification(
      driverId: driver.key,
      context: context,
      ride_id: rideId,
    );

    // 30초 지나면 타임아웃으로 처리
    const oneSecTick = Duration(seconds: 1);

    var timer = Timer.periodic(oneSecTick, (timer) {
      // ride request 취소되면 타이머 멈추기
      if (appState != "REQUESTING") {
        driverDocRef.update({'newtrip': 'cancelled'});
        timer.cancel();
        driverRequestTimeout = 30;
      }

      driverRequestTimeout--;

      // 드라이버 응답 확인을 위한 리스너 설정
      if (currentRideRef != null) {
        currentRideRef!.snapshots().listen((DocumentSnapshot snapshot) {
          if (snapshot.exists) {
            Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
            // 드라이버가 수락한 경우
            if (data['status'] == 'accepted') {
              timer.cancel();
              driverRequestTimeout = 30;
            }
          }
        });
      }

      if (driverRequestTimeout == 0) {
        // 드라이버에게 타임아웃 알려주기
        driverDocRef.update({'newtrip': 'timeout'});
        driverRequestTimeout = 30;
        timer.cancel();

        // 다음 가장 가까운 드라이버 선택
        findDriver();
      }
    });

    // 테스트용: 모든 가능한 경로에 알림 데이터 저장
    testAllNotificationPaths(driver.key, rideId);
  }

  // 테스트용: 모든 가능한 경로에 알림 데이터 저장
  void testAllNotificationPaths(String driverId, String? rideId) async {
    if (rideId == null) return;

    try {
      print('===== 테스트: 모든 가능한 경로에 알림 데이터 저장 =====');

      // 기본 알림 데이터
      var notificationData = {
        'ride_id': rideId,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'new',
        'pickup_address': '테스트 출발지',
        'destination_address': '테스트 목적지',
        'read': false,
      };

      // 1. drivers/{driverId} 문서 업데이트
      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(driverId)
          .update({
            'newtrip': rideId,
            'last_updated': FieldValue.serverTimestamp(),
          });
      print('1. drivers/$driverId 문서 업데이트 완료');

      // 2. drivers/{driverId}/notifications 컬렉션에 알림 추가
      DocumentReference notificationRef = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(driverId)
          .collection('notifications')
          .add(notificationData);
      print(
        '2. drivers/$driverId/notifications 컬렉션에 알림 추가 완료: ${notificationRef.id}',
      );

      // 3. drivers/{driverId} 문서에 알림 표시 업데이트
      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(driverId)
          .update({
            'has_new_notification': true,
            'last_notification': notificationData,
          });
      print('3. drivers/$driverId 문서에 알림 표시 업데이트 완료');

      // 4. 알림 테스트용 HTTP 엔드포인트 호출
      String url =
          'https://us-central1-geetaxi-aa379.cloudfunctions.net/sendPushToDriver';
      Map<String, dynamic> requestData = {
        'driverId': driverId,
        'rideId': rideId,
        'pickup_address': '테스트 출발지',
        'destination_address': '테스트 목적지',
      };

      var response = await http.post(
        Uri.parse(url),
        body: jsonEncode(requestData),
        headers: {'Content-Type': 'application/json'},
      );

      print('4. HTTP 요청 결과: ${response.statusCode}');
      print('응답: ${response.body}');

      print('===== 테스트 완료: 모든 가능한 경로에 알림 데이터 저장됨 =====');
    } catch (e) {
      print('테스트 중 오류 발생: $e');
    }
  }

  // 임시 픽업 마커 업데이트 메서드
  void updatePickupMarker() {
    var appData = Provider.of<AppData>(context, listen: false);

    // 임시 픽업 주소가 있으면 해당 위치를 마커로 표시
    if (appData.tempPickupAddress != null) {
      double lat = appData.tempPickupAddress!.latitude ?? 0.0;
      double lng = appData.tempPickupAddress!.longitude ?? 0.0;

      if (lat != 0.0 && lng != 0.0) {
        LatLng pos = LatLng(lat, lng);

        // 마커 추가
        _Markers.clear();
        final marker = Marker(
          markerId: MarkerId('tempPickup'),
          position: pos,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: InfoWindow(
            title: appData.tempPickupAddress!.placeName ?? 'New Pickup',
            snippet:
                appData.tempPickupAddress!.placeFormattedAddress ??
                'Pickup location',
          ),
        );

        setState(() {
          _Markers.add(marker);
        });

        // 카메라 이동
        mapController.animateCamera(CameraUpdate.newLatLngZoom(pos, 14));
      }
    }
  }

  // 출발지 위치 목록을 표시하는 모달 함수
  void _showPickupLocationListModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          color: Colors.black,
          child: Column(
            children: [
              // 상단 헤더
              Container(
                padding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Text(
                      "출발지 선택",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                thickness: 1.5,
                color: Colors.white.withOpacity(0.6),
              ),
              // 출발지 목록
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  itemCount: PsuLocationsData.locations.length,
                  itemBuilder: (context, index) {
                    final location = PsuLocationsData.locations[index];
                    return _buildLocationItem(
                      location.name,
                      location.address,
                      location.latitude,
                      location.longitude,
                    );
                  },
                  separatorBuilder: (context, index) {
                    return Divider(
                      height: 1,
                      thickness: 1.0,
                      color: Colors.white.withOpacity(0.3),
                      indent: 20, // 왼쪽 여백 20px
                      endIndent: 20, // 오른쪽 여백 20px
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 위치 항목 위젯
  Widget _buildLocationItem(
    String name,
    String address,
    double latitude,
    double longitude,
  ) {
    return ListTile(
      leading: Icon(Icons.location_on, color: Colors.white),
      title: Text(
        name,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(address, style: TextStyle(color: Colors.grey.shade400)),
      tileColor: Colors.transparent,
      onTap: () {
        // 위치 선택 시 처리
        _updatePickupLocation(name, address, latitude, longitude);
        Navigator.pop(context); // 모달 닫기
      },
    );
  }

  // 선택한 위치로 업데이트
  void _updatePickupLocation(
    String name,
    String address,
    double latitude,
    double longitude,
  ) {
    // Address 객체 생성
    var pickupAddress = Address(
      placeName: name,
      placeFormattedAddress: address,
      latitude: latitude,
      longitude: longitude,
      placeId: 'psu_${name.hashCode}', // 임의의 플레이스 ID 생성
    );

    // 임시 픽업 주소로 저장
    Provider.of<AppData>(
      context,
      listen: false,
    ).updateTempPickupAddress(pickupAddress);

    // 지도 이동 및 마커 생성
    LatLng pickupLatLng = LatLng(latitude, longitude);

    // 기존 마커 지우기
    _Markers.clear();
    _Circles.clear();

    // 마커 생성
    final pickupMarker = Marker(
      markerId: const MarkerId('tempPickup'),
      position: pickupLatLng,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      infoWindow: InfoWindow(title: name, snippet: "출발 위치"),
      visible: true,
      zIndex: 3,
    );

    // 원 생성
    Circle pickupCircle = Circle(
      circleId: const CircleId('tempPickup'),
      strokeColor: Colors.white,
      strokeWidth: 3,
      radius: 30,
      center: pickupLatLng,
      fillColor: Colors.white.withOpacity(0.3),
    );

    setState(() {
      _Markers.add(pickupMarker);
      _Circles.add(pickupCircle);
    });

    // 지도 이동
    mapController.animateCamera(CameraUpdate.newLatLngZoom(pickupLatLng, 15));

    // 마커 정보창 표시
    Future.delayed(Duration(milliseconds: 300), () {
      mapController.showMarkerInfoWindow(MarkerId('tempPickup'));
    });
  }

  void updateLuggageCount(int count) {
    setState(() {
      luggageCount = count;
    });
  }
}
