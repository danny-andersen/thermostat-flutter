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
  bool isLoadingImage = false;

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
        isLoadingImage = false;
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
        "Image ${mediaList.length - fileIndex} of ${mediaList.length} $source $date ${time.substring(0, 2)}:${time.substring(2, 4)}:${time.substring(4, 6)}";
    // "Image    Source: $source Date: $date Time: ${time.substring(0, 2)}:${time.substring(2, 4)}:${time.substring(4, 6)}";

    return Scaffold(
        appBar: AppBar(
          title: Center(
              child: Text(
            title,
            style: const TextStyle(
              fontSize: 12,
            ),
          )),
        ),
        body: Center(
            child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Visibility(
                    visible: fileIndex == mediaList.length - 1,
                    child: const Text("First image",
                        style: TextStyle(
                            color: Colors.blue,
                            fontSize: 16,
                            fontWeight: FontWeight.bold))),
                const SizedBox(width: 20),
                ElevatedButton(
                  child: const Text('<<'),
                  onPressed: () {
                    setState(() {
                      isLoadingImage = true;
                    });
                    getPrevious();
                  },
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                    child: const Text('>>'),
                    onPressed: () {
                      setState(() {
                        isLoadingImage = true;
                      });
                      getNext();
                    }),
                const SizedBox(width: 20),
                Visibility(
                    visible: fileIndex == 0,
                    child: const Text("Last image",
                        style: TextStyle(
                            color: Colors.blue,
                            fontSize: 16,
                            fontWeight: FontWeight.bold))),
                const SizedBox(width: 20),
                Visibility(
                    visible: isLoadingImage,
                    child: const CircularProgressIndicator()),
              ],
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onHorizontalDragEnd: (details) {
                // Check if swipe was left-to-right or right-to-left
                if (details.velocity.pixelsPerSecond.dx < 0) {
                  // Left swipe - get next image (which is earlier)
                  setState(() {
                    isLoadingImage = true;
                  });
                  getNext();
                } else {
                  setState(() {
                    isLoadingImage = true;
                  });
                  getPrevious();
                }
              },
              child: Center(
                child: Image.memory(imageData),
              ),
            )
          ],
        )));
  }

  getNext() {
    while (--fileIndex >= 0) {
      String fileName = mediaList[fileIndex].fileName;
      // print("Index: $fileIndex, File: $fileName");
      if (fileName.endsWith(".jpeg")) {
        getImage(fileName, fileIndex);
        break;
        // setState(() {
        //   isLoadingImage = index;
        // });
      }
    }
    if (fileIndex < 0) {
      fileIndex = 0;
      isLoadingImage = false;
    }
  }

  getPrevious() {
    while (++fileIndex < mediaList.length) {
      String fileName = mediaList[fileIndex].fileName;
      // print("Index: $fileIndex, File: $fileName");
      if (fileName.endsWith(".jpeg")) {
        getImage(fileName, fileIndex);
        break;
        // setState(() {
        //   isLoadingImage = index;
        // });
      }
    }
    if (fileIndex >= mediaList.length) {
      fileIndex = mediaList.length - 1;
      isLoadingImage = false;
    }
  }
}
