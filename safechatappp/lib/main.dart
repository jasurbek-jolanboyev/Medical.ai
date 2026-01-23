import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:overlay_support/overlay_support.dart';
import 'firebase_options.dart';

// Sahifalar
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/username_setup_screen.dart';
import 'screens/admin/admin_dashboard.dart'; // Fayl manzilingizga e'tibor bering

// Provayderlar
import 'providers/auth_provider.dart' as my_auth;
import 'providers/chat_provider.dart';

// Servislar
import 'services/notification_service.dart';

// Global Navigator Key - Context bo'lmagan joyda navigatsiya qilish uchun
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Background bildirishnomalar
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Bildirishnoma kanalini sozlash
  await NotificationService.initialize();

  // StatusBar rangini sozlash
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    const OverlaySupport.global(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Ilova ochiqligida bildirishnomalarni tinglash
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      NotificationService.showLocalNotification(message);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => my_auth.AuthProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey, // Navigator key bog'landi
        title: 'SafeChat',
        debugShowCheckedModeBanner: false,
        routes: {
          '/login': (context) => const LoginScreen(),
          '/home': (context) => const HomeScreen(),
          '/admin': (context) => const AdminDashboard(),
        },
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Urbanist',
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2563EB),
            primary: const Color(0xFF2563EB),
          ),
          scaffoldBackgroundColor: Colors.white,
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<my_auth.AuthProvider>(context);

    if (auth.isLoading) {
      return const Scaffold(
        body:
            Center(child: CircularProgressIndicator(color: Color(0xFF2563EB))),
      );
    }

    final user = auth.currentUser;

    if (user == null) {
      return const LoginScreen();
    }

    // Foydalanuvchi ma'lumotlarini real vaqtda kuzatish
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(body: Center(child: Text("Xatolik yuz berdi")));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          // Foydalanuvchi bazada yo'q bo'lsa (yangi kirgan bo'lsa)
          return const UsernameSetupScreen();
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;

        // 1. BLOKLANGANLIKNI TEKSHIRISH
        final bool isBlocked = userData['isBlocked'] ?? false;
        if (isBlocked) {
          return _buildBlockedUI(context, auth);
        }

        // 2. ROLNI TEKSHIRISH (ADMIN)
        final String role = userData['role'] ?? 'user';
        if (role == 'admin') {
          return const AdminDashboard();
        }

        // 3. USERNAME TEKSHIRISH
        final String? username = userData['username'];
        if (username != null && username.isNotEmpty) {
          // Socketga ulanish (faqat bir marta)
          _connectSocket(context, username);
          return const HomeScreen();
        }

        return const UsernameSetupScreen();
      },
    );
  }

  void _connectSocket(BuildContext context, String username) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      if (!chatProvider.isConnected) {
        chatProvider.initSocket(username);
      }
    });
  }

  Widget _buildBlockedUI(BuildContext context, my_auth.AuthProvider auth) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.gpp_bad_rounded,
                  color: Colors.redAccent, size: 100),
              const SizedBox(height: 25),
              const Text(
                "Hisobingiz cheklangan",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              const Text(
                "Siz SafeChat qoidalarini buzganingiz uchun bloklandingiz. Ma'lumot uchun admin bilan bog'laning.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.blueGrey, fontSize: 16),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => auth.signOut(),
                  child: const Text("TIZIMDAN CHIQISH",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
