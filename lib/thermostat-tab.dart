import 'dart:async';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// import 'package:charts_flutter_new/flutter.dart' as charts;
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
// import 'package:webview_flutter/webview_flutter.dart';
// import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'local_settings.dart';
import 'video_screen.dart';
import 'providers.dart';
import 'dropbox-api.dart';

class TypeTemp {
  final String type;
  final double temp;

  TypeTemp(this.type, this.temp);
}

class ColorByTemp {
  static const double maxDarkBlue = 5.0;
  static const double maxBlue = 15.0;
  static const double maxYellow = 17.0;
  static const double maxOrange = 19.0;
  static const double maxRed = 20.0;
  static const double maxRed2 = 21.0;

  static Color findActiveColor(double temp) {
    Color returnColor = Colors.red[700]!;
    if (temp <= maxDarkBlue) {
      returnColor = Colors.indigo;
    } else if (temp <= maxBlue) {
      returnColor = Colors.blue;
    } else if (temp <= maxYellow) {
      returnColor = Colors.yellow;
    } else if (temp <= maxOrange) {
      returnColor = Colors.orange;
    } else if (temp <= maxRed) {
      returnColor = Colors.red;
    } else if (temp <= maxRed2) {
      returnColor = Colors.red[600]!;
    }
    return returnColor;
  }

  // static charts.Color findActiveChartColor(double temp) {
  //   Color color = findActiveColor(temp);
  //   return charts.Color(
  //       r: color.red, g: color.green, b: color.blue, a: color.alpha);
  // }

  static Color findInActiveColor(double temp) {
    Color returnColor = Colors.red;
    if (temp <= maxBlue) {
      returnColor = Colors.amber;
    } else if (temp <= maxYellow) {
      returnColor = Colors.orange;
    } else if (temp <= maxOrange) {
      returnColor = Colors.red;
    }
    return returnColor;
  }
}

class ThermostatPage extends ConsumerStatefulWidget {
  ThermostatPage({super.key, required this.oauthToken, required this.localUI});
  String oauthToken;
  bool localUI;
  late _ThermostatPageState statePage;
  //  =
  //     _ThermostatPageState(oauthToken: "BLANK", localUI: false);
  // // _ThermostatPageState state = _ThermostatPageState(oauthToken: "BLANK");

  @override
  ConsumerState<ThermostatPage> createState() {
    statePage = _ThermostatPageState(oauthToken: oauthToken, localUI: localUI);
    return statePage;
  }
}

class _ThermostatPageState extends ConsumerState<ThermostatPage> {
  _ThermostatPageState({required this.oauthToken, required this.localUI});
  String oauthToken;
  bool localUI;
  String extHost = "";
  int intStartPort = 0;
  int extStartPort = 0;
  late Timer timer;

  @override
  void initState() {
    //Trigger first refresh shortly after widget initialised, to allow state to be initialised
    timer = Timer(const Duration(seconds: 1), updateStatus);
    super.initState();
  }

  void setSecret(final String token) {
    oauthToken = token;
    ref.read(thermostatStatusNotifierProvider).oauthToken = token;
  }

  int getRefreshTimerDurationMs() {
    //If local UI refresh quickly to immediate feedback
    //If on Local lan can get files quickly directly from control station, unless there is an issue
    //e.g. request is hanging, in which case get from dropbox less frequently
    final provider = ref.read(thermostatStatusNotifierProvider);
    return provider.localUI
        ? 500
        : provider.onLocalLan && !provider.localGetInProgress
            ? 10000
            : 20000;
  }

  void updateStatus() {
    //Note: Set timer before we call refresh otherwise will always have a get in progress
    timer = Timer(
        Duration(milliseconds: getRefreshTimerDurationMs()), updateStatus);
    ref.read(thermostatStatusNotifierProvider.notifier).refreshStatus();
    ref.read(cameraStatusNotifierProvider.notifier).refreshStatus();
  }

  @override
  void dispose() {
//    print('Disposing Thermostat page');
    timer.cancel();
    super.dispose();
  }

