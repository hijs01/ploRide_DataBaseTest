import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cabrider/screens/homepage.dart';
import 'package:cabrider/screens/chat_page.dart';
import 'package:cabrider/screens/settings_page.dart';
import 'package:flutter/cupertino.dart';

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

  @override
  void initState() {
    super.initState();
    print('HistoryPage initialized');
    _checkUserData();
    _deleteTestData(); // 테스트 데이터 삭제
    _updateHistoryData(); // 히스토리 데이터 업데이트
    _cleanupInvalidHistory(); // 유효하지 않은 히스토리 데이터 삭제
    _updateCompletedTrips(); // 완료된 여행 상태 업데이트
  }

  Future<void> _checkUserData() async {
    final currentUser = _auth.currentUser;
    print('Current user: ${currentUser?.uid}');
    
    if (currentUser != null) {
      // 사용자의 히스토리 데이터 확인
      final historySnapshot = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('history')
          .get();
      
      print('History count: ${historySnapshot.docs.length}');
      
      // psuToAirport 데이터 확인 - driver_accepted가 true이거나 completed인 모든 항목
      final psuToAirportSnapshot = await _firestore
          .collection('psuToAirport')
          .where('status', whereIn: ['completed', 'accepted'])
          .get();
      
      print('psuToAirport count: ${psuToAirportSnapshot.docs.length}');
      
      // driver_accepted가 true이거나 completed인 모든 항목을 히스토리에 추가
      for (var trip in psuToAirportSnapshot.docs) {
        final tripData = trip.data();
        final tripId = trip.id;
        final status = tripData['status'] ?? 'accepted';
        
        // 이미 히스토리에 있는지 확인
        final existingHistory = await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .collection('history')
            .where('tripId', isEqualTo: tripId)
            .get();
            
        if (existingHistory.docs.isEmpty) {
          // 히스토리에 추가
          await _firestore
              .collection('users')
              .doc(currentUser.uid)
              .collection('history')
              .add({
            'tripId': tripId,
            'pickup': tripData['pickup_info']?['address'] ?? '',
            'destination': tripData['destination_info']?['address'] ?? '',
            'status': status,
            'timestamp': tripData['timestamp'] ?? FieldValue.serverTimestamp(),
            'driver_accepted': tripData['driver_accepted'] ?? false,
          });
          
          print('Added trip to history: $tripId with status: $status');
        }
      }
    }
  }

  Future<void> _deleteTestData() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // psuToAirport 컬렉션에서 테스트 데이터 삭제
        final testDataQuery = await _firestore
            .collection('psuToAirport')
            .where('pickup_info.address', isEqualTo: 'PSU 캠퍼스')
            .where('destination_info.address', isEqualTo: '인천국제공항')
            .get();
        
        for (var doc in testDataQuery.docs) {
          await doc.reference.delete();
          print('Deleted test data document: ${doc.id}');
        }
        
        // users 컬렉션의 history에서 테스트 데이터 삭제
        final historyQuery = await _firestore
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

  // 기존 히스토리 데이터에 ride_date 필드가 없는 경우 업데이트
  Future<void> _updateHistoryData() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // 사용자의 히스토리 데이터 가져오기
        final historySnapshot = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('history')
            .get();
        
        for (var doc in historySnapshot.docs) {
          final data = doc.data();
          
          // ride_date 필드가 없는 경우 업데이트
          if (!data.containsKey('ride_date')) {
            final tripId = data['tripId'] as String?;
            
            if (tripId != null) {
              // psuToAirport 컬렉션에서 해당 trip 정보 가져오기
              final tripDoc = await _firestore
                  .collection('psuToAirport')
                  .doc(tripId)
                  .get();
              
              if (tripDoc.exists) {
                final tripData = tripDoc.data() as Map<String, dynamic>;
                final rideDate = tripData['ride_date_timestamp'] ?? tripData['ride_date'];
                
                if (rideDate != null) {
                  // 히스토리 데이터 업데이트
                  await _firestore
                      .collection('users')
                      .doc(user.uid)
                      .collection('history')
                      .doc(doc.id)
                      .update({'ride_date': rideDate});
                  
                  print('Updated history document ${doc.id} with ride_date: $rideDate');
                }
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error updating history data: $e');
    }
  }

  // Firestore에 없는 여행들을 히스토리에서 삭제
  Future<void> _cleanupInvalidHistory() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // 사용자의 히스토리 데이터 가져오기
        final historySnapshot = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('history')
            .get();
        
        for (var doc in historySnapshot.docs) {
          final data = doc.data();
          final tripId = data['tripId'] as String?;
          
          if (tripId != null) {
            // psuToAirport 컬렉션에서 해당 trip 정보 가져오기
            final tripDoc = await _firestore
                .collection('psuToAirport')
                .doc(tripId)
                .get();
            
            // trip이 존재하지 않으면 히스토리에서 삭제
            if (!tripDoc.exists) {
              await _firestore
                  .collection('users')
                  .doc(user.uid)
                  .collection('history')
                  .doc(doc.id)
                  .delete();
              
              print('Deleted invalid history document ${doc.id} with tripId: $tripId');
            }
          }
        }
      }
    } catch (e) {
      print('Error cleaning up invalid history: $e');
    }
  }

  // ride_date가 24시간 지나면 psuToAirport 컬렉션의 status를 "completed"로 변경
  Future<void> _updateCompletedTrips() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // 현재 시간 가져오기
        final now = DateTime.now();
        final oneDayAgo = now.subtract(Duration(days: 1));
        
        // psuToAirport 컬렉션에서 ride_date가 24시간 이상 지난 항목 가져오기
        final querySnapshot = await _firestore
            .collection('psuToAirport')
            .where('ride_date_timestamp', isLessThan: Timestamp.fromDate(oneDayAgo))
            .where('status', isEqualTo: 'accepted')
            .get();
        
        // 각 항목의 status를 "completed"로 업데이트
        for (var doc in querySnapshot.docs) {
          await _firestore
              .collection('psuToAirport')
              .doc(doc.id)
              .update({'status': 'completed'});
          
          print('Updated trip ${doc.id} status to completed');
          
          // 히스토리 데이터도 업데이트
          final historyQuery = await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('history')
              .where('tripId', isEqualTo: doc.id)
              .get();
          
          for (var historyDoc in historyQuery.docs) {
            await _firestore
                .collection('users')
                .doc(user.uid)
                .collection('history')
                .doc(historyDoc.id)
                .update({'status': 'completed'});
            
            print('Updated history document ${historyDoc.id} status to completed');
          }
        }
      }
    } catch (e) {
      print('Error updating completed trips: $e');
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
  Widget build(BuildContext context) {
    final isDarkMode = MediaQuery.of(context).platformBrightness == Brightness.dark;
    final currentUser = FirebaseAuth.instance.currentUser;

    return CupertinoPageScaffold(
      backgroundColor: isDarkMode ? CupertinoColors.black : CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text('이용 내역', style: TextStyle(color: CupertinoColors.white)),
        backgroundColor: isDarkMode ? CupertinoColors.black : CupertinoColors.systemBackground,
        border: null,
        automaticallyImplyLeading: false,
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: currentUser == null
                  ? Center(
                      child: Text(
                        '로그인이 필요합니다',
                        style: TextStyle(
                          fontSize: 18,
                          color: CupertinoColors.black,
                        ),
                      ),
                    )
                  : StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
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
                                color: isDarkMode ? CupertinoColors.white : CupertinoColors.black,
                              ),
                            ),
                          );
                        }

                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Center(
                            child: CupertinoActivityIndicator(),
                          );
                        }

                        final userTrips = snapshot.data?.docs ?? [];
                        
                        print('User trips count: ${userTrips.length}');
                        
                        if (userTrips.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  CupertinoIcons.clock,
                                  size: 64,
                                  color: isDarkMode ? CupertinoColors.systemGrey : CupertinoColors.systemGrey2,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  '이용 내역이 없습니다',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: CupertinoColors.black,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          itemCount: userTrips.length,
                          itemBuilder: (context, index) {
                            final tripData = userTrips[index].data() as Map<String, dynamic>;
                            print('Building trip item $index: $tripData'); // 디버그 로그 추가
                            
                            final pickup = tripData['pickup'] ?? '출발지 정보 없음';
                            final destination = tripData['destination'] ?? '도착지 정보 없음';
                            final status = tripData['status'] ?? '상태 정보 없음';
                            final timestamp = tripData['timestamp'] as Timestamp?;
                            final date = timestamp?.toDate() ?? DateTime.now();

                            // 도착 날짜 정보 가져오기
                            final rideDate = tripData['ride_date'] as Timestamp?;
                            final rideDateTime = rideDate?.toDate() ?? date;
                            
                            // 현재 날짜와 도착 날짜 비교
                            final now = DateTime.now();
                            final isPastRideDate = now.isAfter(rideDateTime);
                            
                            // 상태 결정 로직
                            String displayStatus = status;
                            if (status == 'accepted') {
                              if (isPastRideDate) {
                                displayStatus = 'completed';
                              }
                            } else if (status == 'canceled') {
                              displayStatus = 'canceled';
                            }

                            print('Trip details - Pickup: $pickup, Destination: $destination, Status: $status, Display Status: $displayStatus, Ride Date: $rideDateTime'); // 디버그 로그 추가

                            // 히스토리 데이터는 한 번만 저장
                            if (index == 0) {
                              _saveToHistory(tripData);
                            }

                            return Container(
                              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDarkMode ? CupertinoColors.black : CupertinoColors.systemGroupedBackground,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: CupertinoColors.white,
                                  width: 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isDarkMode ? CupertinoColors.black.withOpacity(0.1) : CupertinoColors.systemGrey5.withOpacity(0.5),
                                    blurRadius: 10,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: CupertinoListTile(
                                  padding: EdgeInsets.all(16),
                                  title: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            CupertinoIcons.location_solid,
                                            color: CupertinoColors.systemRed,
                                            size: 16,
                                          ),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              pickup,
                                              style: TextStyle(
                                                color: CupertinoColors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(
                                            CupertinoIcons.flag_fill,
                                            color: CupertinoColors.systemGreen,
                                            size: 16,
                                          ),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              destination,
                                              style: TextStyle(
                                                color: CupertinoColors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
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
                                          '${rideDateTime.year}년 ${rideDateTime.month}월 ${rideDateTime.day}일 ${rideDateTime.hour}:${rideDateTime.minute.toString().padLeft(2, '0')}',
                                          style: TextStyle(
                                            color: CupertinoColors.white,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(displayStatus).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            displayStatus,
                                            style: TextStyle(
                                              color: _getStatusColor(displayStatus),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
            Container(
              decoration: BoxDecoration(
                color: isDarkMode ? CupertinoColors.black : CupertinoColors.systemBackground,
                border: Border(
                  top: BorderSide(
                    color: isDarkMode ? CupertinoColors.systemGrey6 : CupertinoColors.systemGrey5,
                    width: 0.5,
                  ),
                ),
              ),
              child: BottomNavigationBar(
                currentIndex: _selectedIndex,
                selectedItemColor: isDarkMode ? CupertinoColors.white : CupertinoColors.activeBlue,
                unselectedItemColor: isDarkMode ? CupertinoColors.systemGrey : CupertinoColors.systemGrey2,
                backgroundColor: isDarkMode ? CupertinoColors.black : CupertinoColors.systemBackground,
                showSelectedLabels: true,
                showUnselectedLabels: true,
                type: BottomNavigationBarType.fixed,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home),
                    label: '홈',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.history),
                    label: '히스토리',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.chat),
                    label: '채팅',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.person),
                    label: '프로필',
                  ),
                ],
                onTap: _onItemTapped,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return CupertinoColors.activeBlue;
      case 'completed':
        return CupertinoColors.systemGreen;
      case 'pending':
        return CupertinoColors.systemGrey;
      case 'canceled':
        return CupertinoColors.systemRed;
      default:
        return CupertinoColors.systemGrey;
    }
  }

  Future<void> _saveToHistory(Map<String, dynamic> tripData) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Check if history entry already exists
        final historyQuery = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('history')
            .where('tripId', isEqualTo: tripData['tripId'])
            .get();

        if (historyQuery.docs.isEmpty) {
          // pickup_info와 destination_info에서 address 정보 추출
          final pickupInfo = tripData['pickup_info'] as Map<String, dynamic>?;
          final destinationInfo = tripData['destination_info'] as Map<String, dynamic>?;
          
          print('Saving history with pickup: ${pickupInfo?['address']}, destination: ${destinationInfo?['address']}');
          
          // Create new history entry
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('history')
              .add({
            'pickup': pickupInfo?['address'] ?? '',
            'destination': destinationInfo?['address'] ?? '',
            'status': tripData['status'] ?? '',
            'timestamp': tripData['timestamp'] ?? FieldValue.serverTimestamp(),
            'tripId': tripData['tripId'] ?? '',
            'ride_date': tripData['ride_date_timestamp'] ?? tripData['ride_date'] ?? FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      print('Error saving to history: $e');
    }
  }

  Future<void> _loadHistory() async {
    setState(() {
      isLoading = true;
    });

    try {
      if (_auth.currentUser == null) {
        setState(() {
          isLoading = false;
        });
        return;
      }

      // 현재 시간 가져오기
      final now = DateTime.now();

      // 사용자의 히스토리 컬렉션에서 데이터 가져오기
      final querySnapshot = await _firestore
          .collection('users')
          .doc(_auth.currentUser?.uid)
          .collection('history')
          .orderBy('timestamp', descending: true)
          .get();

      List<Map<String, dynamic>> history = [];

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final tripId = data['tripId'] as String?;
        final timestamp = data['timestamp'] as Timestamp?;
        final rideDate = data['rideDate'] as Timestamp?;

        // 여행 날짜가 지났는지 확인
        bool isCompleted = false;
        if (rideDate != null) {
          final rideDateTime = rideDate.toDate();
          isCompleted = rideDateTime.isBefore(now);
        }

        // 상태 업데이트
        String status = isCompleted ? 'completed' : (data['status'] ?? 'pending');

        // 상태가 변경되었다면 Firestore 업데이트
        if (status != data['status']) {
          await _firestore
              .collection('users')
              .doc(_auth.currentUser?.uid)
              .collection('history')
              .doc(doc.id)
              .update({'status': status});
        }

        // 히스토리 항목 구성
        Map<String, dynamic> historyItem = {
          'id': doc.id,
          'tripId': tripId,
          'pickup': data['pickup'] ?? '출발지',
          'destination': data['destination'] ?? '목적지',
          'status': status,
          'timestamp': timestamp ?? Timestamp.now(),
          'rideDate': rideDate,
        };

        history.add(historyItem);
      }

      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('히스토리 로드 오류: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }
} 