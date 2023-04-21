import 'package:everyvaluation/screen/home.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:flutter_login/flutter_login.dart';

void main() => runApp(const MyApp());


class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: '모두의 밸류에이션',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
        primaryColor:const Color.fromARGB(255, 10, 38, 71),
        scaffoldBackgroundColor: const Color.fromARGB(255, 10, 38, 71),
        fontFamily: 'nanum'
      ),
      home: MyHomePage(),
    );
  }
}
