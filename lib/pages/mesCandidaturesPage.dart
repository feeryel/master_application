import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:master_application/pages/espaceEtudiantPage.dart';

class MesCandidaturesPage extends StatefulWidget {
  const MesCandidaturesPage({super.key});

  @override
  State<MesCandidaturesPage> createState() => _MesCandidaturesPageState();
}

class _MesCandidaturesPageState extends State<MesCandidaturesPage> {
Future<bool> _willPopCallback() async {
  Navigator.of(context).pushReplacement(
    MaterialPageRoute(builder: (context) => EspaceEtudiantPage()),
  );
  return false;
}

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
      case 'annulée':
        return 'Annulée 🚫';
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
      case 'annulée':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Future<void> _annulerCandidature(String candidatureId) async {
    try {
      await FirebaseFirestore.instance
          .collection('postulations')
          .doc(candidatureId)
          .delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Candidature annulée avec succès'),
          backgroundColor: Colors.green,
        ),
      );
      
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return WillPopScope(
      onWillPop: _willPopCallback,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Mes Candidatures"),
          backgroundColor: const Color(0xFF226D68),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _willPopCallback(),
          ),
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
                final canCancel = statut == 'en_attente';

                return FutureBuilder<String>(
                  future: _getActionTitle(candidature['idAction']),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const ListTile(title: Text('Chargement...'));
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
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
                            if (canCancel)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Annuler la candidature'),
                                        content: const Text(
                                            'Êtes-vous sûr de vouloir annuler cette candidature ?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: const Text('Non'),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              Navigator.pop(context);
                                              _annulerCandidature(candidature.id);
                                            },
                                            child: const Text('Oui'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    'Annuler',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}