import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:master_application/pages/gestionActionsPage.dart';
import 'package:master_application/pages/gestionPostulationsPage.dart';
import 'package:master_application/pages/loginPage.dart';

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
          SnackBar(content: Text("Erreur: ${e.toString()}")),
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
        SnackBar(content: Text("Erreur: ${e.toString()}")),
      );
    }
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(etablissementData?['nom'] ?? "Établissement"),
            accountEmail: Text(_currentUser?.email ?? ""),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.school, color: Color(0xFF226D68)),
            ),
            decoration: const BoxDecoration(color: Color(0xFF226D68)),
          ),
          ListTile(
            leading: const Icon(Icons.info, color: Color(0xFF226D68)),
            title: const Text('Informations'),
            onTap: () {
              Navigator.pop(context);
              _showInformationsDialog();
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings, color: Color(0xFF226D68)),
            title: const Text('Paramètres'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ParametresPage(
                    etablissementData: etablissementData,
                    onUpdate: _loadInitialData,
                  ),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Color(0xFF226D68)),
            title: const Text('Déconnexion'),
            onTap: _logout,
          ),
        ],
      ),
    );
  }

  void _showInformationsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Informations établissement'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInfoRow('Nom', etablissementData?['nom']),
                _buildInfoRow('Email', _currentUser?.email),
                _buildInfoRow('Téléphone', etablissementData?['numTel']),
                _buildInfoRow('Région', etablissementData?['region']),
                _buildInfoRow('Catégorie', etablissementData?['categorie']),
                const SizedBox(height: 16),
                if (etablissementData?['description'] != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Description:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(etablissementData?['description'] ?? ''),
                    ],
                  ),
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

  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value ?? 'Non renseigné')),
        ],
      ),
    );
  }

  Widget _buildDashboardButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget destination,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => destination),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF226D68).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 28, color: const Color(0xFF226D68)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String value, String label) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF226D68),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
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
        title: const Text("Espace Établissement"),
        backgroundColor: const Color(0xFF226D68),
      ),
      drawer: _buildDrawer(),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadInitialData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Tableau de bord",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatCard(nombreActions.toString(), "Actions"),
                        _buildStatCard(nombrePostulations.toString(), "Postulations"),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildDashboardButton(
                      icon: Icons.event_note,
                      title: "Gestion des actions",
                      subtitle: "Créer et modifier vos actions",
                      destination: const GestionActionsPage(),
                    ),
                    _buildDashboardButton(
                      icon: Icons.people_alt,
                      title: "Gestion des postulations",
                      subtitle: "Voir et valider les candidatures",
                      destination: const GestionPostulationsPage(),
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

  const ParametresPage({
    super.key,
    required this.etablissementData,
    required this.onUpdate,
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
        const SnackBar(content: Text('Modifications enregistrées !')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
        backgroundColor: const Color(0xFF226D68),
        actions: [
          IconButton(
            icon: _isSaving
                ? const CircularProgressIndicator(color: Colors.white)
                : const Icon(Icons.save),
            onPressed: _isSaving ? null : _saveChanges,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Coordonnées',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF226D68),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Numéro de téléphone',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF226D68),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descriptionController,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        hintText: 'Décrivez votre établissement...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}