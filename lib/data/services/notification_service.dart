import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adhan/adhan.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:hooks_riverpod/hooks_riverpod.dart';

final notificationServiceProvider = Provider((ref) => NotificationService());

const String kPrayerVoiceKey = 'prayer_voice_key';
const String kPreFajrReminderEnabled = 'pre_fajr_reminder_enabled';

class NotificationService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  NotificationService() {
    _initializeNotifications();
  }

  // ---------------------------------------------------------------------------
  // 1) التهيئة العامة
  // ---------------------------------------------------------------------------
  Future<void> _initializeNotifications() async {
    if (_isInitialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const settings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );

    await flutterLocalNotificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        developer.log('📩 Notification tapped: ${response.payload}');
      },
    );

    // Android فقط: إنشاء قنوات الأصوات
    if (Platform.isAndroid) {
      await _createAndroidChannels();
    }

    _isInitialized = true;
    developer.log('✅ NotificationService initialized');
  }

  // ---------------------------------------------------------------------------
  // 2) قنوات أندرويد
  // ---------------------------------------------------------------------------
  static const List<String> _muezzinRawSounds = [
    'yasir',
    'naseer',
    'mishary',
    'abdulbasit',
    'notification', // نغمة قصيرة / تذكير
  ];

  Future<void> _createAndroidChannels() async {
    final android =
        flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    if (android == null) return;

    for (final sound in _muezzinRawSounds) {
      final channel = AndroidNotificationChannel(
        'prayer_channel_$sound',
        'أذان/تنبيه (${sound.toUpperCase()})',
        description: 'تنبيهات الصلاة بصوت $sound',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(sound),
      );
      await android.createNotificationChannel(channel);
    }

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        'prayer_reminder_channel',
        'تذكيرات الصلاة',
        description: 'تنبيهات بدون صوت مخصص',
        importance: Importance.high,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3) صلاحيات
  // ---------------------------------------------------------------------------
  Future<bool> ensureExactAlarmsEnabled() async {
    if (!Platform.isAndroid) return true;

    final android =
        flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    if (android == null) return true;

    try {
      final granted = await android.requestExactAlarmsPermission();
      return granted ?? true;
    } catch (e) {
      developer.log('⚠️ Exact alarm permission error: $e');
      return true;
    }
  }

  Future<bool> areNotificationsEnabled() async {
    try {
      if (Platform.isAndroid) {
        final android =
            flutterLocalNotificationsPlugin
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >();
        if (android != null) {
          return await android.areNotificationsEnabled() ?? true;
        }
      }

      // iOS / macOS
      final ios =
          flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >();
      if (ios != null) {
        final granted = await ios.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? true;
      }

      return true;
    } catch (e) {
      developer.log('⚠️ areNotificationsEnabled error: $e');
      return true;
    }
  }

  Future<bool> requestPermissions() async {
    try {
      if (Platform.isAndroid) {
        final android =
            flutterLocalNotificationsPlugin
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >();
        if (android != null) {
          final granted = await android.requestNotificationsPermission();
          return granted ?? true;
        }
        return true;
      }

      // iOS
      final ios =
          flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >();
      if (ios != null) {
        final result = await ios.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return result ?? false;
      }

      // macOS
      final mac =
          flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                MacOSFlutterLocalNotificationsPlugin
              >();
      if (mac != null) {
        final result = await mac.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return result ?? false;
      }

      return true;
    } catch (e) {
      developer.log('⚠️ requestPermissions error: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // 4) إشعار فوري
  // ---------------------------------------------------------------------------
  Future<void> showImmediateNotification({
    required String title,
    required String body,
    required int id,
    String? soundFileName,
  }) async {
    await _ensureInitialized();

    AndroidNotificationDetails? androidDetails;
    DarwinNotificationDetails? iosDetails;

    if (Platform.isAndroid) {
      final raw = soundFileName != null ? _rawName(soundFileName) : null;
      final channelId =
          raw != null ? 'prayer_channel_$raw' : 'prayer_reminder_channel';

      androidDetails = AndroidNotificationDetails(
        channelId,
        'مواقيت الصلاة',
        importance: Importance.max,
        priority: Priority.high,
        playSound: raw != null,
        sound: raw != null ? RawResourceAndroidNotificationSound(raw) : null,
      );

      iosDetails = const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
      );
    } else if (Platform.isIOS) {
      // iOS → نغمة قصيرة من داخل الإشعار فقط
      final sound =
          soundFileName != null
              ? _iosFileName(soundFileName)
              : 'notification.caf';

      iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        sound: sound,
      );
    } else {
      iosDetails = const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
      );
    }

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await flutterLocalNotificationsPlugin.show(id, title, body, details);
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) await _initializeNotifications();
  }

  // ---------------------------------------------------------------------------
  // 5) جدولة إشعار صلاة واحد
  // ---------------------------------------------------------------------------
  Future<void> _schedulePrayerNotification({
    required DateTime scheduledTime,
    required String title,
    required String body,
    required int id,
    required String soundFileName,
    bool isSilent = false,
  }) async {
    await _ensureInitialized();

    if (scheduledTime.isBefore(DateTime.now())) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    final tzTime = tz.TZDateTime.from(scheduledTime, tz.local);

    // Android
    if (Platform.isAndroid) {
      final exactAllowed = await ensureExactAlarmsEnabled();
      final mode =
          exactAllowed
              ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexactAllowWhileIdle;

      final raw = _rawName(soundFileName);
      final channelId =
          isSilent ? 'prayer_reminder_channel' : 'prayer_channel_$raw';

      final androidDetails = AndroidNotificationDetails(
        channelId,
        isSilent ? 'تذكير' : 'أذان',
        importance: Importance.max,
        priority: Priority.high,
        playSound: !isSilent,
        sound: isSilent ? null : RawResourceAndroidNotificationSound(raw),
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
      );

      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzTime,
        NotificationDetails(android: androidDetails, iOS: iosDetails),
        androidScheduleMode: mode,
        matchDateTimeComponents: null,
      );
      return;
    }

    // iOS
    if (Platform.isIOS) {
      // ✅ خيارك 2: نغمة قصيرة فقط داخل الإشعار
      final iosSound = isSilent ? null : _iosFileName(soundFileName);

      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentSound: !isSilent,
        sound: iosSound,
      );

      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzTime,
        NotificationDetails(iOS: iosDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: null,
      );
      return;
    }

    // منصات أخرى
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tzTime,
      const NotificationDetails(
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: null,
    );
  }

  // ---------------------------------------------------------------------------
  // 6) جدولة كل الصلوات + تذكير قبل الفجر
  // ---------------------------------------------------------------------------
  Future<void> scheduleAllNotifications(PrayerTimes times) async {
    await _ensureInitialized();
    final prefs = await SharedPreferences.getInstance();

    // أندرويد فقط: صوت الأذان من الإعدادات
    final androidVoice = prefs.getString(kPrayerVoiceKey) ?? 'mishary.mp3';
    final reminderEnabled = prefs.getBool(kPreFajrReminderEnabled) ?? true;

    await flutterLocalNotificationsPlugin.cancelAll();

    // تذكير قبل الفجر بـ 10 دقائق
    if (reminderEnabled) {
      final reminderTime = times.fajr.subtract(const Duration(minutes: 10));
      await _schedulePrayerNotification(
        scheduledTime: reminderTime,
        title: 'تذكير قبل الفجر',
        body: 'تبقى 10 دقائق على أذان الفجر.',
        id: 0,
        soundFileName: Platform.isIOS ? 'notification.caf' : 'notification.mp3',
        isSilent: false,
      );
    }

    final prayers = {
      Prayer.fajr: 'الفجر',
      Prayer.dhuhr: 'الظهر',
      Prayer.asr: 'العصر',
      Prayer.maghrib: 'المغرب',
      Prayer.isha: 'العشاء',
    };

    int id = 1;
    for (final entry in prayers.entries) {
      final prayerTime = times.timeForPrayer(entry.key)!;

      final soundFileName = Platform.isIOS ? 'notification.caf' : androidVoice;

      await _schedulePrayerNotification(
        scheduledTime: prayerTime,
        title: 'حان الآن موعد ${entry.value}',
        body: 'الله أكبر، حي على الصلاة.',
        id: id++,
        soundFileName: soundFileName,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // 7) إلغاء الكل
  // ---------------------------------------------------------------------------
  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  String _rawName(String fileName) => fileName.split('.').first;

  /// iOS يتوقع اسم ملف مثل `mysound.caf` داخل الـ Bundle
  String _iosFileName(String fileName) {
    final base = _rawName(fileName);
    return '$base.caf';
  }
}
