import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dropbox-api.dart';
import 'image-screen.dart';

class CameraPage extends StatefulWidget {
  CameraPage({required this.oauthToken});

  final String oauthToken;
  @override
  State createState() => CameraPageState(oauthToken: this.oauthToken);
}

class CameraPageState extends State<CameraPage> {
  CameraPageState({required this.oauthToken});

  final String oauthToken;
  int folderVisible = -1;
  bool isLoadingMediaList = false;
  int isLoadingImage = -1;
  List<FileEntry> mediaFiles = List.filled(
      0, FileEntry("", "", DateTime.now(), 0, false),
      growable: true);
  List<FileEntry> mediaFolders = List.filled(
      0, FileEntry("", "", DateTime.now(), 0, true),
      growable: true);

  @override
  void initState() {
    getMotionFolderList();
    super.initState();
  }

  void getMotionFolderList() {
    DropBoxAPIFn.listFolder(
        oauthToken: oauthToken,
        folder: "/motion_images/",
        callback: processMediaFolderList,
        timeoutSecs: 600,
        maxResults: 100);
  }

  void getDateMedaList(String dayFolder) {
    DropBoxAPIFn.listFolder(
        oauthToken: oauthToken,
        folder: "/motion_images/$dayFolder",
        callback: processMediaFileList,
        timeoutSecs: 60,
        maxResults: 31);
  }

  void processMediaFileList(FileListing files) {
    mediaFiles = files.fileEntries;
    if (mounted) {
      setState(() {
        isLoadingMediaList = false;
      });
    }
  }

  void processMediaFolderList(FileListing files) {
    mediaFolders = files.fileEntries;
    if (mounted) {
      setState(() {});
    }
  }

  void getImage(String fileName) {
    DropBoxAPIFn.getDropBoxFile(
        oauthToken: oauthToken,
        fileToDownload: fileName,
        callback: showImage,
        isText: false,
        timeoutSecs: 600);
  }

  void showImage(final String filename, final Uint8List imageData) {
    if (mounted) {
      setState(() {
        isLoadingImage = -1;
      });
      Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ImageScreen(
                oauthToken: oauthToken,
                imageName: filename,
                imageData: imageData),
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Row> fileRows = List.generate(mediaFiles.length, (index) {
      String fileName = mediaFiles[index].fileName;
      return Row(children: [
        Icon(mediaFiles[index].getIcon()),
        const SizedBox(
            width: 10), // Adds some spacing between the icon and text
        Column(children: [
          GestureDetector(
            onTap: () {
              print("${mediaFolders[folderVisible].fullPathName}/$fileName");
              if (fileName.endsWith(".jpeg")) {
                getImage(
                    "${mediaFolders[folderVisible].fullPathName}/$fileName");
                setState(() {
                  isLoadingImage = index;
                });
              } else {}
            },
            child: Text(
              fileName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ]),
        Visibility(
            visible: index == isLoadingImage,
            child: const CircularProgressIndicator()),
      ]);
    });
    List<Row> folderRows = List.generate(mediaFolders.length, (index) {
      String fileName = mediaFolders[index].fileName;
      return Row(children: [
        const Icon(Icons.folder),
        const SizedBox(
            width: 10), // Adds some spacing between the icon and text
        Column(children: [
          GestureDetector(
            onTap: () {
              if (folderVisible != index) {
                setState(() {
                  isLoadingMediaList = true;
                  folderVisible = index;
                });
                getDateMedaList(fileName);
              } else {
                setState(() {
                  folderVisible = -1;
                });
              }
            },
            child: Text(
              fileName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Visibility(
            visible: index == folderVisible,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: isLoadingMediaList
                  ? const CircularProgressIndicator()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: fileRows),
            ),
          ),
        ]),
      ]);
    });
    Widget returnWidget = ListView(children: folderRows);
    return returnWidget;
  }
}
