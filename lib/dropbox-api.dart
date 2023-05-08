import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:convert';

enum ContentType { text, image, video }

class ContentCache {
  final Map<String, _CacheEntry<Uint8List>> _cache = {};

  Uint8List get(String key) {
    final entry = _cache[key];
    if (entry != null && !entry.isExpired()) {
      return entry.value;
    } else {
      return Uint8List(0);
    }
  }

  void set(String key, Uint8List value, int duration) {
    if (duration != 0) {
      //Only cache if needed
      _cache[key] = _CacheEntry(value, Duration(seconds: duration));
    }
  }

  void remove(String key) {
    _cache.remove(key);
  }

  void clear() {
    _cache.clear();
  }
}

class _CacheEntry<T> {
  T value;
  final DateTime createdAt;
  Duration duration;

  _CacheEntry(this.value, this.duration) : createdAt = DateTime.now();

  bool isExpired() {
    final now = DateTime.now();
    final elapsed = now.difference(createdAt);
    return elapsed >= duration;
  }
}

class FileEntry {
  final String fileName;
  final String fullPathName;
  final DateTime lastModified;
  final int size;
  final bool isFolder;

  FileEntry(this.fileName, this.fullPathName, this.lastModified, this.size,
      this.isFolder);

  IconData getIcon() {
    IconData returnIcon = Icons.file_download;
    if (isFolder) returnIcon = Icons.folder;
    if (fileName.contains("jpeg")) returnIcon = Icons.photo;
    if (fileName.contains("mpeg")) returnIcon = Icons.video_file;
    if (fileName.contains("mp4")) returnIcon = Icons.video_file;
    return returnIcon;
  }

  Map<String, dynamic> toJson() {
    return {
      'name': fileName,
      'path_display': fullPathName,
      'server_modified': lastModified.toString(),
      '.tag': isFolder ? 'folder' : 'file',
      'size': size
    };
  }

  factory FileEntry.fromJson(Map<String, dynamic> json) {
    String fn = json['name'];
    String path = json['path_display'];
    DateTime modified = DateTime.now();
    if (json.containsKey('server_modified')) {
      modified = DateTime.parse(json['server_modified']);
    }
    bool isFolder = false;
    if (json['.tag'] == 'folder') {
      isFolder = true;
    }
    int size = 0;
    if (json.containsKey("size")) {
      size = json['size'];
    }
    return FileEntry(fn, path, modified, size, isFolder);
  }
}

class FileMatch {
  final FileEntry fileEntry;

  FileMatch(this.fileEntry);

  factory FileMatch.fromJson(Map<String, dynamic> json) =>
      FileMatch(FileEntry.fromJson(json));
}

class FileListing {
  final List<FileEntry> fileEntries;
  final bool isFolderListing;
  FileListing(this.fileEntries, this.isFolderListing);

  factory FileListing.fromJson(Map<String, dynamic> json) {
    List<FileEntry> entries = List.filled(
        0, FileEntry("", "", DateTime.now(), 0, false),
        growable: true);
    bool isFolderList = false;
    if (json.containsKey('matches')) {
      var list = json['matches'] as List;
      List<FileMatch> matches = list
          .map((js) => FileMatch.fromJson(js['metadata']['metadata']))
          .toList();
      entries = matches.map((match) => match.fileEntry).toList();
    } else if (json.containsKey('entries')) {
      isFolderList = true;
      List list = json['entries'];
      entries = list.map((js) => FileEntry.fromJson(js)).toList();
    }
    entries.sort((a, b) => b.fileName.compareTo(a.fileName));
    return FileListing(entries, isFolderList);
  }

  Map<String, dynamic> toJson() {
    return {
      isFolderListing ? 'entries' : 'matches':
          fileEntries.map((entry) => entry.toJson()).toList()
    };
  }
}

class DropBoxAPIFn {
  static ContentCache cache = ContentCache();
  static String globalOauthToken = "BLANK";

  static void getDropBoxFile({
    required String oauthToken,
    required String fileToDownload,
    required Function callback,
    required int timeoutSecs,
    required ContentType contentType,
    String folder = "",
    int fileIndex = -1,
  }) {
    if (oauthToken == "BLANK") {
      oauthToken = globalOauthToken;
      if (oauthToken == "BLANK") {
        return;
      }
    }
    Uint8List cacheEntry = cache.get(fileToDownload);
    if (cacheEntry.isNotEmpty) {
      if (contentType == ContentType.text) {
        //Expecting text result
        callback(String.fromCharCodes(cacheEntry));
      } else {
        callback(fileToDownload, cacheEntry, folder, fileIndex);
      }
      return;
    }
    HttpClient client = HttpClient();
    final Uri downloadUri =
        Uri.parse("https://content.dropboxapi.com/2/files/download");

    try {
      client.getUrl(downloadUri).then((HttpClientRequest request) {
        request.headers.add("Authorization", "Bearer $oauthToken");
        request.headers
            .add("Dropbox-API-Arg", "{\"path\": \"$fileToDownload\"}");
        return request.close();
      }).then((HttpClientResponse response) async {
        if (contentType == ContentType.text) {
          String contents = await response.transform(utf8.decoder).join();
          final List<int> codeUnits = contents.codeUnits;
          final Uint8List bytes = Uint8List.fromList(codeUnits);
          cache.set(fileToDownload, bytes, timeoutSecs);
          callback(contents);
        } else {
          Uint8List contents =
              await consolidateHttpClientResponseBytes(response);
          if (contentType == ContentType.image) {
            //Only cache images, not videos
            cache.set(fileToDownload, contents, timeoutSecs);
          }
          callback(fileToDownload, contents, folder, fileIndex);
        }
      });
    } on HttpException catch (he) {
      print("Got HttpException downloading file: ${he.toString()}");
    }
  }

