import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:charts_flutter_new/flutter.dart' as charts;
import 'package:syncfusion_flutter_gauges/gauges.dart';

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

  static charts.Color findActiveChartColor(double temp) {
    Color color = findActiveColor(temp);
    return charts.Color(
        r: color.red, g: color.green, b: color.blue, a: color.alpha);
  }

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
  ThermostatPage({super.key, required this.oauthToken});
  String oauthToken;
  _ThermostatPageState statePage = _ThermostatPageState(oauthToken: "BLANK");
  // _ThermostatPageState state = _ThermostatPageState(oauthToken: "BLANK");

  @override
  _ThermostatPageState createState() {
    statePage = _ThermostatPageState(oauthToken: oauthToken);
    return statePage;
  }
}

class _ThermostatPageState extends State<ThermostatPage> {
  _ThermostatPageState({required this.oauthToken});
  String oauthToken;
  final String statusFile = "/thermostat_status.txt";
  final String externalstatusFile = "/external_status.txt";
  final String setTempFile = "/setTemp.txt";
  double currentTemp = 0.0;
  double forecastExtTemp = 100.0;
  double extTemp = 100.0;
  double setTemp = 0.0;
  double requestedTemp = 0.0;
  double humidity = 0.0;
  double extHumidity = 0.0;
  DateTime? lastHeardFrom;
  DateTime? extLastHeardFrom;
  bool intPirState = false;
  bool extPirState = false;

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
    sendNewTemp(requestedTemp, true);
  }

  void _incrementRequestedTemp() {
    requestedTemp += 0.50;
    sendNewTemp(requestedTemp, true);
  }

  void sendNewTemp(double temp, bool send) {
    if (send) {
      String contents = requestedTemp.toStringAsFixed(1);
      DropBoxAPIFn.sendDropBoxFile(
          oauthToken: oauthToken,
          fileToUpload: setTempFile,
          contents: contents);
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
  }

  void getStatus() {
    DropBoxAPIFn.getDropBoxFile(
      oauthToken: oauthToken,
      fileToDownload: statusFile,
      callback: processStatus,
      contentType: ContentType.text,
      timeoutSecs: 5,
    );
  }

  void getExternalStatus() {
    DropBoxAPIFn.getDropBoxFile(
      oauthToken: oauthToken,
      fileToDownload: externalstatusFile,
      callback: processExternalStatus,
      contentType: ContentType.text,
      timeoutSecs: 5,
    );
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

  void processStatus(String contents) {
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
          } else if (line.startsWith('PIR:')) {
            String str = line.substring(line.indexOf(':') + 1, line.length);
            intPirState = str.contains('1');
          }
        });
      });
    }
  }

  void processExternalStatus(String contents) {
    if (mounted) {
      setState(() {
        contents.split('\n').forEach((line) {
          if (line.startsWith('Current temp:')) {
            try {
              extTemp = double.parse(line.split(':')[1].trim());
            } on FormatException {
              print("Received non-double Current temp format: $line");
            }
          } else if (line.startsWith('Last heard time')) {
            String dateStr = line.substring(line.indexOf(':') + 2, line.length);
            extLastHeardFrom = DateTime.parse(dateStr);
          } else if (line.startsWith('Current humidity')) {
            String str = line.substring(line.indexOf(':') + 2, line.length);
            extHumidity = double.parse(str);
          } else if (line.startsWith('PIR:')) {
            String str = line.substring(line.indexOf(':') + 1, line.length);
            extPirState = str.contains('1');
          }
        });
      });
    }
  }

  List<charts.Series<TypeTemp, String>> createChartSeries() {
    List<TypeTemp> data = [
      TypeTemp('House', currentTemp),
      TypeTemp('Thermostat', setTemp),
    ];

    if (requestedTemp != setTemp) {
      data.add(
        TypeTemp('Requested', requestedTemp),
      );
    }
    if (extTemp != 100.0) {
      data.add(TypeTemp('Outside', extTemp));
    }
    if (forecastExtTemp != 100.0) {
      data.add(TypeTemp('Forecast', forecastExtTemp));
    }
    return [
      charts.Series<TypeTemp, String>(
        id: 'Temperature',
        domainFn: (TypeTemp tempByType, _) => tempByType.type,
        measureFn: (TypeTemp tempByType, _) => tempByType.temp,
        data: data,
        // Set a label accessor to control the text of the bar label.
        labelAccessorFn: (TypeTemp tempByType, _) =>
            '${tempByType.type}: ${tempByType.temp.toStringAsFixed(1)}\u00B0C',
        fillColorFn: (TypeTemp tempByType, _) =>
            ColorByTemp.findActiveChartColor(tempByType.temp),
        insideLabelStyleAccessorFn: (TypeTemp tempByTemp, _) {
          return const charts.TextStyleSpec(
              fontSize: 18, color: charts.MaterialPalette.white);
        },
        outsideLabelStyleAccessorFn: (TypeTemp tempByTemp, _) {
          return const charts.TextStyleSpec(
              fontSize: 18, color: charts.MaterialPalette.black);
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
//    final TextStyle textStyle = Theme.of(context).textTheme.title;
    Widget returnWidget = ListView(children: [
      // Container(
      //   padding: const EdgeInsets.only(left: 8.0, top: 8.0),
      //   child: const Text(
      //     'Temperature Chart:',
      //     style: TextStyle(
      //       fontSize: 18.0,
      //       fontWeight: FontWeight.bold,
      //     ),
      //   ),
      // ),
      SizedBox(
        // height: 250,
        // child: TemperatureChart(createChartSeries(), animate: false),
        height: 350,
        child: TemperatureGauge(
            currentTemp, setTemp, extTemp, forecastExtTemp, boilerOn),
      ),
      // const SizedBox(height: 16.0),
      Container(
        padding: const EdgeInsets.only(left: 8.0),
        child: const Text(
          'Increase / Decrease Temperature:',
          style: TextStyle(
            fontSize: 14.0,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      // SliderWithRange(
      //     requestedTempGetter: () => requestedTemp, returnNewTemp: sendNewTemp),
      SetTempButtonBar(
        minusPressed: _decRequestedTemp,
        plusPressed: _incrementRequestedTemp,
        requestTemp: requestedTemp,
        sendNew: sendNewTemp,
      ),
      Container(
        padding: const EdgeInsets.only(left: 8.0, top: 8.0),
        child: RichText(
            text: const TextSpan(
                text: 'Relative Humidity,',
                style: TextStyle(
                  fontSize: 14.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                children: <TextSpan>[
              TextSpan(
                  text: ' Inside + ',
                  style: TextStyle(
                    fontSize: 14.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  )),
              TextSpan(
                  text: ' Outside (%):',
                  style: TextStyle(
                    fontSize: 14.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  )),
            ])),
      ),
      RHGauge(
        humidity: humidity,
        extHumidity: extHumidity,
      ),
      Container(
        padding: const EdgeInsets.only(left: 8.0, top: 8.0),
        child: const Text(
          'Status:',
          style: TextStyle(
            fontSize: 14.0,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      // BoilerState(boilerOn: () => boilerOn, minsToTemp: () => minsToSetTemp),
      ShowPirStatus(
        pirStr: "Internal",
        pirState: intPirState,
      ),
      ShowPirStatus(
        pirStr: "External",
        pirState: extPirState,
      ),
// const SizedBox(height: 16.0),
      ShowDateTimeStamp(device: "Thermostat", dateTimeStamp: lastHeardFrom),
      ShowDateTimeStamp(device: "External", dateTimeStamp: extLastHeardFrom),
    ]);
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

class SliderWithRange extends StatelessWidget {
  const SliderWithRange(
      {super.key,
      required this.requestedTempGetter,
      required this.returnNewTemp});

  final ValueGetter<double> requestedTempGetter;
  final Function(double newTemp, bool endChange) returnNewTemp;
  final double maxBlue = 15.0;
  final double maxYellow = 17.0;
  final double maxOrange = 18.5;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,

//              mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Container(
//                  width: 50.0,
          alignment: Alignment.center,
          padding: const EdgeInsets.only(left: 8.0),
          child: Text('10\u00B0C',
              style: Theme.of(context)
                  .textTheme
                  .displaySmall!
                  .apply(fontSizeFactor: 0.5)),
        ),
        Flexible(
            flex: 1,
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 4.0,
                activeTrackColor: Colors.blue,
                inactiveTrackColor: Colors.grey,
                thumbColor: Colors.blue,
                overlayColor: Colors.blue.withOpacity(0.3),
                tickMarkShape: const RoundSliderTickMarkShape(
                  tickMarkRadius: 8.0,
                ),
              ),
              child: Slider(
                value: requestedTempGetter() >= 10.0
                    ? requestedTempGetter()
                    : 10.0,
                min: 10.0,
                max: 25.0,
                divisions: 75,
                activeColor: ColorByTemp.findActiveColor(requestedTempGetter()),
                inactiveColor:
                    ColorByTemp.findInActiveColor(requestedTempGetter()),
                label: requestedTempGetter().toStringAsFixed(1),
                onChanged: (double newValue) {
                  returnNewTemp(newValue, false);
                },
                onChangeEnd: (endValue) {
                  returnNewTemp(endValue, true);
                },
              ),
            )),
        Container(
//                  width: 50.0,
          alignment: Alignment.center,
          padding: const EdgeInsets.only(right: 8.0),
          child: Text('25\u00B0C',
              style: Theme.of(context)
                  .textTheme
                  .displaySmall!
                  .apply(fontSizeFactor: 0.5)),
        ),
      ],
    );
  }
}

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
          axisLabelStyle: const TextStyle(fontSize: 12.0, color: Colors.black),
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
          markerPointers: [
            LinearShapePointer(value: humidity, color: Colors.green),
            LinearShapePointer(value: extHumidity, color: Colors.red)
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

class TemperatureChart extends StatelessWidget {
  List<charts.Series<dynamic, String>> seriesList;
  bool? animate = true;

  TemperatureChart(this.seriesList, {super.key, this.animate});

  // The [BarLabelDecorator] has settings to set the text style for all labels
  // for inside the bar and outside the bar. To be able to control each datum's
  // style, set the style accessor functions on the series.
  @override
  Widget build(BuildContext context) {
    return charts.BarChart(
      seriesList,
      animate: animate,
      vertical: false,
      barRendererDecorator: charts.BarLabelDecorator<String>(),
      // Hide domain axis.
      domainAxis:
          const charts.OrdinalAxisSpec(renderSpec: charts.NoneRenderSpec()),
    );
  }
}

class TemperatureGauge extends StatelessWidget {
  TemperatureGauge(this.currentTemperature, this.setTemperature, this.extTemp,
      this.forecastTemp, this.boilerState, {super.key});

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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SfRadialGauge(
            axes: <RadialAxis>[
              RadialAxis(
                minimum: 5,
                maximum: 35,
                interval: 2,
                ranges: [
                  GaugeRange(
                      startValue: maxDarkBlue,
                      endValue: maxBlue,
                      color: Colors.blue),
                  GaugeRange(
                      startValue: maxBlue,
                      endValue: maxYellow,
                      color: Colors.yellow),
                  GaugeRange(
                      startValue: maxYellow,
                      endValue: maxOrange,
                      color: Colors.orange),
                  GaugeRange(
                      startValue: maxOrange,
                      endValue: maxRed,
                      color: Colors.deepOrange),
                  GaugeRange(
                      startValue: maxRed, endValue: maxRed2, color: Colors.red),
                  GaugeRange(
                      startValue: maxRed2,
                      endValue: deepRed,
                      color: Colors.red[900]),
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
                      value: extTemp,
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
                            ),
                          ),
                          Text(
                            'Set Temp: $setTemperature°C',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Outside Temp: $extTemp°C',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Forecast: $forecastTemp°C',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
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