  Future<void> _statusButtonActionChooser(
      int stationId,
      bool onLocalLan,
      String stationName,
      double? lightStatus,
      int? camStatus,
      String camUrl,
      String? lastEvent,
      BuildContext context) async {
    String lastEventSearchStr = '';
    String filePath = '';

    if (!localUI &&
        lastEvent != null &&
        !lastEvent.contains('LIVE') &&
        !lastEvent.contains('Never')) {
      //lastEvent format: <yyyymmdd> <hh:mm>
      //video file format: /motion_images/yyyy-mm-dd/<yyymmdd>T<hhmmss>-<host>.mp4
      String date = lastEvent.split(':')[1].trim();
      String year = date.substring(0, 4);
      String month = date.substring(4, 6);
      String day = date.substring(6, 8);
      filePath = "/motion_images/$year-$month-$day/";
      String camName = getFilenamefromSource(stationName);
      lastEventSearchStr = "-$camName";
      // print("Looking for motion images $lastEventSearchStr in path $filePath");
    }
    List<Widget> actions = [
      TextButton(
        onPressed: () {
          Navigator.of(context).pop();
        },
        child: const Text('Cancel'),
      ),
    ];
    actions.insert(
        0,
        TextButton(
          onPressed: () {
            resetStation(stationId, onLocalLan);
            Navigator.of(context).pop();
          },
          child: const Text('Reset station'),
        ));
    if (lightStatus != null && stationsWithSwitch.contains(stationId)) {
      actions.insert(
          0,
          TextButton(
            onPressed: () {
              toggleLights(stationId, onLocalLan, lightStatus);
              Navigator.of(context).pop();
            },
            child: Text('Toggle lights ${lightStatus > 0 ? "off" : "on"}'),
          ));
    }
    if (!localUI && stationId != 0) {
      actions.insert(
          0,
          TextButton(
            onPressed: () {
              _navigateToWebView(stationName, camUrl, context);
            },
            child: const Text('Show Live webcam'),
          ));
      if (camStatus != null) {
        actions.insert(
            0,
            TextButton(
              onPressed: () {
                toggleCamera(stationId, onLocalLan, camStatus);
                Navigator.of(context).pop();
              },
              child: Text('Turn Camera ${camStatus > 0 ? "off" : "on"}'),
            ));
      }
      if (lastEventSearchStr != '') {
        actions.insert(
            0,
            TextButton(
              onPressed: () {
                DropBoxAPIFn.searchDropBoxFileNames(
                    oauthToken: oauthToken,
                    filePattern: lastEventSearchStr,
                    callback: _processVideoList,
                    maxResults: 10,
                    filePath: filePath);
              },
              child: const Text('Show Last Event Video'),
            ));
      }
    }

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('$stationName actions:'),
          actions: actions,
        );
      },
    );
  }

  void _processVideoList(FileListing files) {
    List<FileEntry> fileEntries = files.fileEntries;
    //File entries are listed with the most recent first
    if (fileEntries.isNotEmpty) {
      Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoScreen(
              oauthToken: oauthToken,
              videoName: fileEntries[0].fullPathName,
              mediaList: const [],
              folderPath: "",
              fileIndex: -1,
            ),
          ));
    }
  }

  Future<bool?> _navigateToWebView(
      String stationName, String camUrl, BuildContext context) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            WebViewPage(title: "$stationName Live Webcam", website: camUrl),
      ),
    );
  }

  Widget createStatusBox(
      {int stationId = 0,
      required bool onLocalLan,
      required String stationName,
      required DateTime? lastHeardTime,
      required String? lastEventStr,
      required bool? currentPirStatus,
      required double? lightStatus,
      required int? camStatus}) {
    lastEventStr ??= "";
    currentPirStatus ??= false;
    DateTime currentTime = DateTime.now();
    Color boxColor;
    Color eventStrColor = Colors.white;
    String lastHeardStr;
    FontWeight eventWeight = FontWeight.normal;
    if (lastHeardTime == null) {
      boxColor = Colors.red;
      lastHeardStr = "Never";
      lastEventStr = "Event: Never";
    } else {
      DateFormat formatter = DateFormat('yyyy-MM-dd HH:mm');
      lastHeardStr = formatter.format(lastHeardTime);
      int timezoneDifference = currentTime.timeZoneOffset.inMinutes;
      if (currentTime.timeZoneName == 'BST' ||
          currentTime.timeZoneName == 'GMT') {
        timezoneDifference = 0;
      }
      int diff =
          currentTime.difference(lastHeardTime).inMinutes - timezoneDifference;
      if (diff == 60) {
        //If exactly 60 mins then could be daylight savings
        diff = 0;
      }
      if (diff > 15) {
        boxColor = Colors.red;
      } else if (diff > 5) {
        boxColor = Colors.amber;
      } else {
        boxColor = Colors.green;
        if (currentPirStatus) {
          lastEventStr = "LIVE EVENT";
          eventStrColor = Colors.redAccent;
          eventWeight = FontWeight.w900;
        }
      }
      List<String> timeStrs = lastEventStr.split(':');
      if (timeStrs.length == 2) {
        lastEventStr = "Event: $lastEventStr";
      } else if (timeStrs.length > 2) {
        //Remove seconds from display
        lastEventStr = "Event: ${timeStrs[0]}:${timeStrs[1]}";
      }
    }
    Widget nameText = Text(
      stationName,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    );
    bool firstIcon = true;
    List<Widget> nameChildren = [nameText];
    if (lightStatus != null && stationsWithSwitch.contains(stationId)) {
      //This station has a light switch - show whether on or off
      nameChildren.add(const SizedBox(
        width: 5,
      ));
      firstIcon = false;
      nameChildren.add(Icon(
        // <-- Icon
        lightStatus > 0 ? Icons.lightbulb : Icons.lightbulb_outline,
        size: 20.0,
      ));
    }
    if (camStatus != null) {
      if (firstIcon) {
        nameChildren.add(const SizedBox(
          width: 5,
        ));
      }
      nameChildren.add(Icon(
        // <-- Icon
        camStatus > 0 ? Icons.camera_alt : Icons.no_photography_outlined,
        size: 20.0,
      ));
    }
    Widget nameWidget =
        Row(mainAxisSize: MainAxisSize.min, children: nameChildren);
    String camUrl = "";
    if (!localUI && stationId != 0) {
      if (onLocalLan) {
        int portNo = intStartPort + (stationId - 2);
        camUrl = "${stationCamUrlByName[stationName]}:$portNo";
      } else {
        int portNo = extStartPort + (stationId - 2);
        camUrl = "https://$extHost:$portNo";
      }
    }
    return GestureDetector(
        onTap: () {
          _statusButtonActionChooser(stationId, onLocalLan, stationName,
              lightStatus, camStatus, camUrl, lastEventStr, context);
        },
        child: ColoredBox(
          color: boxColor,
          child: Padding(
            padding: const EdgeInsets.all(5.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                nameWidget,
                Text(
                  'Heard: $lastHeardStr',
                  style: const TextStyle(color: Colors.white, fontSize: 10.0),
                ),

                // const SizedBox(height: 8),
                Text(
                  lastEventStr,
                  style: TextStyle(
                      color: eventStrColor,
                      fontSize: 10.0,
                      fontWeight: eventWeight),
                ),
              ],
            ),
          ),
        ));
  }

  @override
  Widget build(BuildContext context) {
    final ThermostatStatus status = ref.watch(thermostatStatusNotifierProvider);
    final CameraStatus cameraStatus = ref.watch(cameraStatusNotifierProvider);
    List<Widget> widgets = [
      const SizedBox(height: 10),
      SizedBox(
        height: localUI ? 480 : 380,
        child: const TemperatureGauge(),
      ),
      const SetTempButtonBar(),
      const RHGauge(),
    ];
    if (localUI) {
      widgets.addAll([
        Container(
          padding: const EdgeInsets.only(left: 8.0, top: 8.0),
          alignment: Alignment.center,
          child: Text(
            status.motdStr,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24.0,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.only(left: 8.0, top: 5.0),
          alignment: Alignment.center,
          child: Text(
            "Wind Speed: ${status.windStr}",
            style: const TextStyle(
              fontSize: 24.0,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        //TODO: Include the get weather forecast when inappwebview supports linux app
        // Center(
        //   child: ElevatedButton(
        //     onPressed: () {
        //       Navigator.push(
        //         context,
        //         MaterialPageRoute(
        //           builder: (context) => WebViewPage(
        //             title: 'BBC Weather forecast',
        //             website: 'https://www.bbc.co.uk/weather/2642573',
        //             username: "",
        //             password: "",
        //           ),
        //         ),
        //       );
        //     },
        //     child: Text('View Forecast'),
        //     style: const ButtonStyle(
        //         maximumSize: MaterialStatePropertyAll(Size.fromHeight(40)),
        //         textStyle:
        //             MaterialStatePropertyAll(TextStyle(color: Colors.white)),
        //         backgroundColor: MaterialStatePropertyAll(Colors.lightGreen)),
        //   ),
        // ),localUI
      ]);
    }
    widgets.add(SizedBox(height: status.localUI ? 30 : 50));

    List<Widget> statusBoxes = [];
    if (!localUI) {
      statusBoxes.add(createStatusBox(
          stationName: "Thermostat",
          onLocalLan: status.onLocalLan,
          lastHeardTime: status.lastHeardFrom,
          lastEventStr: status.intPirLastEvent,
          currentPirStatus: status.intPirState,
          lightStatus: null,
          camStatus: null));
    }
    extStationNames.forEach((id, name) => statusBoxes.add(createStatusBox(
        stationId: id,
        onLocalLan: status.onLocalLan,
        stationName: name,
        lastHeardTime: cameraStatus.extLastHeardFrom[id],
        lastEventStr: cameraStatus.extPirLastEvent[id],
        currentPirStatus: cameraStatus.extPirState[id],
        lightStatus: cameraStatus.lightStatus[id],
        camStatus: cameraStatus.camStatus[id])));

    widgets.add(
      Container(
        padding: const EdgeInsets.only(top: 5.0, bottom: 5.0),
        alignment: Alignment.center,
        child: Wrap(
          alignment: WrapAlignment.spaceEvenly,
          spacing: 3.0,
          runSpacing: 3.0,
          children: statusBoxes,
        ),
      ),
    );

    Widget returnWidget = ListView(children: widgets);
    return returnWidget;
  }
}

class SetTempButtonBar extends ConsumerWidget {
  const SetTempButtonBar({super.key});

  // final Function() minusPressed;
  // final Function() plusPressed;
  // final Function(double, bool) sendNew;
  // final double requestTemp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThermostatStatus status = ref.watch(thermostatStatusNotifierProvider);

    return ButtonBar(
//      decoration: BoxDecoration(
//        border: Border.all(
//          color: Colors.black,
//          width: 1.0,
//        ),
//      ),
      alignment: MainAxisAlignment.spaceEvenly,

      children: [
        ElevatedButton(
            onPressed: ref
                .read(thermostatStatusNotifierProvider.notifier)
                .decRequestedTemp,
            style: const ButtonStyle(
                maximumSize: WidgetStatePropertyAll(Size.fromHeight(40)),
                textStyle:
                    WidgetStatePropertyAll(TextStyle(color: Colors.white)),
                backgroundColor: WidgetStatePropertyAll(Colors.blue)),
            child: const Icon(Icons.arrow_downward_rounded)),
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          SizedBox(
              width: 50,
              child: TextField(
                controller: TextEditingController(
                    text:
                        "${status.requestedTemp == 0 ? status.setTemp : status.requestedTemp}"),
                style: Theme.of(context)
                    .textTheme
                    .displaySmall!
                    .apply(fontSizeFactor: 0.5),
                keyboardType: TextInputType.number,
                maxLines: 1,
                minLines: 1,
                onSubmitted: (String value) async {
                  double temp = double.parse(value);
                  if (temp < 10) temp = 10;
                  if (temp > 25) temp = 25;
                  ref
                      .read(thermostatStatusNotifierProvider.notifier)
                      .sendNewTemp(temp: temp, send: true);
                },

                // inputFormatters: [
                //   FilteringTextInputFormatter.digitsOnly
                // ], // Only numbers can be entered
              )),
          Text(
            "\u00B0C",
            style: TextStyle(
                fontSize: status.localUI ? 20 : 15,
                fontWeight: FontWeight.bold),
          )
        ]),
        ElevatedButton(
            onPressed: ref
                .read(thermostatStatusNotifierProvider.notifier)
                .incrementRequestedTemp,
            style: const ButtonStyle(
                textStyle:
                    WidgetStatePropertyAll(TextStyle(color: Colors.white)),
                backgroundColor: WidgetStatePropertyAll(Colors.red)),
            child: const Icon(Icons.arrow_upward)),
      ],
    );
  }
}

