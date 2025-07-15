import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart'; // Provides [Player], [Media], [Playlist] etc.
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'package:thermostat_flutter/dropbox-api.dart';
import 'package:thermostat_flutter/who_tab.dart';
import 'package:thermostat_flutter/camera_tab.dart';
import 'package:thermostat_flutter/thermostat-tab.dart';
import 'package:thermostat_flutter/history-tab.dart';
import 'package:thermostat_flutter/holidaytab.dart';
import 'package:thermostat_flutter/schedule-tab.dart';
import 'package:thermostat_flutter/airquality-history.dart';
import 'package:thermostat_flutter/airquality.dart';
import 'package:thermostat_flutter/barometer-screen.dart';
// import 'package:flutterpi_gstreamer_video_player/flutterpi_gstreamer_video_player.dart';

HttpAuthCredentialDatabase httpAuthCredentialDatabase =
    HttpAuthCredentialDatabase.instance();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
  //   await InAppWebViewController.setWebContentsDebuggingEnabled(kDebugMode);
  // }

  // FileStat thermStat = FileStat.statSync("/home/danny/thermostat");
  // if (thermStat.type != FileSystemEntityType.notFound) {
  // FlutterpiVideoPlayer.registerWith();
  // }
  MediaKit.ensureInitialized();
  runApp(const ProviderScope(child: MyApp()));
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

  @override
  void initState() {
    //Determine if running local to thermostat by the presence of the thermostat dir
    FileStat thermStat = FileStat.statSync("/home/danny/thermostat");
    if (thermStat.type != FileSystemEntityType.notFound) {
      localUI = true;
    }

    Future<Secret> secret =
        SecretLoader(secretPath: "assets/api-key.json").load();
    secret.then((Secret secret) {
      LocalSendReceive.username = secret.username;
      LocalSendReceive.passphrase = secret.password;
      LocalSendReceive.host = secret.controlHost;
      Future<String> keyString = rootBundle.loadString('assets/connect-data');
      keyString.then((String str) {
        LocalSendReceive.setKeys(str);
      });
      oauthToken = secret.apiKey;
      DropBoxAPIFn.globalOauthToken = oauthToken;

      //Get the external IP address of the cameras from the dropbox file to override the hardcoded IP address
      DropBoxAPIFn.getDropBoxFile(
        fileToDownload: "/external_ip.txt",
        callback: processIPAddress,
        contentType: ContentType.text,
        timeoutSecs: 30,
      );
      setState(() {
        statusPage.oauthToken = oauthToken;
        statusPage.statePage.setSecret(oauthToken);

        statusPage.localUI = localUI;
        statusPage.statePage.localUI = localUI;
        statusPage.statePage.extStartPort = secret.extStartPort;
        statusPage.statePage.intStartPort = secret.intStartPort;
        if (!localUI && !Platform.isLinux) {
          //TODO: When (if?) Inapp_webview supports Linux devices, then remove this condition
          //Until then it causes a null exception as there is no native implementation
          URLCredential creds = URLCredential(
              username: LocalSendReceive.username,
              password: LocalSendReceive.passphrase);

          httpAuthCredentialDatabase.setHttpAuthCredential(
              protectionSpace: URLProtectionSpace(
                  host: "house-rh-side-cam0",
                  protocol: "https",
                  realm: "Motion",
                  port: secret.intStartPort),
              credential: creds);
          httpAuthCredentialDatabase.setHttpAuthCredential(
              protectionSpace: URLProtectionSpace(
                  host: "front-door-cam",
                  protocol: "https",
                  realm: "Motion",
                  port: secret.intStartPort + 1),
              credential: creds);
          httpAuthCredentialDatabase.setHttpAuthCredential(
              protectionSpace: URLProtectionSpace(
                  host: "house-lh-side",
                  protocol: "https",
                  realm: "Motion",
                  port: secret.intStartPort + 2),
              credential: creds);
          httpAuthCredentialDatabase.setHttpAuthCredential(
              protectionSpace: URLProtectionSpace(
                  host: "masterstation",
                  protocol: "https",
                  realm: "Motion",
                  port: secret.intStartPort + 3),
              credential: creds);
          httpAuthCredentialDatabase.setHttpAuthCredential(
              protectionSpace: URLProtectionSpace(
                  host: "conservatory-cam",
                  protocol: "https",
                  realm: "Motion",
                  port: secret.intStartPort + 4),
              credential: creds);
          httpAuthCredentialDatabase.setHttpAuthCredential(
              protectionSpace: URLProtectionSpace(
                  host: "backdoor-cam",
                  protocol: "https",
                  realm: "Motion",
                  port: secret.intStartPort + 5),
              credential: creds);
        }
      });
    });
    super.initState();
  }

  void processIPAddress(String filename, String contents) {
    setState(() {
      //Read contents of file and set the external IP address
      statusPage.statePage.extHost = contents.trim();
      URLCredential creds = URLCredential(
          username: LocalSendReceive.username,
          password: LocalSendReceive.passphrase);

      //Set the credentials for the external cameras ip d
      httpAuthCredentialDatabase.setHttpAuthCredential(
          protectionSpace: URLProtectionSpace(
              host: statusPage.statePage.extHost,
              protocol: "https",
              realm: "Motion",
              port: statusPage.statePage.extStartPort),
          credential: creds);
      httpAuthCredentialDatabase.setHttpAuthCredential(
          protectionSpace: URLProtectionSpace(
              host: statusPage.statePage.extHost,
              protocol: "https",
              realm: "Motion",
              port: statusPage.statePage.extStartPort + 1),
          credential: creds);
      httpAuthCredentialDatabase.setHttpAuthCredential(
          protectionSpace: URLProtectionSpace(
              host: statusPage.statePage.extHost,
              protocol: "https",
              realm: "Motion",
              port: statusPage.statePage.extStartPort + 2),
          credential: creds);
      httpAuthCredentialDatabase.setHttpAuthCredential(
          protectionSpace: URLProtectionSpace(
              host: statusPage.statePage.extHost,
              protocol: "https",
              realm: "Motion",
              port: statusPage.statePage.extStartPort + 3),
          credential: creds);
      httpAuthCredentialDatabase.setHttpAuthCredential(
          protectionSpace: URLProtectionSpace(
              host: statusPage.statePage.extHost,
              protocol: "https",
              realm: "Motion",
              port: statusPage.statePage.extStartPort + 4),
          credential: creds);
      httpAuthCredentialDatabase.setHttpAuthCredential(
          protectionSpace: URLProtectionSpace(
              host: statusPage.statePage.extHost,
              protocol: "https",
              realm: "Motion",
              port: statusPage.statePage.extStartPort + 5),
          credential: creds);
    });
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
      home: StatefulHome(statusPage: statusPage, oauthToken: oauthToken),
    );
  }

  @override
  void dispose() {
    client.close();
    super.dispose();
  }
}

