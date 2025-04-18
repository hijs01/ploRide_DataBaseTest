import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cabrider/screens/homepage.dart';
import 'package:cabrider/screens/chat_page.dart';
import 'package:cabrider/screens/settings_page.dart';

class HistoryPage extends StatefulWidget {
  static const String id = 'history';

  const HistoryPage({Key? key}) : super(key: key);

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool isLoading = true;
  int _selectedIndex = 1; // 히스토리 탭이 선택됨
  bool _isRefreshing = false; // 새로고침 상태 추가

  @override
  void initState() {
    super.initState();
    print('HistoryPage initialized');
    _checkUserData();
    _deleteTestData(); // 테스트 데이터 삭제
    _checkAllRidesStatus(); // 모든 라이드 상태 확인
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
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      appBar: AppBar(
        title: Text('이용 내역'),
        automaticallyImplyLeading: false,
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(
          color: isDarkMode ? Colors.white : Colors.black,
        ),
        titleTextStyle: TextStyle(
          color: isDarkMode ? Colors.white : Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),

        actions: [
          // 새로고침 버튼 추가
          _isRefreshing
              ? Padding(
                padding: const EdgeInsets.all(10.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.0,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isDarkMode ? Colors.white : Colors.blue,
                    ),
                  ),
                ),
              )
              : IconButton(
                icon: Icon(
                  Icons.refresh,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
                onPressed: _refreshHistory,
              ),
        ],
      ),
      body:
          currentUser == null
              ? Center(
                child: Text(
                  '로그인이 필요합니다',
                  style: TextStyle(
                    fontSize: 18,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),

              )
              : StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(currentUser.uid)
                        .collection('history')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        '오류가 발생했습니다',
                        style: TextStyle(
                          fontSize: 18,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  final userTrips = snapshot.data?.docs ?? [];

                  print('User trips count: ${userTrips.length}');

                  if (userTrips.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history,
                            size: 64,
                            color:
                                isDarkMode
                                    ? Colors.grey[600]
                                    : Colors.grey[400],
                          ),
                          SizedBox(height: 16),
                          Text(
                            '이용 내역이 없습니다',
                            style: TextStyle(
                              fontSize: 18,
                              color:
                                  isDarkMode
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: userTrips.length,
                    itemBuilder: (context, index) {
                      final tripData =
                          userTrips[index].data() as Map<String, dynamic>;
                      print(
                        'Building trip item $index: $tripData',
                      ); // 디버그 로그 추가

                      final pickup = tripData['pickup'] ?? '출발지 정보 없음';
                      final destination =
                          tripData['destination'] ?? '도착지 정보 없음';
                      final status = tripData['status'] ?? '상태 정보 없음';
                      final timestamp = tripData['timestamp'] as Timestamp?;
                      final date = timestamp?.toDate() ?? DateTime.now();

                      print(
                        'Trip details - Pickup: $pickup, Destination: $destination, Status: $status',
                      ); // 디버그 로그 추가

                      // 히스토리 데이터는 한 번만 저장
                      // if (index == 0) {
                      //   _saveToHistory(tripData);
                      // }

                      return Container(
                        margin: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isDarkMode ? Color(0xFF1E1E1E) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  isDarkMode
                                      ? Colors.black12
                                      : Colors.grey.withOpacity(0.1),
                              blurRadius: 10,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: EdgeInsets.all(16),
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    color: Colors.red,
                                    size: 16,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      pickup,
                                      style: TextStyle(
                                        color:
                                            isDarkMode
                                                ? Colors.white
                                                : Colors.black,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.flag,
                                    color: Colors.green,
                                    size: 16,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      destination,
                                      style: TextStyle(
                                        color:
                                            isDarkMode
                                                ? Colors.white
                                                : Colors.black,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${date.year}년 ${date.month}월 ${date.day}일 ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    color:
                                        isDarkMode
                                            ? Colors.grey[400]
                                            : Colors.grey[600],
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(
                                      status,
                                    ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      color: _getStatusColor(status),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          onTap: () {
                            // 상태가 '드라이버의 수락을 기다리는 중'인 경우에만 상태 확인
                            if (status == '드라이버의 수락을 기다리는 중' &&
                                tripData.containsKey('tripId')) {
                              _checkRideStatus(
                                tripData,
                                userTrips[index].reference,
                              );
                            }
                          },
                        ),
                      );
                    },
                  );
                },
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'canceled':
        return Colors.red;
      case '확정됨':
        return Colors.green;
      case '드라이버의 수락을 기다리는 중':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  // 추가: 채팅방 상태를 확인하여 히스토리 상태 업데이트
  Future<void> _checkRideStatus(
    Map<String, dynamic> tripData,
    DocumentReference historyRef,
  ) async {
    try {
      final tripId = tripData['tripId'];
      if (tripId == null || tripId.isEmpty) {
        print('tripId가 비어있습니다');
        return;
      }

      print('채팅방 상태 확인 중: $tripId');

      // 해당 tripId가 속한 채팅방 컬렉션 찾기
      final collections = ['psuToAirport', 'airportToPsu', 'generalRides'];

      for (var collection in collections) {
        try {
          final chatDoc =
              await _firestore.collection(collection).doc(tripId).get();

          if (chatDoc.exists) {
            final chatData = chatDoc.data() as Map<String, dynamic>;
            final bool driverAccepted = chatData['driver_accepted'] ?? false;

            print('채팅방 찾음 ($collection): driverAccepted=$driverAccepted');

            if (driverAccepted) {
              // 히스토리 상태 업데이트
              await historyRef.update({'status': '확정됨'});

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('라이드 상태가 업데이트되었습니다: 확정됨'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
              return;
            }
          }
        } catch (e) {
          print('$collection 컬렉션 확인 중 오류: $e');
        }
      }

      print('해당 채팅방을 찾을 수 없거나 드라이버가 아직 수락하지 않았습니다.');
    } catch (e) {
      print('채팅방 상태 확인 중 오류: $e');
    }
  }

  // 이용 내역 새로고침 함수
  Future<void> _refreshHistory() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      // 이용 내역 상태 확인
      await _checkAllRidesStatus();

      // 새로고침 성공 메시지
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('이용 내역이 업데이트되었습니다'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('새로고침 중 오류 발생: $e');

      // 오류 메시지
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('업데이트 중 오류가 발생했습니다'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }
}
