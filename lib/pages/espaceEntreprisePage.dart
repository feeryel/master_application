import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:master_application/pages/loginPage.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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
  int _nombreActionsEntreprise = 0;
  List<DocumentSnapshot> _actions = [];
  List<DocumentSnapshot> _sponsoredActions = [];
  List<DocumentSnapshot> _establishments = [];
  List<DocumentSnapshot> _entrepriseActions = [];
  List<DocumentSnapshot> _sponsorshipHistory = [];

  bool _isSponsoring = false;
  int _currentIndex = 0;
  DocumentSnapshot? _selectedEtablissement;

  // Palette de couleurs professionnelle
  final Color primaryColor = const Color(0xFF226D68);
  final Color secondaryColor = const Color(0xFF439A97);
  final Color accentColor = const Color(0xFF62B6B7);
  final Color backgroundColor = const Color(0xFFF8F9FA);
  final Color successColor = const Color(0xFF4CC9F0);
  final Color warningColor = const Color(0xFFF72585);
  final Color cardColor = Colors.white;
  final Color textPrimary = const Color(0xFF2D3748);
  final Color textSecondary = const Color(0xFF718096);

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      await _loadEntrepriseData();
      await _loadEstablishments();
      await _loadActions();
      await _loadStats();
      await _loadSponsorshipHistory();

    } catch (e) {
      debugPrint('Erreur lors du chargement initial: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur: ${e.toString()}"),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: warningColor,
            margin: const EdgeInsets.all(16),
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

  Future<void> _loadEstablishments() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await _firestore.collection('etablissements').get();
      setState(() => _establishments = snapshot.docs);
    } catch (e) {
      debugPrint('Erreur chargement établissements: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Erreur de chargement des établissements"),
            backgroundColor: warningColor,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadActions() async {
    setState(() => _isLoading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Load all actions
      final allActions = await _firestore
          .collection('actions_volontariat')
          .orderBy('dateFin')
          .get();

      // Load sponsored actions
      final sponsored = await _firestore
          .collection('actions_volontariat')
          .where('sponsors', arrayContains: user.uid)
          .get();

      // Load enterprise-specific actions
      List<DocumentSnapshot> entrepriseActions = [];
      if (_establishments.isNotEmpty) {
        final etablissementIds = _establishments.map((e) => e.id).toSet();
        for (String etablissementId in etablissementIds) {
          final actionsQuery = await _firestore
              .collection('actions_volontariat')
              .where('idEtablissement', isEqualTo: etablissementId)
              .get();
          entrepriseActions.addAll(actionsQuery.docs);
        }
      }

      // Remove duplicates by action ID
      final uniqueEntrepriseActions = entrepriseActions
          .asMap()
          .entries
          .fold<Map<String, DocumentSnapshot>>(
            {},
            (map, entry) => map..[entry.value.id] = entry.value,
          )
          .values
          .toList();

      setState(() {
        _actions = allActions.docs;
        _sponsoredActions = sponsored.docs;
        _entrepriseActions = uniqueEntrepriseActions;
        _nombreActionsEntreprise = uniqueEntrepriseActions.length;
      });
    } catch (e) {
      debugPrint('Erreur chargement actions: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur chargement actions: $e"),
            backgroundColor: warningColor,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _generateAndPrintPDF() async {
    try {
      setState(() => _isLoading = true);

      final user = _auth.currentUser;
      if (user == null) return;

      // Collecter toutes les données de manière asynchrone
      List<Map<String, dynamic>> historyWithDetails = [];
      for (var doc in _sponsorshipHistory) {
        final data = doc.data() as Map<String, dynamic>;

        // Récupérer les contributions
        final contribSnap = await _firestore
            .collection('actions_volontariat')
            .doc(doc.id)
            .collection('contributions')
            .where('entrepriseId', isEqualTo: user.uid)
            .get();

        String contributionDetails = 'Aucune contribution';
        if (contribSnap.docs.isNotEmpty) {
          final contribution = contribSnap.docs.first.data();
          contributionDetails = contribution['type'] == 'argent'
              ? 'Montant: ${contribution['details']} TND'
              : 'Matériel: ${contribution['details']}';
        }

        // Récupérer le nom de l'établissement (optionnel, mais pour cohérence)
        final etabDoc = await _firestore.collection('etablissements').doc(data['idEtablissement']).get();
        final etabNom = etabDoc.data()?['nom'] ?? 'Non spécifié';

        historyWithDetails.add({
          'titre': data['titre'] ?? 'Action sans titre',
          'etablissement': etabNom,
          'dateDebut': formatDate(data['dateDebut']),
          'dateFin': formatDate(data['dateFin']),
          'statut': data['statut'] ?? 'Inconnu',
          'contribution': contributionDetails,
        });
      }

      // Créer le PDF
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(
                  level: 0,
                  child: pw.Text(
                    'Historique des Sponsorships - ${_entrepriseData?['nom'] ?? 'Non spécifié'}',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Les actions sponsorisés',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                // pw.Text(
                //   'Date de génération: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                //   style: const pw.TextStyle(fontSize: 12),
                // ),
                pw.SizedBox(height: 20),
                ...historyWithDetails.map((item) {
                  return pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        item['titre'],
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'Établissement: ${item['etablissement']}',
                        style: pw.TextStyle(fontSize: 12),
                      ),
                      pw.Text(
                        'Dates: ${item['dateDebut']} - ${item['dateFin']}',
                        style: pw.TextStyle(fontSize: 12),
                      ),
                      pw.Text(
                        'Statut: ${item['statut']}',
                        style: pw.TextStyle(fontSize: 12),
                      ),
                      pw.Text(
                        'Contribution: ${item['contribution']}',
                        style: pw.TextStyle(fontSize: 12),
                      ),
                      pw.Divider(),
                      pw.SizedBox(height: 16),
                    ],
                  );
                }).toList(),
              ],
            );
          },
        ),
      );

      // Imprimer ou partager le PDF
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur lors de la génération du PDF: ${e.toString()}"),
            backgroundColor: warningColor,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStats() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final actionsQuery = await _firestore
          .collection('actions_volontariat')
          .where('sponsors', arrayContains: user.uid)
          .get();

      setState(() {
        _nombreActionsSponsorisees = actionsQuery.size;
      });
    } catch (e) {
      debugPrint('Erreur chargement stats: $e');
    }
  }

  Future<void> _sponsoriserAction(String actionId, String contributionType, String contributionDetails) async {
    final user = _auth.currentUser;
    if (user == null || !mounted) return;
    try {
      setState(() => _isSponsoring = true);

      // Mettre à jour l'action pour inclure l'utilisateur comme sponsor
      await _firestore.collection('actions_volontariat').doc(actionId).update({
        'sponsors': FieldValue.arrayUnion([user.uid]),
        'dateMiseAJour': FieldValue.serverTimestamp(),
      });

      // Enregistrer les détails de la contribution dans une sous-collection
      await _firestore
          .collection('actions_volontariat')
          .doc(actionId)
          .collection('contributions')
          .add({
        'entrepriseId': user.uid,
        'type': contributionType,
        'details': contributionDetails,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Sponsoring confirmé avec succès !"),
          backgroundColor: successColor,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
      await _loadStats();
      await _loadActions();
      await _loadSponsorshipHistory();
      if (_currentIndex == 4) {
        setState(() => _currentIndex = 3); // Retourner à l'onglet Établissements
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Échec: ${e.toString()}"),
          backgroundColor: warningColor,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSponsoring = false);
      }
    }
  }

  Future<void> _loadSponsorshipHistory() async {
    setState(() => _isLoading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Charger les actions sponsorisées par l'entreprise
      final snapshot = await _firestore
          .collection('actions_volontariat')
          .where('sponsors', arrayContains: user.uid)
          .orderBy('dateMiseAJour', descending: true)
          .get();

      setState(() => _sponsorshipHistory = snapshot.docs);
    } catch (e) {
      debugPrint('Erreur chargement historique: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Erreur de chargement de l'historique"),
            backgroundColor: warningColor,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: primaryColor),
              const SizedBox(height: 16),
              Text(
                'Déconnexion en cours...',
                style: TextStyle(color: textPrimary),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      await _auth.signOut();
      if (!mounted) return;

      Navigator.of(context).pop();

      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const LoginPage(),
          transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
          transitionDuration: const Duration(milliseconds: 400),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur: ${e.toString()}"),
          backgroundColor: warningColor,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Widget _buildDrawer() {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.75,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(0)),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              primaryColor,
              primaryColor.withOpacity(0.9),
              secondaryColor,
            ],
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
              child: Column(
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.15),
                      border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.business_rounded, size: 45, color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _entrepriseData?['nom']?.toUpperCase() ?? "ENTREPRISE",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _auth.currentUser?.email ?? "",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.white.withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                children: [
                  _buildDrawerItem(
                    icon: Icons.dashboard_rounded,
                    title: 'Tableau de bord',
                    isSelected: _currentIndex == 0,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _currentIndex = 0);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.volunteer_activism_rounded,
                    title: 'Actions à sponsoriser',
                    isSelected: _currentIndex == 1,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _currentIndex = 1);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.verified_rounded,
                    title: 'Actions sponsorisées',
                    isSelected: _currentIndex == 2,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _currentIndex = 2);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.business_rounded,
                    title: 'Établissements',
                    isSelected: _currentIndex == 3,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _currentIndex = 3);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.info_outline_rounded,
                    title: 'Mon entreprise',
                    isSelected: _currentIndex == 4,
                    onTap: () {
                      Navigator.pop(context);
                      _showInformationsDialog();
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.info_outline_rounded,
                    title: 'Historique des sponsorships',
                    isSelected: _currentIndex == 5,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _currentIndex = 5);
                    },
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(24),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _logout,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout_rounded, size: 20, color: Colors.white),
                          const SizedBox(width: 12),
                          Text(
                            'Déconnexion',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? Colors.white : Colors.white.withOpacity(0.8),
                  size: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white.withOpacity(0.9),
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          ),
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
                    content: const Text('Modifications enregistrées !'),
                    backgroundColor: successColor,
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.all(16),
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erreur: ${e.toString()}'),
                    backgroundColor: warningColor,
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.all(16),
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
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.only(top: 16, bottom: 8),
                    child: Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.business_rounded, color: primaryColor, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Informations entreprise',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              ),
                              Text(
                                'Gérez les informations de votre entreprise',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSaving)
                          Container(
                            padding: const EdgeInsets.all(8),
                            child: CircularProgressIndicator(color: primaryColor, strokeWidth: 2),
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                              color: isEditing ? successColor : primaryColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () async {
                                  if (isEditing) {
                                    await _saveChanges();
                                  } else {
                                    setModalState(() => isEditing = true);
                                  }
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  child: Icon(
                                    isEditing ? Icons.save_rounded : Icons.edit_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          _buildEditableInfoField(
                            label: 'Nom de l\'entreprise',
                            value: _nomController,
                            icon: Icons.business_rounded,
                            isEditing: isEditing,
                            primaryColor: primaryColor,
                          ),
                          const SizedBox(height: 24),
                          _buildEditableInfoField(
                            label: 'Numéro de téléphone',
                            value: _phoneController,
                            icon: Icons.phone_rounded,
                            isEditing: isEditing,
                            primaryColor: primaryColor,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 24),
                          _buildEditableInfoField(
                            label: 'Code fiscale',
                            value: _codeFiscaleController,
                            icon: Icons.numbers_rounded,
                            isEditing: isEditing,
                            primaryColor: primaryColor,
                          ),
                          const SizedBox(height: 24),
                          _buildEditableInfoField(
                            label: 'Numéro RNE',
                            value: _rneController,
                            icon: Icons.badge_rounded,
                            isEditing: isEditing,
                            primaryColor: primaryColor,
                          ),
                          const SizedBox(height: 40),
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isEditing ? Colors.grey[50] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEditing ? primaryColor.withOpacity(0.3) : Colors.grey[200]!,
          width: isEditing ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: primaryColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: isEditing
                ? TextField(
                    controller: value,
                    decoration: InputDecoration(
                      labelText: label,
                      labelStyle: TextStyle(color: primaryColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: primaryColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: primaryColor, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    keyboardType: keyboardType,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        value.text.isEmpty ? 'Non renseigné' : value.text,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: value.text.isEmpty ? Colors.grey[400] : textPrimary,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String value, String label, IconData icon, Color color, {String? subtitle}) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.42,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
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
                  height: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: TextStyle(
              color: textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: successColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1);
  }

  Widget _buildBackToDashboardButton() {
    return Container(
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() => _currentIndex = 0);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(8),
            child: Icon(
              Icons.arrow_back,
              color: primaryColor,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabHeader(String title, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor.withOpacity(0.1),
            accentColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    if (_currentIndex == 4) {
                      _currentIndex = 3; // Return to Établissements tab
                    } else {
                      _currentIndex = 0; // Return to dashboard
                    }
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.arrow_back,
                    color: primaryColor,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    final actionsEntrepriseSponsorisees = _entrepriseActions.where((action) {
      final data = action.data() as Map<String, dynamic>;
      final sponsors = List<String>.from(data['sponsors'] ?? []);
      return sponsors.contains(_auth.currentUser?.uid);
    }).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
    
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildStatCard(
              _establishments.length.toString(),
              "Établissements",
              Icons.business_rounded,
              secondaryColor,
            ),
            _buildStatCard(
              _actions.length.toString(),
              "Total actions",
              Icons.verified_rounded,
              primaryColor,
            ),
          ],
        ),
        const SizedBox(height: 48),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.dashboard_rounded, color: primaryColor, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              "Accès rapide",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.6,
          children: [
            _buildQuickAccessButton(
              "Actions à sponsoriser",
              Icons.volunteer_activism_rounded,
              primaryColor,
              () => setState(() => _currentIndex = 1),
            ),
            _buildQuickAccessButton(
              "Actions sponsorisées",
              Icons.verified_rounded,
              successColor,
              () => setState(() => _currentIndex = 2),
            ),
            _buildQuickAccessButton(
              "Établissements",
              Icons.business_rounded,
              secondaryColor,
              () => setState(() => _currentIndex = 3),
            ),
            _buildQuickAccessButton(
              "Mon entreprise",
              Icons.info_outline_rounded,
              accentColor,
              _showInformationsDialog,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickAccessButton(String title, IconData icon, Color color, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, size: 24, color: color),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

void _showSponsorshipDialog(String actionId) {
  String contributionType = 'argent'; // Par défaut : argent
  TextEditingController montantController = TextEditingController();
  TextEditingController materielController = TextEditingController();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.5,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sponsoriser l\'action',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Type de contribution',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ChoiceChip(
                        label: Text('Argent'),
                        selected: contributionType == 'argent',
                        onSelected: (selected) {
                          if (selected) {
                            setModalState(() => contributionType = 'argent');
                          }
                        },
                        selectedColor: primaryColor.withOpacity(0.2),
                        labelStyle: TextStyle(
                          color: contributionType == 'argent' ? primaryColor : textSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text('Matériel'),
                        selected: contributionType == 'materiel',
                        onSelected: (selected) {
                          if (selected) {
                            setModalState(() => contributionType = 'materiel');
                          }
                        },
                        selectedColor: primaryColor.withOpacity(0.2),
                        labelStyle: TextStyle(
                          color: contributionType == 'materiel' ? primaryColor : textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (contributionType == 'argent')
                    TextField(
                      controller: montantController,
                      decoration: InputDecoration(
                        labelText: 'Montant (TND)',
                        labelStyle: TextStyle(color: primaryColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: primaryColor, width: 2),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                    )
                  else
                    TextField(
                      controller: materielController,
                      decoration: InputDecoration(
                        labelText: 'Description du matériel',
                        labelStyle: TextStyle(color: primaryColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: primaryColor, width: 2),
                        ),
                      ),
                      maxLines: 3,
                    ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: warningColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context); // Ferme la boîte de dialogue
                        },
                        child: Text(
                          'Annuler',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () async {
                          if ((contributionType == 'argent' && montantController.text.isNotEmpty) ||
                              (contributionType == 'materiel' && materielController.text.isNotEmpty)) {
                            if (contributionType == 'argent' && double.tryParse(montantController.text) == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Veuillez entrer un montant valide'),
                                  backgroundColor: warningColor,
                                  behavior: SnackBarBehavior.floating,
                                  margin: const EdgeInsets.all(16),
                                ),
                              );
                              return;
                            }
                            await _sponsoriserAction(
                              actionId,
                              contributionType,
                              contributionType == 'argent'
                                  ? montantController.text
                                  : materielController.text,
                            );
                            Navigator.pop(context);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Veuillez remplir tous les champs'),
                                backgroundColor: warningColor,
                                behavior: SnackBarBehavior.floating,
                                margin: const EdgeInsets.all(16),
                              ),
                            );
                          }
                        },
                        child: Text(
                          'Confirmer',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
Widget _buildActionCard(DocumentSnapshot action) {
  final data = action.data() as Map<String, dynamic>;
  final sponsors = List<String>.from(data['sponsors'] ?? []);
  final estSponsor = sponsors.contains(_auth.currentUser?.uid);

  return FutureBuilder<DocumentSnapshot>(
    future: _firestore.collection('etablissements').doc(data['idEtablissement']).get(),
    builder: (context, snapshot) {
      final etablissement = snapshot.data?.data() as Map<String, dynamic>?;
      final etablissementNom = etablissement?['nom'] ?? 'Établissement inconnu';

      return FutureBuilder<QuerySnapshot>(
        future: _firestore
            .collection('actions_volontariat')
            .doc(action.id)
            .collection('contributions')
            .where('entrepriseId', isEqualTo: _auth.currentUser?.uid)
            .get(),
        builder: (context, contributionsSnapshot) {
          String typeContribution = '';
          String detailsContribution = '';

          if (contributionsSnapshot.hasData && contributionsSnapshot.data!.docs.isNotEmpty) {
            final contribution = contributionsSnapshot.data!.docs.first.data() as Map<String, dynamic>;
            typeContribution = contribution['type'] == 'argent' ? 'Argent' : 'Matériel';
            detailsContribution = contribution['details'] ?? '';
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 15,
                  spreadRadius: 0,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
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
                            color: textPrimary,
                          ),
                        ),
                      ),
                      if (estSponsor)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: successColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "Sponsorisée",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: secondaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.business_rounded, size: 16, color: secondaryColor),
                        const SizedBox(width: 6),
                        Text(
                          etablissementNom,
                          style: TextStyle(
                            color: secondaryColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (estSponsor) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: typeContribution == 'Argent' 
                            ? Colors.green.withOpacity(0.1)
                            : Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            typeContribution == 'Argent' 
                                ? Icons.monetization_on_rounded 
                                : Icons.inventory_2_rounded,
                            size: 16,
                            color: typeContribution == 'Argent' ? Colors.green : Colors.blue,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Contribution: $typeContribution',
                            style: TextStyle(
                              color: typeContribution == 'Argent' ? Colors.green : Colors.blue,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (detailsContribution.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded, size: 16, color: textSecondary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                typeContribution == 'Argent' 
                                    ? 'Montant: $detailsContribution TND'
                                    : 'Matériel: $detailsContribution',
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    data['description'] ?? 'Pas de description',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 16, color: textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          "${formatDate(data['dateDebut'])} - ${formatDate(data['dateFin'])}",
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: estSponsor
                            ? []
                            : [
                                BoxShadow(
                                  color: primaryColor.withOpacity(0.3),
                                  blurRadius: 10,
                                  spreadRadius: 0,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: estSponsor ? Colors.grey[300] : primaryColor,
                          foregroundColor: estSponsor ? Colors.grey[600] : Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: estSponsor ? null : () => _showSponsorshipDialog(action.id),
                        child: _isSponsoring
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    estSponsor ? Icons.check_rounded : Icons.volunteer_activism_rounded,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    estSponsor ? "Sponsorisée" : "Sponsoriser",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
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
}




void _showSponsorsDetails(String actionId, String actionTitle) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Sponsors - $actionTitle',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<QuerySnapshot>(
                future: _firestore
                    .collection('actions_volontariat')
                    .doc(actionId)
                    .collection('contributions')
                    .get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: primaryColor));
                  }
                  
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Text(
                        'Aucun sponsor pour cette action',
                        style: TextStyle(color: textSecondary),
                      ),
                    );
                  }
                  
                  final contributions = snapshot.data!.docs;
                  
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: contributions.length,
                    itemBuilder: (context, index) {
                      final contribution = contributions[index].data() as Map<String, dynamic>;
                      
                      return FutureBuilder<DocumentSnapshot>(
                        future: _firestore.collection('entreprises')
                            .doc(contribution['entrepriseId'])
                            .get(),
                        builder: (context, entrepriseSnapshot) {
                          if (entrepriseSnapshot.connectionState == ConnectionState.waiting) {
                            return Container();
                          }
                          
                          final entrepriseData = entrepriseSnapshot.data?.data() 
                              as Map<String, dynamic>?;
                          final entrepriseNom = entrepriseData?['nom'] 
                              ?? 'Entreprise inconnue';
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    contribution['type'] == 'argent' 
                                        ? Icons.monetization_on_rounded 
                                        : Icons.inventory_2_rounded,
                                    color: primaryColor,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entrepriseNom,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        contribution['type'] == 'argent'
                                            ? 'Contribution: ${contribution['details']} TND'
                                            : 'Contribution: ${contribution['details']}',
                                        style: TextStyle(
                                          color: textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}




Widget _buildSponsoredActionCard(DocumentSnapshot action) {
  final data = action.data() as Map<String, dynamic>;

  return FutureBuilder<DocumentSnapshot>(
    future: _firestore.collection('etablissements').doc(data['idEtablissement']).get(),
    builder: (context, snapshot) {
      final etablissement = snapshot.data?.data() as Map<String, dynamic>?;
      final etablissementNom = etablissement?['nom'] ?? 'Établissement inconnu';

      return FutureBuilder<QuerySnapshot>(
        future: _firestore
            .collection('actions_volontariat')
            .doc(action.id)
            .collection('contributions')
            .where('entrepriseId', isEqualTo: _auth.currentUser?.uid)
            .get(),
        builder: (context, contributionSnapshot) {
          String typeContribution = 'Non spécifié';
          String detailsContribution = '';

          if (contributionSnapshot.hasData && contributionSnapshot.data!.docs.isNotEmpty) {
            final contribution = contributionSnapshot.data!.docs.first.data() as Map<String, dynamic>;
            typeContribution = contribution['type'] == 'argent' ? 'Argent' : 'Matériel';
            detailsContribution = contribution['details'] ?? '';
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: successColor.withOpacity(0.3), width: 2),
              boxShadow: [
                BoxShadow(
                  color: successColor.withOpacity(0.1),
                  blurRadius: 15,
                  spreadRadius: 0,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
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
                            color: textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: successColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_rounded, size: 16, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              "Sponsorisée",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: secondaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.business_rounded, size: 16, color: secondaryColor),
                        const SizedBox(width: 6),
                        Text(
                          etablissementNom,
                          style: TextStyle(
                            color: secondaryColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // AFFICHAGE DU TYPE DE CONTRIBUTION
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: typeContribution == 'Argent' 
                          ? Colors.green.withOpacity(0.1)
                          : Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          typeContribution == 'Argent' 
                              ? Icons.monetization_on_rounded 
                              : Icons.inventory_2_rounded,
                          size: 16,
                          color: typeContribution == 'Argent' ? Colors.green : Colors.blue,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Contribution: $typeContribution',
                          style: TextStyle(
                            color: typeContribution == 'Argent' ? Colors.green : Colors.blue,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // AFFICHAGE DES DÉTAILS DE LA CONTRIBUTION
                  if (detailsContribution.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 16, color: textSecondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              typeContribution == 'Argent' 
                                  ? 'Montant: $detailsContribution TND'
                                  : 'Matériel: $detailsContribution',
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  
                  Text(
                    data['description'] ?? 'Pas de description',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 16, color: textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          "${formatDate(data['dateDebut'])} - ${formatDate(data['dateFin'])}",
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
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
}
  Widget _buildEstablishmentCard(DocumentSnapshot etablissement) {
    final data = etablissement.data() as Map<String, dynamic>;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.business_rounded, color: primaryColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    data['nom'] ?? 'Établissement sans nom',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: secondaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    data['categorie'] ?? 'Non spécifié',
                    style: TextStyle(
                      color: secondaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    data['region'] ?? 'Région inconnue',
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (data['description'] != null && data['description'].isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                data['description'],
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
            if (data['numTel'] != null && data['numTel'].isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.phone_rounded, size: 16, color: textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      data['numTel'],
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            FutureBuilder<QuerySnapshot>(
              future: _firestore
                  .collection('actions_volontariat')
                  .where('idEtablissement', isEqualTo: etablissement.id)
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: CircularProgressIndicator(color: primaryColor, strokeWidth: 2),
                    ),
                  );
                }

                final actions = snapshot.data?.docs ?? [];
                final sponsoredActions = actions.where((action) {
                  final actionData = action.data() as Map<String, dynamic>;
                  final sponsors = List<String>.from(actionData['sponsors'] ?? []);
                  return sponsors.contains(_auth.currentUser?.uid);
                }).toList();

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.event_available_rounded, size: 20, color: textSecondary),
                          const SizedBox(width: 8),
                          Text(
                            "Actions disponibles: ${actions.length}",
                            style: TextStyle(
                              color: textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      if (sponsoredActions.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.verified_rounded, size: 20, color: successColor),
                            const SizedBox(width: 8),
                            Text(
                              "Dont ${sponsoredActions.length} sponsorisées par vous",
                              style: TextStyle(
                                color: successColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                  setState(() {
                    _currentIndex = 4;
                    _selectedEtablissement = etablissement;
                  });
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.visibility_rounded, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      "Voir les actions",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
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

  Widget _buildEmptyState(String message, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(40),
      margin: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 50, color: Colors.grey[400]),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              style: TextStyle(
                color: textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsList(bool sponsoredOnly) {
    final actions = sponsoredOnly
        ? _sponsoredActions
        : _actions.where((action) {
            final data = action.data() as Map<String, dynamic>;
            final sponsors = List<String>.from(data['sponsors'] ?? []);
            return !sponsors.contains(_auth.currentUser?.uid);
          }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTabHeader(
          sponsoredOnly ? "Vos actions sponsorisées" : "Actions disponibles",
          sponsoredOnly ? Icons.verified_rounded : Icons.volunteer_activism_rounded,
          sponsoredOnly ? successColor : primaryColor,
        ),
        const SizedBox(height: 20),
        if (actions.isEmpty)
          _buildEmptyState(
            sponsoredOnly
                ? "Vous n'avez sponsorisé aucune action"
                : "Aucune action disponible actuellement",
            sponsoredOnly ? Icons.volunteer_activism_rounded : Icons.event_available_rounded,
          )
        else
          ...actions.map((action) => sponsoredOnly
              ? _buildSponsoredActionCard(action)
              : _buildActionCard(action)).toList(),
      ],
    );
  }

  Widget _buildEstablishmentsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTabHeader(
          "Liste des établissements",
          Icons.business_rounded,
          secondaryColor,
        ),
        const SizedBox(height: 20),
        if (_establishments.isEmpty)
          _buildEmptyState("Aucun établissement trouvé", Icons.business_rounded)
        else
          ..._establishments.map((etablissement) => _buildEstablishmentCard(etablissement)).toList(),
      ],
    );
  }

  Widget _buildEstablishmentActions() {
    if (_selectedEtablissement == null) {
      return _buildEmptyState("Aucun établissement sélectionné", Icons.error_outline_rounded);
    }

    final data = _selectedEtablissement!.data() as Map<String, dynamic>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTabHeader(
          "Actions de ${data['nom'] ?? 'Établissement'}",
          Icons.event_available_rounded,
          primaryColor,
        ),
        const SizedBox(height: 20),
        FutureBuilder<QuerySnapshot>(
          future: _firestore
              .collection('actions_volontariat')
              .where('idEtablissement', isEqualTo: _selectedEtablissement!.id)
              .get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: primaryColor),
                    const SizedBox(height: 16),
                    Text(
                      'Chargement des actions...',
                      style: TextStyle(color: textSecondary),
                    ),
                  ],
                ),
              );
            }

            final actions = snapshot.data?.docs ?? [];

            if (actions.isEmpty) {
              return _buildEmptyState(
                "Aucune action pour cet établissement",
                Icons.event_available_rounded,
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: actions.length,
              itemBuilder: (context, index) {
                return _buildActionCard(actions[index]);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor.withOpacity(0.1),
            accentColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Bonjour,",
            style: TextStyle(
              fontSize: 16,
              color: textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _entrepriseData?['nom'] ?? 'Entreprise',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Voici votre tableau de bord",
            style: TextStyle(
              fontSize: 16,
              color: textSecondary,
            ),
          ),
        ],
      ),
    );
  }

Widget _buildSponsorshipHistory() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: _buildTabHeader(
              "Historique des Sponsorships",
              Icons.history_rounded,
              accentColor,
            ),
          ),
          if (_sponsorshipHistory.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 24),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: Icon(Icons.print_rounded, color: primaryColor),
                onPressed: _generateAndPrintPDF,
                tooltip: 'Exporter en PDF',
              ),
            ),
        ],
      ),
      const SizedBox(height: 20),
      if (_sponsorshipHistory.isEmpty)
        _buildEmptyState(
          "Aucun historique de sponsorship trouvé",
          Icons.history_rounded,
        )
      else
        ..._sponsorshipHistory.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return FutureBuilder<DocumentSnapshot>(
            future: _firestore.collection('etablissements').doc(data['idEtablissement']).get(),
            builder: (context, snapshot) {
              final etablissement = snapshot.data?.data() as Map<String, dynamic>?;
              final etablissementNom = etablissement?['nom'] ?? 'Établissement inconnu';

              return FutureBuilder<QuerySnapshot>(
                future: _firestore
                    .collection('actions_volontariat')
                    .doc(doc.id)
                    .collection('contributions')
                    .where('entrepriseId', isEqualTo: _auth.currentUser?.uid)
                    .get(),
                builder: (context, contributionSnapshot) {
                  String contributionDetails = 'Aucune contribution';
                  String contributionType = 'Non spécifié';
                  if (contributionSnapshot.hasData && contributionSnapshot.data!.docs.isNotEmpty) {
                    final contribution = contributionSnapshot.data!.docs.first.data() as Map<String, dynamic>;
                    contributionType = contribution['type'] == 'argent' ? 'Argent' : 'Matériel';
                    contributionDetails = contribution['type'] == 'argent'
                        ? 'Montant: ${contribution['details']} TND'
                        : 'Matériel: ${contribution['details']}';
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    constraints: BoxConstraints(
                      minHeight: 180, // Hauteur minimale uniforme
                    ),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 15,
                          spreadRadius: 0,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['titre'] ?? 'Action inconnue',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Icon(Icons.business_rounded, size: 16, color: textSecondary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Établissement: $etablissementNom",
                                  style: TextStyle(
                                    color: textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.calendar_today_rounded, size: 16, color: textSecondary),
                              const SizedBox(width: 8),
                              Text(
                                "Dates: ${formatDate(data['dateDebut'])} - ${formatDate(data['dateFin'])}",
                                style: TextStyle(
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.info_outline_rounded, size: 16, color: textSecondary),
                              const SizedBox(width: 8),
                              Text(
                                "Statut: ${data['statut'] ?? 'Inconnu'}",
                                style: TextStyle(
                                  color: successColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                contributionType == 'Argent'
                                    ? Icons.monetization_on_rounded
                                    : Icons.inventory_2_rounded,
                                size: 16,
                                color: contributionType == 'Argent' ? Colors.green : Colors.blue,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  contributionDetails,
                                  style: TextStyle(
                                    color: textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (data['description'] != null && data['description'].isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text(
                              data['description'],
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        }).toList(),
    ],
  );
}
// Avant de parser la date, formatez-la correctement
String formatDate(String dateString) {
  try {
    // Essayer de parser directement
    DateTime.parse(dateString);
    return dateString;
  } catch (e) {
    // Formater manuellement si échec
    List<String> parts = dateString.split('-');
    if (parts.length == 3) {
      String year = parts[0];
      String month = parts[1].padLeft(2, '0');
      String day = parts[2].padLeft(2, '0');
      return '$year-$month-$day';
    }
    return dateString;
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          "Espace Entreprise",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        foregroundColor: Colors.white,
        centerTitle: false,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: _loadInitialData,
              tooltip: 'Actualiser',
            ),
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: primaryColor, strokeWidth: 3),
                  const SizedBox(height: 24),
                  Text(
                    'Chargement...',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              color: primaryColor,
              onRefresh: _loadInitialData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_currentIndex == 0)
                      _buildDashboard()
                    else if (_currentIndex == 1)
                      _buildActionsList(false) // Actions à sponsoriser
                    else if (_currentIndex == 2)
                      _buildActionsList(true) // Actions sponsorisées
                    else if (_currentIndex == 3)
                      _buildEstablishmentsTab()
                    else if (_currentIndex == 4)
                      _buildEstablishmentActions()
                    else if (_currentIndex == 5)
                      _buildSponsorshipHistory(),
                  ],
                ),
              ),
            ),
    );
  }
}