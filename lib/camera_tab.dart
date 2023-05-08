import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import 'dart:typed_data';

import 'dropbox-api.dart';
import 'image-screen.dart';
import 'video_screen.dart';

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

  void getVideo(String fileName, int index) {
    DropBoxAPIFn.getDropBoxFile(
        oauthToken: oauthToken,
        fileToDownload: "${mediaFolders[folderVisible].fullPathName}/$fileName",
        callback: showVideo,
        contentType: ContentType.video,
        timeoutSecs: 0,
        folder: mediaFolders[folderVisible].fullPathName,
        fileIndex: index);
  }

  void _initVideoPlayer(VideoPlayerController vc) async {
    /// Initialize the video player
    await vc.initialize();
  }

  void showVideo(final String filename, final Uint8List videoData, String path,
      int index) {
    if (mounted) {
      final dataUrl = Uri.dataFromBytes(videoData).toString();
      final VideoPlayerController videoController =
          VideoPlayerController.network(dataUrl);
      _initVideoPlayer(videoController);
      ChewieController chewie = ChewieController(
        videoPlayerController: videoController,
        autoPlay: true,
        looping: true,
      );
      setState(() {
        isLoadingImage = -1;
      });

      Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoScreen(
              oauthToken: oauthToken,
              videoName: filename,
              chewieController: chewie,
              mediaList: mediaFiles,
              folderPath: path,
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
      return Row(children: [
        Icon(mediaFiles[index].getIcon()),
        const SizedBox(
            width: 10), // Adds some spacing between the icon and text
        Column(children: [
          GestureDetector(
            onTap: () {
              print("${mediaFolders[folderVisible].fullPathName}/$fileName");
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
