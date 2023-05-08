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
    if (temp <= maxDarkBlue)
      returnColor = Colors.indigo;
    else if (temp <= maxBlue)
      returnColor = Colors.blue;
    else if (temp <= maxYellow)
      returnColor = Colors.yellow;
    else if (temp <= maxOrange)
      returnColor = Colors.orange;
    else if (temp <= maxRed)
      returnColor = Colors.red;
    else if (temp <= maxRed2) returnColor = Colors.red[600]!;
    return returnColor;
  }

  static charts.Color findActiveChartColor(double temp) {
    Color color = findActiveColor(temp);
    return charts.Color(
        r: color.red, g: color.green, b: color.blue, a: color.alpha);
  }

  static Color findInActiveColor(double temp) {
    Color returnColor = Colors.red;
    if (temp <= maxBlue)
      returnColor = Colors.amber;
    else if (temp <= maxYellow)
      returnColor = Colors.orange;
    else if (temp <= maxOrange) returnColor = Colors.red;
    return returnColor;
  }
}

class ThermostatPage extends StatefulWidget {
  ThermostatPage({required this.oauthToken}) : super();
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
  final String setTempFile = "/setTemp.txt";
  double currentTemp = 0.0;
  double extTemp = 100.0;
  double setTemp = 0.0;
  double requestedTemp = 0.0;
  double humidity = 0.0;
  DateTime? lastHeardFrom;
  bool pirState = false;

  bool requestOutstanding = false;
  bool boilerOn = true;
  int minsToSetTemp = 0;
  Timer timer = Timer(Duration(), () {});

