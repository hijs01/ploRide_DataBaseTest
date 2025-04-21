import 'package:cabrider/brand_colors.dart';
import 'package:cabrider/screens/loginpage.dart';
import 'package:cabrider/screens/mainpage.dart';
import 'package:cabrider/screens/email_verification_page.dart';
import 'package:cabrider/screens/terms_agreement_page.dart';
import 'package:cabrider/widgets/ProgressDialog.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';

class RegistrationPage extends StatefulWidget {
  static const String id = 'register';

  const RegistrationPage({super.key});

  @override
  _RegistrationPageState createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GlobalKey<ScaffoldState> scaffoldKey = new GlobalKey<ScaffoldState>();

  var fullnameController = TextEditingController();
  var emailController = TextEditingController();
  var passwordController = TextEditingController();

  // 비밀번호 표시 여부 상태 추가
  bool _obscurePassword = true;

  // 로딩 상태 추가
  bool _isLoading = false;

  // 애니메이션 컨트롤러 추가
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // 테마 색상 정의
  final Color themeColor = Color(0xFF3F51B5); // 인디고 색상
  final Color secondaryColor = Color(0xFF5C6BC0); // 밝은 인디고 색상

  @override
  void initState() {
    super.initState();
    // 애니메이션 컨트롤러 초기화
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );

    // 페이드 애니메이션 초기화
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    // 애니메이션 시작
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    fullnameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void showSnackBar(String title, {bool isError = false}) {
    final snackBar = SnackBar(
      content: Text(
        title,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 15),
      ),
      backgroundColor: isError ? Colors.red : themeColor,
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  void registerUser(BuildContext context) async {
    // 로딩 상태 설정
    setState(() {
      _isLoading = true;
    });

    try {
      final UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(
            email: emailController.text,
            password: passwordController.text,
          );

      final User? user = userCredential.user;

      if (user != null) {
        // 이메일 인증 메일 발송
        await user.sendEmailVerification();

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fullname': fullnameController.text,
          'email': emailController.text,
          'created_at': FieldValue.serverTimestamp(),
          'emailVerified': false, // 이메일 인증 상태 필드 추가
        });

        setState(() {
          _isLoading = false;
        });

        // 이메일 인증 페이지로 이동
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => EmailVerificationPage(email: emailController.text),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
      });

