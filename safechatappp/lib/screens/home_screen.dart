import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = "";
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateUserStatus(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateUserStatus(true);
    } else {
      _updateUserStatus(false);
    }
  }

  void _updateUserStatus(bool isOnline) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
        'online': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true,
      appBar: _selectedIndex == 0 ? _buildAppBar() : null,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildChatList(),
          const Center(child: Text("Yangiliklar (Reels) Sahifasi")),
          const Center(child: Text("Ommaviy Guruhlar Sahifasi")),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: _buildModernBottomNav(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      centerTitle: false,
      title: const Text(
        'SafeChat',
        style: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w900,
          fontSize: 26,
          letterSpacing: -0.5,
        ),
      ),
      actions: const [],
    );
  }

  Widget _buildChatList() {
    return Column(
      children: [
        _buildSearchBox(),
        _buildSectionTitle(
            _isSearching ? "Qidiruv natijalari" : "Sizning chatlaringiz"),
        Expanded(
          child: _isSearching ? _buildSearchResults() : _buildActiveChats(),
        ),
      ],
    );
  }

  Widget _buildSearchBox() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(15),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (val) {
            setState(() {
              _searchQuery = val.trim();
              _isSearching = _searchQuery.isNotEmpty;
            });
          },
          decoration: InputDecoration(
            hintText: "Username orqali qidirish...",
            prefixIcon: const Icon(Icons.search, color: Colors.grey),
            suffixIcon: _isSearching
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = "";
                        _isSearching = false;
                      });
                    })
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    final currentUser = FirebaseAuth.instance.currentUser;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: _searchQuery)
          .where('username', isLessThanOrEqualTo: '$_searchQuery\uf8ff')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildNoResult("Foydalanuvchi topilmadi");
        }

        final users = snapshot.data!.docs
            .where((doc) => doc.id != currentUser?.uid)
            .toList();

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final userData = users[index].data() as Map<String, dynamic>;
            return _buildUserTile(
              context,
              uid: users[index].id,
              username: userData['username'] ?? 'Foydalanuvchi',
              avatar: userData['avatar'] ?? '',
              online: userData['online'] ?? false,
              bio: userData['bio'] ?? 'SafeChat foydalanuvchisi',
              currentUserId: currentUser!.uid,
            );
          },
        );
      },
    );
  }

  // DOIMIY CHATLARNI KO'RSATISH QISMI
  Widget _buildActiveChats() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('users', arrayContains: currentUser.uid)
          .orderBy('lastTime',
              descending: true) // Oxirgi xabarga qarab tartiblash
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildNoResult(
              "Hali chatlar yo'q.\nDo'stlaringizni qidirib toping!");
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final chatDoc = snapshot.data!.docs[index];
            final chatData = chatDoc.data() as Map<String, dynamic>;
            final List users = chatData['users'];

            // Suhbatdoshni aniqlash
            final otherUserId = users.firstWhere((id) => id != currentUser.uid);

            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(otherUserId)
                  .snapshots(),
              builder: (context, userSnap) {
                if (!userSnap.hasData || !userSnap.data!.exists)
                  return const SizedBox();

                final userData = userSnap.data!.data() as Map<String, dynamic>;

                return _buildUserTile(
                  context,
                  uid: otherUserId,
                  username: userData['username'] ?? 'Foydalanuvchi',
                  avatar: userData['avatar'] ?? '',
                  online: userData['online'] ?? false,
                  // Agar oxirgi xabar bo'lsa ko'rsatamiz, bo'lmasa bio
                  bio: chatData['lastMessage'] ?? 'Yangi chat boshlandi',
                  currentUserId: currentUser.uid,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildModernBottomNav() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 30),
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(35),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(
              0, Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded),
          _navItem(1, Icons.play_circle_outline_rounded,
              Icons.play_circle_fill_rounded),
          _buildCenterPlusButton(),
          _navItem(2, Icons.explore_outlined, Icons.explore),
          _navItem(3, Icons.person_outline_rounded, Icons.person_rounded),
        ],
      ),
    );
  }

  Widget _navItem(int index, IconData icon, IconData activeIcon) {
    bool isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      child: Icon(
        isSelected ? activeIcon : icon,
        color: isSelected ? const Color(0xFF2563EB) : Colors.grey,
        size: 28,
      ),
    );
  }

  Widget _buildCenterPlusButton() {
    return GestureDetector(
      onTap: () => _showPlusMenu(context),
      child: Container(
        height: 52,
        width: 52,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient:
              LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)]),
          boxShadow: [
            BoxShadow(
                color: Color(0xFF2563EB), blurRadius: 12, offset: Offset(0, 4))
          ],
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
    );
  }

  void _showPlusMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _modalOption(Icons.group_add_rounded, "Yangi guruh",
                "Do'stlaringizni to'plang"),
            _modalOption(Icons.video_call_rounded, "Reels yuklash",
                "Qisqa video ulashing"),
            _modalOption(
                Icons.qr_code_scanner_rounded, "QR Kod", "Kontakt qo'shish"),
          ],
        ),
      ),
    );
  }

  Widget _modalOption(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF2563EB)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
      onTap: () => Navigator.pop(context),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Align(
          alignment: Alignment.centerLeft,
          child: Text(title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
    );
  }

  Widget _buildNoResult(String text) {
    return Center(
        child: Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey)));
  }

  Widget _buildUserTile(BuildContext context,
      {required String uid,
      required String username,
      required String avatar,
      required bool online,
      required String bio,
      required String currentUserId}) {
    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.blue.shade50,
            backgroundImage:
                avatar.isNotEmpty ? CachedNetworkImageProvider(avatar) : null,
            child: avatar.isEmpty ? Text(username[0].toUpperCase()) : null,
          ),
          if (online)
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                  )),
            ),
        ],
      ),
      title:
          Text(username, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(bio, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () {
        List<String> ids = [currentUserId, uid];
        ids.sort();
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => ChatScreen(
                    roomId: ids.join('_'),
                    otherUserId: uid,
                    otherUsername: username,
                    otherAvatar: avatar)));
      },
    );
  }
}
