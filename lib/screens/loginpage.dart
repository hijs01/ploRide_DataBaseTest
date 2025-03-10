import 'package:cabrider/brand_colors.dart';
import 'package:cabrider/screens/mainpage.dart';
import 'package:cabrider/widgets/TaxiButton.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class Loginpage extends StatefulWidget {
  static const String id = 'login';
  const Loginpage({super.key});

  @override
  State<Loginpage> createState() => _LoginpageState();
}

class _LoginpageState extends State<Loginpage> {
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  var emailController = TextEditingController();
  var passwordController = TextEditingController();

  void showSnackBar(String title) {
    final snackBar = SnackBar(
      content: Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 15),),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  void login() async {
    try {
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: emailController.text, 
        password: passwordController.text
      );
      
      final User? user = userCredential.user;
      
      if(user != null) {
        DatabaseReference userRef = FirebaseDatabase.instance.ref().child('users/${user.uid}');
        userRef.once().then((DatabaseEvent event) {
          if(event.snapshot.value != null) {
            Navigator.pushNamedAndRemoveUntil(context, MainPage.id, (route) => false);
          }
        });
      }
    } on FirebaseAuthException catch (e) {
      showSnackBar(e.message ?? 'An error occurred during sign in');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey, 
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(8.0),
            child: Column(
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
                  'Sign in as a Rider',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 25, fontFamily: 'brand-bold'),
                ),

                Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Column(
                    children: <Widget>[
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email Address',
                          labelStyle: TextStyle(fontSize: 14),
                          hintStyle: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                        style: TextStyle(fontSize: 14),
                      ),

                      SizedBox(height: 10),

                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: TextStyle(fontSize: 14),
                          hintStyle: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                        style: TextStyle(fontSize: 14),
                      ),

                      SizedBox(height: 40),

                      TaxiButton(
                        text: 'LOGIN',
                        color: BrandColors.colorGreen,
                        onPressed: () async{
                            var connectivityResult = await Connectivity().checkConnectivity();
                            if(connectivityResult == ConnectivityResult.none){
                              showSnackBar('No Internet Connectivity');
                              return;
                            }

                            if(!emailController.text.contains('@')){
                              showSnackBar('Please enter a valid email address');
                              return;
                            }

                            if(passwordController.text.length < 8){
                              showSnackBar('Please enter a valid password');
                              return;
                            }

                            login();
                        },
                      ),
                    ],
                  ),
                ),

                TextButton(
                  onPressed: () {},
                  child: Text(
                    'Don\'t have an account? Create Account',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