class StatefulHome extends StatefulWidget {
  StatefulHome({super.key, required this.statusPage, required this.oauthToken});
  final ThermostatPage statusPage;
  final String oauthToken;
  @override
  _StatefulHomeState createState() => _StatefulHomeState();
}

class _StatefulHomeState extends State<StatefulHome> {
  late ThermostatPage statusPage;
  late String oauthToken;
  final PageController _pageController = PageController();
  final List<String> _pageTitles = [
    'Current Status',
    'Temperature History',
    'Barometer',
    'Air Quality',
    'Air Quality History',
    'Holiday Setting',
    'Heating Schedule',
    'Whos In and Out',
    'Security Videos'
  ];
  late List<Widget> _pages;
  // Map<String, Widget> pages = {};
  // late Widget currentPage;
  // late String currentPageTitle;
  int _currentPageIndex = 0;

  @override
  void initState() {
    super.initState();
    statusPage = widget.statusPage;
    oauthToken = widget.oauthToken;

    _pages = [
      statusPage,
      HistoryPage(oauthToken: oauthToken),
      BarometerPage(oauthToken: oauthToken),
      AirQualityPage(oauthToken: oauthToken),
      AirQualityHistoryPage(oauthToken: oauthToken),
      HolidayPage(oauthToken: oauthToken),
      SchedulePage(oauthToken: oauthToken),
      WhoPage(oauthToken: oauthToken),
      CameraPage(oauthToken: oauthToken)
    ];
    // pages.addAll({'Status': statusPage,
    //     'History': HistoryPage(oauthToken: oauthToken),
    //     'Holiday': HolidayPage(oauthToken: oauthToken),
    //     'Schedule': SchedulePage(oauthToken: oauthToken),
    //     'Who': WhoPage(oauthToken: oauthToken),
    //     'Video': CameraPage(oauthToken: oauthToken),
    //     });
    // currentPage = statusPage;
    // currentPageTitle = _pageTitles[_currentPageIndex];
  }

