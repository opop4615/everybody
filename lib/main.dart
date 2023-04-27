import 'dart:io';

import 'package:everyvaluation/firebase_options.dart';
import 'package:everyvaluation/screen/splash.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
//https://ipt9nj2vdb.execute-api.ap-northeast-2.amazonaws.com/everyvalue/
//API주소


//인증서무시(Build할때 빼자)
class MyHttpOverrides extends HttpOverrides{
  @override
  HttpClient createHttpClient(SecurityContext? context){
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port)=> true;
  }
}


void main() async{
  HttpOverrides.global = MyHttpOverrides(); //요것도 인증서 무시, Build할때 빼자
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

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
