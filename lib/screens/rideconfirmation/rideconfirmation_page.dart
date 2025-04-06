import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cabrider/dataprovider/appdata.dart';
import 'package:cabrider/datamodels/address.dart';

class RideConfirmationPage extends StatefulWidget {
  @override
  _RideConfirmationPageState createState() => _RideConfirmationPageState();
}

class _RideConfirmationPageState extends State<RideConfirmationPage> {
  @override
  Widget build(BuildContext context) {
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    final backgroundColor = isDarkMode ? Colors.black : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final primaryColor = Color(0xFF3F51B5);

    final appData = Provider.of<AppData>(context);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          '예약 확인',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Text(
          '탑승 정보가 확인되었습니다',
          style: TextStyle(fontSize: 18, color: textColor),
        ),
      ),
    );
  }
}
