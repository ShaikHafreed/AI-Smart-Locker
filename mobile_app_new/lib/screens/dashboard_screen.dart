import 'dart:async';

import 'package:flutter/material.dart';

import '../api_service.dart';

import 'capture_face_screen.dart';
import 'gallery_screen.dart';
import 'approval_request_screen.dart';
import 'logs_screen.dart';
import 'verify_face_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int selectedIndex = 0;

  Map<String, dynamic>? statusData;

  Timer? timer;

  @override
  void initState() {
    super.initState();

    loadStatus();

    timer = Timer.periodic(const Duration(seconds: 5), (_) {
      loadStatus();
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> loadStatus() async {
    try {
      final result = await ApiService.getStatus();

      setState(() {
        statusData = result;
      });
    } catch (e) {
      print(e);
    }
  }

  Widget statusCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: ListTile(
        leading: Icon(icon, color: color, size: 35),
        title: Text(title),
        subtitle: Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget dashboardButton(
    BuildContext context,
    IconData icon,
    String title,
    Widget page,
  ) {
    return Card(
      elevation: 5,
      child: InkWell(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => page));
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40),

            const SizedBox(height: 10),

            Text(title, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI Smart Locker"), centerTitle: true),

      body: statusData == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(12),

                child: Column(
                  children: [
                    statusCard(
                      "Locker Status",
                      statusData!["locker"].toString(),
                      Icons.lock,
                      Colors.green,
                    ),

                    statusCard(
                      "Pending Request",
                      statusData!["pending"].toString(),
                      Icons.approval,
                      Colors.orange,
                    ),

                    statusCard(
                      "Last Event",
                      statusData!["last_event"].toString(),
                      Icons.history,
                      Colors.blue,
                    ),

                    statusCard(
                      "Total Logs",
                      statusData!["total_logs"].toString(),
                      Icons.list,
                      Colors.purple,
                    ),

                    statusCard(
                      "Intruder Count",
                      statusData!["intruder_count"].toString(),
                      Icons.warning,
                      Colors.red,
                    ),

                    const SizedBox(height: 20),

                    GridView.count(
                      shrinkWrap: true,

                      physics: const NeverScrollableScrollPhysics(),

                      crossAxisCount: 2,

                      crossAxisSpacing: 12,

                      mainAxisSpacing: 12,

                      children: [
                        dashboardButton(
                          context,
                          Icons.face,
                          "Capture Face",
                          const CaptureFaceScreen(),
                        ),

                        dashboardButton(
                          context,
                          Icons.photo_library,
                          "Gallery Images",
                          const GalleryScreen(),
                        ),

                        dashboardButton(
                          context,
                          Icons.verified_user,
                          "Verify Face",
                          const VerifyFaceScreen(),
                        ),

                        dashboardButton(
                          context,
                          Icons.approval,
                          "Approval Requests",
                          const ApprovalRequestScreen(),
                        ),

                        dashboardButton(
                          context,
                          Icons.history,
                          "Access Logs",
                          const LogsScreen(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,

        onTap: (index) {
          setState(() {
            selectedIndex = index;
          });
        },

        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),

          BottomNavigationBarItem(icon: Icon(Icons.history), label: "Logs"),

          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}
