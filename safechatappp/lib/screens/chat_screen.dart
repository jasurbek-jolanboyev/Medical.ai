import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  final String roomId;
  final String otherUserId;
  final String otherUsername;
  final String otherAvatar;

  const ChatScreen({
    super.key,
    required this.roomId,
    required this.otherUserId,
    required this.otherUsername,
    required this.otherAvatar,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  
  bool _isUploading = false;
  String? _editingMessageId;
  Map<String, dynamic>? _replyMessage;

  // 1. "YOZMOQDA..." HOLATINI YANGILASH
  void _onTyping(String value) {
    final currentUser = FirebaseAuth.instance.currentUser!;
    FirebaseFirestore.instance.collection('chats').doc(widget.roomId).set({
      'typing': {
        currentUser.uid: value.isNotEmpty, 
      }
    }, SetOptions(merge: true));
  }

  // Xabarni yuborgandan keyin typingni to'xtatish uchun yordamchi
  void _stopTyping() {
    final currentUser = FirebaseAuth.instance.currentUser!;
    FirebaseFirestore.instance.collection('chats').doc(widget.roomId).set({
      'typing': {
        currentUser.uid: false,
      }
    }, SetOptions(merge: true));
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final currentUser = FirebaseAuth.instance.currentUser!;
    _messageController.clear();
    _stopTyping(); // Yuborilganda typing to'xtaydi

    if (_editingMessageId != null) {
      await FirebaseFirestore.instance
          .collection('chats').doc(widget.roomId)
          .collection('messages').doc(_editingMessageId)
          .update({'text': text, 'isEdited': true});
      setState(() => _editingMessageId = null);
    } else {
      final messageData = {
        'text': text,
        'senderId': currentUser.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'text',
        'isRead': false,
        'replyTo': _replyMessage,
      };
      await _saveMessage(messageData, text);
      setState(() => _replyMessage = null);
    }
  }

  // Media yuborish (Rasm, Video va h.k.)
  Future<void> _sendMedia(String type) async {
    String? filePath;
    String? fileName;
    try {
      if (type == 'image') {
        final XFile? file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
        filePath = file?.path;
      } else if (type == 'video') {
        final XFile? file = await _picker.pickVideo(source: ImageSource.gallery);
        filePath = file?.path;
      } else if (type == 'audio' || type == 'file') {
        FilePickerResult? result = await FilePicker.platform.pickFiles(type: type == 'audio' ? FileType.audio : FileType.any);
        filePath = result?.files.single.path;
        fileName = result?.files.single.name;
      }

      if (filePath == null) return;
      setState(() => _isUploading = true);

      final currentUser = FirebaseAuth.instance.currentUser!;
      final String ext = filePath.split('.').last;
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();

      final ref = FirebaseStorage.instance.ref().child('chat_media/${widget.roomId}/${type}_$timestamp.$ext');
      await ref.putFile(File(filePath));
      final url = await ref.getDownloadURL();

      final messageData = {
        'fileUrl': url,
        'fileName': fileName ?? "$type.$ext",
        'text': type == 'image' ? '📷 Rasm' : type == 'video' ? '🎥 Video' : type == 'audio' ? '🎵 Musiqa' : '📁 Fayl',
        'senderId': currentUser.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'type': type,
        'isRead': false,
        'replyTo': _replyMessage,
      };

      await _saveMessage(messageData, messageData['text'] as String);
      setState(() => _replyMessage = null);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xatolik: $e")));
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _saveMessage(Map<String, dynamic> data, String lastMsg) async {
    await FirebaseFirestore.instance.collection('chats').doc(widget.roomId).collection('messages').add(data);
    await FirebaseFirestore.instance.collection('chats').doc(widget.roomId).set({
      'lastMessage': lastMsg,
      'lastTime': FieldValue.serverTimestamp(),
      'users': [FirebaseAuth.instance.currentUser!.uid, widget.otherUserId],
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (_isUploading) const LinearProgressIndicator(backgroundColor: Colors.transparent),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats').doc(widget.roomId)
                  .collection('messages').orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) return _buildEmptyState();

                return ListView.builder(
                  reverse: true,
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final msg = docs[index].data() as Map<String, dynamic>;
                    final isMe = msg['senderId'] == FirebaseAuth.instance.currentUser!.uid;

                    return GestureDetector(
                      onLongPress: () => _showOptions(docs[index].id, msg, isMe),
                      child: MessageBubble(
                        text: msg['text'] ?? '',
                        imageUrl: msg['type'] == 'image' ? msg['fileUrl'] : null,
                        isMe: isMe,
                        timestamp: (msg['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
                        senderName: isMe ? 'Siz' : widget.otherUsername,
                        isEdited: msg['isEdited'] ?? false,
                        replyTo: msg['replyTo'],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  // 2. APPBAR-DA ONLINE VA TYPING STATUSI
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0.5,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      title: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('chats').doc(widget.roomId).snapshots(),
        builder: (context, chatSnap) {
          bool isOtherTyping = false;
          if (chatSnap.hasData && chatSnap.data!.exists) {
            Map<String, dynamic> data = chatSnap.data!.data() as Map<String, dynamic>;
            isOtherTyping = data['typing']?[widget.otherUserId] ?? false;
          }

          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(widget.otherUserId).snapshots(),
            builder: (context, userSnap) {
              bool isOnline = false;
              if (userSnap.hasData && userSnap.data!.exists) {
                isOnline = userSnap.data!['online'] ?? false;
              }

              return Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundImage: widget.otherAvatar.isNotEmpty ? CachedNetworkImageProvider(widget.otherAvatar) : null,
                    child: widget.otherAvatar.isEmpty ? Text(widget.otherUsername[0]) : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.otherUsername, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text(
                          isOtherTyping ? "yozmoqda..." : (isOnline ? "online" : "offline"),
                          style: TextStyle(
                            fontSize: 12, 
                            color: isOtherTyping || isOnline ? Colors.green : Colors.grey,
                            fontWeight: isOtherTyping ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMessageInput() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_replyMessage != null) _buildReplyPreview(),
        if (_editingMessageId != null) _buildEditPreview(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          color: Colors.white,
          child: SafeArea(
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.blue, size: 28), onPressed: _showAttachmentMenu),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(25)),
                    child: TextField(
                      controller: _messageController,
                      onChanged: _onTyping, // Typing boshlandi
                      maxLines: null,
                      decoration: const InputDecoration(hintText: 'Xabar...', border: InputBorder.none),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                GestureDetector(
                  onTap: _sendMessage,
                  child: CircleAvatar(
                    backgroundColor: _editingMessageId != null ? Colors.orange : Colors.blue,
                    child: Icon(_editingMessageId != null ? Icons.check : Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Options, Modal va boshqa yordamchi UI qismlari (Oldingi kodingizdagidek qoladi)
  void _showOptions(String messageId, Map<String, dynamic> msgData, bool isMe) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.reply_rounded),
            title: const Text("Javob berish"),
            onTap: () {
              Navigator.pop(context);
              setState(() => _replyMessage = {'text': msgData['text'], 'senderName': isMe ? 'Siz' : widget.otherUsername});
            },
          ),
          ListTile(
            leading: const Icon(Icons.copy_rounded),
            title: const Text("Nusxalash"),
            onTap: () {
              Clipboard.setData(ClipboardData(text: msgData['text']));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Nusxalandi")));
            },
          ),
          if (isMe && msgData['type'] == 'text')
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: Colors.orange),
              title: const Text("Tahrirlash"),
              onTap: () {
                Navigator.pop(context);
                setState(() { _editingMessageId = messageId; _messageController.text = msgData['text']; });
              },
            ),
          if (isMe)
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              title: const Text("O'chirish"),
              onTap: () async {
                Navigator.pop(context);
                await FirebaseFirestore.instance.collection('chats').doc(widget.roomId).collection('messages').doc(messageId).delete();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildReplyPreview() {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.blue.shade50,
      child: Row(
        children: [
          const Icon(Icons.reply, size: 20, color: Colors.blue),
          const SizedBox(width: 10),
          Expanded(child: Text("${_replyMessage!['senderName']}: ${_replyMessage!['text']}", maxLines: 1, overflow: TextOverflow.ellipsis)),
          IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => setState(() => _replyMessage = null)),
        ],
      ),
    );
  }

  Widget _buildEditPreview() {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.orange.shade50,
      child: Row(
        children: [
          const Icon(Icons.edit, size: 20, color: Colors.orange),
          const SizedBox(width: 10),
          const Expanded(child: Text("Xabarni tahrirlash...", style: TextStyle(color: Colors.orange))),
          IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () {
            setState(() { _editingMessageId = null; _messageController.clear(); _stopTyping(); });
          }),
        ],
      ),
    );
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _attachItem(Icons.image, "Rasm", Colors.orange, () => _sendMedia('image')),
            _attachItem(Icons.videocam, "Video", Colors.red, () => _sendMedia('video')),
            _attachItem(Icons.audiotrack, "Musiqa", Colors.purple, () => _sendMedia('audio')),
            _attachItem(Icons.insert_drive_file, "Fayl", Colors.blue, () => _sendMedia('file')),
          ],
        ),
      ),
    );
  }

  Widget _attachItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: () { Navigator.pop(context); onTap(); },
      child: Column(children: [CircleAvatar(radius: 25, backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)), const SizedBox(height: 8), Text(label, style: const TextStyle(fontSize: 12))]),
    );
  }

  Widget _buildEmptyState() {
    return Center(child: Text("Hali xabarlar yo'q", style: TextStyle(color: Colors.grey.shade500)));
  }
}