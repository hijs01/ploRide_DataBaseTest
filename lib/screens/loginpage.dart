import 'package:cabrider/brand_colors.dart';
import 'package:cabrider/screens/homepage.dart';
import 'package:cabrider/screens/registrationpage.dart';
import 'package:cabrider/screens/email_verification_page.dart';
import 'package:cabrider/widgets/ProgressDialog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cabrider/helpers/RequestHelper.dart';

class Loginpage extends StatefulWidget {
  static const String id = 'login';
  const Loginpage({super.key});

  @override
  State<Loginpage> createState() => _LoginpageState();
}

class _LoginpageState extends State<Loginpage>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
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
  final Color themeColor = Color(0xFF3F51B5); // 인디고 색상으로 변경
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

  void login() async {
    // 이메일 형식 검증
    if (emailController.text.isEmpty) {
      showSnackBar('Please enter your email', isError: true);
      return;
    }

    final RegExp emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(emailController.text)) {
      showSnackBar('Invalid email format', isError: true);
      return;
    }

    // 비밀번호 검증
    if (passwordController.text.isEmpty) {
      showSnackBar('Please enter your password', isError: true);
      return;
    }

    if (passwordController.text.length < 6) {
      showSnackBar('Password must be at least 6 characters', isError: true);
      return;
    }

    // 로딩 상태 설정
    setState(() {
      _isLoading = true;
    });

    try {
      final UserCredential userCredential = await _auth
          .signInWithEmailAndPassword(
            email: emailController.text,
            password: passwordController.text,
          );

      final User? user = userCredential.user;

      if (user != null) {
        final userDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();

        if (userDoc.exists) {
          setState(() {
            _isLoading = false;
          });

          // 이메일 인증 상태 확인
          bool isEmailVerified = user.emailVerified;
          bool firebaseEmailVerified =
              userDoc.data()?['emailVerified'] ?? false;

          if (isEmailVerified || firebaseEmailVerified) {
            // 이메일이 인증된 경우 홈페이지로 이동
            Navigator.pushNamedAndRemoveUntil(
              context,
              HomePage.id,
              (route) => false,
            );
          } else {
            // 이메일이 인증되지 않은 경우 인증 페이지로 이동
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) =>
                        EmailVerificationPage(email: emailController.text),
              ),
            );
          }
        } else {
          setState(() {
            _isLoading = false;
          });
          showSnackBar('User data not found', isError: true);
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
      });

      // 오류 메시지 처리
      String errorMessage = 'An error occurred during login.';
      switch (e.code) {
        case 'user-not-found':
        case 'wrong-password':
          errorMessage = 'Incorrect email or password.';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email format.';
          break;
        default:
          errorMessage = 'Incorrect email or password.';
      }

      showSnackBar(errorMessage, isError: true);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      showSnackBar('Incorrect email or password.', isError: true);
    }
  }

  void _showForgotPasswordDialog() {
    final TextEditingController resetEmailController = TextEditingController();
    // 현재 이메일 필드에 입력된 값이 있으면 복사
    if (emailController.text.isNotEmpty) {
      resetEmailController.text = emailController.text;
    }

    bool isLoading = false;
    bool isValidEmail = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // 이메일 유효성 검사 함수
            void validateEmail(String email) {
              final RegExp emailRegex = RegExp(
                r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
              );
              setState(() {
                isValidEmail = email.isNotEmpty && emailRegex.hasMatch(email);
              });
            }

            // 초기 이메일 유효성 검사
            validateEmail(resetEmailController.text);

            return AlertDialog(
              title: Text('Reset Password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'We\'ll send a password reset link to your registered email.',
                    style: TextStyle(fontSize: 14),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: resetEmailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.email_outlined, color: themeColor),
                      hintText: 'Email address',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (value) {
                      validateEmail(value);
                    },
                  ),
                  SizedBox(height: 8),
                  if (isLoading)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(themeColor),
                          strokeWidth: 2.0,
                        ),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
                ElevatedButton(
                  onPressed:
                      isLoading || !isValidEmail
                          ? null
                          : () async {
                            setState(() {
                              isLoading = true;
                            });

                            try {
                              // 인터넷 연결 확인
                              var connectivityResult =
                                  await Connectivity().checkConnectivity();
                              if (connectivityResult ==
                                  ConnectivityResult.none) {
                                Navigator.pop(context);
                                showSnackBar('No internet connection', isError: true);
                                return;
                              }

                              // 비밀번호 재설정 이메일 발송
                              await _auth.sendPasswordResetEmail(
                                email: resetEmailController.text.trim(),
                              );

                              // 다이얼로그 닫기
                              Navigator.pop(context);

                              // 성공 메시지 표시
                              showSnackBar(
                                'Password reset email has been sent to ${resetEmailController.text}. Please check your email.',
                              );
                            } on FirebaseAuthException catch (e) {
                              Navigator.pop(context);

                              // 오류 메시지 처리
                              String errorMessage =
                                  'An error occurred while sending the password reset email.';
                              if (e.code == 'user-not-found') {
                                errorMessage = 'No account found with this email.';
                              }

                              showSnackBar(errorMessage, isError: true);
                            } catch (e) {
                              Navigator.pop(context);
                              showSnackBar(
                                'An error occurred while sending the password reset email.',
                                isError: true,
                              );
                            }
                          },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('Send'),
                ),
              ],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            );
          },
        );
      },
    );
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
                bottom: MediaQuery.of(context).viewInsets.bottom + 100,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: <Widget>[
                  // 상단 영역
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.only(top: 80, bottom: 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(height: 20), // 상단 여백 추가
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
                        SizedBox(height: 20), // 간격 조정
                        Text(
                          'TAGO',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 10), // 간격 유지
                        Text(
                          'WE ARE, TAGO',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 10), // 간격 추가
                  // 로그인 폼 영역
                  AnimatedContainer(
                    duration: Duration(milliseconds: 800),
                    curve: Curves.easeOutQuint,
                    margin: EdgeInsets.fromLTRB(20, 30, 20, 20),
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
                                  hintText: 'Email address',
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
                                  0.2,
                                  0.7,
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

                        // 비밀번호 찾기 링크
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
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  _showForgotPasswordDialog();
                                },
                                child: Text(
                                  'Forgot your password?',
                                  style: TextStyle(
                                    color: themeColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: 16),

                        // 로그인 버튼
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
                                          : () async {
                                            var connectivityResult =
                                                await Connectivity()
                                                    .checkConnectivity();
                                            if (connectivityResult ==
                                                ConnectivityResult.none) {
                                              showSnackBar(
                                                'No internet connection',
                                                isError: true,
                                              );
                                              return;
                                            }

                                            login();
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
                                                    Icons.login_rounded,
                                                    color: Colors.white,
                                                    size: 22,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    'Login',
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

                        // 회원가입 링크
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
                                  RegistrationPage.id,
                                  (route) => false,
                                );
                              },
                              child: RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'Don\'t have an account? ',
                                      style: TextStyle(
                                        color: Colors.black54,
                                        fontSize: 14,
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'Sign Up',
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
