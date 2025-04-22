import 'package:TAGO/brand_colors.dart';
import 'package:flutter/material.dart';

class TaxiOutlineButton extends StatelessWidget {
  final String title;
  final VoidCallback onPressed;
  final Color color;

  const TaxiOutlineButton({
    Key? key,
    required this.title,
    required this.onPressed,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25.0),
        ),
        foregroundColor: color,
      ),
      onPressed: onPressed,
      child: Container(
        height: 50.0,
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 15.0,
              fontFamily: 'Brand-Bold',
              color: BrandColors.colorText,
            ),
          ),
        ),
      ),
    );
  }
}
