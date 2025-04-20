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
import 'package:cabrider/screens/rideconfirmation/rideconfirmation_page.dart';
import 'package:cabrider/screens/email_verification_page.dart';
import 'package:cabrider/screens/chat_room_page.dart';
import 'package:cabrider/globalvariable.dart';
import 'package:provider/provider.dart';
import 'package:cabrider/dataprovider/appdata.dart';
import 'package:cabrider/helpers/helpermethods.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';

// 백그라운드 메시지 핸들러
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('백그라운드 메시지 처리: ${message.messageId}');
  print('알림 제목: ${message.notification?.title}');
  print('알림 내용: ${message.notification?.body}');
  print('데이터: ${message.data}');
}

// FCM 토큰을 Firestore에 저장하는 함수
Future<void> _updateUserFcmToken() async {
  if (currentFirebaseUser != null) {
    try {
      print('FCM 토큰 업데이트 시작...');
      String? token = await FirebaseMessaging.instance.getToken();

      if (token != null) {
        print('새로운 FCM 토큰: $token');

        // users 컬렉션의 현재 사용자 문서
        final userDoc = FirebaseFirestore.instance
            .collection('users')
            .doc(currentFirebaseUser!.uid);

        // 현재 저장된 토큰 확인
        final userData = await userDoc.get();
        final currentToken = userData.data()?['token'];

        if (currentToken != token) {
          print('토큰이 변경되어 업데이트합니다.');
          print('이전 토큰: $currentToken');
          print('새로운 토큰: $token');

          await userDoc.update({
            'token': token,
            'fcm_token': token, // 이전 버전 호환성을 위해 두 필드 모두 업데이트
            'platform': Platform.isIOS ? 'ios' : 'android',
            'last_updated': FieldValue.serverTimestamp(),
          });
          print('FCM 토큰 업데이트 완료');
        } else {
          print('토큰이 동일하여 업데이트하지 않습니다.');
        }
      } else {
        print('FCM 토큰을 가져올 수 없습니다.');
      }
    } catch (e) {
      print('FCM 토큰 업데이트 실패: $e');
    }
  } else {
    print('사용자가 로그인되어 있지 않아 토큰을 업데이트할 수 없습니다.');
  }
}

// iOS 알림 설정 초기화 함수
Future<void> _initializeIOSNotifications() async {
  print('iOS 알림 설정 시작...');

  try {
    // iOS 포그라운드 알림 설정
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

    // 현재 알림 권한 상태 확인
    final initialSettings =
        await FirebaseMessaging.instance.getNotificationSettings();
    print('현재 알림 권한 상태: ${initialSettings.authorizationStatus}');

    if (initialSettings.authorizationStatus ==
        AuthorizationStatus.notDetermined) {
      print('알림 권한 요청 시작...');
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      print('알림 권한 요청 결과:');
      print('- 권한 상태: ${settings.authorizationStatus}');
      print('- alert 허용: ${settings.alert}');
      print('- badge 허용: ${settings.badge}');
      print('- sound 허용: ${settings.sound}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('알림 권한이 허용되었습니다');
        await _updateUserFcmToken();
      }
    } else if (initialSettings.authorizationStatus ==
        AuthorizationStatus.authorized) {
      print('이미 알림 권한이 허용되어 있습니다');
      await _updateUserFcmToken();
    } else {
      print('알림 권한이 거부되었습니다');
      _showNotificationPermissionDialog();
    }
  } catch (e) {
    print('iOS 알림 설정 중 오류 발생: $e');
  }
}

// 알림 권한 요청 다이얼로그
void _showNotificationPermissionDialog() {
  Future.delayed(Duration(seconds: 1), () {
    if (navigatorKey.currentContext != null) {
      showDialog(
        context: navigatorKey.currentContext!,
        builder:
            (context) => AlertDialog(
              title: Text('알림 권한 필요'),
              content: Text('원활한 서비스 이용을 위해 설정에서 알림을 허용해주세요.'),
              actions: [
                TextButton(
                  child: Text('취소'),
                  onPressed: () => Navigator.pop(context),
                ),
                TextButton(
                  child: Text('설정으로 이동'),
                  onPressed: () {
                    Navigator.pop(context);
                    if (Platform.isIOS) {
                      exit(0);
                    }
                  },
                ),
              ],
            ),
      );
    }
  });
}

