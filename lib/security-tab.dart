import 'package:flutter/material.dart';
import 'package:sprintf/sprintf.dart';

import 'dropbox-api.dart';
import 'schedule.dart';

class SecurityPage extends StatefulWidget {
  SecurityPage({required this.oauthToken});

  final String oauthToken;
  @override
  State createState() => SecurityPageState(oauthToken: this.oauthToken);
}

class SecurityPageState extends State<SecurityPage> {
  SecurityPageState({required this.oauthToken});

  final String oauthToken;
  final String deviceChangePattern = "_device_change.txt";
  String todayFile = "";
  List<DataRow> whoByHourRows = List.filled(
      0, DataRow(cells: List.filled(0, const DataCell(Text("")))),
      growable: true);

  @override
  void initState() {
    DateTime now = DateTime.now();
    todayFile = sprintf(
        "%s%02i%02i%s", [now.year, now.month, now.day, deviceChangePattern]);
    getTodaysFile();
    super.initState();
  }

  void getTodaysFile() {
    getChangeFile(todayFile);
  }

  void getChangeFile(String changeFile) {
    // Reset lists
    whoByHourRows = List.filled(
        0, DataRow(cells: List.filled(0, const DataCell(Text("")))),
        growable: true);
    // print("Downloading file: $changeFile");
    DropBoxAPIFn.getDropBoxFile(
        oauthToken: oauthToken,
        fileToDownload: "/$changeFile",
        callback: processChangeFile);
  }

  void processChangeFile(String contents) {
    List<DeviceByHour> whoList =
        List.filled(0, DeviceByHour(0, "", false), growable: true);

    contents.split('\n').forEach((line) {
      if (line.contains(':Device:')) {
        try {
          List<String> parts = line.split(':');
          int time = int.parse(parts[0].trim());
          bool event = (parts[2].trim()) == 'New';
          String device = (parts[3].trim());
          whoList.add(DeviceByHour(time, device, event));
        } on FormatException {
          print("Received incorrect time format: $line");
        }
      }
    });
    //Process device events into (who, time arrived, time left) tuples
    //Device File is in event time order and so list should be in time order
    //First event for a device should be an arrived event - look for a gone event for the same device
    List<WhoByHour> whoByHourList =
        List.filled(0, WhoByHour("", 0, 0), growable: true);

    for (final who in whoList) {
      if (who.event) {
        //Arrival
        whoByHourList.add(WhoByHour(who.device, who.hour, 0));
      } else {
        //Leaving - find last event for device and amend the left time
        //Note if device hasnt left then leaveTime will remain as 0
        for (WhoByHour who2 in whoByHourList) {
          if (who2.device == who.device && who2.leaveTime == 0) {
            who2.leaveTime = who.hour;
            break;
          }
        }
      }
    }
    //Convert to Datarows for display if tab still on display
    if (mounted) {
      setState(() {
        for (final who in whoByHourList) {
          whoByHourRows.add(who.getDataRow());
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget returnWidget = ListView(children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Who\'s home',
              style: TextStyle(
                fontSize: 24,
                color: Colors.black87,
              ),
            )),
      ]),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
            padding: const EdgeInsets.only(top: 8.0),
            child: DataTable(
                horizontalMargin: 3,
                columnSpacing: 10,
                columns: [
                  DataColumn(label: Text("Who")),
                  DataColumn(label: Text("Time Arrived")),
                  DataColumn(label: Text("Time Left"))
                ],
                rows: whoByHourRows)),
      ]),
    ]);
//      ],
//    );
    return returnWidget;
  }
}

//Used to represent a device arrival or departure times
class DeviceByHour {
  final int hour; //Hours and mins time of day
  final String device; //temperature at this time
  final bool event; //true if arrived/new, false if left / gone
  DeviceByHour(this.hour, this.device, this.event);
  // factory DeviceByHour.from(DateTime time, String dev, String ev) {
  //   String tStr = sprintf("%2i%02i", [time.hour, time.minute]);
  //   int hour = int.parse(tStr);
  //   bool event = (ev == 'New');
  //   return DeviceByHour(hour, dev, event);
  // }
}

//Used to represent a device arrival or departure times
class WhoByHour {
  final String device; //temperature at this time
  final int arriveTime; //Hours and mins time of day
  int leaveTime; //true if arrived/new, false if left / gone

  WhoByHour(this.device, this.arriveTime, this.leaveTime);
  DataRow getDataRow() {
    List<DataCell> cells = List.filled(3, DataCell(Text("")));
    TextStyle rowStyle = TextStyle(
        color: (leaveTime == 0 ? Colors.red : Colors.green),
        fontWeight: (leaveTime == 0 ? FontWeight.bold : FontWeight.normal));
    cells[0] = DataCell(Text(device, style: rowStyle));
    cells[1] = DataCell(Text(
        sprintf("%02i:%02i", [getHour(arriveTime), getMin(arriveTime)]),
        style: rowStyle));
    if (leaveTime != 0) {
      cells[2] = DataCell(Text(
          sprintf("%02i:%02i", [getHour(leaveTime), getMin(leaveTime)]),
          style: rowStyle));
    }
    return DataRow(cells: cells);
  }

  static getHour(int time) {
    return time ~/ 100;
  }

  static getMin(int time) {
    return time % 100;
    ;
  }
}