  @override
  void initState() {
    getSetTemp();
    getStatus();
    timer = Timer.periodic(Duration(seconds: 30), refreshStatus);
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
      String contents = "${requestedTemp.toStringAsFixed(1)} \n";
      DropBoxAPIFn.sendDropBoxFile(
          oauthToken: this.oauthToken,
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
    getSetTemp();
    getStatus();
  }

  void getStatus() {
    DropBoxAPIFn.getDropBoxFile(
      oauthToken: this.oauthToken,
      fileToDownload: statusFile,
      callback: processStatus,
      contentType: ContentType.text,
      timeoutSecs: 30,
    );
  }

  void getSetTemp() {
    if (requestOutstanding) {
      DropBoxAPIFn.getDropBoxFile(
        oauthToken: this.oauthToken,
        fileToDownload: setTempFile,
        callback: processSetTemp,
        contentType: ContentType.text,
        timeoutSecs: 0,
      );
    }
  }

  void processSetTemp(String contents) {
    try {
      requestedTemp = double.parse(contents.trim());
      if (requestedTemp.toStringAsFixed(1) == setTemp.toStringAsFixed(1)) {
        requestOutstanding = false;
      }
    } on FormatException {
      print("Received non-double Current temp format: $contents");
    }
  }

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
              extTemp = 100.0;
            } else {
              try {
                extTemp = double.parse(line.split(':')[1].trim());
              } on FormatException {
                print("Received non-double extTemp format: $line");
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
            pirState = str.contains('1');
          }
        });
      });
    }
  }

  List<charts.Series<TypeTemp, String>> createChartSeries() {
    List<TypeTemp> data = [
      new TypeTemp('House', currentTemp),
      new TypeTemp('Thermostat', setTemp),
    ];

    if (requestedTemp != setTemp) {
      data.add(
        new TypeTemp('Requested', requestedTemp),
      );
    }
    if (extTemp != 100.0) {
      data.add(new TypeTemp('Outside', extTemp));
    }
    return [
      new charts.Series<TypeTemp, String>(
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
          return new charts.TextStyleSpec(
              fontSize: 18, color: charts.MaterialPalette.white);
        },
        outsideLabelStyleAccessorFn: (TypeTemp tempByTemp, _) {
          return new charts.TextStyleSpec(
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
      Container(
        padding: const EdgeInsets.only(left: 8.0, top: 8.0),
        child: Text(
          'Temperature Chart:',
          style: TextStyle(
            fontSize: 18.0,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      Container(
        height: 250,
        child: TemperatureChart(createChartSeries(), animate: false),
      ),
      const SizedBox(height: 16.0),
      Container(
        padding: const EdgeInsets.only(left: 8.0, top: 8.0),
        child: Text(
          'Adjust Set Temp:',
          style: TextStyle(
            fontSize: 18.0,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      SliderWithRange(
          requestedTempGetter: () => requestedTemp, returnNewTemp: sendNewTemp),
      SetTempButtonBar(
          minusPressed: _decRequestedTemp,
          plusPressed: _incrementRequestedTemp),
      Container(
        padding: const EdgeInsets.only(left: 8.0, top: 8.0),
        child: Text(
          'Relative Humidity (%):',
          style: TextStyle(
            fontSize: 18.0,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      RHGauge(humidity: humidity),
      Container(
        padding: const EdgeInsets.only(left: 8.0, top: 8.0),
        child: Text(
          'Status:',
          style: TextStyle(
            fontSize: 18.0,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      BoilerState(boilerOn: () => boilerOn, minsToTemp: () => minsToSetTemp),
      ShowPirStatus(
        pirState: pirState,
      ),
// const SizedBox(height: 16.0),
      ShowDateTimeStamp(dateTimeStamp: lastHeardFrom),
//        const SizedBox(height: 32.0),
//        Row(
//          mainAxisAlignment: MainAxisAlignment.center,
//          children: <Widget>[
//            RaisedButton(
//              child: Icon(Icons.refresh),
//              color: Colors.blue,
//              textColor: Colors.white,
//              onPressed: getStatus,
//            ),
//          ],
//        ),
//       FloatingActionButton(
//         onPressed: getStatus,
//         elevation: 15,
//         tooltip: 'Refresh',
// //          shape: StadiumBorder(),
//         child: Icon(Icons.refresh),
//       ),

//        FloatingActionButton.extended(
//            onPressed: getStatus,
//            tooltip: 'Refresh',
//            label: Text('Refresh'),
//            icon: Icon(Icons.refresh),
//          ),
    ]);
    return returnWidget;
  }
}

class SetTempButtonBar extends StatelessWidget {
  SetTempButtonBar({required this.minusPressed, required this.plusPressed});

  final Function() minusPressed;
  final Function() plusPressed;

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
            child: Icon(Icons.arrow_downward),
//                        tooltip: "Decrease Set Temp by 0.1 degree",
            onPressed: minusPressed,
            style: ButtonStyle(
                textStyle:
                    MaterialStatePropertyAll(TextStyle(color: Colors.white)),
                backgroundColor: MaterialStatePropertyAll(Colors.blue))),
        ElevatedButton(
            child: Icon(Icons.arrow_upward),
//                      tooltip: "Increase Set Temp by 0.1 degree",
            onPressed: plusPressed,
            style: ButtonStyle(
                textStyle:
                    MaterialStatePropertyAll(TextStyle(color: Colors.white)),
                backgroundColor: MaterialStatePropertyAll(Colors.red))),
      ],
    );
  }
}

class ActionButtons extends StatelessWidget {
  ActionButtons({required this.minusPressed, required this.plusPressed});

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
                    icon: Icon(Icons.remove),
                    tooltip: "Decrease Set Temp by 0.5 degree",
                    onPressed: minusPressed,
                    color: Colors.blue,
                  )
                ])),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                IconButton(
                  icon: Icon(Icons.add),
                  color: Colors.red,
                  tooltip: "Increase Set Temp by 0.5 degree",
                  onPressed: plusPressed,
                )
              ],
            ))
          ]),
    );
  }
}

