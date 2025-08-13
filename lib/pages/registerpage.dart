import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/helpers/fcm_token.dart';
import 'LoginPage.dart';

const List<String> tunisianGovernorates = [
  'Ariana', 'Béja', 'Ben Arous', 'Bizerte', 'Gabès', 'Gafsa', 'Jendouba',
  'Kairouan', 'Kasserine', 'Kébili', 'Le Kef', 'Mahdia', 'La Manouba',
  'Médenine', 'Monastir', 'Nabeul', 'Sfax', 'Sidi Bouzid', 'Siliana',
  'Sousse', 'Tataouine', 'Tozeur', 'Tunis', 'Zaghouan'
];

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
  void initState() {
    super.initState();
    telController.text = '+216';
  }

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
        'statut': 'en attente',
        'createdAt': FieldValue.serverTimestamp(),
        'points': selectedRole == 'etudiant' ? 0 : null,
      });

      final roleRef = FirebaseFirestore.instance
          .collection('${selectedRole}s')
          .doc(uid);
      batch.set(roleRef, {
        ...getDataByRole(),
        'uid': uid,
        'statut': 'en attente',
      });

      await batch.commit();
      await FcmTokenHelper.saveToken();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ Inscription réussie ! En attente de validation"),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Erreur d\'inscription';
      if (e.code == 'email-already-in-use') {
        errorMessage = 'Email déjà utilisé';
      } else if (e.code == 'weak-password') {
        errorMessage = 'Mot de passe trop faible';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ $errorMessage"),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Erreur: ${e.toString()}"),
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
          'points': 0,
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

  Widget _buildPhoneField() {
    return TextFormField(
      controller: telController,
      keyboardType: TextInputType.phone,
      decoration: InputDecoration(
        labelText: "Numéro de téléphone",
        prefixIcon: const Icon(Icons.phone, color: Color(0xFF226D68)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
        LengthLimitingTextInputFormatter(12),
        _TunisianPhoneInputFormatter(),
      ],
      onChanged: (value) {
        if (!value.startsWith('+216')) {
          final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
          telController.value = TextEditingValue(
            text: '+216${digits.length > 8 ? digits.substring(0, 8) : digits}',
            selection: TextSelection.collapsed(offset: 4 + digits.length),
          );
        }
      },
      onTap: () {
        if (telController.selection.start < 4) {
          telController.selection = TextSelection.collapsed(offset: 4);
        }
      },
      validator: (value) {
        if (value == null || value.length < 12) {
          return '8 chiffres requis après +216';
        }
        final digits = value.substring(4);
        if (selectedRole == 'etudiant' && !['2','5','9'].contains(digits[0])) {
          return 'Doit commencer par 2, 5 ou 9';
        } else if (selectedRole != 'etudiant' && !['2','5','7','9'].contains(digits[0])) {
          return 'Doit commencer par 2, 5, 7 ou 9';
        }
        return null;
      },
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
              ? Icon(icon, color: const Color(0xFF226D68)) 
              : null,
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        ),
        validator: validator ? (value) {
          if (value == null || value.isEmpty) return 'Ce champ est requis';
          if (label.contains('Email') && !value.contains('@')) return 'Email invalide';
          if (label.contains('Mot de passe') && value.length < 6) return '6 caractères minimum';
          return null;
        } : null,
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
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF226D68), Color(0xFF2A8C82)],
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Image.asset('assets/images/ecominds_logo22.png', height: 80),
                    const SizedBox(height: 12),
                    const Text('EcoMinds', 
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
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
                        children: [
                          const Text("Créer un compte", 
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF226D68))),
                          const SizedBox(height: 16),
                          const Text("Choisir votre rôle :", 
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
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
                          _buildTextField(nomController, "Nom", validator: true, icon: Icons.person),
                          if (selectedRole == 'etudiant')
                            _buildTextField(prenomController, "Prénom", validator: true, icon: Icons.person_outline),
                          const SizedBox(height: 8),
                          _buildPhoneField(),
                          if (selectedRole == 'etablissement') ...[
                          
                                                    const SizedBox(height: 16),
  _buildTextField(categorieController, "Catégorie", validator: true, icon: Icons.category),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: regionController.text.isEmpty ? null : regionController.text,
                              decoration: InputDecoration(
                                labelText: "Région",
                                prefixIcon: const Icon(Icons.location_on, color: Color(0xFF226D68)),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                              ),
                              items: tunisianGovernorates.map((String governorate) {
                                return DropdownMenuItem<String>(
                                  value: governorate,
                                  child: Text(governorate),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  regionController.text = newValue ?? '';
                                });
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Veuillez sélectionner une région';
                                return null;
                              },
                            ),
                          ],
                          if (selectedRole == 'entreprise') ...[
                                                     const SizedBox(height: 16),

                            _buildTextField(rneController, "RNE", validator: true, icon: Icons.business),
                            _buildTextField(codeFiscaleController, "Code fiscale", validator: true, icon: Icons.credit_card),
                          ],
                                                    const SizedBox(height: 16),

                          _buildTextField(emailController, "Email", 
                            type: TextInputType.emailAddress, validator: true, icon: Icons.email),
                          _buildTextField(passwordController, "Mot de passe",
                            obscure: _obscurePassword, validator: true,
                            icon: Icons.lock,
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
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
                                  borderRadius: BorderRadius.circular(12)),
                              ),
                              child: _isLoading
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Text("S'inscrire", style: TextStyle(color: Colors.white)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage())),
                            child: const Text("Vous avez déjà un compte ? Connectez-vous",
                              style: TextStyle(color: Color(0xFF226D68))),
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
}

class _TunisianPhoneInputFormatter extends TextInputFormatter {
  
  @override
  
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
   
    String newText = '+216';
    if (newValue.text.length > 4) {
      final digits = newValue.text.substring(4).replaceAll(RegExp(r'[^0-9]'), '');
      newText += digits.length > 8 ? digits.substring(0, 8) : digits;
    }
    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}