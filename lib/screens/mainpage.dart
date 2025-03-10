import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class Mainpage extends StatefulWidget {
  const Mainpage({super.key});
  static const String id = 'mainpage';
  

  @override
  State<Mainpage> createState() => _MainpageState();
}

class _MainpageState extends State<Mainpage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Main Page',
        style: TextStyle(
          color: Colors.white
        ),),

        centerTitle: true,
        backgroundColor: Colors.black,
      ),
      body: Center(
        child: MaterialButton(
          onPressed: (){
             DatabaseReference dbref = FirebaseDatabase.instance.ref().child('Test');
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

