import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MessageBubble extends StatelessWidget {
  final String text;
  final String? imageUrl;
  final bool isMe;
  final DateTime timestamp;
  final String senderName;
  final bool isRead;
  final bool isEdited; // Tahrirlanganligini ko'rsatish
  final Map<String, dynamic>? replyTo; // Qaysi xabarga javob berilgani

  const MessageBubble({
    super.key,
    required this.text,
    this.imageUrl,
    required this.isMe,
    required this.timestamp,
    required this.senderName,
    this.isRead = true,
    this.isEdited = false,
    this.replyTo,
  });

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm').format(timestamp);
    final size = MediaQuery.of(context).size;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe) _buildAvatar(),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  constraints: BoxConstraints(maxWidth: size.width * 0.75),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isMe ? const Color(0xFF2563EB) : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMe ? 18 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // --- REPLY QISMI ---
                      if (replyTo != null) _buildReplyBlock(),

                      // --- IMAGE QISMI ---
                      if (imageUrl != null && imageUrl!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _buildImage(context),
                        ),

                      // --- MATN VA VAQT ---
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Wrap(
                          alignment: WrapAlignment.end,
                          crossAxisAlignment: WrapCrossAlignment.end,
                          runSpacing: 4,
                          children: [
                            Text(
                              text,
                              style: TextStyle(
                                color: isMe ? Colors.white : Colors.black87,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isEdited)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: Text(
                                      "tahrirlandi",
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontStyle: FontStyle.italic,
                                        color: isMe ? Colors.white70 : Colors.black45,
                                      ),
                                    ),
                                  ),
                                Text(
                                  time,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isMe ? Colors.white70 : Colors.black45,
                                  ),
                                ),
                                if (isMe) ...[
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.done_all,
                                    size: 14,
                                    color: isRead ? Colors.lightBlueAccent : Colors.white60,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Javob berilgan xabar bloki (Reply design)
  Widget _buildReplyBlock() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        color: isMe ? Colors.white.withOpacity(0.15) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: isMe ? Colors.white : Colors.blue,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            replyTo!['senderName'] ?? "Foydalanuvchi",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isMe ? Colors.white : Colors.blue,
            ),
          ),
          Text(
            replyTo!['text'] ?? "",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: isMe ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            builder: (_) => Dialog(
              backgroundColor: Colors.transparent,
              child: InteractiveViewer(child: CachedNetworkImage(imageUrl: imageUrl!)),
            ),
          );
        },
        child: CachedNetworkImage(
          imageUrl: imageUrl!,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            height: 150,
            width: double.infinity,
            color: Colors.black12,
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          errorWidget: (context, url, error) => const Icon(Icons.error),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return CircleAvatar(
      radius: 14,
      backgroundColor: Colors.blue.shade100,
      child: Text(
        senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}