import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// import 'package:charts_flutter_new/flutter.dart' as charts;
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:webview_flutter/webview_flutter.dart';
// import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

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

class ThermostatPage extends StatefulWidget {
  ThermostatPage({super.key, required this.oauthToken, required this.localUI});
  String oauthToken;
  bool localUI;
  _ThermostatPageState statePage =
      _ThermostatPageState(oauthToken: "BLANK", localUI: false);
  // _ThermostatPageState state = _ThermostatPageState(oauthToken: "BLANK");

  @override
  _ThermostatPageState createState() {
    statePage = _ThermostatPageState(oauthToken: oauthToken, localUI: localUI);
    return statePage;
  }
}

class _ThermostatPageState extends State<ThermostatPage> {
  _ThermostatPageState({required this.oauthToken, required this.localUI});
  String oauthToken;
  bool localUI;
  final String statusFile = "/thermostat_status.txt";
  final String localStatusFile = "/home/danny/thermostat/status.txt";
  final Map<int, String> extStationNames = {
    2: "House RH side",
    3: "Front Door",
    4: "House LH side"
  };
  final List<String> externalstatusFile = [
    "/2_status.txt",
    "/3_status.txt",
    "/4_status.txt"
  ];
  final List<String> localExternalstatusFile = [
    "/home/danny/controlstation/2_status.txt",
    "/home/danny/controlstation/3_status.txt",
    "/home/danny/controlstation/4_status.txt",
  ];
  final String setTempFile = "/setTemp.txt";
  final String localSetTempFile = "/home/danny/thermostat/setTemp.txt";
  final String localForecastExt = "/home/danny/thermostat/extTemp.txt";
  final String localMotd = "/home/danny/thermostat/motd.txt";
  final int STATION_WITH_EXT_TEMP = 2;
  double currentTemp = 0.0;
  DateTime lastStatusReadTime = DateTime(2000);
  double forecastExtTemp = 100.0;
  String windStr = "";
  DateTime lastForecastReadTime = DateTime(2000);
  String motdStr = "";
  DateTime lastMotdReadTime = DateTime(2000);
  double setTemp = 0.0;
  double requestedTemp = 0.0;
  double humidity = 0.0;
  DateTime? lastHeardFrom;
  bool intPirState = false;
  String intPirLastEvent = "";

  Map<int, double> extTemp = {2: 100.0, 4: 100.0};
  Map<String, DateTime> lastExtReadTime = {};
  Map<int, double> extHumidity = {2: 0.0, 4: 0.0};
  Map<int, DateTime?> extLastHeardFrom = {4: null, 3: null, 2: null};
  Map<int, bool> extPirState = {4: false, 3: false, 2: false};
  Map<int, String> extPirLastEvent = {4: "", 3: "", 2: ""};

  bool requestOutstanding = false;
  bool boilerOn = true;
  int minsToSetTemp = 0;
  Timer timer = Timer(const Duration(), () {});

  @override
  void initState() {
    timer = Timer.periodic(const Duration(seconds: 30), refreshStatus);
    refreshStatus(timer);
    super.initState();
  }

  void setSecret(final String token) {
    oauthToken = token;
  }

  @override
  void dispose() {
//    print('Disposing Thermostat page');
    timer.cancel();
    super.dispose();
  }

  void _decRequestedTemp() {
//      print("Minus pressed");
    requestedTemp -= 0.50;
    // print("Minus pressed");
    sendNewTemp(requestedTemp, true);
  }

  void _incrementRequestedTemp() {
    requestedTemp += 0.50;
    // print("Plus pressed");
    sendNewTemp(requestedTemp, true);
  }

  void sendNewTemp(double temp, bool send) {
    if (send) {
      String contents = requestedTemp.toStringAsFixed(1);
      if (localUI) {
        File(localSetTempFile).writeAsStringSync(contents);
      } else {
        DropBoxAPIFn.sendDropBoxFile(
            oauthToken: oauthToken,
            fileToUpload: setTempFile,
            contents: contents);
      }
    }
    requestOutstanding = true;
    if (mounted) {
      setState(() {
        requestedTemp = temp;
      });
    }
  }

  void refreshStatus(Timer timer) {
    // getSetTemp();
    getStatus();
    getExternalStatus();
    if (!timer.isActive) {
      timer = Timer.periodic(
          localUI
              ? const Duration(milliseconds: 500)
              : const Duration(seconds: 30),
          refreshStatus);
    }
  }

