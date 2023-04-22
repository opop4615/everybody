import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';

class ValuationScreen extends StatefulWidget {
  _ValuationScreenState createState() => _ValuationScreenState();
}

class _ValuationScreenState extends State<ValuationScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ValuationPage();
  }
}

class ValuationPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: EdgeInsets.fromLTRB(25, 7, 25, 7),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(
                  height: 15,
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  "모두의\n밸류에이션",
                  style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 25,
                      letterSpacing: -1.5),
                ),
              ],
            ),
            Row(
              children: [
                SizedBox(
                  height: 5,
                )
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  '모두를 위한 주식 가치평가 어플리케이션',
                  style: TextStyle(
                      fontWeight: FontWeight.w100,
                      fontSize: 15,
                      letterSpacing: -1),
                )
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [],
            )
          ],
        ),
      ),
    );
  }
}
