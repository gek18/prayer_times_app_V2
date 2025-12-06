import 'dart:developer' as developer;
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
  // 🔹 1) تهيئة الإشعارات — Android + iOS
  // ---------------------------------------------------------------------------
  Future<void> _initializeNotifications() async {
    if (_isInitialized) return;

    const AndroidInitializationSettings initAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initDarwin =
        DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );

    const InitializationSettings settings = InitializationSettings(
      android: initAndroid,
      iOS: initDarwin,
      macOS: initDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        developer.log("📩 Notification clicked → ${response.payload}");
      },
    );

    await _createNotificationChannels();
    _isInitialized = true;
    developer.log('✅ NotificationService initialized');
  }

  // ---------------------------------------------------------------------------
  // 🔹 2) إنشاء القنوات الصوتية للأذان
  // ---------------------------------------------------------------------------
  static const List<String> _muezzinRawSounds = [
    'yasir',
    'naseer',
    'mishary',
    'abdulbasit',
    'notification', // تذكير قبل الفجر
  ];

  Future<void> _createNotificationChannels() async {
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

    // قناة التذكيرات
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        'prayer_reminder_channel',
        'تذكيرات الصلاة',
        description: 'تنبيهات بدون صوت',
        importance: Importance.high,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 🔹 3) صلاحيات إشعارات Android 12+ (Exact Alarm)
  // ---------------------------------------------------------------------------
  Future<bool> ensureExactAlarmsEnabled() async {
    final android =
        flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    if (android == null) return true;

    try {
      final granted = await android.requestExactAlarmsPermission();
      return granted ?? true;
    } catch (_) {
      return true;
    }
  }

  // ---------------------------------------------------------------------------
  // 🔹 4) فحص هل الإشعارات مسموحة — Android + iOS
  // ---------------------------------------------------------------------------
  Future<bool> areNotificationsEnabled() async {
    try {
      // ANDROID
      final android =
          flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      if (android != null) {
        return await android.areNotificationsEnabled() ?? true;
      }

      // iOS — لا يوجد API لفحص الإذن مباشرة → نستخدم requestPermissions
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
      developer.log("⚠️ Permission check error: $e");
      return true;
    }
  }

  // ---------------------------------------------------------------------------
  // 🔹 5) طلب صلاحيات الإشعارات (Android + iOS)
  // ---------------------------------------------------------------------------
  Future<bool> requestPermissions() async {
    try {
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
    } catch (e) {
      developer.log("⚠️ Error requesting permissions: $e");
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // 🔹 6) عرض إشعار فوري
  // ---------------------------------------------------------------------------
  Future<void> showImmediateNotification({
    required String title,
    required String body,
    required int id,
    String? soundFileName,
  }) async {
    await _ensureInitialized();

    final raw = soundFileName?.split('.').first;
    final channelId =
        raw != null ? 'prayer_channel_$raw' : 'prayer_reminder_channel';

    final androidDetails = AndroidNotificationDetails(
      channelId,
      'مواقيت الصلاة',
      importance: Importance.max,
      priority: Priority.high,
      playSound: raw != null,
      sound: raw != null ? RawResourceAndroidNotificationSound(raw) : null,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
    );

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
  // 🔹 7) جدولة إشعار
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

    final exactAllowed = await ensureExactAlarmsEnabled();
    final mode =
        exactAllowed
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle;

    if (scheduledTime.isBefore(DateTime.now())) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    final tzTime = tz.TZDateTime.from(scheduledTime, tz.local);
    final raw = soundFileName.split('.').first;

    final channelId =
        isSilent ? 'prayer_reminder_channel' : 'prayer_channel_$raw';

    final androidDetails = AndroidNotificationDetails(
      channelId,
      isSilent ? 'تذكير' : 'أذان',
      importance: Importance.max,
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
  }

  // ---------------------------------------------------------------------------
  // 🔹 8) جدولة جميع الصلوات + تذكير قبل الفجر
  // ---------------------------------------------------------------------------
  Future<void> scheduleAllNotifications(PrayerTimes times) async {
    await _ensureInitialized();
    final prefs = await SharedPreferences.getInstance();

    final voice = prefs.getString(kPrayerVoiceKey) ?? 'mishary.mp3';
    final reminderEnabled = prefs.getBool(kPreFajrReminderEnabled) ?? true;

    await flutterLocalNotificationsPlugin.cancelAll();

    // تذكير قبل الفجر 10 دقائق
    if (reminderEnabled) {
      final reminder = times.fajr.subtract(const Duration(minutes: 10));
      await _schedulePrayerNotification(
        scheduledTime: reminder,
        title: 'تذكير قبل الفجر',
        body: 'تبقى 10 دقائق على أذان الفجر.',
        id: 0,
        soundFileName: 'notification.mp3',
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
      final t = times.timeForPrayer(entry.key)!;
      await _schedulePrayerNotification(
        scheduledTime: t,
        title: 'حان الآن موعد ${entry.value}',
        body: 'الله أكبر، حي على الصلاة.',
        id: id++,
        soundFileName: voice,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // 🔹 9) حذف كل الإشعارات المقررة
  // ---------------------------------------------------------------------------
  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }
}
