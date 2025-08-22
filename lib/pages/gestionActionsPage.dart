import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
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
  final TextEditingController _points = TextEditingController();

  final User? _currentUser = FirebaseAuth.instance.currentUser;
  bool _showForm = false;
  bool _isEditing = false;
  String? _editingActionId;

  final Color primaryColor = const Color(0xFF226D68);
  final Color secondaryColor = const Color(0xFF3A7D44);
  final Color accentColor = const Color(0xFF5C8D89);

Future<void> _selectDate(TextEditingController controller, {DateTime? firstDate}) async {
  DateTime initialDate = DateTime.now().add(const Duration(days: 1)); // Demain comme date initiale
  DateTime minimumDate = DateTime.now().add(const Duration(days: 1)); // Date minimale est demain
  
  // Si on sélectionne la date de fin et qu'une date de début est déjà définie,
  // utiliser la date de début comme date minimale
  if (firstDate != null && firstDate.isAfter(minimumDate)) {
    minimumDate = firstDate;
    initialDate = firstDate;
  }
  
  DateTime? picked = await showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: minimumDate, // Utiliser minimumDate comme date minimale
    lastDate: DateTime(2100),
  );
  
  if (picked != null) {
    setState(() {
      controller.text = DateFormat('yyyy-MM-dd').format(picked);
    });
  }
}
  bool _validateDates() {
    if (_dateDebut.text.isEmpty || _dateFin.text.isEmpty) return true;
    
    final dateFormat = DateFormat('yyyy-MM-dd');
    final debut = dateFormat.parse(_dateDebut.text);
    final fin = dateFormat.parse(_dateFin.text);
    
    return fin.isAfter(debut) || fin.isAtSameMomentAs(debut);
  }

  Future<void> _saveAction() async {
    try {
      // Validation des champs obligatoires
      if (_titre.text.isEmpty ||
          _dateDebut.text.isEmpty ||
          _dateFin.text.isEmpty ||
          _points.text.isEmpty) {
        _showErrorAlert('Veuillez remplir tous les champs obligatoires');
        return;
      }

      // Validation des dates
      if (!_validateDates()) {
        _showErrorAlert('La date de fin doit être après ou égale à la date\n de début');
        return;
      }

      // Validation des points
 final int? points = int.tryParse(_points.text);
      if (points == null) {
        _showErrorAlert('Le nombre de points doit être un nombre valide');
        return;
      }
      if (points < 10 || points > 60) {
        _showErrorAlert('Le nombre de points doit être entre 10 et 60');
        return;
      }

      if (_isEditing && _editingActionId != null) {
        // Mise à jour de l'action existante
        await FirebaseFirestore.instance
            .collection("actions_volontariat")
            .doc(_editingActionId)
            .update({
          'titre': _titre.text,
          'description': _description.text,
          'lieu': _lieu.text,
          'dateDebut': _dateDebut.text,
          'dateFin': _dateFin.text,
          'points': points,
        });
        _showSuccessAlert('Action modifiée avec succès');
      } else {
        // Création d'une nouvelle action
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
          'points': points,
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
      _points.clear();
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
_points.text = (data['points'] ?? 10).toString();
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
  onTap: () => _selectDate(_dateDebut, firstDate: DateTime.now().add(const Duration(days: 1))),
),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _dateFin,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: "Date Fin*",
                      border: OutlineInputBorder(),
                    ),
                    onTap: () {
                      final dateFormat = DateFormat('yyyy-MM-dd');
                      final firstDate = _dateDebut.text.isNotEmpty 
                          ? dateFormat.parse(_dateDebut.text) 
                          : null;
                      _selectDate(_dateFin, firstDate: firstDate);
                    },
                  ),
                  const SizedBox(height: 12),
             TextField(
                    controller: _points,
                    decoration: InputDecoration(
                      labelText: "Points à attribuer*",
                      hintText: "Entre 10 et 60",
                      border: const OutlineInputBorder(),
                      errorText: _points.text.isNotEmpty && (int.tryParse(_points.text) ?? 0) < 10 || (int.tryParse(_points.text) ?? 0) > 60
                          ? 'Veuillez entrer un nombre entre 10 et 60'
                          : null,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly, // Allow only digits
                    ],
                    onChanged: (value) {
                      setState(() {}); // Update UI to show error text if needed
                    },
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
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
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
            
            // AFFICHAGE DES SPONSORS
            FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance
                  .collection('actions_volontariat')
                  .doc(action.id)
                  .collection('contributions')
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Container();
                }
                
                final sponsorsCount = snapshot.data?.docs.length ?? 0;
                
                if (sponsorsCount > 0) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.volunteer_activism_rounded, 
                            size: 14, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(
                          '$sponsorsCount sponsor${sponsorsCount > 1 ? 's' : ''}',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return Container();
              },
            ),
            
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