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
  @override
  _RideConfirmationPageState createState() => _RideConfirmationPageState();
}

class _RideConfirmationPageState extends State<RideConfirmationPage> {
  bool _isLoading = false;

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
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    final backgroundColor = isDarkMode ? Colors.black : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final primaryColor = Color(0xFF3F51B5);

    final appData = Provider.of<AppData>(context);
    final pickup = appData.pickupAddress;
    final destination = appData.destinationAddress;
    final luggageCount = appData.luggageCount;
    final rideDate = appData.rideDate;
    final rideTime = appData.rideTime;

    // 날짜 및 시간 포맷
    String formattedDate =
        rideDate != null
            ? "${rideDate.year}년 ${rideDate.month}월 ${rideDate.day}일"
            : "날짜 정보 없음";

    String formattedTime =
        rideTime != null
            ? "${rideTime.hour}:${rideTime.minute.toString().padLeft(2, '0')}"
            : "시간 정보 없음";

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          '예약 확인',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 예약 정보 카드
              Container(
                decoration: BoxDecoration(
                  color: isDarkMode ? Color(0xFF1A1A1A) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '탑승 정보',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      SizedBox(height: 16),

                      // 출발지
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.location_on, color: primaryColor),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '출발지',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color:
                                        isDarkMode
                                            ? Colors.grey[400]
                                            : Colors.grey[600],
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  pickup?.placeName ?? '출발지 정보 없음',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: textColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 16),

                      // 목적지
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.location_city, color: primaryColor),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '목적지',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color:
                                        isDarkMode
                                            ? Colors.grey[400]
                                            : Colors.grey[600],
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  destination?.placeName ?? '목적지 정보 없음',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: textColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 16),

                      // 날짜 및 시간
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today, color: primaryColor),
                                SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '날짜',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color:
                                            isDarkMode
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      formattedDate,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: textColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Row(
                              children: [
                                Icon(Icons.access_time, color: primaryColor),
                                SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '시간',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color:
                                            isDarkMode
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      formattedTime,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: textColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 16),

                      // 캐리어 개수
                      Row(
                        children: [
                          Icon(Icons.luggage, color: primaryColor),
                          SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '캐리어 개수',
                                style: TextStyle(
                                  fontSize: 14,
                                  color:
                                      isDarkMode
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '$luggageCount개',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: textColor,
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

              SizedBox(height: 24),

              // 이용 약관 안내
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDarkMode ? Color(0xFF202020) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '이용 안내',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• 예약 시간 10분 전까지 취소 가능합니다.\n• 드라이버가 도착하면 알림을 받게 됩니다.\n• 결제는 탑승 완료 후 진행됩니다.',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 32),

              // 확인 버튼
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _confirmRide,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child:
                      _isLoading
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text(
                            '예약 확정',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