  void getStatus() {
    if (localUI) {
      if (mounted) {
        setState(() {
          FileStat stat = FileStat.statSync(localStatusFile);
          if (stat.changed.isAfter(lastStatusReadTime)) {
            String statusStr = File(localStatusFile).readAsStringSync();
            processStatus(localStatusFile, statusStr);
            lastStatusReadTime = stat.changed;
          }
          stat = FileStat.statSync(localMotd);
          if (stat.changed.isAfter(lastMotdReadTime)) {
            String contents = File(localMotd).readAsStringSync();
            motdStr = contents.split('\n')[0];
            lastMotdReadTime = stat.changed;
          }
          stat = FileStat.statSync(localForecastExt);
          if (stat.changed.isAfter(lastForecastReadTime)) {
            String contents = File(localForecastExt).readAsStringSync();
            processForecast(contents);
            lastForecastReadTime = stat.changed;
          }
        });
      }
    } else {
      DropBoxAPIFn.getDropBoxFile(
        oauthToken: oauthToken,
        fileToDownload: statusFile,
        callback: processStatus,
        contentType: ContentType.text,
        timeoutSecs: 5,
      );
    }
  }

  void getExternalStatus() {
    if (localUI) {
      if (mounted) {
        for (final extfile in localExternalstatusFile) {
          FileStat stat = FileStat.statSync(extfile);
          DateTime? lastTime = lastExtReadTime[extfile];
          lastTime ??= DateTime(2000);
          if (stat.changed.isAfter(lastTime)) {
            String statusStr = File(extfile).readAsStringSync();
            processExternalStatus(extfile, statusStr);
            lastExtReadTime[extfile] = stat.changed;
          }
        }
      }
    } else {
      for (final extfile in externalstatusFile) {
        DropBoxAPIFn.getDropBoxFile(
          oauthToken: oauthToken,
          fileToDownload: extfile,
          callback: processExternalStatus,
          contentType: ContentType.text,
          timeoutSecs: 5,
        );
      }
    }
  }

  // void getSetTemp() {
  //   if (requestOutstanding) {
  //     DropBoxAPIFn.getDropBoxFile(
  //       oauthToken: oauthToken,
  //       fileToDownload: setTempFile,
  //       callback: processSetTemp,
  //       contentType: ContentType.text,
  //       timeoutSecs: 0,
  //     );
  //   }
  // }

  // void processSetTemp(String contents) {
  //   if (contents.contains("path/not_found/")) {
  //     requestOutstanding = false;
  //   } else {
  //     try {
  //       requestedTemp = double.parse(contents.trim());
  //       if (requestedTemp.toStringAsFixed(1) == setTemp.toStringAsFixed(1)) {
  //         requestOutstanding = false;
  //       }
  //     } on FormatException {
  //       print("Set Temp: Received non-double Current temp format: $contents");
  //     }
  //   }
  // }

  void processStatus(String filename, String contents) {
    if (mounted) {
      setState(() {
        contents.split('\n').forEach((line) {
          if (line.startsWith('Current temp:')) {
            try {
              currentTemp = double.parse(line.split(':')[1].trim());
            } on FormatException {
              print("Received non-double Current temp format: $line");
            }
          } else if (line.startsWith('Current set temp:')) {
            try {
              setTemp = double.parse(line.split(':')[1].trim());
//              print("Req Temp: $requestedTemp, request out? $requestOutstanding");
              if (requestedTemp.toStringAsFixed(1) ==
                  setTemp.toStringAsFixed(1)) {
                requestOutstanding = false;
              }
              if (!requestOutstanding) {
                requestedTemp = setTemp;
              }
            } on FormatException {
              print("Received non-double setTemp format: $line");
            }
          } else if (line.startsWith('External temp:')) {
            if (line.split(':')[1].trim().startsWith('Not Set')) {
              forecastExtTemp = 100.0;
            } else {
              try {
                forecastExtTemp = double.parse(line.split(':')[1].trim());
              } on FormatException {
                print("Received non-double forecast extTemp format: $line");
              }
            }
          } else if (line.startsWith('Heat on?')) {
            boilerOn = (line.split('?')[1].trim() == 'Yes');
          } else if (line.startsWith('Mins to set temp')) {
            try {
              minsToSetTemp = int.parse(line.split(':')[1].trim());
            } on FormatException {
              try {
                minsToSetTemp = double.parse(line.split(':')[1].trim()).toInt();
              } on FormatException {
                print("Received non-int minsToSetTemp format: $line");
              }
            }
          } else if (line.startsWith('Last heard time')) {
            String dateStr = line.substring(line.indexOf(':') + 2, line.length);
            lastHeardFrom = DateTime.parse(dateStr);
          } else if (line.startsWith('Current humidity')) {
            String str = line.substring(line.indexOf(':') + 2, line.length);
            humidity = double.parse(str);
          } else if (line.startsWith('Last PIR')) {
            intPirLastEvent =
                line.substring(line.indexOf(':') + 1, line.length);
          } else if (line.startsWith('PIR:')) {
            String str = line.substring(line.indexOf(':') + 1, line.length);
            intPirState = str.contains('1');
          }
        });
      });
    }
  }

