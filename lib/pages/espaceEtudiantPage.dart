import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'mesCandidaturesPage.dart'; // Assure-toi que ce fichier est bien importé
import 'notification_service.dart'; // Ton service notifications local (à adapter selon ton projet)

class EspaceEtudiantPage extends StatefulWidget {
  const EspaceEtudiantPage({super.key});

  @override
  State<EspaceEtudiantPage> createState() => _EspaceEtudiantPageState();
}

class _EspaceEtudiantPageState extends State<EspaceEtudiantPage> {
  StreamSubscription<QuerySnapshot>? _candidatureSub;

  @override
  void initState() {
    super.initState();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _candidatureSub = FirebaseFirestore.instance
          .collection('postulations')
          .where('idEtudiant', isEqualTo: uid)
          .snapshots()
          .listen((snapshot) {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.modified) {
            final data = change.doc.data();
            if (data == null) continue;

            final newStatut = data['statut'];
            if (newStatut == 'accepté' || newStatut == 'refusé') {
              NotificationService.showFlutterNotification(
                RemoteMessage(
                  notification: RemoteNotification(
                    title: 'Mise à jour de votre candidature',
                    body: newStatut == 'accepté'
                        ? '🎉 Félicitations ! Vous avez été accepté.'
                        : '❌ Votre candidature a été refusée.',
                  ),
                ),
              );
            }
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _candidatureSub?.cancel();
    super.dispose();
  }

  Future<void> postuler(BuildContext context, String idAction) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez vous connecter.")),
      );
      return;
    }

    final existing = await FirebaseFirestore.instance
        .collection('postulations')
        .where('idAction', isEqualTo: idAction)
        .where('idEtudiant', isEqualTo: user.uid)
        .get();

    if (existing.docs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vous avez déjà postulé à cette action.")),
      );
      return;
    }

    await FirebaseFirestore.instance.collection('postulations').add({
      'idAction': idAction,
      'idEtudiant': user.uid,
      'email': user.email ?? 'non défini',
      'createdAt': Timestamp.now(),
      'statut': 'en_attente', // Statut initial
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Postulation envoyée avec succès !")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Espace Étudiant"),
        backgroundColor: const Color(0xFF226D68),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Color(0xFF226D68)),
              child: Text('Menu', style: TextStyle(color: Colors.white, fontSize: 24)),
            ),
            ListTile(
              leading: const Icon(Icons.assignment_turned_in),
              title: const Text('Mes postulations'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MesCandidaturesPage()),
                );
              },
            ),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("actions_volontariat")
            .orderBy("createdAt", descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Aucune action disponible."));
          }

          final actions = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: actions.length,
            itemBuilder: (context, index) {
              final action = actions[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(action['titre'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(action['description']),
                      const SizedBox(height: 6),
                      Text("📍 ${action['lieu']}"),
                      Text("📅 Du ${action['dateDebut']} au ${action['dateFin']}"),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: () => postuler(context, action.id),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF226D68),
                              foregroundColor: Colors.white),
                          child: const Text("Postuler"),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
