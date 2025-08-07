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
  bool _isLoading = false;
  bool _obscurePassword = true;

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

    setState(() => _isLoading = true);

    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final uid = credential.user!.uid;
      final batch = FirebaseFirestore.instance.batch();
      
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
      batch.set(userRef, {
        'uid': uid,
        'email': emailController.text.trim(),
        'role': selectedRole,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final roleRef = FirebaseFirestore.instance
          .collection('${selectedRole}s')
          .doc(uid);
      batch.set(roleRef, {
        ...getDataByRole(),
        'uid': uid,
      });

      await batch.commit();
      await FcmTokenHelper.saveToken();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ Inscription réussie !"),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Une erreur est survenue';
      if (e.code == 'email-already-in-use') {
        errorMessage = 'Un compte existe déjà avec cet email';
      } else if (e.code == 'weak-password') {
        errorMessage = 'Le mot de passe est trop faible';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Email invalide';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Erreur : $errorMessage"),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Erreur : ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> getDataByRole() {
    switch (selectedRole) {
      case 'etudiant':
        return {
          'nom': nomController.text.trim(),
          'prenom': prenomController.text.trim(),
          'numTel': telController.text.trim(),
        };
      case 'etablissement':
        return {
          'nom': nomController.text.trim(),
          'categorie': categorieController.text.trim(),
          'region': regionController.text.trim(),
          'numTel': telController.text.trim(),
        };
      case 'entreprise':
        return {
          'nom': nomController.text.trim(),
          'numTel': telController.text.trim(),
          'rne': rneController.text.trim(),
          'codeFiscale': codeFiscaleController.text.trim(),
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
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                        'EcoMinds',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Center(
                              child: Text(
                                "Créer un compte",
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF226D68),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              "Choisir votre rôle :",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildRoleChip("Étudiant", 'etudiant'),
                                  const SizedBox(width: 8),
                                  _buildRoleChip("Établissement", 'etablissement'),
                                  const SizedBox(width: 8),
                                  _buildRoleChip("Entreprise", 'entreprise'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              nomController,
                              "Nom",
                              validator: true,
                              icon: Icons.person_outline,
                            ),
                            if (selectedRole == 'etudiant')
                              _buildTextField(
                                prenomController,
                                "Prénom",
                                validator: true,
                                icon: Icons.person_outlined,
                              ),
                            _buildTextField(
                              telController,
                              "Numéro de téléphone",
                              type: TextInputType.phone,
                              validator: true,
                              icon: Icons.phone_android_outlined,
                            ),
                            if (selectedRole == 'etablissement') ...[
                              _buildTextField(
                                categorieController,
                                "Catégorie",
                                icon: Icons.category_outlined,
                              ),
                              _buildTextField(
                                regionController,
                                "Région",
                                icon: Icons.location_on_outlined,
                              ),
                            ],
                            if (selectedRole == 'entreprise') ...[
                              _buildTextField(
                                rneController,
                                "RNE",
                                icon: Icons.business_outlined,
                              ),
                              _buildTextField(
                                codeFiscaleController,
                                "Code fiscale",
                                icon: Icons.credit_card_outlined,
                              ),
                            ],
                            _buildTextField(
                              emailController,
                              "Email",
                              type: TextInputType.emailAddress,
                              validator: true,
                              icon: Icons.email_outlined,
                            ),
                            _buildTextField(
                              passwordController,
                              "Mot de passe",
                              obscure: _obscurePassword,
                              validator: true,
                              icon: Icons.lock_outlined,
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
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : registerUser,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF226D68),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 3,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        "S'inscrire",
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                const Text(
                                  "Vous avez déjà un compte ?",
                                  style: TextStyle(color: Colors.grey),
                                ),
                                TextButton(
                                  onPressed: _isLoading
                                      ? null
                                      : () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) => const LoginPage()),
                                          );
                                        },
                                  child: const Text(
                                    "Connectez-vous",
                                    style: TextStyle(
                                      color: Color(0xFF226D68),
                                      fontWeight: FontWeight.w600,
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
      ),
    );
  }

  Widget _buildRoleChip(String label, String value) {
    return ChoiceChip(
      label: Text(label),
      selected: selectedRole == value,
      onSelected: (selected) => setState(() => selectedRole = value),
      selectedColor: const Color(0xFF226D68).withOpacity(0.2),
      labelStyle: TextStyle(
        color: selectedRole == value ? const Color(0xFF226D68) : Colors.black,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selectedRole == value 
              ? const Color(0xFF226D68) 
              : Colors.grey.shade300,
          width: 1.5,
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    TextInputType type = TextInputType.text,
    bool obscure = false,
    bool validator = false,
    IconData? icon,
    Widget? suffixIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: type,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null 
              ? Icon(icon, color: const Color(0xFF226D68), size: 22) 
              : null,
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF226D68), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 16,
          ),
        ),
        validator: validator
            ? (value) {
                if (value == null || value.isEmpty) {
                  return 'Ce champ est requis';
                }
                if (label.contains('Email') && !value.contains('@')) {
                  return 'Email invalide';
                }
                if (label.contains('Mot de passe') && value.length < 6) {
                  return '6 caractères minimum';
                }
                if (label.contains('téléphone') && 
                    !RegExp(r'^[0-9]+$').hasMatch(value)) {
                  return 'Numéro invalide';
                }
                return null;
              }
            : null,
      ),
    );
  }
}