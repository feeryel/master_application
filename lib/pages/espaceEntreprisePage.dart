import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';

class EspaceEntreprisePage extends StatefulWidget {
  const EspaceEntreprisePage({super.key});

  @override
  State<EspaceEntreprisePage> createState() => _EspaceEntreprisePageState();
}

class _EspaceEntreprisePageState extends State<EspaceEntreprisePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? _entrepriseData;
  bool _isLoading = true;
  int _nombreActionsSponsorisees = 0;
  List<DocumentSnapshot> _actions = [];
  bool _isSponsoring = false;

  // Palette de couleurs
  final Color primaryColor = const Color(0xFF226D68);
  final Color secondaryColor = const Color(0xFF439A97);
  final Color accentColor = const Color(0xFF62B6B7);
  final Color backgroundColor = const Color(0xFFF8F9FA);
  final Color successColor = const Color(0xFF4CC9F0);
  final Color warningColor = const Color(0xFFF72585);

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      await _loadEntrepriseData();
      await _loadStats();
      await _loadActions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur: ${e.toString()}"),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            backgroundColor: warningColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadEntrepriseData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doc = await _firestore.collection('entreprises').doc(user.uid).get();
    if (doc.exists) {
      setState(() => _entrepriseData = doc.data());
    }
  }

  Future<void> _loadStats() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final actionsQuery = await _firestore
        .collection('actions_volontariat')
        .where('sponsors', arrayContains: user.uid)
        .get();

    setState(() {
      _nombreActionsSponsorisees = actionsQuery.size;
    });
  }

  Future<void> _loadActions() async {
    setState(() => _isLoading = true);
    
    try {
      final snapshot = await _firestore
          .collection('actions_volontariat')
          .orderBy('dateFin')
          .get();

      setState(() {
        _actions = snapshot.docs;
      });
    } catch (e) {
      debugPrint('Erreur chargement actions: $e');
    }
  }

  Future<void> _sponsoriserAction(String actionId) async {
    final user = _auth.currentUser;
    if (user == null || !mounted) return;

    try {
      setState(() => _isSponsoring = true);

      await _firestore.collection('actions_volontariat').doc(actionId).update({
        'sponsors': FieldValue.arrayUnion([user.uid]),
        'dateMiseAJour': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Sponsoring confirmé !"),
          backgroundColor: successColor,
        ),
      );

      await _loadStats();
      await _loadActions();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Échec: ${e.toString()}"),
          backgroundColor: warningColor,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSponsoring = false);
      }
    }
  }

  Future<void> _logout() async {
    try {
      await _auth.signOut();
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
          backgroundColor: warningColor,
        ),
      );
    }
  }

  Widget _buildDrawer() {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.7,
      elevation: 16,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(25)),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [primaryColor.withOpacity(0.9), primaryColor],
          ),
        ),
        child: Column(
          children: [
            // Header avec logo et infos entreprise
            Container(
              padding: const EdgeInsets.only(top: 50, bottom: 20),
              child: Column(
                children: [
                  // Logo entreprise
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.2),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Icon(Icons.business, size: 40, color: Colors.white),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    _entrepriseData?['nom']?.toUpperCase() ?? "ENTREPRISE",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _auth.currentUser?.email ?? "",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            
            // Séparateur
            Divider(
              color: Colors.white.withOpacity(0.3),
              thickness: 1,
              indent: 20,
              endIndent: 20,
              height: 30,
            ),
            
            // Menu items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: [
                  _buildDrawerItem(
                    icon: Icons.dashboard,
                    title: 'Tableau de bord',
                    isSelected: true,
                    onTap: () => Navigator.pop(context),
                  ),
                  _buildDrawerItem(
                    icon: Icons.business_center,
                    title: 'Mon entreprise',
                    onTap: _showInformationsDialog,
                  ),
                  _buildDrawerItem(
                    icon: Icons.analytics,
                    title: 'Statistiques',
                    onTap: () {},
                  ),
                  _buildDrawerItem(
                    icon: Icons.settings,
                    title: 'Paramètres',
                    onTap: () {},
                  ),
                ],
              ),
            ),
            
            // Bouton de déconnexion
            Padding(
              padding: const EdgeInsets.all(20),
              child: OutlinedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout, size: 20, color: Colors.white),
                label: const Text('Déconnexion', 
                  style: TextStyle(color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withOpacity(0.5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    bool isSelected = false,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: Icon(icon, 
          color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
          size: 24,
        ),
        title: Text(title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.8),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: () {
          Navigator.pop(context);
          onTap();
        },
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showInformationsDialog() {
    bool isEditing = false;
    bool isSaving = false;
    
    TextEditingController _nomController = TextEditingController(text: _entrepriseData?['nom'] ?? '');
    TextEditingController _phoneController = TextEditingController(text: _entrepriseData?['numTel'] ?? '');
    TextEditingController _codeFiscaleController = TextEditingController(text: _entrepriseData?['codeFiscale'] ?? '');
    TextEditingController _rneController = TextEditingController(text: _entrepriseData?['rne'] ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            Future<void> _saveChanges() async {
              setModalState(() => isSaving = true);
              try {
                await _firestore
                    .collection('entreprises')
                    .doc(_auth.currentUser?.uid)
                    .update({
                  'nom': _nomController.text,
                  'numTel': _phoneController.text,
                  'codeFiscale': _codeFiscaleController.text,
                  'rne': _rneController.text,
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                setState(() {
                  _entrepriseData?['nom'] = _nomController.text;
                  _entrepriseData?['numTel'] = _phoneController.text;
                  _entrepriseData?['codeFiscale'] = _codeFiscaleController.text;
                  _entrepriseData?['rne'] = _rneController.text;
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Modifications enregistrées !'),
                    backgroundColor: successColor,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erreur: ${e.toString()}'),
                    backgroundColor: warningColor,
                  ),
                );
              } finally {
                setModalState(() {
                  isSaving = false;
                  isEditing = false;
                });
              }
            }

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              padding: const EdgeInsets.only(top: 20, left: 20, right: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: primaryColor),
                          const SizedBox(width: 10),
                          Text(
                            'Informations entreprise',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                      isSaving
                          ? CircularProgressIndicator(color: primaryColor)
                          : IconButton(
                              icon: Icon(isEditing ? Icons.save : Icons.edit),
                              onPressed: () async {
                                if (isEditing) {
                                  await _saveChanges();
                                } else {
                                  setModalState(() => isEditing = true);
                                }
                              },
                            ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildEditableInfoField(
                            label: 'Nom',
                            value: _nomController,
                            icon: Icons.business_rounded,
                            isEditing: isEditing,
                            primaryColor: primaryColor,
                          ),
                          _buildEditableInfoField(
                            label: 'Téléphone',
                            value: _phoneController,
                            icon: Icons.phone_rounded,
                            isEditing: isEditing,
                            primaryColor: primaryColor,
                            keyboardType: TextInputType.phone,
                          ),
                          _buildEditableInfoField(
                            label: 'Code fiscale',
                            value: _codeFiscaleController,
                            icon: Icons.numbers_rounded,
                            isEditing: isEditing,
                            primaryColor: primaryColor,
                          ),
                          _buildEditableInfoField(
                            label: 'RNE',
                            value: _rneController,
                            icon: Icons.badge_rounded,
                            isEditing: isEditing,
                            primaryColor: primaryColor,
                          ),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEditableInfoField({
    required String label,
    required TextEditingController value,
    required IconData icon,
    required bool isEditing,
    required Color primaryColor,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        children: [
          Icon(icon, color: primaryColor, size: 24),
          const SizedBox(width: 15),
          Expanded(
            child: isEditing
                ? TextField(
                    controller: value,
                    decoration: InputDecoration(
                      labelText: label,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType: keyboardType,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        value.text.isEmpty ? 'Non renseigné' : value.text,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String value, String label, IconData icon, Color color) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.42,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1);
  }

  Widget _buildActionCard(DocumentSnapshot action) {
    final data = action.data() as Map<String, dynamic>;
    final sponsors = List<String>.from(data['sponsors'] ?? []);
    final estSponsor = sponsors.contains(_auth.currentUser?.uid);

    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    data['titre'] ?? 'Action sans titre',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),
                if (estSponsor)
                  Chip(
                    label: Text("Sponsorisée", style: TextStyle(color: Colors.white)),
                    backgroundColor: successColor,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(data['description'] ?? 'Pas de description'),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text("${_formatDate(data['dateDebut'])} - ${_formatDate(data['dateFin'])}"),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: estSponsor ? Colors.grey : primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: estSponsor ? null : () => _sponsoriserAction(action.id),
                child: _isSponsoring
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        estSponsor ? "Sponsorisée" : "Sponsoriser",
                        style: TextStyle(color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic date) {
    try {
      if (date is Timestamp) {
        return DateFormat('dd/MM/yyyy').format(date.toDate());
      } else if (date is String) {
        final parsedDate = DateTime.parse(date);
        return DateFormat('dd/MM/yyyy').format(parsedDate);
      }
    } catch (e) {
      debugPrint('Erreur de formatage de date: $e');
    }
    return 'Date inconnue';
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Bonjour,",
          style: TextStyle(
            fontSize: 18,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 5),
        Text(
          _entrepriseData?['nom'] ?? 'Entreprise',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          "Voici votre tableau de bord",
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text("Espace Entreprise"),
        backgroundColor: primaryColor,
        elevation: 0,
        foregroundColor: Colors.white,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadInitialData,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            )
          : RefreshIndicator(
              color: primaryColor,
              onRefresh: _loadInitialData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 30),
                    const Text(
                      "Statistiques",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatCard(
                          _nombreActionsSponsorisees.toString(),
                          "Actions sponsorisées",
                          Icons.volunteer_activism_rounded,
                          accentColor,
                        ),
                        _buildStatCard(
                          _actions.length.toString(),
                          "Actions disponibles",
                          Icons.event_available_rounded,
                          secondaryColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      "Actions disponibles",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    if (_actions.isEmpty)
                      Center(
                        child: Column(
                          children: [
                            Icon(Icons.volunteer_activism, size: 50, color: Colors.grey),
                            const SizedBox(height: 20),
                            Text(
                              "Aucune action disponible actuellement",
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    else
                      ..._actions.map((action) => _buildActionCard(action)).toList(),
                  ],
                ),
              ),
            ),
    );
  }
}

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text('Page de connexion')),
    );
  }
}