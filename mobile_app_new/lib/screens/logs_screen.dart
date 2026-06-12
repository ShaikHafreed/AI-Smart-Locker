import 'dart:async';

import 'package:flutter/material.dart';
import '../api_service.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() =>
      _LogsScreenState();
}

class _LogsScreenState
    extends State<LogsScreen> {

  List<dynamic> logs = [];

  bool isLoading = true;

  Timer? timer;

  @override
  void initState() {
    super.initState();

    loadLogs();

    timer = Timer.periodic(
      const Duration(seconds: 5),
      (_) {
        loadLogs();
      },
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> loadLogs() async {

    try {

      final result =
          await ApiService.getLogs();

      setState(() {

        logs = result.reversed.toList();

        isLoading = false;
      });

    } catch (e) {

      print(e);

      setState(() {
        isLoading = false;
      });
    }
  }

  IconData getIcon(String result) {

    if (result.contains("Owner")) {
      return Icons.verified_user;
    }

    if (result.contains("Intruder")) {
      return Icons.warning;
    }

    if (result.contains("Approved")) {
      return Icons.check_circle;
    }

    if (result.contains("Rejected")) {
      return Icons.cancel;
    }

    return Icons.history;
  }

  Color getColor(String result) {

    if (result.contains("Owner")) {
      return Colors.green;
    }

    if (result.contains("Intruder")) {
      return Colors.red;
    }

    if (result.contains("Approved")) {
      return Colors.blue;
    }

    if (result.contains("Rejected")) {
      return Colors.orange;
    }

    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text(
          "Access Logs",
        ),
      ),

      body: isLoading

          ? const Center(
              child:
                  CircularProgressIndicator(),
            )

          : logs.isEmpty

              ? const Center(
                  child: Text(
                    "No Logs Available",
                    style: TextStyle(
                      fontSize: 20,
                    ),
                  ),
                )

              : RefreshIndicator(

                  onRefresh: loadLogs,

                  child: ListView.builder(

                    itemCount: logs.length,

                    itemBuilder:
                        (context, index) {

                      final log =
                          logs[index];

                      return Card(

                        margin:
                            const EdgeInsets.all(
                          10,
                        ),

                        elevation: 5,

                        child: ListTile(

                          leading: CircleAvatar(

                            backgroundColor:
                                getColor(
                              log["result"]
                                  .toString(),
                            ),

                            child: Icon(
                              getIcon(
                                log["result"]
                                    .toString(),
                              ),
                              color:
                                  Colors.white,
                            ),
                          ),

                          title: Text(
                            log["result"]
                                .toString(),
                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),

                          subtitle: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [

                              const SizedBox(
                                height: 5,
                              ),

                              Text(
                                log["time"]
                                    .toString(),
                              ),

                              if (log[
                                      "similarity"] !=
                                  null)

                                Text(
                                  "Similarity: ${log["similarity"]}%",
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}