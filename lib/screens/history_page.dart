import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:TAGO/screens/homepage.dart';
import 'package:TAGO/screens/chat_page.dart';
import 'package:TAGO/screens/settings_page.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:easy_localization/easy_localization.dart';

class HistoryPage extends StatefulWidget {
  static const String id = 'history';

  const HistoryPage({Key? key}) : super(key: key);

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  int _selectedIndex = 1; // 히스토리 탭이 선택됨
  bool _isRefreshing = false; // 새로고침 상태 추가
  List<Map<String, dynamic>> _psuToAirportTrips = [];
  List<Map<String, dynamic>> _airportToPsuTrips = [];

  @override
  void initState() {
    super.initState();
    initializeDateFormatting();
    print('HistoryPage initialized');
    _checkUserData();
    _deleteTestData(); // 테스트 데이터 삭제
    _checkAllRidesStatus(); // 모든 라이드 상태 확인
    _loadTrips(); // 새로운 메서드 호출
  }

  String _formatDate(DateTime date) {
    final locale = context.locale.languageCode;
    if (locale == 'ko') {
      return DateFormat('yyyy년 MM월 dd일', 'ko').format(date);
    } else {
      return DateFormat('MMMM d, yyyy', 'en_US').format(date);
    }
  }

  Future<void> _checkUserData() async {
    final currentUser = _auth.currentUser;
    print('Current user: ${currentUser?.uid}');

    if (currentUser != null) {
      // 사용자의 히스토리 데이터 확인
      final historySnapshot =
          await _firestore
              .collection('users')
              .doc(currentUser.uid)
              .collection('history')
              .get();

      print('History count: ${historySnapshot.docs.length}');

      // psuToAirport 데이터 확인
      final psuToAirportSnapshot =
          await _firestore.collection('psuToAirport').get();

      print('psuToAirport count: ${psuToAirportSnapshot.docs.length}');

      // 현재 사용자가 멤버로 포함된 문서 확인
      final userTrips =
          psuToAirportSnapshot.docs.where((doc) {
            final data = doc.data();
            final members = data['members'] as List<dynamic>?;
            return members?.contains(currentUser.uid) ?? false;
          }).toList();

      print('User trips count: ${userTrips.length}');
    }
  }

  Future<void> _deleteTestData() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // psuToAirport 컬렉션에서 테스트 데이터 삭제
        final testDataQuery =
            await _firestore
                .collection('psuToAirport')
                .where('pickup_info.address', isEqualTo: 'PSU 캠퍼스')
                .where('destination_info.address', isEqualTo: '인천국제공항')
                .get();

        for (var doc in testDataQuery.docs) {
          await doc.reference.delete();
          print('Deleted test data document: ${doc.id}');
        }

        // users 컬렉션의 history에서 테스트 데이터 삭제
        final historyQuery =
            await _firestore
                .collection('users')
                .doc(user.uid)
                .collection('history')
                .where('pickup', isEqualTo: 'PSU 캠퍼스')
                .where('destination', isEqualTo: '인천국제공항')
                .get();

