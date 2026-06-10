import 'package:flutter/material.dart';

class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Access Logs"),
      ),
      body: const Center(
        child: Text(
          "Locker Access History",
          style: TextStyle(
            fontSize: 24,
          ),
        ),
      ),
    );
  }
}