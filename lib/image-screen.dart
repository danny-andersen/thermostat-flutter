import 'dart:typed_data';
import 'dropbox-api.dart';

import 'package:flutter/material.dart';

class ImageScreen extends StatefulWidget {
  final String imageName;
  final Uint8List imageData;
  final String oauthToken;

  ImageScreen(
      {required this.oauthToken,
      required this.imageName,
      required this.imageData});

  @override
  State createState() => ImageScreenState(
        oauthToken: this.oauthToken,
        imageName: this.imageName,
        imageData: this.imageData,
      );
}

class ImageScreenState extends State<ImageScreen> {
  ImageScreenState(
      {required this.oauthToken,
      required this.imageName,
      required this.imageData});

  final String oauthToken;
  String imageName;
  Uint8List imageData;

  void getImage(String fileName) {
    DropBoxAPIFn.getDropBoxFile(
        oauthToken: oauthToken,
        fileToDownload: fileName,
        callback: showImage,
        isText: false,
        timeoutSecs: 600);
  }

  void showImage(final String filename, final Uint8List data) {
    if (mounted) {
      setState(() {
        imageData = imageData;
        imageName = filename;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    List<String> parts = imageName.split('/');
    String date = parts[2];
    String source = "Webcam";
    if (parts[3].contains("pi")) {
      source = "PiCam";
    }
    String time = parts[3].split('-')[0].split('T')[1];
    String title =
        "Image    Source: $source Date: $date Time: ${time.substring(0, 2)}:${time.substring(2, 4)}:${time.substring(4, 6)}";

    return Scaffold(
        appBar: AppBar(
          title: Text(title),
        ),
        body: GestureDetector(
          onHorizontalDragEnd: (details) {
            // Check if swipe was left-to-right or right-to-left
            if (details.velocity.pixelsPerSecond.dx < 0) {
              // Left swipe - get next image
            }
          },
          child: Center(
            child: Image.memory(imageData),
          ),
        ));
  }
}
