import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:thermostat_flutter/dropbox-api.dart';
import 'package:thermostat_flutter/who_tab.dart';
import 'package:thermostat_flutter/camera_tab.dart';
import 'package:thermostat_flutter/thermostat-tab.dart';
import 'package:thermostat_flutter/history-tab.dart';
import 'package:thermostat_flutter/holidaytab.dart';
import 'package:thermostat_flutter/schedule-tab.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  String oauthToken = "BLANK";
  ThermostatPage statusPage = ThermostatPage(oauthToken: "BLANK");
  final HttpClient client = HttpClient();
  // Future<String> loadAsset() async {
  //   return await rootBundle.loadString('assets/api-key.json');
  // }

  @override
  void initState() {
//    print("Loading API KEY");
    Future<Secret> secret =
        SecretLoader(secretPath: "assets/api-key.json").load();
    secret.then((Secret secret) {
      setState(() {
        oauthToken = secret.apiKey;
        DropBoxAPIFn.globalOauthToken = oauthToken;
        statusPage.statePage.refreshStatus(Timer(const Duration(), () {}));
      });
    });
    super.initState();
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Home Controller',
      theme: ThemeData(
        // This is the theme of your application.
        primarySwatch: Colors.blue,
        fontFamily: 'Roboto',
      ),
//      home: ThermostatPage(title: 'Thermostat'),
      home: DefaultTabController(
        length: 6,
        child: Scaffold(
          appBar: AppBar(
            // Here we take the value from the MyHomePage object that was created by
            // the App.build method, and use it to set our appbar title.
            title: const Text('Thermostat'),
            bottom: const TabBar(
              isScrollable: true,
              tabs: [
                Tab(
                  text: "Stat",
//                icon: Icon(Icons.stay_current_landscape)
                ),
                Tab(text: 'Hist'),
                Tab(text: 'Hols'),
                Tab(text: 'Sched'),
                Tab(text: 'Who'),
                Tab(text: 'Cam'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              statusPage,
              HistoryPage(oauthToken: oauthToken),
              HolidayPage(oauthToken: oauthToken),
              SchedulePage(oauthToken: oauthToken),
              WhoPage(oauthToken: oauthToken),
              CameraPage(oauthToken: oauthToken),
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

//   @override
//   void initState() {
// //    print("Loading API KEY");
//     Future<Secret> secret =
//         SecretLoader(secretPath: "assets/api-key.json").load();
//     secret.then((Secret secret) {
//       setState(() {
//         this.oauthToken = secret.apiKey;
//       });
//     });
//     super.initState();
//   }

  @override
  void dispose() {
    client.close();
    super.dispose();
  }
}

class SecretLoader {
  final String? secretPath;

  SecretLoader({this.secretPath});
  Future<Secret> load() {
    return rootBundle.loadStructuredData<Secret>(secretPath!, (jsonStr) async {
      final secret = Secret.fromJson(jsonDecode(jsonStr));
      return secret;
    });
  }
}

class Secret {
  final String apiKey;
  Secret({this.apiKey = ""});
  factory Secret.fromJson(Map<String, dynamic> jsonMap) {
    return Secret(apiKey: jsonMap["api_key"]);
  }
}
