import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cabrider/screens/loginpage.dart';
import 'package:cabrider/screens/registrationpage.dart';
import 'package:cabrider/screens/mainpage.dart';
import 'package:cabrider/screens/searchpage.dart';
import 'package:cabrider/screens/homepage.dart';
import 'package:cabrider/screens/settings_page.dart';
import 'package:cabrider/screens/taxi_info_page.dart';
import 'package:cabrider/screens/rideconfirmation/rideconfirmation_page.dart';
import 'package:cabrider/screens/email_verification_page.dart';
import 'package:cabrider/globalvariable.dart';
import 'package:provider/provider.dart';
import 'package:cabrider/dataprovider/appdata.dart';
import 'package:cabrider/helpers/helpermethods.dart';

// 백그라운드 메시지 핸들러
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // 백그라운드 핸들러에서는 Firebase.initializeApp() 호출하지 않음
  print('백그라운드 메시지 처리: ${message.messageId}');
  print('알림 제목: ${message.notification?.title}');
  print('알림 내용: ${message.notification?.body}');
  print('데이터: ${message.data}');
}

// FCM 토큰을 Firebase Database에 저장하는 함수
// Future<void> _updateDriverFcmToken() async {
//   if (currentFirebaseUser != null) {
//     // FCM 토큰 가져오기
//     String? token = await FirebaseMessaging.instance.getToken();
//     if (token != null) {
//       // 토큰 저장
//       DatabaseReference tokenRef = FirebaseDatabase.instance.ref().child(
//         'drivers/${currentFirebaseUser!.uid}/fcm_token',
//       );
//       await tokenRef.set(token);
//       print('드라이버 FCM 토큰 저장 완료: $token');

//       // 토큰 갱신 설정
//       FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
//         tokenRef.set(newToken);
//         print('드라이버 FCM 토큰 갱신됨: $newToken');
//       });
//     }
//   }
// }

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    // Firebase 초기화 - 더 안전한 방식으로 수정
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options:
            Platform.isIOS
                ? const FirebaseOptions(
                  apiKey: 'AIzaSyBbAeoUHY5ptkBe-xR54A45fVnJX7iS3YA',
                  appId: '1:425631894947:ios:e9b63aa2e048a45095de16',
                  messagingSenderId: '425631894947',
                  projectId: 'geetaxi-aa379',
                  databaseURL:
                      'https://geetaxi-aa379-default-rtdb.firebaseio.com',
                  storageBucket: 'geetaxi-aa379.firebasestorage.app',
                  iosClientId: '425631894947-xxxxx.apps.googleusercontent.com',
                )
                : const FirebaseOptions(
                  apiKey: 'AIzaSyAknGQdA7yAS5SICTW8lOKilEN7FBpNS-U',
                  appId: '1:425631894947:android:783ac2ba27d2db6e95de16',
                  messagingSenderId: '425631894947',
                  projectId: 'geetaxi-aa379',
                  databaseURL:
                      'https://geetaxi-aa379-default-rtdb.firebaseio.com',
                  storageBucket: 'geetaxi-aa379.firebasestorage.app',
                ),
      );
    } else {
      Firebase.app(); // 이미 초기화된 앱 인스턴스 사용
    }

    // currentFirebaseUser 초기화
    currentFirebaseUser = FirebaseAuth.instance.currentUser;

    // Firebase 메시징 백그라운드 핸들러 설정
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Firebase 메시징 권한 요청
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('알림 권한이 허용되었습니다');
    } else {
      print('알림 권한이 거부되었습니다');
    }

    // iOS 포그라운드 알림 설정
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

    // FCM 토큰 저장
    if (currentFirebaseUser != null) {
      await HelperMethods.updateDriverFcmToken();
    }

    // 포그라운드 메시지 핸들러 등록
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('포그라운드 메시지 수신:');
      print('제목: ${message.notification?.title}');
      print('내용: ${message.notification?.body}');
      print('데이터: ${message.data}');
    });

    // 알림 클릭 이벤트 처리
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('알림 클릭: ${message.data}');
      // TODO: 알림 클릭 시 특정 화면으로 이동하는 로직 추가
    });
  } catch (e) {
    print('Firebase 초기화 에러: $e');
    // Firebase 초기화 실패 시 currentFirebaseUser를 null로 설정
    currentFirebaseUser = null;
  }

  // Provider로 감싼 앱 실행
  runApp(
    ChangeNotifierProvider(
      create: (context) => AppData(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Brand-Regular',
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      // 로그인 상태에 따라 초기 라우트 설정
      initialRoute: currentFirebaseUser == null ? Loginpage.id : MainPage.id,
      routes: {
        MainPage.id: (context) => MainPage(),
        RegistrationPage.id: (context) => RegistrationPage(),
        Loginpage.id: (context) => Loginpage(),
        SearchPage.id: (context) => SearchPage(),
        HomePage.id: (context) => HomePage(),
        SettingsPage.id: (context) => SettingsPage(),
        TaxiInfoPage.id: (context) => TaxiInfoPage(),
        EmailVerificationPage.id: (context) => EmailVerificationPage(email: ''),
        'rideconfirmation': (context) => RideConfirmationPage(),
      },
    );
  }
}
