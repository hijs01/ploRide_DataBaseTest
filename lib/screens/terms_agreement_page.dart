import 'package:TAGO/brand_colors.dart';
import 'package:TAGO/helpers/privacy_policy.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';

class TermsAgreementPage extends StatefulWidget {
  final Function onAccept;
  final Function onReject;

  const TermsAgreementPage({
    Key? key,
    required this.onAccept,
    required this.onReject,
  }) : super(key: key);

  @override
  _TermsAgreementPageState createState() => _TermsAgreementPageState();
}

class _TermsAgreementPageState extends State<TermsAgreementPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final ScrollController _scrollController = ScrollController();
  bool _reachedEnd = false;

  @override
  void initState() {
    super.initState();

    // 스크롤 이벤트 리스너 추가
    _scrollController.addListener(_checkScrollPosition);

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

    // 슬라이드 애니메이션 초기화
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    // 애니메이션 시작
    _animationController.forward();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_checkScrollPosition);
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // 스크롤 위치를 체크하여 끝에 도달했는지 확인
  void _checkScrollPosition() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100) {
      if (!_reachedEnd) {
        setState(() {
          _reachedEnd = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = Color(0xFF3F51B5); // 인디고 색상

    return WillPopScope(
      onWillPop: () async {
        widget.onReject();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Terms of Service'),
          backgroundColor: themeColor,
          centerTitle: true,
          elevation: 0,
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [themeColor, themeColor.withOpacity(0.8)],
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Container(
                      margin: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'Please agree to the Privacy Policy to use the service',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Divider(height: 1, thickness: 1),
                          Expanded(
                            child: Scrollbar(
                              controller: _scrollController,
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: SingleChildScrollView(
                                  controller: _scrollController,
                                  physics: BouncingScrollPhysics(),
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Text(
                                      PrivacyPolicy.privacyPolicyText,
                                      style: TextStyle(
                                        fontSize: 14,
                                        height: 1.5,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (!_reachedEnd)
                            Container(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              color: Colors.amber.shade100,
                              width: double.infinity,
                              alignment: Alignment.center,
                              child: Text(
                                'Please read to the end to continue',
                                style: TextStyle(
                                  color: Colors.amber.shade900,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          // 강한 진동 효과
                          HapticFeedback.heavyImpact();

                          // 약간의 지연 후 앱 강제 종료
                          Future.delayed(Duration(milliseconds: 200), () {
                            // 앱 강제 종료
                            exit(0); // 가장 강력한 종료 방법, 앱이 즉시 종료됩니다
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          elevation: 5,
                        ),
                        child: Text(
                          'Decline',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed:
                            _reachedEnd
                                ? () {
                                  HapticFeedback.mediumImpact();
                                  widget.onAccept();
                                }
                                : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          elevation: 5,
                          disabledBackgroundColor: Colors.grey,
                        ),
                        child: Text(
                          'Accept',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
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
    );
  }
}
