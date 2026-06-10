import 'package:flutter/material.dart'; // Tambahkan baris ini
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../../core/utils/shared_prefs_helper.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid = 
        AndroidInitializationSettings('@mipmap/ic_launcher');
        
    const InitializationSettings initializationSettings = 
        InitializationSettings(android: initializationSettingsAndroid);
        
    await _notificationsPlugin.initialize(initializationSettings);
  }

  static Future<void> tampilkanNotifikasiBelanja() async {
    String shoppingDay = SharedPrefsHelper.shoppingDay; 

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'belanja_channel',
      'Pengingat Belanja',
      channelDescription: 'Notifikasi jadwal belanja mingguan otomatis',
      importance: Importance.max,
      priority: Priority.high,
      color: Color(0xFF2E7D32), // Sekarang Color sudah dikenali!
    );
    
    const NotificationDetails details = NotificationDetails(android: androidDetails);
    
    await _notificationsPlugin.show(
      0,
      'Waktunya Belanja! 🛒',
      'Hari ini jadwal kamu belanja sesuai setting ($shoppingDay). Cek daftar belanja sekarang!',
      details,
    );
  }
}