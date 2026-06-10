import 'package:flutter/material.dart';

class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gallery Images"),
      ),
      body: const Center(
        child: Text(
          "Captured Images",
          style: TextStyle(
            fontSize: 24,
          ),
        ),
      ),
    );
  }
}