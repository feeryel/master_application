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
  final TextEditingController _nomController = TextEditingController();
  final TextEditingController _prenomController = TextEditingController();
  final TextEditingController _telController = TextEditingController();
  int _selectedIndex = 0;

  final List<Widget> _pages = [];
  final PageController _pageController = PageController();

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
    _nomController.dispose();
    _prenomController.dispose();
    _telController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final studentDoc = await FirebaseFirestore.instance
        .collection('etudiants')
        .doc(user.uid)
        .get();

    if (studentDoc.exists) {
      setState(() => _etudiantData = studentDoc.data());
    }

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
            // Ajouter les points seulement si la candidature est acceptée
            await _addPointsToStudent(change.doc.id, data['idAction']);
            
            NotificationService.showLocalNotification(
          title: 'Félicitations',
          body: '🎉 Bravo ! Ta candidature a été acceptée 🎉',
            );
          } else if (newStatut == 'refusé') {
            NotificationService.showLocalNotification(
              title: 'Candidature refusée',
              body: '❌ Votre candidature a été refusée.',
            );
          }
        }
      }
    });
  }

Future<void> _addPointsToStudent(String postulationId, String actionId) async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Vérifier d'abord si la participation est confirmée
    final postulationDoc = await FirebaseFirestore.instance
        .collection('postulations')
        .doc(postulationId)
        .get();

    if (postulationDoc.data()?['participationConfirmee'] != true) {
      debugPrint('Participation non confirmée - points non attribués');
      return;
    }

    // Vérifier si les points ont déjà été attribués
    if (postulationDoc.data()?['pointsAttributed'] == true) {
      debugPrint('Points déjà attribués pour cette postulation');
      return;
    }

    // Récupérer les points de l'action
    final actionDoc = await FirebaseFirestore.instance
        .collection('actions_volontariat')
        .doc(actionId)
        .get();
    
    final points = actionDoc.data()?['points'] ?? 10;

    // Mettre à jour les points de l'étudiant
    await FirebaseFirestore.instance
        .collection('etudiants')
        .doc(user.uid)
        .update({
          'points': FieldValue.increment(points),
        });

    // Marquer que les points ont été attribués
    await FirebaseFirestore.instance
        .collection('postulations')
        .doc(postulationId)
        .update({
          'pointsAttributed': true,
        });

    // Recharger les données de l'étudiant
    final updatedDoc = await FirebaseFirestore.instance
        .collection('etudiants')
        .doc(user.uid)
        .get();
        
    setState(() => _etudiantData = updatedDoc.data());
  } catch (e) {
    debugPrint('Erreur lors de l\'ajout des points: $e');
  }
}
  Future<void> postuler(String idAction) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Veuillez vous connecter");

      final existing = await FirebaseFirestore.instance
          .collection('postulations')
          .where('idAction', isEqualTo: idAction)
          .where('idEtudiant', isEqualTo: user.uid)
          .where('statut', whereNotIn: ['annulée'])
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        throw Exception("Vous avez déjà postulé à cette action");
      }

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
        SnackBar(
          content: Text("Postulation envoyée avec succès !"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
// ... (le reste du code reste inchangé)
  Widget _buildDrawer() {
    final user = FirebaseAuth.instance.currentUser;
    final points = _etudiantData?['points'] ?? 0;
    final prenom = _etudiantData?['prenom'] ?? '';
    final nom = _etudiantData?['nom'] ?? '';

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.8,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text('$prenom $nom', 
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            accountEmail: Text(user?.email ?? ''),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                prenom.isNotEmpty ? prenom[0].toUpperCase() : '?',
                style: TextStyle(fontSize: 24, color: Color(0xFF226D68)),
              ),
            ),
            decoration: BoxDecoration(
              color: Color(0xFF226D68),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  icon: Icons.home,
                  title: 'Accueil',
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _selectedIndex = 0);
                    _pageController.jumpToPage(0);
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.assignment_turned_in,
                  title: 'Mes postulations',
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _selectedIndex = 1);
                    _pageController.jumpToPage(1);
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.person,
                  title: 'Mon profil',
                  onTap: _showProfileDialog,
                ),
                _buildDrawerItem(
                  icon: Icons.star,
                  title: 'Mes points: $points',
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _selectedIndex = 2);
                    _pageController.jumpToPage(2);
                  },
                ),
                Divider(height: 1, thickness: 1, indent: 20, endIndent: 20),
                _buildDrawerItem(
                  icon: Icons.logout,
                  title: 'Déconnexion',
                  onTap: _logout,
                  color: Colors.red,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? Color(0xFF226D68)),
      title: Text(title, style: TextStyle(color: color ?? Colors.black87)),
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(horizontal: 20),
      minLeadingWidth: 10,
    );
  }

  Widget _buildWelcomePage() {
    final prenom = _etudiantData?['prenom'] ?? '';
    final points = _etudiantData?['points'] ?? 0;
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bonjour, $prenom',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF226D68),
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Bienvenue dans votre espace étudiant',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          SizedBox(height: 30),
          
          // Carte de bienvenue avec points
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber, size: 30),
                      SizedBox(width: 10),
                      Text(
                        'Vos points',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 15),
                  Text(
                    '$points',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF226D68),
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Points accumulés',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 30),
          
          // Applications connues
          Text(
            'Applications recommandées',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF226D68),
            ),
          ),
          SizedBox(height: 15),
          GridView.count(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
            children: [
              _buildAppCard(
                icon: Icons.school,
                title: 'Certifications',
                color: Colors.blue,
                   onTap: () {
        // Ajoutez ici la navigation vers la page des certifications si elle existe
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fonctionnalité à venir')),
        );}
              ),
              _buildAppCard(
                icon: Icons.volunteer_activism,
                title: 'Bénévolat',
                color: Colors.green,
                   onTap: () {
        setState(() => _selectedIndex = 3); // Index de la page Actions
        _pageController.jumpToPage(3);
      },
              ),
              _buildAppCard(
                icon: Icons.event,
                title: 'Historique de participation',
                color: Colors.orange,
                   onTap: () {
        // Ajoutez ici la navigation vers la page des certifications si elle existe
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fonctionnalité à venir')),
        );}
              ),
              _buildAppCard(
                icon: Icons.post_add_rounded,
                title: 'Mes Candidatures',
                color: Colors.purple, 
                  onTap: () {
        setState(() => _selectedIndex = 1); // Index de MesCandidaturesPage
        _pageController.jumpToPage(1);
      },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppCard({required IconData icon, required String title, required Color color  ,required VoidCallback onTap, }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
      onTap: onTap, // Utilisation du callback
        child: Padding(
          padding: EdgeInsets.all(15),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: color),
              SizedBox(height: 10),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPointsPage() {
    final points = _etudiantData?['points'] ?? 0;
    final prenom = _etudiantData?['prenom'] ?? '';
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: EdgeInsets.all(25),
              child: Column(
                children: [
                  Text(
                    'Votre score',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    '$points',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF226D68),
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Points',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 20),
                  LinearProgressIndicator(
                    value: points / 100, // Supposons que 100 est le max
                    backgroundColor: Colors.grey[200],
                    color: Color(0xFF226D68),
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  SizedBox(height: 10),
                  Text(
                    '${(points / 100 * 100).toStringAsFixed(0)}% du score maximal',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 30),
          
          Text(
            'Comment maximiser votre impact?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF226D68),
            ),
          ),
          SizedBox(height: 15),
          
     _buildPointInfo(
  icon: Icons.volunteer_activism,
  title: 'Postuler à une action',
  points: 'Premier pas',  // Remplace +5 points
  color: Colors.green,
),
_buildPointInfo(
  icon: Icons.check_circle,
  title: 'Candidature acceptée',
  points: 'Reconnaissance ',  // Remplace +15 points
  color: Colors.lightGreen,
),
_buildPointInfo(
  icon: Icons.event_available,
  title: 'Participation effective',
  points: 'Impact concret ',  // Remplace +30 points
  color: Colors.green,
),
_buildPointInfo(
  icon: Icons.star,
  title: 'Évaluation positive',
  points: 'Exemplarité reconnue',  // Remplace +10 points
  color: Colors.blueAccent,
),
_buildPointInfo(
  icon: Icons.leaderboard,
  title: 'Affectation des labels ',
  points: 'Progression',  // Remplace Jusqu'à +100 points
  color: Colors.orange,
),

        ],
      ),
    );
  }

  Widget _buildPointInfo({required IconData icon, required String title, required String points, required Color color}) {
    return Card(
      margin: EdgeInsets.only(bottom: 15),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color),
            ),
            SizedBox(width: 15),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                ),
              ),
            ),
            Chip(
              label: Text(
                points,
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: color,
            ),
          ],
        ),
      ),
    );
  }

  void _showProfileDialog() {
    final prenom = _etudiantData?['prenom'] ?? '';
    final nom = _etudiantData?['nom'] ?? '';
    final numTel = _etudiantData?['numTel'] ?? '';
    final points = _etudiantData?['points'] ?? 0;
    final user = FirebaseAuth.instance.currentUser;

    _prenomController.text = prenom;
    _nomController.text = nom;
    _telController.text = numTel;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Mon Profil', 
            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF226D68))),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Color(0xFF226D68).withOpacity(0.2),
                  child: Text(
                    prenom.isNotEmpty ? prenom[0].toUpperCase() : '?',
                    style: TextStyle(fontSize: 30, color: Color(0xFF226D68)),
                ),),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _prenomController,
                  decoration: InputDecoration(
                    labelText: 'Prénom',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _nomController,
                  decoration: InputDecoration(
                    labelText: 'Nom',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _telController,
                  decoration: InputDecoration(
                    labelText: 'Téléphone',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 20),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFF226D68).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.star, color: Colors.amber),
                      const SizedBox(width: 8),
                      Text('Points: $points',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(user?.email ?? '',
                  style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Annuler', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: _updateProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF226D68),
              ),
              child: Text('Enregistrer',style: TextStyle(color: Colors.white)),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        );
      },
    );
  }

  Future<void> _updateProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance.collection('etudiants').doc(user.uid).update({
        'prenom': _prenomController.text,
        'nom': _nomController.text,
        'numTel': _telController.text,
      });

      final updatedDoc = await FirebaseFirestore.instance
          .collection('etudiants')
          .doc(user.uid)
          .get();
          
      setState(() => _etudiantData = updatedDoc.data());
      
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profil mis à jour avec succès!'), 
          backgroundColor: Colors.green,
        ),
      );
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

  String _formatDate(dynamic date) {
    if (date == null) return 'Date inconnue';
    
    if (date is Timestamp) {
      final dt = date.toDate();
      return '${dt.day}/${dt.month}/${dt.year}';
    } else if (date is String) {
      return date;
    }
    return 'Date inconnue';
  }

  Widget _buildActionCard(DocumentSnapshot action) {
    final data = action.data() as Map<String, dynamic>;
    final points = data['points'] ?? 10;
    final titre = data['titre'] ?? 'Titre inconnu';
    final description = data['description'] ?? '';
    final lieu = data['lieu'] ?? 'Lieu non spécifié';
    final dateDebut = _formatDate(data['dateDebut']);
    final dateFin = _formatDate(data['dateFin']);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () => _showActionDetails(data),
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
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF226D68)),
                    ),
                  ),
                  Chip(
                    label: Text('$points pts', 
                      style: TextStyle(color: Colors.white)),
                    backgroundColor: Color(0xFF226D68),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (description.isNotEmpty) 
                Text(description, 
                  style: TextStyle(color: Colors.grey[700])),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.location_on, size: 18, color: Colors.grey),
                  const SizedBox(width: 5),
                  Text(lieu, style: TextStyle(color: Colors.grey[700])),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                  const SizedBox(width: 5),
                  Text(
                    'Du $dateDebut au $dateFin',
                    style: TextStyle(color: Colors.grey[700])),
                ],
              ),
              const SizedBox(height: 15),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => postuler(action.id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF226D68),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  child: const Text("Postuler"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionsPage() {
    return _loadedActions.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Color(0xFF226D68)),
                SizedBox(height: 20),
                Text('Chargement des actions...',
                  style: TextStyle(color: Colors.grey)),
              ],
            ),
          )
        : RefreshIndicator(
            onRefresh: _loadInitialData,
            color: Color(0xFF226D68),
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _loadedActions.length + (_isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= _loadedActions.length) {
                  return Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: CircularProgressIndicator(color: Color(0xFF226D68))),
                  );
                }
                return _buildActionCard(_loadedActions[index]);
              },
            ),
          );
  }

  void _showActionDetails(Map<String, dynamic> data) {
    final dateDebut = _formatDate(data['dateDebut']);
    final dateFin = _formatDate(data['dateFin']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  margin: EdgeInsets.only(bottom: 15),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
              Text(data['titre'] ?? '',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF226D68))),
              SizedBox(height: 10),
              Text('Du $dateDebut au $dateFin',
                style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              Text(data['description'] ?? '',
                style: TextStyle(fontSize: 16)),
              SizedBox(height: 20),
              if (data['competencesRequises'] != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Compétences requises:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 5),
                    Wrap(
                      spacing: 5,
                      children: (data['competencesRequises'] as List<dynamic>)
                          .map((e) => Chip(label: Text(e.toString())))
                          .toList(),
                    ),
                  ],
                ),
              SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    postuler(data['id']);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF226D68),
                    padding: EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  ),
                child: Text(
  'Postuler maintenant',
  style: TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  ),
),
                ),
              ),
            ],
          ),
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
        SnackBar(
          content: Text("Erreur: ${e.toString()}"), 
          backgroundColor: Colors.red,
        ),
      );
    }
  }

 @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Espace Étudiant", 
          style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF226D68),
        iconTheme: IconThemeData(color: Colors.white),
        elevation: 0,
         actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          onPressed: _loadInitialData,
          tooltip: 'Actualiser',
        ),
      ],
    
      ),
      drawer: _buildDrawer(),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() => _selectedIndex = index);
        },
        children: [
          _buildWelcomePage(),
          MesCandidaturesPage(),
          _buildPointsPage(),
          _buildActionsPage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
          _pageController.jumpToPage(index);
        },
        selectedItemColor: Color(0xFF226D68),
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_turned_in),
            label: 'Mes candidatures',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.star),
            label: 'Mes points',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.volunteer_activism),
            label: 'Actions',
          ),
        ],
      ),
    );
  }
}