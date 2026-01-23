import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart' as my_auth;
import 'package:cached_network_image/cached_network_image.dart';
import 'admin/admin_dashboard.dart'; // Fayl manzili to'g'riligiga ishonch hosil qiling

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isUploading = false;

  // 1. Profil rasmini yangilash
  Future<void> _updateAvatar() async {
    final picker = ImagePicker();
    final image =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (image == null) return;

    setState(() => _isUploading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final ref = FirebaseStorage.instance.ref().child('avatars/$uid.jpg');

      await ref.putFile(File(image.path));
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'avatar': url});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profil rasmi muvaffaqiyatli yangilandi")),
      );
    } catch (e) {
      debugPrint("Avatar Update Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Xatolik yuz berdi: $e")),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // 2. Ma'lumotlarni tahrirlash dialogi
  void _showEditDialog(String field, String currentValue) {
    final controller = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("$field tahrirlash"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: "Yangi $field yozing",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Bekor qilish")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB)),
            onPressed: () async {
              final uid = FirebaseAuth.instance.currentUser!.uid;
              final newValue = controller.text.trim();
              if (newValue.isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .update({field.toLowerCase(): newValue});
              }
              if (mounted) Navigator.pop(context);
            },
            child: const Text("Saqlash", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text("Mening profilim",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Ma'lumot topilmadi"));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final avatar = data['avatar'] ?? '';
          final username = data['username'] ?? 'Foydalanuvchi';
          final bio = data['bio'] ?? 'SafeChat orqali muloqotda';
          final email = data['email'] ?? user?.email ?? '';
          final role = data['role'] ?? 'user';

          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 110), // Bottom bar uchun joy
            child: Column(
              children: [
                _buildHeader(avatar, username, email),
                const SizedBox(height: 20),

                _buildSectionTitle("ASOSIY MA'LUMOTLAR"),
                _buildCard([
                  _buildListTile(Icons.person_outline, "Username", "@$username",
                      () => _showEditDialog("Username", username)),
                  _buildListTile(Icons.info_outline, "Bio", bio,
                      () => _showEditDialog("Bio", bio)),
                  _buildListTile(Icons.email_outlined, "Email", email, null),
                ]),

                // ADMIN PANEL TUGMASI (FAQAT ADMINLAR UCHUN)
                if (role == 'admin') ...[
                  const SizedBox(height: 20),
                  _buildSectionTitle("BOSHQARUV (ADMIN)"),
                  _buildCard([
                    _buildListTile(
                      Icons.admin_panel_settings_outlined,
                      "Admin Dashboard",
                      "Foydalanuvchilar va postlarni boshqarish",
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const AdminDashboard()),
                        );
                      },
                    ),
                  ]),
                ],

                const SizedBox(height: 20),
                _buildSectionTitle("XAVFSIZLIK VA ILOVA"),
                _buildCard([
                  _buildListTile(
                      Icons.lock_outline, "Maxfiylik", "Sozlamalar", () {}),
                  _buildListTile(Icons.notifications_none, "Bildirishnomalar",
                      "Yoqilgan", () {}),
                ]),

                const SizedBox(height: 30),

                // CHIQISH TUGMASI
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.all(15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
                        side: const BorderSide(color: Colors.red),
                      ),
                      onPressed: () => _handleLogout(context),
                      icon: const Icon(Icons.logout),
                      label: const Text("HISOBDAN CHIQISH",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Tizimdan chiqish funksiyasi
  void _handleLogout(BuildContext context) async {
    final authProvider =
        Provider.of<my_auth.AuthProvider>(context, listen: false);
    await authProvider.signOut();
    if (mounted) {
      Navigator.of(context, rootNavigator: true)
          .pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  Widget _buildHeader(String avatar, String username, String email) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: Colors.blue.shade50,
                backgroundImage: avatar.isNotEmpty
                    ? CachedNetworkImageProvider(avatar)
                    : null,
                child: avatar.isEmpty
                    ? const Icon(Icons.person, size: 60, color: Colors.blue)
                    : null,
              ),
              if (_isUploading)
                const Positioned.fill(
                    child: Center(child: CircularProgressIndicator())),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _updateAvatar,
                  child: const CircleAvatar(
                    backgroundColor: Color(0xFF2563EB),
                    radius: 18,
                    child:
                        Icon(Icons.camera_alt, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(username,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(email, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
      child: Text(title,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey)),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)
          ]),
      child: Column(children: children),
    );
  }

  Widget _buildListTile(
      IconData icon, String title, String sub, VoidCallback? onTap) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF2563EB)),
      title: Text(title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle:
          Text(sub, style: const TextStyle(fontSize: 13, color: Colors.grey)),
      trailing:
          onTap != null ? const Icon(Icons.chevron_right, size: 18) : null,
      onTap: onTap,
    );
  }
}
