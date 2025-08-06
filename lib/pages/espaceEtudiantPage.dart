import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'loginPage.dart';
import 'mesCandidaturesPage.dart';
import 'notification_service.dart';

class EspaceEtudiantPage extends StatefulWidget {
  const EspaceEtudiantPage({super.key});

  @override
  State<EspaceEtudiantPage> createState() => _EspaceEtudiantPageState();
}

class _EspaceEtudiantPageState extends State<EspaceEtudiantPage> {
  StreamSubscription<QuerySnapshot>? _candidatureSub;
  final ScrollController _scrollController = ScrollController();
  List<DocumentSnapshot> _loadedActions = [];
  bool _isLoadingMore = false;
  DocumentSnapshot? _lastDocument;
  Map<String, dynamic>? _etudiantData;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _setupNotifications();
    _loadInitialData();
  }

  @override
  void dispose() {
    _candidatureSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Charger les données de l'étudiant
    final studentDoc = await FirebaseFirestore.instance
        .collection('etudiants')
        .doc(user.uid)
        .get();

    if (studentDoc.exists) {
      setState(() => _etudiantData = studentDoc.data());
    }

    // Charger les actions
    final actionsQuery = FirebaseFirestore.instance
        .collection("actions_volontariat")
        .orderBy("createdAt", descending: true)
        .limit(10);

    final snapshot = await actionsQuery.get();
    setState(() {
      _loadedActions = snapshot.docs;
      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
      }
    });
  }

  Future<void> _loadMoreData() async {
    if (_isLoadingMore || _lastDocument == null) return;

    setState(() => _isLoadingMore = true);

    final query = FirebaseFirestore.instance
        .collection("actions_volontariat")
        .orderBy("createdAt", descending: true)
        .startAfterDocument(_lastDocument!)
        .limit(10);

    final snapshot = await query.get();

    if (snapshot.docs.isNotEmpty) {
      setState(() {
        _loadedActions.addAll(snapshot.docs);
        _lastDocument = snapshot.docs.last;
      });
    }

    setState(() => _isLoadingMore = false);
  }

  void _scrollListener() {
    if (_scrollController.offset >= _scrollController.position.maxScrollExtent &&
        !_scrollController.position.outOfRange &&
        !_isLoadingMore) {
      _loadMoreData();
    }
  }

  void _setupNotifications() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _candidatureSub = FirebaseFirestore.instance
        .collection('postulations')
        .where('idEtudiant', isEqualTo: uid)
        .snapshots()
        .listen((snapshot) async {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.modified) {
          final data = change.doc.data() as Map<String, dynamic>? ?? {};
          if (data.isEmpty) continue;

          final newStatut = data['statut']?.toString() ?? '';
          if (newStatut == 'accepté') {
            await FirebaseFirestore.instance
                .collection('etudiants')
                .doc(uid)
                .update({'points': FieldValue.increment(10)});

            NotificationService.showFlutterNotification(
              RemoteMessage(
                notification: RemoteNotification(
                  title: 'Candidature acceptée',
                  body: '🎉 Félicitations! Vous avez gagné 10 points!',
                ),
              ),
            );
          } else if (newStatut == 'refusé') {
            NotificationService.showFlutterNotification(
              RemoteMessage(
                notification: RemoteNotification(
                  title: 'Candidature refusée',
                  body: '❌ Votre candidature a été refusée.',
                ),
              ),
            );
          }
        }
      }
    });
  }

  Future<void> postuler(String idAction) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Veuillez vous connecter");

      // Vérifier si déjà postulé
      final existing = await FirebaseFirestore.instance
          .collection('postulations')
          .where('idAction', isEqualTo: idAction)
          .where('idEtudiant', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        throw Exception("Vous avez déjà postulé à cette action");
      }

      // Créer la postulation
      await FirebaseFirestore.instance.collection('postulations').add({
        'idAction': idAction,
        'idEtudiant': user.uid,
        'email': user.email,
        'nomComplet': '${_etudiantData?['prenom']} ${_etudiantData?['nom']}',
        'createdAt': Timestamp.now(),
        'statut': 'en_attente',
        'idEtablissement': (await FirebaseFirestore.instance
            .collection('actions_volontariat')
            .doc(idAction)
            .get())
            .data()?['idEtablissement'],
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Postulation envoyée avec succès !")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur: ${e.toString()}")),
      );
    }
  }

  Widget _buildDrawer() {
    final user = FirebaseAuth.instance.currentUser;
    final points = _etudiantData?['points'] ?? 0;
    final prenom = _etudiantData?['prenom'] ?? '';
    final nom = _etudiantData?['nom'] ?? '';

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text('$prenom $nom'),
            accountEmail: Text(user?.email ?? ''),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(prenom.isNotEmpty ? prenom[0].toUpperCase() : '?'),
            ),
            decoration: const BoxDecoration(color: Color(0xFF226D68)),
          ),
          ListTile(
            leading: const Icon(Icons.assignment_turned_in),
            title: const Text('Mes postulations'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, 
                MaterialPageRoute(builder: (_) => const MesCandidaturesPage()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Mon profil'),
            onTap: _showProfileDialog,
          ),
          ListTile(
            leading: const Icon(Icons.star),
            title: Text('Mes points: $points'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Déconnexion'),
            onTap: _logout,
          ),
        ],
      ),
    );
  }

  void _showProfileDialog() {
    final prenom = _etudiantData?['prenom'] ?? '';
    final nom = _etudiantData?['nom'] ?? '';
    final numTel = _etudiantData?['numTel'] ?? 'Non renseigné';
    final points = _etudiantData?['points'] ?? 0;
    final user = FirebaseAuth.instance.currentUser;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Mon Profil'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  child: Text(prenom.isNotEmpty ? prenom[0].toUpperCase() : '?'),
                ),
                const SizedBox(height: 16),
                Text('$prenom $nom', 
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(user?.email ?? ''),
                const SizedBox(height: 8),
                Text('Téléphone: $numTel'),
                const SizedBox(height: 16),
                Text('Points: $points',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur: ${e.toString()}")),
      );
    }
  }

  Widget _buildActionCard(DocumentSnapshot action) {
    final data = action.data() as Map<String, dynamic>;
    final points = data['points'] ?? 10;
    final titre = data['titre'] ?? 'Titre inconnu';
    final description = data['description'] ?? '';
    final lieu = data['lieu'] ?? 'Lieu non spécifié';
    final dateDebut = data['dateDebut'] ?? 'Date inconnue';
    final dateFin = data['dateFin'] ?? 'Date inconnue';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    titre,
                    style: const TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.bold
                    ),
                  ),
                ),
                Chip(
                  label: Text('$points pts'),
                  backgroundColor: const Color(0xFF226D68).withOpacity(0.2),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (description.isNotEmpty) Text(description),
            const SizedBox(height: 8),
            Text("📍 $lieu"),
            Text("📅 Du $dateDebut au $dateFin"),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () => postuler(action.id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF226D68),
                  foregroundColor: Colors.white,
                ),
                child: const Text("Postuler"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Espace Étudiant"),
        backgroundColor: const Color(0xFF226D68),
      ),
      drawer: _buildDrawer(),
      body: _loadedActions.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _loadedActions.length + (_isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= _loadedActions.length) {
                  return const Center(child: CircularProgressIndicator());
                }
                return _buildActionCard(_loadedActions[index]);
              },
            ),
    );
  }
}