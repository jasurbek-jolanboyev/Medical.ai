import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ==========================================================
// 1. ADMIN DASHBOARD - ASOSIY BOSHQARUV MARKAZI
// ==========================================================
class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("SafeChat Admin", 
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatGrid(),
            const SizedBox(height: 30),
            const Text("BOSHQARUV AMALLARI", 
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
            const SizedBox(height: 15),
            _buildAdminMenu(context),
          ],
        ),
      ),
    );
  }

  Widget _buildStatGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, userSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('posts').snapshots(),
          builder: (context, postSnap) {
            int userCount = userSnap.data?.docs.length ?? 0;
            int postCount = postSnap.data?.docs.length ?? 0;

            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 15,
              crossAxisSpacing: 15,
              childAspectRatio: 1.4,
              children: [
                _statCard("Foydalanuvchilar", userCount.toString(), Icons.people, Colors.blue),
                _statCard("Jami Postlar", postCount.toString(), Icons.article, Colors.orange),
                _statCard("Onlayn", "Active", Icons.bolt, Colors.green),
                _statCard("Shikoyatlar", "0", Icons.report, Colors.red),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAdminMenu(BuildContext context) {
    return Column(
      children: [
        _menuTile(Icons.group_outlined, "Foydalanuvchilar", "Bloklash, Rol berish va Ro'yxat", Colors.blue, 
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UsersListScreen()))),
        _menuTile(Icons.post_add_rounded, "Dinamik Post Qo'shish", "Video, Rasm va Yuklab olish linklari", Colors.purple, 
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddPostScreen()))),
      ],
    );
  }

  Widget _statCard(String title, String val, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), 
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 24),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(val, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ]),
        ],
      ),
    );
  }

  Widget _menuTile(IconData icon, String title, String sub, Color color, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(sub, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, size: 20),
      ),
    );
  }
}

// ==========================================================
// 2. USERS LIST SCREEN - FOYDALANUVCHILARNI BOSHQARISH
// ==========================================================
class UsersListScreen extends StatelessWidget {
  const UsersListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(title: const Text("Foydalanuvchilar"), centerTitle: true),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final users = snapshot.data!.docs;
          
          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final userData = users[index].data() as Map<String, dynamic>;
              final String uid = users[index].id;
              final bool isBlocked = userData['isBlocked'] ?? false;
              final String role = userData['role'] ?? 'user';

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: (userData['avatar'] != null && userData['avatar'] != '') 
                        ? NetworkImage(userData['avatar']) : null,
                    child: (userData['avatar'] == null || userData['avatar'] == '') 
                        ? const Icon(Icons.person) : null,
                  ),
                  title: Text(userData['username'] ?? "Noma'lum", style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Rol: ${role.toUpperCase()} ${isBlocked ? '🛑' : '✅'}"),
                  trailing: PopupMenuButton<String>(
                    onSelected: (val) => _handleUserAction(context, uid, val, isBlocked),
                    itemBuilder: (context) => [
                      PopupMenuItem(value: 'block', child: Text(isBlocked ? "Blokdan yechish" : "Bloklash")),
                      const PopupMenuItem(value: 'admin', child: Text("Admin darajasiga ko'tarish")),
                      const PopupMenuItem(value: 'user', child: Text("User darajasiga tushirish")),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _handleUserAction(BuildContext context, String uid, String action, bool status) async {
    final ref = FirebaseFirestore.instance.collection('users').doc(uid);
    if (action == 'block') await ref.update({'isBlocked': !status});
    if (action == 'admin') await ref.update({'role': 'admin'});
    if (action == 'user') await ref.update({'role': 'user'});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Muvaffaqiyatli bajarildi")));
  }
}

// ==========================================================
// 3. ADD POST SCREEN - ILG'OR DINAMIK POST YARATISH
// ==========================================================
class AddPostScreen extends StatefulWidget {
  const AddPostScreen({super.key});

  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _thumbnailController = TextEditingController();
  final _videoUrlController = TextEditingController();
  final _btnLabelController = TextEditingController();
  final _btnActionController = TextEditingController();

  String _selectedType = 'image'; // Standart rasm
  bool _isLoading = false;

  Future<void> _publishPost() async {
    if (_titleController.text.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('posts').add({
        'title': _titleController.text.trim(),
        'shortDesc': _descController.text.trim(),
        'mediaPath': _thumbnailController.text.trim(), // Asosiy rasm
        'videoUrl': _videoUrlController.text.trim(),   // Video linki
        'type': _selectedType,                         // image yoki video
        'buttonText': _btnLabelController.text.trim(), // Tugma nomi
        'buttonLink': _btnActionController.text.trim(),// Tugma amali
        'views': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      Navigator.pop(context);
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xatolik: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Yangi Post Yaratish")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Post turini tanlash (Rasm yoki Video)
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'image', label: Text("Rasm"), icon: Icon(Icons.image)),
                ButtonSegment(value: 'video', label: Text("Video"), icon: Icon(Icons.videocam)),
              ],
              selected: {_selectedType},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() => _selectedType = newSelection.first);
              },
            ),
            const SizedBox(height: 20),
            
            _buildInput(_titleController, "Post sarlavhasi", Icons.title),
            _buildInput(_descController, "Qisqacha tavsif", Icons.description, lines: 3),
            _buildInput(_thumbnailController, "Asosiy rasm (URL)", Icons.link),
            
            if (_selectedType == 'video')
              _buildInput(_videoUrlController, "Video URL (MP4/YouTube)", Icons.play_circle_fill),

            const Divider(height: 40),
            const Text("HARAKAT TUGMASI (IXTIYORIY)", 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blueGrey)),
            const SizedBox(height: 10),
            
            _buildInput(_btnLabelController, "Tugma matni (masalan: Yuklab olish)", Icons.ads_click),
            _buildInput(_btnActionController, "Tugma linki", Icons.launch),

            const SizedBox(height: 30),
            _isLoading
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _publishPost,
                      child: const Text("POSTNI CHIQARISH", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(TextEditingController controller, String label, IconData icon, {int lines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        maxLines: lines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
      ),
    );
  }
}