class ActionButtons extends StatelessWidget {
  const ActionButtons(
      {super.key, required this.minusPressed, required this.plusPressed});

  final Function() minusPressed;
  final Function() plusPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10.0),
      child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.remove),
                    tooltip: "Decrease Set Temp by 0.5\u00B0C",
                    onPressed: minusPressed,
                    color: Colors.blue,
                  )
                ])),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                IconButton(
                  icon: const Icon(Icons.add),
                  color: Colors.red,
                  tooltip: "Increase Set Temp by 0.5\u00B0C",
                  onPressed: plusPressed,
                )
              ],
            ))
          ]),
    );
  }
}

class RHGauge extends ConsumerWidget {
  const RHGauge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Map<int, double> extHumid = ref.watch(
        cameraStatusNotifierProvider.select((status) => status.extHumidity));
    double intHumidity = ref.watch(
        thermostatStatusNotifierProvider.select((status) => status.humidity));
    List<double> extList = [];
    double extHumidity = 0.0;
    extHumid.forEach((stn, ext) {
      if (stn != 1 && ext > 0) {
        extList.add(ext);
      }
    });
    if (extList.isNotEmpty) extHumidity = extList.average;

    return Column(
        // mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
              padding: const EdgeInsets.only(left: 8.0, top: 5.0),
              child: RichText(
                  textAlign: TextAlign.left,
                  text: TextSpan(
                      text: 'Relative Humidity',
                      style: const TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                      children: <TextSpan>[
                        TextSpan(
                            text:
                                extHumidity != -100 ? ' Inside + ' : ' Inside:',
                            style: const TextStyle(
                              fontSize: 18.0,
                              fontWeight: FontWeight.bold,
                              color: Colors.lightBlue,
                            )),
                        TextSpan(
                            text: extHumidity != -100 ? ' Outside (%):' : '',
                            style: const TextStyle(
                              fontSize: 18.0,
                              fontWeight: FontWeight.bold,
                              color: Colors.yellow,
                            )),
                      ]))),
          Container(
            padding: const EdgeInsets.only(left: 8.0, top: 5.0, right: 8.0),
            child: SfLinearGauge(
              minimum: 0.0,
              maximum: 100.0,
              orientation: LinearGaugeOrientation.horizontal,
              majorTickStyle: const LinearTickStyle(length: 20),
              axisLabelStyle:
                  const TextStyle(fontSize: 12.0, color: Colors.grey),
              ranges: const [
                LinearGaugeRange(
                    startValue: 0,
                    endValue: 20.0,
                    color: Colors.red,
                    startWidth: 10.0,
                    endWidth: 10.0),
                LinearGaugeRange(
                    startValue: 20.0,
                    endValue: 30.0,
                    color: Colors.orange,
                    startWidth: 10.0,
                    endWidth: 10.0),
                LinearGaugeRange(
                    startValue: 30.0,
                    endValue: 60.0,
                    color: Colors.green,
                    startWidth: 10.0,
                    endWidth: 10.0),
                LinearGaugeRange(
                    startValue: 60.0,
                    endValue: 70.0,
                    color: Colors.orange,
                    startWidth: 10.0,
                    endWidth: 10.0),
                LinearGaugeRange(
                    startValue: 70.0,
                    endValue: 100.0,
                    color: Colors.red,
                    startWidth: 10.0,
                    endWidth: 10.0),
              ],
              markerPointers: extHumidity == -100
                  ? [
                      LinearShapePointer(
                          value: intHumidity, color: Colors.lightBlue),
                    ]
                  : [
                      LinearShapePointer(
                          value: intHumidity, color: Colors.lightBlue),
                      LinearShapePointer(
                          value: extHumidity, color: Colors.yellow),
                    ],
              // axisTrackStyle: const LinearAxisTrackStyle(
              //     // color: Colors.cyan,
              //     edgeStyle: LinearEdgeStyle.bothFlat,
              //     thickness: 8.0,
              //     borderColor: Colors.grey)
            ),
            // );
          ),
        ]);
  }
}

