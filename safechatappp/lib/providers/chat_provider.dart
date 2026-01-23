import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:io';

class ChatProvider with ChangeNotifier {
  late IO.Socket socket;
  List<Map<String, dynamic>> _messages = [];
  String? _currentChatRoom;
  bool _isConnected = false;

  // Getterlar
  List<Map<String, dynamic>> get messages => _messages;
  String? get currentChatRoom => _currentChatRoom;
  bool get isConnected => _isConnected;

  // Soketni ishga tushirish
  void initSocket(String username) {
    // RENDER yoki o'zingizning Server URL manzilingizni yozing
    // Masalan: http://192.168.1.10:5000 yoki https://safechat.onrender.com
    socket =
        IO.io('https://safechat-backend-api.onrender.com', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.connect();

    socket.onConnect((_) {
      _isConnected = true;
      print('Socket.IO ga ulandi');
      socket.emit('join', {'username': username});
      notifyListeners();
    });

    socket.onDisconnect((_) {
      _isConnected = false;
      print('Socket.IO uzildi');
      notifyListeners();
    });

    // Xabar kelganda
    socket.on('receive_message', (data) {
      // Kelgan xabar aynan hozirgi ochiq xonaga tegishli ekanini tekshirish (ixtiyoriy)
      _messages.insert(0, Map<String, dynamic>.from(data));
      notifyListeners();
    });
  }

  // Shaxsiy chatga kirish (Xonani yaratish)
  void setCurrentChat(String user1, String user2) {
    List<String> ids = [user1, user2];
    ids.sort(); // Xona nomi har doim bir xil bo'lishi uchun (masalan: ali_vali)
    _currentChatRoom = ids.join('_');

    // Xonani almashtirganda xabarlarni tozalash (yoki serverdan yuklash)
    _messages = [];

    // Serverga xonaga qo'shilganimizni bildirish
    socket.emit('join_room', {'room': _currentChatRoom});

    notifyListeners();
  }

  // Oddiy matnli xabar yuborish
  void sendMessage({
    required String sender,
    required String receiver,
    required String text,
  }) {
    if (text.trim().isEmpty) return;

    final msgData = {
      'sender': sender,
      'receiver': receiver,
      'content': text,
      'room': _currentChatRoom,
      'chat_type': 'private',
      'timestamp': DateTime.now().toIso8601String(),
    };

    // Serverga yuborish
    socket.emit('send_message', msgData);

    // O'zimizning ro'yxatga darhol qo'shish (UI tez ishlashi uchun)
    _messages.insert(0, msgData);
    notifyListeners();
  }

  // Media (Rasm/Video) yuborish funksiyasi
  Future<void> sendMedia(
      File file, String type, String sender, String receiver) async {
    // 1. Avval faylni serverga (masalan Flask /uploads/ ga) yuklash kerak
    // 2. Server qaytargan URL manzilini soket orqali yuborish kerak

    print("${type} yuborilmoqda: ${file.path}");

    // Hozircha namunaviy struktura:
    final msgData = {
      'sender': sender,
      'receiver': receiver,
      'content': 'Media xabar',
      'media_url': 'yuklangan_fayl_url',
      'type': type,
      'room': _currentChatRoom,
    };

    socket.emit('send_message', msgData);
  }

  @override
  void dispose() {
    socket.disconnect();
    super.dispose();
  }
}
