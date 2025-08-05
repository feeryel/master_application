import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GestionPostulationsPage extends StatelessWidget {
  const GestionPostulationsPage({super.key});

  Future<String> _getTitreAction(String idAction) async {
    final doc = await FirebaseFirestore.instance.collection('actions_volontariat').doc(idAction).get();
    return doc.data()?['titre'] ?? 'Action inconnue';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestion des postulations"),
        backgroundColor: const Color(0xFF226D68),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('postulations').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final postulations = snapshot.data!.docs;

          if (postulations.isEmpty) {
            return const Center(child: Text("Aucune postulation reçue."));
          }

          return ListView.builder(
            itemCount: postulations.length,
            itemBuilder: (context, index) {
              final postulation = postulations[index];
              final idAction = postulation['idAction'];
              final email = postulation.data().toString().contains('email') ? postulation['email'] : 'Email inconnu';
              final idEtudiant = postulation.data().toString().contains('idEtudiant') ? postulation['idEtudiant'] : 'Inconnu';

              return FutureBuilder<String>(
                future: _getTitreAction(idAction),
                builder: (context, snapshotTitre) {
                  if (!snapshotTitre.hasData) return const ListTile(title: Text("Chargement..."));

                  return ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(email),
                    subtitle: Text("Id de l'Étudiant : $idEtudiant\nAction : ${snapshotTitre.data!}"),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