class LabelWithDoubleState extends StatelessWidget {
  const LabelWithDoubleState(
      {super.key,
      required this.label,
      required this.valueGetter,
      required this.textStyle});

  final String label;
  final ValueGetter<double> valueGetter;
//  final double fontSizeFactor;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    return Container(
//      decoration: BoxDecoration(
//        border: Border.all(
//          color: Colors.black,
//          width: 1.0,
//        ),
//      ),
      padding: const EdgeInsets.all(10.0),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
//                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    label,
                    style: textStyle,
//                    style: Theme.of(context)
//                        .textTheme
//                        .display1
//                        .apply(fontSizeFactor: fontSizeFactor, ),
//                    style: TextStyle(
//                      fontSize: 18.0,
//                      fontWeight: FontWeight.bold,
//                    ),
                  ),
                )
              ],
            ),
          ),
          Text(
            (valueGetter() == -100.0
                ? ''
                : '${valueGetter().toStringAsFixed(1)}\u00B0C'),
            style: textStyle,
//            Theme.of(context)
//                .textTheme
//                .display1
//                .apply(fontSizeFactor: fontSizeFactor),
////            style: TextStyle(
//              //color: Colors.grey[500],
//              fontSize: 18.0,
//            ),
          ),
        ],
      ),
    );
  }
}

