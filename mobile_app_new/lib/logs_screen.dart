import 'package:flutter/material.dart';
import 'api_service.dart';

class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Access History",
        ),
      ),
      body: FutureBuilder(
        future: ApiService.getLogs(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          List logs =
              snapshot.data as List;

          if (logs.isEmpty) {
            return const Center(
              child: Text(
                "No Access Logs",
              ),
            );
          }

          return ListView.builder(
            itemCount: logs.length,
            itemBuilder:
                (context, index) {
              return Card(
                margin:
                    const EdgeInsets.all(10),
                child: ListTile(
                  leading: Icon(
                    logs[index]["result"] ==
                            "OWNER"
                        ? Icons.verified_user
                        : Icons.warning,
                    color:
                        logs[index]["result"] ==
                                "OWNER"
                            ? Colors.green
                            : Colors.red,
                  ),
                  title: Text(
                    logs[index]["result"],
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    logs[index]["time"],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}