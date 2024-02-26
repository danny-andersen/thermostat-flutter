import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sprintf/sprintf.dart';
import 'package:timeline_tile/timeline_tile.dart';

import 'dropbox-api.dart';

class WhoPage extends StatefulWidget {
  const WhoPage({super.key, required this.oauthToken});

  final String oauthToken;
  @override
  State createState() => WhoPageState(oauthToken: oauthToken);
}

class WhoPageState extends State<WhoPage> {
  WhoPageState({required this.oauthToken});

  final String oauthToken;
  final String deviceChangePattern = "*_device_change.txt";
  String todayFile = "";
  String? selectedDate;
  List<DropdownMenuItem<String>>? changeEntries = [];
  bool enabled = false;
  // List<DataRow> whoByHourRows = List.filled(
  //     0, DataRow(cells: List.filled(0, const DataCell(Text("")))),
  //     growable: true);
  List<DeviceByHour> whoByHourList =
      List.filled(0, DeviceByHour(0, "", false), growable: false);
  List<Row> folderRows = List.filled(
      1,
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
            padding: const EdgeInsets.only(top: 8.0),
            child: const Text(
              'Image folders',
              style: TextStyle(
                fontSize: 20,
                color: Colors.black87,
              ),
            )),
      ]),
      growable: true);

  @override
  void initState() {
    getChangeFileList();
    DateTime now = DateTime.now();
    todayFile = sprintf(
        "%s%02i%02i%s", [now.year, now.month, now.day, "_device_change.txt"]);
    getChangeFile(todayFile);
    super.initState();
  }

  void getChangeFile(String changeFile) {
    // Reset lists
    // whoByHourRows = List.filled(
    //     0, DataRow(cells: List.filled(0, const DataCell(Text("")))),
    //     growable: true);
    // print("Downloading file: $changeFile");
    DropBoxAPIFn.getDropBoxFile(
      oauthToken: oauthToken,
      fileToDownload: "/$changeFile",
      callback: processChangeFile,
      contentType: ContentType.text,
      timeoutSecs: 300,
    );
  }

  void getChangeFileList() {
    DropBoxAPIFn.searchDropBoxFileNames(
        oauthToken: oauthToken,
        filePattern: deviceChangePattern,
        callback: processChangeFileList,
        maxResults: 31);
  }

  void newChangeFileSelected(String? changeFile) {
    if (changeFile != null) {
      // bool inList = false;
      // String dateStr = changeFile.split('_')[0];
      // changeEntries ??= [
      //   DropdownMenuItem<String>(value: changeFile, child: Text(dateStr))
      // ];
      // changeEntries!.forEach((entry) {
      //   if (entry.value == changeFile) inList = true;
      // });
      // if (!inList) {
      //   changeEntries!.add(
      //       DropdownMenuItem<String>(value: changeFile, child: Text(dateStr)));
      // }
      selectedDate = changeFile;
      getChangeFile(changeFile);
    }
  }

  void processChangeFileList(FileListing files) {
    //Process each file and add to dropdown
    List<FileEntry> fileEntries = files.fileEntries;
    List<DropdownMenuItem<String>> entries = List.filled(
        0, const DropdownMenuItem<String>(value: "", child: Text("")),
        growable: true);
    for (var fileEntry in fileEntries) {
      if (!fileEntry.fullPathName.contains("Archive")) {
        String fileName = fileEntry.fileName;
        String dateStr = fileName.split('_')[0];
        entries.add(
            DropdownMenuItem<String>(value: fileName, child: Text(dateStr)));
      }
    }
    String dateStr = todayFile.split('_')[0];
    entries.insert(
        0, DropdownMenuItem<String>(value: todayFile, child: Text(dateStr)));
    if (mounted) {
      setState(() {
        changeEntries = entries;
        enabled = true;
      });
    }
  }

  void processChangeFile(String filename, String contents) {
    List<DeviceByHour> whoList =
        List.filled(0, DeviceByHour(0, "", false), growable: true);
    //Clear existing list
    // whoByHourRows = List.filled(
    //     0, DataRow(cells: List.filled(0, const DataCell(Text("")))),
    //     growable: true);
    // whoByHourList = List.filled(0, WhoByHour("", 0, 0), growable: true);
    Map<String, DeviceByHour> lastDeviceTime = {};
    contents.split('\n').forEach((line) {
      if (line.contains(':Device:')) {
        try {
          List<String> parts = line.split(':');
          String timeStr = parts[0].trim();
          int hours = int.parse(timeStr.substring(0, 2));
          int mins = int.parse(timeStr.substring(2, 4));
          int timeMins = hours * 60 + mins;

          int time = int.parse(timeStr);
          bool event = (parts[2].trim()) == 'New';
          String device = (parts[3].trim());
          DeviceByHour dbh = DeviceByHour(time, device, event);
          if (lastDeviceTime.containsKey(device)) {
            //Filter events that are spurious, which are events that Gone then New
            DeviceByHour? lastTime = lastDeviceTime[device];
            lastTime ??= DeviceByHour(0, "", false);
            String lastTimeStr = formatEventHour(lastTime.hour);
            hours = int.parse("${lastTimeStr}".substring(0, 2));
            mins = int.parse("${lastTimeStr}".substring(3, 5));
            int lastTimeMins = hours * 60 + mins;
            if (timeMins - 11 < lastTimeMins && (event && !lastTime.event)) {
              //Last event was a "Gone" and this event was "New"
              //Cancel out the previous event and dont add this one
              whoList.remove(lastTime);
            } else {
              //Event is OK
              whoList.add(dbh);
            }
          } else {
            whoList.add(dbh);
          }
          lastDeviceTime[device] = dbh;
        } on FormatException {
          print("Received incorrect time format: $line");
        }
      }
    });
    //Process device events into (who, time arrived, time left) tuples
    //Device File is in event time order and so list should be in time order
    //First event for a device should be an arrived event - look for a gone event for the same device
    //Convert to Datarows for display if tab still on display
    // Map<String, int> lastEventForDevice = <String, int>{};
    // for (final who in whoList) {
    //   if (who.event) {
    //     //Arrival
    //     whoByHourList.add(WhoByHour(who.device, who.hour, 0));
    //   } else {
    //     //Leaving - find last event for device and amend the left time
    //     //Note if device hasnt left then leaveTime will remain as 0
    //     for (WhoByHour who2 in whoByHourList) {
    //       if (who2.device == who.device && who2.leaveTime == 0) {
    //         who2.leaveTime = who.hour;
    //         lastEventForDevice[who.device] = who.hour;
    //         break;
    //       }
    //     }
    //   }
    // }
    if (mounted) {
      setState(() {
        whoByHourList = whoList;
        // for (final who in whoByHourList) {
        //   whoByHourRows.add(
        //       who.getDataRow(lastEventForDevice[who.device] == who.leaveTime));
        // }
      });
    }
  }

  String formattedDateStr(String fileName) {
    //Convert yyyymmdd to dd Month Year
    DateTime dateTime = DateTime.parse(fileName.split('_')[0]);
    return DateFormat.yMMMMd("en_US").format(dateTime);
  }

  String formatEventHour(int eventHour) {
    String retStr = "";
    String hourStr = "$eventHour";
    switch (hourStr.length) {
      case 1:
        retStr = "00:0$hourStr";
        break;
      case 2:
        retStr = "00:$hourStr";
        break;
      case 3:
        retStr = "0${hourStr[0]}:${hourStr.substring(1, 3)}";
        break;
      case 4:
        retStr = "${hourStr.substring(0, 2)}:${hourStr.substring(2, 4)}";
        break;
    }
    return retStr;
  }

  Widget createTile(int index) {
    final DeviceByHour event = whoByHourList[index];
    return TimelineTile(
      alignment: TimelineAlign.center,
      // lineXY: 0.1, // Adjust the line position as needed
      isFirst: index == 0,
      axis: TimelineAxis.vertical,
      isLast: index == whoByHourList.length - 1,
      beforeLineStyle: const LineStyle(color: Colors.blue),
      indicatorStyle: IndicatorStyle(
        width: 80,
        height: 50,
        indicator: Container(
          decoration: const BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              formatEventHour(event.hour),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
      startChild: event.event
          ? Card(
              color: Colors.grey[800],
              child: Padding(
                padding: const EdgeInsets.all(5.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      event.device,
                      style: const TextStyle(
                          color: Colors.green,
                          fontSize: 14,
                          fontWeight: FontWeight.bold),
                    ),
                    Text(
                      event.event ? "Arrive" : "Left",
                      style: const TextStyle(
                          color: Colors.green,
                          fontSize: 14,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            )
          : null,
      endChild: event.event
          ? null
          : Card(
              color: Colors.grey[800],
              child: Padding(
                padding: const EdgeInsets.all(5.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      event.device,
                      style: const TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                          fontWeight: FontWeight.bold),
                    ),
                    Text(
                      event.event ? "Arrive" : "Left",
                      style: const TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> listChildren = [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Who\'s home on ${(selectedDate != null ? formattedDateStr(selectedDate!) : formattedDateStr(todayFile))}',
              style: const TextStyle(
                fontSize: 20,
                color: Colors.grey,
              ),
            )),
      ]),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.only(left: 8.0, top: 15.0, right: 10.0),
          child: Text(
            'Choose date:   ',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        Container(
          padding: const EdgeInsets.only(top: 15.0, right: 8.0),
          width: 100.0,
          height: 50.0,
          child: DropdownButton<String>(
            items: changeEntries,
            onChanged: enabled ? newChangeFileSelected : null,
            elevation: 20,
            isExpanded: true,
            value: selectedDate,
            isDense: false,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ]),
    ];
    for (int i = 0; i < whoByHourList.length; i++) {
      listChildren.add(Row(children: [Expanded(child: createTile(i))]));
    }

    Widget returnWidget = ListView(
      scrollDirection: Axis.vertical,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(5.0),
      // shrinkWrap: true,
      children: listChildren,
    );

    return returnWidget;
  }
}

//Used to represent a device arrival or departure times
class DeviceByHour {
  final int hour; //Hours and mins time of day
  final String device; //device at this time
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
  DataRow getDataRow(bool lastEvent) {
    //lastEvent is true if last time device had an event
    //if it was a leave event show in red, else its an amber
    List<DataCell> cells = List.filled(3, const DataCell(Text("")));
    TextStyle rowStyle = TextStyle(
        color: (leaveTime == 0
            ? Colors.green
            : (lastEvent ? Colors.red : Colors.amber)),
        fontWeight: (leaveTime == 0 || lastEvent
            ? FontWeight.bold
            : FontWeight.normal));
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
  }
}
