import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/intl.dart';
import 'loginPage.dart';
import 'mesCandidaturesPage.dart';
import 'notification_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
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
  bool _showHistorique = false;

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

  String _getStudentLabel(int points) {
    if (points >= 1000) return 'Leader Communautaire';
    if (points >= 500) return 'Étudiant Exemplaire';
    if (points >= 250) return 'Étudiant Responsable';
    if (points >= 100) return 'Étudiant Engagé';
    return 'Nouveau';
  }

  Color _getLabelColor(int points) {
    if (points >= 1000) return Color(0xFFdc2626);
    if (points >= 500) return Color(0xFF7c3aed);
    if (points >= 250) return Color(0xFF2563eb);
    if (points >= 100) return Color(0xFF0ea5e9);
    return Color(0xFF64748b);
  }


List<Map<String, dynamic>> _getEarnedLabels(int points) {
  final List<Map<String, dynamic>> earnedLabels = [];
  
  if (points >= 1000) {
    earnedLabels.add({
      'name': 'Leader Communautaire',
      'color': Color(0xFFdc2626),
      'threshold': 1000
    });
  }
  if (points >= 500) {
    earnedLabels.add({
      'name': 'Étudiant Exemplaire', 
      'color': Color(0xFF7c3aed),
      'threshold': 500
    });
  }
  if (points >= 250) {
    earnedLabels.add({
      'name': 'Étudiant Responsable',
      'color': Color(0xFF2563eb),
      'threshold': 250
    });
  }
  if (points >= 100) {
    earnedLabels.add({
      'name': 'Étudiant Engagé',
      'color': Color(0xFF0ea5e9),
      'threshold': 100
    });
  }
  if (points < 100) {
    earnedLabels.add({
      'name': 'Nouveau',
      'color': Color(0xFF64748b),
      'threshold': 0
    });
  }
  
  // Trier par ordre décroissant de points
  earnedLabels.sort((a, b) => b['threshold'].compareTo(a['threshold']));
  
  return earnedLabels;
}
  Map<String, dynamic>? _getNextLevel(int points) {
    if (points >= 1000) return null;
    if (points >= 500) return {'name': 'Leader Communautaire', 'threshold': 1000, 'color': 0xFFdc2626};
    if (points >= 250) return {'name': 'Étudiant Exemplaire', 'threshold': 500, 'color': 0xFF7c3aed};
    if (points >= 100) return {'name': 'Étudiant Responsable', 'threshold': 250, 'color': 0xFF2563eb};
    return {'name': 'Étudiant Engagé', 'threshold': 100, 'color': 0xFF0ea5e9};
  }

  int _getCurrentThreshold(int points) {
    if (points >= 1000) return 1000;
    if (points >= 500) return 500;
    if (points >= 250) return 250;
    if (points >= 100) return 100;
    return 0;
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

      final postulationDoc = await FirebaseFirestore.instance
          .collection('postulations')
          .doc(postulationId)
          .get();

      if (postulationDoc.data()?['participationConfirmee'] != true) {
        debugPrint('Participation non confirmée - points non attribués');
        return;
      }

      if (postulationDoc.data()?['pointsAttributed'] == true) {
        debugPrint('Points déjà attribués pour cette postulation');
        return;
      }

      final actionDoc = await FirebaseFirestore.instance
          .collection('actions_volontariat')
          .doc(actionId)
          .get();
      
      final points = actionDoc.data()?['points'] ?? 10;

      await FirebaseFirestore.instance
          .collection('etudiants')
          .doc(user.uid)
          .update({
            'points': FieldValue.increment(points),
          });

      await FirebaseFirestore.instance
          .collection('postulations')
          .doc(postulationId)
          .update({
            'pointsAttributed': true,
          });

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
      content: Text("Erreur: ${e.toString().replaceAll('Exception: ', '')}"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

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
    final nom = _etudiantData?['nom'] ?? '';
    final points = _etudiantData?['points'] ?? 0;
    final label = _getStudentLabel(points);
    final labelColor = _getLabelColor(points);
    final nextLevel = _getNextLevel(points);
    final progress = nextLevel != null 
        ? (points - _getCurrentThreshold(points)) / 
          (nextLevel['threshold'] - _getCurrentThreshold(points))
        : 1.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Color(0xFF226D68).withOpacity(0.2),
                child: Text(
                  prenom.isNotEmpty ? prenom[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 24,
                    color: Color(0xFF226D68),
                  ),
                ),
              ),
              SizedBox(width: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bonjour, $prenom',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF226D68),
                    ),
                  ),
                  Text(
                    'Bienvenue dans votre espace',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 30),
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
                  SizedBox(height: 5),
                  Text(
                    'Points accumulés',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 20),
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
                      Icon(Icons.emoji_events, color: labelColor, size: 30),
                      SizedBox(width: 10),
                      Text(
                        'Votre niveau',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 15),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: labelColor,
                    ),
                  ),
                  SizedBox(height: 10),
                  if (nextLevel != null)
                    Column(
                      children: [
                        LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.grey[200],
                          color: labelColor,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '${(progress * 100).toStringAsFixed(0)}% vers ${nextLevel['name']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      'Niveau maximum atteint!',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(height: 30),
          Text(
            'Actions rapides',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF226D68),
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _buildCertificationsPage(),
      ),
    );
  }
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _buildHistoriquePage(),
      ),
    );
  }
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


