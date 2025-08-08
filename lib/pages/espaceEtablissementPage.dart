import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:master_application/pages/gestionActionsPage.dart';
import 'package:master_application/pages/gestionPostulationsPage.dart';
import 'package:master_application/pages/loginPage.dart';
import 'package:flutter_animate/flutter_animate.dart';

class EspaceEtablissementPage extends StatefulWidget {
  const EspaceEtablissementPage({super.key});

  @override
  State<EspaceEtablissementPage> createState() => _EspaceEtablissementPageState();
}

class _EspaceEtablissementPageState extends State<EspaceEtablissementPage> {
  Map<String, dynamic>? etablissementData;
  bool isLoading = true;
  int nombreActions = 0;
  int nombrePostulations = 0;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

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
    setState(() => isLoading = true);
    try {
      await _loadEtablissementData();
      await _loadStats();
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
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _loadEtablissementData() async {
    if (_currentUser == null) return;
    
    final doc = await FirebaseFirestore.instance
        .collection('etablissements')
        .doc(_currentUser!.uid)
        .get();

    if (doc.exists) {
      setState(() => etablissementData = doc.data());
    }
  }

  Future<void> _loadStats() async {
    if (_currentUser == null) return;

    final actionsQuery = await FirebaseFirestore.instance
        .collection('actions_volontariat')
        .where('idEtablissement', isEqualTo: _currentUser!.uid)
        .get();

    final postulationsQuery = await FirebaseFirestore.instance
        .collection('postulations')
        .where('idEtablissement', isEqualTo: _currentUser!.uid)
        .get();

    setState(() {
      nombreActions = actionsQuery.size;
      nombrePostulations = postulationsQuery.size;
    });
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
          backgroundColor: warningColor,
        ),
      );
    }
  }

