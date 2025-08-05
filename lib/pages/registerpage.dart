import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/helpers/fcm_token.dart';
import 'LoginPage.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nomController = TextEditingController();
  final prenomController = TextEditingController();
  final telController = TextEditingController();
  final categorieController = TextEditingController();
  final regionController = TextEditingController();
  final rneController = TextEditingController();
  final codeFiscaleController = TextEditingController();

  String selectedRole = 'etudiant';

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    nomController.dispose();
    prenomController.dispose();
    telController.dispose();
    categorieController.dispose();
    regionController.dispose();
    rneController.dispose();
    codeFiscaleController.dispose();
    super.dispose();
  }

  Future<void> registerUser() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final uid = credential.user!.uid;

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'email': emailController.text.trim(),
        'role': selectedRole,
      });

      final additionalData = getDataByRole();

      await FirebaseFirestore.instance
          .collection('${selectedRole}s')
          .doc(uid)
          .set({...additionalData, 'uid': uid});
await FcmTokenHelper.saveToken();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Inscription réussie !")),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Erreur : ${e.toString()}")),
      );
    }
  }

  Map<String, dynamic> getDataByRole() {
    switch (selectedRole) {
      case 'etudiant':
        return {
          'nom': nomController.text,
          'prenom': prenomController.text,
          'numTel': telController.text,
        };
      case 'etablissement':
        return {
          'nom': nomController.text,
          'categorie': categorieController.text,
          'region': regionController.text,
          'numTel': telController.text,
        };
      case 'entreprise':
        return {
          'nom': nomController.text,
          'numTel': telController.text,
          'rne': rneController.text,
          'codeFiscale': codeFiscaleController.text,
        };
      default:
        return {};
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      'assets/images/ecominds_logo22.png',
                      height: 80,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'EcoMinds',
                      style: TextStyle(fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Center(
                            child: Text(
                              "Créer un compte",
                              style: TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text("Choisir votre rôle :",
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildInlineRadio("Étudiant", 'etudiant'),
                              _buildInlineRadio(
                                  "Établissement", 'etablissement'),
                              _buildInlineRadio("Entreprise", 'entreprise'),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(nomController, "Nom",
                              validator: true),
                          if (selectedRole == 'etudiant')
                            _buildTextField(
                                prenomController, "Prénom", validator: true),
                          _buildTextField(telController, "Numéro de téléphone",
                              type: TextInputType.phone),
                          if (selectedRole == 'etablissement') ...[
                            _buildTextField(categorieController, "Catégorie"),
                            _buildTextField(regionController, "Région"),
                          ],
                          if (selectedRole == 'entreprise') ...[
                            _buildTextField(rneController, "RNE"),
                            _buildTextField(
                                codeFiscaleController, "Code fiscale"),
                          ],
                          _buildTextField(emailController, "Email",
                              type: TextInputType.emailAddress,
                              validator: true),
                          _buildTextField(passwordController, "Mot de passe",
                              obscure: true, validator: true),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: registerUser,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF226D68),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                "S'inscrire",
                                style: TextStyle(
                                    fontSize: 16, color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("Vous avez déjà un compte ?"),
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const LoginPage()),
                                  );
                                },
                                child: const Text(
                                  "Connectez-vous",
                                  style: TextStyle(color: Color(0xFF226D68)),
                                ),
                              ),
                            ],
                          ),
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

  Widget _buildInlineRadio(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Radio<String>(
          value: value,
          groupValue: selectedRole,
          onChanged: (val) => setState(() => selectedRole = val!),
        ),
        Text(label),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {TextInputType type = TextInputType
          .text, bool obscure = false, bool validator = false}) {
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
          if (label == "Mot de passe" && val.length < 6) {
            return 'Minimum 6 caractères';
          }
          return null;
        }
            : null,
      ),
    );
  }
}