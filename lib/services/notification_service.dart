import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/app_store.dart';
import 'reminder_planner.dart';

/// Schedules the app's local notifications.
///
/// Rather than tracking individual notification ids, every change to the
/// data re-plans the whole set: pending notifications are cancelled and the
/// current plan (see [planReminders]) is scheduled again.
class NotificationService {
  NotificationService._();

  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  Timer? _debounce;

  /// Receives the payload of a tapped notification (see [ReminderTarget]).
  final taps = StreamController<String>.broadcast();

  /// Payload of the notification that launched the app, if any.
  String? launchPayload;

  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  Future<void> init() async {
    if (!_supported || _ready) return;
    try {
      tzdata.initializeTimeZones();
      try {
        final zone = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(zone.identifier));
      } catch (e) {
        debugPrint('Falling back to Africa/Cairo time zone: $e');
        tz.setLocalLocation(tz.getLocation('Africa/Cairo'));
      }

      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload != null) taps.add(payload);
        },
      );

      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        launchPayload = launch!.notificationResponse?.payload;
      }
      _ready = true;
    } catch (e) {
      debugPrint('Notifications unavailable: $e');
    }
  }

  /// Asks for permission to post notifications (Android 13+, iOS).
  Future<bool> requestPermission() async {
    if (!_ready) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _android?.requestNotificationsPermission() ?? false;
    }
    return await _ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        false;
  }

  Future<bool> areEnabled() async {
    if (!_ready) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _android?.areNotificationsEnabled() ?? false;
    }
    final perms = await _ios?.checkPermissions();
    return perms?.isEnabled ?? false;
  }

  /// Android only: whether reminders fire at the exact minute.
  Future<bool> canScheduleExact() async {
    if (!_ready || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    return await _android?.canScheduleExactNotifications() ?? false;
  }

  Future<void> requestExactAlarms() async {
    if (!_ready || defaultTargetPlatform != TargetPlatform.android) return;
    await _android?.requestExactAlarmsPermission();
  }

  Future<int> pendingCount() async {
    if (!_ready) return 0;
    return (await _plugin.pendingNotificationRequests()).length;
  }

  Future<void> showTest() async {
    if (!_ready) return;
    await _plugin.show(
      id: 999999,
      title: 'الإشعارات شغالة ✅',
      body: 'هفكرك بمحاضراتك وكويزاتك وتسليماتك في معادها',
      notificationDetails: _details(ReminderChannel.classes, ''),
      payload: ReminderTarget.home,
    );
  }

  /// Re-plans all notifications shortly after the data stops changing.
  void scheduleSoon(AppStore store) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 800),
      () => rescheduleAll(store),
    );
  }

  Future<void> rescheduleAll(AppStore store) async {
    if (!_ready) return;
    try {
      // Cancels only pending ones, so already-shown notifications stay.
      await _plugin.cancelAllPendingNotifications();
      final limit = defaultTargetPlatform == TargetPlatform.iOS ? 60 : 300;
      final plan = planReminders(store, DateTime.now(), limit: limit);
      if (plan.isEmpty) return;
      final mode = await canScheduleExact()
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;
      var id = 1;
      for (final r in plan) {
        final when = tz.TZDateTime(
          tz.local,
          r.when.year,
          r.when.month,
          r.when.day,
          r.when.hour,
          r.when.minute,
        );
        await _plugin.zonedSchedule(
          id: id++,
          title: r.title,
          body: r.body,
          scheduledDate: when,
          notificationDetails: _details(r.channel, r.body),
          androidScheduleMode: mode,
          payload: r.payload,
          matchDateTimeComponents: r.weekly
              ? DateTimeComponents.dayOfWeekAndTime
              : null,
        );
      }
    } catch (e) {
      debugPrint('Failed to schedule notifications: $e');
    }
  }

  NotificationDetails _details(ReminderChannel channel, String body) {
    final (id, name, description) = switch (channel) {
      ReminderChannel.classes => (
        'classes',
        'مواعيد المحاضرات',
        'تنبيه قبل المحاضرات والسكاشن',
      ),
      ReminderChannel.deadlines => (
        'deadlines',
        'الكويزات والتسليمات',
        'تنبيهات الكويزات والأسايمنتات والمشاريع والتاسكات',
      ),
      ReminderChannel.daily => ('daily', 'ملخص اليوم', 'ملخص الصبح لخطة اليوم'),
    };
    return NotificationDetails(
      android: AndroidNotificationDetails(
        id,
        name,
        channelDescription: description,
        importance: channel == ReminderChannel.daily
            ? Importance.defaultImportance
            : Importance.high,
        priority: channel == ReminderChannel.daily
            ? Priority.defaultPriority
            : Priority.high,
        styleInformation: BigTextStyleInformation(body),
        category: channel == ReminderChannel.daily
            ? null
            : AndroidNotificationCategory.reminder,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBanner: true,
        presentSound: true,
      ),
    );
  }
}
