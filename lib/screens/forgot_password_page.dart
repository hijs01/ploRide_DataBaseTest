import 'package:cabrider/brand_colors.dart';
import 'package:cabrider/screens/loginpage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ForgotPasswordPage extends StatefulWidget {
  static const String id = 'forgot_password';

  const ForgotPasswordPage({Key? key}) : super(key: key);

  @override
  _ForgotPasswordPageState createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  bool _isEmailSent = false;

  // 테마 색상 정의
  final Color themeColor = Color(0xFF3F51B5); // 인디고 색상
  final Color secondaryColor = Color(0xFF5C6BC0); // 밝은 인디고 색상

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  // 비밀번호 재설정 이메일 전송
  Future<void> _sendPasswordResetEmail() async {
    // 이메일 입력 확인
    if (_emailController.text.isEmpty) {
      _showSnackBar('이메일을 입력해주세요', isError: true);
      return;
    }

    // 이메일 형식 검증
    final RegExp emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(_emailController.text)) {
      _showSnackBar('올바른 이메일 형식이 아닙니다', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _auth.sendPasswordResetEmail(email: _emailController.text.trim());
      setState(() {
        _isEmailSent = true;
        _isLoading = false;
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
      });

      String errorMessage = '오류가 발생했습니다. 다시 시도해주세요.';
      switch (e.code) {
        case 'invalid-email':
          errorMessage = '유효하지 않은 이메일 형식입니다.';
          break;
        case 'user-not-found':
          errorMessage = '해당 이메일로 등록된 계정이 없습니다.';
          break;
        default:
          errorMessage = '오류가 발생했습니다: ${e.message}';
      }

      _showSnackBar(errorMessage, isError: true);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('오류가 발생했습니다: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15),
        ),
        backgroundColor: isError ? Colors.red : themeColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: themeColor,
      appBar: AppBar(
        backgroundColor: themeColor,
        elevation: 0,
        title: Text('비밀번호 재설정', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
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
            child:
                _isEmailSent
                    ? _buildEmailSentContent()
                    : _buildPasswordResetForm(),
          ),
        ),
      ),
    );
  }

  // 이메일 전송 전 폼
  Widget _buildPasswordResetForm() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(height: 40),
        // 잠금 아이콘
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
          child: Icon(Icons.lock_reset, size: 70, color: Colors.white),
        ),
        SizedBox(height: 40),
        // 안내 카드
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
                  '비밀번호를 잊으셨나요?',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: themeColor,
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  '계정에 등록된 이메일 주소를 입력하시면 비밀번호 재설정 링크를 보내드립니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                ),
                SizedBox(height: 30),
                // 이메일 입력 필드
                Container(
                  margin: EdgeInsets.only(bottom: 24),
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
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      prefixIcon: Icon(
                        Icons.email_outlined,
                        color: themeColor,
                        size: 22,
                      ),
                      hintText: '이메일 주소',
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
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                ),
                // 재설정 링크 전송 버튼
                Container(
                  width: double.infinity,
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
                      onTap: _isLoading ? null : _sendPasswordResetEmail,
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
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                    strokeWidth: 2.0,
                                  ),
                                )
                                : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.send_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      '재설정 링크 전송',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
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
        ),
        SizedBox(height: 20),
        // 로그인 페이지로 돌아가기
        TextButton(
          onPressed: () {
            Navigator.pushNamedAndRemoveUntil(
              context,
              Loginpage.id,
              (route) => false,
            );
          },
          child: Text(
            '로그인 페이지로 돌아가기',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  // 이메일 전송 후 화면
  Widget _buildEmailSentContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(height: 60),
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
            Icons.check_circle_outline,
            size: 70,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 40),
        // 안내 카드
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
                  '이메일이 전송되었습니다',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: themeColor,
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  '다음 이메일 주소로 비밀번호 재설정 링크를 보냈습니다:',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                ),
                SizedBox(height: 8),
                Text(
                  _emailController.text,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  '이메일의 링크를 클릭하여 비밀번호를 재설정해주세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
                SizedBox(height: 30),
                // 이메일 앱 열기 버튼
                ElevatedButton.icon(
                  onPressed: () {
                    // 이메일 앱 열기 기능은 구현하지 않음
                    _showSnackBar('이메일 앱을 열어주세요');
                  },
                  icon: Icon(Icons.open_in_new),
                  label: Text('이메일 앱 열기'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                // 로그인 페이지 버튼
                TextButton(
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      Loginpage.id,
                      (route) => false,
                    );
                  },
                  child: Text(
                    '로그인 페이지로 돌아가기',
                    style: TextStyle(
                      color: themeColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
