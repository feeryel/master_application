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
  late StreamSubscription<QuerySnapshot>? postulationSubscription;
  final Map<String, String> _previousStatus = {};

  @override
  void initState() {
    super.initState();
    user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Écoute les changements sur les postulations de cet utilisateur
      postulationSubscription = FirebaseFirestore.instance
          .collection('postulations')
          .where('idEtudiant', isEqualTo: user!.uid)
          .snapshots()
          .listen(_handlePostulationChanges);
    }
  }

  void _handlePostulationChanges(QuerySnapshot snapshot) {
    for (var change in snapshot.docChanges) {
      final doc = change.doc;
      final statut = (doc.data() as Map<String, dynamic>)['statut']?.toString().toLowerCase() ?? '';
      final id = doc.id;

      // Vérifie si le statut a changé
      final oldStatut = _previousStatus[id];
      if (oldStatut != statut && (statut == 'accepté' || statut == 'acceptée' || statut == 'refusé' || statut == 'refusée')) {
        _previousStatus[id] = statut;

        // Cherche le titre de l'action
        FirebaseFirestore.instance.collection('actions_volontariat').doc(doc['idAction']).get().then((actionDoc) {
          final titre = actionDoc.exists ? (actionDoc.data()?['titre'] ?? 'Action inconnue') : 'Action inconnue';

          final titreNotif = "🎯 Mise à jour de votre candidature";
          final bodyNotif = 'Votre postulation pour "$titre" a été ${statut == 'accepté' || statut == 'acceptée' ? 'acceptée' : 'refusée'}.';

          NotificationService.showLocalNotification(titreNotif, bodyNotif);
        });
      }
    }
  }

  @override
  void dispose() {
    postulationSubscription?.cancel();
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
