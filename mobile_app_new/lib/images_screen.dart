import 'package:flutter/material.dart';
import 'api_service.dart';

class ImagesScreen extends StatelessWidget {
  const ImagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Captured Images"),
      ),
      body: FutureBuilder(
        future: ApiService.getImages(),
        builder: (context, snapshot) {

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          List images =
              snapshot.data as List;

          if (images.isEmpty) {
            return const Center(
              child: Text("No Images Found"),
            );
          }

          return ListView.builder(
            itemCount: images.length,
            itemBuilder: (context, index) {

              return Card(
                margin: const EdgeInsets.all(10),
                child: Column(
                  children: [

                    Image.network(
                      images[index],
                      fit: BoxFit.cover,
                    ),

                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        images[index],
                        style: const TextStyle(
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}