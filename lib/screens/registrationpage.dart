import 'package:cabrider/brand_colors.dart';
import 'package:cabrider/screens/loginpage.dart';
import 'package:cabrider/screens/mainpage.dart';
import 'package:cabrider/widgets/ProgressDialog.dart';
import 'package:cabrider/widgets/taxi_button.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RegistrationPage extends StatefulWidget {
  static const String id = 'register';

  const RegistrationPage({super.key});

  @override
  _RegistrationPageState createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GlobalKey<ScaffoldState> scaffoldKey = new GlobalKey<ScaffoldState>();

  var fullnameController = TextEditingController();
  var emailController = TextEditingController();
  var phoneController = TextEditingController();
  var passwordController = TextEditingController();

  void showSnackBar(String title) {
    final snackBar = SnackBar(
      content: Text(
        title,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 15),
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  void registerUser(BuildContext context) async {
    showDialog(
      context: context,
      builder:
          (BuildContext context) =>
              ProgressDialog(status: 'Registering you...'),
    );

    try {
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: emailController.text,
        password: passwordController.text,
      );

      final User? user = userCredential.user;

      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fullname': fullnameController.text,
          'email': emailController.text,
          'phone': phoneController.text,
          'created_at': FieldValue.serverTimestamp(),
        });

        Navigator.pop(context);
        Navigator.pushNamedAndRemoveUntil(context, MainPage.id, (route) => false);
      }
    } catch (e) {
      Navigator.pop(context);
      showSnackBar(e.toString());
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
                  'Create a Rider\'s Account',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 25, fontFamily: 'brand-bold'),
                ),

                Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Column(
                    children: <Widget>[
                      // Fullname
                      TextField(
                        controller: fullnameController,
                        keyboardType: TextInputType.text,
                        decoration: InputDecoration(
                          labelText: 'Full name',
                          labelStyle: TextStyle(fontSize: 14),
                          hintStyle: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                        style: TextStyle(fontSize: 14),
                      ),

                      SizedBox(height: 10),

                      // Email Address
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

                      // Phone
                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Phone number',
                          labelStyle: TextStyle(fontSize: 14),
                          hintStyle: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                        style: TextStyle(fontSize: 14),
                      ),

                      SizedBox(height: 10),

                      // Password
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
                        title: 'REGISTER',
                        color: BrandColors.colorGreen,
                        onPressed: () async {
                          //check network Availability

                          try {
                            var connectivityResult =
                                await (Connectivity().checkConnectivity());

                            if (connectivityResult == ConnectivityResult.none) {
                              showSnackBar('인터넷 연결이 없습니다. 연결 상태를 확인해주세요.');
                              return;
                            }

                            if (fullnameController.text.length < 3) {
                              showSnackBar('Please provide full name');
                              return;
                            }

                            if (!emailController.text.contains('@')) {
                              showSnackBar(
                                'Please provide a valid email address',
                              );
                              return;
                            }

                            if (phoneController.text.length < 10) {
                              showSnackBar(
                                'Please provide a valid phone number',
                              );
                              return;
                            }

                            if (passwordController.text.length < 8) {
                              showSnackBar(
                                'Password must be at least 8 characters',
                              );
                              return;
                            }
                            registerUser(context);
                          } catch (e) {
                            showSnackBar('An error occurred');
                          }
                        },
                      ),
                    ],
                  ),
                ),

                TextButton(
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      Loginpage.id,
                      (route) => false,
                    );
                  },
                  child: Text(
                    'Already have a RIDER account? Log in',
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
