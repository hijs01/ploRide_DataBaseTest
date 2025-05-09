import 'dart:async';
import 'package:TAGO/brand_colors.dart';
import 'package:TAGO/screens/homepage.dart';
import 'package:TAGO/screens/loginpage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class EmailVerificationPage extends StatefulWidget {
  static const String id = 'email_verification';
  final String email;

  const EmailVerificationPage({Key? key, required this.email})
    : super(key: key);

  @override
  _EmailVerificationPageState createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late Timer _timer;
  late Timer _countdownTimer;
  bool _isEmailVerified = false;
  bool _isResendingEmail = false;
  bool _isCheckingStatus = false;
  int _timeLeft = 60;
  bool _showResendButton = false;

  // 테마 색상 정의
  final Color themeColor = Color(0xFF3F51B5); // 인디고 색상
  final Color secondaryColor = Color(0xFF5C6BC0); // 밝은 인디고 색상

  @override
  void initState() {
    super.initState();
    // 현재 사용자의 이메일 인증 상태 확인
    _checkEmailVerified();

    // 타이머 시작 - 3초마다 이메일 인증 상태 확인
    _timer = Timer.periodic(Duration(seconds: 3), (_) {
      _checkEmailVerified();
    });

    // 초기에는 재전송 버튼 숨김
    _showResendButton = false;

    // 앱 시작 시 60초 카운트다운 시작
    _startInitialCountdown();
  }

  // 초기 카운트다운 시작
  void _startInitialCountdown() {
    _countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
        } else {
          timer.cancel();
          _showResendButton = true;
        }
      });
    });
  }

  @override
  void dispose() {
    // 타이머들 해제
    _timer.cancel();
    if (_countdownTimer.isActive) {
      _countdownTimer.cancel();
    }
    super.dispose();
  }

  // 이메일 인증 상태 확인
  Future<void> _checkEmailVerified() async {
    if (_isCheckingStatus) return;

    setState(() {
      _isCheckingStatus = true;
    });

    try {
      // 현재 사용자 정보 갱신
      await _auth.currentUser?.reload();

      // 이메일 인증 여부 확인
      final user = _auth.currentUser;
      if (user != null && user.emailVerified) {
        setState(() {
          _isEmailVerified = true;
        });

        // Firestore에 이메일 인증 상태 업데이트
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'emailVerified': true});

        // 타이머 해제
        _timer.cancel();
        if (_countdownTimer.isActive) {
          _countdownTimer.cancel();
        }

        // 홈페이지로 이동
        Navigator.pushNamedAndRemoveUntil(
          context,
          HomePage.id,
          (route) => false,
        );
      }
    } catch (e) {
      print('이메일 인증 확인 중 오류: $e');
    } finally {
      setState(() {
        _isCheckingStatus = false;
      });
    }
  }

  // 인증 이메일 재전송
  Future<void> _resendVerificationEmail() async {
    if (_isResendingEmail) return;

    setState(() {
      _isResendingEmail = true;
      _showResendButton = false;
    });

    try {
      await _auth.currentUser?.sendEmailVerification();

      // 카운트다운 시작
      setState(() {
        _timeLeft = 60;
      });

      // 카운트다운 타이머
      _countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
        setState(() {
          if (_timeLeft > 0) {
            _timeLeft--;
          } else {
            timer.cancel();
            _showResendButton = true;
          }
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('인증 이메일이 재전송되었습니다.'),
          backgroundColor: themeColor,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('이메일 재전송 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _showResendButton = true;
      });
    } finally {
      setState(() {
        _isResendingEmail = false;
      });
    }
  }

  // 로그아웃 및 로그인 페이지로 이동
  Future<void> _signOut() async {
    await _auth.signOut();
    Navigator.pushNamedAndRemoveUntil(context, Loginpage.id, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: themeColor,
      appBar: AppBar(
        backgroundColor: themeColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text('이메일 인증', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: _signOut,
            child: Text('로그아웃', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Center(
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
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 40),
                  // 이메일 아이콘
                  Container(
                    padding: EdgeInsets.all(25),
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
                    child: Icon(
                      Icons.email_outlined,
                      size: 70,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 40),
                  // 안내 텍스트
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Text(
                            '이메일 인증이 필요합니다',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: themeColor,
                            ),
                          ),
                          SizedBox(height: 20),
                          Text(
                            '다음 이메일 주소로 인증 링크를 보냈습니다:',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[700],
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            widget.email,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 20),
                          Text(
                            '이메일의 인증 링크를 클릭하여 계정 인증을 완료해주세요. 인증이 완료되면 자동으로 앱에 로그인됩니다.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                          SizedBox(height: 30),
                          SizedBox(height: 20),
                          // 타이머 표시 (항상 표시되도록 수정)
                          if (_timeLeft > 0)
                            Column(
                              children: [
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    SizedBox(
                                      width: 80,
                                      height: 80,
                                      child: CircularProgressIndicator(
                                        value: _timeLeft / 60,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              themeColor,
                                            ),
                                        backgroundColor: Colors.grey[300],
                                        strokeWidth: 8,
                                      ),
                                    ),
                                    Text(
                                      '$_timeLeft',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: themeColor,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 10),
                                Text(
                                  '재전송 대기 시간',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          // 이메일 재전송 버튼 (타이머가 끝난 후에만 표시)
                          if (_showResendButton)
                            ElevatedButton(
                              onPressed: _resendVerificationEmail,
                              child: Text(
                                '인증 이메일 재전송',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: themeColor,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 40),
                  // 인증 상태 표시
                  _isCheckingStatus
                      ? CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      )
                      : Text(
                        '인증 상태를 확인 중입니다...',
                        style: TextStyle(color: Colors.white70),
                      ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
