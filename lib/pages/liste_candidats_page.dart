import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ListeCandidatsPage extends StatelessWidget {
  final String idAction;
  final String titreAction;

  const ListeCandidatsPage({
    super.key,
    required this.idAction,
    required this.titreAction,
  });

  Future<void> updateStatut(String docId, String statut, BuildContext context) async {
    try {
      await FirebaseFirestore.instance
          .collection('postulations')
          .doc(docId)
          .update({'statut': statut});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Statut mis à jour : $statut")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur : ${e.toString()}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Candidats - $titreAction"),
        backgroundColor: const Color(0xFF226D68),
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('postulations')
              .where('idAction', isEqualTo: idAction)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return const Center(child: Text("Erreur de chargement."));
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text("Aucune candidature reçue."));
            }

            final candidatures = snapshot.data!.docs;

            return ListView.builder(
              itemCount: candidatures.length,
              itemBuilder: (context, index) {
                final doc = candidatures[index];
                final email = doc['email'] ?? 'Email inconnu';
                final idEtudiant = doc['idEtudiant'] ?? 'ID inconnu';
                final statut = doc['statut'] ?? 'en attente';

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(email, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text("ID Étudiant: $idEtudiant"),
                        Text("Statut: ${statut.toUpperCase()}"),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: statut == 'accepté'
                                  ? null
                                  : () => updateStatut(doc.id, 'accepté', context),
                              icon: const Icon(Icons.check),
                              label: const Text("Accepter"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: statut == 'refusé'
                                  ? null
                                  : () => updateStatut(doc.id, 'refusé', context),
                              icon: const Icon(Icons.close),
                              label: const Text("Refuser"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
