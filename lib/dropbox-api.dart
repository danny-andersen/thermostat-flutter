import 'dart:io';
import 'dart:convert';
import 'package:meta/meta.dart';

getDropBoxFile({
  @required HttpClient client,
  @required String oauthToken,
  @required String fileToDownload,
  @required Function callback,
}) {
  final Uri downloadUri =
      Uri.parse("https://content.dropboxapi.com/2/files/download");

  try {
    client.getUrl(downloadUri).then((HttpClientRequest request) {
      request.headers.add("Authorization", "Bearer " + oauthToken);
      request.headers.add("Dropbox-API-Arg", "{\"path\": \"$fileToDownload\"}");
      return request.close();
    }).then((HttpClientResponse response) {
      response.transform(utf8.decoder).listen((contents) {
//          print('Got response:');
//          print(contents);
        callback(contents);
      });
    });
  } on HttpException catch (he) {
    print("Got HttpException getting status: " + he.toString());
  }
}

sendDropBoxFile({
  @required HttpClient client,
  @required String oauthToken,
  @required String fileToUpload,
  @required String contents,
  Function callback,
  String callbackMsg,
}) {
  final Uri uploadUri =
      Uri.parse("https://content.dropboxapi.com/2/files/upload");

  try {
    client.postUrl(uploadUri).then((HttpClientRequest request) {
      request.headers.add("Authorization", "Bearer " + oauthToken);
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
    print("Got HttpException sending setTemp: " + he.toString());
  }
}
