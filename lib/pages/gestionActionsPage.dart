import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'liste_candidats_page.dart';

class GestionActionsPage extends StatefulWidget {
  const GestionActionsPage({super.key});

  @override
  State<GestionActionsPage> createState() => _GestionActionsPageState();
}

class _GestionActionsPageState extends State<GestionActionsPage> {
  final TextEditingController _titre = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _lieu = TextEditingController();
  final TextEditingController _dateDebut = TextEditingController();
  final TextEditingController _dateFin = TextEditingController();
  final TextEditingController _points = TextEditingController(); // 🔹 Champ pour les points

  final User? _currentUser = FirebaseAuth.instance.currentUser;
  bool _showForm = false;
  bool _isEditing = false;
  String? _editingActionId;

  // Couleurs thématiques
  final Color primaryColor = const Color(0xFF226D68);
  final Color secondaryColor = const Color(0xFF3A7D44);
  final Color accentColor = const Color(0xFF5C8D89);

  Future<void> _selectDate(TextEditingController controller) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        controller.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _saveAction() async {
    try {
      if (_titre.text.isEmpty ||
          _dateDebut.text.isEmpty ||
          _dateFin.text.isEmpty ||
          _points.text.isEmpty) {
        _showErrorAlert('Veuillez remplir les champs obligatoires (Titre, Dates, Points)');
        return;
      }

      final int points = int.tryParse(_points.text) ?? 10;
      if (points <= 0) {
        _showErrorAlert('Le nombre de points doit être positif');
        return;
      }

      if (_isEditing && _editingActionId != null) {
        await FirebaseFirestore.instance
            .collection("actions_volontariat")
            .doc(_editingActionId)
            .update({
          'titre': _titre.text,
          'description': _description.text,
          'lieu': _lieu.text,
          'dateDebut': _dateDebut.text,
          'dateFin': _dateFin.text,
          'points': points, // 🔹 Mise à jour des points
        });
        _showSuccessAlert('Action modifiée avec succès');
      } else {
        await FirebaseFirestore.instance.collection("actions_volontariat").add({
          'titre': _titre.text,
          'description': _description.text,
          'lieu': _lieu.text,
          'dateDebut': _dateDebut.text,
          'dateFin': _dateFin.text,
          'statut': 'À venir',
          'createdAt': Timestamp.now(),
          'idEtablissement': _currentUser?.uid,
          'emailEtablissement': _currentUser?.email,
          'points': points, // 🔹 Ajout des points
        });
        _showSuccessAlert('Action créée avec succès');
      }
      _resetForm();
    } catch (e) {
      _showErrorAlert("Erreur: ${e.toString()}");
    }
  }

  void _showSuccessAlert(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(message, style: const TextStyle(color: Colors.white)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  void _showErrorAlert(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Text(message, style: const TextStyle(color: Colors.white)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  void _resetForm() {
    setState(() {
      _titre.clear();
      _description.clear();
      _lieu.clear();
      _dateDebut.clear();
      _dateFin.clear();
      _points.clear(); // 🔹 Réinitialisation du champ points
      _showForm = false;
      _isEditing = false;
      _editingActionId = null;
    });
  }

  void _startEditing(DocumentSnapshot action) {
    final data = action.data() as Map<String, dynamic>;
    setState(() {
      _titre.text = data['titre']?.toString() ?? '';
      _description.text = data['description']?.toString() ?? '';
      _lieu.text = data['lieu']?.toString() ?? '';
      _dateDebut.text = data['dateDebut']?.toString() ?? '';
      _dateFin.text = data['dateFin']?.toString() ?? '';
      _points.text = (data['points'] ?? 10).toString(); // 🔹 Pré-remplir les points
      _isEditing = true;
      _editingActionId = action.id;
      _showForm = true;
    });
  }

  Future<void> _confirmDelete(String id) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Confirmer la suppression',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Voulez-vous vraiment supprimer cette action ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler',
                style: TextStyle(color: Color(0xFF226D68))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer',
                style: TextStyle(color: Colors.white)),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
      ),
    ) ?? false;
    if (confirm) {
      try {
        await FirebaseFirestore.instance
            .collection("actions_volontariat")
            .doc(id)
            .delete();
        if (!mounted) return;
        _showSuccessAlert('Action supprimée');
      } catch (e) {
        if (!mounted) return;
        _showErrorAlert("Erreur: ${e.toString()}");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Actions'),
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          _buildActionsList(),
          if (_showForm) _buildModalForm(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(
          Icons.add_circle_outlined,
          size: 24,
          color: Colors.white,
        ),
        label: const Text(
          "Nouveau",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 4,
        highlightElevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        onPressed: () {
          setState(() {
            _resetForm();
            _showForm = true;
          });
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildModalForm() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.5),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isEditing ? 'Modifier Action' : 'Nouvelle Action',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: _resetForm,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _titre,
                    decoration: const InputDecoration(
                      labelText: "Titre*",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _description,
                    decoration: const InputDecoration(
                      labelText: "Description",
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _lieu,
                    decoration: const InputDecoration(
                      labelText: "Lieu",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _dateDebut,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: "Date Début*",
                      border: OutlineInputBorder(),
                    ),
                    onTap: () => _selectDate(_dateDebut),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _dateFin,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: "Date Fin*",
                      border: OutlineInputBorder(),
                    ),
                    onTap: () => _selectDate(_dateFin),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _points,
                    decoration: const InputDecoration(
                      labelText: "Points à attribuer*",
                      hintText: "Ex: 15",
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _resetForm,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(color: primaryColor),
                          ),
                          child: Text(
                            'Annuler',
                            style: TextStyle(color: primaryColor),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _saveAction,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(
                            _isEditing ? 'Modifier' : 'Créer',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _currentUser != null
          ? FirebaseFirestore.instance
              .collection("actions_volontariat")
              .where("idEtablissement", isEqualTo: _currentUser!.uid)
              .orderBy("createdAt", descending: true)
              .snapshots()
          : null,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_note, size: 80, color: Colors.grey.shade400),
                const SizedBox(height: 20),
                Text(
                  "Aucune action créée",
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _resetForm();
                      _showForm = true;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text('Créer une action'),
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final action = snapshot.data!.docs[index];
            final data = action.data() as Map<String, dynamic>;
            return _buildActionItem(action, data);
          },
        );
      },
    );
  }

  Widget _buildActionItem(DocumentSnapshot action, Map<String, dynamic> data) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ListeCandidatsPage(
                idAction: action.id,
                titreAction: data['titre']?.toString() ?? 'Action',
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: secondaryColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.event, color: primaryColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      data['titre']?.toString() ?? 'Sans titre',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Modifier'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Supprimer', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'edit') {
                        _startEditing(action);
                      } else if (value == 'delete') {
                        _confirmDelete(action.id);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (data['description'] != null &&
                  data['description'].toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    data['description'].toString(),
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    data['lieu']?.toString() ?? 'Non spécifié',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    "${data['dateDebut']?.toString() ?? '?'} - ${data['dateFin']?.toString() ?? '?'}",
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // 🔹 Affichage des points
              Row(
                children: [
                  Icon(Icons.star, size: 16, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(
                    "${data['points'] ?? 10} points",
                    style: TextStyle(color: Colors.amber),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}