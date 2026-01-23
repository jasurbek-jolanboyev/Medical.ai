// lib/screens/post_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class PostDetailScreen extends StatefulWidget {
  final Map<String, dynamic> post;
  final String postId;
  const PostDetailScreen({super.key, required this.post, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    // Ko'rishlar sonini oshirish (faqat bir marta)
    _videoController =
        VideoPlayerController.networkUrl(Uri.parse(widget.post['mediaPath']))
          ..initialize().then((_) {
            setState(() {
              _chewieController = ChewieController(
                videoPlayerController: _videoController,
                autoPlay: true,
                looping: false,
                aspectRatio: _videoController.value.aspectRatio,
              );
            });
          });
  }

  @override
  void dispose() {
    _videoController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Maqola")),
      body: SingleChildScrollView(
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: _chewieController != null
                  ? Chewie(controller: _chewieController!)
                  : const Center(child: CircularProgressIndicator()),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.post['title'],
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  Text(widget.post['fullText'],
                      style: const TextStyle(
                          fontSize: 16, height: 1.5, color: Colors.black87)),
                  const SizedBox(height: 30),
                  const Text("Havolalar:",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  // JS dagi kabi linklar ro'yxati
                  ...?widget.post['links']
                      ?.map<Widget>((link) => ListTile(
                            leading: const Icon(Icons.link, color: Colors.blue),
                            title: Text(link['name']),
                            onTap: () {}, // Url launcher orqali ochish
                          ))
                      .toList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
