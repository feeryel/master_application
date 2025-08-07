import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'pages/notification_service.dart';
import 'pages/welcomePage.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await NotificationService.initialize();

  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late final User? user;
  late StreamSubscription<QuerySnapshot>? _notificationsSubscription;
  final Map<String, String> _previousStatus = {};

  @override
  void initState() {
    super.initState();
    user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _setupNotificationsListener();
    }
  }

  void _setupNotificationsListener() async {
    // Vérifier si l'utilisateur est un étudiant
    final studentDoc = await FirebaseFirestore.instance
        .collection('etudiants')
        .doc(user!.uid)
        .get();

    if (studentDoc.exists) {
      // Écouter les notifications pour cet étudiant
      _notificationsSubscription = FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: user!.uid)
          .orderBy('timestamp', descending: true)
          .snapshots()
          .listen((snapshot) {
            for (var change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.added) {
                final notification = change.doc.data() as Map<String, dynamic>;
                NotificationService.showLocalNotification(
                  title: notification['title'],
                  body: notification['body'],
                );
              }
            }
          });
    }
  }

  @override
  void dispose() {
    _notificationsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: WelcomePage(),
    );
  }
}