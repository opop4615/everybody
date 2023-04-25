import 'dart:async';
import 'package:everyvaluation/screen/home.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SplashView extends StatelessWidget {
  const SplashView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Timer(const Duration(seconds: 2), () {
      Get.to(home(),
          transition: Transition.fadeIn, duration: Duration(seconds: 1));
    });
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 10, 38, 71),
      body: const Center(
        child: Text(
          '모두의\n밸류에이션',
          style: TextStyle(
              fontSize: 12, letterSpacing: -2, fontWeight: FontWeight.w500),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