class LabelWithIntState extends StatelessWidget {
  const LabelWithIntState(
      {super.key, required this.label, required this.valueGetter});

  final String label;
  final ValueGetter<int> valueGetter;

  @override
  Widget build(BuildContext context) {
    return Container(
//      decoration: BoxDecoration(
//        border: Border.all(
//          color: Colors.black,
//          width: 1.0,
//        ),
//      ),
//      padding: const EdgeInsets.all(10.0),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
//                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                )
              ],
            ),
          ),
          Text(
            '${valueGetter()}',
            style: Theme.of(context).textTheme.displayMedium,
          ),
        ],
      ),
    );
  }
}

class BoilerState extends StatelessWidget {
  const BoilerState(
      {super.key, required this.boilerOn, required this.minsToTemp});

  final ValueGetter<bool> boilerOn;
  final ValueGetter<int> minsToTemp;

  @override
  Widget build(BuildContext context) {
    Widget returnWidget;
    if (boilerOn()) {
      returnWidget = Container(
        padding: const EdgeInsets.fromLTRB(10, 2, 10, 2),
        // padding: const EdgeInsets.all(10.0),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          // crossAxisAlignment: CrossAxisAlignment.spaceEvenly,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
                child: Container(
//                  padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                "Boiler is on - Mins to Set Temp:",
                // style: dispStyle.apply(color: Colors.green),
                style: Theme.of(context)
                    .textTheme
                    .displaySmall!
                    .apply(fontSizeFactor: 0.3)
                    .apply(color: Colors.green),
//                    ),
              ),
            )),
            Container(
              child: Text(
                '${minsToTemp()}',
                style: Theme.of(context)
                    .textTheme
                    .displaySmall!
                    .apply(fontSizeFactor: 0.3)
                    .apply(color: Colors.green),
              ),
              // Row(
              //   mainAxisSize: MainAxisSize.max,
              //   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              //   children: [
              //     Expanded(
              //       child: Column(
              //         crossAxisAlignment: CrossAxisAlignment.start,
              //         children: [
              //           Container(
              //             //                  padding: const EdgeInsets.only(bottom: 8.0),
              //             child: Text(
              //               "Boiler is on - Mins to Set Temp:",
              //               style: dispStyle.apply(color: Colors.green),
              //             ),
              //           )
              //         ],
              //       ),
              //     ),
              //     Text(
              //       '${minsToTemp()}',
              //       style: Theme.of(context)
              //           .textTheme
              //           .displaySmall!
              //           .apply(fontSizeFactor: 0.3)
              //           .apply(color: Colors.green),
              //     ),
              //   ],
              // ),
            )
          ],
        ),
      );
    } else {
      returnWidget = Container(
        // padding: const EdgeInsets.all(10.0),
        padding: const EdgeInsets.fromLTRB(10, 2, 10, 2),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
//                  padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      "Boiler is Off",
                      // style: dispStyle.apply(color: Colors.red),
                      style: Theme.of(context)
                          .textTheme
                          .displaySmall!
                          .apply(fontSizeFactor: 0.3)
                          .apply(color: Colors.red),
//                    style: TextStyle(
//                      fontSize: 18.0,
//                      fontWeight: FontWeight.bold,
//                    ),
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      );
    }
    return returnWidget;
  }
}

