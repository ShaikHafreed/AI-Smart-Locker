import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  File? savedFace;

  List<dynamic> visitorImages = [];

  bool isLoading = true;

  /// CHANGE THIS TO YOUR FLASK SERVER IP
  static const String serverUrl = "http://192.168.1.100:5000";

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    await loadSavedFace();
    await loadVisitorImages();

    setState(() {
      isLoading = false;
    });
  }

  Future<void> loadSavedFace() async {
    final directory = await getApplicationDocumentsDirectory();

    final String path = "${directory.path}/owner_face.jpg";

    final File image = File(path);

    if (await image.exists()) {
      setState(() {
        savedFace = image;
      });
    }
  }

  Future<void> loadVisitorImages() async {
    try {
      final response = await http.get(Uri.parse("$serverUrl/gallery"));

      if (response.statusCode == 200) {
        setState(() {
          visitorImages = jsonDecode(response.body);
        });
      }
    } catch (e) {
      debugPrint("Gallery Error: $e");
    }
  }

  Future<void> refreshGallery() async {
    await loadVisitorImages();
  }

  void openImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FullImageScreen(imageUrl: imageUrl)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Gallery")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: refreshGallery,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    "Registered Owner",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 15),

                  if (savedFace != null)
                    Card(
                      elevation: 5,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: Image.file(
                                savedFace!,
                                height: 250,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),

                            const SizedBox(height: 10),

                            const Text(
                              "Owner Face",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(child: Text("No Owner Face Registered")),
                      ),
                    ),

                  const SizedBox(height: 30),

                  const Text(
                    "Visitor History",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 15),

                  if (visitorImages.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(child: Text("No Visitor Images Found")),
                      ),
                    ),

                  ...visitorImages.map((image) {
                    return Card(
                      elevation: 4,
                      margin: const EdgeInsets.only(bottom: 15),
                      child: InkWell(
                        onTap: () {
                          openImage(image["url"]);
                        },
                        child: Column(
                          children: [
                            Image.network(
                              image["url"],
                              height: 220,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),

                            Padding(
                              padding: const EdgeInsets.all(10),
                              child: Text(
                                image["name"],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}

class FullImageScreen extends StatelessWidget {
  final String imageUrl;

  const FullImageScreen({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(child: InteractiveViewer(child: Image.network(imageUrl))),
    );
  }
}
