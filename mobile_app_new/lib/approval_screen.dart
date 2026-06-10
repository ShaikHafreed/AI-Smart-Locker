import 'dart:async';
import 'package:flutter/material.dart';
import 'api_service.dart';

class ApprovalScreen extends StatefulWidget {
  const ApprovalScreen({super.key});

  @override
  State<ApprovalScreen> createState() =>
      _ApprovalScreenState();
}

class _ApprovalScreenState
    extends State<ApprovalScreen> {

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
        await ApiService.getPendingAccess();

    setState(() {
      data = result;
    });
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
          "Access Approval",
        ),
      ),
      body: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          children: [

            Text(
              "Status: ${data!["status"]}",
              style:
                  const TextStyle(
                fontSize: 20,
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
              "Time: ${data!["time"]}",
            ),

            const SizedBox(
              height: 20,
            ),

            if (data!["image"] != "")
              Expanded(
                child: Image.network(
                  data!["image"],
                  fit: BoxFit.contain,
                ),
              ),

            const SizedBox(
              height: 20,
            ),

            Row(
              children: [

                Expanded(
                  child:
                      ElevatedButton(
                    onPressed:
                        () async {

                      await ApiService
                          .approveAccess();

                      ScaffoldMessenger.of(
                              context)
                          .showSnackBar(
                        const SnackBar(
                          content: Text(
                            "ACCESS APPROVED",
                          ),
                        ),
                      );

                      loadData();
                    },
                    child: const Text(
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
                        () async {

                      await ApiService
                          .rejectAccess();

                      ScaffoldMessenger.of(
                              context)
                          .showSnackBar(
                        const SnackBar(
                          content: Text(
                            "ACCESS REJECTED",
                          ),
                        ),
                      );

                      loadData();
                    },
                    child: const Text(
                      "REJECT",
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}