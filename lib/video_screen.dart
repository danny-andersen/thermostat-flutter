import 'dropbox-api.dart';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';

class VideoScreen extends StatefulWidget {
  final String videoName;
  final String oauthToken;
  final List<FileEntry> mediaList;
  final String folderPath;
  final int fileIndex;

  const VideoScreen(
      {super.key,
      required this.oauthToken,
      required this.videoName,
      required this.mediaList,
      required this.folderPath,
      required this.fileIndex});

  @override
  State createState() => VideoScreenState(
      oauthToken: oauthToken,
      videoName: videoName,
      mediaList: mediaList,
      folderPath: folderPath,
      fileIndex: fileIndex);
}

class VideoScreenState extends State<VideoScreen> {
  VideoScreenState(
      {required this.oauthToken,
      required this.videoName,
      required this.mediaList,
      required this.folderPath,
      required this.fileIndex});

  final String oauthToken;
  String videoName;
  final List<FileEntry> mediaList;
  final String folderPath;
  int fileIndex;
  late ChewieController chewieController;
  late VideoPlayerController videoController;
  bool isLoadingImage = true;

  @override
  void initState() {
    getVideo(videoName, fileIndex);
    super.initState();
  }

  void disposePlayer() {
    videoController.dispose();
    chewieController.dispose();
  }

  void getVideo(String fileName, int index) {
    DropBoxAPIFn.getDropBoxFile(
        oauthToken: oauthToken,
        fileToDownload: fileName,
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
      videoController = VideoPlayerController.network(dataUrl);
      // _initVideoPlayer(videoController);
      ChewieController chewie = ChewieController(
        videoPlayerController: videoController,
        autoPlay: false,
        allowFullScreen: true,
        fullScreenByDefault: false,
        showControls: true,
        showControlsOnInitialize: true,
        // aspectRatio: 5 / 8,
        // looping: true,
        // autoInitialize: true,
      );
      setState(() {
        chewieController = chewie;
        videoName = name;
        fileIndex = index;
        isLoadingImage = false;
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
        "Video ${mediaList.length - fileIndex} of ${mediaList.length} $source $date ${time.substring(0, 2)}:${time.substring(2, 4)}:${time.substring(4, 6)}";

    return Scaffold(
        appBar: AppBar(
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 12,
            ),
          ),
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
                    child: const Text("At First",
                        style: TextStyle(
                            color: Colors.blue,
                            fontSize: 12,
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
                const SizedBox(width: 10),
                ElevatedButton(
                    child: const Text('>>'),
                    onPressed: () {
                      setState(() {
                        isLoadingImage = true;
                      });
                      getNext();
                    }),
                const SizedBox(width: 10),
                Visibility(
                    visible: fileIndex == 0,
                    child: const Text("At Last",
                        style: TextStyle(
                            color: Colors.blue,
                            fontSize: 12,
                            fontWeight: FontWeight.bold))),
                const SizedBox(width: 10),
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
              child: isLoadingImage
                  ? const SizedBox(
                      height: 10,
                      width: 10,
                    )
                  : Chewie(controller: chewieController),
            ),
            const SizedBox(height: 10),
          ],
        )));
  }

  getNext() {
    int startIndex = fileIndex;
    while (--fileIndex > 0) {
      String fileName = mediaList[fileIndex].fileName;
      if (fileName.endsWith(".mpeg") || fileName.endsWith(".mp4")) {
        disposePlayer();
        getVideo("$folderPath/$fileName", fileIndex);
        break;
      }
    }
    if (fileIndex < 0) {
      fileIndex = startIndex;
      setState(() {
        isLoadingImage = false;
      });
    }
  }

  getPrevious() {
    int startIndex = fileIndex;
    while (++fileIndex < mediaList.length) {
      String fileName = mediaList[fileIndex].fileName;
      if (fileName.endsWith(".mpeg") || fileName.endsWith(".mp4")) {
        disposePlayer();
        getVideo("$folderPath/$fileName", fileIndex);
        break;
      }
    }
    if (fileIndex >= mediaList.length) {
      fileIndex = startIndex;
      setState(() {
        isLoadingImage = false;
      });
    }
  }
}
