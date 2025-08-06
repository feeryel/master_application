import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

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
  List<DocumentSnapshot<Map<String, dynamic>>> _loadedPostulations = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  DocumentSnapshot<Map<String, dynamic>>? _lastDocument;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _loadInitialData();
  }

  @override
  void dispose() {
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

      final Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('postulations')
          .where('idAction', isEqualTo: widget.idAction)
          .orderBy('createdAt', descending: true)
          .limit(15);

      final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();

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

      final Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('postulations')
          .where('idAction', isEqualTo: widget.idAction)
          .orderBy('createdAt', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(15);

      final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();

      if (mounted) {
        setState(() {
          _loadedPostulations.addAll(snapshot.docs);
          _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          _errorMessage = 'Erreur de chargement: ${e.toString()}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage!)),
        );
      }
    }
  }

  Future<Map<String, dynamic>> _getStudentData(String studentId) async {
    if (_studentsCache.containsKey(studentId)) {
      return _studentsCache[studentId]!;
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore.instance
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
          SnackBar(content: Text('Erreur de chargement étudiant: ${e.toString()}')),
        );
      }
      return {};
    }
  }

  Widget _buildCandidatCard(DocumentSnapshot<Map<String, dynamic>> postulation) {
    if (!postulation.exists) return const SizedBox();

    final data = postulation.data() ?? {};
    final datePostulation = (data['createdAt'] as Timestamp).toDate();
    final formattedDate = DateFormat('dd MMM yyyy • HH:mm').format(datePostulation);

    return FutureBuilder<Map<String, dynamic>>(
      future: _getStudentData(data['idEtudiant'] as String),
      builder: (context, studentSnapshot) {
        final studentData = studentSnapshot.data ?? {};
        final nomComplet = studentData.isNotEmpty
            ? '${studentData['prenom'] ?? ''} ${studentData['nom'] ?? ''}'.trim()
            : data['nomComplet']?.toString() ?? 'Candidat inconnu';
        
        final initials = nomComplet
            .split(' ')
            .where((String part) => part.isNotEmpty)
            .take(2)
            .map((String part) => part[0])
            .join()
            .toUpperCase();

        return Container(
          margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _getAvatarColor(nomComplet),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            title: Text(
              nomComplet,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: _buildStatutWidget(data['statut']?.toString()),
            onTap: () => _showCandidatDetails(context, studentData, data, postulation.id),
          ),
        );
      },
    );
  }

  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFF226D68),
      const Color(0xFF3A7D44),
      const Color(0xFF5C8D89),
      const Color(0xFF2D767F),
    ];
    return colors[name.hashCode % colors.length];
  }

  Widget _buildStatutWidget(String? statut) {
    final Map<String, Map<String, dynamic>> statusOptions = {
      'accepté': {'color': Colors.green, 'icon': Icons.check_circle},
      'refusé': {'color': Colors.red, 'icon': Icons.cancel},
      'en_attente': {'color': Colors.orange, 'icon': Icons.access_time},
    };

    final statusInfo = statusOptions[statut?.toLowerCase()] ?? 
        {'color': Colors.grey, 'icon': Icons.help_outline};

    final Color color = statusInfo['color']! as Color;
    final IconData icon = statusInfo['icon']! as IconData;

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
            statut?.toUpperCase() ?? 'EN ATTENTE',
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

  void _showCandidatDetails(
    BuildContext context,
    Map<String, dynamic> studentData,
    Map<String, dynamic> postulationData,
    String postulationId,
  ) {
    final nomComplet = '${studentData['prenom'] ?? ''} ${studentData['nom'] ?? ''}'.trim();
    final initials = nomComplet.isNotEmpty 
        ? nomComplet.split(' ').where((String e) => e.isNotEmpty).take(2).map((String e) => e[0]).join().toUpperCase()
        : '?';

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
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
                        color: _getAvatarColor(nomComplet),
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
                    color: _getStatusColor(postulationData['statut']?.toString()).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getStatusIcon(postulationData['statut']?.toString()),
                        color: _getStatusColor(postulationData['statut']?.toString()),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Statut: ${_getStatusText(postulationData['statut']?.toString())}',
                        style: TextStyle(
                          color: _getStatusColor(postulationData['statut']?.toString()),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey,
                      ),
                      child: const Text('FERMER'),
                    ),
                    if (postulationData['statut']?.toString() != 'accepté')
                      const SizedBox(width: 8),
                    if (postulationData['statut']?.toString() != 'accepté')
                      ElevatedButton(
                        onPressed: () => _updateStatut(context, postulationId, 'accepté'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('ACCEPTER'),
                      ),
                    if (postulationData['statut']?.toString() != 'refusé')
                      const SizedBox(width: 8),
                    if (postulationData['statut']?.toString() != 'refusé')
                      ElevatedButton(
                        onPressed: () => _updateStatut(context, postulationId, 'refusé'),
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
        );
      },
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF226D68)),
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
                const SizedBox(height: 2),
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

  IconData _getStatusIcon(String? statut) {
    switch (statut?.toLowerCase()) {
      case 'accepté':
        return Icons.check_circle;
      case 'refusé':
        return Icons.cancel;
      default:
        return Icons.access_time;
    }
  }

  String _getStatusText(String? statut) {
    switch (statut?.toLowerCase()) {
      case 'accepté':
        return 'Accepté';
      case 'refusé':
        return 'Refusé';
      default:
        return 'En attente';
    }
  }

  Future<void> _updateStatut(BuildContext context, String postulationId, String newStatut) async {
    try {
      await FirebaseFirestore.instance
          .collection('postulations')
          .doc(postulationId)
          .update({
            'statut': newStatut,
            'traiteLe': Timestamp.now(),
          });

      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Statut mis à jour: $newStatut')),
      );
      
      _loadInitialData();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}')),
      );
    }
  }

  Color _getStatusColor(String? statut) {
    switch (statut?.toLowerCase()) {
      case 'accepté':
        return Colors.green;
      case 'refusé':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Candidats - ${widget.titreAction}",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: const Color(0xFF226D68),
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF226D68)),
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadInitialData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF226D68),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                )
              : _loadedPostulations.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.people_outline, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text(
                            "Aucun candidat pour cette action",
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _loadInitialData,
                            child: const Text(
                              'Actualiser',
                              style: TextStyle(color: Color(0xFF226D68)),
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadInitialData,
                      color: const Color(0xFF226D68),
                      child: ListView.builder(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(top: 16, bottom: 24),
                        itemCount: _loadedPostulations.length + (_isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= _loadedPostulations.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF226D68)),
                                ),
                              ),
                            );
                          }
                          return _buildCandidatCard(_loadedPostulations[index]);
                        },
                      ),
                    ),
    );
  }
}