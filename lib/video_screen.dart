import 'dropbox-api.dart';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';

class VideoScreen extends StatefulWidget {
  final String videoName;
  final ChewieController chewieController;
  final String oauthToken;
  final List<FileEntry> mediaList;
  final String folderPath;
  final int fileIndex;

  VideoScreen(
      {required this.oauthToken,
      required this.videoName,
      required this.chewieController,
      required this.mediaList,
      required this.folderPath,
      required this.fileIndex});

  @override
  State createState() => VideoScreenState(
      oauthToken: this.oauthToken,
      videoName: this.videoName,
      chewieController: this.chewieController,
      mediaList: this.mediaList,
      folderPath: this.folderPath,
      fileIndex: this.fileIndex);
}

class VideoScreenState extends State<VideoScreen> {
  VideoScreenState(
      {required this.oauthToken,
      required this.videoName,
      required this.chewieController,
      required this.mediaList,
      required this.folderPath,
      required this.fileIndex});

  final String oauthToken;
  String videoName;
  final List<FileEntry> mediaList;
  final String folderPath;
  int fileIndex;
  ChewieController chewieController;

  @override
  void initState() {
    super.initState();
  }

  void getVideo(String fileName, int index) {
    DropBoxAPIFn.getDropBoxFile(
        oauthToken: oauthToken,
        fileToDownload: "$folderPath/$fileName",
        callback: showVideo,
        contentType: ContentType.video,
        timeoutSecs: 0,
        folder: folderPath,
        fileIndex: index);
  }

  void _initVideoPlayer(VideoPlayerController vc) async {
    /// Initialize the video player
    await vc.initialize();
  }

  void showVideo(
      final String name, final Uint8List data, String path, final int index) {
    if (mounted) {
      final mime = (name.endsWith(".mp4")) ? "video/mp4" : "video/mpeg";
      final dataUrl = Uri.dataFromBytes(data, mimeType: mime).toString();
      final VideoPlayerController videoController =
          VideoPlayerController.network(dataUrl);
      _initVideoPlayer(videoController);
      ChewieController chewie = ChewieController(
        videoPlayerController: videoController,
        autoPlay: true,
        looping: true,
      );
      setState(() {
        chewieController = chewie;
        videoName = name;
        fileIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    List<String> parts = videoName.split('/');
    String date = parts[2];
    String source = "Webcam";
    if (parts[3].contains("pi")) {
      source = "PiCam";
    }
    String time = parts[3].split('-')[0].split('T')[1];
    String title =
        "$source Video $date ${time.substring(0, 2)}:${time.substring(2, 4)}:${time.substring(4, 6)}";
    // "Video    Source: $source Date: $date Time: ${time.substring(0, 2)}:${time.substring(2, 4)}:${time.substring(4, 6)}";

    return Scaffold(
        appBar: AppBar(
          title: Text(
            title,
            style: TextStyle(
              fontSize: 18,
            ),
          ),
        ),
        body: GestureDetector(
          onHorizontalDragEnd: (details) {
            // Check if swipe was left-to-right or right-to-left
            if (details.velocity.pixelsPerSecond.dx < 0) {
              // Left swipe - get next image
              while (++fileIndex < mediaList.length) {
                String fileName = mediaList[fileIndex].fileName;
                if (fileName.endsWith(".mpeg") || fileName.endsWith(".mp4")) {
                  getVideo(fileName, fileIndex);
                  // setState(() {
                  //   isLoadingImage = index;
                  // });
                  break;
                }
              }
              if (fileIndex >= mediaList.length) {
                fileIndex = mediaList.length - 1;
              }
            } else {
              while (--fileIndex > 0) {
                String fileName = mediaList[fileIndex].fileName;
                if (fileName.endsWith(".mpeg") || fileName.endsWith(".mp4")) {
                  getVideo(fileName, fileIndex);
                  // setState(() {
                  //   isLoadingImage = index;
                  // });
                  break;
                }
              }
              if (fileIndex < 0) fileIndex = 0;
            }
          },
          child: Center(
            child: Chewie(controller: chewieController),
          ),
        ));
  }
}
