import 'package:flutter/material.dart';

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
    return TopBar();
  }
}

class TopBar extends StatelessWidget{
  @override
  Widget build(BuildContext context){
    return Container(
      padding: EdgeInsets.fromLTRB(20, 7, 20, 7),
      child: Row(
        children: [
          //Image.asset('asset/images/logo.png', fit: BoxFit.contain, height: 25,),
          Text("모두의밸류에이션", style: TextStyle(fontWeight: FontWeight.w500, fontSize: 20, letterSpacing: -1.5),),
        ],
      ),
      
    );
  }
}









