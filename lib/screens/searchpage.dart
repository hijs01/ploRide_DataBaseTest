// 섹션7 31강 코드

import 'package:TAGO/brand_colors.dart';
import 'package:TAGO/dataprovider/appdata.dart';
import 'package:TAGO/globalvariable.dart'; // globalvariable 강의에선 이거 임포트 돼있길래 일단 써놨음
import 'package:TAGO/helpers/requesthelper.dart';
import 'package:TAGO/widgets/PredictionTile.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; //provider 임포트인데 그전 강의에서 설치하는듯? 그전 강의에 없는거면 임포트 주소 바꾸기
import 'package:TAGO/datamodels/prediction.dart';
import 'package:TAGO/widgets/BrandDivider.dart';
import 'package:TAGO/datamodels/address.dart';
import 'package:geolocator/geolocator.dart';
import 'package:TAGO/widgets/psu_locations_list.dart';
import 'package:TAGO/data/airport_locations_list.dart';
import 'package:TAGO/screens/homepage.dart';
import 'package:TAGO/screens/location_map_page.dart'; // 지도 페이지 임포트
import 'package:easy_localization/easy_localization.dart';

// 커스텀 Route 클래스 정의
class LeftToRightPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  LeftToRightPageRoute({required this.page})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(-1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;

          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: Duration(milliseconds: 300),
      );
}

class SearchPage extends StatefulWidget {
  static const String id = 'search';
  final Function(int)? onLuggageCountChanged;

  const SearchPage({super.key, this.onLuggageCountChanged});

  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  var pickupController = TextEditingController();
  var destinationController = TextEditingController();
  var dateController = TextEditingController(); // 날짜 입력 컨트롤러
  var timeController = TextEditingController(); // 시간 입력 컨트롤러

  var focusDestination = FocusNode();

  bool focused = false;
  int luggageCount = 1; // 캐리어 개수 기본값
  int companionCount = 0; // 같이 타는 친구 수 기본값

  var destinationPredictionList = <Prediction>[];

  // 변수 추가
  bool showPsuLocations = false;
  bool showAirportLocations = false; // 공항 위치 목록 표시 여부
  DateTime? selectedDate; // 선택된 날짜
  TimeOfDay? selectedTime; // 선택된 시간

  // 출발 위치 타입을 저장하는 변수 추가
  String pickupLocationType = ''; // 'psu' 또는 'airport'

  bool isGroupRide = false; // 추가된 변수

  @override
  void initState() {
    super.initState();
  }