// Firebase 초기화 함수
Future<void> _initializeFirebase() async {
  print('Firebase 초기화 시작...');

  try {
    // 이미 초기화된 앱이 있는지 확인
    if (Firebase.apps.isNotEmpty) {
      print('기존 Firebase 앱 발견: ${Firebase.apps.length}개');
      final defaultApp = Firebase.app();
      if (defaultApp.name == '[DEFAULT]') {
        print('기본 Firebase 앱 사용');
        return; // 이미 초기화된 기본 앱이 있으면 재사용
      }
    }

    print('새로운 Firebase 앱 초기화 중...');
    // Firebase 코어 초기화
    final app = await Firebase.initializeApp(
      name: 'DEFAULT', // 명시적으로 이름 지정
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
                iosClientId:
                    '425631894947-098d68944ab071a995de16.apps.googleusercontent.com',
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

    print('Firebase 코어 초기화 완료: ${app.name}');

    // Firebase Auth 초기화
    currentFirebaseUser = FirebaseAuth.instance.currentUser;
    print('Firebase Auth 초기화 완료');

    // Firebase Messaging 초기화
    await _initializeMessaging();
    print('Firebase Messaging 초기화 완료');
  } catch (e) {
    print('Firebase 초기화 오류: $e');
    if (e.toString().contains('duplicate-app')) {
      print('중복 앱 오류 발생, 기존 앱 사용 시도...');
      try {
        final defaultApp = Firebase.app();
        print('기존 Firebase 앱 사용: ${defaultApp.name}');
        return;
      } catch (innerError) {
        print('기존 앱 사용 실패: $innerError');
        currentFirebaseUser = null;
        rethrow;
      }
    }
    currentFirebaseUser = null;
    rethrow;
  }
}

// Firebase Messaging 초기화 함수
Future<void> _initializeMessaging() async {
  print('Firebase Messaging 초기화 시작...');

  // 백그라운드 메시지 핸들러 설정
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 포그라운드 알림 설정
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  // iOS 알림 권한 처리
  if (Platform.isIOS) {
    await _initializeIOSNotifications();
  }

  // 토큰 업데이트 (iOS, Android 모두)
  await _updateUserFcmToken();

  // 토큰 갱신 리스너 설정
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
    print('FCM 토큰이 갱신되었습니다: $newToken');
    _updateUserFcmToken();
  });

  // 포그라운드 메시지 리스너 설정
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('=== 포그라운드 메시지 수신 ===');
    print('메시지 ID: ${message.messageId}');
    print('제목: ${message.notification?.title}');
    print('내용: ${message.notification?.body}');
    print('데이터: ${message.data}');
    print('발신자: ${message.data['senderName']}');
    print('채팅방: ${message.data['chatRoomName']}');
    print('채팅방 ID: ${message.data['chatRoomId']}');
    print('메시지 타입: ${message.data['type']}');

    // 포그라운드에서도 알림이 표시되도록 처리
    if (message.notification != null) {
      print('포그라운드 알림 표시');
      if (Platform.isIOS) {
        // iOS에서는 이미 설정되어 있음
      } else {
        // Android의 경우 추가 처리가 필요할 수 있음
        print('Android 포그라운드 알림 처리');
      }
    }
  });

  // 백그라운드에서 알림 클릭 처리
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('=== 백그라운드 알림 클릭 ===');
    print('메시지 데이터: ${message.data}');
    _handleNotificationClick(message);
  });

  // 앱이 종료된 상태에서 알림 클릭으로 열린 경우 처리
  RemoteMessage? initialMessage =
      await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    print('=== 종료 상태에서 알림 클릭 ===');
    print('초기 메시지 데이터: ${initialMessage.data}');
    _handleNotificationClick(initialMessage);
  }

  print('Firebase Messaging 초기화 완료');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await _initializeFirebase();
  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('ko', 'KR'),
        Locale('en', 'US'),
      ],
      path: 'assets/translations',
      fallbackLocale: const Locale('ko', 'KR'),
      child: ChangeNotifierProvider(
        create: (context) => AppData(),
        child: const MyApp(),
      ),
    ),
  );
}

// 알림 클릭 처리 함수
void _handleNotificationClick(RemoteMessage message) {
  if (message.data['type'] == 'chat_message') {
    final chatRoomId = message.data['chatRoomId'];
    final chatRoomName = message.data['chatRoomName'] ?? '채팅방';

    if (chatRoomId != null) {
      print('채팅방으로 이동: $chatRoomId, $chatRoomName');

      Future.delayed(Duration(milliseconds: 500), () {
        if (navigatorKey.currentState != null) {
          navigatorKey.currentState!.push(
            MaterialPageRoute(
              builder:
                  (context) => ChatRoomPage(
                    chatRoomId: chatRoomId,
                    chatRoomName: chatRoomName,
                  ),
            ),
          );
        }
      });
    }
  }
}

// 전역 NavigatorKey 선언
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Brand-Regular',
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      // 로그인 상태에 따라 초기 라우트 설정
      initialRoute: currentFirebaseUser == null ? Loginpage.id : HomePage.id,
      routes: {
        MainPage.id: (context) => MainPage(),
        RegistrationPage.id: (context) => RegistrationPage(),
        Loginpage.id: (context) => Loginpage(),
        SearchPage.id: (context) => SearchPage(),
        HomePage.id: (context) => HomePage(),
        SettingsPage.id: (context) => SettingsPage(),
        EmailVerificationPage.id: (context) => EmailVerificationPage(email: ''),
        'rideconfirmation': (context) => RideConfirmationPage(),
      },
    );
  }
}
