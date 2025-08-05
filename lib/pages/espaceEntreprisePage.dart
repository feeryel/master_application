import 'package:flutter/material.dart';

class EspaceEntreprisePage extends StatelessWidget {
  const EspaceEntreprisePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        title: const Text("Espace Entreprise"),
        backgroundColor: const Color(0xFF226D68),
      ),
      body: const Center(
        child: Text("Bienvenue dans l'espace entreprise !",
            style: TextStyle(fontSize: 18)),
      ),
    );
  }
}