      // 오류 메시지 처리
      String errorMessage = 'An error occurred during registration.';
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = 'This email is already in use.';
          break;
        case 'weak-password':
          errorMessage = 'Password is too weak.';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email format.';
          break;
        default:
          errorMessage = e.message ?? errorMessage;
      }

      showSnackBar(errorMessage, isError: true);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      showSnackBar(e.toString(), isError: true);
    }
  }

  // 이용약관 동의 화면을 표시하는 함수
  void _showTermsAgreement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => TermsAgreementPage(
              onAccept: () {
                // 이용약관에 동의했을 때, 회원가입 진행
                Navigator.pop(context); // 이용약관 페이지 닫기
                // 이메일, 이름, 비밀번호 유효성 검사를 여기서 수행
                _validateAndRegister();
              },
              onReject: () {
                // 이용약관에 거절했을 때, 앱 강제 종료
                exit(0); // 앱 즉시 종료
              },
            ),
      ),
    );
  }

  // 입력 유효성 검사 후 회원가입 처리
  void _validateAndRegister() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      showSnackBar('No internet connection', isError: true);
      return;
    }

    // 이름 검증
    if (fullnameController.text.length < 3) {
      showSnackBar('Please enter your name', isError: true);
      return;
    }

    // 이메일 형식 검증
    final RegExp emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@gmail\.com$');
    if (!emailRegex.hasMatch(emailController.text)) {
      showSnackBar('Only Gmail(@gmail.com) is allowed', isError: true);
      return;
    }

    // 비밀번호 검증
    if (passwordController.text.length < 6) {
      showSnackBar('Password must be at least 6 characters', isError: true);
      return;
    }

    registerUser(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: themeColor,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () {
          // 키보드 숨기기
          FocusScope.of(context).unfocus();
        },
        child: Container(
          width: double.infinity,
          height: MediaQuery.of(context).size.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [themeColor, secondaryColor],
            ),
          ),
          child: SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Padding(
              padding: EdgeInsets.only(
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: <Widget>[
                  // 상단 영역
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.only(top: 60, bottom: 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 택시 아이콘
                        Container(
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 15,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Hero(
                            tag: 'taxiIcon',
                            child: Icon(
                              Icons.local_taxi,
                              size: 60,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(height: 20),
                        Text(
                          'PLO RIDE',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 회원가입 폼 영역
                  AnimatedContainer(
                    duration: Duration(milliseconds: 800),
                    curve: Curves.easeOutQuint,
                    margin: EdgeInsets.fromLTRB(20, 20, 20, 20),
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 30),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(40),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 15,
                          offset: Offset(0, 5),
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        // 이름 입력 필드
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: Offset(0, 0.2),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: _animationController,
                                curve: Interval(
                                  0.0,
                                  0.5,
                                  curve: Curves.easeOut,
                                ),
                              ),
                            ),
                            child: Container(
                              margin: EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.grey.shade200),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    themeColor.withOpacity(0.05),
                                    secondaryColor.withOpacity(0.05),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 10,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: TextField(
                                controller: fullnameController,
                                keyboardType: TextInputType.name,
                                decoration: InputDecoration(
                                  prefixIcon: Icon(
                                    Icons.person_outline,
                                    color: themeColor,
                                    size: 22,
                                  ),
                                  hintText: 'Full Name',
                                  hintStyle: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 14,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 15,
                                  ),
                                ),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // 이메일 입력 필드
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: Offset(0, 0.2),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: _animationController,
                                curve: Interval(
                                  0.1,
                                  0.6,
                                  curve: Curves.easeOut,
                                ),
                              ),
                            ),
                            child: Container(
                              margin: EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.grey.shade200),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    themeColor.withOpacity(0.05),
                                    secondaryColor.withOpacity(0.05),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 10,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: TextField(
                                controller: emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  prefixIcon: Icon(
                                    Icons.email_outlined,
                                    color: themeColor,
                                    size: 22,
                                  ),
                                  hintText: 'Email address (Gmail only)',
                                  helperText: 'Only Gmail accounts are allowed',
                                  helperStyle: TextStyle(
                                    color: themeColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  hintStyle: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 14,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 15,
                                  ),
                                ),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // 비밀번호 입력 필드
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: Offset(0, 0.2),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: _animationController,
                                curve: Interval(
                                  0.3,
                                  0.8,
                                  curve: Curves.easeOut,
                                ),
                              ),
                            ),
                            child: Container(
                              margin: EdgeInsets.only(bottom: 25),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.grey.shade200),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    themeColor.withOpacity(0.05),
                                    secondaryColor.withOpacity(0.05),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 10,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: TextField(
                                controller: passwordController,
                                obscureText: _obscurePassword,
                                decoration: InputDecoration(
                                  prefixIcon: Icon(
                                    Icons.lock_outline,
                                    color: themeColor,
                                    size: 22,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: Colors.grey.shade400,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                  hintText: 'Password',
                                  hintStyle: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 14,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 15,
                                  ),
                                ),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // 회원가입 버튼
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: Offset(0, 0.2),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: _animationController,
                                curve: Interval(
                                  0.4,
                                  0.9,
                                  curve: Curves.easeOut,
                                ),
                              ),
                            ),
                            child: Container(
                              width: MediaQuery.of(context).size.width * 0.7,
                              height: 45,
                              margin: EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xFF3949AB).withOpacity(0.3),
                                    blurRadius: 12,
                                    spreadRadius: 0,
                                    offset: Offset(0, 5),
                                  ),
                                  BoxShadow(
                                    color: Color(0xFF3F51B5).withOpacity(0.2),
                                    blurRadius: 6,
                                    spreadRadius: 0,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF4A5CDB), // 밝은 인디고
                                    Color(0xFF3F51B5), // 인디고
                                    Color(0xFF303F9F), // 진한 인디고
                                  ],
                                  stops: [0.0, 0.5, 1.0],
                                ),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(18),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  splashColor: Colors.white.withOpacity(0.3),
                                  highlightColor: Colors.transparent,
                                  onTap:
                                      _isLoading
                                          ? null
                                          : () {
                                            // 회원가입 버튼 클릭 시 이용약관 동의 화면을 표시
                                            _showTermsAgreement();
                                          },
                                  child: Container(
                                    width: double.infinity,
                                    height: 45,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(18),
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.white.withOpacity(0.15),
                                          Colors.white.withOpacity(0.05),
                                          Colors.transparent,
                                        ],
                                        stops: [0.0, 0.3, 1.0],
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child:
                                        _isLoading
                                            ? SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(Colors.white),
                                                strokeWidth: 2.0,
                                              ),
                                            )
                                            : Padding(
                                              padding: EdgeInsets.only(top: 2),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons
                                                        .app_registration_rounded,
                                                    color: Colors.white,
                                                    size: 22,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    'Sign Up',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      letterSpacing: 0.5,
                                                      shadows: [
                                                        Shadow(
                                                          color: Colors.black26,
                                                          offset: Offset(0, 1),
                                                          blurRadius: 2,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // 로그인 링크
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: Offset(0, 0.2),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: _animationController,
                                curve: Interval(
                                  0.5,
                                  1.0,
                                  curve: Curves.easeOut,
                                ),
                              ),
                            ),
                            child: TextButton(
                              onPressed: () {
                                Navigator.pushNamedAndRemoveUntil(
                                  context,
                                  Loginpage.id,
                                  (route) => false,
                                );
                              },
                              child: RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'Already have an account? ',
                                      style: TextStyle(
                                        color: Colors.black54,
                                        fontSize: 14,
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'Login',
                                      style: TextStyle(
                                        color: themeColor,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      // 하단 텍스트 추가
      bottomNavigationBar: Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [secondaryColor, secondaryColor],
          ),
        ),
        child: Text(
          'Made by team PLO',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
