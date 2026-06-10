import 'package:flutter/material.dart';

class ApprovalScreen extends StatelessWidget {
  const ApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Approval Requests"),
      ),
      body: const Center(
        child: Text(
          "Pending Requests",
          style: TextStyle(
            fontSize: 24,
          ),
        ),
      ),
    );
  }
}