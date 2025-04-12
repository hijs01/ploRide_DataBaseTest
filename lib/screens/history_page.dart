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

  @override
  void initState() {
    super.initState();
    print('HistoryPage initialized');
    _checkUserData();
    _deleteTestData(); // 테스트 데이터 삭제
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
      
      // psuToAirport 데이터 확인
      final psuToAirportSnapshot = await _firestore
          .collection('psuToAirport')
          .get();
      
      print('psuToAirport count: ${psuToAirportSnapshot.docs.length}');
      
      // 현재 사용자가 멤버로 포함된 문서 확인
      final userTrips = psuToAirportSnapshot.docs.where((doc) {
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
    final currentUser = _auth.currentUser;
    
    print('Building HistoryPage for user: ${currentUser?.uid}');

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        title: Text(
          '이용 내역',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('psuToAirport')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            print('Error loading history: ${snapshot.error}');
            return Center(
              child: Text(
                '오류가 발생했습니다',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            print('No data in psuToAirport collection');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: 64,
                    color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                  ),
                  SizedBox(height: 16),
                  Text(
                    '이용 내역이 없습니다',
                    style: TextStyle(
                      fontSize: 18,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          print('Total documents in psuToAirport: ${snapshot.data!.docs.length}');
          
          // 현재 사용자의 여행만 필터링하고 시간순 정렬
          final userTrips = snapshot.data!.docs
              .where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final members = data['members'] as List<dynamic>?;
                final isUserTrip = members?.contains(currentUser?.uid) ?? false;
                print('Document ${doc.id}: members=${members}, isUserTrip=$isUserTrip');
                return isUserTrip;
              })
              .toList()
            ..sort((a, b) {
              final timestampA = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
              final timestampB = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
              
              if (timestampA == null) return 1;
              if (timestampB == null) return -1;
              
              return timestampB.compareTo(timestampA); // 내림차순 정렬
            });
          
          print('Filtered user trips count: ${userTrips.length}');
          
          if (userTrips.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: 64,
                    color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                  ),
                  SizedBox(height: 16),
                  Text(
                    '이용 내역이 없습니다',
                    style: TextStyle(
                      fontSize: 18,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
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
              
              // pickup_info와 destination_info에서 address 정보 추출
              final pickupInfo = tripData['pickup_info'] as Map<String, dynamic>?;
              final destinationInfo = tripData['destination_info'] as Map<String, dynamic>?;
              
              final pickup = pickupInfo?['address'] ?? '출발지 정보 없음';
              final destination = destinationInfo?['address'] ?? '도착지 정보 없음';
              final status = tripData['status'] ?? '상태 정보 없음';
              final timestamp = tripData['timestamp'] as Timestamp?;
              final date = timestamp?.toDate() ?? DateTime.now();

              print('Trip details - Pickup: $pickup, Destination: $destination, Status: $status'); // 디버그 로그 추가

              // 히스토리 데이터는 한 번만 저장
              if (index == 0) {
                _saveToHistory(tripData);
              }

              return Container(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isDarkMode ? Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: isDarkMode ? Colors.black12 : Colors.grey.withOpacity(0.1),
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
                                color: isDarkMode ? Colors.white : Colors.black,
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
                                color: isDarkMode ? Colors.white : Colors.black,
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
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(status).withOpacity(0.1),
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
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: '히스토리'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: '채팅'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '프로필'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: isDarkMode ? Colors.white : Colors.blue,
        unselectedItemColor: isDarkMode ? Colors.grey[600] : Colors.grey,
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        showSelectedLabels: true,
        showUnselectedLabels: true,
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
        return Colors.grey;
      case 'canceled':
        return Colors.red;
      default:
        return Colors.grey;
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
          });
        }
      }
    } catch (e) {
      print('Error saving to history: $e');
    }
  }
} 