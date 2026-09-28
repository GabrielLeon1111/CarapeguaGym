import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../data/models/member_status.dart';
import '../../data/repositories/member_repository.dart';
import '../../data/repositories/settings_repository.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _plugin.initialize(
      settings: const InitializationSettings(android: androidInit, iOS: iosInit),
    );
    _initialized = true;
  }

  Future<void> requestPermissions() async {
    await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    await _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Recalcula y reprograma todos los avisos de vencimiento en base a los socios activos
  /// y la configuración vigente. Se debe llamar al abrir la app y luego de cada cobro.
  Future<void> rescheduleAll(MemberRepository memberRepo, SettingsRepository settingsRepo) async {
    await _plugin.cancelAll();
    final settings = await settingsRepo.get();
    final statuses = await memberRepo.getStatuses();

    var id = 1000;
    for (final s in statuses) {
      if (s.endDate == null || s.status == MemberStatusKind.congelado) continue;

      if (settings.notifyBeforeDueDays > 0) {
        final fireDate = s.endDate!.subtract(Duration(days: settings.notifyBeforeDueDays));
        await _scheduleAt(id++, fireDate, '${s.fullName} está por vencer', 'Vence el ${_fmt(s.endDate!)} (en ${settings.notifyBeforeDueDays} días)');
      }
      if (settings.notifyOnDueDay) {
        await _scheduleAt(id++, s.endDate!, '${s.fullName} vence hoy', 'La membresía vence hoy');
      }
      if (settings.notifyOverdueDays > 0) {
        final overdueDate = s.endDate!.add(Duration(days: settings.notifyOverdueDays));
        await _scheduleAt(id++, overdueDate, '${s.fullName} está moroso', 'Lleva ${settings.notifyOverdueDays} días de atraso');
      }
    }

    if (settings.notifyDailySummary) {
      await _scheduleDailySummary();
    }
    if (settings.notifyWeeklySummary) {
      await _scheduleWeeklySummary();
    }
  }

  Future<void> _scheduleWeeklySummary() async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 20);
    while (scheduled.weekday != DateTime.sunday || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    await _plugin.zonedSchedule(
      id: 998,
      title: 'Resumen semanal',
      body: 'Revisá los ingresos de la semana y los socios por vencer en Fitness Gym',
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails('resumen', 'Resumen', importance: Importance.defaultImportance),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  Future<void> _scheduleAt(int id, DateTime date, String title, String body) async {
    final scheduled = tz.TZDateTime.from(DateTime(date.year, date.month, date.day, 9), tz.local);
    if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) return;
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails('vencimientos', 'Vencimientos', importance: Importance.high, priority: Priority.high),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> _scheduleDailySummary() async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 20);
    if (scheduled.isBefore(now)) scheduled = scheduled.add(const Duration(days: 1));
    await _plugin.zonedSchedule(
      id: 999,
      title: 'Resumen diario',
      body: 'Revisá los ingresos y vencimientos de hoy en Fitness Gym',
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails('resumen', 'Resumen', importance: Importance.defaultImportance),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  String _fmt(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
