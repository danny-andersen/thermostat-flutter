import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'holidaytab.dart';
import 'thermostat-tab.dart';
import 'schedule-tab.dart';
import 'history-tab.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  State createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  String oauthToken = "API KEY IS BLANK";
  final HttpClient client = new HttpClient();
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Home Controller',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto',
      ),
//      home: ThermostatPage(title: 'Thermostat'),
      home: DefaultTabController(
        length: 4,
        child: Scaffold(
          appBar: AppBar(
            // Here we take the value from the MyHomePage object that was created by
            // the App.build method, and use it to set our appbar title.
            title: Text('Thermostat'),
            bottom: TabBar(
              tabs: [
                Tab(
                  text: "Status",
//                icon: Icon(Icons.stay_current_landscape)
                ),
                Tab(text: 'History'),
                Tab(text: 'Holiday'),
                Tab(text: 'Schedule'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              ThermostatPage(client: this.client, oauthToken: this.oauthToken),
              HistoryPage(client: this.client, oauthToken: this.oauthToken),
              HolidayPage(client: this.client, oauthToken: this.oauthToken),
              SchedulePage(client: this.client, oauthToken: this.oauthToken),
            ],
          ),
//          floatingActionButton: FloatingActionButton(
//            onPressed: getStatus,
//            tooltip: 'Refresh',
//            child: Icon(Icons.refresh),
//          ), // This trailing comma makes auto-formatting nicer for build methods.
        ),
      ),
    );
  }

  @override
  void initState() {
//    print("Loading API KEY");
    Future<Secret> secret =
        SecretLoader(secretPath: "assets/api-key.json").load();
    secret.then((Secret secret) {
      setState(() {
        this.oauthToken = secret.apiKey;
      });
    });
    super.initState();
  }

  @override
  void dispose() {
    client.close();
    super.dispose();
  }

}

class SecretLoader {
  final String secretPath;

  SecretLoader({this.secretPath});
  Future<Secret> load() {
    return rootBundle.loadStructuredData<Secret>(this.secretPath,
        (jsonStr) async {
      final secret = Secret.fromJson(json.decode(jsonStr));
      return secret;
    });
  }
}

class Secret {
  final String apiKey;
  Secret({this.apiKey = ""});
  factory Secret.fromJson(Map<String, dynamic> jsonMap) {
    return new Secret(apiKey: jsonMap["api_key"]);
  }
}
