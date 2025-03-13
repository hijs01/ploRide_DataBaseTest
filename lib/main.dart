import 'package:cabrider/dataprovider/appdata.dart';
import 'package:cabrider/globalvariable.dart';
import 'package:cabrider/screens/loginpage.dart';
import 'package:cabrider/screens/mainpage.dart';
import 'package:cabrider/screens/registrationpage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'dart:io';

import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options:
        Platform.isIOS
            ? const FirebaseOptions(
              apiKey: 'AIzaSyBFtw9Wu3003CyA4auGTToQw_JjB2xaGN8',
              appId: '1:425631894947:ios:3dd5d94321ccd60195de16',
              messagingSenderId: '425631894947',
              projectId: 'geetaxi-aa379',
              databaseURL: 'https://geetaxi-aa379-default-rtdb.firebaseio.com',
            )
            : const FirebaseOptions(
              apiKey: 'AIzaSyAknGQdA7yAS5SICTW8lOKilEN7FBpNS-U',
              appId: '1:425631894947:android:dff55450334fed0295de16',
              messagingSenderId: '425631894947',
              projectId: 'geetaxi-aa379',
              databaseURL: 'https://geetaxi-aa379-default-rtdb.firebaseio.com',
            ),
  );

  currentFirebaseUser = await FirebaseAuth.instance.currentUser;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppData>(
      create: (context) => AppData(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          fontFamily: 'Brand-Regular',
          primarySwatch: Colors.blue,
        ),
        initialRoute:
            (currentFirebaseUser == null) ? Loginpage.id : MainPage.id,
        routes: {
          MainPage.id: (context) => MainPage(),
          RegistrationPage.id: (context) => RegistrationPage(),
          Loginpage.id: (context) => Loginpage(),
        },
      ),
    );
  }
}
