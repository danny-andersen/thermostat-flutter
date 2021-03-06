import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:charts_flutter/flutter.dart' as charts;

import 'dropbox-api.dart';

class TypeTemp {
  final String type;
  final double temp;

  TypeTemp(this.type, this.temp);
}

class ColorByTemp {
  static final double maxDarkBlue = 5.0;
  static final double maxBlue = 15.0;
  static final double maxYellow = 17.0;
  static final double maxOrange = 19.0;
  static final double maxRed = 20.0;
  static final double maxRed2 = 21.0;

  static Color findActiveColor(double temp) {
    Color returnColor = Colors.red[700];
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
    else if (temp <= maxRed2) returnColor = Colors.red[600];
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
  ThermostatPage({@required this.client, @required this.oauthToken}) : super();

  final String oauthToken;
  final HttpClient client;

  @override
  _ThermostatPageState createState() =>
      _ThermostatPageState(client: this.client, oauthToken: this.oauthToken);
}

class _ThermostatPageState extends State<ThermostatPage> {
  _ThermostatPageState({@required this.client, @required this.oauthToken});
  final String oauthToken;
  final HttpClient client;
  final String statusFile = "/thermostat_status.txt";
  final String setTempFile = "/setTemp.txt";
  double currentTemp = 0.0;
  double extTemp = 100.0;
  double setTemp = 0.0;
  double requestedTemp = 0.0;

  bool requestOutstanding = false;
  bool boilerOn = true;
  int minsToSetTemp = 0;
  Timer timer;

  @override
  void initState() {
    client.idleTimeout = Duration(seconds: 90);
    getSetTemp();
    getStatus();
    timer = new Timer.periodic(Duration(seconds: 45), refreshStatus);
    super.initState();
  }

  @override
  void dispose() {
//    print('Disposing Thermostat page');
    timer.cancel();
    client.close();
    super.dispose();
  }

  void _decRequestedTemp() {
//      print("Minus pressed");
    requestedTemp -= 0.10;
    sendNewTemp(requestedTemp, true);
  }

  void _incrementRequestedTemp() {
    requestedTemp += 0.10;
    sendNewTemp(requestedTemp, true);
  }

  void sendNewTemp(double temp, bool send) {
    if (send) {
      String contents = requestedTemp.toStringAsFixed(1) + "\n";
      DropBoxAPIFn.sendDropBoxFile(
          client: this.client,
          oauthToken: this.oauthToken,
          fileToUpload: setTempFile,
          contents: contents);
    }
    requestOutstanding = true;
    if (this.mounted) {
      setState(() {
        requestedTemp = temp;
      });
    }
  }

  void refreshStatus(Timer timer) {
    getStatus();
  }

  void getStatus() {
    DropBoxAPIFn.getDropBoxFile(
        client: this.client,
        oauthToken: this.oauthToken,
        fileToDownload: this.statusFile,
        callback: processStatus);
  }

  void getSetTemp() {
    DropBoxAPIFn.getDropBoxFile(
        client: this.client,
        oauthToken: this.oauthToken,
        fileToDownload: this.setTempFile,
        callback: processSetTemp);
  }

  void processSetTemp(String contents) {
    if (this.mounted) {
      try {
        setState(() {
          requestedTemp = double.parse(contents.trim());
          if (requestedTemp.toStringAsFixed(1) != setTemp.toStringAsFixed(1)) {
            requestOutstanding = true;
          }
        });
      } on FormatException {
        //Do nothing - no setTemp file exists
      }
    }
  }

