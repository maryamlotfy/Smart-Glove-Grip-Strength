import 'package:flutter/material.dart';
import 'package:myapp/splash_screen.dart'; // استيراد شاشة البداية

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartGlove App',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const SplashScreen(), // هنا يتم تعيين شاشة البداية كأول شاشة
      debugShowCheckedModeBanner: false, // لإخفاء شعار DEBUG في وضع التطوير
    );
  }
}
