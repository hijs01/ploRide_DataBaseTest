import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cabrider/dataprovider/appdata.dart';
import 'package:cabrider/datamodels/address.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cabrider/globalvariable.dart';
import 'package:cabrider/helpers/helpermethods.dart';
import 'package:cabrider/screens/homepage.dart';

class RideConfirmationPage extends StatefulWidget {
  static const String id = 'rideconfirmation';

  @override
  _RideConfirmationPageState createState() => _RideConfirmationPageState();
}

class _RideConfirmationPageState extends State<RideConfirmationPage> {
  bool _isLoading = false;

  // 인디고 색상 정의
  final Color themeColor = Color(0xFF3F51B5); // 인디고 색상
  final Color secondaryColor = Color(0xFF5C6BC0); // 밝은 인디고 색상

  // 슬라이더 값 상태 추가
  double _sliderValue = 0.0;

  // 예약 정보를 Firestore에 저장하고 드라이버에게 전송하는 함수
  Future<void> _confirmRide() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('탑승 정보가 올바르지 않습니다')));
        return;
      }

      // 현재 사용자 확인
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('로그인이 필요합니다')));
        return;
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

      // 라이드 요청 데이터 생성
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

      print('라이드 요청 데이터:');
      print(rideMap);

      // Firestore에 라이드 요청 저장
      DocumentReference rideRef = await FirebaseFirestore.instance
          .collection('rideRequests')
          .add(rideMap);

      print('라이드 요청 생성 성공: ${rideRef.id}');

      // 가용 드라이버들에게 알림 전송 (선택적)
      try {
        // MainPage의 FireHelper.nearbyDriverList를 사용하거나 드라이버 목록을 직접 가져옴
        // 1. driversAvailable 컬렉션에서 온라인 드라이버 가져오기
        QuerySnapshot driversAvailable =
            await FirebaseFirestore.instance
                .collection('driversAvailable')
                .get();

        print(
          'driversAvailable 컬렉션 조회 결과: ${driversAvailable.docs.length}개 문서 발견',
        );

        // 온라인 드라이버가 없다면 drivers 컬렉션 확인
        if (driversAvailable.docs.isEmpty) {
          print('온라인 드라이버가 없어 drivers 컬렉션 확인');
          QuerySnapshot allDrivers =
              await FirebaseFirestore.instance
                  .collection('drivers')
                  .limit(5)
                  .get();

          for (var doc in allDrivers.docs) {
            print('드라이버 문서 확인: ${doc.id}, 데이터: ${doc.data()}');
          }

          print('drivers 컬렉션에서 online 필드가 true인 드라이버 확인');
          // 여러 가능한 필드명 시도
          List<String> possibleFields = [
            'available',
            'online',
            'isOnline',
            'status',
          ];

          for (var field in possibleFields) {
            try {
              QuerySnapshot onlineDrivers =
                  await FirebaseFirestore.instance
                      .collection('drivers')
                      .where(field, isEqualTo: true)
                      .get();

              print('필드 $field로 검색한 결과: ${onlineDrivers.docs.length}개 문서');

              if (onlineDrivers.docs.isNotEmpty) {
                driversAvailable = onlineDrivers;
                print('사용된 필드: $field');
                break;
              }
            } catch (e) {
              print('$field 필드로 쿼리 중 오류: $e');
            }
          }
        }

        // 드라이버가 발견되지 않았다면 테스트 드라이버 사용
        if (driversAvailable.docs.isEmpty) {
          print('가용 드라이버를 찾을 수 없어 임시 방편으로 첫 번째 드라이버 사용');

          QuerySnapshot firstDriver =
              await FirebaseFirestore.instance
                  .collection('drivers')
                  .limit(1)
                  .get();

          if (firstDriver.docs.isNotEmpty) {
            driversAvailable = firstDriver;
            print('첫 번째 드라이버를 사용합니다: ${firstDriver.docs.first.id}');
          }
        }

        if (driversAvailable.docs.isNotEmpty) {
          // 첫 번째 가용 드라이버에게 알림 전송
          String driverId = driversAvailable.docs.first.id;

          // driver_id 필드가 있다면 그 값을 사용
          var driverData =
              driversAvailable.docs.first.data() as Map<String, dynamic>;
          if (driverData.containsKey('driver_id')) {
            driverId = driverData['driver_id'].toString();
            print('driver_id 필드 발견: $driverId');
          }

          print('알림을 보낼 드라이버: $driverId');

          // 드라이버의 newtrip 필드 업데이트 (드라이버 앱이 이를 확인)
          await FirebaseFirestore.instance
              .collection('drivers')
              .doc(driverId)
              .update({
                'newtrip': rideRef.id,
                'notification_time': FieldValue.serverTimestamp(),
              });

          print('드라이버($driverId)에게 라이드 요청 전송 완료');

          // HelperMethods를 통해 FCM 푸시 알림 전송
          await HelperMethods.sendNotification(
            driverId: driverId,
            context: context,
            ride_id: rideRef.id,
          );
        } else {
          print('가용 드라이버가 없습니다');
        }
      } catch (e) {
        print('드라이버 알림 전송 중 오류: $e');
      }

      // 예약 완료 알림
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('예약이 완료되었습니다!'),
          backgroundColor: Colors.green,
        ),
      );

      // 홈페이지로 이동
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => HomePage()),
        (route) => false,
      );
    } catch (e) {
      print('라이드 요청 생성 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류가 발생했습니다: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                              onHorizontalDragUpdate: (details) {
                                // 드래그 위치를 계산하여 슬라이더 값 업데이트
                                double newPosition =
                                    _sliderValue +
                                    details.delta.dx /
                                        (MediaQuery.of(context).size.width -
                                            92);
                                setState(() {
                                  _sliderValue = newPosition.clamp(0.0, 1.0);
                                });

                                // 예약 확정 조건
                                if (_sliderValue >= 0.9) {
                                  _showMatchingDialog(context);
                                  Future.delayed(
                                    Duration(milliseconds: 300),
                                    () {
                                      if (mounted) {
                                        setState(() {
                                          _sliderValue = 0.0;
                                        });
                                      }
                                    },
                                  );
                                }
                              },
                              onHorizontalDragEnd: (details) {
                                // 사용자가 끝까지 슬라이드하지 않은 경우 초기 위치로 돌아감
                                if (_sliderValue < 0.9) {
                                  setState(() {
                                    _sliderValue = 0.0;
                                  });
                                }
                              },
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
    // 테마 색상 가져오기 - 인디고 색상 사용
    final Color primaryColor = themeColor;
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    final Color textColor = isDarkMode ? Colors.white : Colors.black87;
    final Color subtitleColor =
        isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;
    final Color cardColor = isDarkMode ? Color(0xFF1E1E1E) : Colors.white;

    showDialog(
      context: context,
      barrierDismissible: false, // 배경 터치로 닫기 방지
      barrierColor: Colors.black54, // 배경을 더 어둡게 처리
      builder: (BuildContext dialogContext) {
        return Dialog(
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
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      strokeWidth: 3,
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  '비슷한 일정의 예약자와\n매칭중 입니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  '잠시만 기다려 주세요',
                  style: TextStyle(fontSize: 14, color: subtitleColor),
                ),
                SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );

    // 3초 후에 다이얼로그 닫고 스낵바 표시
    Future.delayed(Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pop(); // 다이얼로그 닫기
        _confirmRide(); // 실제 예약 확정 함수 호출
      }
    });
  }
}