  void processStatus(String contents) {
    if (this.mounted) {
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
              print("Received non-int minsToSetTemp format: $line");
            }
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
//        LabelWithDoubleState(
//          label: 'House Temp:',
//          valueGetter: () => currentTemp,
//          textStyle: textStyle,
//        ),
//        LabelWithDoubleState(
//          label: 'Outside Temp:',
//          valueGetter: () => extTemp,
//          textStyle: textStyle,
//        ),
//        LabelWithDoubleState(
//            label: 'Current Set Temp:',
//            valueGetter: () => setTemp,
//    textStyle: textStyle,
//        ),
//        requestOutstanding
//            ? LabelWithDoubleState(
//                label: 'Requested Set Temp:',
//                valueGetter: () => requestedTemp,
//          textStyle: textStyle,
//              )
//            : const SizedBox(
//                height: 10,
//              ),
      Container(
                  padding: const EdgeInsets.only(left: 8.0, top: 8.0),
      child: Text(
      'Temperature Chart',
                    style: TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                    ),
    ),
      ),
        Container(
        height: 250,
        child:
            TemperatureChart(createChartSeries(), animate: false),
      ),
      const SizedBox(height: 16.0),
      SliderWithRange(
          requestedTempGetter: () => requestedTemp, returnNewTemp: sendNewTemp),
      SetTempButtonBar(
          minusPressed: _decRequestedTemp,
          plusPressed: _incrementRequestedTemp),
      BoilerState(boilerOn: () => boilerOn, minsToTemp: () => minsToSetTemp),
      const SizedBox(height: 16.0),
      ShowDateTimeStamp(dateTimeStamp: new DateTime.now()),
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
      FloatingActionButton(
        onPressed: getStatus,
        elevation: 15,
        tooltip: 'Refresh',
//          shape: StadiumBorder(),
        child: Icon(Icons.refresh),
      ),

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

class ShowDateTimeStamp extends StatelessWidget {
  ShowDateTimeStamp({@required this.dateTimeStamp});

  final DateTime dateTimeStamp;
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
                    "Last Updated: ",
                    style: Theme.of(context)
                        .textTheme
                        .display1
                        .apply(fontSizeFactor: 0.5),
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
            dateFormat.format(dateTimeStamp),
            style:
                Theme.of(context).textTheme.display1.apply(fontSizeFactor: 0.5),
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

class SetTempButtonBar extends StatelessWidget {
  SetTempButtonBar({@required this.minusPressed, @required this.plusPressed});

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
        RaisedButton(
          child: Icon(Icons.arrow_downward),
//                        tooltip: "Decrease Set Temp by 0.1 degree",
          textColor: Colors.white,
          onPressed: minusPressed,
          elevation: 15,
          color: Colors.blue,
        ),
        RaisedButton(
          child: Icon(Icons.arrow_upward),
//                      tooltip: "Increase Set Temp by 0.1 degree",
          onPressed: plusPressed,
          elevation: 15,
          color: Colors.red,
          textColor: Colors.white,
        )
      ],
    );
  }
}

class ActionButtons extends StatelessWidget {
  ActionButtons({@required this.minusPressed, @required this.plusPressed});

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
                    tooltip: "Decrease Set Temp by 0.1 degree",
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
                  tooltip: "Increase Set Temp by 0.1 degree",
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
      {@required this.requestedTempGetter, @required this.returnNewTemp});

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
                  .display1
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
                  .display1
                  .apply(fontSizeFactor: 0.5)),
        ),
      ],
    );
  }
}

class LabelWithDoubleState extends StatelessWidget {
  LabelWithDoubleState(
      {@required this.label,
      @required this.valueGetter,
      @required this.textStyle});

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
  LabelWithIntState({@required this.label, @required this.valueGetter});

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
                    style: Theme.of(context).textTheme.display1,
                  ),
                )
              ],
            ),
          ),
          Text(
            '${valueGetter()}',
            style: Theme.of(context).textTheme.display1,
          ),
        ],
      ),
    );
  }
}

class BoilerState extends StatelessWidget {
  BoilerState({@required this.boilerOn, @required this.minsToTemp});

  final ValueGetter<bool> boilerOn;
  final ValueGetter<int> minsToTemp;

  @override
  Widget build(BuildContext context) {
    Widget _returnWidget;
    TextStyle dispStyle = Theme.of(context).textTheme.title;
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

class TemperatureChart extends StatelessWidget {
  final List<charts.Series> seriesList;
  final bool animate;

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
