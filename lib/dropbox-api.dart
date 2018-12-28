import 'dart:io';
import 'dart:convert';

getDropBoxFile(
{HttpClient client,
  String oauthToken,
  String fileToDownload,
  Function callback,
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

sendDropBoxFile({HttpClient client,
String oauthToken,
String fileToUpload,
String contents,
}) {
  final Uri uploadUri =  Uri.parse("https://content.dropboxapi.com/2/files/upload");

  try {
    client.postUrl(uploadUri).then((HttpClientRequest request) {
      request.headers.add("Authorization", "Bearer " + oauthToken);
      request.headers.add("Dropbox-API-Arg",
          "{\"path\": \"$fileToUpload\", \"mode\": \"overwrite\", \"mute\": true}");
      request.headers
          .add(HttpHeaders.contentTypeHeader, "application/octet-stream");
      request.write(contents);
      return request.close();
    }).then((HttpClientResponse response) {});
  } on HttpException catch (he) {
    print("Got HttpException sending setTemp: " + he.toString());
  }

}