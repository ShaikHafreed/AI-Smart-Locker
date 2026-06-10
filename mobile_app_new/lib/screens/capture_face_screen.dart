import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class CaptureFaceScreen extends StatefulWidget {
  const CaptureFaceScreen({super.key});

  @override
  State<CaptureFaceScreen> createState() =>
      _CaptureFaceScreenState();
}

class _CaptureFaceScreenState
    extends State<CaptureFaceScreen> {

  File? imageFile;

  Future<void> captureImage() async {
    final picker = ImagePicker();

    final XFile? image =
        await picker.pickImage(
      source: ImageSource.camera,
    );

    if (image != null) {
      setState(() {
        imageFile = File(image.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Capture Face"),
      ),
      body: Center(
        child: Padding(
          padding:
              const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [

              imageFile == null
                  ? const Icon(
                      Icons.face,
                      size: 150,
                    )
                  : Image.file(
                      imageFile!,
                      height: 300,
                    ),

              const SizedBox(
                height: 30,
              ),

              ElevatedButton.icon(
                onPressed:
                    captureImage,
                icon:
                    const Icon(Icons.camera),
                label: const Text(
                  "Capture Face",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}