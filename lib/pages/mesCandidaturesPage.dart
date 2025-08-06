import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class MesCandidaturesPage extends StatelessWidget {
  const MesCandidaturesPage({super.key});

  Future<String> _getActionTitle(String actionId) async {
    final doc = await FirebaseFirestore.instance
        .collection('actions_volontariat')
        .doc(actionId)
        .get();
    return doc.data()?['titre'] ?? 'Action inconnue';
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'accepté':
        return 'Acceptée ✅';
      case 'refusé':
        return 'Refusée ❌';
      case 'en_attente':
        return 'En attente ⌛';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'accepté':
        return Colors.green;
      case 'refusé':
        return Colors.red;
      case 'en_attente':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Mes Candidatures"),
        backgroundColor: const Color(0xFF226D68),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('postulations')
            .where('idEtudiant', isEqualTo: userId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("Vous n'avez aucune candidature."),
            );
          }

          final candidatures = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: candidatures.length,
            itemBuilder: (context, index) {
              final candidature = candidatures[index];
              final statut = candidature['statut'];

              return FutureBuilder<String>(
                future: _getActionTitle(candidature['idAction']),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const ListTile(title: Text('Chargement...'));
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(snapshot.data!),
                      subtitle: Text(
                        'Postulé le ${DateFormat('dd/MM/yyyy').format(
                          (candidature['createdAt'] as Timestamp).toDate()
                        )}',
                      ),
                      trailing: Chip(
                        label: Text(
                          _getStatusText(statut),
                          style: const TextStyle(color: Colors.white),
                        ),
                        backgroundColor: _getStatusColor(statut),
                      ),
                    ),
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