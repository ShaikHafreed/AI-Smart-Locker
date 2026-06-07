import 'dart:async';
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'images_screen.dart';

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
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() =>
      _DashboardScreenState();
}

class _DashboardScreenState
    extends State<DashboardScreen> {

  Map<String, dynamic>? data;

  @override
  void initState() {
    super.initState();

    loadData();

    Timer.periodic(
      const Duration(seconds: 3),
      (timer) {
        loadData();
      },
    );
  }

  Future<void> loadData() async {

    var result =
        await ApiService.getStatus();

    setState(() {
      data = result;
    });
  }

  Widget statusCard(
    IconData icon,
    Color color,
    String title,
    String value,
  ) {
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

    if (data == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "AI Smart Locker",
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            statusCard(
              Icons.lock,
              Colors.green,
              "Locker Status",
              data!["locker"],
            ),

            statusCard(
              Icons.door_front_door,
              Colors.orange,
              "Door Status",
              data!["door"],
            ),

            statusCard(
              Icons.face,
              Colors.green,
              "Owner Status",
              data!["owner"],
            ),

            statusCard(
              Icons.warning,
              Colors.red,
              "Latest Alert",
              data!["alert"],
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const ImagesScreen(),
                  ),
                );
              },
              child: const Text(
                "VIEW CAPTURED IMAGES",
              ),
            ),
          ],
        ),
      ),
    );
  }
}