Widget _buildDrawer() {
  return Drawer(
    width: MediaQuery.of(context).size.width * 0.75,
    elevation: 10,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.horizontal(right: Radius.circular(25)),
    ),
    child: Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _buildDrawerHeader(),
              _buildDrawerItem(
                icon: Icons.dashboard_rounded,
                title: 'Tableau de bord',
                isSelected: true,
                onTap: () => Navigator.pop(context),
              ),
              _buildDrawerItem(
                icon: Icons.info_outline_rounded,
                title: 'Informations',
                onTap: _showInformationsDialog,
              ),
              _buildDrawerItem(
                icon: Icons.settings_rounded,
                title: 'Paramètres',
                onTap: _navigateToSettings,
              ),
            ],
          ),
        ),
        _buildLogoutButton(),
      ],
    ),
  );
}

  Widget _buildDrawerHeader() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryColor, secondaryColor],
        ),
        borderRadius: const BorderRadius.only(
          bottomRight: Radius.circular(25),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            bottom: 0,
            right: 0,
            child: Opacity(
              opacity: 0.1,
              child: Icon(Icons.school, size: 150, color: Colors.white),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 20, bottom: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: Icon(Icons.school, size: 30, color: Colors.white),
                ),
                const SizedBox(height: 15),
                Text(
                  etablissementData?['nom'] ?? "Établissement",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _currentUser?.email ?? "",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
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
    bool isSelected = false,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected 
              ? primaryColor.withOpacity(0.2) 
              : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, 
            color: isSelected ? primaryColor : Colors.grey[700],
          ),
        ),
        title: Text(title,
          style: TextStyle(
            color: isSelected ? primaryColor : Colors.grey[800],
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

  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: ElevatedButton.icon(
        onPressed: _logout,
        icon: const Icon(Icons.logout_rounded, size: 20),
        label: const Text('Déconnexion'),
        style: ElevatedButton.styleFrom(
          foregroundColor: warningColor,
          backgroundColor: warningColor.withOpacity(0.1),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        ),
      ),
    );
  }

  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ParametresPage(
          etablissementData: etablissementData,
          onUpdate: _loadInitialData,
          primaryColor: primaryColor,
        ),
      ),
    ).then((_) => _loadInitialData());
  }

  void _showInformationsDialog() {
    bool isEditing = false;
    bool isSaving = false;
    
    TextEditingController _nomController = TextEditingController(text: etablissementData?['nom'] ?? '');
    TextEditingController _phoneController = TextEditingController(text: etablissementData?['numTel'] ?? '');
    TextEditingController _regionController = TextEditingController(text: etablissementData?['region'] ?? '');
    TextEditingController _categorieController = TextEditingController(text: etablissementData?['categorie'] ?? '');
    TextEditingController _descriptionController = TextEditingController(text: etablissementData?['description'] ?? '');

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
                await FirebaseFirestore.instance
                    .collection('etablissements')
                    .doc(_currentUser?.uid)
                    .update({
                  'nom': _nomController.text,
                  'numTel': _phoneController.text,
                  'region': _regionController.text,
                  'categorie': _categorieController.text,
                  'description': _descriptionController.text,
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                // Mettre à jour les données locales
                setState(() {
                  etablissementData?['nom'] = _nomController.text;
                  etablissementData?['numTel'] = _phoneController.text;
                  etablissementData?['region'] = _regionController.text;
                  etablissementData?['categorie'] = _categorieController.text;
                  etablissementData?['description'] = _descriptionController.text;
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Modifications enregistrées !'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erreur: ${e.toString()}'),
                    backgroundColor: Colors.red,
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
                            'Informations établissement',
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
                            icon: Icons.school_rounded,
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
                            label: 'Région',
                            value: _regionController,
                            icon: Icons.location_on_rounded,
                            isEditing: isEditing,
                            primaryColor: primaryColor,
                          ),
                          _buildEditableInfoField(
                            label: 'Catégorie',
                            value: _categorieController,
                            icon: Icons.category_rounded,
                            isEditing: isEditing,
                            primaryColor: primaryColor,
                          ),
                          const SizedBox(height: 15),
                          Text(
                            'Description',
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: isEditing
                                  ? TextField(
                                      controller: _descriptionController,
                                      maxLines: 4,
                                      decoration: InputDecoration.collapsed(
                                        hintText: 'Entrez la description...',
                                      ),
                                    )
                                  : Text(
                                      _descriptionController.text.isEmpty
                                          ? 'Aucune description'
                                          : _descriptionController.text,
                                    ),
                            ),
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

  Widget _buildDashboardButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget destination,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.9),
            color.withOpacity(0.7),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: () => _navigateWithAnimation(destination),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 28, color: Colors.white),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.1);
  }

  void _navigateWithAnimation(Widget page) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.5, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutQuint,
              )),
              child: child,
            ),
          );
        },
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
          etablissementData?['nom'] ?? 'Établissement',
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
        title: const Text("Espace Établissement"),
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
      body: isLoading
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
                          nombreActions.toString(),
                          "Actions en cours",
                          Icons.event_available_rounded,
                          accentColor,
                        ),
                        _buildStatCard(
                          nombrePostulations.toString(),
                          "Postulations",
                          Icons.people_alt_rounded,
                          secondaryColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      "Gestion",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    _buildDashboardButton(
                      icon: Icons.event_note_rounded,
                      title: "Actions",
                      subtitle: "Gérer vos actions et événements",
                      destination: const GestionActionsPage(),
                      color: primaryColor,
                    ),
                    _buildDashboardButton(
                      icon: Icons.people_alt_rounded,
                      title: "Participations",
                      subtitle: "Voir et gérer les participations",
                      destination: const GestionPostulationsPage(),
                      color: secondaryColor,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class ParametresPage extends StatefulWidget {
  final Map<String, dynamic>? etablissementData;
  final VoidCallback onUpdate;
  final Color primaryColor;

  const ParametresPage({
    super.key,
    required this.etablissementData,
    required this.onUpdate,
    required this.primaryColor,
  });

  @override
  State<ParametresPage> createState() => _ParametresPageState();
}

class _ParametresPageState extends State<ParametresPage> {
  late TextEditingController _descriptionController;
  late TextEditingController _phoneController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(
      text: widget.etablissementData?['description'] ?? '',
    );
    _phoneController = TextEditingController(
      text: widget.etablissementData?['numTel'] ?? '',
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('etablissements')
          .doc(user.uid)
          .update({
        'description': _descriptionController.text,
        'numTel': _phoneController.text,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      widget.onUpdate();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Modifications enregistrées avec succès !'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          backgroundColor: widget.primaryColor,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        children: [
          Icon(icon, color: widget.primaryColor, size: 20),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              color: widget.primaryColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Paramètres'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        centerTitle: false,
        actions: [
          _isSaving
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(widget.primaryColor),
                  ),
                )
              : TextButton(
                  onPressed: _saveChanges,
                  child: const Text('Enregistrer',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
                side: BorderSide(color: Colors.grey[200]!),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('Coordonnées', Icons.contact_phone_rounded),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: 'Numéro de téléphone',
                        prefixIcon: Icon(Icons.phone_rounded, color: widget.primaryColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: widget.primaryColor),
                        ),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
                side: BorderSide(color: Colors.grey[200]!),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('Description', Icons.description_rounded),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _descriptionController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: 'Décrivez votre établissement...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: widget.primaryColor),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveChanges,
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: widget.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 2,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'SAUVEGARDER LES MODIFICATIONS',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}