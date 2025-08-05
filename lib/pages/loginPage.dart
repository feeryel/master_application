import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/helpers/fcm_token.dart';

import 'espaceEtudiantPage.dart';
import 'espaceEntreprisePage.dart';
import 'espaceEtablissementPage.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;

  Future<void> loginUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final uid = credential.user!.uid;

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (!userDoc.exists) {
        throw Exception("Utilisateur introuvable dans Firestore !");
      }

      final role = userDoc['role'];
await FcmTokenHelper.saveToken();     // <-- AJOUTE AVANT la navigation

      Widget nextPage;
      switch (role) {
        case 'etudiant':
          nextPage = const EspaceEtudiantPage();
          break;
        case 'etablissement':
          nextPage = const EspaceEtablissementPage();
          break;
        case 'entreprise':
          nextPage = const EspaceEntreprisePage();
          break;
        default:
          throw Exception("Rôle non reconnu : $role");
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => nextPage),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur : ${e.toString()}")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                color: const Color(0xFF226D68),
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Image.asset(
                      'assets/ecominds_logo22.png',
                      height: 80,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Ecominds',
                      style: TextStyle(fontSize: 30, color: Colors.white),
                      
                    ),          
                  ],
                ),
              ),
                  const SizedBox(height: 90), 
              Padding(
                padding: const EdgeInsets.all(16.0),
                
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          const Text(
                            "Se connecter ",
                            style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 20),
                          _buildTextField(emailController, "Email", type: TextInputType.emailAddress, validator: true),
                          _buildTextField(passwordController, "Mot de passe", obscure: true, validator: true),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: isLoading ? null : loginUser,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF226D68),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: isLoading
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Text("Connexion", style: TextStyle(fontSize: 16,color: Colors.white)),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {TextInputType type = TextInputType.text, bool obscure = false, bool validator = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: TextFormField(
        controller: controller,
        keyboardType: type,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        validator: validator
            ? (val) {
                if (val == null || val.isEmpty) return 'Champ requis';
                if (label == "Mot de passe" && val.length < 6) return 'Minimum 6 caractères';
                return null;
              }
            : null,
      ),
    );
  }
}
