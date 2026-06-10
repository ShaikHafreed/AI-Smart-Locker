import 'package:flutter/material.dart';

import 'capture_face_screen.dart';
import 'gallery_screen.dart';
import 'approval_screen.dart';
import 'logs_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() =>
      _DashboardScreenState();
}

class _DashboardScreenState
    extends State<DashboardScreen> {

  int selectedIndex = 0;

  Widget statusCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 4,
      child: ListTile(
        leading: Icon(
          icon,
          color: color,
          size: 35,
        ),
        title: Text(title),
        subtitle: Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
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
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => page,
            ),
          );
        },
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 40,
            ),
            const SizedBox(
              height: 10,
            ),
            Text(
              title,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(
      BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text("AI Smart Locker"),
        centerTitle: true,
      ),

      body: SingleChildScrollView(
        child: Padding(
          padding:
              const EdgeInsets.all(12),
          child: Column(
            children: [

              statusCard(
                "Locker Status",
                "Locked",
                Icons.lock,
                Colors.green,
              ),

              statusCard(
                "Owner Status",
                "Verified",
                Icons.verified_user,
                Colors.blue,
              ),

              statusCard(
                "Last Access",
                "Today 5:30 PM",
                Icons.access_time,
                Colors.orange,
              ),

              const SizedBox(
                height: 20,
              ),

              GridView.count(
                shrinkWrap: true,
                physics:
                    const NeverScrollableScrollPhysics(),
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
                    Icons.approval,
                    "Approval Requests",
                    const ApprovalScreen(),
                  ),

                  dashboardButton(
                    context,
                    Icons.lock_open,
                    "Open Locker",
                    const LogsScreen(),
                  ),

                  Card(
                    elevation: 5,
                    child: InkWell(
                      onTap: () {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Notifications Coming Soon",
                            ),
                          ),
                        );
                      },
                      child: const Column(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications,
                            size: 40,
                          ),
                          SizedBox(height: 10),
                          Text(
                            "Notifications",
                          ),
                        ],
                      ),
                    ),
                  ),

                  Card(
                    elevation: 5,
                    child: InkWell(
                      onTap: () {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Settings Coming Soon",
                            ),
                          ),
                        );
                      },
                      child: const Column(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.settings,
                            size: 40,
                          ),
                          SizedBox(height: 10),
                          Text(
                            "Settings",
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),

      bottomNavigationBar:
          BottomNavigationBar(
        currentIndex:
            selectedIndex,
        onTap: (index) {

          setState(() {
            selectedIndex = index;
          });

          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const LogsScreen(),
              ),
            );
          }
        },
        items: const [

          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "Home",
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: "Logs",
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}