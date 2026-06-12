import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import 'approval_request_screen.dart';

class VerifyFaceScreen extends StatefulWidget {
  const VerifyFaceScreen({super.key});

  @override
  State<VerifyFaceScreen> createState() =>
      _VerifyFaceScreenState();
}

class _VerifyFaceScreenState
    extends State<VerifyFaceScreen> {

  File? visitorImage;

  String verificationResult = "";

  bool isLoading = false;

  Future<void> captureVisitorFace() async {

    final picker = ImagePicker();

    final XFile? image =
        await picker.pickImage(
      source: ImageSource.camera,
    );

    if (image != null) {

      setState(() {

        visitorImage = File(
          image.path,
        );

        verificationResult = "";
      });
    }
  }

  Future<void> verifyFace() async {

    if (visitorImage == null) {

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            "Capture face first",
          ),
        ),
      );

      return;
    }

    setState(() {
      isLoading = true;
    });

    try {

      var request =
          http.MultipartRequest(
        "POST",
        Uri.parse(
          "http://192.168.31.229:5000/verify",
        ),
      );

      request.files.add(
        await http.MultipartFile
            .fromPath(
          "image",
          visitorImage!.path,
        ),
      );

      var response =
          await request.send();

      var responseData =
          await response.stream
              .bytesToString();

      print(responseData);

      var jsonData =
          jsonDecode(responseData);

      if (jsonData["success"] == false) {

        setState(() {

          verificationResult =
              jsonData["message"] ??
                  "Verification Failed";

          isLoading = false;
        });

        return;
      }

      String resultText =
          jsonData["message"];

      if (jsonData["similarity"] !=
          null) {

        resultText +=
            "\nSimilarity: ${jsonData["similarity"]}%";
      }

      setState(() {

        verificationResult =
            resultText;

        isLoading = false;
      });

      // =====================
      // INTRUDER DETECTED
      // =====================

      if (jsonData["verified"] ==
          false) {

        showDialog(
          context: context,
          barrierDismissible:
              false,
          builder: (_) =>
              AlertDialog(
            title: const Text(
              "🚨 Intruder Detected",
            ),
            content: Text(
              "Similarity: ${jsonData["similarity"]}%\n\nApproval Required.",
            ),
            actions: [

              TextButton(
                onPressed: () {

                  Navigator.pop(
                      context);

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const ApprovalRequestScreen(),
                    ),
                  );
                },
                child: const Text(
                  "Open Approval",
                ),
              ),
            ],
          ),
        );
      }

    } catch (e) {

      setState(() {

        verificationResult =
            "Connection Error\n$e";

        isLoading = false;
      });
    }
  }

  @override
  Widget build(
      BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title:
            const Text(
          "Verify Face",
        ),
      ),

      body: SingleChildScrollView(

        child: Padding(
          padding:
              const EdgeInsets.all(
                  20),

          child: Column(

            children: [

              const SizedBox(
                height: 20,
              ),

              visitorImage == null

                  ? const Icon(
                      Icons.face,
                      size: 180,
                    )

                  : Image.file(
                      visitorImage!,
                      height: 350,
                    ),

              const SizedBox(
                height: 30,
              ),

              ElevatedButton.icon(
                onPressed:
                    captureVisitorFace,
                icon:
                    const Icon(
                  Icons.camera,
                ),
                label: const Text(
                  "Capture Visitor Face",
                ),
              ),

              const SizedBox(
                height: 20,
              ),

              ElevatedButton.icon(
                onPressed:
                    verifyFace,
                icon:
                    const Icon(
                  Icons.verified,
                ),
                label: const Text(
                  "Verify Face",
                ),
              ),

              const SizedBox(
                height: 30,
              ),

              if (isLoading)
                const CircularProgressIndicator(),

              const SizedBox(
                height: 20,
              ),

              Text(
                verificationResult,
                textAlign:
                    TextAlign.center,
                style:
                    const TextStyle(
                  fontSize: 22,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}