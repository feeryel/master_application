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
  final ScrollController _scrollController = ScrollController();
  List<DocumentSnapshot> _loadedPostulations = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  DocumentSnapshot? _lastDocument;
  String? _errorMessage;
  String _filterStatut = 'tous';

  Color _getStatusColor(String? statut) {
    switch (statut?.toLowerCase()) {
      case 'accepté': return Colors.green;
      case 'refusé': return Colors.red;
      case 'annulée': return Colors.grey;
      default: return Colors.orange;
    }
  }

  IconData _getStatusIcon(String? statut) {
    switch (statut?.toLowerCase()) {
      case 'accepté': return Icons.check_circle;
      case 'refusé': return Icons.cancel;
      case 'annulée': return Icons.block;
      default: return Icons.access_time;
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

    // Now we have studentId passed in, so no error
    await _sendStudentNotification(
      studentId: studentId,
      actionId: widget.idAction,
      newStatus: newStatut,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Statut mis à jour')),
      );
      await _refreshData();
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}')),
      );
    }
  }
}



Future<void> _addPointsToStudent(String studentId, String postulationId) async {
    try {
      // Vérifier si les points ont déjà été attribués
      final postulationDoc = await FirebaseFirestore.instance
          .collection('postulations')
          .doc(postulationId)
          .get();
      
       if (postulationDoc.data()?['statut'] != 'accepté' || 
          postulationDoc.data()?['participationConfirmee'] != true ||
          postulationDoc.data()?['pointsAttributed'] == true) {
        return;// Les points ont déjà été attribués
      }

      // Récupérer les points de l'action
      final actionDoc = await FirebaseFirestore.instance
          .collection('actions_volontariat')
          .doc(widget.idAction)
          .get();
      
      final points = actionDoc.data()?['points'] ?? 10;

      // Mettre à jour les points de l'étudiant
      await FirebaseFirestore.instance
          .collection('etudiants')
          .doc(studentId)
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
      case 'accepté': return 'acceptée';
      case 'refusé': return 'refusée';
      case 'annulée': return 'annulée';
      default: return 'en attente';
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
              selectedColor: const Color(0xFF226D68),
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
                    backgroundColor: const Color(0xFF226D68), // Couleur fixe pour l'avatar
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
                          color: const Color(0xFF226D68), // Couleur fixe pour l'avatar
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
          "Candidats - ${widget.titreAction}",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF226D68),
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(child: Text(_errorMessage!))
                    : _loadedPostulations.isEmpty
                        ? const Center(child: Text("Aucun candidat"))
                        : RefreshIndicator(
                            onRefresh: _refreshData,
                            child: ListView.builder(
                              controller: _scrollController,
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
                          ),
          ),
        ],
      ),
    );
  }
}