class ShowPirStatus extends StatelessWidget {
  const ShowPirStatus(
      {super.key, required this.pirStr, required this.pirState});

  final String pirStr;
  final bool pirState;

  @override
  Widget build(BuildContext context) {
    return Container(
//      decoration: BoxDecoration(
//        border: Border.all(
//          color: Colors.black,
//          width: 1.0,
//        ),
//      ),
      padding: const EdgeInsets.fromLTRB(10, 2, 10, 2),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
//                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    "$pirStr Event: ",
                    style: Theme.of(context)
                        .textTheme
                        .displaySmall!
                        .apply(fontSizeFactor: pirState ? 0.4 : 0.3)
                        .apply(fontWeightDelta: pirState ? 4 : 0)
                        .apply(
                            backgroundColor:
                                pirState ? Colors.red : Colors.white),
//                    style: TextStyle(
//                      fontSize: 18.0,
//                      fontWeight: FontWeight.bold,
//                    ),
                  ),
                )
              ],
            ),
          ),
          Text(
            pirState ? "Active" : "None",
            style: Theme.of(context)
                .textTheme
                .displaySmall!
                .apply(fontSizeFactor: pirState ? 0.4 : 0.3)
                .apply(fontWeightDelta: pirState ? 4 : 0)
                .apply(backgroundColor: pirState ? Colors.red : Colors.white),
//            style: TextStyle(
//              //color: Colors.grey[500],
//              fontSize: 18.0,
//            ),
          ),
        ],
      ),
    );
  }
}

class ShowDateTimeStamp extends StatelessWidget {
  ShowDateTimeStamp(
      {super.key, required this.device, required this.dateTimeStamp});

  final DateTime? dateTimeStamp;
  final String? device;
  final DateFormat dateFormat = DateFormat("yyyy-MM-dd HH:mm:ss");

  @override
  Widget build(BuildContext context) {
    return Container(
//      decoration: BoxDecoration(
//        border: Border.all(
//          color: Colors.black,
//          width: 1.0,
//        ),
//      ),
      padding: const EdgeInsets.fromLTRB(10, 2, 10, 2),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
//                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    "Last Heard from $device: ",
                    style: Theme.of(context)
                        .textTheme
                        .displaySmall!
                        .apply(fontSizeFactor: 0.3),
//                    style: TextStyle(
//                      fontSize: 18.0,
//                      fontWeight: FontWeight.bold,
//                    ),
                  ),
                )
              ],
            ),
          ),
          Text(
            dateTimeStamp != null
                ? dateFormat.format(dateTimeStamp!)
                : 'Not heard from',
            style: Theme.of(context)
                .textTheme
                .displaySmall!
                .apply(fontSizeFactor: 0.3),
//            style: TextStyle(
//              //color: Colors.grey[500],
//              fontSize: 18.0,
//            ),
          ),
        ],
      ),
    );
  }
}

// class TemperatureChart extends StatelessWidget {
//   List<charts.Series<dynamic, String>> seriesList;
//   bool? animate = true;

//   TemperatureChart(this.seriesList, {super.key, this.animate});

//   // The [BarLabelDecorator] has settings to set the text style for all labels
//   // for inside the bar and outside the bar. To be able to control each datum's
//   // style, set the style accessor functions on the series.
//   @override
//   Widget build(BuildContext context) {
//     return charts.BarChart(
//       seriesList,
//       animate: animate,
//       vertical: false,
//       barRendererDecorator: charts.BarLabelDecorator<String>(),
//       // Hide domain axis.
//       domainAxis:
//           const charts.OrdinalAxisSpec(renderSpec: charts.NoneRenderSpec()),
//     );
//   }
// }

