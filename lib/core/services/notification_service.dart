import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // 1. Initialize Timezone Data (Crucial for scheduled notifications)
    tz.initializeTimeZones();

    // 2. Set Local Location exactly as done in SubscriptionService
    try {
      final String rawTimezone = (await FlutterTimezone.getLocalTimezone())
          .toString();
      final String timeZoneName = rawTimezone.contains('(')
          ? rawTimezone.split('(')[1].split(',')[0]
          : rawTimezone;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      debugPrint("Could not set local location, defaulting to UTC: $e");
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('ic_stat_ledgr');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
        );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<bool> requestPermission() async {
    if (Platform.isIOS) {
      final bool? result = await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return result ?? false;
    } else if (Platform.isAndroid) {
      final status = await Permission.notification.request();
      return status.isGranted;
    }
    return false;
  }

  Future<void> showLimitAlert({
    required int id,
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'budget_limits_channel',
          'Budget Limits',
          channelDescription:
              'Alerts for when you exceed daily or monthly budget limits',
          importance: Importance.max,
          priority: Priority.high,
        );
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails();
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );
    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
    );
  }

  Future<void> scheduleDailySummary({
    required int id,
    required String title,
    required String body,
  }) async {
    final now = DateTime.now();
    // Use native DateTime math first
    var scheduledDate = DateTime(now.year, now.month, now.day, 22, 0, 0);

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    // Convert to TZDateTime only at the end
    final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);

    const AndroidNotificationDetails
    androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'summaries_channel_v2', // <-- CHANGED: Forces Android to create a fresh channel
      'Daily/Weekly Summaries',
      channelDescription: 'Periodic summaries of your spending',
      importance: Importance.high, // <-- CHANGED: Matches SubscriptionService
      priority: Priority.high, // <-- CHANGED: Matches SubscriptionService
      icon: 'ic_stat_ledgr', // <-- CHANGED: Explicitly defined
    );
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails();
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tzScheduledDate,
      platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents:
          DateTimeComponents.time, // Repeats daily at this time
    );
  }

  Future<void> scheduleWeeklySummary({
    required int id,
    required String title,
    required String body,
  }) async {
    final now = DateTime.now();

    // Find days until next Sunday
    int daysUntilSunday = DateTime.sunday - now.weekday;
    if (daysUntilSunday < 0) {
      daysUntilSunday += 7;
    }

    var scheduledDate = DateTime(
      now.year,
      now.month,
      now.day,
      22,
      0,
      0,
    ).add(Duration(days: daysUntilSunday));

    // If today is Sunday but past 10 PM, schedule for next week
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 7));
    }

    final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);

    const AndroidNotificationDetails
    androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'summaries_channel_v2', // <-- CHANGED: Forces Android to create a fresh channel
      'Daily/Weekly Summaries',
      channelDescription: 'Periodic summaries of your spending',
      importance: Importance.high, // <-- CHANGED: Matches SubscriptionService
      priority: Priority.high, // <-- CHANGED: Matches SubscriptionService
      icon: 'ic_stat_ledgr', // <-- CHANGED: Explicitly defined
    );
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails();
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tzScheduledDate,
      platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents:
          DateTimeComponents.dayOfWeekAndTime, // Repeats weekly
    );
  }

  Future<void> scheduleMonthlySummary({
    required int id,
    required String title,
    required String body,
  }) async {
    final now = DateTime.now();

    // Determine the last day of the current month
    int nextMonth = now.month + 1;
    int year = now.year;
    if (nextMonth > 12) {
      nextMonth = 1;
      year += 1;
    }
    int lastDay = DateTime(year, nextMonth, 0).day;

    var scheduledDate = DateTime(now.year, now.month, lastDay, 22, 0, 0);

    // If we are past 10 PM on the last day of the current month, schedule for next month
    if (scheduledDate.isBefore(now)) {
      int nextNextMonth = nextMonth + 1;
      int nextYear = year;
      if (nextNextMonth > 12) {
        nextNextMonth = 1;
        nextYear += 1;
      }
      int nextLastDay = DateTime(nextYear, nextNextMonth, 0).day;
      scheduledDate = DateTime(year, nextMonth, nextLastDay, 22, 0, 0);
    }

    final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);

    const AndroidNotificationDetails
    androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'summaries_channel_v2', // <-- CHANGED: Forces Android to create a fresh channel
      'Daily/Weekly Summaries',
      channelDescription: 'Periodic summaries of your spending',
      importance: Importance.high, // <-- CHANGED: Matches SubscriptionService
      priority: Priority.high, // <-- CHANGED: Matches SubscriptionService
      icon: 'ic_stat_ledgr', // <-- CHANGED: Explicitly defined
    );
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails();
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tzScheduledDate,
      platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents:
          DateTimeComponents.dayOfMonthAndTime, // Repeats monthly
    );
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'summaries_channel',
          'Daily/Weekly Summaries',
          importance: Importance.max,
          priority: Priority.high,
        );
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails();
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );
    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
    );
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);

    const AndroidNotificationDetails
    androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'summaries_channel_v2', // <-- CHANGED: Forces Android to create a fresh channel
      'Daily/Weekly Summaries',
      channelDescription: 'Periodic summaries of your spending',
      importance: Importance.high, // <-- CHANGED: Matches SubscriptionService
      priority: Priority.high, // <-- CHANGED: Matches SubscriptionService
      icon: 'ic_stat_ledgr', // <-- CHANGED: Explicitly defined
    );
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails();
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tzDate,
      platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }
}
