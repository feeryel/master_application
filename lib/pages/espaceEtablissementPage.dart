import 'package:flutter/material.dart';
import 'package:master_application/pages/gestionActionsPage.dart';
import 'package:master_application/pages/gestionPostulationsPage.dart';


class EspaceEtablissementPage extends StatelessWidget {
  const EspaceEtablissementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Espace Établissement"),
        backgroundColor: const Color(0xFF226D68),
        
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.event_note),
              label: const Text("Gestion des actions"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF226D68),
                foregroundColor: Colors.white,

                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GestionActionsPage()),
                );
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.people_alt),
              label: const Text("Gestion des postulations"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF226D68),
                              foregroundColor: Colors.white,

                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GestionPostulationsPage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
