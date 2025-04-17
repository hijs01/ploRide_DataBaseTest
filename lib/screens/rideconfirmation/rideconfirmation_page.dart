import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cabrider/dataprovider/appdata.dart';
import 'package:cabrider/datamodels/address.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:cabrider/globalvariable.dart';
// 알림 관련 임포트 주석 처리
// import 'package:cabrider/helpers/helpermethods.dart';
import 'package:cabrider/screens/homepage.dart';

class RideConfirmationPage extends StatefulWidget {
  static const String id = 'rideconfirmation';

  const RideConfirmationPage({super.key});

  @override
  _RideConfirmationPageState createState() => _RideConfirmationPageState();
}

class _RideConfirmationPageState extends State<RideConfirmationPage>
    with WidgetsBindingObserver {
  bool _isLoading = false;
  bool _isProcessing = false; // 예약 처리 중 상태 추가
  bool _disposed = false; // 위젯 dispose 상태 체크

  // 인디고 색상 정의
  final Color themeColor = Color(0xFF3F51B5); // 인디고 색상
  final Color secondaryColor = Color(0xFF5C6BC0); // 밝은 인디고 색상

  // 슬라이더 값 상태 추가
  double _sliderValue = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 페이지가 로드되면 채팅방 리스너를 설정
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupChatRoomListener();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // 앱이 백그라운드로 가거나 종료될 때 이미 진행 중인 작업 취소 로직 추가 가능
      _isProcessing = false;
    }
  }

  // setState 함수를 오버라이드하여 안전하게 상태 업데이트
  @override
  void setState(VoidCallback fn) {
    if (!_disposed && mounted) {
      super.setState(fn);
    }
  }

  // 예약 확정 버튼 슬라이드 처리 함수
  void _handleSliderUpdate(DragUpdateDetails details, BuildContext context) {
    // 이미 처리 중이면 무시
    if (_isLoading || _isProcessing) return;

    // 드래그 위치를 계산하여 슬라이더 값 업데이트
    final double maxWidth = MediaQuery.of(context).size.width - 92;
    double newPosition = _sliderValue + details.delta.dx / maxWidth;

    setState(() {
      _sliderValue = newPosition.clamp(0.0, 1.0);
    });

    // 예약 확정 조건
    if (_sliderValue >= 0.9 && !_isLoading && !_isProcessing) {
      // 슬라이더 값을 리셋하고 로딩 상태로 전환
      setState(() {
        _sliderValue = 0.0;
        _isLoading = true;
      });

      // 안전하게 UI 업데이트 후 다이얼로그 표시
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_disposed) {
          _showMatchingDialog(context);
        }
      });
    }
  }

  // 예약 확정 버튼 슬라이드 종료 처리 함수
  void _handleSliderEnd(DragEndDetails details) {
    // 이미 처리 중이면 무시
    if (_isLoading || _isProcessing) return;

    // 사용자가 끝까지 슬라이드하지 않은 경우 초기 위치로 돌아감
    if (_sliderValue < 0.9) {
      setState(() {
        _sliderValue = 0.0;
      });
    }
  }

  // 예약 정보를 Firestore에 저장하고 드라이버에게 전송하는 함수
  Future<void> _confirmRide() async {
    if (_isLoading) return;

    try {
      setState(() {
        _isLoading = true;
      });

      await _processRide();

      // 이전 코드에서는 여기서 성공 메시지와 네비게이션을 했지만
      // 이 함수를 직접 호출하는 곳이 있을 수 있어 남겨둡니다.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('예약이 완료되었습니다! 채팅방에서 다른 여행자들과 소통하세요.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );

        // 홈페이지로 이동
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => HomePage()),
          (route) => false,
        );
      }
    } catch (e) {
      print('라이드 요청 생성 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    var appData = Provider.of<AppData>(context);
    var pickup = appData.pickupAddress;
    var destination = appData.destinationAddress;

    // 테마 색상 설정
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    final Color primaryColor = themeColor; // 인디고 색상 사용
    final Color textColor = isDarkMode ? Colors.white : Colors.black87;
    final Color subtitleColor =
        isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;
    final Color backgroundColor = isDarkMode ? Color(0xFF121212) : Colors.white;
    final Color cardColor = isDarkMode ? Color(0xFF1E1E1E) : Colors.white;
    final Color dividerColor =
        isDarkMode ? Colors.grey[800]! : Colors.grey[300]!;

    // 날짜와 시간 형식화
    String formattedDate = '';
    String formattedTime = '';

    if (appData.rideDate != null) {
      formattedDate =
          "${appData.rideDate!.year}년 ${appData.rideDate!.month}월 ${appData.rideDate!.day}일";
    }

    if (appData.rideTime != null) {
      String period = appData.rideTime!.hour < 12 ? '오전' : '오후';
      int hour = appData.rideTime!.hour % 12;
      if (hour == 0) hour = 12;
      formattedTime =
          "$period $hour:${appData.rideTime!.minute.toString().padLeft(2, '0')}";
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        title: Text(
          '탑승 정보 확인',
          style: TextStyle(
            color: textColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 18),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: Icon(
              isDarkMode ? Icons.light_mode : Icons.dark_mode,
              color: textColor,
              size: 18,
            ),
            onPressed: () {
              // 테마 전환 기능 (실제 구현 없음)
            },
          ),
        ],
      ),
      body: SafeArea(
        child: WillPopScope(
          // 처리 중일 때 뒤로가기 방지
          onWillPop: () async {
            return !_isProcessing;
          },
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                // 출발지-목적지 카드
                Container(
                  margin: EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Column(
                      children: [
                        // 출발지-목적지 경로 시각화
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 왼쪽 경로 아이콘
                            SizedBox(
                              width: 24,
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.trip_origin,
                                    color: primaryColor,
                                    size: 16,
                                  ),
                                  Container(
                                    width: 1,
                                    height: 30,
                                    color: primaryColor.withOpacity(0.3),
                                  ),
                                  Icon(
                                    Icons.location_on,
                                    color: primaryColor,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 12),
                            // 출발지-목적지 텍스트 정보
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 출발지
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '출발지',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: subtitleColor,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        pickup?.placeName ?? '정보 없음',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: textColor,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 16),
                                  // 목적지
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '목적지',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: subtitleColor,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        destination?.placeName ?? '정보 없음',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: textColor,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
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

                // 날짜, 시간, 캐리어 개수 그리드
                Container(
                  margin: EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      _buildInfoCard(
                        context,
                        Icons.calendar_today_outlined,
                        '날짜',
                        formattedDate.isEmpty ? '정보 없음' : formattedDate,
                        primaryColor,
                        textColor,
                        subtitleColor,
                        cardColor,
                        flex: 2,
                      ),
                      SizedBox(width: 8),
                      _buildInfoCard(
                        context,
                        Icons.access_time,
                        '시간',
                        formattedTime.isEmpty ? '정보 없음' : formattedTime,
                        primaryColor,
                        textColor,
                        subtitleColor,
                        cardColor,
                      ),
                      SizedBox(width: 8),
                      _buildInfoCard(
                        context,
                        Icons.luggage,
                        '캐리어',
                        '${appData.luggageCount}개',
                        primaryColor,
                        textColor,
                        subtitleColor,
                        cardColor,
                      ),
                    ],
                  ),
                ),

                // 요금 카드 (강조 표시)
                Container(
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor, secondaryColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.receipt_long_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '예상 요금',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            '15,000원',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      Spacer(),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '현금결제',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.payments_outlined,
                              color: Colors.white,
                              size: 14,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 35),

                // 예약 확정을 위한 슬라이드 버튼 (GestureDetector 사용)
                Container(
                  margin: EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    children: [
                      Container(
                        height: 55,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Stack(
                          children: [
                            // 진행 표시줄
                            AnimatedContainer(
                              duration: Duration(milliseconds: 100),
                              width:
                                  MediaQuery.of(context).size.width *
                                  _sliderValue,
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),

                            // 안내 텍스트
                            Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.arrow_forward,
                                    color:
                                        _sliderValue > 0.6
                                            ? Colors.white
                                            : primaryColor,
                                    size: 16,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    '스와이프하여 예약 확정',
                                    style: TextStyle(
                                      color:
                                          _sliderValue > 0.6
                                              ? Colors.white
                                              : primaryColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // 슬라이더 노브
                            Positioned(
                              left:
                                  (_sliderValue *
                                      (MediaQuery.of(context).size.width - 92)),
                              top: 3.5,
                              child: GestureDetector(
                                onHorizontalDragUpdate:
                                    (details) =>
                                        _handleSliderUpdate(details, context),
                                onHorizontalDragEnd: _handleSliderEnd,
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 5,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.arrow_forward,
                                    color: primaryColor,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '오른쪽으로 끝까지 밀어서 예약 확정',
                        style: TextStyle(color: subtitleColor, fontSize: 12),
                      ),
                    ],
                  ),
                ),

                // 남은 공간 채우기
                Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 정보 카드 위젯
  Widget _buildInfoCard(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    Color primaryColor,
    Color textColor,
    Color subtitleColor,
    Color cardColor, {
    int flex = 1,
  }) {
    return Expanded(
      flex: flex,
      child: Container(
        height: 95,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: primaryColor, size: 14),
            ),
            SizedBox(height: 8),
            Text(label, style: TextStyle(fontSize: 11, color: subtitleColor)),
            SizedBox(height: 4),
            Expanded(
              child: Container(
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 매칭 중 다이얼로그를 표시하는 함수
  void _showMatchingDialog(BuildContext context) {
    // 이미 처리 중이면 중복 실행 방지
    if (_isProcessing) return;

    // 상태 설정
    setState(() {
      _isProcessing = true;
    });

    // 테마 색상 가져오기 - 인디고 색상 사용
    final Color primaryColor = themeColor;
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    final Color textColor = isDarkMode ? Colors.white : Colors.black87;
    final Color subtitleColor =
        isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;
    final Color cardColor = isDarkMode ? Color(0xFF1E1E1E) : Colors.white;

    // 다이얼로그 컨트롤러 (닫기 제어용)
    BuildContext? dialogContext;

    // 안전하게 다이얼로그 표시
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false, // 배경 터치로 닫기 방지
        barrierColor: Colors.black54, // 배경을 더 어둡게 처리
        builder: (BuildContext context) {
          dialogContext = context;
          return WillPopScope(
            // 뒤로가기 버튼 비활성화
            onWillPop: () async => false,
            child: Dialog(
              backgroundColor: cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0),
              ),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.8,
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 8),
                    // 개선된 로딩 애니메이션
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            primaryColor,
                          ),
                          strokeWidth: 3,
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      '예약 정보를 처리 중입니다',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      '비슷한 일정의 여행자들과 그룹을 구성 중입니다',
                      style: TextStyle(fontSize: 14, color: subtitleColor),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '4명의 여행자가 모이면 드라이버에게 표시되며,\n드라이버 수락 후 채팅방이 활성화됩니다',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: subtitleColor),
                    ),
                    SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    // 다이얼로그 표시 후 처리 시작
    _safeConfirmRide()
        .then((_) {
          // 성공 시 다이얼로그 닫기 및 상태 업데이트
          _closeDialogAndUpdateUI(
            dialogContext: dialogContext,
            isSuccess: true,
            message: '예약 정보가 등록되었습니다. 드라이버 매칭을 기다려주세요.',
          );
        })
        .catchError((e) {
          print('예약 처리 오류: $e');

          // 오류 발생 시 다이얼로그 닫기 및 상태 업데이트
          _closeDialogAndUpdateUI(
            dialogContext: dialogContext,
            isSuccess: false,
            message: e.toString(),
          );
        })
        .whenComplete(() {
          // 무슨 일이 있어도 상태 업데이트
          if (mounted) {
            setState(() {
              _isLoading = false;
              _isProcessing = false;
            });
          }
        });
  }

  // 다이얼로그 닫고 UI 업데이트하는 헬퍼 함수
  void _closeDialogAndUpdateUI({
    BuildContext? dialogContext,
    required bool isSuccess,
    required String message,
  }) {
    // 다이얼로그 닫기
    if (dialogContext != null && mounted) {
      try {
        Navigator.of(dialogContext).pop();
      } catch (e) {
        print('다이얼로그 닫기 오류: $e');
      }
    }

    if (!mounted) return;

    // 스낵바 표시
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        duration: Duration(seconds: isSuccess ? 4 : 6),
      ),
    );

    // 성공 시 홈페이지로 이동
    if (isSuccess && mounted) {
      // 알림 전송 부분 주석 처리
      /*
      try {
        // FCM 알림 전송 로직이 있다면 여기에 있을 것
      } catch (e) {
        print('알림 전송 오류: $e');
      }
      */

      Future.delayed(Duration(milliseconds: 500), () {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => HomePage()),
          (route) => false,
        );
      });
    }
  }

  // 예약 처리 로직을 별도 함수로 분리
  Future<void> _processRide() async {
    try {
      final appData = Provider.of<AppData>(context, listen: false);
      final pickup = appData.pickupAddress;
      final destination = appData.destinationAddress;
      final luggageCount = appData.luggageCount;
      final rideDate = appData.rideDate;
      final rideTime = appData.rideTime;

      // 필수 정보 확인
      if (pickup == null ||
          destination == null ||
          rideDate == null ||
          rideTime == null) {
        throw Exception('탑승 정보가 올바르지 않습니다');
      }

      // 현재 사용자 확인
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('로그인이 필요합니다');
      }

      // 예약 시간을 DateTime으로 변환
      final rideDateTime = DateTime(
        rideDate.year,
        rideDate.month,
        rideDate.day,
        rideTime.hour,
        rideTime.minute,
      );

      // 픽업과 목적지 위치 정보
      Map<String, dynamic> pickupMap = {
        'latitude': pickup.latitude,
        'longitude': pickup.longitude,
        'address': pickup.placeName,
        'formatted_address': pickup.placeFormattedAddress,
      };

      Map<String, dynamic> destinationMap = {
        'latitude': destination.latitude,
        'longitude': destination.longitude,
        'address': destination.placeName,
        'formatted_address': destination.placeFormattedAddress,
      };

      // 출발지와 목적지 정보 확인
      String pickupName = pickup.placeName?.toLowerCase() ?? '';
      String destinationName = destination.placeName?.toLowerCase() ?? '';

      // 채팅방 컬렉션 이름과 식별자 결정
      String chatRoomCollection = '';
      String locationIdentifier = '';
      int chatRoomNumber = 1; // 기본 채팅방 번호

      // Penn State University에서 출발하는 경우 - 도착 공항 기준으로 그룹화
      if (pickupName.contains('penn state') ||
          pickupName.contains('university') ||
          pickupName.contains('대학')) {
        chatRoomCollection = 'psuToAirport'; // PSU에서 공항으로 컬렉션

        // 목적지(공항) 이름에서 식별자 추출
        if (destinationName.contains('airport') ||
            destinationName.contains('공항')) {
          // 공항 이름 추출 (예: jfk airport -> jfk)
          String airportName =
              destinationName
                  .replaceAll("airport", "")
                  .replaceAll("공항", "")
                  .trim();
          if (airportName.isEmpty) {
            airportName = "unknown";
          }
          locationIdentifier = airportName.replaceAll(" ", "_");
        } else {
          locationIdentifier = destinationName.replaceAll(" ", "_");
        }

        print('출발지가 Penn State University입니다. psuToAirport 컬렉션을 사용합니다.');
        print('식별자: $locationIdentifier');
      }
      // 공항에서 출발하는 경우 - 출발 공항 기준으로 그룹화
      else if (pickupName.contains('airport') || pickupName.contains('공항')) {
        chatRoomCollection = 'airportToPsu'; // 공항에서 PSU로 컬렉션

        // 출발지(공항) 이름에서 식별자 추출
        String airportName =
            pickupName.replaceAll("airport", "").replaceAll("공항", "").trim();
        if (airportName.isEmpty) {
          airportName = "unknown";
        }
        locationIdentifier = airportName.replaceAll(" ", "_");

        print('출발지가 공항입니다. airportToPsu 컬렉션을 사용합니다.');
        print('식별자: $locationIdentifier');
      } else {
        // 둘 다 아닌 경우(일반 케이스) 기본값 설정
        chatRoomCollection = 'generalRides';
        locationIdentifier = '${pickupName}_to_$destinationName'.replaceAll(
          " ",
          "_",
        );
        print('일반 경로입니다. generalRides 컬렉션을 사용합니다.');
      }

      // 날짜를 yyyy-mm-dd 형식으로 변환 (채팅방 필터링용)
      String formattedDate =
          "${rideDate.year}-${rideDate.month.toString().padLeft(2, '0')}-${rideDate.day.toString().padLeft(2, '0')}";

      // 시간대 식별자 생성 (채팅방 그룹화용)
      int timeSlot = (rideTime.hour / 2).floor(); // 2시간 단위로 시간대 그룹화

      print('채팅방 컬렉션: $chatRoomCollection, 위치 식별자: $locationIdentifier');

      // 라이드 요청 데이터 생성 (채팅방 저장 전에 미리 준비)
      Map<String, dynamic> rideMap = {
        'created_at': FieldValue.serverTimestamp(),
        'rider_name': currentUserInfo?.fullName ?? user.displayName ?? '이름 없음',
        'rider_phone': currentUserInfo?.phone ?? '전화번호 없음',
        'rider_email': user.email,
        'pickup': pickupMap,
        'destination': destinationMap,
        'luggage_count': luggageCount,
        'ride_date': rideDateTime,
        'ride_date_timestamp': Timestamp.fromDate(rideDateTime),
        'status': 'pending',
        'user_id': user.uid,
        'payment_method': 'card',
        'driver_id': 'waiting',
      };

      print('라이드 요청 데이터 준비 완료');

      // 트랜잭션과 함께 타임아웃 설정
      String chatRoomId = '';
      DocumentReference chatRoomRef;

      try {
        // 타임아웃 설정으로 비동기 작업 보호
        await Future.wait([
          // 1. 기존 채팅방 검색 작업
          Future(() async {
            // 해당 컬렉션에서 같은 날짜와 비슷한 시간대의 채팅방 찾기
            QuerySnapshot existingChatRooms = await FirebaseFirestore.instance
                .collection(chatRoomCollection)
                .where('location_identifier', isEqualTo: locationIdentifier)
                .where('date_str', isEqualTo: formattedDate)
                .get()
                .timeout(Duration(seconds: 5));

            print('같은 날짜/위치의 기존 채팅방 수: ${existingChatRooms.docs.length}');

            // 비슷한 시간대(±1시간)의 채팅방 찾기
            bool foundMatchingRoom = false;
            chatRoomRef =
                FirebaseFirestore.instance
                    .collection(chatRoomCollection)
                    .doc(); // 초기 빈 참조로 초기화

            // 기존 채팅방 중에서 시간이 맞고 인원 여유가 있는 채팅방 찾기
            if (existingChatRooms.docs.isNotEmpty) {
              for (var doc in existingChatRooms.docs) {
                Map<String, dynamic> roomData =
                    doc.data() as Map<String, dynamic>;

                // 채팅방의 탑승 시간 확인
                if (roomData.containsKey('ride_date_timestamp')) {
                  Timestamp rideTimestamp =
                      roomData['ride_date_timestamp'] as Timestamp;
                  DateTime roomRideDateTime = rideTimestamp.toDate();

                  // 시간 차이 계산 (절대값)
                  Duration timeDifference =
                      roomRideDateTime.difference(rideDateTime).abs();

                  // 채팅방 멤버 수 확인
                  List<dynamic> members = roomData['members'] ?? [];

                  // 시간 차이가 1시간 이내이고, 멤버 수가 4명 미만이며, 해당 사용자가 멤버가 아닌 경우
                  if (timeDifference.inHours <= 1 &&
                      members.length < 4 &&
                      !members.contains(user.uid)) {
                    chatRoomId = doc.id;
                    chatRoomRef = FirebaseFirestore.instance
                        .collection(chatRoomCollection)
                        .doc(chatRoomId);

                    print(
                      '비슷한 시간대의 채팅방을 찾았습니다: $chatRoomId (시간 차이: ${timeDifference.inMinutes}분)',
                    );
                    foundMatchingRoom = true;
                    break;
                  }
                }
              }
            }

            // 적합한 채팅방을 찾지 못한 경우 새 채팅방 생성
            if (!foundMatchingRoom) {
              // 새 채팅방 번호 결정 (기존 채팅방 중 가장 큰 번호 + 1)
              int maxRoomNumber = 0;

              for (var doc in existingChatRooms.docs) {
                String docId = doc.id;

                // 문서 ID에서 번호 부분 추출 (예: jfk_1 -> 1)
                List<String> parts = docId.split('_');
                if (parts.length > 1) {
                  try {
                    int roomNumber = int.parse(parts.last);
                    if (roomNumber > maxRoomNumber) {
                      maxRoomNumber = roomNumber;
                    }
                  } catch (e) {
                    print('채팅방 번호 추출 오류: $e');
                  }
                }
              }

              chatRoomNumber = maxRoomNumber + 1;
              // 새 채팅방 ID 생성 (prefix_locationIdentifier_번호)
              String prefix = "";
              if (chatRoomCollection == 'psuToAirport') {
                prefix = "pta_";
              } else if (chatRoomCollection == 'airportToPsu') {
                prefix = "atp_";
              }
              chatRoomId = "${prefix}${locationIdentifier}_$chatRoomNumber";

              print('새 채팅방 생성: $chatRoomId');

              // 채팅방 참조
              chatRoomRef = FirebaseFirestore.instance
                  .collection(chatRoomCollection)
                  .doc(chatRoomId);

              // 새 채팅방 데이터
              Map<String, dynamic> chatRoomData = {
                'created_at': FieldValue.serverTimestamp(),
                'location_identifier': locationIdentifier,
                'ride_date': rideDateTime,
                'ride_date_timestamp': Timestamp.fromDate(rideDateTime),
                'date_str': formattedDate,
                'time_slot': timeSlot,
                'pickup_info': pickupMap,
                'destination_info': destinationMap,
                'members': [user.uid],
                'member_count': 1,
                'last_message': '새로운 그룹이 생성되었습니다.',
                'last_message_time': FieldValue.serverTimestamp(),
                'room_number': chatRoomNumber,
                'collection_name': chatRoomCollection,
                'luggage_count_total': luggageCount,
                'user_luggage_counts': {user.uid: luggageCount},
                // 새로운 필드 추가: 드라이버 앱 관련 필드
                'driver_accepted': false, // 드라이버가 수락했는지 여부
                'driver_id': '', // 수락한 드라이버 ID
                'available_for_driver': false, // 드라이버 앱에 표시 여부
                'chat_activated': false, // 채팅방 활성화 여부
                'chat_visible': false, // 채팅방 표시 여부 필드 추가 (driver_accepted와 연동)
              };

              // 채팅방 생성
              await chatRoomRef.set(chatRoomData).timeout(Duration(seconds: 5));

              // 시스템 메시지 추가
              try {
                // 사용자 정보 가져오기
                DocumentSnapshot userDoc =
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .get();

                String userName = '알 수 없음';
                if (userDoc.exists) {
                  Map<String, dynamic> userData =
                      userDoc.data() as Map<String, dynamic>;
                  userName = userData['fullname'] ?? '알 수 없음';
                }

                await FirebaseFirestore.instance
                    .collection(chatRoomCollection)
                    .doc(chatRoomId)
                    .collection('messages')
                    .where('text', isEqualTo: '$userName님이 그룹에 참여했습니다.')
                    .get()
                    .then((snapshot) async {
                      if (snapshot.docs.isEmpty) {
                        await FirebaseFirestore.instance
                            .collection(chatRoomCollection)
                            .doc(chatRoomId)
                            .collection('messages')
                            .add({
                              'text': '$userName님이 그룹에 참여했습니다.',
                              'sender_id': 'system',
                              'sender_name': '시스템',
                              'timestamp': FieldValue.serverTimestamp(),
                              'type': 'system',
                            });
                      }
                    });
              } catch (e) {
                print('시스템 메시지 추가 중 오류: $e');
              }

              print('새 채팅방 생성 완료: $chatRoomId in $chatRoomCollection');
            }
            // 적합한 채팅방을 찾은 경우, 해당 채팅방에 사용자 추가
            else {
              print('기존 채팅방에 사용자 추가: $chatRoomId');

              DocumentSnapshot chatRoomDoc = await chatRoomRef.get().timeout(
                Duration(seconds: 5),
              );
              Map<String, dynamic> chatRoomData =
                  chatRoomDoc.data() as Map<String, dynamic>;
              List<dynamic> members = chatRoomData['members'] ?? [];

              if (!members.contains(user.uid)) {
                // 사용자 정보 가져오기
                DocumentSnapshot userDoc =
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .get();

                String userName = '알 수 없음';
                if (userDoc.exists) {
                  Map<String, dynamic> userData =
                      userDoc.data() as Map<String, dynamic>;
                  userName = userData['fullname'] ?? '알 수 없음';
                }

                // 채팅방 멤버 목록에 사용자 추가
                members.add(user.uid);

                // 업데이트할 데이터 준비
                Map<String, dynamic> updateData = {
                  'members': FieldValue.arrayUnion([user.uid]),
                  'member_count': FieldValue.increment(1),
                  'last_message': '$userName님이 그룹에 참여했습니다.',
                  'last_message_time': FieldValue.serverTimestamp(),
                  'luggage_count_total': FieldValue.increment(luggageCount),
                  'user_luggage_counts.${user.uid}': luggageCount,
                };

                // 1명이 모이면 드라이버 앱에 표시 가능하도록 설정
                if (members.length + 1 >= 1) {
                  // 기존 멤버 + 현재 추가된 사용자
                  updateData['available_for_driver'] = true;

                  // 로그 추가
                  print('1명이 모였습니다. 드라이버 앱에 표시됩니다.');
                }

                // 채팅방 업데이트
                await chatRoomRef.update(updateData);

                // 참여 메시지 추가
                await FirebaseFirestore.instance
                    .collection(chatRoomCollection)
                    .doc(chatRoomId)
                    .collection('messages')
                    .where('text', isEqualTo: '$userName님이 그룹에 참여했습니다.')
                    .get()
                    .then((snapshot) async {
                      if (snapshot.docs.isEmpty) {
                        await FirebaseFirestore.instance
                            .collection(chatRoomCollection)
                            .doc(chatRoomId)
                            .collection('messages')
                            .add({
                              'text': '$userName님이 그룹에 참여했습니다.',
                              'sender_id': 'system',
                              'sender_name': '시스템',
                              'timestamp': FieldValue.serverTimestamp(),
                              'type': 'system',
                            });
                      }
                    });

                print('사용자를 기존 채팅방에 추가했습니다.');
              } else {
                print('사용자가 이미 채팅방에 존재합니다.');
              }
            }
          }).timeout(Duration(seconds: 15)),
        ]);
      } catch (e) {
        print('채팅방 생성/검색 중 오류: $e');
        throw Exception('채팅방 처리 중 오류가 발생했습니다. 다시 시도해주세요.');
      }

      // --------- 사용자 정보 및 라이드 요청 저장 로직 ---------

      try {
        // 사용자의 채팅방 목록에 추가
        String userChatRoomPath = '$chatRoomCollection/$chatRoomId';

        // 고유한 문서 ID 생성 (안전한 방법)
        String safeDocId = "${chatRoomCollection}_$chatRoomId".replaceAll(
          '/',
          '_',
        );

        // 채팅방 정보 가져오기
        DocumentSnapshot chatRoomDoc = await FirebaseFirestore.instance
            .collection(chatRoomCollection)
            .doc(chatRoomId)
            .get()
            .timeout(Duration(seconds: 5));

        Map<String, dynamic> chatRoomData =
            chatRoomDoc.data() as Map<String, dynamic>;

        // 채팅방 활성화 상태 확인
        bool isChatActivated = chatRoomData['driver_accepted'] ?? false;

        // 사용자의 채팅방 정보 설정
        Map<String, dynamic> userChatRoomData = {
          'chat_room_collection': chatRoomCollection,
          'chat_room_id': chatRoomId,
          'chat_room_path': userChatRoomPath,
          'joined_at': FieldValue.serverTimestamp(),
          'ride_date': rideDateTime,
          'driver_accepted': chatRoomData['driver_accepted'] ?? false,
          'driver_id': chatRoomData['driver_id'] ?? '',
          'chat_visible':
              chatRoomData['driver_accepted'] ??
              false, // driver_accepted 값과 동일하게 설정
        };

        // 사용자 채팅방 목록에 추가
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('chatRooms')
            .doc(safeDocId) // 안전하게 처리된 ID 사용
            .set(userChatRoomData)
            .timeout(Duration(seconds: 5));

        print('사용자의 채팅방 목록에 추가 완료');

        // 히스토리에 즉시 추가
        String status = isChatActivated ? '확정됨' : '드라이버의 수락을 기다리는 중';
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('history')
            .add({
              'pickup': pickupMap['address'] ?? '',
              'destination': destinationMap['address'] ?? '',
              'status': status,
              'timestamp': FieldValue.serverTimestamp(),
              'tripId': chatRoomId,
              'pickup_info': pickupMap,
              'destination_info': destinationMap,
            })
            .timeout(Duration(seconds: 5));

        print('사용자의 히스토리에 즉시 추가 완료');

        // driver_accepted가 true인 경우에만 추가 메시지 표시
        if (isChatActivated) {
          print('드라이버가 이미 수락한 채팅방입니다. 즉시 활성화됩니다.');
        } else {
          print('드라이버 수락을 기다리는 중입니다.');
        }

        return; // 모든 작업 완료
      } catch (e) {
        print('사용자 정보 저장 중 오류: $e');
        throw Exception('예약 정보 저장 중 오류가 발생했습니다. 네트워크 연결을 확인해주세요.');
      }
    } catch (e) {
      print('_processRide 오류: $e');
      String errorMessage = '예약 처리 중 오류가 발생했습니다';

      if (e.toString().contains('network') ||
          e.toString().contains('timeout')) {
        errorMessage = '네트워크 연결 상태를 확인해주세요';
      } else if (e.toString().contains('permission-denied')) {
        errorMessage = '권한이 없습니다. 다시 로그인해주세요';
      } else if (e.toString().contains('not-found')) {
        errorMessage = '요청한 정보를 찾을 수 없습니다';
      }

      throw Exception(errorMessage);
    }
  }

  // 예약 확정을 안전하게 시도하는 함수 (재시도 로직 포함)
  Future<void> _safeConfirmRide() async {
    int retryCount = 0;
    const int maxRetries = 2;
    const Duration baseDelay = Duration(milliseconds: 500);

    while (retryCount <= maxRetries) {
      try {
        await _processRide();

        // 성공 후 채팅방 상태에 따라 메시지 조정
        final appData = Provider.of<AppData>(context, listen: false);
        final user = FirebaseAuth.instance.currentUser;

        if (user != null) {
          // 가장 최근에 생성된 채팅방 정보 확인을 위한 쿼리
          QuerySnapshot chatRooms =
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('chatRooms')
                  .orderBy('joined_at', descending: true)
                  .limit(1)
                  .get();

          if (chatRooms.docs.isNotEmpty) {
            var chatRoomData =
                chatRooms.docs.first.data() as Map<String, dynamic>;
            bool isDriverAccepted = chatRoomData['driver_accepted'] ?? false;

            if (!isDriverAccepted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('예약이 대기열에 추가되었습니다. 드라이버 수락 후 채팅방이 활성화됩니다.'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 4),
                ),
              );
            }
          }
        }

        return; // 성공하면 즉시 반환
      } catch (e) {
        retryCount++;
        print('예약 시도 $retryCount 실패: $e');

        if (retryCount > maxRetries) {
          if (e is FirebaseException) {
            // Firebase 관련 구체적인 오류 처리
            if (e.code == 'permission-denied') {
              throw Exception('권한이 없습니다. 다시 로그인해주세요.');
            } else if (e.code == 'not-found') {
              throw Exception('요청한 정보를 찾을 수 없습니다.');
            } else {
              throw Exception('Firebase 오류: ${e.message}');
            }
          } else {
            rethrow; // 최대 재시도 횟수 초과 시 예외를 다시 던짐
          }
        }

        // 지수 백오프로 대기 시간 증가
        final delay = baseDelay * (retryCount * 2);
        await Future.delayed(delay);
      }
    }
  }

  // 채팅방 리스너 설정을 위한 코드 추가
  Future<void> _setupChatRoomListener() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 최근 추가된 채팅방 찾기
      QuerySnapshot chatRooms =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('chatRooms')
              .orderBy('joined_at', descending: true)
              .limit(1)
              .get();

      if (chatRooms.docs.isNotEmpty) {
        Map<String, dynamic> chatRoomData =
            chatRooms.docs.first.data() as Map<String, dynamic>;
        String chatRoomCollection = chatRoomData['chat_room_collection'] ?? '';
        String chatRoomId = chatRoomData['chat_room_id'] ?? '';

        if (chatRoomCollection.isNotEmpty && chatRoomId.isNotEmpty) {
          // 원본 채팅방 문서 리스너 설정
          FirebaseFirestore.instance
              .collection(chatRoomCollection)
              .doc(chatRoomId)
              .snapshots()
              .listen(
                (documentSnapshot) async {
                  if (documentSnapshot.exists) {
                    Map<String, dynamic> data =
                        documentSnapshot.data() as Map<String, dynamic>;
                    bool driverAccepted = data['driver_accepted'] ?? false;
                    String driverId = data['driver_id'] ?? '';
                    bool chatActivated = data['chat_activated'] ?? false;

                    // driver_accepted 상태가 변경되고 chat_activated가 false인 경우에만 처리
                    if (driverAccepted && !chatActivated) {
                      // 원본 채팅방 문서에 chat_activated 필드 업데이트
                      await FirebaseFirestore.instance
                          .collection(chatRoomCollection)
                          .doc(chatRoomId)
                          .update({
                            'chat_activated': true,
                            'chat_visible': true,
                          });

                      // 채팅방의 모든 멤버 가져오기
                      DocumentSnapshot roomSnapshot =
                          await FirebaseFirestore.instance
                              .collection(chatRoomCollection)
                              .doc(chatRoomId)
                              .get();

                      if (roomSnapshot.exists) {
                        Map<String, dynamic> roomData =
                            roomSnapshot.data() as Map<String, dynamic>;
                        List<dynamic> members = roomData['members'] ?? [];

                        // 각 멤버의 채팅방 정보 업데이트
                        for (String memberId in members) {
                          String memberSafeDocId =
                              "${chatRoomCollection}_$chatRoomId".replaceAll(
                                '/',
                                '_',
                              );

                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(memberId)
                              .collection('chatRooms')
                              .doc(memberSafeDocId)
                              .update({
                                'driver_accepted': true,
                                'driver_id': driverId,
                                'chat_visible': true,
                              });

                          // 히스토리 상태 업데이트 개선
                          print('사용자 $memberId의 히스토리 상태 업데이트 시도 중');
                          try {
                            // 히스토리 컬렉션에서 해당 tripId를 가진 모든 문서 찾기
                            QuerySnapshot historyQuery =
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(memberId)
                                    .collection('history')
                                    .where('tripId', isEqualTo: chatRoomId)
                                    .get();

                            print(
                              '사용자 $memberId의 히스토리 문서 개수: ${historyQuery.docs.length}',
                            );

                            if (historyQuery.docs.isEmpty) {
                              print(
                                '사용자 $memberId의 히스토리에서 tripId=$chatRoomId를 찾을 수 없습니다.',
                              );

                              // 대안으로 히스토리 컬렉션에서 가장 최근 문서 확인
                              QuerySnapshot recentHistoryQuery =
                                  await FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(memberId)
                                      .collection('history')
                                      .orderBy('timestamp', descending: true)
                                      .limit(1)
                                      .get();

                              if (recentHistoryQuery.docs.isNotEmpty) {
                                var historyDoc = recentHistoryQuery.docs.first;
                                print('최근 히스토리 문서를 찾았습니다: ${historyDoc.id}');

                                // 해당 문서의 pickup_info와 destination_info가 채팅방과 일치하는지 확인
                                var historyData =
                                    historyDoc.data() as Map<String, dynamic>;

                                // 최근 히스토리 문서 상태 업데이트
                                await historyDoc.reference.update({
                                  'status': '확정됨',
                                  'tripId': chatRoomId, // tripId도 업데이트
                                });
                                print('최근 히스토리 문서 상태를 "확정됨"으로 업데이트했습니다.');
                              }
                            } else {
                              // 기존 방식: tripId로 찾은 문서 업데이트
                              for (var historyDoc in historyQuery.docs) {
                                print(
                                  '히스토리 문서 ${historyDoc.id}의 상태를 "확정됨"으로 업데이트합니다.',
                                );
                                await historyDoc.reference.update({
                                  'status': '확정됨',
                                });
                              }
                              print('히스토리 상태 업데이트 완료');
                            }
                          } catch (e) {
                            print('히스토리 상태 업데이트 중 오류 발생: $e');
                          }
                        }

                        // 채팅방에 시스템 메시지 추가 (중복 방지를 위해 이전 메시지 확인)
                        QuerySnapshot existingMessages =
                            await FirebaseFirestore.instance
                                .collection(chatRoomCollection)
                                .doc(chatRoomId)
                                .collection('messages')
                                .where(
                                  'text',
                                  isEqualTo: '드라이버가 요청을 수락했습니다. 채팅방이 활성화되었습니다.',
                                )
                                .get();

                        if (existingMessages.docs.isEmpty) {
                          await FirebaseFirestore.instance
                              .collection(chatRoomCollection)
                              .doc(chatRoomId)
                              .collection('messages')
                              .add({
                                'text': '드라이버가 요청을 수락했습니다. 채팅방이 활성화되었습니다.',
                                'sender_id': 'system',
                                'sender_name': '시스템',
                                'timestamp': FieldValue.serverTimestamp(),
                                'type': 'system',
                              });
                        }
                      }

                      print('드라이버가 수락했습니다. 채팅방이 활성화됩니다.');
                    }
                  }
                },
                onError: (error) {
                  print('채팅방 리스너 오류: $error');
                },
              );
        }
      }
    } catch (e) {
      print('채팅방 리스너 설정 오류: $e');
    }
  }
}
