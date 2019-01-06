/// Line chart example
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/material.dart';
import 'dart:io';
import 'dropbox-api.dart';

//A schedule day
class ScheduleDay {
  final String dayRange; //e.g. Mon-Fri
  final TimeOfDay start; // Start time in the day of this schedule
  final TimeOfDay end; //End time
  final double temperature; //Temperature to set during the schedule
  ScheduleDay(this.dayRange, this.start, this.end, this.temperature);
}

//Schdule is a list of days
class Schedule {
  final ScheduleEntry file;
  final List<ScheduleDay> days;
  Schedule(this.file, this.days);
  factory Schedule.fromFile(ScheduleEntry file, String contents) {
    List<ScheduleDay> entries = List();
    print (contents);
    contents.split('\n').forEach((line) {
      var fields = line.split(',');
      if (fields.length == 4) {
        String day = fields[0];
        print("start: ${fields[1]} hour ${fields[1].substring(
            0, 2)} min ${fields[1].substring(2, 4)}");
        TimeOfDay start = TimeOfDay(hour: int.parse(fields[1].substring(0, 2)),
            minute: int.parse(fields[1].substring(2, 4)));
        TimeOfDay end = TimeOfDay(hour: int.parse(fields[2].substring(0, 2)),
            minute: int.parse(fields[2].substring(2, 4)));
        double temp = double.parse(fields[3]);
        entries.add(ScheduleDay(day, start, end, temp));
      }
    });
  return Schedule(file, entries);
        }
}

//Details of the file holding schedule details
class ScheduleEntry {
  final FileEntry fileListing;
  final String name;
  ScheduleEntry(this.fileListing, this.name);
  factory ScheduleEntry.fromFileEntry(FileEntry fileEntry) {
    String fn = fileEntry.fileName;
    List<String> parts = fn.split('setSchedule.txt.');
    String n = parts[1];
    return ScheduleEntry(fileEntry, n);
  }
}

class SchedulePage extends StatefulWidget {
  SchedulePage({@required this.oauthToken});

  final String oauthToken;

  @override
  State createState() => SchedulePageState(oauthToken: this.oauthToken);
}

class SchedulePageState extends State<SchedulePage> {
  SchedulePageState({@required this.oauthToken});

  final String oauthToken;
  final String scheduleFilesPattern = "setSchedule.txt.";

  List<Schedule> schedules;
  HttpClient httpClient = new HttpClient();
  ScheduleEntry selectedScheduleEntry;
  List<DropdownMenuItem<ScheduleEntry>> scheduleEntries;
  Schedule selectedSchedule;
  List<DropdownMenuItem<ScheduleDay>> scheduleDays;
  ScheduleDay selectedDay;

  @override
  void initState() {
    getSchedules();
    super.initState();
  }

  void getSchedules() {
    DropBoxAPIFn.searchDropBoxFileNames(
        client: httpClient,
        oauthToken: oauthToken,
        filePattern: scheduleFilesPattern,
        callback: processScheduleFiles);
  }

  void processScheduleFiles(FileListing files) {
    //Process each file and add to dropdown
    this.scheduleEntries = List();
    for (FileEntry file in files.fileEntries) {
//      print("Adding ${file.fileName}");
      ScheduleEntry schedule = ScheduleEntry.fromFileEntry(file);
      this.scheduleEntries.add(DropdownMenuItem<ScheduleEntry>(
        value: schedule,
        child: new Text(schedule.name),
      ));
    }
  }

  void scheduleSelected(ScheduleEntry scheduleEntry) {
//    print('Selected ${scheduleEntry.name}');
    DropBoxAPIFn.getDropBoxFile(
        client: this.httpClient,
        oauthToken: this.oauthToken,
        fileToDownload: scheduleEntry.fileListing.fullPathName,
        callback: processScheduleFile,
    );
    setState(() {
      this.scheduleDays = null;
      this.selectedScheduleEntry = scheduleEntry;
    });
  }

  void daySelected(ScheduleDay day) {
    setState(() {
      this.selectedDay = day;
    });
  }

  void processScheduleFile(String contents) {
    setState(() {
      this.selectedSchedule = Schedule.fromFile(this.selectedScheduleEntry, contents);
      this.scheduleDays = List();
      for (ScheduleDay day in this.selectedSchedule.days)
        this.scheduleDays.add(DropdownMenuItem<ScheduleDay>(
          value: ScheduleDay(day.dayRange, day.start, day.end, day.temperature),
          child: new Text(day.dayRange),
        ));
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget returnWidget = ListView(children: [
      Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.only(top: 10.0, bottom: 16.0),
              child: Text(
                'Select Saved Schedule to modify:',
                style: Theme.of(context).textTheme.title,
              ),
            ),
            Container(
              padding: const EdgeInsets.only(left: 20.0, right: 20.0),
              child: DropdownButton<ScheduleEntry>(
                items: scheduleEntries,
                onChanged: scheduleSelected,
                elevation: 25,
                isExpanded: true,
                value: this.selectedScheduleEntry,
                isDense: true,
                style: Theme.of(context).textTheme.subtitle,
              ),
            ),
          ]),
      Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.only(top: 10.0, bottom: 16.0),
              child: Text(
                'Select Day Range to show:',
                style: Theme.of(context).textTheme.title,
              ),
            ),
            Container(
              padding: const EdgeInsets.only(left: 20.0, right: 20.0),
              child: DropdownButton<ScheduleDay>(
                items: scheduleDays,
                onChanged: daySelected,
                elevation: 25,
                isExpanded: true,
                value: this.selectedDay,
                isDense: true,
                style: Theme.of(context).textTheme.subtitle,
              ),
            ),
          ]),
    ]);
//      ],
//    );
    return returnWidget;
  }
}

class PointsLineChart extends StatelessWidget {
  final List<charts.Series> seriesList;
  final bool animate;

  PointsLineChart(this.seriesList, {this.animate});

  /// Creates a [LineChart] with sample data and no transition.
  factory PointsLineChart.withSampleData() {
    return new PointsLineChart(
      _createSampleData(),
      // Disable animations for image tests.
      animate: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return new charts.LineChart(seriesList,
        animate: animate,
        defaultRenderer: new charts.LineRendererConfig(includePoints: true));
  }

  /// Create one series with sample hard coded data.
  static List<charts.Series<LinearSales, int>> _createSampleData() {
    final data = [
      new LinearSales(0, 5),
      new LinearSales(1, 25),
      new LinearSales(2, 100),
      new LinearSales(3, 75),
    ];

    return [
      new charts.Series<LinearSales, int>(
        id: 'Sales',
        colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
        domainFn: (LinearSales sales, _) => sales.year,
        measureFn: (LinearSales sales, _) => sales.sales,
        data: data,
      )
    ];
  }
}

/// Sample linear data type.
class LinearSales {
  final int year;
  final int sales;

  LinearSales(this.year, this.sales);
}
