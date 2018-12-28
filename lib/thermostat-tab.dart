import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:intl/intl.dart';


class ThermostatPage extends StatefulWidget {
  ThermostatPage({@required this.oauthToken}) : super();

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String oauthToken;

  @override
  _ThermostatPageState createState() => _ThermostatPageState(oauthToken: this.oauthToken);
}

class _ThermostatPageState extends State<ThermostatPage> {
  _ThermostatPageState({@required this.oauthToken});
  final String oauthToken;
  double currentTemp = 0.0;
  double extTemp = 0.0;
  double setTemp = 0.0;
  double requestedTemp = 10.0;
  bool boilerOn = true;
  int minsToSetTemp = 0;
  Uri statusUri = Uri.parse("https://content.dropboxapi.com/2/files/download");
  Uri uploadUri = Uri.parse("https://content.dropboxapi.com/2/files/upload");
  HttpClient client = new HttpClient();
  String statusFile = "/thermostat_status.txt";
  String setTempFile = "/setTemp.txt";
  Timer timer;
  bool iconButtonsEnabled = false;

  @override
  void initState() {
    client.idleTimeout = Duration(seconds: 90);
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
    if (iconButtonsEnabled) {
//      print("Minus pressed");
      requestedTemp -= 0.10;
      sendNewTemp(requestedTemp, true);
    }
  }

  void _incrementRequestedTemp() {
    if (iconButtonsEnabled) {
      requestedTemp += 0.10;
      sendNewTemp(requestedTemp, true);
    }
  }

  void sendNewTemp(double temp, bool send) {
    if (send) {
      try {
        client.postUrl(uploadUri).then((HttpClientRequest request) {
          request.headers.add("Authorization", "Bearer " + this.oauthToken);
          request.headers.add("Dropbox-API-Arg",
              "{\"path\": \"$setTempFile\", \"mode\": \"overwrite\", \"mute\": true}");
          request.headers
              .add(HttpHeaders.contentTypeHeader, "application/octet-stream");
          request.write(requestedTemp.toStringAsFixed(1) + "\n");
          return request.close();
        }).then((HttpClientResponse response) {});
      } on HttpException catch (he) {
        print ("Got HttpException sending setTemp: " + he.toString());
      }
    }
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
    try {
//      print (this.oauthToken);
      client.getUrl(statusUri).then((HttpClientRequest request) {
        request.headers.add("Authorization", "Bearer " + this.oauthToken);
        request.headers.add("Dropbox-API-Arg", "{\"path\": \"$statusFile\"}");
        return request.close();
      }).then((HttpClientResponse response) {
        response.transform(utf8.decoder).listen((contents) {
//          print('Got response:');
//          print(contents);
          if (mounted) {
            setState(() {
              processStatus(contents);
            });
          }
          //        client.close();
        });
      });
    } on HttpException catch (he) {
      print ("Got HttpException getting status: " + he.toString());
    }

  }

