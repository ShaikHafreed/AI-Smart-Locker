import 'package:flutter/material.dart';
import 'api_service.dart';

class ImagesScreen extends StatefulWidget {
  const ImagesScreen({super.key});

  @override
  State<ImagesScreen> createState() => _ImagesScreenState();
}

class _ImagesScreenState extends State<ImagesScreen> {
  late Future<List<dynamic>> _imagesFuture;

  @override
  void initState() {
    super.initState();
    _imagesFuture = ApiService.getImages();
  }

  Future<void> _refresh() async {
    setState(() {
      _imagesFuture = ApiService.getImages();
    });
    // wait for the new future so the RefreshIndicator spinner
    // stays visible until data actually arrives
    await _imagesFuture;
  }

  void _openFullImage(String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          backgroundColor: Colors.black,
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4,
              child: Image.network(
                url,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.broken_image,
                  color: Colors.white54,
                  size: 64,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Captured Images")),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<dynamic>>(
          future: _imagesFuture,
          builder: (context, snapshot) {
            // Error state
            if (snapshot.connectionState == ConnectionState.done &&
                snapshot.hasError) {
              return ListView(
                // ListView wrapper keeps pull-to-refresh working
                // even when the body is just an error message
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline,
                              size: 48, color: Colors.redAccent),
                          const SizedBox(height: 12),
                          const Text("Couldn't load images"),
                          const SizedBox(height: 4),
                          Text(
                            "${snapshot.error}",
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _refresh,
                            child: const Text("Retry"),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            // Loading state
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final List images = snapshot.data as List;

            // Empty state
            if (images.isEmpty) {
              return ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: const Center(
                      child: Text("No Images Found"),
                    ),
                  ),
                ],
              );
            }

            // Grid of thumbnails
            return GridView.builder(
              padding: const EdgeInsets.all(10),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: images.length,
              itemBuilder: (context, index) {
                final String url = images[index];

                return GestureDetector(
                  onTap: () => _openFullImage(url),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      url,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.broken_image,
                            color: Colors.grey),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}