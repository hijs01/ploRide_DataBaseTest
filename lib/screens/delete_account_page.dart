import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cabrider/screens/loginpage.dart';

class DeleteAccountPage extends StatefulWidget {
  static const String id = 'delete_account';

  @override
  _DeleteAccountPageState createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  String _errorMessage = '';
  final TextEditingController _passwordController = TextEditingController();

  // 앱의 테마 색상 정의
  final Color primaryColor = Color(0xFF3F51B5); // 인디고 색상
  final Color accentColor = Color(0xFF536DFE); // 밝은 인디고 색상
  final Color dangerColor = Colors.red;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  // 계정 삭제 함수
  Future<void> _deleteAccount() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      User? currentUser = _auth.currentUser;

      if (currentUser != null) {
        // 1. Firestore에서 사용자 데이터 삭제
        await _firestore.collection('users').doc(currentUser.uid).delete();

        // 2. Firebase Authentication에서 사용자 계정 삭제
        await currentUser.delete();

        // 3. 로그인 페이지로 이동
        Navigator.pushNamedAndRemoveUntil(
          context,
          Loginpage.id,
          (route) => false,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('계정이 성공적으로 삭제되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (e.code == 'requires-recent-login') {
        // 사용자에게 재인증 요청
        _showReauthenticateDialog();
      } else {
        setState(() {
          _errorMessage = '계정 삭제 중 오류가 발생했습니다: ${e.message}';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '계정 삭제 중 오류가 발생했습니다: $e';
      });
    }
  }

  // 재인증 다이얼로그 표시
  void _showReauthenticateDialog() {
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    final backgroundColor = isDarkMode ? Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: backgroundColor,
          title: Text(
            '재인증 필요',
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '보안상의 이유로 계정을 삭제하기 전에 다시 로그인해야 합니다.',
                style: TextStyle(color: textColor),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: '비밀번호',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: primaryColor, width: 2),
                  ),
                ),
                obscureText: true,
                style: TextStyle(color: textColor),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                '취소',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[300] : Colors.grey[800],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _reauthenticateAndDelete();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: dangerColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('확인'),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
        );
      },
    );
  }

  // 재인증 후 계정 삭제
  Future<void> _reauthenticateAndDelete() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      User? currentUser = _auth.currentUser;

      if (currentUser != null && currentUser.email != null) {
        // 이메일/비밀번호로 재인증
        AuthCredential credential = EmailAuthProvider.credential(
          email: currentUser.email!,
          password: _passwordController.text,
        );

        // 재인증
        await currentUser.reauthenticateWithCredential(credential);

        // 재인증 성공 후 계정 삭제
        // 1. Firestore에서 사용자 데이터 삭제
        await _firestore.collection('users').doc(currentUser.uid).delete();

        // 2. Firebase Authentication에서 사용자 계정 삭제
        await currentUser.delete();

        // 3. 로그인 페이지로 이동
        Navigator.pushNamedAndRemoveUntil(
          context,
          Loginpage.id,
          (route) => false,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('계정이 성공적으로 삭제되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '재인증 중 오류가 발생했습니다. 비밀번호를 확인해주세요.';
      });
    }
  }

  // 계정 삭제 확인 다이얼로그
  void _showDeleteConfirmationDialog() {
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    final backgroundColor = isDarkMode ? Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: backgroundColor,
          title: Text(
            '계정 삭제',
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          ),
          content: Text(
            '정말로 계정을 삭제하시겠습니까? 이 작업은 되돌릴 수 없으며, 모든 개인 데이터가 영구적으로 삭제됩니다.',
            style: TextStyle(height: 1.5, color: textColor),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                '취소',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[300] : Colors.grey[800],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteAccount();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: dangerColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('삭제'),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    final backgroundColor = isDarkMode ? Color(0xFF121212) : Colors.white;
    final cardColor = isDarkMode ? Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final shadowColor = isDarkMode ? Colors.transparent : Colors.black12;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          '계정 삭제',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body:
          _isLoading
              ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                ),
              )
              : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color:
                            isDarkMode
                                ? dangerColor.withOpacity(0.2)
                                : dangerColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              isDarkMode
                                  ? dangerColor.withOpacity(0.4)
                                  : dangerColor.withOpacity(0.3),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: shadowColor,
                            blurRadius: 5,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning, color: dangerColor),
                              SizedBox(width: 8),
                              Text(
                                '주의사항',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: dangerColor,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Text(
                            '계정을 삭제하면 다음 정보가 영구적으로 제거됩니다:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: textColor,
                            ),
                          ),
                          SizedBox(height: 12),
                          _buildWarningItem('프로필 정보 및 설정', textColor),
                          _buildWarningItem('ride 기록', textColor),
                          _buildWarningItem('채팅 내역', textColor),
                          _buildWarningItem('기타 개인 데이터', textColor),
                          SizedBox(height: 12),
                          Text(
                            '계정이 삭제되면 복구할 수 없으며, 새로 가입해야 합니다.',
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color:
                                  isDarkMode
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24),
                    if (_errorMessage.isNotEmpty)
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              isDarkMode
                                  ? dangerColor.withOpacity(0.2)
                                  : dangerColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _errorMessage,
                          style: TextStyle(color: dangerColor),
                        ),
                      ),
                    Spacer(),
                    ElevatedButton(
                      onPressed: _showDeleteConfirmationDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: dangerColor,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 3,
                      ),
                      child: Text(
                        '계정 삭제',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(
                          color: isDarkMode ? Colors.grey[700]! : Colors.grey,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        '취소',
                        style: TextStyle(
                          fontSize: 16,
                          color:
                              isDarkMode ? Colors.grey[300] : Colors.grey[800],
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                  ],
                ),
              ),
    );
  }

  Widget _buildWarningItem(String text, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
          ),
          Expanded(child: Text(text, style: TextStyle(color: textColor))),
        ],
      ),
    );
  }
}
