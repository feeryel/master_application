import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'postulations_channel', // id
    'Notifications des postulations', // nom
    description: 'Ce canal est utilisé pour les notifications des postulations',
    importance: Importance.max,
  );

  static Future<void> initialize() async {
    // Crée le channel Android (nécessaire pour Android 8+)
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: DarwinInitializationSettings(
        // onDidReceiveLocalNotification: (id, title, body, payload) async {
        //   // Gestion locale sur iOS
        // },
      ),
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initSettings,
      // onSelectNotification: (payload) async {
      //   // Action quand utilisateur clique sur notification
      // },
    );

    // Demander les permissions aux utilisateurs (iOS & Android 13+)
    await FirebaseMessaging.instance.requestPermission();

    // Ecoute en foreground des notifications Firebase Cloud Messaging
    FirebaseMessaging.onMessage.listen(showFlutterNotification);
  }

  static void showFlutterNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    final androidDetails = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.max,
      priority: Priority.high,
    );

    final platformDetails = NotificationDetails(android: androidDetails);

    _flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      platformDetails,
    );
  }

  // --- AJOUTE CETTE MÉTHODE POUR AFFICHER UNE NOTIFICATION LOCALE SIMPLE ---
  static Future<void> showLocalNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'postulations_channel',
      'Notifications des postulations',
      channelDescription: 'Ce canal est utilisé pour les notifications des postulations',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    await _flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      platformDetails,
    );
  }
}