        for (var doc in historyQuery.docs) {
          await doc.reference.delete();
          print('Deleted test history document: ${doc.id}');
        }
      }
    } catch (e) {
      print('Error deleting test data: $e');
    }
  }

  // 모든 라이드 상태를 한 번에 확인하는 함수
  Future<void> _checkAllRidesStatus() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      print('모든 라이드 상태 확인 시작');

      // 히스토리에서 '드라이버의 수락을 기다리는 중' 상태인 항목만 가져오기
      final pendingHistoryQuery =
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('history')
              .where('status', isEqualTo: '드라이버의 수락을 기다리는 중')
              .get();

      print('업데이트가 필요한 라이드 수: ${pendingHistoryQuery.docs.length}');

      if (pendingHistoryQuery.docs.isEmpty) return;

      // 해당 항목들의 채팅방 상태 확인 및 업데이트
      for (var doc in pendingHistoryQuery.docs) {
        final data = doc.data();
        if (data.containsKey('tripId')) {
          await _checkRideStatus(data, doc.reference);
        }
      }
    } catch (e) {
      print('모든 라이드 상태 확인 중 오류: $e');
    }
  }

  // 새로운 메서드: psuToAirport와 airportToPsu 여정 로드
  Future<void> _loadTrips() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // psuToAirport 여정 로드
      final psuToAirportSnapshot =
          await _firestore
              .collection('psuToAirport')
              .where('members', arrayContains: currentUser.uid)
              .get();

      // airportToPsu 여정 로드
      final airportToPsuSnapshot =
          await _firestore
              .collection('airportToPsu')
              .where('members', arrayContains: currentUser.uid)
              .get();

      setState(() {
        _psuToAirportTrips =
            psuToAirportSnapshot.docs
                .map(
                  (doc) => {
                    ...doc.data(),
                    'id': doc.id,
                    'collection': 'psuToAirport',
                  },
                )
                .toList();

        _airportToPsuTrips =
            airportToPsuSnapshot.docs
                .map(
                  (doc) => {
                    ...doc.data(),
                    'id': doc.id,
                    'collection': 'airportToPsu',
                  },
                )
                .toList();
      });

      print('PSU → Airport 여정 수: ${_psuToAirportTrips.length}');
      print('Airport → PSU 여정 수: ${_airportToPsuTrips.length}');
    } catch (e) {
      print('여정 로드 중 오류 발생: $e');
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      if (index != _selectedIndex) {
        if (index == 0) {
          // Home 탭으로 이동
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder:
                  (context, animation, secondaryAnimation) => HomePage(),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ),
          );
        } else if (index == 2) {
          // Chat 탭으로 이동
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder:
                  (context, animation, secondaryAnimation) => ChatPage(),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ),
          );
        } else if (index == 3) {
          // Profile 탭으로 이동
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder:
                  (context, animation, secondaryAnimation) => SettingsPage(),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ),
          );
        }
        _selectedIndex = index;
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 화면에 나타날 때마다 자동으로 상태 확인
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAllRidesStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final backgroundColor = isDarkMode ? Color(0xFF000000) : Color(0xFFF2F2F7);
    final cardColor = isDarkMode ? Color(0xFF1C1C1E) : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        title: Text(
          'app.history.title'.tr(),
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: textColor),
            onPressed: () {
              setState(() {
                _loadTrips();
              });
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadTrips,
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // PSU → Airport 여정
                if (_psuToAirportTrips.isNotEmpty) ...[
                  Padding(
                    padding: EdgeInsets.only(left: 16, bottom: 16),
                    child: Text(
                      'app.history.psu_to_airport'.tr(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : Colors.black87,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: _psuToAirportTrips.length,
                    itemBuilder: (context, index) {
                      final trip = _psuToAirportTrips[index];
                      final driverAccepted = trip['driver_accepted'] ?? false;
                      final status = driverAccepted ? '확정됨' : '대기중';
                      return _buildModernTripCard(
                        context,
                        trip['pickup_info']['address'] ?? 'PSU',
                        trip['destination_info']['address'] ?? 'Airport',
                        trip['ride_date']?.toDate(),
                        status,
                        cardColor,
                        textColor,
                      );
                    },
                  ),
                  SizedBox(height: 32),
                ],

                // Airport → PSU 여정
                if (_airportToPsuTrips.isNotEmpty) ...[
                  Padding(
                    padding: EdgeInsets.only(left: 16, bottom: 16),
                    child: Text(
                      'app.history.airport_to_psu'.tr(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : Colors.black87,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: _airportToPsuTrips.length,
                    itemBuilder: (context, index) {
                      final trip = _airportToPsuTrips[index];
                      final driverAccepted = trip['driver_accepted'] ?? false;
                      final status = driverAccepted ? '확정됨' : '대기중';
                      return _buildModernTripCard(
                        context,
                        trip['pickup_info']['address'] ?? 'Airport',
                        trip['destination_info']['address'] ?? 'PSU',
                        trip['ride_date']?.toDate(),
                        status,
                        cardColor,
                        textColor,
                      );
                    },
                  ),
                ],

                // 여정이 없는 경우 메시지 표시
                if (_psuToAirportTrips.isEmpty && _airportToPsuTrips.isEmpty)
                  Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: Column(
                        children: [
                          Icon(
                            Icons.history,
                            size: 70,
                            color:
                                isDarkMode
                                    ? Colors.grey[700]
                                    : Colors.grey[300],
                          ),
                          SizedBox(height: 20),
                          Text(
                            'app.history.no_history'.tr(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color:
                                  isDarkMode
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: ''),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: isDarkMode ? Colors.white : Colors.blue,
        unselectedItemColor: isDarkMode ? Colors.grey[600] : Colors.grey,
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        type: BottomNavigationBarType.fixed,
        onTap: _onItemTapped,
      ),
    );
  }

  // 모던한 디자인의 여정 카드 위젯
  Widget _buildModernTripCard(
    BuildContext context,
    String pickup,
    String destination,
    DateTime? rideDate,
    String status,
    Color cardColor,
    Color textColor,
  ) {
    final driverAccepted = status == '확정됨';
    final updatedStatus =
        driverAccepted
            ? 'app.history.status.accepted'.tr()
            : 'app.history.status.pending'.tr();
    final statusColor = _getStatusColor(updatedStatus);
    final isCancelled = status == '취소됨';

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상태 표시
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                updatedStatus,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
            SizedBox(height: 16),

            // 경로 표시 - 세로 레이아웃으로 변경
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 출발지
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'app.history.pickup'.tr(),
                      style: TextStyle(
                        fontSize: 12,
                        color: textColor.withOpacity(0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      pickup,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ],
                ),

                // 화살표
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Icon(
                    Icons.arrow_downward,
                    color: textColor.withOpacity(0.5),
                    size: 20,
                  ),
                ),

                // 도착지
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'app.history.dropoff'.tr(),
                      style: TextStyle(
                        fontSize: 12,
                        color: textColor.withOpacity(0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      destination,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            SizedBox(height: 16),
            Divider(color: textColor.withOpacity(0.1), height: 1),
            SizedBox(height: 12),

            // 날짜 정보
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: textColor.withOpacity(0.6),
                ),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    rideDate != null
                        ? _formatDate(rideDate)
                        : 'app.history.date'.tr(),
                    style: TextStyle(
                      fontSize: 14,
                      color: textColor.withOpacity(0.8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusText(String status) {
    if (status == '확정됨') {
      return '확정됨';
    } else if (status == '대기중') {
      return '대기중';
    } else if (status == '드라이버의 수락을 기다리는 중') {
      return '대기중';
    }
    return status;
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
      case '확정됨':
        return Colors.green;
      case 'completed':
      case '완료됨':
        return Colors.green;
      case 'pending':
      case '대기중':
        return Colors.orange;
      case 'canceled':
      case 'cancelled':
      case '취소됨':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Icon _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
      case '확정됨':
        return Icon(Icons.check_circle, color: Colors.green, size: 12);
      case 'completed':
      case '완료됨':
        return Icon(Icons.done, color: Colors.green, size: 12);
      case 'pending':
      case '대기중':
        return Icon(Icons.schedule, color: Colors.orange, size: 12);
      case 'canceled':
      case 'cancelled':
      case '취소됨':
        return Icon(Icons.cancel, color: Colors.red, size: 12);
      default:
        return Icon(Icons.help_outline, color: Colors.grey, size: 12);
    }
  }

  // 추가: 채팅방 상태를 확인하여 히스토리 상태 업데이트
  Future<void> _checkRideStatus(
    Map<String, dynamic> tripData,
    DocumentReference historyRef,
  ) async {
    try {
      final tripId = tripData['tripId'];
      final collection = tripData['collection'];

      if (tripId == null || collection == null) {
        print('tripId 또는 collection이 비어있습니다');
        return;
      }

      print('채팅방 상태 확인 중: $tripId');

      // 해당 tripId가 속한 채팅방 컬렉션 찾기
      final chatRoomDoc =
          await _firestore.collection(collection).doc(tripId).get();

      if (chatRoomDoc.exists) {
        final chatRoomData = chatRoomDoc.data() as Map<String, dynamic>;
        final driverAccepted = chatRoomData['driver_accepted'] ?? false;
        final status = driverAccepted ? '확정됨' : '대기중';

        print('채팅방 찾음: driverAccepted=$driverAccepted');

        await historyRef.update({'status': status});

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('라이드 상태가 업데이트되었습니다: $status'),
            backgroundColor: _getStatusColor(status),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        print('해당 채팅방을 찾을 수 없거나 드라이버가 아직 수락하지 않았습니다.');
      }
    } catch (e) {
      print('채팅방 상태 확인 중 오류: $e');
    }
  }
}
