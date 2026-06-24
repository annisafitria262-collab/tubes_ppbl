import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../../../core/utils/shared_prefs_helper.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    if (kIsWeb || !Platform.isAndroid) return;

    // Inisialisasi Zona Waktu
    tz.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
    } catch (_) {
      // Fallback jika timezone lokal tidak ditemukan
    }

    const AndroidInitializationSettings initializationSettingsAndroid = 
        AndroidInitializationSettings('@mipmap/ic_launcher');
        
    const InitializationSettings initializationSettings = 
        InitializationSettings(android: initializationSettingsAndroid);
        
    await _notificationsPlugin.initialize(initializationSettings);

    // Minta izin runtime di Android saat inisialisasi awal
    await requestPermission();
  }

  static Future<bool> requestPermission() async {
    if (kIsWeb || !Platform.isAndroid) return true;

    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      final bool? granted = await androidImplementation.requestNotificationsPermission();
      return granted ?? false;
    }
    return true;
  }

  static Future<void> tampilkanNotifikasiBelanja() async {
    if (kIsWeb || !Platform.isAndroid) {
      Fluttertoast.showToast(
        msg: "Fitur notifikasi belanja hanya aktif di platform Android.",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
      return;
    }

    // Pastikan izin sudah diberikan sebelum menampilkan notifikasi
    final isGranted = await requestPermission();
    if (!isGranted) {
      Fluttertoast.showToast(
        msg: "Izin notifikasi ditolak. Aktifkan izin di pengaturan perangkat.",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    String shoppingDay = SharedPrefsHelper.shoppingDay; 

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'belanja_channel',
      'Pengingat Belanja',
      channelDescription: 'Notifikasi jadwal belanja mingguan otomatis',
      importance: Importance.max,
      priority: Priority.high,
      color: Color(0xFF2E7D32),
    );
    
    const NotificationDetails details = NotificationDetails(android: androidDetails);
    
    await _notificationsPlugin.show(
      0,
      'Waktunya Belanja! 🛒',
      'Hari ini jadwal kamu belanja sesuai setting ($shoppingDay). Cek daftar belanja sekarang!',
      details,
    );
  }

  // --- FITUR BARU: PENJADWALAN MINGGUAN KUSTOM ---
  static int _getDayIndex(String day) {
    switch (day.toLowerCase()) {
      case 'senin': return DateTime.monday;
      case 'selasa': return DateTime.tuesday;
      case 'rabu': return DateTime.wednesday;
      case 'kamis': return DateTime.thursday;
      case 'jumat': return DateTime.friday;
      case 'sabtu': return DateTime.saturday;
      case 'minggu': return DateTime.sunday;
      default: return DateTime.monday;
    }
  }

  static tz.TZDateTime _nextInstanceOfDayAndTime(int dayIndex, int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    while (scheduledDate.weekday != dayIndex) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 7));
    }
    return scheduledDate;
  }

  static Future<void> scheduleWeeklyNotification({
    required int id,
    required String title,
    required String body,
    required String day,
    required int hour,
    required int minute,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return;

    int dayIndex = _getDayIndex(day);

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      _nextInstanceOfDayAndTime(dayIndex, hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'jadwal_channel',
          'Pengingat Jadwal',
          channelDescription: 'Notifikasi pengingat makan dan belanja kustom',
          importance: Importance.max,
          priority: Priority.high,
          color: Color(0xFF2E7D32),
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  static Future<void> cancelNotification(int id) async {
    if (kIsWeb || !Platform.isAndroid) return;
    await _notificationsPlugin.cancel(id);
  }
}