  void processExternalStatus(String filename, String contents) {
    if (mounted) {
      setState(() {
        int stationNo = STATION_WITH_EXT_TEMP;
        if (filename != "") {
          //Retrieve station number from file name
          List<String> parts = filename.split('/');
          stationNo = int.parse(parts[parts.length - 1].split('_')[0]);
        }
        contents.split('\n').forEach((line) {
          if (line.startsWith('Current temp:')) {
            try {
              extTemp[stationNo] = double.parse(line.split(':')[1].trim());
            } on FormatException {
              print("Received non-double External temp format: $line");
            }
          } else if (line.startsWith('Last heard time')) {
            String dateStr = line.substring(line.indexOf(':') + 2, line.length);
            extLastHeardFrom[stationNo] = DateTime.parse(dateStr);
          } else if (line.startsWith('Current humidity')) {
            String str = line.substring(line.indexOf(':') + 2, line.length);
            extHumidity[stationNo] = double.parse(str);
          } else if (line.startsWith('Last PIR')) {
            extPirLastEvent[stationNo] =
                line.substring(line.indexOf(':') + 1, line.length);
          } else if (line.startsWith('PIR:')) {
            String str = line.substring(line.indexOf(':') + 1, line.length);
            extPirState[stationNo] = str.contains('1');
          }
        });
      });
    }
  }

  void processForecast(String contents) {
    if (mounted) {
      setState(() {
        List<String> lines = contents.split('\n');
        try {
          forecastExtTemp = double.parse(lines[0].trim());
        } on FormatException {
          print("Received non-double forecast temp format: $lines[0]");
        }
        windStr = lines[1].trim();
      });
    }
  }