  void switchPage(int index) {
    setState(() {
      _currentPageIndex = index;
      // currentPage = pages[pageKey]!;
      // currentPageTitle = pageKey;
    });
    _pageController.jumpToPage(index);
    Navigator.pop(context); // Close the drawer after switching
  }

  void onPageChanged(int index) {
    setState(() {
      _currentPageIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: statusPage.localUI &&
                  _pageTitles[_currentPageIndex].startsWith('Current')
              ? DateTimeWidget()
              : Text(_pageTitles[_currentPageIndex])),
      drawer: CustomDrawer(
        pageTitles: _pageTitles,
        onPageSelected: switchPage,
      ),
      body: PageView(
        controller: _pageController,
        children: _pages,
        onPageChanged: onPageChanged,
      ),
    );
  }
}

class CustomDrawer extends StatelessWidget {
  final List<String> pageTitles;
  final Function(int) onPageSelected;

  CustomDrawer({required this.pageTitles, required this.onPageSelected});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.blue,
            ),
            child: Text(
              'Menu',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
              ),
            ),
          ),
          ...List.generate(pageTitles.length, (index) {
            IconData icon;
            switch (pageTitles[index]) {
              case 'Current Status':
                icon = Icons.home;
                break;
              case 'Temperature History':
                icon = Icons.history;
                break;
              case 'Barometer':
                icon = Icons.route;
                break;
              case 'Air Quality':
                icon = Icons.air;
                break;
              case 'Air Quality History':
                icon = Icons.history;
                break;
              case 'Holiday Setting':
                icon = Icons.calendar_month;
                break;
              case 'Heating Schedule':
                icon = Icons.schedule;
                break;
              case 'Whos In and Out':
                icon = Icons.person;
                break;
              case 'Security Videos':
                icon = Icons.switch_video;
                break;
              default:
                icon = Icons.home;
            }
            return ListTile(
              leading: Icon(icon),
              title: Text(pageTitles[index]),
              onTap: () => onPageSelected(index),
            );
          }).toList(),
        ],
      ),
    );
  }
}

class DateTimeWidget extends StatefulWidget {
  @override
  _DateTimeWidgetState createState() => _DateTimeWidgetState();
}

class _DateTimeWidgetState extends State<DateTimeWidget> {
  String _currentDateTime = " ";

  @override
  void initState() {
    super.initState();
    _updateDateTime();
    // Update the date and time every second
    Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateDateTime();
    });
  }

  void _updateDateTime() {
    bool updateState =
        FileStat.statSync("/home/danny/thermostat/displayOn.txt").type !=
            FileSystemEntityType.notFound;
    if (updateState) {
      setState(() {
        _currentDateTime = DateFormat('dd MMMM yyyy             HH:mm:ss')
            .format(DateTime.now());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _currentDateTime,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ],
    );
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
  final String controlHost;
  final String extHost;
  final int extStartPort;
  final int intStartPort;
  Secret(
      {this.apiKey = "",
      this.username = "",
      this.password = "",
      this.controlHost = "",
      this.extHost = "",
      this.intStartPort = 0,
      this.extStartPort = 0});
  factory Secret.fromJson(Map<String, dynamic> jsonMap) {
    return Secret(
        apiKey: jsonMap["api_key"],
        username: jsonMap["username"],
        password: jsonMap["password"],
        controlHost: jsonMap["controlHost"],
        // extHost: jsonMap["extHost"],
        extStartPort: jsonMap["extStartPort"],
        intStartPort: jsonMap["intStartPort"]);
  }
}
