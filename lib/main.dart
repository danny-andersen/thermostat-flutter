import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'package:thermostat_flutter/dropbox-api.dart';
import 'package:thermostat_flutter/who_tab.dart';
import 'package:thermostat_flutter/camera_tab.dart';
import 'package:thermostat_flutter/thermostat-tab.dart';
import 'package:thermostat_flutter/history-tab.dart';
import 'package:thermostat_flutter/holidaytab.dart';
import 'package:thermostat_flutter/schedule-tab.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
  //   await InAppWebViewController.setWebContentsDebuggingEnabled(kDebugMode);
  // }
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  String oauthToken = "BLANK";
  ThermostatPage statusPage =
      ThermostatPage(oauthToken: "BLANK", localUI: false);
  final HttpClient client = HttpClient();
  bool localUI = false;
  String username = "";
  String password = "";

  // Future<String> loadAsset() async {
  //   return await rootBundle.loadString('assets/api-key.json');
  // }

  @override
  void initState() {
//    print("Loading API KEY");
    //Determine if running local to thermostat by the presence of the thermostat dir
    FileStat thermStat = FileStat.statSync("/home/danny/thermostat");
    if (thermStat.type != FileSystemEntityType.notFound) {
      localUI = true;
    }
    //This is for just debugging thermostat UI on an emulator
    //TODO: remove
    // localUI = true;
    Future<Secret> secret =
        SecretLoader(secretPath: "assets/api-key.json").load();
    secret.then((Secret secret) {
      setState(() {
        oauthToken = secret.apiKey;
        DropBoxAPIFn.globalOauthToken = oauthToken;
        statusPage.statePage.username = secret.username;
        statusPage.statePage.password = secret.password;
        statusPage.statePage.extHost = secret.extHost;
        statusPage.statePage.startPort = secret.startPort;
        statusPage.localUI = localUI;
        statusPage.statePage.localUI = localUI;
        // Cancel any current time as will want to do it more frequently if local
        statusPage.statePage.timer.cancel();
        statusPage.oauthToken = oauthToken;
        statusPage.statePage.oauthToken = oauthToken;
        statusPage.statePage.refreshStatus(statusPage.statePage.timer);
      });
    });
    super.initState();
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    // ScreenType screenType = FormFactor.getScreenType(context);
    return MaterialApp(
        title: 'Home Controller',
        theme: ThemeData(
          useMaterial3: true,

          // Define the default brightness and colors.
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ), // This is the theme of your application.
          // primarySwatch: Colors.blue,
          fontFamily: 'Roboto',
        ),
//      home: ThermostatPage(title: 'Thermostat'),
        home:
            // screenType != ScreenType.embedded ?
            DefaultTabController(
          length: 6,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Thermostat'),
              automaticallyImplyLeading: false,
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
        )
        // : Material(child: statusPage),
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
  final String username;
  final String password;
  final String extHost;
  final int startPort;
  Secret(
      {this.apiKey = "",
      this.username = "",
      this.password = "",
      this.extHost = "",
      this.startPort = 0});
  factory Secret.fromJson(Map<String, dynamic> jsonMap) {
    return Secret(
        apiKey: jsonMap["api_key"],
        username: jsonMap["username"],
        password: jsonMap["password"],
        extHost: jsonMap["extHost"],
        startPort: jsonMap["startPort"]);
  }
}