  Widget createStatusBox(
      {required String stationName,
      required DateTime? lastHeardTime,
      required String? lastEventStr,
      required bool? currentPirStatus}) {
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
      int diff = currentTime.difference(lastHeardTime).inMinutes;
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

    return ColoredBox(
      color: boxColor,
      child: Padding(
        padding: const EdgeInsets.all(5.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              stationName,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
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
    );
  }

  // List<charts.Series<TypeTemp, String>> createChartSeries() {
  //   List<TypeTemp> data = [
  //     TypeTemp('House', currentTemp),
  //     TypeTemp('Thermostat', setTemp),
  //   ];

  //   if (requestedTemp != setTemp) {
  //     data.add(
  //       TypeTemp('Requested', requestedTemp),
  //     );
  //   }
  //   if (extTemp != 100.0) {
  //     data.add(TypeTemp('Outside', extTemp));
  //   }
  //   if (forecastExtTemp != 100.0) {
  //     data.add(TypeTemp('Forecast', forecastExtTemp));
  //   }
  //   return [
  //     charts.Series<TypeTemp, String>(
  //       id: 'Temperature',
  //       domainFn: (TypeTemp tempByType, _) => tempByType.type,
  //       measureFn: (TypeTemp tempByType, _) => tempByType.temp,
  //       data: data,
  //       // Set a label accessor to control the text of the bar label.
  //       labelAccessorFn: (TypeTemp tempByType, _) =>
  //           '${tempByType.type}: ${tempByType.temp.toStringAsFixed(1)}\u00B0C',
  //       fillColorFn: (TypeTemp tempByType, _) =>
  //           ColorByTemp.findActiveChartColor(tempByType.temp),
  //       insideLabelStyleAccessorFn: (TypeTemp tempByTemp, _) {
  //         return const charts.TextStyleSpec(
  //             fontSize: 18, color: charts.MaterialPalette.white);
  //       },
  //       outsideLabelStyleAccessorFn: (TypeTemp tempByTemp, _) {
  //         return const charts.TextStyleSpec(
  //             fontSize: 18, color: charts.MaterialPalette.black);
  //       },
  //     ),
  //   ];
  // }

  @override
  Widget build(BuildContext context) {
    double? extTempVal = extTemp[STATION_WITH_EXT_TEMP];
    extTempVal ??= -100.0;
    double? extHumidVal = extHumidity[STATION_WITH_EXT_TEMP];
    extHumidVal ??= 0.0;
    List<Widget> widgets = [
      SizedBox(
        // height: 250,
        // child: TemperatureChart(createChartSeries(), animate: false),
        height: localUI ? 380 : 350,
        child: TemperatureGauge(
            currentTemp, setTemp, extTempVal, forecastExtTemp, boilerOn),
      ),
      SetTempButtonBar(
        minusPressed: _decRequestedTemp,
        plusPressed: _incrementRequestedTemp,
        requestTemp: requestedTemp,
        sendNew: sendNewTemp,
      ),
      Container(
        padding: const EdgeInsets.only(left: 8.0, top: 2.0),
        child: RichText(
            text: TextSpan(
                text: 'Relative Humidity',
                style: const TextStyle(
                  fontSize: 14.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
                children: <TextSpan>[
              TextSpan(
                  text: extHumidity != -100 ? ' Inside + ' : ' Inside:',
                  style: const TextStyle(
                    fontSize: 14.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  )),
              TextSpan(
                  text: extHumidity != -100 ? ' Outside (%):' : '',
                  style: const TextStyle(
                    fontSize: 14.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  )),
            ])),
      ),
      RHGauge(
        humidity: humidity,
        extHumidity: extHumidVal,
      ),
    ];
    if (localUI) {
      widgets.addAll([
        Container(
          padding: const EdgeInsets.only(left: 8.0, top: 8.0),
          alignment: Alignment.center,
          child: Text(
            "$motdStr",
            style: TextStyle(
              fontSize: 18.0,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.only(left: 8.0, top: 8.0),
          alignment: Alignment.center,
          child: Text(
            "Wind Speed: $windStr",
            style: TextStyle(
              fontSize: 18.0,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Center(
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WebViewPage(),
                ),
              );
            },
            child: Text('View Forecast'),
            style: const ButtonStyle(
                maximumSize: MaterialStatePropertyAll(Size.fromHeight(40)),
                textStyle:
                    MaterialStatePropertyAll(TextStyle(color: Colors.white)),
                backgroundColor: MaterialStatePropertyAll(Colors.lightGreen)),
          ),
        ),
        // ShowPirStatus(
        //   pirStr: "External",
        //   pirState: extPirState,
        // ),
        // ShowDateTimeStamp(device: "External", dateTimeStamp: extLastHeardFrom),
      ]);
    }
    // } else {
    //   widgets.addAll([
    //     Container(
    //       padding: const EdgeInsets.only(left: 8.0, top: 8.0),
    //       child: const Text(
    //         'Status:',
    //         style: TextStyle(
    //           fontSize: 14.0,
    //           fontWeight: FontWeight.bold,
    //         ),
    //       ),
    //     ),
    //     ShowPirStatus(
    //       pirStr: "Internal",
    //       pirState: intPirState,
    //     ),
    //     ShowPirStatus(
    //       pirStr: "External",
    //       pirState: extPirState,
    //     ),
    //     ShowDateTimeStamp(device: "Thermostat", dateTimeStamp: lastHeardFrom),
    //     ShowDateTimeStamp(device: "External", dateTimeStamp: extLastHeardFrom),
    //   ]);
    // }
    List<Widget> statusBoxes = [];
    if (!localUI) {
      statusBoxes.add(createStatusBox(
          stationName: "Thermostat",
          lastHeardTime: lastHeardFrom,
          lastEventStr: intPirLastEvent,
          currentPirStatus: intPirState));
    }
    extStationNames.forEach((id, name) => statusBoxes.add(createStatusBox(
        stationName: name,
        lastHeardTime: extLastHeardFrom[id],
        lastEventStr: extPirLastEvent[id],
        currentPirStatus: extPirState[id])));

    widgets.add(
      Container(
        padding: const EdgeInsets.only(top: 5.0, bottom: 5.0),
        alignment: Alignment.center,
        child: Wrap(
          alignment: WrapAlignment.spaceEvenly,
          children: statusBoxes,
          spacing: 3.0,
          runSpacing: 3.0,
        ),
      ),
    );

    Widget returnWidget = ListView(children: widgets);
    return returnWidget;
  }
}

class SetTempButtonBar extends StatelessWidget {
  const SetTempButtonBar(
      {super.key,
      required this.minusPressed,
      required this.plusPressed,
      required this.requestTemp,
      required this.sendNew});

  final Function() minusPressed;
  final Function() plusPressed;
  final Function(double, bool) sendNew;
  final double requestTemp;

  @override
  Widget build(BuildContext context) {
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
            onPressed: minusPressed,
            style: const ButtonStyle(
                maximumSize: MaterialStatePropertyAll(Size.fromHeight(40)),
                textStyle:
                    MaterialStatePropertyAll(TextStyle(color: Colors.white)),
                backgroundColor: MaterialStatePropertyAll(Colors.blue)),
            child: const Icon(Icons.arrow_downward)),
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          SizedBox(
              width: 50,
              child: TextField(
                controller: TextEditingController(text: "$requestTemp"),
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
                  sendNew(temp, true);
                },

                // inputFormatters: [
                //   FilteringTextInputFormatter.digitsOnly
                // ], // Only numbers can be entered
              )),
          Text(
            "\u00B0C",
            style: Theme.of(context)
                .textTheme
                .displaySmall!
                .apply(fontSizeFactor: 0.5),
          )
        ]),
        ElevatedButton(
            onPressed: plusPressed,
            style: const ButtonStyle(
                textStyle:
                    MaterialStatePropertyAll(TextStyle(color: Colors.white)),
                backgroundColor: MaterialStatePropertyAll(Colors.red)),
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

// class SliderWithRange extends StatelessWidget {
//   const SliderWithRange(
//       {super.key,
//       required this.requestedTempGetter,
//       required this.returnNewTemp});

//   final ValueGetter<double> requestedTempGetter;
//   final Function(double newTemp, bool endChange) returnNewTemp;
//   final double maxBlue = 15.0;
//   final double maxYellow = 17.0;
//   final double maxOrange = 18.5;

//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       mainAxisSize: MainAxisSize.max,
//       mainAxisAlignment: MainAxisAlignment.spaceEvenly,

// //              mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: <Widget>[
//         Container(
// //                  width: 50.0,
//           alignment: Alignment.center,
//           padding: const EdgeInsets.only(left: 8.0),
//           child: Text('10\u00B0C',
//               style: Theme.of(context)
//                   .textTheme
//                   .displaySmall!
//                   .apply(fontSizeFactor: 0.5)),
//         ),
//         Flexible(
//             flex: 1,
//             child: SliderTheme(
//               data: SliderThemeData(
//                 trackHeight: 4.0,
//                 activeTrackColor: Colors.blue,
//                 inactiveTrackColor: Colors.grey,
//                 thumbColor: Colors.blue,
//                 overlayColor: Colors.blue.withOpacity(0.3),
//                 tickMarkShape: const RoundSliderTickMarkShape(
//                   tickMarkRadius: 8.0,
//                 ),
//               ),
//               child: Slider(
//                 value: requestedTempGetter() >= 10.0
//                     ? requestedTempGetter()
//                     : 10.0,
//                 min: 10.0,
//                 max: 25.0,
//                 divisions: 75,
//                 activeColor: ColorByTemp.findActiveColor(requestedTempGetter()),
//                 inactiveColor:
//                     ColorByTemp.findInActiveColor(requestedTempGetter()),
//                 label: requestedTempGetter().toStringAsFixed(1),
//                 onChanged: (double newValue) {
//                   returnNewTemp(newValue, false);
//                 },
//                 onChangeEnd: (endValue) {
//                   returnNewTemp(endValue, true);
//                 },
//               ),
//             )),
//         Container(
// //                  width: 50.0,
//           alignment: Alignment.center,
//           padding: const EdgeInsets.only(right: 8.0),
//           child: Text('25\u00B0C',
//               style: Theme.of(context)
//                   .textTheme
//                   .displaySmall!
//                   .apply(fontSizeFactor: 0.5)),
//         ),
//       ],
//     );
//   }
// }

class RHGauge extends StatelessWidget {
  const RHGauge({super.key, required this.humidity, required this.extHumidity});

  final double humidity;
  final double extHumidity;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(10),
      child: SfLinearGauge(
          minimum: 0.0,
          maximum: 100.0,
          orientation: LinearGaugeOrientation.horizontal,
          majorTickStyle: const LinearTickStyle(length: 20),
          axisLabelStyle: const TextStyle(fontSize: 12.0, color: Colors.grey),
          ranges: const [
            LinearGaugeRange(startValue: 0, endValue: 20.0, color: Colors.red),
            LinearGaugeRange(
                startValue: 20.0, endValue: 30.0, color: Colors.orange),
            LinearGaugeRange(
                startValue: 30.0, endValue: 60.0, color: Colors.green),
            LinearGaugeRange(
                startValue: 60.0, endValue: 70.0, color: Colors.orange),
            LinearGaugeRange(
                startValue: 70.0, endValue: 100.0, color: Colors.red),
          ],
          markerPointers: extHumidity == -100
              ? [
                  LinearShapePointer(value: humidity, color: Colors.red),
                ]
              : [
                  LinearShapePointer(value: humidity, color: Colors.red),
                  LinearShapePointer(value: extHumidity, color: Colors.green),
                ],
          axisTrackStyle: const LinearAxisTrackStyle(
              color: Colors.cyan,
              edgeStyle: LinearEdgeStyle.bothFlat,
              thickness: 8.0,
              borderColor: Colors.grey)),
    );
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
            (valueGetter() == 100.0
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
    TextStyle dispStyle = Theme.of(context).textTheme.titleMedium!;
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

class TemperatureGauge extends StatelessWidget {
  TemperatureGauge(this.currentTemperature, this.setTemperature, this.extTemp,
      this.forecastTemp, this.boilerState,
      {super.key});

  double currentTemperature; // Initial temperature
  double setTemperature; // Initial set temperature
  double extTemp;
  double forecastTemp;
  bool boilerState;

  static const double maxDarkBlue = 5.0;
  static const double maxBlue = 15.0;
  static const double maxYellow = 17.0;
  static const double maxOrange = 19.0;
  static const double maxRed = 21.0;
  static const double maxRed2 = 25.0;
  static const double deepRed = 35.0;

  @override
  Widget build(BuildContext context) {
    double minRange = maxDarkBlue;
    double maxRange = maxRed2;
    if (extTemp < minRange && extTemp > -5) {
      minRange = extTemp.round() - 1.0;
      // maxRange = minRange + 20;
    } else if (extTemp > maxRange && extTemp < 40.0) {
      maxRange = extTemp.round() + 1.0;
      // minRange = maxRange - 20;
    }
    if (minRange < 0) {
      minRange = 0;
    }
    if (minRange > 10) minRange = 10;
    if (maxRange < currentTemperature + 2) maxRange = currentTemperature + 2;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SfRadialGauge(
            axes: <RadialAxis>[
              RadialAxis(
                minimum: minRange,
                maximum: maxRange,
                interval: 1,
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
                    value: currentTemperature,
                    enableAnimation: true,
                    animationType: AnimationType.ease,
                    needleEndWidth: 5,
                    lengthUnit: GaugeSizeUnit.factor,
                    needleLength: 0.8,
                    needleColor: currentTemperature > setTemperature
                        ? Colors.red
                        : Colors.blue,
                  ),
                  NeedlePointer(
                    value: setTemperature,
                    enableAnimation: true,
                    animationType: AnimationType.ease,
                    lengthUnit: GaugeSizeUnit.factor,
                    needleLength: 0.8,
                    needleEndWidth: 5,
                    needleColor: Colors.grey,
                  ),
                  MarkerPointer(
                      value: extTemp > -30 ? extTemp : forecastTemp,
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
                            'Internal Temp: $currentTemperature°C',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                          Text(
                            'Set Temp: $setTemperature°C',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            'Outside Temp: ${extTemp > -40 ? extTemp : "??"}°C',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          Text(
                            'Forecast: $forecastTemp°C',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey,
                            ),
                          ),
                          boilerState
                              ? const Icon(Icons.local_fire_department_rounded,
                                  color: Colors.red, size: 50.0)
                              : Icon(Icons.local_fire_department_sharp,
                                  color: Colors.grey[300], size: 50.0),
                        ]),
                    angle: 90,
                    positionFactor: 0.5,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class WebViewPage extends StatefulWidget {
  @override
  _WebViewPageState createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late final WebViewController controller;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..loadRequest(
        Uri.parse('https://www.bbc.co.uk/weather/2642573'),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BBC Weather forecast'),
      ),
      body: WebViewWidget(
        controller: controller,
      ),
    );
  }
}
