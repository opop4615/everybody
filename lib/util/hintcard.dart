import 'package:flutter/material.dart';

class HintCard extends StatelessWidget {
  final String valuationName;
  final String hintText;

  HintCard({
    required this.valuationName,
    required this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 15.0),
      child: Container(
        width: 150,
        decoration: BoxDecoration(color: Color.fromARGB(255, 20, 66, 114)),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                children: [
                  Text(
                    this.valuationName,
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 20),
                  ),
                  SizedBox(
                    height: 3,
                  ),
                  Text(this.hintText)
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
