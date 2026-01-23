import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';

class UsernameSetupScreen extends StatefulWidget {
  const UsernameSetupScreen({super.key});

  @override
  State<UsernameSetupScreen> createState() => _UsernameSetupScreenState();
}

class _UsernameSetupScreenState extends State<UsernameSetupScreen> {
  final _usernameController = TextEditingController();
  bool _isLoading = false;

  Future<void> _saveUsername() async {
    final name = _usernameController.text
        .trim()
        .toLowerCase(); // Hammasini kichik harf qilish tavsiya etiladi

    if (name.isEmpty || name.length < 3) {
      _showError("Username kamida 3 ta belgi bo'lishi kerak");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // 1. Username band emasligini tekshirish (ixtiyoriy lekin muhim)
        final query = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: name)
            .get();

        if (query.docs.isNotEmpty) {
          _showError("Bu username band. Boshqa nom tanlang.");
          setState(() => _isLoading = false);
          return;
        }

        // 2. Ma'lumotlarni saqlash
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'username': name,
          'email': user.email,
          'avatar': user.photoURL ?? '',
          'bio': 'SafeChat orqali muloqotda',
          'role': 'user',
          'online': true,
          'lastActive': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'isBlocked': false,
        }, SetOptions(merge: true));

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      }
    } catch (e) {
      _showError("Xatolik yuz berdi: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // LoginScreen bilan bir xil gradient fon
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2563EB), Color(0xFF1E40AF), Color(0xFF000000)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.alternate_email_rounded,
                    size: 80, color: Colors.white),
                const SizedBox(height: 20),
                const Text(
                  "Username tanlang",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Bu nom orqali boshqalar sizni qidirib topishadi va muloqot qilishadi.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 15),
                ),
                const SizedBox(height: 40),
                _buildInput(),
                const SizedBox(height: 30),
                _buildButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.2))),
      child: TextField(
        controller: _usernameController,
        style: const TextStyle(color: Colors.white, fontSize: 18),
        decoration: const InputDecoration(
          hintText: "username",
          hintStyle: TextStyle(color: Colors.white38),
          border: InputBorder.none,
          prefixText: "@ ",
          prefixStyle: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveUsername,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF2563EB),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 0,
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Color(0xFF2563EB))
            : const Text("SAQLASH VA KIRISH",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }
}