Widget _buildCertificationsPage() {
  final points = _etudiantData?['points'] ?? 0;
  final earnedLabels = _getEarnedLabels(points);

  return Scaffold(
    appBar: AppBar(
      title: Text("Mes Certifications"),
      backgroundColor: Color(0xFF226D68),
      actions: [
        IconButton(
          icon: Icon(Icons.picture_as_pdf),
          onPressed: _generateCertificationPDF,
          tooltip: 'Exporter en PDF',
        ),
      ],
    ),
    body: SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mes Certificats Obtenus',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF226D68),
            )),
          SizedBox(height: 20),
          if (earnedLabels.isEmpty)
            Text("Vous n'avez pas encore de certifications")
          else
            ...earnedLabels.map((label) => _buildCertificationCard(label)).toList(),
          
          // Add progress to next level
          if (_getNextLevel(points) != null) ...[
            SizedBox(height: 30),
            
          ],
        ],
      ),
    ),
  );
}
Widget _buildCertificationCard(Map<String, dynamic> label) {
  return Card(
    elevation: 3,
    margin: EdgeInsets.only(bottom: 15),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(15),
    ),
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: label['color'].withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.verified, color: label['color']),
          ),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label['name'],
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Seuil: ${label['threshold']} points',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Icon(Icons.check_circle, color: Colors.green),
        ],
      ),
    ),
  );
}
  Widget _buildAppCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(15),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 30, color: color),
              ),
              SizedBox(height: 10),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
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
    final label = _getStudentLabel(points);
    final labelColor = _getLabelColor(points);
    final nextLevel = _getNextLevel(points);
    final progress = nextLevel != null 
        ? (points - _getCurrentThreshold(points)) / 
          (nextLevel['threshold'] - _getCurrentThreshold(points))
        : 1.0;

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
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF226D68),
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Points accumulés',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
          SizedBox(height: 20),
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: EdgeInsets.all(25),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.emoji_events, color: labelColor, size: 30),
                      SizedBox(width: 10),
                      Text(
                        'Votre niveau',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 15),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: labelColor,
                    ),
                  ),
                  SizedBox(height: 10),
                  if (nextLevel != null)
                    Column(
                      children: [
                        LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.grey[200],
                          color: labelColor,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '${(progress * 100).toStringAsFixed(0)}% vers ${nextLevel['name']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      'Niveau maximum atteint!',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
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
            points: 'Premier pas',
            color: Colors.green,
          ),
          _buildPointInfo(
            icon: Icons.check_circle,
            title: 'Candidature acceptée',
            points: 'Reconnaissance',
            color: Colors.lightGreen,
          ),
          _buildPointInfo(
            icon: Icons.event_available,
            title: 'Participation effective',
            points: 'Impact concret',
            color: Colors.green,
          ),
          _buildPointInfo(
            icon: Icons.star,
            title: 'Évaluation positive',
            points: 'Exemplarité reconnue',
            color: Colors.blueAccent,
          ),
          _buildPointInfo(
            icon: Icons.leaderboard,
            title: 'Affectation des labels',
            points: 'Progression',
            color: Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildPointInfo({
    required IconData icon,
    required String title,
    required String points,
    required Color color,
  }) {
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
          title: const Text(
            'Mon Profil',
            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF226D68)),
          ),
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
                  ),
                ),
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
                      Text(
                        'Points: $points',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  user?.email ?? '',
                  style: TextStyle(color: Colors.grey),
                ),
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
              child: Text('Enregistrer', style: TextStyle(color: Colors.white)),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        );
      },
    );
  }
  Widget _buildHistoriquePage() {
    return Scaffold(
      appBar: AppBar(
        title: Text("Historique de participation"),
        backgroundColor: Color(0xFF226D68),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.picture_as_pdf),
            onPressed: _generateHistoriquePDF,
            tooltip: 'Exporter en PDF',
          ),
        ],
      ),
      body: _buildHistoriqueContent(),
    );
  }

    Widget _buildHistoriqueContent() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('postulations')
          .where('idEtudiant', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
          .where('statut', isEqualTo: 'accepté')
          .where('participationConfirmee', isEqualTo: true)
          .orderBy('dateConfirmation', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: Color(0xFF226D68)));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 50, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Aucune participation enregistrée',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final postulation = snapshot.data!.docs[index];
            return _buildParticipationCard(postulation);
          },
        );
      },
    );
  }

    Widget _buildParticipationCard(DocumentSnapshot postulation) {
    final data = postulation.data() as Map<String, dynamic>;
    
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('actions_volontariat')
          .doc(data['idAction'])
          .get(),
      builder: (context, actionSnapshot) {
        if (!actionSnapshot.hasData) {
          return SizedBox.shrink();
        }

        final actionData = actionSnapshot.data!.data() as Map<String, dynamic>? ?? {};
        final dateConfirmation = (data['dateConfirmation'] as Timestamp).toDate();

        return Card(
          margin: EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 2,
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Expanded(
      child: Text(
        actionData['titre'] ?? 'Action inconnue',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF226D68),
        ),
      ),
    ),
    Chip(
      label: Text('${actionData['points'] ?? 0} pts'),
      backgroundColor: Color(0xFF226D68).withOpacity(0.1),
      labelStyle: TextStyle(color: Color(0xFF226D68)),
    ),
  ],
),
                SizedBox(height: 8),
                if (actionData['description']?.isNotEmpty ?? false)
                  Text(
                    actionData['description']!,
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey),
                    SizedBox(width: 8),
                    Text(
                      actionData['lieu'] ?? 'Lieu inconnu',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                    SizedBox(width: 8),
                    Text(
                      'Participé le ${DateFormat('dd/MM/yyyy').format(dateConfirmation)}',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

Future<void> _generateCertificationPDF() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  try {
    final points = _etudiantData?['points'] ?? 0;
    final prenom = _etudiantData?['prenom'] ?? '';
    final nom = _etudiantData?['nom'] ?? '';
    final fullName = '$prenom $nom'.trim();
    final earnedLabels = _getEarnedLabels(points);
    
    if (earnedLabels.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vous n\'avez pas encore de certifications'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final highestCertification = earnedLabels.first;
    final certColor = PdfColor.fromInt(highestCertification['color'].value);

    // 1. Création du document PDF
    final pdf = pw.Document();

    // 2. Ajout de la page de certificat
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(
          base: await PdfGoogleFonts.openSansRegular(),
          bold: await PdfGoogleFonts.openSansBold(),
        ),
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              // Arrière-plan décoratif
              pw.Positioned.fill(
                child: pw.Opacity(
                  opacity: 0.1,
                  child: pw.Container(
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(
                        color: certColor,
                        width: 15,
                      ),
                    ),
                  ),
                ),
              ),
              
              // Contenu principal centré
              pw.Center(
                child: pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                   
                    
                    
                    // Titre principal
                    pw.Text(
                      'CERTIFICAT DE RECONNAISSANCE',
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: certColor,
                        letterSpacing: 1.5,
                      ),
                    ),
                    
                    pw.SizedBox(height: 40),
                    
                    // Texte de certification
                    pw.Text(
                      'Ceci certifie que',
                      style: pw.TextStyle(fontSize: 16),
                    ),
                    
                    pw.SizedBox(height: 10),
                    
                    // Nom de l'étudiant
                    pw.Text(
                      fullName.isNotEmpty ? fullName : user.email ?? '',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    
                    pw.SizedBox(height: 10),
                    
                    // Description
                    pw.Padding(
                      padding: pw.EdgeInsets.symmetric(horizontal: 50),
                      child: pw.Text(
                        'a obtenu(e) avec succès le titre de',
                        style: pw.TextStyle(fontSize: 16),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    
                    pw.SizedBox(height: 20),
                    
                    // Titre de certification
                    pw.Container(
                      padding: pw.EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                      decoration: pw.BoxDecoration(
                        color: certColor,
                        borderRadius: pw.BorderRadius.circular(5),
                      ),
                      child: pw.Text(
                        highestCertification['name'],
                        style: pw.TextStyle(
                          fontSize: 22,
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    
                    pw.SizedBox(height: 20),
                    
                    // Points
                    pw.Text(
                      'Avec un total de $points points accumulés',
                      style: pw.TextStyle(fontSize: 14),
                    ),
                    
                    pw.SizedBox(height: 40),
                    
                    // Ligne de signature
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                      children: [
                        pw.Column(
                          children: [   pw.Text(
                              'L\'université de Gabes ',
                              style: pw.TextStyle(fontSize: 12),
                            ),
                            pw.SizedBox(height: 5),
                            pw.Container(
                              width: 150,
                              height: 1,
                              color: PdfColors.black,
                            ),
                            pw.SizedBox(height: 5),
                            pw.Text(
                              'Directeur du Programme',
                              style: pw.TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        pw.Column(
                          children: [
                            pw.Text(
                              DateFormat('le dd/MM/yyyy').format(DateTime.now()),
                              style: pw.TextStyle(fontSize: 12),
                            ),
                            pw.SizedBox(height: 5),
                            pw.Container(
                              width: 150,
                              height: 1,
                              color: PdfColors.black,
                            ),
                            pw.SizedBox(height: 5),
                            pw.Text(
                              'Date',
                              style: pw.TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                    
                    // Cachet officiel (optionnel)
                    pw.Positioned(
                      right: 50,
                      bottom: 50,
                      child: pw.Container(
                        width: 80,
                        height: 80,
                        decoration: pw.BoxDecoration(
                          shape: pw.BoxShape.circle,
                          border: pw.Border.all(
                            color: PdfColors.red,
                            width: 2,
                          ),
                        ),
                        child: pw.Center(
                          child: pw.Text(
                            'OFFICIEL',
                            style: pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.red,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    // Export du PDF
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Erreur lors de la génération du certificat: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}



 Future<void> _generateHistoriquePDF() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Récupérer les données
      final query = await FirebaseFirestore.instance
          .collection('postulations')
          .where('idEtudiant', isEqualTo: user.uid)
          .where('statut', isEqualTo: 'accepté')
          .where('participationConfirmee', isEqualTo: true)
          .orderBy('dateConfirmation', descending: true)
          .get();

      // Préparer les données pour le PDF
      final List<Map<String, dynamic>> pdfData = [];
      
      for (final postulation in query.docs) {
        final data = postulation.data() as Map<String, dynamic>;
        final action = await FirebaseFirestore.instance
            .collection('actions_volontariat')
            .doc(data['idAction'])
            .get();
        final actionData = action.data() as Map<String, dynamic>? ?? {};
        
        pdfData.add({
          'titre': actionData['titre'] ?? 'Action inconnue',
          'description': actionData['description'] ?? '',
          'lieu': actionData['lieu'] ?? 'Lieu inconnu',
          'date': DateFormat('dd/MM/yyyy')
              .format((data['dateConfirmation'] as Timestamp).toDate()),
          'points': actionData['points'] ?? 0,
        });
      }

      // Générer le PDF
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(
                  level: 0,
                  child: pw.Text('Mon Historique de Participation',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      )),
                ),
                pw.SizedBox(height: 20),
                pw.Text('Étudiant: ${user.email}'),
                pw.SizedBox(height: 10),
                pw.Text('Date d\'export: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}'),
                pw.SizedBox(height: 30),
                ...pdfData.map((participation) => pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      participation['titre'],
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(participation['description']),
                    pw.SizedBox(height: 5),
                    pw.Row(
                      children: [
                        pw.Text('Lieu: '),
                        pw.Text(participation['lieu']),
                      ],
                    ),
                    pw.Row(
                      children: [
                        pw.Text('Date: '),
                        pw.Text(participation['date']),
                      ],
                    ),
                    pw.Row(
                      children: [
                        pw.Text('Points: '),
                        pw.Text('${participation['points']}'),
                      ],
                    ),
                    pw.Divider(),
                    pw.SizedBox(height: 10),
                  ],
                )).toList(),
              ],
            );
          },
        ),
      );

          // Exporter le PDF
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la génération du PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
        borderRadius: BorderRadius.circular(15),
      ),
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
                        color: Color(0xFF226D68),
                      ),
                    ),
                  ),
                  Chip(
                    label: Text(
                      '$points pts',
                      style: TextStyle(color: Colors.white),
                    ),
                    backgroundColor: Color(0xFF226D68),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (description.isNotEmpty)
                Text(
                  description,
                  style: TextStyle(color: Colors.grey[700]),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.location_on, size: 18, color: Colors.grey),
                  const SizedBox(width: 5),
                  Text(
                    lieu,
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                  const SizedBox(width: 5),
                  Text(
                    'Du $dateDebut au $dateFin',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
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
                Text(
                  'Chargement des actions...',
                  style: TextStyle(color: Colors.grey),
                ),
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
                      child: CircularProgressIndicator(color: Color(0xFF226D68)),
                    ),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
              Text(
                data['titre'] ?? '',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF226D68),
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Du $dateDebut au $dateFin',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                data['description'] ?? '',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 20),
              if (data['competencesRequises'] != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Compétences requises:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
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
                      borderRadius: BorderRadius.circular(10),
                    ),
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