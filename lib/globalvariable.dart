import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:TAGO/datamodels/user.dart';

String mapKey = 'AIzaSyAknGQdA7yAS5SICTW8lOKilEN7FBpNS-U';
// TODO: 아래 값을 Firebase 콘솔에서 가져온 실제 서버 키로 교체하세요
String serverKey = '425631894947'; // FCM 발신자 ID
String firebaseProjectId = 'geetaxi-aa379'; // Firebase 프로젝트 ID

// FCM 서버 키
const String fcmServerKey = '425631894947'; // FCM 발신자 ID

final CameraPosition googlePlex = CameraPosition(
  target: LatLng(37.42796133580664, -122.085749655962),
  zoom: 14.4746,
);

auth.User? currentFirebaseUser;
User? currentUserInfo;
