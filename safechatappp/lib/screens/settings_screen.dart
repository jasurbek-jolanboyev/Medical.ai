import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/auth_provider.dart' as my_auth;

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Yumshoq kulrang fon
      appBar: AppBar(
        title: const Text("Sozlamalar",
            style: TextStyle(fontWeight: FontWeight.bold)),
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
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          final data = snapshot.data?.data() as Map<String, dynamic>?;
          final role = data?['role'] ?? 'user';
          final username = data?['username'] ?? 'Foydalanuvchi';

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),

                // 1. ACCOUNT SECTION
                _buildSectionHeader("HISOB"),
                _buildSettingsGroup([
                  _buildSettingItem(
                    icon: Icons.person_outline_rounded,
                    title: "Profilni tahrirlash",
                    subtitle: "@$username",
                    color: Colors.blue,
                    onTap: () =>
                        Navigator.pop(context), // Profil sahifasiga qaytadi
                  ),
                  _buildSettingItem(
                    icon: Icons.notifications_none_rounded,
                    title: "Bildirishnomalar",
                    subtitle: "Ovoz va xabarlar",
                    color: Colors.orange,
                    onTap: () {},
                  ),
                  _buildSettingItem(
                    icon: Icons.lock_outline_rounded,
                    title: "Maxfiylik",
                    subtitle: "Bloklanganlar, xavfsizlik",
                    color: Colors.green,
                    onTap: () {},
                  ),
                ]),

                const SizedBox(height: 20),

                // 2. ADMIN SECTION (Faqat admin bo'lsa ko'rinadi)
                if (role == 'admin') ...[
                  _buildSectionHeader("ADMINISTRATOR"),
                  _buildSettingsGroup([
                    _buildSettingItem(
                      icon: Icons.admin_panel_settings_outlined,
                      title: "Admin Dashboard",
                      subtitle: "Ilovani to'liq boshqarish",
                      color: Colors.redAccent,
                      onTap: () {
                        // Admin panel yaratganimizda shu yerga yo'naltiramiz
                      },
                    ),
                    _buildSettingItem(
                      icon: Icons.campaign_outlined,
                      title: "Global Reklama",
                      subtitle: "Barchaga xabar yuborish",
                      color: Colors.purple,
                      onTap: () {},
                    ),
                  ]),
                  const SizedBox(height: 20),
                ],

                // 3. APP SETTINGS
                _buildSectionHeader("ILOVA"),
                _buildSettingsGroup([
                  _buildSettingItem(
                    icon: Icons.dark_mode_outlined,
                    title: "Tungi rejim",
                    subtitle: "O'chirilgan",
                    color: Colors.indigo,
                    onTap: () {},
                  ),
                  _buildSettingItem(
                    icon: Icons.translate_rounded,
                    title: "Ilova tili",
                    subtitle: "O'zbekcha",
                    color: Colors.cyan,
                    onTap: () {},
                  ),
                  _buildSettingItem(
                    icon: Icons.help_outline_rounded,
                    title: "Yordam va aloqa",
                    subtitle: "SafeChat qo'llab-quvvatlash",
                    color: Colors.teal,
                    onTap: () {},
                  ),
                ]),

                const SizedBox(height: 30),

                // 4. LOGOUT BUTTON
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                    tileColor: Colors.white,
                    leading:
                        const Icon(Icons.logout_rounded, color: Colors.red),
                    title: const Text("Tizimdan chiqish",
                        style: TextStyle(
                            color: Colors.red, fontWeight: FontWeight.bold)),
                    onTap: () => _showLogoutDialog(context),
                  ),
                ),

                const SizedBox(height: 10),
                const Text("SafeChat v1.0.0",
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  // Sarlavha vidjeti
  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
      child: Text(title,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey)),
    );
  }

  // Sozlamalar guruhini karta ichiga olish
  Widget _buildSettingsGroup(List<Widget> items) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)
        ],
      ),
      child: Column(children: items),
    );
  }

  // Har bir qator (Item) uchun vidjet
  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded,
          size: 14, color: Colors.grey),
      onTap: onTap,
    );
  }

  // Chiqish dialogi
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Chiqish"),
        content: const Text("Haqiqatan ham hisobdan chiqmoqchimisiz?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Yo'q")),
          TextButton(
            onPressed: () {
              Provider.of<my_auth.AuthProvider>(context, listen: false)
                  .signOut();
              Navigator.pop(context); // Dialog
              Navigator.pop(context); // Settings screen
            },
            child:
                const Text("Ha, chiqish", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
