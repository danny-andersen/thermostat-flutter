import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'thermostat-tab.dart';
import 'history-tab.dart';
import 'holidaytab.dart';
import 'schedule-tab.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  MyApp({super.key});
  @override
  State createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  String oauthToken = "API KEY IS BLANK";
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
      });
    });
    super.initState();
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    // loadAsset().then((value) {
    //   Map jsonMap = json.decode(value);
    //   oauthToken = jsonMap["api_key"];
    // });
    // Future.wait([loadAsset()]).then((List<String> values) {
    //   Map jsonMap = json.decode(values[0]);
    //   oauthToken = jsonMap["api_key"];
    // });
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
              ThermostatPage(oauthToken: this.oauthToken),
              HistoryPage(oauthToken: this.oauthToken),
              HolidayPage(oauthToken: this.oauthToken),
              SchedulePage(oauthToken: this.oauthToken),
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
