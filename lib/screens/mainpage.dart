import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});
  static const String id = 'mainpage';

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Main Page', style: TextStyle(color: Colors.white)),

        centerTitle: true,
        backgroundColor: Colors.black,
      ),
      body: Center(
        child: MaterialButton(
          onPressed: () {
            DatabaseReference dbref = FirebaseDatabase.instance.ref().child(
              'Test',
            );
            dbref.set('IsConnected');
          },
          height: 50,
          minWidth: 300,
          color: Colors.green,
          child: Text('Test Connection'),
        ),
      ),
    );
  }
}
