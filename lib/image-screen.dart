import 'dart:typed_data';
import 'dropbox-api.dart';

import 'package:flutter/material.dart';

class ImageScreen extends StatefulWidget {
  final String imageName;
  final Uint8List imageData;
  final String oauthToken;
  final List<FileEntry> mediaList;
  final String folderPath;
  final int fileIndex;

  ImageScreen(
      {required this.oauthToken,
      required this.imageName,
      required this.imageData,
      required this.mediaList,
      required this.folderPath,
      required this.fileIndex});

  @override
  State createState() => ImageScreenState(
      oauthToken: this.oauthToken,
      imageName: this.imageName,
      imageData: this.imageData,
      mediaList: this.mediaList,
      folderPath: this.folderPath,
      fileIndex: this.fileIndex);
}

class ImageScreenState extends State<ImageScreen> {
  ImageScreenState(
      {required this.oauthToken,
      required this.imageName,
      required this.imageData,
      required this.mediaList,
      required this.folderPath,
      required this.fileIndex});

  final String oauthToken;
  String imageName;
  Uint8List imageData;
  final List<FileEntry> mediaList;
  final String folderPath;
  int fileIndex;

  void getImage(String fileName, int index) {
    DropBoxAPIFn.getDropBoxFile(
        oauthToken: oauthToken,
        fileToDownload: "$folderPath/$fileName",
        callback: showImage,
        contentType: ContentType.image,
        timeoutSecs: 600,
        folder: folderPath,
        fileIndex: index);
  }

  void showImage(
      final String name, final Uint8List data, String path, final int index) {
    if (mounted) {
      setState(() {
        imageData = data;
        imageName = name;
        fileIndex = index;
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
              while (++fileIndex < mediaList.length) {
                String fileName = mediaList[fileIndex].fileName;
                print("Index: $fileIndex, File: $fileName");
                if (fileName.endsWith(".jpeg")) {
                  getImage(fileName, fileIndex);
                  break;
                  // setState(() {
                  //   isLoadingImage = index;
                  // });
                } else {}
              }
              if (fileIndex >= mediaList.length) {
                fileIndex = mediaList.length - 1;
              }
            } else {
              while (--fileIndex > 0) {
                String fileName = mediaList[fileIndex].fileName;
                print("Index: $fileIndex, File: $fileName");
                if (fileName.endsWith(".jpeg")) {
                  getImage(fileName, fileIndex);
                  break;
                  // setState(() {
                  //   isLoadingImage = index;
                  // });
                } else {}
              }
              if (fileIndex < 0) fileIndex = 0;
            }
          },
          child: Center(
            child: Image.memory(imageData),
          ),
        ));
  }
}
