import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:master_application/pages/espaceEtablissementPage.dart';
import 'package:master_application/pages/loginPage.dart';
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
    _loadHistorique();
  }

  Future<void> _loadHistorique() async {
    try {
      setState(() => _isLoading = true);
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final actionsQuery = await FirebaseFirestore.instance
          .collection('actions_volontariat')
          .where('idEtablissement', isEqualTo: user.uid)
          .where('statut', isEqualTo: 'Terminé')
          .orderBy('dateFin', descending: true)
          .get();

      if (!mounted) return;
      setState(() {
        _historiqueActions = actionsQuery.docs;
      });

      for (var action in _historiqueActions) {
        final participationsQuery = await FirebaseFirestore.instance
            .collection('postulations')
            .where('idAction', isEqualTo: action.id)
            .where('statut', isEqualTo: 'accepté')
            .get();

        if (!mounted) return;
        setState(() {
          _participationsParAction[action.id] = participationsQuery.docs;
        });
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
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _generatePdf() async {
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
                child: pw.Text('Historique des Actions',
                    style: pw.TextStyle(
                        fontSize: 24, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 20),
              ..._historiqueActions.map((action) {
                final data = action.data() as Map<String, dynamic>;
                final participations = _participationsParAction[action.id] ?? [];
                
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(data['titre'] ?? 'Action sans titre',
                        style: pw.TextStyle(
                            fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    pw.Text(
                        'Terminée le ${data['dateFin']} • ${participations.length} participant${participations.length > 1 ? 's' : ''}'),
                    pw.SizedBox(height: 8),
                    pw.Text('Participants:',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    participations.isEmpty
                        ? pw.Text('Aucune participation enregistrée')
                        : pw.Column(
                            children: participations.map((participation) {
                              final partData =
                                  participation.data() as Map<String, dynamic>;
                              return pw.Padding(
                                padding: const pw.EdgeInsets.only(left: 16, top: 4),
                                child: pw.Text(
                                    '- ${partData['nomComplet'] ?? 'Participant inconnu'} (${partData['email'] ?? ''})'),
                              );
                            }).toList(),
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

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  Widget _buildParticipantList(List<DocumentSnapshot> participations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
          child: Text(
            'Participants:',
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
              'Aucune participation enregistrée',
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
              trailing: partData['participationConfirmee'] == true
                  ? Icon(Icons.verified, color: successColor)
                  : Icon(Icons.pending, color: warningColor),
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
                  'Terminée le ${data['dateFin']} • ${participations.length} participant${participations.length > 1 ? 's' : ''}',
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
                  'Historique des Actions',
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
            onPressed: _historiqueActions.isEmpty ? null : _generatePdf,
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
              onPressed: _loadHistorique,
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
              onRefresh: _loadHistorique,
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
                          action, 
                          _participationsParAction[action.id] ?? []
                        )
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}