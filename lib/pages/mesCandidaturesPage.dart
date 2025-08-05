import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MesCandidaturesPage extends StatelessWidget {
  const MesCandidaturesPage({super.key});

  Future<String> _getTitreAction(String idAction) async {
    final doc = await FirebaseFirestore.instance.collection('actions_volontariat').doc(idAction).get();
    return doc.exists ? (doc.data()?['titre'] ?? 'Titre inconnu') : 'Action inconnue';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Mes Candidatures"),
          backgroundColor: const Color(0xFF226D68),
        ),
        body: const Center(
          child: Text("Veuillez vous connecter pour voir vos candidatures."),
        ),
      );
    }

    //  Debug : Affiche UID de l'utilisateur connecté
    print("✅ UID connecté : ${user.uid}");

    return Scaffold(
      appBar: AppBar(
        title: const Text("Mes Candidatures"),
        backgroundColor: const Color(0xFF226D68),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('postulations')
            .where('idEtudiant', isEqualTo: user.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            print("❌ Aucune postulation trouvée pour UID : ${user.uid}");
            return const Center(child: Text("Vous n'avez pas encore postulé à une action."));
          }

          final candidatures = snapshot.data!.docs;

          // Debug : Affiche les candidatures trouvées
          print("🔍 ${candidatures.length} postulations trouvées pour l'utilisateur connecté.");

          return ListView.builder(
            itemCount: candidatures.length,
            itemBuilder: (context, index) {
              final candidature = candidatures[index];
              final idAction = candidature['idAction'];
              final date = candidature['createdAt']?.toDate();

              print("📄 Candidature #$index : idAction = $idAction, date = $date");

              return FutureBuilder<String>(
                future: _getTitreAction(idAction),
                builder: (context, snapshotTitre) {
                  if (!snapshotTitre.hasData) {
                    return const ListTile(title: Text("Chargement..."));
                  }

                  return ListTile(
                    leading: const Icon(Icons.assignment),
                    title: Text(snapshotTitre.data!),
subtitle: Text(
  "Postulé le : ${date != null ? date.toString().split(' ')[0] : 'Inconnue'}\n"
  "Statut : ${candidature['statut']}",
),                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
