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
  // 1) INIT
  // ---------------------------------------------------------------------------
  Future<void> _initializeNotifications() async {
    if (_isInitialized) return;

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: iosSettings,
    );

    await flutterLocalNotificationsPlugin.initialize(initSettings);

    await _createAndroidChannels();

    _isInitialized = true;
    developer.log("✅ NotificationService initialized");
  }

  // ---------------------------------------------------------------------------
  // 2) Android Channels
  // ---------------------------------------------------------------------------
  Future<void> _createAndroidChannels() async {
    final android =
        flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    if (android == null) return;

    final List<String> sounds = [
      'yasir',
      'naseer',
      'mishary',
      'abdulbasit',
      'notification',
    ];

    for (final s in sounds) {
      final channel = AndroidNotificationChannel(
        'prayer_channel_$s',
        'أذان $s',
        description: 'صوت الأذان ($s)',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(s),
      );
      await android.createNotificationChannel(channel);
    }

    // silent reminder
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        'prayer_reminder_channel',
        'تذكير الصلاة',
        description: 'تنبيهات بدون صوت',
        importance: Importance.high,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3) Permissions
  // ---------------------------------------------------------------------------
  Future<bool> requestPermissions() async {
    try {
      final ios =
          flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >();

      if (ios != null) {
        return await ios.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            true;
      }

      final android =
          flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      if (android != null) {
        return await android.requestNotificationsPermission() ?? true;
      }

      return true;
    } catch (e) {
      developer.log("⚠️ requestPermissions error: $e");
      return false;
    }
  }

  // required by settings page
  Future<bool> areNotificationsEnabled() async {
    try {
      final android =
          flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      if (android != null) {
        return await android.areNotificationsEnabled() ?? true;
      }

      return true;
    } catch (_) {
      return true;
    }
  }

  // required by settings page
  Future<bool> ensureExactAlarmsEnabled() async {
    try {
      final android =
          flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      if (android != null) {
        return await android.requestExactAlarmsPermission() ?? true;
      }
      return true;
    } catch (_) {
      return true;
    }
  }

  // ---------------------------------------------------------------------------
  // 4) Immediate notification
  // ---------------------------------------------------------------------------
  Future<void> showImmediateNotification({
    required int id,
    required String title,
    required String body,
    String? soundFileName,
  }) async {
    await _ensureInitialized();

    String channelId = "prayer_reminder_channel";
    AndroidNotificationDetails androidDetails;

    if (soundFileName != null) {
      final raw = soundFileName.split('.').first;
      channelId = "prayer_channel_$raw";
      androidDetails = AndroidNotificationDetails(
        channelId,
        'أذان',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(raw),
      );
    } else {
      androidDetails = const AndroidNotificationDetails(
        "prayer_reminder_channel",
        "تذكير",
        importance: Importance.high,
        playSound: false,
      );
    }

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
    );

    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) await _initializeNotifications();
  }

  // ---------------------------------------------------------------------------
  // 5) Schedule internal
  // ---------------------------------------------------------------------------
  Future<void> _schedulePrayer({
    required int id,
    required DateTime scheduled,
    required String title,
    required String body,
    required String soundFileName,
    bool silent = false,
  }) async {
    await _ensureInitialized();

    if (scheduled.isBefore(DateTime.now())) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    final tzTime = tz.TZDateTime.from(scheduled, tz.local);

    String channelId =
        silent
            ? "prayer_reminder_channel"
            : "prayer_channel_${soundFileName.split('.').first}";

    final android = AndroidNotificationDetails(
      channelId,
      title,
      importance: Importance.max,
      playSound: !silent,
      sound:
          silent
              ? null
              : RawResourceAndroidNotificationSound(
                soundFileName.split('.').first,
              ),
    );

    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
    );

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tzTime,
      NotificationDetails(android: android, iOS: ios),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: null, // تستخدم للتكرار اليومي (غير مستخدمة هنا)
    );
  }

  // ---------------------------------------------------------------------------
  // 6) Schedule all prayer notifications
  // ---------------------------------------------------------------------------
  Future<void> scheduleAllNotifications(PrayerTimes t) async {
    await _ensureInitialized();
    final prefs = await SharedPreferences.getInstance();

    final voice = prefs.getString(kPrayerVoiceKey) ?? 'mishary.mp3';
    final preFajrEnabled = prefs.getBool(kPreFajrReminderEnabled) ?? true;

    await flutterLocalNotificationsPlugin.cancelAll();

    // reminder 10 mins before fajr
    if (preFajrEnabled) {
      await _schedulePrayer(
        id: 0,
        scheduled: t.fajr.subtract(const Duration(minutes: 10)),
        title: "تذكير قبل الفجر",
        body: "تبقى 10 دقائق على أذان الفجر.",
        soundFileName: "notification.mp3",
      );
    }

    // main prayers
    int id = 1;
    final entries = {
      Prayer.fajr: "الفجر",
      Prayer.dhuhr: "الظهر",
      Prayer.asr: "العصر",
      Prayer.maghrib: "المغرب",
      Prayer.isha: "العشاء",
    };

    for (final e in entries.entries) {
      await _schedulePrayer(
        id: id++,
        scheduled: t.timeForPrayer(e.key)!,
        title: "حان الآن موعد ${e.value}",
        body: "الله أكبر، حي على الصلاة.",
        soundFileName: voice,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // 7) Cancel All
  // ---------------------------------------------------------------------------
  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }
}
