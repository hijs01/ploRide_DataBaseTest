import 'package:flutter/material.dart';

class Loginpage extends StatelessWidget {
  const Loginpage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: <Widget>[
          SizedBox(height: 70),
          Image(
            alignment: Alignment.center,
            height: 100.0,
            width: 100.0,
            image: AssetImage('images/logo.png'),
          ),

          SizedBox(height: 40),

          Text(
            'Login',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 25, fontFamily: 'brand-bold'),
          ),

          TextField(
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email Address',
              labelStyle: TextStyle(fontSize: 14),
              hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            style: TextStyle(fontSize: 14),
          ),

          SizedBox(height: 10),

          TextField(
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Email Address',
              labelStyle: TextStyle(fontSize: 14),
              hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            style: TextStyle(fontSize: 14),
          ),

          SizedBox(height: 40),
        ],
      ),
    );
  }
}

