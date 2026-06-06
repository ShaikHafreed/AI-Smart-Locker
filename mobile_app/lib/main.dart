import 'package:flutter/material.dart';
import 'api_service.dart';

void main() {
  runApp(const SmartLockerApp());
}

class SmartLockerApp extends StatelessWidget {
  const SmartLockerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "AI Smart Locker",
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Widget statusCard(
      IconData icon,
      Color color,
      String title,
      String value) {
    return Card(
      elevation: 5,
      child: ListTile(
        leading: Icon(
          icon,
          color: color,
          size: 40,
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          value,
          style: const TextStyle(
            fontSize: 18,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AI Smart Locker"),
        centerTitle: true,
      ),
      body: FutureBuilder(
        future: ApiService.getStatus(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          var data =
              snapshot.data as Map<String, dynamic>;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [

                statusCard(
                  Icons.lock,
                  Colors.green,
                  "Locker Status",
                  data["locker"],
                ),

                statusCard(
                  Icons.door_front_door,
                  Colors.orange,
                  "Door Status",
                  data["door"],
                ),

                statusCard(
                  Icons.face,
                  Colors.green,
                  "Owner Status",
                  data["owner"],
                ),

                statusCard(
                  Icons.warning,
                  Colors.red,
                  "Latest Alert",
                  data["alert"],
                ),

                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: () {},
                  child: const Text(
                    "VIEW CAPTURED IMAGES",
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}