  static void sendDropBoxFile({
    required String oauthToken,
    required String fileToUpload,
    required String contents,
    Function? callback,
    String? callbackMsg,
  }) {
    HttpClient client = HttpClient();
    final Uri uploadUri =
        Uri.parse("https://content.dropboxapi.com/2/files/upload");

    try {
      client.postUrl(uploadUri).then((HttpClientRequest request) {
        request.headers.add("Authorization", "Bearer $oauthToken");
        request.headers.add("Dropbox-API-Arg",
            "{\"path\": \"$fileToUpload\", \"mode\": \"overwrite\", \"mute\": true}");
        request.headers
            .add(HttpHeaders.contentTypeHeader, "application/octet-stream");
        request.write(contents);
        return request.close();
      }).then((HttpClientResponse response) {
        if (callback != null) {
          callback(contents, callbackMsg);
        }
      });
    } on HttpException catch (he) {
      print("Got HttpException sending file: ${he.toString()}");
    }
  }

  static void searchDropBoxFileNames({
    required String oauthToken,
    required String filePattern,
    required Function callback,
    int maxResults = 31,
  }) {
    if (oauthToken == "BLANK") {
      oauthToken = DropBoxAPIFn.globalOauthToken;
      if (oauthToken == "BLANK") {
        return;
      }
    }
    String cacheEntry = String.fromCharCodes(cache.get(filePattern));
    if (cacheEntry != '') {
      callback(FileListing.fromJson(jsonDecode(cacheEntry)));
      return;
    }
    HttpClient client = HttpClient();
    final Uri uploadUri =
        Uri.parse("https://api.dropboxapi.com/2/files/search_v2");
    try {
      client.postUrl(uploadUri).then((HttpClientRequest request) {
        request.headers.add("Authorization", "Bearer $oauthToken");
        request.headers.add(HttpHeaders.contentTypeHeader, "application/json");
        request.write(
            "{\"match_field_options\":{\"path\": \"\", \"max_results\": $maxResults, \"filename_only\": true}, \"query\": \"$filePattern\"}");
        return request.close();
      }).then((HttpClientResponse response) async {
        String contents = await response.transform(utf8.decoder).join();
        // print('Got response:');
        // print(contents.toString());
        final List<int> codeUnits = contents.codeUnits;
        final Uint8List bytes = Uint8List.fromList(codeUnits);
        cache.set(filePattern, bytes, 600);
        callback(FileListing.fromJson(jsonDecode(contents)));
      });
    } on HttpException catch (he) {
      print("Got HttpException during search: ${he.toString()}");
    }
  }

  static void listFolder({
    required String oauthToken,
    required String folder,
    required Function callback,
    // Timeout of 0 - dont cache
    required int timeoutSecs,
    bool refreshCache = false,
    //Set to unempty if a continuation call
    String cursor = "",
    int maxResults = 100,
  }) {
    if (oauthToken == "BLANK") {
      oauthToken = DropBoxAPIFn.globalOauthToken;
      if (oauthToken == "BLANK") {
        return;
      }
    }

    if (refreshCache || timeoutSecs == 0) {
      cache.remove(folder);
    } else if (cursor == '') {
      String cacheEntry = String.fromCharCodes(cache.get(folder));
      if (cacheEntry != '') {
        //Only use the cache entry if not a continue call
        callback(FileListing.fromJson(jsonDecode(cacheEntry)));
        return;
      }
    }
    HttpClient client = HttpClient();
    final Uri uploadUri = Uri.parse(
        "https://api.dropboxapi.com/2/files/list_folder${cursor != '' ? '/continue' : ''}");
    try {
      client.postUrl(uploadUri).then((HttpClientRequest request) {
        request.headers.add("Authorization", "Bearer $oauthToken");
        request.headers.add(HttpHeaders.contentTypeHeader, "application/json");
        if (cursor != '') {
          request.write("{\"cursor\": \"$cursor\"}");
        } else {
          request.write("{\"path\": \"$folder\"}");
        }
        return request.close();
      }).then((HttpClientResponse response) async {
        String contents = await response.transform(utf8.decoder).join();
        // print('Got response:');
        // print(contents);
        var json = jsonDecode(contents);
        FileListing entries = FileListing.fromJson(json);
        String cacheEntry = String.fromCharCodes(cache.get(folder));
        if (cacheEntry != '') {
          //Add the cache entries to the new entries
          FileListing newEntries = FileListing.fromJson(jsonDecode(cacheEntry));
          entries.fileEntries.addAll(newEntries.fileEntries);
          //Add to the cache
          String newStr = jsonEncode(entries.toJson());
          final List<int> codeUnits = newStr.codeUnits;
          final Uint8List bytes = Uint8List.fromList(codeUnits);
          cache.set(folder, bytes, timeoutSecs);
        } else {
          final List<int> codeUnits = contents.codeUnits;
          final Uint8List bytes = Uint8List.fromList(codeUnits);
          cache.set(folder, bytes, timeoutSecs);
        }
        if (json['has_more']) {
          cursor = json['cursor'];
          //Need to recursively call continue url and add to list
          // print("Recursive call");
          listFolder(
              oauthToken: oauthToken,
              folder: folder,
              callback: callback,
              timeoutSecs: timeoutSecs,
              cursor: cursor,
              maxResults: maxResults);
        } else {
          callback(entries);
        }
      });
    } on HttpException catch (he) {
      print("Got HttpException during search: ${he.toString()}");
    }
  }
}
