import 'dart:async';
import 'package:flutter/material.dart';
import '../api_service.dart';

class ApprovalRequestScreen extends StatefulWidget {
  const ApprovalRequestScreen({super.key});

  @override
  State<ApprovalRequestScreen> createState() =>
      _ApprovalRequestScreenState();
}

class _ApprovalRequestScreenState
    extends State<ApprovalRequestScreen> {

  Map<String, dynamic>? data;

  Timer? timer;

  @override
  void initState() {
    super.initState();

    loadData();

    timer = Timer.periodic(
      const Duration(seconds: 3),
      (_) {
        loadData();
      },
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> loadData() async {
    try {

      final result =
          await ApiService.getPendingAccess();

      setState(() {
        data = result;
      });

    } catch (e) {
      print(e);
    }
  }

  Future<void> approve() async {

    await ApiService.approveAccess();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          "Access Approved",
        ),
      ),
    );

    loadData();
  }

  Future<void> reject() async {

    await ApiService.rejectAccess();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          "Access Rejected",
        ),
      ),
    );

    loadData();
  }

  @override
  Widget build(BuildContext context) {

    if (data == null) {

      return const Scaffold(
        body: Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Approval Requests",
        ),
      ),

      body: SingleChildScrollView(
        child: Padding(
          padding:
              const EdgeInsets.all(16),

          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [

              Card(
                elevation: 5,
                child: Padding(
                  padding:
                      const EdgeInsets.all(16),

                  child: Column(
                    children: [

                      Text(
                        "Status: ${data!["status"]}",
                        style:
                            const TextStyle(
                          fontSize: 22,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(
                        height: 10,
                      ),

                      Text(
                        "Result: ${data!["result"]}",
                        style:
                            const TextStyle(
                          fontSize: 18,
                        ),
                      ),

                      const SizedBox(
                        height: 10,
                      ),

                      Text(
                        "Similarity: ${data!["similarity"]}%",
                        style:
                            const TextStyle(
                          fontSize: 18,
                        ),
                      ),

                      const SizedBox(
                        height: 10,
                      ),

                      Text(
                        data!["time"] ?? "",
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(
                height: 20,
              ),

              if (data!["image"] != null &&
                  data!["image"] != "")

                Image.network(
                  data!["image"],
                  height: 300,
                  fit: BoxFit.cover,
                ),

              const SizedBox(
                height: 20,
              ),

              if (data!["status"] ==
                  "Pending Approval")

                Row(
                  children: [

                    Expanded(
                      child:
                          ElevatedButton(
                        onPressed:
                            approve,
                        style:
                            ElevatedButton.styleFrom(
                          backgroundColor:
                              Colors.green,
                        ),
                        child:
                            const Text(
                          "APPROVE",
                        ),
                      ),
                    ),

                    const SizedBox(
                      width: 10,
                    ),

                    Expanded(
                      child:
                          ElevatedButton(
                        onPressed:
                            reject,
                        style:
                            ElevatedButton.styleFrom(
                          backgroundColor:
                              Colors.red,
                        ),
                        child:
                            const Text(
                          "REJECT",
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}