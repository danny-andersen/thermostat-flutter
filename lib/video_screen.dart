import 'dropbox-api.dart';
import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/material.dart';
// import 'package:chewie/chewie.dart';
// import 'package:video_player/video_player.dart';
import 'package:media_kit/media_kit.dart'; // Provides [Player], [Media], [Playlist] etc.
import 'package:media_kit_video/media_kit_video.dart'; // Provides [VideoController] & [Video] etc.
import 'package:path_provider/path_provider.dart';

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
  // late ChewieController chewieController;
  // late VideoPlayerController videoController;
  bool isLoadingImage = true;

  // Create a [Player] to control playback.
  late final player = Player();
  // Create a [VideoController] to handle video output from [Player].
  late final controller = VideoController(player);

  @override
  void initState() {
    getVideo(videoName, fileIndex);
    super.initState();
  }

  @override
  void dispose() {
    disposePlayer();
    super.dispose();
  }

  void disposePlayer() {
    player.dispose();
    //   videoController.dispose();
    //   chewieController.dispose();
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

  // void _initVideoPlayer(VideoPlayerController vc) async {
  //   /// Initialize the video player
  //   await vc.initialize();
  // }

  void showVideo(final String name, final Uint8List data, String path,
      final int index) async {
    if (mounted) {
      //Save bytes to temporary file
      Directory tempDir = await getTemporaryDirectory();
      String filePath = '${tempDir.path}/video_tmp.mp4';
      // print("Saving video of length ${data.length} to $filePath");
      File(filePath).writeAsBytes(data);
      player.open(Media(filePath));

      // final mime = (name.endsWith(".mp4")) ? "video/mp4" : "video/mpeg";
      // final dataUrl = Uri.dataFromBytes(data, mimeType: mime);
      // // videoController = VideoPlayerController.networkUrl(dataUrl);
      // _initVideoPlayer(videoController);
      // // _initVideoPlayer(videoController);
      // ChewieController chewie = ChewieController(
      //   videoPlayerController: videoController,
      //   autoPlay: false,
      //   allowFullScreen: true,
      //   fullScreenByDefault: false,
      //   showControls: true,
      //   showControlsOnInitialize: true,
      //   // aspectRatio: 5 / 8,
      //   // looping: true,
      //   // autoInitialize: true,
      // );

      // setState(() {
      //   // chewieController = chewie;
      //   videoName = name;
      //   fileIndex = index;
      //   isLoadingImage = false;
      // });
    }
  }

  @override
  Widget build(BuildContext context) {
    String filename = '';
    if (videoName.contains("/")) {
      List<String> parts = videoName.split('/');
      filename = parts[3];
    } else {
      filename = videoName;
    }
    String source = getSourceFromFilename(filename);
    String datetime = filename.split('-')[0];
    String date = datetime.split('T')[0];
    String time = datetime.split('T')[1];
    String title =
        "${fileIndex > -1 ? 'Video ${mediaList.length - fileIndex} of ${mediaList.length}' : ' '}Webcam: $source $date ${time.substring(0, 2)}:${time.substring(2, 4)}:${time.substring(4, 6)}";

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
        child: SizedBox(
          width: 720,
          height: 1280,
          // width: MediaQuery.of(context).size.width,
          // height: MediaQuery.of(context).size.width * 9.0 / 16.0,
          // Use [Video] widget to display video output.
          child: Video(controller: controller),
        ),
      ),
      //     Center(
      //   child: isLoadingImage
      //       ? const SizedBox(
      //           height: 10,
      //           width: 10,
      //         )
      //       : Chewie(controller: chewieController),
      // ),
    );
  }

//   getNext() {
//     int startIndex = fileIndex;
//     while (--fileIndex > 0) {
//       String fileName = mediaList[fileIndex].fileName;
//       if (fileName.endsWith(".mpeg") || fileName.endsWith(".mp4")) {
//         disposePlayer();
//         getVideo("$folderPath/$fileName", fileIndex);
//         break;
//       }
//     }
//     if (fileIndex < 0) {
//       fileIndex = startIndex;
//       setState(() {
//         isLoadingImage = false;
//       });
//     }
//   }

//   getPrevious() {
//     int startIndex = fileIndex;
//     while (++fileIndex < mediaList.length) {
//       String fileName = mediaList[fileIndex].fileName;
//       if (fileName.endsWith(".mpeg") || fileName.endsWith(".mp4")) {
//         disposePlayer();
//         getVideo("$folderPath/$fileName", fileIndex);
//         break;
//       }
//     }
//     if (fileIndex >= mediaList.length) {
//       fileIndex = startIndex;
//       setState(() {
//         isLoadingImage = false;
//       });
//     }
//   }
}

String getSourceFromFilename(String filename) {
  List<String> parts = filename.split('-');
  String source = "Unknown Webcam";
  if (parts[1].contains("hall")) {
    source = "Hall";
  } else if (parts[1].contains("cam0")) {
    source = "House right side";
  } else if (parts[1].contains("frontdoor")) {
    source = "Front door";
  } else if (parts[1].contains("house") && (parts[2] == 'lh')) {
    source = "House left side";
  } else if (parts[1].contains("conservatory")) {
    source = "Conservatory";
  } else if (parts[1].contains("backdoor")) {
    source = "Back Door";
  }

  return source;
}

String getFilenamefromSource(String source) {
  String filename = "unknown";
  if (source.contains("Hall")) {
    filename = "hall";
  } else if (source.contains("RH")) {
    filename = "cam0output";
  } else if (source.contains("Front")) {
    filename = "frontdoor";
  } else if (source.contains("LH")) {
    filename = "house-lh-side";
  } else if (source.contains("Conservatory")) {
    filename = "conservatory";
  } else if (source.contains("Back")) {
    filename = "backdoor";
  }
  return filename;
}
