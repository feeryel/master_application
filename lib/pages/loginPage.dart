import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/helpers/fcm_token.dart';
import 'espaceEtudiantPage.dart';
import 'espaceEntreprisePage.dart';
import 'espaceEtablissementPage.dart';
import 'registerPage.dart';

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
  bool _obscurePassword = true;

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

    // Vérifier le statut de l'utilisateur
    final statut = userDoc['statut'];
    if (statut == 'en attente') {
      throw Exception("Votre compte n'est pas encore activé. Veuillez patienter.");
    } else if (statut == 'refusé') {
      throw Exception("Votre demande d'inscription a été refusée.");
    }

    final role = userDoc['role'];
    await FcmTokenHelper.saveToken();

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
      SnackBar(
      content: Text("Erreur: ${e.toString().replaceAll('Exception: ', '')}"),
        backgroundColor: Colors.redAccent,
      ),
    );
  } finally {
    setState(() => isLoading = false);
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
              // Header Section
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF226D68),
                      Color(0xFF2A8C82),
                    ],
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Image.asset(
                      'assets/images/ecominds_logo22.png',
                      height: 80,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Ecominds',
                      style: TextStyle(
                        fontSize: 30, 
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),          
                  ],
                ),
              ),
              
              // Login Form Section
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  shadowColor: const Color(0xFF226D68).withOpacity(0.3),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          const Text(
                            "Se connecter",
                            style: TextStyle(
                              fontSize: 25, 
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          // Email Field with Icon
                          _buildTextField(
                            emailController, 
                            "Email",
                            icon: Icons.email_outlined,
                            type: TextInputType.emailAddress, 
                            validator: true,
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Password Field with Icon and Toggle
                          _buildTextField(
                            passwordController, 
                            "Mot de passe",
                            icon: Icons.lock_outline,
                            obscure: _obscurePassword,
                            validator: true,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword 
                                  ? Icons.visibility_outlined 
                                  : Icons.visibility_off_outlined,
                                color: Colors.grey,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Login Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: isLoading ? null : loginUser,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF226D68),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 3,
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      "Connexion", 
                                      style: TextStyle(
                                        fontSize: 16, 
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Register Link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                "Vous n'avez pas de compte ? ",
                                style: TextStyle(color: Colors.grey),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const RegisterPage()),
                                  );
                                },
                                child: const Text(
                                  "S'inscrire",
                                  style: TextStyle(
                                    color: Color(0xFF226D68),
                                    fontWeight: FontWeight.bold,
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller, 
    String label, {
    IconData? icon,
    TextInputType type = TextInputType.text, 
    bool obscure = false, 
    bool validator = false,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: type,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, color: const Color(0xFF226D68)) : null,
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF226D68), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
      validator: validator
          ? (val) {
              if (val == null || val.isEmpty) return 'Champ requis';
              if (label == "Email" && !val.contains('@')) return 'Email invalide';
              if (label == "Mot de passe" && val.length < 6) return 'Minimum 6 caractères';
              return null;
            }
          : null,
    );
  }
}