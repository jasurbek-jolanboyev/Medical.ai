import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'username_setup_screen.dart';
import 'home_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isRegister = false;
  bool _isLoading = false;

  // Foydalanuvchi ma'lumotlarini tekshirish va yo'naltirish
  Future<void> _checkUsernameAndNavigate() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;

    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      if (!userDoc.exists ||
          userDoc.data()?['username'] == null ||
          userDoc.data()?['username'] == "") {
        // Username sozlanmagan bo'lsa
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const UsernameSetupScreen()),
        );
      } else {
        // Username bor bo'lsa
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    }
  }

  // Email va Parol orqali kirish/ro'yxatdan o'tish
  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError("Iltimos, barcha maydonlarni to'ldiring");
      return;
    }

    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (_isRegister) {
        await auth.signUp(email, password, "");
      } else {
        await auth.signIn(email, password);
      }
      await _checkUsernameAndNavigate();
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Google orqali kirish
  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);

      // AuthProvider'dagi metodni chaqiramiz
      final result = await auth.signInWithGoogle();

      if (result != null) {
        await _checkUsernameAndNavigate();
      }
    } catch (e) {
      _showError("Google orqali kirishda xatolik yuz berdi");
      debugPrint("Google Auth Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white))
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Column(
                    children: [
                      const SizedBox(height: 50),
                      _buildLogo(),
                      const SizedBox(height: 40),
                      _buildTextField(_emailController, "Email manzilingiz",
                          Icons.email_outlined),
                      const SizedBox(height: 20),
                      _buildTextField(_passwordController, "Maxfiy parol",
                          Icons.lock_outline,
                          isObscure: true),
                      const SizedBox(height: 30),
                      _buildMainButton(),
                      const SizedBox(height: 20),
                      _buildGoogleButton(),
                      const SizedBox(height: 20),
                      _buildSwitchModeButton(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: const Icon(Icons.security, size: 60, color: Colors.white),
        ),
        const SizedBox(height: 20),
        const Text("SafeChat",
            style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w900)),
        Text("Xavfsiz va tezkor aloqa",
            style:
                TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16)),
      ],
    );
  }

  Widget _buildMainButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF2563EB),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 0,
        ),
        child: Text(
          _isRegister ? "DAVOM ETISH" : "KIRISH",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: OutlinedButton(
        onPressed: _handleGoogleSignIn,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.white38),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.network(
              'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_\"G\"_Logo.svg/1200px-Google_\"G\"_Logo.svg.png',
              height: 24,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2));
              },
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.g_mobiledata, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 12),
            const Text("Google bilan davom etish",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchModeButton() {
    return TextButton(
      onPressed: () => setState(() => _isRegister = !_isRegister),
      child: Text(
          _isRegister
              ? "Hisobingiz bormi? Kirish"
              : "Hisobingiz yo'qmi? Ro'yxatdan o'tish",
          style: const TextStyle(color: Colors.white70)),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String hint, IconData icon,
      {bool isObscure = false}) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.2))),
      child: TextField(
        controller: controller,
        obscureText: isObscure,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white54),
            prefixIcon: Icon(icon, color: Colors.white70),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 18, horizontal: 10)),
      ),
    );
  }
}
