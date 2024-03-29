import 'package:flutter/material.dart';
import 'dart:typed_data';

// import 'package:timeline_list/timeline.dart';
// import 'package:timeline_list/timeline_model.dart';

import 'dropbox-api.dart';
import 'image-screen.dart';
import 'video_screen.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key, required this.oauthToken});

  final String oauthToken;
  @override
  State createState() => CameraPageState(oauthToken: oauthToken);
}

class CameraPageState extends State<CameraPage> {
  CameraPageState({required this.oauthToken});

  final String oauthToken;
  int folderVisible = -1;
  bool isLoadingMediaList = false;
  int isLoadingImage = -1;
  String currentFolder = "";
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

  void getVideo(String fileName, int index) {
    if (mounted) {
      //   setState(() {
      //     isLoadingImage = -1;
      //   });

      Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoScreen(
              oauthToken: oauthToken,
              videoName:
                  "${mediaFolders[folderVisible].fullPathName}/$fileName",
              mediaList: mediaFiles,
              folderPath: mediaFolders[folderVisible].fullPathName,
              fileIndex: index,
            ),
          ));
    }
  }

  void getImage(String fileName, int index) {
    DropBoxAPIFn.getDropBoxFile(
        oauthToken: oauthToken,
        fileToDownload: "${mediaFolders[folderVisible].fullPathName}/$fileName",
        callback: showImage,
        contentType: ContentType.image,
        timeoutSecs: 600,
        folder: mediaFolders[folderVisible].fullPathName,
        fileIndex: index);
  }

  void showImage(final String filename, final Uint8List imageData, String path,
      int index) {
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
              imageData: imageData,
              mediaList: mediaFiles,
              folderPath: path,
              fileIndex: index,
            ),
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Row> fileRows = List.generate(mediaFiles.length, (index) {
      String fileName = mediaFiles[index].fileName;
      List<String> parts = fileName.split('-');
      String time = parts[0].split('T')[1];
      String source = getSourceFromFilename(fileName);
      String media = "Video";
      if (parts[1].contains("jpeg")) {
        media = "Photo";
      }

      String title =
          "${time.substring(0, 2)}:${time.substring(2, 4)}:${time.substring(4, 6)} -> $source $media";

      return Row(children: [
        Icon(mediaFiles[index].getIcon()),
        const SizedBox(
            width: 10), // Adds some spacing between the icon and text
        Column(children: [
          GestureDetector(
            onTap: () {
              // print("${mediaFolders[folderVisible].fullPathName}/$fileName");
              if (fileName.endsWith(".jpeg")) {
                getImage(fileName, index);
                setState(() {
                  isLoadingImage = index;
                });
              } else if (fileName.endsWith(".mpeg") ||
                  fileName.endsWith(".mp4")) {
                getVideo(fileName, index);
                setState(() {
                  isLoadingImage = index;
                });
              }
            },
            child: Text(
              title,
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
      String folderName = mediaFolders[index].fileName;
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
                currentFolder = folderName;
                getDateMedaList(folderName);
              } else {
                setState(() {
                  folderVisible = -1;
                });
              }
            },
            child: Text(
              folderName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Visibility(
              visible: index == folderVisible,
              child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: currentFolder == folderName
                      ? isLoadingMediaList
                          ? const CircularProgressIndicator()
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: fileRows)
                      : const SizedBox(width: 1))),
        ]),
      ]);
    });
    Widget returnWidget = ListView(children: folderRows);
    return returnWidget;
  }

  // Widget getTimeLine() {
  //   if (mediaFiles.isNotEmpty) {
  //     List<TimelineModel> timeLines =
  //         List.generate(mediaFiles.length, growable: false, (index) {
  //       String fileName = mediaFiles[index].fileName;
  //       return TimelineModel(
  //         Column(children: [
  //           GestureDetector(
  //             onTap: () {
  //               // print("${mediaFolders[folderVisible].fullPathName}/$fileName");
  //               if (fileName.endsWith(".jpeg")) {
  //                 getImage(fileName, index);
  //                 setState(() {
  //                   isLoadingImage = index;
  //                 });
  //               } else if (fileName.endsWith(".mpeg") ||
  //                   fileName.endsWith(".mp4")) {
  //                 getVideo(fileName, index);
  //                 setState(() {
  //                   isLoadingImage = index;
  //                 });
  //               }
  //             },
  //             child: Text(
  //               fileName,
  //               style: const TextStyle(
  //                 fontSize: 16,
  //                 fontWeight: FontWeight.bold,
  //               ),
  //             ),
  //           ),
  //         ]),
  //         position: index % 2 == 0
  //             ? TimelineItemPosition.right
  //             : TimelineItemPosition.left,
  //         icon: Icon(mediaFiles[index].getIcon()),
  //         isFirst: index == 0,
  //         isLast: index == mediaFiles.length - 1,
  //       );
  //     });
  //     return Timeline(children: timeLines, position: TimelinePosition.Center);
  //   } else {
  //     return Text("Please wait...");
  //   }
  // }
}