class TemperatureGauge extends ConsumerStatefulWidget {
  const TemperatureGauge({super.key});

  @override
  ConsumerState<TemperatureGauge> createState() => _TemperatureGaugeState();
}

class _TemperatureGaugeState extends ConsumerState<TemperatureGauge> {
  static const double maxDarkBlue = 5.0;
  static const double maxBlue = 15.0;
  static const double maxYellow = 17.0;
  static const double maxOrange = 19.0;
  static const double maxRed = 21.0;
  static const double maxRed2 = 25.0;
  static const double deepRed = 35.0;

  Future<void> _boostActionChooser(
      bool boilerState, BuildContext context) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Boost Mode', textAlign: TextAlign.center),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                ref.read(thermostatStatusNotifierProvider.notifier).sendBoost();
                Navigator.of(context).pop();
              },
              child: Text('Turn Boost ${boilerState ? "Off" : "On"}'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThermostatStatus status = ref.watch(thermostatStatusNotifierProvider);
    final CameraStatus cameraStatus = ref.watch(cameraStatusNotifierProvider);
    double extTemp = -100.0;
    List<double> extList = [];
    cameraStatus.extTemp.forEach((stn, ext) {
      if (stn != 1 &&
          ext > -100 &&
          (status.forecastExtTemp != -100 ||
              (status.forecastExtTemp != -100 &&
                  (status.forecastExtTemp - ext).abs() < 10.0))) {
        //Only add in value if within 10 degrees of the forecast
        extList.add(ext);
      }
    });
    if (extList.isNotEmpty) extTemp = extList.average;
    double minRange = 10;
    double maxRange = maxRed2;
    if (status.currentTemp > maxRange && status.currentTemp < 30.0) {
      //Show external temp on guage up to 30
      maxRange = status.currentTemp.round() + 1.0;
      // minRange = maxRange - 20;
    } else if (status.currentTemp > maxRange && status.currentTemp < 40.0) {
      //Show internal temp on guage up to 40(!)
      maxRange = status.currentTemp.round() + 1.0;
    }

    return Center(
      child: GestureDetector(
          onTap: () {
            // print("Boost");
            _boostActionChooser(status.boilerOn, context);
          },
          child: Container(
            child: SfRadialGauge(
              axes: <RadialAxis>[
                RadialAxis(
                  minimum: minRange,
                  maximum: maxRange,
                  interval: 1,
                  radiusFactor: 1,
                  ranges: [
                    GaugeRange(
                      startValue: maxDarkBlue,
                      endValue: maxBlue,
                      gradient: const SweepGradient(
                          colors: [Colors.blue, Colors.yellow],
                          stops: [0.25, 0.9]),
                    ),
                    GaugeRange(
                      startValue: maxBlue,
                      endValue: maxYellow,
                      gradient: const SweepGradient(
                          colors: [Colors.yellow, Colors.orange],
                          stops: [0.25, 0.9]),
                    ),
                    GaugeRange(
                      startValue: maxYellow,
                      endValue: maxOrange,
                      gradient: const SweepGradient(
                          colors: [Colors.orange, Colors.deepOrange],
                          stops: [0.25, 0.9]),
                    ),
                    GaugeRange(
                      startValue: maxOrange,
                      endValue: maxRed,
                      gradient: const SweepGradient(
                          colors: [Colors.deepOrange, Colors.red],
                          stops: [0.25, 0.9]),
                    ),
                    GaugeRange(
                      startValue: maxRed,
                      endValue: maxRed2,
                      gradient: const SweepGradient(
                          colors: [Colors.red, Color.fromARGB(255, 77, 6, 1)],
                          stops: [0.25, 0.9]),
                    ),
                    GaugeRange(
                        startValue: maxRed2,
                        endValue: deepRed,
                        color: const Color.fromARGB(255, 77, 6, 1)),
                  ],
                  pointers: <GaugePointer>[
                    NeedlePointer(
                      value:
                          status.currentTemp == -100 ? 0 : status.currentTemp,
                      enableAnimation: true,
                      animationType: AnimationType.ease,
                      needleEndWidth: 5,
                      lengthUnit: GaugeSizeUnit.factor,
                      needleLength: 0.8,
                      needleColor: status.currentTemp > status.setTemp
                          ? Colors.red
                          : Colors.blue,
                    ),
                    NeedlePointer(
                      value: status.setTemp,
                      enableAnimation: true,
                      animationType: AnimationType.ease,
                      lengthUnit: GaugeSizeUnit.factor,
                      needleLength: 0.8,
                      needleEndWidth: 5,
                      needleColor: Colors.grey,
                    ),
                    MarkerPointer(
                        value: extTemp > -50 ? extTemp : status.forecastExtTemp,
                        color: Colors.green[600],
                        enableAnimation: true,
                        animationType: AnimationType.ease,
                        markerType: MarkerType.rectangle),
                  ],
                  annotations: <GaugeAnnotation>[
                    GaugeAnnotation(
                      widget: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Internal Temp: ${status.currentTemp == -100 ? "??" : status.currentTemp}°C',
                              textAlign: TextAlign.left,
                              style: TextStyle(
                                fontSize: status.localUI ? 20 : 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                            Text(
                              'Set Temp: ${status.setTemp}°C',
                              textAlign: TextAlign.left,
                              style: TextStyle(
                                fontSize: status.localUI ? 20 : 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              'Next: ${status.nextSetTempStr}',
                              textAlign: TextAlign.left,
                              style: TextStyle(
                                fontSize: status.localUI ? 20 : 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              'Outside Temp: ${extTemp != -100 ? extTemp.toStringAsFixed(1) : "??"}°C',
                              textAlign: TextAlign.left,
                              style: TextStyle(
                                fontSize: status.localUI ? 20 : 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            Text(
                              'Forecast: ${status.forecastExtTemp != -100 ? status.forecastExtTemp.toStringAsFixed(1) : "??"}°C',
                              textAlign: TextAlign.left,
                              style: TextStyle(
                                fontSize: status.localUI ? 20 : 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey,
                              ),
                            ),
                            status.boilerOn
                                ? Icon(Icons.local_fire_department_rounded,
                                    color: Colors.red,
                                    size: status.localUI ? 70.0 : 50.0)
                                : Icon(Icons.local_fire_department_sharp,
                                    color: Colors.grey[300],
                                    size: status.localUI ? 70.0 : 50.0),
                          ]),
                      angle: 90,
                      positionFactor: 0.5,
                    ),
                  ],
                ),
              ],
            ),
          )),
    );
  }
}

class WebViewPage extends StatefulWidget {
  const WebViewPage({
    super.key,
    required this.title,
    required this.website,
  });
  final String title;
  final String website;
  @override
  _WebViewPageState createState() =>
      _WebViewPageState(title: title, website: website);
}

class _WebViewPageState extends State<WebViewPage> {
  _WebViewPageState({
    required this.title,
    required this.website,
  });
  String title;
  String website;
  late final InAppWebViewController webViewController;
  final GlobalKey webViewKey = GlobalKey();
  final urlController = TextEditingController();
  double progress = 0;

  InAppWebViewSettings settings = InAppWebViewSettings(
    useShouldOverrideUrlLoading: true,
    mediaPlaybackRequiresUserGesture: false,
    useHybridComposition: true,
    allowsInlineMediaPlayback: true,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(title),
        ),
        body: SafeArea(
            child: Column(children: <Widget>[
          Expanded(
            child: Stack(children: [
              InAppWebView(
                // initialheaders: {
                //   'authorization': 'basic ' + base64encode(utf8.encode('$username:$password'))
                // },

                key: webViewKey,
                initialUrlRequest: URLRequest(url: WebUri(website)),
                initialSettings: settings,
                // pullToRefreshController: pullToRefreshController,
                onWebViewCreated: (controller) {
                  webViewController = controller;
                },
                onLoadStart: (controller, url) {
                  setState(() {
                    urlController.text = website;
                  });
                },
                onProgressChanged: (controller, progress) {
                  // if (progress == 100) {
                  //   pullToRefreshController.endRefreshing();
                  // }
                  setState(() {
                    this.progress = progress / 100;
                    urlController.text = website;
                  });
                },
                onPermissionRequest: (controller, origin) async {
                  return PermissionResponse(
                      action: PermissionResponseAction.GRANT);
                },
                // shouldOverrideUrlLoading: (controller, navigationAction) async {
                //   var uri = navigationAction.request.url!;

                //   if (![ "http", "https", "file", "chrome",
                //     "data", "javascript", "about"].contains(uri.scheme)) {
                //     if (await canLaunch(url)) {
                //       // Launch the App
                //       await launch(
                //         url,
                //       );
                //       // and cancel the request
                //       return NavigationActionPolicy.CANCEL;
                //     }
                //   }

                //   return NavigationActionPolicy.ALLOW;
                // },
                onLoadStop: (controller, url) async {
                  setState(() {
                    // this.url = url.toString();
                    urlController.text = website;
                  });
                },
                onReceivedServerTrustAuthRequest:
                    (controller, challenge) async {
                  return ServerTrustAuthResponse(
                      action: ServerTrustAuthResponseAction.PROCEED);
                },
                onReceivedHttpAuthRequest: (controller, challenge) async {
                  return HttpAuthResponse(
                      action: HttpAuthResponseAction
                          .USE_SAVED_HTTP_AUTH_CREDENTIALS);
                },
              ),
              progress < 1.0
                  ? LinearProgressIndicator(value: progress)
                  : Container(),
            ]),
          ),
        ])));
  }
}
