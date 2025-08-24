import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:master_application/pages/notification_service.dart';

class ListeCandidatsPage extends StatefulWidget {
  final String idAction;
  final String titreAction;

  const ListeCandidatsPage({
    Key? key,
    required this.idAction,
    required this.titreAction,
  }) : super(key: key);

  @override
  State<ListeCandidatsPage> createState() => _ListeCandidatsPageState();
}

class _ListeCandidatsPageState extends State<ListeCandidatsPage> {
  final Map<String, Map<String, dynamic>> _studentsCache = {};
  final Map<String, Map<String, dynamic>> _entreprisesCache = {};
  final ScrollController _scrollController = ScrollController();
  List<DocumentSnapshot> _loadedPostulations = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  DocumentSnapshot? _lastDocument;
  String? _errorMessage;
  String _filterStatut = 'tous';
  final Color primaryColor = const Color(0xFF226D68);

  Color _getStatusColor(String? statut) {
    switch (statut?.toLowerCase()) {
      case 'accepté':
        return Colors.green;
      case 'refusé':
        return Colors.red;
      case 'annulée':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  IconData _getStatusIcon(String? statut) {
    switch (statut?.toLowerCase()) {
      case 'accepté':
        return Icons.check_circle;
      case 'refusé':
        return Icons.cancel;
      case 'annulée':
        return Icons.block;
      default:
        return Icons.access_time;
    }
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
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

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _loadInitialData();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _studentsCache.clear();
    _entreprisesCache.clear();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.offset >= _scrollController.position.maxScrollExtent &&
        !_scrollController.position.outOfRange &&
        !_isLoadingMore &&
        _lastDocument != null) {
      _loadMoreData();
    }
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      Query query = FirebaseFirestore.instance
          .collection('postulations')
          .where('idAction', isEqualTo: widget.idAction)
          .orderBy('createdAt', descending: true);

      if (_filterStatut != 'tous') {
        query = query.where('statut', isEqualTo: _filterStatut);
      } else {
        query = query.where('statut', whereNotIn: ['annulée']);
      }

      final snapshot = await query.limit(15).get();

      if (mounted) {
        setState(() {
          _loadedPostulations = snapshot.docs;
          _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Erreur de chargement: ${e.toString()}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage!)),
        );
      }
    }
  }

  Future<void> _loadMoreData() async {
    if (_isLoadingMore || _lastDocument == null) return;

    try {
      setState(() => _isLoadingMore = true);

      Query query = FirebaseFirestore.instance
          .collection('postulations')
          .where('idAction', isEqualTo: widget.idAction)
          .orderBy('createdAt', descending: true);

      if (_filterStatut != 'tous') {
        query = query.where('statut', isEqualTo: _filterStatut);
      } else {
        query = query.where('statut', whereNotIn: ['annulée']);
      }

      final snapshot = await query.startAfterDocument(_lastDocument!).limit(15).get();

      if (mounted) {
        setState(() {
          _loadedPostulations.addAll(snapshot.docs);
          _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _refreshData() async {
    await _loadInitialData();
  }

  Future<void> _changeFilter(String newFilter) async {
    setState(() {
      _filterStatut = newFilter;
      _loadedPostulations = [];
      _lastDocument = null;
    });
    await _loadInitialData();
  }

  Future<Map<String, dynamic>> _getStudentData(String studentId) async {
    if (_studentsCache.containsKey(studentId)) {
      return _studentsCache[studentId]!;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('etudiants')
          .doc(studentId)
          .get();

      if (doc.exists) {
        final studentData = doc.data()!;
        _studentsCache[studentId] = studentData;
        return studentData;
      }
      return {};
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}')),
        );
      }
      return {};
    }
  }

  Future<Map<String, dynamic>> _getEntrepriseData(String entrepriseId) async {
    if (_entreprisesCache.containsKey(entrepriseId)) {
      return _entreprisesCache[entrepriseId]!;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('entreprises')
          .doc(entrepriseId)
          .get();

      if (doc.exists) {
        final entrepriseData = doc.data()!;
        _entreprisesCache[entrepriseId] = entrepriseData;
        return entrepriseData;
      }
      return {};
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}')),
        );
      }
      return {};
    }
  }

  Future<void> _updateStatut(String postulationId, String newStatut, String studentId) async {
    try {
      await FirebaseFirestore.instance
          .collection('postulations')
          .doc(postulationId)
          .update({
            'statut': newStatut,
            'traiteLe': Timestamp.now(),
          });

      if (newStatut == 'accepté') {
        await FirebaseFirestore.instance
            .collection('postulations')
            .doc(postulationId)
            .update({
              'pointsAttributed': false,
            });
      }

      await _sendStudentNotification(
        studentId: studentId,
        actionId: widget.idAction,
        newStatus: newStatut,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Statut mis à jour !"),
          backgroundColor: Colors.green,
        ),
      );
      await _refreshData();
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

  Future<void> _addPointsToStudent(String studentId, String postulationId) async {
    try {
      final postulationDoc = await FirebaseFirestore.instance
          .collection('postulations')
          .doc(postulationId)
          .get();

      if (postulationDoc.data()?['statut'] != 'accepté' ||
          postulationDoc.data()?['participationConfirmee'] != true ||
          postulationDoc.data()?['pointsAttributed'] == true) {
        return;
      }

      final actionDoc = await FirebaseFirestore.instance
          .collection('actions_volontariat')
          .doc(widget.idAction)
          .get();

      final points = actionDoc.data()?['points'] ?? 10;

      await FirebaseFirestore.instance
          .collection('etudiants')
          .doc(studentId)
          .update({
            'points': FieldValue.increment(points),
          });

      await FirebaseFirestore.instance
          .collection('postulations')
          .doc(postulationId)
          .update({
            'pointsAttributed': true,
          });
    } catch (e) {
      debugPrint('Erreur lors de l\'ajout des points: $e');
    }
  }

  Future<void> _sendStudentNotification({
    required String studentId,
    required String actionId,
    required String newStatus,
  }) async {
    try {
      final actionDoc = await FirebaseFirestore.instance
          .collection('actions_volontariat')
          .doc(actionId)
          .get();

      final titre = actionDoc.data()?['titre'] ?? 'Action inconnue';

      await NotificationService.sendNotificationToStudent(
        studentId: studentId,
        title: 'Mise à jour candidature',
        body: 'Votre candidature pour "$titre" a été ${_getStatusText(newStatus)}',
      );
    } catch (e) {
      debugPrint('Erreur notification: $e');
    }
  }

  String _getStatusText(String? statut) {
    switch (statut?.toLowerCase()) {
      case 'accepté':
        return 'acceptée';
      case 'refusé':
        return 'refusée';
      case 'annulée':
        return 'annulée';
      default:
        return 'en attente';
    }
  }

  Widget _buildStatutWidget(String? statut) {
    Color color;
    IconData icon;

    switch (statut?.toLowerCase()) {
      case 'accepté':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'refusé':
        color = Colors.red;
        icon = Icons.cancel;
        break;
      case 'annulée':
        color = Colors.grey;
        icon = Icons.block;
        break;
      default:
        color = Colors.orange;
        icon = Icons.access_time;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            _getStatusText(statut).toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    const filters = [
      {'value': 'tous', 'label': 'Tous'},
      {'value': 'en_attente', 'label': 'En attente'},
      {'value': 'accepté', 'label': 'Acceptés'},
      {'value': 'refusé', 'label': 'Refusés'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: filters.map((filter) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(filter['label']!),
              selected: _filterStatut == filter['value'],
              onSelected: (selected) => _changeFilter(filter['value']!),
              selectedColor: primaryColor,
              labelStyle: TextStyle(
                color: _filterStatut == filter['value'] ? Colors.white : Colors.black,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCandidatCard(DocumentSnapshot postulation) {
    final data = postulation.data() as Map<String, dynamic>;
    final date = (data['createdAt'] as Timestamp).toDate();

    return FutureBuilder<Map<String, dynamic>>(
      future: _getStudentData(data['idEtudiant']),
      builder: (context, snapshot) {
        final student = snapshot.data ?? {};
        final nomComplet = '${student['prenom']} ${student['nom']}'.trim();
        final initials = nomComplet.isNotEmpty
            ? nomComplet.split(' ').map((n) => n[0]).take(2).join()
            : '?';

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _showDetailsDialog(postulation, student, data, nomComplet, initials),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: primaryColor,
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nomComplet.isNotEmpty ? nomComplet : 'Candidat inconnu',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('dd/MM/yyyy à HH:mm').format(date),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatutWidget(data['statut']),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSponsorCard(DocumentSnapshot contribution) {
    final data = contribution.data() as Map<String, dynamic>;

    return FutureBuilder<Map<String, dynamic>>(
      future: _getEntrepriseData(data['entrepriseId']),
      builder: (context, snapshot) {
        final entreprise = snapshot.data ?? {};
        final nomEntreprise = entreprise['nom']?.toString() ?? 'Entreprise inconnue';
        final initials = nomEntreprise.isNotEmpty
            ? nomEntreprise.split(' ').map((n) => n[0]).take(2).join()
            : '?';

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: primaryColor,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nomEntreprise,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data['type'] == 'argent'
                            ? 'Montant: ${data['details']} TND'
                            : 'Matériel: ${data['details']}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  data['type'] == 'argent' ? Icons.monetization_on : Icons.inventory,
                  color: primaryColor,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDetailsDialog(
    DocumentSnapshot postulation,
    Map<String, dynamic> studentData,
    Map<String, dynamic> postulationData,
    String nomComplet,
    String initials,
  ) {
    final statut = postulationData['statut']?.toString().toLowerCase();
    final postulationId = postulation.id;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nomComplet.isNotEmpty ? nomComplet : 'Candidat inconnu',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Postulé le ${DateFormat('dd MMM yyyy à HH:mm').format((postulationData['createdAt'] as Timestamp).toDate())}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildDetailItem(Icons.account_circle_outlined, 'Nom', studentData['nom']?.toString() ?? postulationData['nom']?.toString() ?? 'Non renseigné'),
                  _buildDetailItem(Icons.account_circle_outlined, 'Prenom', studentData['prenom']?.toString() ?? postulationData['prenom']?.toString() ?? 'Non renseigné'),
                  _buildDetailItem(Icons.email, 'Email', studentData['email']?.toString() ?? postulationData['email']?.toString() ?? 'Non renseigné'),
                  _buildDetailItem(Icons.phone, 'Téléphone', studentData['numTel']?.toString() ?? 'Non renseigné'),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getStatusColor(statut).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _getStatusIcon(statut),
                          color: _getStatusColor(statut),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Statut: ${_getStatusText(statut)}',
                          style: TextStyle(
                            color: _getStatusColor(statut),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey,
                        ),
                        child: const Text('FERMER'),
                      ),
                      if (statut != 'accepté' && statut != 'annulée')
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _updateStatut(postulationId, 'accepté', postulationData['idEtudiant']);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('ACCEPTER'),
                        ),
                      if (statut != 'refusé' && statut != 'annulée')
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _updateStatut(postulationId, 'refusé', postulationData['idEtudiant']);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('REFUSER'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Candidats & Sponsors - ${widget.titreAction}",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilterChips(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(child: Text(_errorMessage!))
                    : RefreshIndicator(
                        onRefresh: _refreshData,
                        child: ListView(
                          controller: _scrollController,
                          children: [
                            // Titre pour la liste des candidats
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              child: Text(
                                'Liste des candidats pour cette action',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                            // Liste des candidats
                            _loadedPostulations.isEmpty && !_isLoadingMore
                                ? const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Center(child: Text("Aucun candidat")),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: _loadedPostulations.length + (_isLoadingMore ? 1 : 0),
                                    itemBuilder: (context, index) {
                                      if (index >= _loadedPostulations.length) {
                                        return const Padding(
                                          padding: EdgeInsets.all(16),
                                          child: Center(child: CircularProgressIndicator()),
                                        );
                                      }
                                      return _buildCandidatCard(_loadedPostulations[index]);
                                    },
                                  ),
                            // Titre pour la liste des sponsors
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              child: Text(
                                'Nos Sponsors pour cette action',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                            // Liste des sponsors
                            FutureBuilder<QuerySnapshot>(
                              future: FirebaseFirestore.instance
                                  .collection('actions_volontariat')
                                  .doc(widget.idAction)
                                  .collection('contributions')
                                  .get(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const Center(child: CircularProgressIndicator());
                                }
                                if (snapshot.hasError) {
                                  return Center(child: Text('Erreur: ${snapshot.error}'));
                                }
                                final contributions = snapshot.data?.docs ?? [];
                                if (contributions.isEmpty) {
                                  return const Center(child: Text('Aucun sponsor pour cette action'));
                                }
                                return ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: contributions.length,
                                  itemBuilder: (context, index) {
                                    return _buildSponsorCard(contributions[index]);
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}