  Future<void> getCurrentLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    String address = "Lat: ${position.latitude}, Long: ${position.longitude}";
    setState(() {
      pickupController.text = address;
    });
  }

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

  // MainPage로 이동하는 함수 추가
  void navigateToMainPage() {
    var pickup = Provider.of<AppData>(context, listen: false).pickupAddress;
    var destination =
        Provider.of<AppData>(context, listen: false).destinationAddress;

    // pickup과 destination이 모두 존재하는지 확인
    if (pickup == null || destination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('app.search.error.pickup_destination_required'.tr()),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (pickup.latitude == null ||
        pickup.longitude == null ||
        destination.latitude == null ||
        destination.longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('app.search.error.invalid_location'.tr()),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (selectedDate == null || selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('app.search.error.date_time_required'.tr()),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // 모든 정보를 AppData에 저장
    Provider.of<AppData>(
      context,
      listen: false,
    ).updateLuggageCount(luggageCount);
    Provider.of<AppData>(
      context,
      listen: false,
    ).updateRideDateTime(selectedDate!, selectedTime!);
    Provider.of<AppData>(
      context,
      listen: false,
    ).updateCompanionCount(companionCount);

    // RideConfirmationPage로 이동
    Navigator.pushNamed(context, 'rideconfirmation');
  }

  // 날짜 선택 다이얼로그
  Future<void> _selectDate(BuildContext context) async {
    final DateTime now = DateTime.now();
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    final primaryColor = Color(0xFF3F51B5);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 1, now.month, now.day),
      helpText: 'app.search.date_picker.title'.tr(),
      cancelText: 'app.common.cancel'.tr(),
      confirmText: 'app.common.confirm'.tr(),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data:
              isDarkMode
                  ? ThemeData.dark().copyWith(
                    colorScheme: ColorScheme.dark(
                      primary: primaryColor,
                      onPrimary: Colors.white,
                      surface: Color(0xFF121212),
                      onSurface: Colors.white,
                    ),
                    dialogTheme: DialogThemeData(
                      backgroundColor: Color(0xFF121212),
                    ),
                  )
                  : ThemeData.light().copyWith(
                    colorScheme: ColorScheme.light(
                      primary: primaryColor,
                      onPrimary: Colors.white,
                      onSurface: Colors.black,
                    ),
                    dialogTheme: DialogThemeData(backgroundColor: Colors.white),
                  ),
          child: child ?? Container(),
        );
      },
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        dateController.text = "${picked.year}년 ${picked.month}월 ${picked.day}일";
      });
    }
  }

  // 시간 선택 다이얼로그
  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay now = TimeOfDay.now();
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    final primaryColor = Color(0xFF3F51B5);

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: selectedTime ?? now,
      helpText: 'app.search.time_picker.title'.tr(),
      cancelText: 'app.common.cancel'.tr(),
      confirmText: 'app.common.confirm'.tr(),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data:
              isDarkMode
                  ? ThemeData.dark().copyWith(
                    colorScheme: ColorScheme.dark(
                      primary: primaryColor,
                      onPrimary: Colors.white,
                      surface: Color(0xFF121212),
                      onSurface: Colors.white,
                    ),
                    timePickerTheme: TimePickerThemeData(
                      backgroundColor: Color(0xFF121212),
                      hourMinuteColor: primaryColor.withOpacity(0.1),
                      hourMinuteTextColor: Colors.white,
                      dayPeriodTextColor: Colors.white70,
                      dialBackgroundColor: Color(0xFF212121),
                      dialHandColor: primaryColor,
                      dialTextColor: Colors.white,
                    ),
                    dialogTheme: DialogThemeData(
                      backgroundColor: Color(0xFF121212),
                    ),
                  )
                  : ThemeData.light().copyWith(
                    colorScheme: ColorScheme.light(
                      primary: primaryColor,
                      onPrimary: Colors.white,
                      onSurface: Colors.black,
                    ),
                    timePickerTheme: TimePickerThemeData(
                      backgroundColor: Colors.white,
                      hourMinuteColor: primaryColor.withOpacity(0.1),
                      hourMinuteTextColor: Colors.black,
                      dayPeriodTextColor: Colors.black87,
                      dialBackgroundColor: Colors.grey.shade200,
                      dialHandColor: primaryColor,
                      dialTextColor: Colors.black87,
                    ),
                  ),
          child: child ?? Container(),
        );
      },
    );

    if (picked != null && picked != selectedTime) {
      setState(() {
        selectedTime = picked;
        // 12시간제로 표시 (AM/PM)
        final hour = picked.hourOfPeriod;
        final hourDisplayed = hour == 0 ? 12 : hour;
        final period = picked.hour < 12 ? 'AM' : 'PM';

        timeController.text =
            "$hourDisplayed:${picked.minute.toString().padLeft(2, '0')} $period";
      });
    }
  }

  void _updateLuggageCount(int count) {
    setState(() {
      luggageCount = count;
    });
    widget.onLuggageCountChanged?.call(count);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    final primaryColor = Color(0xFF3F51B5);
    final backgroundColor = isDarkMode ? Colors.black : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final cardColor = isDarkMode ? Color(0xFF1A1A1A) : Colors.white;
    final borderColor = isDarkMode ? Colors.grey[800] : Colors.grey[300];

    // 전체 주소 대신 빌딩 이름(placeName)만 표시
    String address =
        Provider.of<AppData>(context).pickupAddress?.placeName ?? '';
    pickupController.text = address;

    return WillPopScope(
      onWillPop: () async {
        // Provider에서 출발지 정보 초기화
        Provider.of<AppData>(
          context,
          listen: false,
        ).updatePickupAddress(Address());

        // 홈페이지로 이동 (왼쪽에서 오른쪽으로 슬라이드)
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => HomePage(),
            transitionsBuilder: (
              context,
              animation,
              secondaryAnimation,
              child,
            ) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(-1, 0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.fastOutSlowIn,
                  ),
                ),
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 150),
          ),
        );
        return false; // 기본 뒤로가기 방지
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: backgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: textColor),
            onPressed: () {
              // Provider에서 출발지 정보 초기화
              Provider.of<AppData>(
                context,
                listen: false,
              ).updatePickupAddress(Address());

              // 홈페이지로 이동 (왼쪽에서 오른쪽으로 슬라이드)
              Navigator.of(context).pushReplacement(
                PageRouteBuilder(
                  pageBuilder:
                      (context, animation, secondaryAnimation) => HomePage(),
                  transitionsBuilder: (
                    context,
                    animation,
                    secondaryAnimation,
                    child,
                  ) {
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(-1, 0),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.fastOutSlowIn,
                        ),
                      ),
                      child: child,
                    );
                  },
                  transitionDuration: const Duration(milliseconds: 150),
                ),
              );
            },
          ),
          title: Text(
            'app.search.title'.tr(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: backgroundColor,
                  boxShadow: [
                    BoxShadow(
                      color:
                          isDarkMode
                              ? Colors.black12
                              : Colors.black.withOpacity(0.05),
                      blurRadius: 8.0,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // Solo/Group Ride 토글 버튼 추가
                      Container(
                        margin: EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color:
                              isDarkMode ? Color(0xFF202020) : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                isDarkMode
                                    ? Colors.grey[800]!
                                    : Colors.grey[300]!,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    isGroupRide = false;
                                    companionCount =
                                        0; // Solo Ride 선택 시 동반자 수 0으로 초기화
                                    luggageCount =
                                        1; // Solo Ride 선택 시 캐리어 개수 초기화
                                  });
                                },
                                child: Container(
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color:
                                        !isGroupRide
                                            ? primaryColor
                                            : (isDarkMode
                                                ? Color(0xFF202020)
                                                : Colors.grey[100]),
                                    borderRadius: BorderRadius.horizontal(
                                      left: Radius.circular(11),
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Solo Ride',
                                      style: TextStyle(
                                        color:
                                            !isGroupRide
                                                ? Colors.white
                                                : (isDarkMode
                                                    ? Colors.grey[400]
                                                    : Colors.grey[600]),
                                        fontWeight:
                                            !isGroupRide
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    isGroupRide = true;
                                    companionCount =
                                        1; // Group Ride 선택 시 기본값 2명(본인+1)으로 설정
                                    luggageCount =
                                        1; // Group Ride 선택 시 캐리어 개수 초기화
                                  });
                                },
                                child: Container(
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color:
                                        isGroupRide
                                            ? primaryColor
                                            : (isDarkMode
                                                ? Color(0xFF202020)
                                                : Colors.grey[100]),
                                    borderRadius: BorderRadius.horizontal(
                                      right: Radius.circular(11),
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Group Ride',
                                      style: TextStyle(
                                        color:
                                            isGroupRide
                                                ? Colors.white
                                                : (isDarkMode
                                                    ? Colors.grey[400]
                                                    : Colors.grey[600]),
                                        fontWeight:
                                            isGroupRide
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 출발지 입력
                      Container(
                        margin: EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color:
                              isDarkMode ? Color(0xFF202020) : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                isDarkMode
                                    ? Colors.grey[800]!
                                    : Colors.grey[300]!,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.horizontal(
                                  left: Radius.circular(12),
                                ),
                              ),
                              child: Icon(
                                Icons.location_on_rounded,
                                color: primaryColor,
                                size: 24,
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: pickupController,
                                readOnly: true,
                                onTap: () {
                                  // 출발지 선택을 위한 바텀 시트 표시
                                  _showPickupOptionsBottomSheet(context);
                                },
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 16,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'app.search.pickup'.tr(),
                                  hintStyle: TextStyle(
                                    color:
                                        isDarkMode
                                            ? Colors.grey[500]
                                            : Colors.grey[600],
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 목적지 입력
                      Container(
                        margin: EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color:
                              isDarkMode ? Color(0xFF202020) : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                isDarkMode
                                    ? Colors.grey[800]!
                                    : Colors.grey[300]!,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.horizontal(
                                  left: Radius.circular(12),
                                ),
                              ),
                              child: Icon(
                                Icons.location_city_rounded,
                                color: primaryColor,
                                size: 24,
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                focusNode: focusDestination,
                                controller: destinationController,
                                readOnly: true,
                                onTap: () {
                                  // 도착지 선택을 위한 바텀 시트 표시
                                  _showDestinationOptionsBottomSheet(context);
                                },
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 16,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'app.search.destination'.tr(),
                                  hintStyle: TextStyle(
                                    color:
                                        isDarkMode
                                            ? Colors.grey[500]
                                            : Colors.grey[600],
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 날짜와 시간 선택 (가로 배치)
                      Row(
                        children: [
                          // 날짜 선택
                          Expanded(
                            child: Container(
                              margin: EdgeInsets.only(right: 8, bottom: 16),
                              decoration: BoxDecoration(
                                color:
                                    isDarkMode
                                        ? Color(0xFF202020)
                                        : Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color:
                                      isDarkMode
                                          ? Colors.grey[800]!
                                          : Colors.grey[300]!,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: primaryColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.horizontal(
                                        left: Radius.circular(12),
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.calendar_today_rounded,
                                      color: primaryColor,
                                      size: 20,
                                    ),
                                  ),
                                  Expanded(
                                    child: TextField(
                                      controller: dateController,
                                      readOnly: true,
                                      onTap: () => _selectDate(context),
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 15,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'app.search.date'.tr(),
                                        hintStyle: TextStyle(
                                          color:
                                              isDarkMode
                                                  ? Colors.grey[500]
                                                  : Colors.grey[600],
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // 시간 선택
                          Expanded(
                            child: Container(
                              margin: EdgeInsets.only(left: 8, bottom: 16),
                              decoration: BoxDecoration(
                                color:
                                    isDarkMode
                                        ? Color(0xFF202020)
                                        : Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color:
                                      isDarkMode
                                          ? Colors.grey[800]!
                                          : Colors.grey[300]!,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: primaryColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.horizontal(
                                        left: Radius.circular(12),
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.access_time_rounded,
                                      color: primaryColor,
                                      size: 20,
                                    ),
                                  ),
                                  Expanded(
                                    child: TextField(
                                      controller: timeController,
                                      readOnly: true,
                                      onTap: () => _selectTime(context),
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 15,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'app.search.time'.tr(),
                                        hintStyle: TextStyle(
                                          color:
                                              isDarkMode
                                                  ? Colors.grey[500]
                                                  : Colors.grey[600],
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      // 캐리어 개수 선택 (Solo Ride에서만 표시)
                      if (!isGroupRide)
                        Container(
                          margin: EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color:
                                isDarkMode
                                    ? Color(0xFF202020)
                                    : Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  isDarkMode
                                      ? Colors.grey[800]!
                                      : Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.horizontal(
                                    left: Radius.circular(12),
                                  ),
                                ),
                                child: Icon(
                                  Icons.luggage_rounded,
                                  color: primaryColor,
                                  size: 24,
                                ),
                              ),
                              SizedBox(width: 16),
                              Text(
                                'app.search.luggage'.tr(),
                                style: TextStyle(
                                  fontSize: 16,
                                  color: textColor,
                                ),
                              ),
                              Spacer(),
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.remove, color: textColor),
                                    onPressed: () {
                                      setState(() {
                                        if (luggageCount > 0) {
                                          luggageCount--;
                                        }
                                      });
                                    },
                                  ),
                                  Text(
                                    '$luggageCount',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.add, color: textColor),
                                    onPressed: () {
                                      setState(() {
                                        if (luggageCount < 2) {
                                          // Solo Ride일 때는 최대 2개
                                          luggageCount++;
                                        } else {
                                          // 최대 개수 도달 시 알림
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                '인당 최대 2개의 캐리어만 허용됩니다.',
                                              ),
                                              duration: Duration(seconds: 2),
                                            ),
                                          );
                                        }
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                      // 동반자 선택 (Group Ride일 때만 표시)
                      if (isGroupRide) ...[
                        // 총 인원수 (동반자 포함) 박스
                        Container(
                          margin: EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color:
                                isDarkMode
                                    ? Color(0xFF202020)
                                    : Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  isDarkMode
                                      ? Colors.grey[800]!
                                      : Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.horizontal(
                                    left: Radius.circular(12),
                                  ),
                                ),
                                child: Icon(
                                  Icons.people_rounded,
                                  color: primaryColor,
                                  size: 24,
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  'app.search.companions'.tr(),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: textColor,
                                    height: 1.2,
                                  ),
                                  maxLines: 2,
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: BoxConstraints(),
                                    icon: Icon(
                                      Icons.remove,
                                      color: textColor,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        if (companionCount > 1) {
                                          companionCount--;
                                          int maxLuggage =
                                              (companionCount + 1) * 2;
                                          if (luggageCount > maxLuggage) {
                                            luggageCount = maxLuggage;
                                          }
                                        }
                                      });
                                    },
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    '${companionCount + 1}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: BoxConstraints(),
                                    icon: Icon(
                                      Icons.add,
                                      color: textColor,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        if (companionCount < 3) {
                                          companionCount++;
                                        }
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // 총 캐리어 개수 박스 (Group Ride)
                        Container(
                          margin: EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color:
                                isDarkMode
                                    ? Color(0xFF202020)
                                    : Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  isDarkMode
                                      ? Colors.grey[800]!
                                      : Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.horizontal(
                                    left: Radius.circular(12),
                                  ),
                                ),
                                child: Icon(
                                  Icons.luggage_rounded,
                                  color: primaryColor,
                                  size: 24,
                                ),
                              ),
                              SizedBox(width: 16),
                              Text(
                                'app.search.luggage'.tr(),
                                style: TextStyle(
                                  fontSize: 16,
                                  color: textColor,
                                ),
                              ),
                              Spacer(),
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.remove, color: textColor),
                                    onPressed: () {
                                      setState(() {
                                        if (luggageCount > 0) {
                                          luggageCount--;
                                        }
                                      });
                                    },
                                  ),
                                  Text(
                                    '$luggageCount',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.add, color: textColor),
                                    onPressed: () {
                                      setState(() {
                                        // 총 인원수에 따른 최대 캐리어 개수 계산 (인당 2개)
                                        int maxLuggage =
                                            (companionCount + 1) * 2;
                                        if (luggageCount < maxLuggage) {
                                          luggageCount++;
                                        } else {
                                          // 최대 개수 도달 시 알림
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                '인당 최대 2개의 캐리어만 허용됩니다.',
                                              ),
                                              duration: Duration(seconds: 2),
                                            ),
                                          );
                                        }
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // 확인 버튼
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 60, vertical: 5),
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 200),
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      // 버튼에 물결 효과 추가
                      ScaffoldMessenger.of(context).clearSnackBars();
                      navigateToMainPage();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                      shadowColor: primaryColor.withOpacity(0.4),
                    ),
                    child: Text(
                      'app.search.confirm'.tr(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),

              // 버튼과 콘텐츠 사이에 공간 및 구분선 추가
              SizedBox(height: 12),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Divider(
                  color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                  thickness: 1,
                ),
              ),
              SizedBox(height: 12),

              // 추천 경로, 프로모션, 이용 팁 등 콘텐츠
              if (destinationPredictionList.isEmpty) ...[
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // PLORIDE 광고 배너
                      Container(
                        width: double.infinity,
                        height: 160,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            colors: [Color(0xFF3F51B5), Color(0xFF5C6BC0)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              right: -10,
                              bottom: -10,
                              child: Icon(
                                Icons.airport_shuttle_rounded,
                                size: 100,
                                color: Colors.white.withOpacity(0.2),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'TAGO',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 24,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'app.search.banner.description'.tr(),
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 16,
                                    ),
                                  ),
                                  Spacer(flex: 2),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      'app.search.banner.book_now'.tr(),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 24),
                      Text(
                        'app.search.tips.title'.tr(),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      SizedBox(height: 12),
                      _buildTipCard(
                        context,
                        'app.search.tips.book_early'.tr(),
                        'app.search.tips.book_early_desc'.tr(),
                        Icons.access_time,
                        isDarkMode,
                      ),
                      SizedBox(height: 8),
                      _buildTipCard(
                        context,
                        'app.search.tips.prepare_luggage'.tr(),
                        'app.search.tips.prepare_luggage_desc'.tr(),
                        Icons.luggage,
                        isDarkMode,
                      ),
                      SizedBox(height: 8),
                      _buildTipCard(
                        context,
                        'app.search.tips.arrival_time'.tr(),
                        'app.search.tips.arrival_time_desc'.tr(),
                        Icons.timer,
                        isDarkMode,
                      ),
                      // 공간 확보를 위한 패딩 추가
                      SizedBox(height: 80),
                    ],
                  ),
                ),
              ] else ...[
                // 검색 결과 목록
                ListView.separated(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.all(0),
                  itemBuilder: (context, index) {
                    return PredictionTile(
                      prediction: destinationPredictionList[index],
                      isPickup: false,
                    );
                  },
                  separatorBuilder:
                      (BuildContext context, int index) => Divider(
                        height: 1,
                        thickness: 1,
                        color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                      ),
                  itemCount: destinationPredictionList.length,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    pickupController.dispose();
    destinationController.dispose();
    super.dispose();
  }

  // 출발 위치 옵션을 선택하기 위한 바텀 시트
  void _showPickupOptionsBottomSheet(BuildContext context) {
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    final backgroundColor = isDarkMode ? Colors.black : Colors.white;
    final sheetColor = isDarkMode ? Color(0xFF121212) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            padding: EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: sheetColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 핸들 바
                Container(
                  margin: EdgeInsets.only(bottom: 16),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // 헤더
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'app.search.popup.select_pickup'.tr(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
                SizedBox(height: 8),
                // Penn State University 옵션
                ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Color(0xFF3F51B5).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.school, color: Color(0xFF3F51B5)),
                  ),
                  title: Text(
                    'app.search.popup.psu_option'.tr(),
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                  subtitle: Text(
                    'app.search.popup.psu_subtitle'.tr(),
                    style: TextStyle(
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  onTap: () {
                    // 출발 위치 타입을 'psu'로 설정
                    setState(() {
                      pickupLocationType = 'psu';
                      // 도착지 초기화
                      destinationController.text = '';
                      Provider.of<AppData>(
                        context,
                        listen: false,
                      ).updateDestinationAddress(Address());
                    });
                    Navigator.pop(context);
                    _showPsuLocationsBottomSheet(context);
                  },
                ),
                // Airport 옵션
                ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Color(0xFF3F51B5).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.flight, color: Color(0xFF3F51B5)),
                  ),
                  title: Text(
                    'app.search.popup.airport_option'.tr(),
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                  subtitle: Text(
                    'app.search.popup.airport_subtitle'.tr(),
                    style: TextStyle(
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  onTap: () {
                    // 출발 위치 타입을 'airport'로 설정
                    setState(() {
                      pickupLocationType = 'airport';
                      // 도착지 초기화
                      destinationController.text = '';
                      Provider.of<AppData>(
                        context,
                        listen: false,
                      ).updateDestinationAddress(Address());
                    });
                    Navigator.pop(context);
                    _showAirportPickupLocationsBottomSheet(context);
                  },
                ),
                SizedBox(height: 16),
              ],
            ),
          ),
    );
  }

  // 공항 출발 위치 선택을 위한 바텀 시트
  void _showAirportPickupLocationsBottomSheet(BuildContext context) {
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    final backgroundColor = isDarkMode ? Colors.black : Colors.white;
    final sheetColor = isDarkMode ? Color(0xFF121212) : Colors.white;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: sheetColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              children: [
                // 핸들 바
                Container(
                  margin: EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // 헤더
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.flight, color: Color(0xFF3F51B5)),
                      SizedBox(width: 12),
                      Text(
                        'app.search.popup.airport_pickup'.tr(),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1),
                // 리스트
                Expanded(
                  child: AirportLocationsList(
                    isDarkMode: isDarkMode,
                    onLocationSelected: (Address address) {
                      Navigator.pop(context); // 바텀 시트 닫기
                      // 지도 페이지로 이동
                      _navigateToLocationMapPage(context, address);
                    },
                    updateTextField: (String name) {
                      // 빌딩 이름만 표시
                      pickupController.text = name;
                    },
                  ),
                ),
              ],
            ),
          ),
    );
  }

  // PSU 위치 선택을 위한 바텀 시트
  void _showPsuLocationsBottomSheet(BuildContext context) {
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    final backgroundColor = isDarkMode ? Colors.black : Colors.white;
    final sheetColor = isDarkMode ? Color(0xFF121212) : Colors.white;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 전체 높이를 사용할 수 있도록 설정
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: sheetColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              children: [
                // 핸들 바
                Container(
                  margin: EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // 헤더
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.location_on, color: Color(0xFF3F51B5)),
                      SizedBox(width: 12),
                      Text(
                        'app.search.popup.psu_locations'.tr(),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1),
                // 리스트
                Expanded(
                  child: PsuLocationsList(
                    isDarkMode: isDarkMode,
                    onLocationSelected: (Address address) {
                      Navigator.pop(context); // 바텀 시트 닫기

                      // 빌딩 이름을 TextController에 설정
                      setState(() {
                        pickupController.text = address.placeName ?? '';
                      });

                      // 모든 위치에 대해 지도 페이지로 이동
                      _navigateToLocationMapPage(context, address);
                    },
                  ),
                ),
              ],
            ),
          ),
    );
  }

  // 도착 위치 옵션을 선택하기 위한 바텀 시트
  void _showDestinationOptionsBottomSheet(BuildContext context) {
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    final backgroundColor = isDarkMode ? Colors.black : Colors.white;
    final sheetColor = isDarkMode ? Color(0xFF121212) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    // 출발 위치 타입에 따라 자동으로 도착 위치 선택
    if (pickupLocationType == 'psu') {
      // PSU에서 출발한 경우 바로 공항 목적지 선택 화면으로 이동
      _showAirportDestinationLocationsBottomSheet(context);
      return;
    } else if (pickupLocationType == 'airport') {
      // 공항에서 출발한 경우 바로 PSU 목적지 선택 화면으로 이동
      _showPsuDestinationLocationsBottomSheet(context);
      return;
    }

    // 출발 위치를 선택하지 않은 경우 기존 바텀 시트 표시
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            padding: EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: sheetColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 핸들 바
                Container(
                  margin: EdgeInsets.only(bottom: 16),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // 헤더
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'app.search.popup.select_destination'.tr(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
                SizedBox(height: 8),
                // Penn State University 옵션
                ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Color(0xFF3F51B5).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.school, color: Color(0xFF3F51B5)),
                  ),
                  title: Text(
                    'app.search.popup.psu_option'.tr(),
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                  subtitle: Text(
                    'app.search.popup.psu_destination_subtitle'.tr(),
                    style: TextStyle(
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showPsuDestinationLocationsBottomSheet(context);
                  },
                ),
                // Airport 옵션
                ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Color(0xFF3F51B5).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.flight, color: Color(0xFF3F51B5)),
                  ),
                  title: Text(
                    'app.search.popup.airport_option'.tr(),
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                  subtitle: Text(
                    'app.search.popup.airport_destination_subtitle'.tr(),
                    style: TextStyle(
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showAirportDestinationLocationsBottomSheet(context);
                  },
                ),
                SizedBox(height: 16),
              ],
            ),
          ),
    );
  }

  // PSU 도착 위치 선택을 위한 바텀 시트
  void _showPsuDestinationLocationsBottomSheet(BuildContext context) {
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    final backgroundColor = isDarkMode ? Colors.black : Colors.white;
    final sheetColor = isDarkMode ? Color(0xFF121212) : Colors.white;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 전체 높이를 사용할 수 있도록 설정
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: sheetColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              children: [
                // 핸들 바
                Container(
                  margin: EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // 헤더
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.location_on, color: Color(0xFF3F51B5)),
                      SizedBox(width: 12),
                      Text(
                        'Penn State University 도착 위치',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1),
                // 리스트
                Expanded(
                  child: PsuLocationsList(
                    isDarkMode: isDarkMode,
                    onLocationSelected: (Address address) {
                      Navigator.pop(context); // 바텀 시트 닫기

                      // 빌딩 이름을 TextController에 설정
                      setState(() {
                        destinationController.text = address.placeName ?? '';
                      });

                      // 지도 페이지로 이동
                      _navigateToDestinationMapPage(context, address);
                    },
                  ),
                ),
              ],
            ),
          ),
    );
  }

  // 지도 위치 확인 페이지로 이동하는 함수
  void _navigateToLocationMapPage(BuildContext context, Address address) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => LocationMapPage(
              address: address,
              isPickup: true,
              onConfirm: () {
                // 확인 버튼을 누르면 위치 정보를 AppData에 저장하고 SearchPage로 돌아옴
                Provider.of<AppData>(
                  context,
                  listen: false,
                ).updatePickupAddress(address);

                // 빌딩 이름만 표시하도록 설정
                setState(() {
                  pickupController.text = address.placeName ?? '';
                });

                Navigator.pop(context); // 지도 페이지 닫기
              },
            ),
      ),
    );
  }

  // 목적지 지도 위치 확인 페이지로 이동하는 함수
  void _navigateToDestinationMapPage(BuildContext context, Address address) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => LocationMapPage(
              address: address,
              isPickup: false,
              onConfirm: () {
                // 확인 버튼을 누르면 위치 정보를 AppData에 저장하고 SearchPage로 돌아옴
                Provider.of<AppData>(
                  context,
                  listen: false,
                ).updateDestinationAddress(address);

                // 빌딩 이름만 표시하도록 설정
                setState(() {
                  destinationController.text = address.placeName ?? '';
                });

                Navigator.pop(context); // 지도 페이지 닫기
              },
            ),
      ),
    );
  }

  // 공항 도착 위치 선택을 위한 바텀 시트
  void _showAirportDestinationLocationsBottomSheet(BuildContext context) {
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    final backgroundColor = isDarkMode ? Colors.black : Colors.white;
    final sheetColor = isDarkMode ? Color(0xFF121212) : Colors.white;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 전체 높이를 사용할 수 있도록 설정
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: sheetColor,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              children: [
                // 핸들 바
                Container(
                  margin: EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // 헤더
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.flight_takeoff, color: Color(0xFF3F51B5)),
                      SizedBox(width: 12),
                      Text(
                        'app.search.popup.airport_destination'.tr(),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1),
                // 리스트
                Expanded(
                  child: AirportLocationsList(
                    isDarkMode: isDarkMode,
                    onLocationSelected: (Address address) {
                      Navigator.pop(context); // 바텀 시트 닫기
                      // 지도 페이지로 이동
                      _navigateToDestinationMapPage(context, address);
                    },
                    updateTextField: (String name) {
                      // 빌딩 이름만 표시
                      destinationController.text = name;
                    },
                  ),
                ),
              ],
            ),
          ),
    );
  }

  // 팁 카드를 위한 헬퍼 메소드
  Widget _buildTipCard(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    bool isDarkMode,
  ) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Color(0xFF202020) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Color(0xFF3F51B5).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Color(0xFF3F51B5)),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