class SliderWithRange extends StatelessWidget {
  SliderWithRange(
      {required this.requestedTempGetter, required this.returnNewTemp});

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
          child: Slider(
            value: requestedTempGetter() >= 10.0 ? requestedTempGetter() : 10.0,
            min: 10.0,
            max: 25.0,
            divisions: 75,
            activeColor: ColorByTemp.findActiveColor(requestedTempGetter()),
            inactiveColor: ColorByTemp.findInActiveColor(requestedTempGetter()),
            label: requestedTempGetter().toStringAsFixed(1),
            onChanged: (double newValue) {
              returnNewTemp(newValue, false);
            },
            onChangeEnd: (endValue) {
              returnNewTemp(endValue, true);
            },
          ),
        ),
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
  RHGauge({required this.humidity});

  final double humidity;

  @override
  Widget build(BuildContext context) {
    return Container(
      child: SfLinearGauge(
          minimum: 0.0,
          maximum: 100.0,
          orientation: LinearGaugeOrientation.horizontal,
          majorTickStyle: LinearTickStyle(length: 20),
          axisLabelStyle: TextStyle(fontSize: 12.0, color: Colors.black),
          ranges: [
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
          markerPointers: [LinearShapePointer(value: humidity)],
          axisTrackStyle: LinearAxisTrackStyle(
              color: Colors.cyan,
              edgeStyle: LinearEdgeStyle.bothFlat,
              thickness: 8.0,
              borderColor: Colors.grey)),
      margin: EdgeInsets.all(10),
    );
  }
}

class LabelWithDoubleState extends StatelessWidget {
  LabelWithDoubleState(
      {required this.label,
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
            '${(valueGetter() == 100.0 ? '' : valueGetter().toStringAsFixed(1) + '\u00B0C')}',
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
  LabelWithIntState({required this.label, required this.valueGetter});

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
  BoilerState({required this.boilerOn, required this.minsToTemp});

  final ValueGetter<bool> boilerOn;
  final ValueGetter<int> minsToTemp;

  @override
  Widget build(BuildContext context) {
    Widget _returnWidget;
    TextStyle dispStyle = Theme.of(context).textTheme.titleMedium!;
    if (boilerOn()) {
      _returnWidget = Container(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
//                  padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                "Boiler is On",
                style: dispStyle.apply(color: Colors.green),
//                    ),
              ),
            ),
            Container(
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
                            "Mins to Set Temp:",
                            style: dispStyle.apply(color: Colors.green),
                          ),
                        )
                      ],
                    ),
                  ),
                  Text(
                    '${minsToTemp()}',
                    style: dispStyle.apply(color: Colors.green),
                  ),
                ],
              ),
            )
          ],
        ),
      );
    } else {
      _returnWidget = Container(
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
                      "Boiler is Off",
                      style: dispStyle.apply(color: Colors.red),
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
    return _returnWidget;
  }
}

class ShowPirStatus extends StatelessWidget {
  ShowPirStatus({required this.pirState});

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
                    "PIR State: ",
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
            pirState ? "On" : "Off",
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

class ShowDateTimeStamp extends StatelessWidget {
  ShowDateTimeStamp({required this.dateTimeStamp});

  final DateTime? dateTimeStamp;
  final DateFormat dateFormat = new DateFormat("yyyy-MM-dd HH:mm:ss");

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
                    "Last Heard from: ",
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

  TemperatureChart(this.seriesList, {this.animate});

  // The [BarLabelDecorator] has settings to set the text style for all labels
  // for inside the bar and outside the bar. To be able to control each datum's
  // style, set the style accessor functions on the series.
  @override
  Widget build(BuildContext context) {
    return new charts.BarChart(
      seriesList,
      animate: animate,
      vertical: false,
      barRendererDecorator: new charts.BarLabelDecorator<String>(),
      // Hide domain axis.
      domainAxis:
          new charts.OrdinalAxisSpec(renderSpec: new charts.NoneRenderSpec()),
    );
  }
}
