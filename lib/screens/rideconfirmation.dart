import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RideConfirmation extends StatefulWidget {
  final String? rideId;
  final String? direction;

  const RideConfirmation({super.key, this.rideId, this.direction});

  @override
  State<RideConfirmation> createState() => _RideConfirmationState();
}

class _RideConfirmationState extends State<RideConfirmation> {
  void _updateMemberCount() async {
    if (widget.rideId == null) return;

    try {
      // 채팅방의 모든 유저 정보 가져오기
      final usersSnapshot =
          await FirebaseFirestore.instance
              .collection(
                widget.direction == 'psuToAirport'
                    ? 'psuToAirport'
                    : 'airportToPsu',
              )
              .doc(widget.rideId)
              .collection('users')
              .get();

      // member_count 가져오기
      final rideDoc =
          await FirebaseFirestore.instance
              .collection(
                widget.direction == 'psuToAirport'
                    ? 'psuToAirport'
                    : 'airportToPsu',
              )
              .doc(widget.rideId)
              .get();

      // 모든 유저의 user_companion_count 합계 계산
      num totalCompanionCount = 0;
      print('===== 디버그 정보 =====');
      print('채팅방 전체 유저 수: ${usersSnapshot.docs.length}');

      // 채팅방의 user_companion_counts 맵에서 값을 가져옴
      final userCompanionCounts =
          rideDoc.data()?['user_companion_counts'] ?? {};
      for (var userId in userCompanionCounts.keys) {
        final companionCount = userCompanionCounts[userId] ?? 0;
        print('유저 ID: $userId');
        print('- user_companion_count: $companionCount');
        totalCompanionCount += companionCount;
      }
      print('총 동반자 수 합계: $totalCompanionCount');

      // 현재 destination_info 상태 확인
      final currentDestInfo = rideDoc.data()?['destination_info'];
      print('현재 destination_info:');
      print(currentDestInfo);

      // member_count 업데이트 (기존 member_count + 모든 유저의 user_companion_count)
      final updatedMemberCount =
          usersSnapshot.docs.length + totalCompanionCount;
      print('업데이트될 member_count: $updatedMemberCount');

      // Firestore 문서 업데이트
      final destinationInfo = Map<String, dynamic>.from(
        rideDoc.data()?['destination_info'] ?? {},
      );
      destinationInfo['member_count'] = updatedMemberCount;

      print('업데이트할 destination_info:');
      print(destinationInfo);

      await FirebaseFirestore.instance
          .collection(
            widget.direction == 'psuToAirport'
                ? 'psuToAirport'
                : 'airportToPsu',
          )
          .doc(widget.rideId)
          .update({'destination_info': destinationInfo});

      print('인원수 업데이트 완료');
      print('==================');
    } catch (e) {
      print('인원수 업데이트 중 오류 발생: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _setupUserListener();
    _updateMemberCount(); // 초기 인원수 계산
  }

  void _setupUserListener() {
    if (widget.rideId == null) return;

    // users 컬렉션의 변경사항을 실시간으로 감지
    FirebaseFirestore.instance
        .collection(
          widget.direction == 'psuToAirport' ? 'psuToAirport' : 'airportToPsu',
        )
        .doc(widget.rideId)
        .collection('users')
        .snapshots()
        .listen((snapshot) {
          // 유저 정보가 변경될 때마다 인원수 업데이트
          _updateMemberCount();
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('라이드 확인')),
      body: Center(child: Text('라이드 ID: ${widget.rideId}')),
    );
  }
}
