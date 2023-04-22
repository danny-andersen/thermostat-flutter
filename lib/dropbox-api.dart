import 'dart:io';
import 'dart:convert';
import 'package:synchronized/synchronized.dart';
// import 'package:meta/meta.dart';

class ContentCache {
  final Map<String, _CacheEntry<String>> _cache = {};

  String get(String key) {
    final entry = _cache[key];
    if (entry != null && !entry.isExpired()) {
      return entry.value;
    } else {
      return "";
    }
  }

  void set(String key, String value, int duration) {
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

  FileEntry(this.fileName, this.fullPathName, this.lastModified);

  factory FileEntry.fromJson(Map<String, dynamic> json) {
    String fn = json['name'];
    String path = json['path_display'];
    DateTime modified = DateTime.parse(json['server_modified']);
    return FileEntry(fn, path, modified);
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
  FileListing(this.fileEntries);

  factory FileListing.fromJson(Map<String, dynamic> json) {
    var list = json['matches'] as List;
    List<FileMatch> matches =
        list.map((js) => FileMatch.fromJson(js['metadata'])).toList();
    List<FileEntry> entries = matches.map((match) => match.fileEntry).toList();
    return FileListing(entries);
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
  }) {
    if (oauthToken == "BLANK") {
      oauthToken = globalOauthToken;
      if (oauthToken == "BLANK") {
        return;
      }
    }
    String cacheEntry = cache.get(fileToDownload);
    if (cacheEntry != '') {
      callback(cacheEntry);
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
      }).then((HttpClientResponse response) {
        response.transform(utf8.decoder).listen((contents) {
//          print('Got response:');
//          print(contents);
          cache.set(fileToDownload, contents, timeoutSecs);
          callback(contents);
        });
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
    int maxResults = 100,
  }) {
    if (oauthToken == "BLANK") {
      oauthToken = DropBoxAPIFn.globalOauthToken;
      if (oauthToken == "BLANK") {
        return;
      }
    }
    String cacheEntry = cache.get(filePattern);
    if (cacheEntry != '') {
      callback(FileListing.fromJson(jsonDecode(cacheEntry)));
    }
    HttpClient client = HttpClient();
    final Uri uploadUri =
        Uri.parse("https://api.dropboxapi.com/2/files/search");
    try {
      client.postUrl(uploadUri).then((HttpClientRequest request) {
        request.headers.add("Authorization", "Bearer $oauthToken");
        request.headers.add(HttpHeaders.contentTypeHeader, "application/json");
        request.write(
            "{\"path\": \"\", \"max_results\": $maxResults, \"query\": \"$filePattern\",  \"mode\": \"filename\" }");
        return request.close();
      }).then((HttpClientResponse response) {
        response.transform(utf8.decoder).listen((contents) {
//          print('Got response:');
//          print(contents);
          callback(FileListing.fromJson(jsonDecode(contents)));
        });
      });
    } on HttpException catch (he) {
      print("Got HttpException during search: ${he.toString()}");
    }
  }
}
