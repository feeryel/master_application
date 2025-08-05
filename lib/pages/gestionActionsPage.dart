import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  Future<void> _selectDate(TextEditingController controller) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      String formatted = DateFormat('yyyy-MM-dd').format(picked);
      setState(() {
        controller.text = formatted;
      });
    }
  }

  void ajouterActionVolontariat() async {
    if (_titre.text.isEmpty || _dateDebut.text.isEmpty || _dateFin.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir tous les champs obligatoires.')),
      );
      return;
    }

    await FirebaseFirestore.instance.collection("actions_volontariat").add({
      'titre': _titre.text,
      'description': _description.text,
      'lieu': _lieu.text,
      'dateDebut': _dateDebut.text,
      'dateFin': _dateFin.text,
      'statut': 'À venir',
      'createdAt': Timestamp.now(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Action ajoutée avec succès !')),
    );

    _titre.clear();
    _description.clear();
    _lieu.clear();
    _dateDebut.clear();
    _dateFin.clear();
  }

  void modifierAction(DocumentSnapshot action) async {
    _titre.text = action['titre'];
    _description.text = action['description'];
    _lieu.text = action['lieu'];
    _dateDebut.text = action['dateDebut'];
    _dateFin.text = action['dateFin'];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Modifier l\'action'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(controller: _titre, decoration: const InputDecoration(labelText: "Titre")),
                TextField(controller: _description, decoration: const InputDecoration(labelText: "Description")),
                TextField(controller: _lieu, decoration: const InputDecoration(labelText: "Lieu")),
                TextFormField(
                  controller: _dateDebut,
                  readOnly: true,
                  decoration: const InputDecoration(labelText: "Date Début"),
                  onTap: () => _selectDate(_dateDebut),
                ),
                TextFormField(
                  controller: _dateFin,
                  readOnly: true,
                  decoration: const InputDecoration(labelText: "Date Fin"),
                  onTap: () => _selectDate(_dateFin),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () async {
                await FirebaseFirestore.instance.collection("actions_volontariat").doc(action.id).update({
                  'titre': _titre.text,
                  'description': _description.text,
                  'lieu': _lieu.text,
                  'dateDebut': _dateDebut.text,
                  'dateFin': _dateFin.text,
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Action modifiée avec succès !')),
                );
              },
              child: const Text('Modifier'),
            ),
          ],
        );
      },
    );
  }

  Future<void> supprimerAction(String id) async {
    await FirebaseFirestore.instance.collection("actions_volontariat").doc(id).delete();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Action supprimée avec succès.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestion des actions"),
        backgroundColor: const Color(0xFF226D68),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text("Nouvelle Action de Volontariat",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(controller: _titre, decoration: const InputDecoration(labelText: "Titre")),
          TextField(controller: _description, decoration: const InputDecoration(labelText: "Description")),
          TextField(controller: _lieu, decoration: const InputDecoration(labelText: "Lieu")),
          TextFormField(
            controller: _dateDebut,
            readOnly: true,
            decoration: const InputDecoration(labelText: "Date Début"),
            onTap: () => _selectDate(_dateDebut),
          ),
          TextFormField(
            controller: _dateFin,
            readOnly: true,
            decoration: const InputDecoration(labelText: "Date Fin"),
            onTap: () => _selectDate(_dateFin),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: ajouterActionVolontariat,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF226D68),foregroundColor: Colors.white,
),
            child: const Text("Ajouter l'action"),
          ),
          const Divider(height: 32, thickness: 2),
          const Text("Actions publiées",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection("actions_volontariat")
                .orderBy("createdAt", descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final actions = snapshot.data!.docs;

              if (actions.isEmpty) {
                return const Text("Aucune action publiée.");
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: actions.length,
                itemBuilder: (context, index) {
                  final action = actions[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      title: Text(action['titre']),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(action['description']),
                          Text("📍 ${action['lieu']}"),
                          Text("📅 Du ${action['dateDebut']} au ${action['dateFin']}")
                        ],
                      ),
                      trailing: Column(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Color(0xFF226D68)),
                            onPressed: () => modifierAction(action),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Color(0xFF226D68)),
                            onPressed: () => supprimerAction(action.id),
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ListeCandidatsPage(
                              idAction: action.id,
                              titreAction: action['titre'],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
