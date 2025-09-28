import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:master_application/pages/espaceEtablissementPage.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class HistoriquePage extends StatefulWidget {
  const HistoriquePage({Key? key}) : super(key: key);

  @override
  State<HistoriquePage> createState() => _HistoriquePageState();
}

class _HistoriquePageState extends State<HistoriquePage> {
  List<DocumentSnapshot> _historiqueActions = [];
  Map<String, List<DocumentSnapshot>> _participationsParAction = {};
  bool _isLoading = true;
  String? _etablissementName;

  // Couleurs du design system
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
    _initData();
  }

  // Initialisation : charger le nom de l'établissement + historique
  Future<void> _initData() async {
    setState(() => _isLoading = true);

    await _loadEtablissementName();
    await _loadHistorique();

    if (mounted) setState(() => _isLoading = false);
  }

  // Charger le nom de l'établissement
  Future<void> _loadEtablissementName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final query = await FirebaseFirestore.instance
          .collection('etablissements')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        _etablissementName = query.docs.first['nom'];
        print("✅ Nom établissement: $_etablissementName");
      } else {
        print("⚠️ Aucun établissement trouvé pour cet UID");
      }
    } catch (e) {
      print("❌ Erreur chargement établissement: $e");
    }
  }

  // Charger l'historique des actions
  Future<void> _loadHistorique() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final actionsQuery = await FirebaseFirestore.instance
          .collection('actions_volontariat')
          .where('idEtablissement', isEqualTo: user.uid)
          .where('statut', isEqualTo: 'Terminé')
          .orderBy('dateFin', descending: true)
          .get();

      if (!mounted) return;
      _historiqueActions = actionsQuery.docs;

      for (var action in _historiqueActions) {
        final participationsQuery = await FirebaseFirestore.instance
            .collection('postulations')
            .where('idAction', isEqualTo: action.id)
            .where('statut', isEqualTo: 'accepté')
            .get();

        if (!mounted) return;
        
        // Filtrer uniquement les participants avec participation confirmée (présents)
        final participationsConfirmees = participationsQuery.docs.where((participation) {
          final partData = participation.data() as Map<String, dynamic>;
          return partData['participationConfirmee'] == true;
        }).toList();

        _participationsParAction[action.id] = participationsConfirmees;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur: ${e.toString()}"),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: warningColor,
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  // Génération PDF
// Génération PDF
Future<void> _generatePdf() async {
  final pdf = pw.Document();

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // En-tête simple
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Historique des Actions',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      _etablissementName ?? 'Établissement',
                      style: pw.TextStyle(
                        fontSize: 14,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
                pw.Text(
                  '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                  style: pw.TextStyle(
                    fontSize: 12,
                    color: PdfColors.grey500,
                  ),
                ),
              ],
            ),
            
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 20),

            // Liste des actions
            if (_historiqueActions.isEmpty)
              pw.Center(
                child: pw.Text(
                  'Aucune action terminée',
                  style: pw.TextStyle(
                    fontSize: 16,
                    color: PdfColors.grey500,
                  ),
                ),
              )
            else
              ..._historiqueActions.map((action) {
                final data = action.data() as Map<String, dynamic>;
                final participations = _participationsParAction[action.id] ?? [];

                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 16),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey200, width: 1),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // En-tête de l'action
                      pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.all(12),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.blue50,
                          borderRadius: const pw.BorderRadius.only(
                            topLeft: pw.Radius.circular(8),
                            topRight: pw.Radius.circular(8),
                          ),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              data['titre'] ?? 'Action sans titre',
                              style: pw.TextStyle(
                                fontSize: 16,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.blue900,
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              'Terminée le ${data['dateFin']} • ${participations.length} participant${participations.length > 1 ? 's' : ''} présent${participations.length > 1 ? 's' : ''}',
                              style: pw.TextStyle(
                                fontSize: 12,
                                color: PdfColors.grey600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Participants
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(12),
                        child: participations.isEmpty
                            ? pw.Text(
                                'Aucun participant présent',
                                style: pw.TextStyle(
                                  fontSize: 12,
                                  color: PdfColors.grey500,
                                  fontStyle: pw.FontStyle.italic,
                                ),
                              )
                            : pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    'Participants présents:',
                                    style: pw.TextStyle(
                                      fontSize: 12,
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColors.grey700,
                                    ),
                                  ),
                                  pw.SizedBox(height: 8),
                                  ...participations.map((participation) {
                                    final partData = participation.data() as Map<String, dynamic>;
                                    return pw.Container(
                                      margin: const pw.EdgeInsets.only(bottom: 4),
                                      child: pw.Text(
                                        '• ${partData['nomComplet'] ?? 'Participant inconnu'}',
                                        style: pw.TextStyle(
                                          fontSize: 11,
                                          color: PdfColors.grey600,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ],
                              ),
                      ),
                    ],
                  ),
                );
              }).toList(),
          ],
        );
      },
    ),
  );

  await Printing.layoutPdf(
    onLayout: (PdfPageFormat format) async => pdf.save(),
  );
}
  // Widgets pour l'affichage
  Widget _buildParticipantList(List<DocumentSnapshot> participations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
          child: Text(
            'Participants présents:',
            style: TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (participations.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Aucun participant présent',
              style: TextStyle(color: textSecondary),
            ),
          )
        else
          ...participations.map((participation) {
            final partData = participation.data() as Map<String, dynamic>;
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: CircleAvatar(
                backgroundColor: primaryColor.withOpacity(0.1),
                child: Icon(Icons.person, color: primaryColor),
              ),
              title: Text(partData['nomComplet'] ?? 'Participant inconnu'),
              subtitle: Text(
                partData['email'] ?? '',
                style: TextStyle(color: textSecondary),
              ),
              trailing: Icon(Icons.verified, color: successColor),
            );
          }).toList(),
      ],
    );
  }

  Widget _buildActionCard(DocumentSnapshot action, List<DocumentSnapshot> participations) {
    final data = action.data() as Map<String, dynamic>;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['titre'] ?? 'Action sans titre',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Terminée le ${data['dateFin']} • ${participations.length} participant${participations.length > 1 ? 's' : ''} présent${participations.length > 1 ? 's' : ''}',
                  style: TextStyle(color: textSecondary),
                ),
              ],
            ),
          ),
          _buildParticipantList(participations),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_rounded,
            size: 64,
            color: textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune action terminée',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Vos actions terminées apparaîtront ici',
            style: TextStyle(
              fontSize: 14,
              color: textSecondary.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, accentColor],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.history_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _etablissementName != null
                      ? 'Historique des Actions - $_etablissementName'
                      : 'Historique des Actions',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_historiqueActions.length} action${_historiqueActions.length > 1 ? 's' : ''} terminée${_historiqueActions.length > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 14,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          "Historique",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: cardColor,
        elevation: 0,
        foregroundColor: textPrimary,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const EspaceEtablissementPage()),
            );
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.print, color: primaryColor),
            onPressed: (_historiqueActions.isEmpty || _etablissementName == null)
                ? null
                : _generatePdf,
            tooltip: 'Imprimer PDF',
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(Icons.refresh_rounded, color: primaryColor),
              onPressed: _initData,
              tooltip: 'Actualiser',
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  ),
                  const SizedBox(height: 16),
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
              backgroundColor: cardColor,
              onRefresh: _initData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 20),
                    if (_historiqueActions.isEmpty)
                      _buildEmptyState()
                    else
                      ..._historiqueActions.map((action) =>
                          _buildActionCard(
                              action, _participationsParAction[action.id] ?? [])),
                  ],
                ),
              ),
            ),
    );
  }
}