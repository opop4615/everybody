import 'package:everyvaluation/screen/splash.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

//https://ipt9nj2vdb.execute-api.ap-northeast-2.amazonaws.com/everyvalue/
//API주소

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: '모두의밸류에이션',
      theme: ThemeData(
        useMaterial3: true,
          primarySwatch: Colors.blue,
          brightness: Brightness.dark,
          primaryColor: const Color.fromARGB(255, 10, 38, 71),
          scaffoldBackgroundColor: const Color.fromARGB(255, 10, 38, 71),
          fontFamily: 'nanum'),
      home: SplashView(),
    );
  }
}
