import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:master_application/pages/notification_service.dart';

class GestionPostulationsPage extends StatefulWidget {
  const GestionPostulationsPage({super.key});

  @override
  State<GestionPostulationsPage> createState() => _GestionPostulationsPageState();
}

class _GestionPostulationsPageState extends State<GestionPostulationsPage> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final Color primaryColor = const Color(0xFF226D68);
  final Color secondaryColor = const Color(0xFF439A97);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Liste des Actions"),
        backgroundColor: const Color(0xFF226D68),
      ),
      body: _currentUser == null 
          ? Center(child: Text("Veuillez vous connecter"))
          : _ActionsList(currentUserId: _currentUser!.uid),
    );
  }
}

class _ActionsList extends StatelessWidget {
  final String currentUserId;
  final Color primaryColor = const Color(0xFF226D68);
  final Color secondaryColor = const Color(0xFF439A97);

  const _ActionsList({required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('actions_volontariat')
          .where('idEtablissement', isEqualTo: currentUserId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: primaryColor));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_note, size: 48, color: Colors.grey),
                SizedBox(height: 16),
                Text("Aucune action créée"),
                SizedBox(height: 8),
                Text(
                  "Les actions que vous créez apparaîtront ici",
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final action = snapshot.data!.docs[index];
            final data = action.data() as Map<String, dynamic>;
            
            return Card(
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: secondaryColor.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.event, color: primaryColor),
                ),
                title: Text(data['titre'] ?? 'Action sans titre'),
                subtitle: Text("${data['dateDebut']} - ${data['dateFin']}"),
                trailing: Icon(Icons.arrow_forward),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ParticipationConfirmationPage(
                        actionId: action.id,
                        actionTitle: data['titre'] ?? 'Action',
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class ParticipationConfirmationPage extends StatefulWidget {
  final String actionId;
  final String actionTitle;

  const ParticipationConfirmationPage({
    required this.actionId,
    required this.actionTitle,
    super.key,
  });

  @override
  State<ParticipationConfirmationPage> createState() => _ParticipationConfirmationPageState();
}

class _ParticipationConfirmationPageState extends State<ParticipationConfirmationPage> {
  final Color successColor = Colors.green;
  final Color warningColor = Colors.red;
  final Color primaryColor = const Color(0xFF226D68);
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Participants - ${widget.actionTitle}"),
        backgroundColor: primaryColor,
      ),
      body: _currentUser == null
          ? Center(child: Text("Veuillez vous connecter"))
          : _ParticipantsList(
              actionId: widget.actionId,
              currentUserId: _currentUser!.uid,
            ),
    );
  }
}

class _ParticipantsList extends StatelessWidget {
  final String actionId;
  final String currentUserId;
  final Color primaryColor = const Color(0xFF226D68);
  final Color secondaryColor = const Color(0xFF439A97);

  const _ParticipantsList({
    required this.actionId,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('postulations')
          .where('idAction', isEqualTo: actionId)
          .where('idEtablissement', isEqualTo: currentUserId)
          .where('statut', isEqualTo: 'accepté')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: primaryColor));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 48, color: Colors.grey),
                SizedBox(height: 16),
                Text("Aucun participant accepté pour cette action"),
                SizedBox(height: 8),
                Text(
                  "Les candidats acceptés apparaîtront ici",
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final postulation = snapshot.data!.docs[index];
            final data = postulation.data() as Map<String, dynamic>;
            return _ParticipantItem(
              postulationId: postulation.id,
              actionId: actionId,
              data: data,
            );
          },
        );
      },
    );
  }
}

class _ParticipantItem extends StatelessWidget {
  final String postulationId;
  final String actionId;
  final Map<String, dynamic> data;
  final Color successColor = Colors.green;
  final Color warningColor = Colors.red;
  final Color primaryColor = const Color(0xFF226D68);

  const _ParticipantItem({
    required this.postulationId,
    required this.actionId,
    required this.data,
  });

  Future<void> _confirmerParticipation(BuildContext context) async {
    try {
      final postulationDoc = await FirebaseFirestore.instance
          .collection('postulations')
          .doc(postulationId)
          .get();

      if (postulationDoc.data()?['statut'] != 'accepté') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('La candidature doit être acceptée avant confirmation')),
        );
        return;
      }

      if (postulationDoc.data()?['participationConfirmee'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Participation déjà confirmée')),
        );
        return;
      }

      final actionDoc = await FirebaseFirestore.instance
          .collection('actions_volontariat')
          .doc(actionId)
          .get();
      final points = actionDoc.data()?['points'] ?? 20;

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        transaction.update(
          FirebaseFirestore.instance.collection('postulations').doc(postulationId),
          {
            'participationConfirmee': true,
            'dateConfirmation': Timestamp.now(),
            'pointsAttributed': true,
          },
        );

        transaction.update(
          FirebaseFirestore.instance.collection('etudiants').doc(data['idEtudiant']),
          {'points': FieldValue.increment(points)},
        );
      });

      await NotificationService.sendNotificationToStudent(
        studentId: data['idEtudiant'],
        title: 'Participation confirmée',
        body: 'Vous avez reçu $points points pour votre participation !',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$points points attribués avec succès')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}')),
      );
    }
  }

  Future<void> _marquerAbsence(BuildContext context) async {
    try {
      await FirebaseFirestore.instance
          .collection('postulations')
          .doc(postulationId)
          .update({
        'participationConfirmee': false,
        'dateConfirmation': Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Absence enregistrée'),
          backgroundColor: warningColor,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: warningColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final nomComplet = data['nomComplet'] ?? 'Participant inconnu';
    final participationConfirmee = data['participationConfirmee'] ?? false;
    final dateConfirmation = (data['dateConfirmation'] as Timestamp?)?.toDate();

    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: primaryColor.withOpacity(0.1),
                  child: Icon(Icons.person, color: primaryColor),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nomComplet,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        data['email'] ?? 'Email non disponible',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (participationConfirmee)
                  Icon(Icons.verified, color: successColor, size: 24)
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.check_circle, color: successColor),
                        onPressed: () => _confirmerParticipation(context),
                        tooltip: 'Confirmer participation',
                      ),
                      IconButton(
                        icon: Icon(Icons.cancel, color: warningColor),
                        onPressed: () => _marquerAbsence(context),
                        tooltip: 'Marquer comme absent',
                      ),
                    ],
                  ),
              ],
            ),
            if (participationConfirmee && dateConfirmation != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Confirmé le ${DateFormat('dd/MM/yyyy à HH:mm').format(dateConfirmation)}',
                  style: TextStyle(
                    color: successColor,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}