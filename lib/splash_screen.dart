import 'package:flutter/material.dart';
import 'package:myapp/home_screen.dart'; // تأكدي من المسار ده صح لملف home_screen.dart

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToHome(); // استدعاء دالة الانتقال بعد انتهاء الـ Splash
  }

  _navigateToHome() async {
    // الانتظار لمدة 0 ملي ثانية للانتقال السريع بعد الـ Native Splash
    await Future.delayed(const Duration(milliseconds: 0), () {});

    // الانتقال إلى الشاشة الرئيسية (HomeScreen) واستبدال Splash Screen بها
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // جعل خلفية الـ Scaffold شفافة لكي تندمج مع الـ Native Splash Screen
      // أو وضع لون Teal إذا لم يتم إعداد Native Splash Screen بشكل كامل
      backgroundColor: Colors.transparent, // أو Colors.teal إذا أردتِ لونا محددا هنا
      body: Stack( // استخدام Stack لوضع العناصر فوق بعضها
        fit: StackFit.expand, // لجعل الـ Stack يملأ الشاشة بالكامل
        children: [
          // الصورة كخلفية تملأ الشاشة بالكامل
          Image.asset(
            'assets/images/splash_image.png', // تأكدي من مسار الصورة واسمها الجديد
            fit: BoxFit.cover, // لجعل الصورة تملأ المساحة المتاحة مع الحفاظ على نسبة العرض للارتفاع
          ),
          // مؤشر التحميل في المنتصف
          const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