  void processStatus(String contents) {
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
          if (requestedTemp == 10.0) requestedTemp = setTemp;
        } on FormatException {
          print("Received non-double setTemp format: $line");
        }
      } else if (line.startsWith('External temp:')) {
        try {
          extTemp = double.parse(line.split(':')[1].trim());
        } on FormatException {
          print("Received non-double extTemp format: $line");
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
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    Widget returnWidget =
    ListView(children: [
          LabelWithDoubleState(
              label: 'House Temp:', valueGetter: () => currentTemp),
          LabelWithDoubleState(
              label: 'External Temp:', valueGetter: () => extTemp),
          LabelWithDoubleState(
              label: 'Current Set Temp:', valueGetter: () => setTemp),
          LabelWithDoubleStateOrBlank(
              label: 'Requested Set Temp:',
              valueGetter: () => requestedTemp,
              blank: (requestedTemp.toStringAsFixed(1) == setTemp.toStringAsFixed(1))),
          LabelWithDoubleStateOrBlank( //Hacky way to get a line spacing between rows
            label: 'Blank Line',
            valueGetter: () => requestedTemp,
            blank: true,
          ),
          SliderWithRange(
              requestedTempGetter: () => requestedTemp,
              returnNewTemp: sendNewTemp),
          SetTempButtonBar(
              minusPressed: _decRequestedTemp,
              plusPressed: _incrementRequestedTemp),
          BoilerState(
              boilerOn: () => boilerOn, minsToTemp: () => minsToSetTemp),
          ShowDateTimeStamp(dateTimeStamp: new DateTime.now()),
        ],
      );
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
            style: Theme.of(context)
                .textTheme
                .display1
                .apply(fontSizeFactor: 0.5),
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
          onPressed: minusPressed,
          color: Colors.blue,
        ),
        RaisedButton(
          child: Icon(Icons.arrow_upward),
//                      tooltip: "Increase Set Temp by 0.1 degree",
          onPressed: plusPressed,
          color: Colors.red,
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

  Color findActiveColor() {
    Color returnColor = Colors.red;
    if (requestedTempGetter() <= maxBlue)
      returnColor = Colors.blue;
    else if (requestedTempGetter() <= maxYellow)
      returnColor = Colors.yellow;
    else if (requestedTempGetter() <= maxOrange) returnColor = Colors.orange;
    return returnColor;
  }

  Color findInActiveColor() {
    Color returnColor = Colors.red;
    if (requestedTempGetter() <= maxBlue)
      returnColor = Colors.amber;
    else if (requestedTempGetter() <= maxYellow)
      returnColor = Colors.orange;
    else if (requestedTempGetter() <= maxOrange) returnColor = Colors.red;
    return returnColor;
  }

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
          child: Text('10',
              style: Theme.of(context)
                  .textTheme
                  .display1
                  .apply(fontSizeFactor: 0.5)),
        ),
        Flexible(
          flex: 1,
          child: Slider(
            value: requestedTempGetter() >= 10.0? requestedTempGetter() : 10.0,
            min: 10.0,
            max: 25.0,
            divisions: 75,
            activeColor: findActiveColor(),
            inactiveColor: findInActiveColor(),
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
          child: Text('25',
              style: Theme.of(context)
                  .textTheme
                  .display1
                  .apply(fontSizeFactor: 0.5)),
        ),
      ],
    );
  }
}

class LabelWithDoubleStateOrBlank extends StatelessWidget {
  LabelWithDoubleStateOrBlank(
      {@required this.label, @required this.valueGetter, @required this.blank});

  final String label;
  final ValueGetter<double> valueGetter;
  final bool blank;

  @override
  Widget build(BuildContext context) {
    return Opacity (
      opacity: blank ? 0.0 : 1.0,
      child: LabelWithDoubleState(
        label: label,
        valueGetter: valueGetter,
        fontSizeFactor: 0.5,
      ),
    );
  }
}

class LabelWithDoubleState extends StatelessWidget {
  LabelWithDoubleState(
      {@required this.label,
        @required this.valueGetter,
        this.fontSizeFactor = 1.0});

  final String label;
  final ValueGetter<double> valueGetter;
  final double fontSizeFactor;

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
                    style: Theme.of(context)
                        .textTheme
                        .display1
                        .apply(fontSizeFactor: fontSizeFactor),
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
            '${valueGetter().toStringAsFixed(1)}\u00B0C',
            style: Theme.of(context)
                .textTheme
                .display1
                .apply(fontSizeFactor: fontSizeFactor),
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
    TextStyle dispStyle = Theme.of(context).textTheme.display1;
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
//                    style: TextStyle(
//                      fontSize: 18.0,
//                      fontWeight: FontWeight.bold,
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
                            style: dispStyle.apply(
                                color: Colors.green, fontSizeFactor: 0.75),
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
                    '${minsToTemp()}',
                    style: dispStyle.apply(
                        color: Colors.green, fontSizeFactor: 0.75),
                    //            style: TextStyle(
                    //              //color: Colors.grey[500],
                    //              fontSize: 18.0,
                    //            ),
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
