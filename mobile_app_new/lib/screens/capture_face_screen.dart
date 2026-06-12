import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class CaptureFaceScreen extends StatefulWidget {
  const CaptureFaceScreen({super.key});

  @override
  State<CaptureFaceScreen> createState() =>
      _CaptureFaceScreenState();
}

class _CaptureFaceScreenState
    extends State<CaptureFaceScreen> {

  File? imageFile;
  String savedPath = "";

  Future<void> captureImage() async {
    final picker = ImagePicker();

    final XFile? image =
        await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );

    if (image != null) {
      setState(() {
        imageFile = File(image.path);
      });
    }
  }

  Future<void> saveFace() async {
    if (imageFile == null) return;

    final directory =
        await getApplicationDocumentsDirectory();

    final String newPath =
        "${directory.path}/owner_face.jpg";

    final File savedImage =
        await imageFile!.copy(newPath);

    setState(() {
      savedPath = savedImage.path;
    });

    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
              Text("Face Saved Successfully"),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Capture Face",
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding:
              const EdgeInsets.all(20),
          child: Column(
            children: [

              const SizedBox(height: 20),

              imageFile == null
                  ? const Icon(
                      Icons.face,
                      size: 180,
                    )
                  : ClipRRect(
                      borderRadius:
                          BorderRadius.circular(15),
                      child: Image.file(
                        imageFile!,
                        height: 300,
                      ),
                    ),

              const SizedBox(height: 30),

              ElevatedButton.icon(
                onPressed: captureImage,
                icon: const Icon(
                  Icons.camera_alt,
                ),
                label: const Text(
                  "Capture Face",
                ),
              ),

              const SizedBox(height: 15),

              if (imageFile != null)

                ElevatedButton.icon(
                  onPressed: saveFace,
                  icon: const Icon(
                    Icons.save,
                  ),
                  label: const Text(
                    "Save Face",
                  ),
                ),

              const SizedBox(height: 20),

              if (savedPath.isNotEmpty)

                Card(
                  child: Padding(
                    padding:
                        const EdgeInsets.all(12),
                    child: Column(
                      children: [

                        const Text(
                          "Saved Face Location",
                          style: TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        const SizedBox(
                          height: 10,
                        ),

                        Text(
                          savedPath,
                          textAlign:
                              TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}