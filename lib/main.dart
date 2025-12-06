import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:prayer_times_app/presentation/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ تهيئة التقويم الهجري
  HijriCalendar.setLocal('ar');

  // ✅ تهيئة إعلانات جوجل
  try {
    await MobileAds.instance.initialize();
    developer.log('✅ MobileAds initialized');
  } catch (e) {
    developer.log('⚠️ MobileAds init error: $e');
  }

  // ✅ تهيئة المناطق الزمنية
  try {
    tzdata.initializeTimeZones();

    final currentTimeZone = await FlutterTimezone.getLocalTimezone();

    // ✅ تحويل TimezoneInfo إلى String
    tz.setLocalLocation(tz.getLocation(currentTimeZone.toString()));

    developer.log('✅ Timezone set to: ${tz.local.name}');
  } catch (e) {
    developer.log('⚠️ Timezone error: $e');

    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
      developer.log('⚠️ Using fallback timezone: Europe/Istanbul');
    } catch (fallbackError) {
      developer.log('❌ Critical timezone error: $fallbackError');
    }
  }

  final now = tz.TZDateTime.now(tz.local);
  developer.log('⏰ Current local time: $now');

  runApp(
    ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) => const ProviderScope(child: PrayerApp()),
    ),
  );
}

class PrayerApp extends StatelessWidget {
  const PrayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final tajawalTheme = GoogleFonts.tajawalTextTheme(
      Theme.of(context).textTheme,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'أوقات الصلاة',
      locale: const Locale('ar', 'SA'),
      supportedLocales: const [Locale('ar', 'SA')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.transparent,
        primaryColor: Colors.tealAccent,
        textTheme: tajawalTheme.copyWith(
          bodyLarge: const TextStyle(color: Color.fromARGB(222, 255, 255, 255)),
          titleLarge: tajawalTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
