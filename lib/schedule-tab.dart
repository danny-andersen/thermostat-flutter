/// Line chart example
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dropbox-api.dart';
import 'package:sprintf/sprintf.dart';

//
class TempByHour {
  final int hour;
  final double temperature;
  TempByHour(this.hour, this.temperature);
  factory TempByHour.from(DateTime time, temp) {
    String tStr = sprintf("%2i%02i", [time.hour, time.day]);
    int hour = int.parse(tStr);
    return TempByHour(hour, temp);
  }
}

//A schedule entry. This represents the temperature to set the thermostat
//for a particular time range on a particular set of days
//It may be overwritten by a more specific entry, e.g. one for a particular day rather than day range
class ScheduleDay {
  final String dayRange; //e.g. Mon-Fri
  final DateTime start; // Start time in the day of this schedule
  final DateTime end; //End time
  final double temperature; //Temperature to set during the schedule
  ScheduleDay(this.dayRange, this.start, this.end, this.temperature);

  //Determine if the given day (or dayRange) is in the range of this entry
  bool isDayInRange(String day) {
    bool isInRange = false;
    if (day == this.dayRange) isInRange = true;
    else if (dayRangeDays.keys.contains(this.dayRange) && daysofWeek.contains(day)) {
      //Its a single day and we are a dayrange
      isInRange = dayRangeDays[this.dayRange].contains(day);
    }
    return isInRange;
  }

  //The more days the schedule entry covers, the less its precedence
  //in other words a schedule entry that specifies the temperature at a time on a Monday only
  //has a higher precedence than one that specified a temperature for the same time but for a day range, say Mon-Fri
  int getPrecedence() {
    int precedence = 99;
    if (dayRangeDays.containsKey(this.dayRange)) {
      precedence = dayRangeDays[this.dayRange].length;
    } else if (daysofWeek.contains(this.dayRange)) {
      precedence = 1;
    } else {
      throw new FormatException("Day range in schedule not recognised: $this.dayRange");
    }
    return precedence;
  }

  static final Map<String, List<String>> dayRangeDays = {
    'Mon-Sun': ['Mon', 'Tues', 'Wed', 'Thurs', 'Fri', 'Sat', 'Sun'],
    'Mon-Fri': [
      'Mon',
      'Tues',
      'Wed',
      'Thurs',
      'Fri',
    ],
    'Sat-Sun': ['Sat', 'Sun'],
  };

  static final List<String> daysofWeek = [
    'Sun',
    'Mon',
    'Tues',
    'Wed',
    'Thurs',
    'Fri',
    'Sat'
  ];
}

//Schedule is a simple list of ScheduleDay entries
class Schedule {
  //The dropbox file holding this schedule
  final ScheduleEntry file;
  //Each schedule consists of a list of <dayrange>,<start>,<stop>,<temp> tuples
  final List<ScheduleDay> days;

  Schedule(this.file, this.days);

  factory Schedule.fromFile(ScheduleEntry file, String contents) {
    List<ScheduleDay> entries = List();
//    print (contents);
    contents.split('\n').forEach((line) {
      var fields = line.split(',');
      if (fields.length == 4) {
        String day = fields[0];
//        print("start: ${fields[1]} hour ${fields[1].substring(
//            0, 2)} min ${fields[1].substring(2, 4)}");        retEntries

        DateTime start = DateTime(2000, 1, 1,
            int.parse(fields[1].substring(0, 2)),
            int.parse(fields[1].substring(2, 4)));
        DateTime end = DateTime(2000, 1, 1,
            int.parse(fields[2].substring(0, 2)),
            int.parse(fields[2].substring(2, 4)));
        double temp = double.parse(fields[3]);
        entries.add(ScheduleDay(day, start, end, temp));
      }
    });
    return Schedule(file, entries);
  }

  //Returns the list of schedule entries that match this dayrange (or day)
  List<ScheduleDay> filterEntriesByDayRange(String dayRange) {
    List<ScheduleDay> dayEntries = List();
    for (ScheduleDay day in this.days) {
      if (day.isDayInRange(dayRange)) dayEntries.add(day);
    }
    return dayEntries;
  }

  //For each 15 mins, work out what the temperature is for the filtered list given
  static List<TempByHour> generateTempByHourForEntries(List<ScheduleDay> entries) {
    DateTime currentTime = DateTime(2000);
    DateTime end = DateTime(2000, 1,1, 24, 1);
    //Sort entries by precedence so that most precedence (lower number) is last
    entries.sort((a, b) => b.getPrecedence().compareTo(a.getPrecedence()));
    List<TempByHour> retEntries = List();
    double currentTemp = getCurrentTemp(currentTime, entries);
    retEntries.add(TempByHour.from(currentTime, currentTemp));
    do {
      DateTime newTime = currentTime.add(Duration(minutes: 5));
      double newTemp = getCurrentTemp(newTime, entries);
      if (newTemp != currentTemp) {
        //Create an entry at old temp and new temp
        retEntries.add(TempByHour.from(currentTime, currentTemp));
        retEntries.add(TempByHour.from(newTime, newTemp));
      }
      currentTime = newTime;
      currentTemp = newTemp;
    } while (currentTime.isBefore(end));
    return retEntries;
  }

  //Return the current temperature for the given time
  //Sorted entries must be in reverse precedence order
  static double getCurrentTemp(DateTime now, List<ScheduleDay> sortedEntries) {
    double retTemp = 10.0;
    sortedEntries.forEach((entry) {
      if (now.isAfter(entry.start) && now.isBefore(entry.end)) {
        retTemp = entry.temperature;
      }
    });
    return retTemp;
  }
}

//Details of the file holding schedule details
class ScheduleEntry {
  //Dropbox file entry details
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
  SchedulePage({@required this.client, @required this.oauthToken});

  final String oauthToken;
  final HttpClient client;

  @override
  State createState() => SchedulePageState(client: this.client, oauthToken: this.oauthToken);
}

class SchedulePageState extends State<SchedulePage> {
  SchedulePageState({@required this.client, @required this.oauthToken});

  final String oauthToken;
  final HttpClient client;
  final String scheduleFilesPattern = "setSchedule.txt.";

  List<Schedule> schedules;
  HttpClient httpClient = new HttpClient();
  ScheduleEntry selectedScheduleEntry;
  List<DropdownMenuItem<ScheduleEntry>> scheduleEntries;
  Schedule selectedSchedule;
  List<DropdownMenuItem<String>> scheduleDays;
  String selectedDayRange;
  List<charts.Series> hourTempSeries;

  @override
  void initState() {
    getSchedules();
    hourTempSeries = PointsLineChart.createSeries([TempByHour(0, 10.0), TempByHour(2400, 10.0)]);
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
      setState(() {
        this.scheduleEntries.add(DropdownMenuItem<ScheduleEntry>(
          value: schedule,
          child: new Text(schedule.name),
        ));
      });
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

  void processScheduleFile(String contents) {
    setState(() {
      this.selectedSchedule =
          Schedule.fromFile(this.selectedScheduleEntry, contents);
      this.scheduleDays = List();
      Set<String> dayRangeSet = Set();
      for (ScheduleDay day in this.selectedSchedule.days)
        dayRangeSet.add(day.dayRange);
      for (String day in ScheduleDay.daysofWeek) dayRangeSet.add(day);
      for (String dayRange in dayRangeSet)
        this.scheduleDays.add(DropdownMenuItem<String>(
              value: dayRange,
              child: new Text(dayRange),
            ));
    });
  }

  void daySelected(String day) {
    setState(() {
      this.selectedDayRange = day;
      generateHourTempSeries(day);
    });
  }


  //Process schedule for selected day to create Series to plot
  void generateHourTempSeries(String day) {
    List<ScheduleDay> dayEntries = this.selectedSchedule.filterEntriesByDayRange(day);
    List<TempByHour> tempPoints = Schedule.generateTempByHourForEntries(dayEntries);
    hourTempSeries = PointsLineChart.createSeries(tempPoints);
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
                'Select Saved Schedule to view/modify:',
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
              padding:
                  const EdgeInsets.only(left: 20.0, right: 20.0, bottom: 30.0),
              child: DropdownButton<String>(
                items: scheduleDays,
                onChanged: daySelected,
                elevation: 25,
                isExpanded: true,
                value: this.selectedDayRange,
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
            height: 300.0,
//            child: TimeSeriesRangeAnnotationMarginChart.withSampleData(),
            child: PointsLineChart(this.hourTempSeries),
          ),
        ],
      ),
    ]);
//      ],
//    );
    return returnWidget;
  }
}

class PointsLineChart extends StatelessWidget {
  final List<charts.Series> seriesList;
  final bool animate;

  static final NumberFormat domainFormat = new NumberFormat('0000', 'en_US');

  PointsLineChart(this.seriesList, {this.animate});

  /// Creates a [LineChart] with sample data and no transition.
  factory PointsLineChart.withSampleData() {
    return new PointsLineChart(
      _createSampleData(),
      // Disable animations for image tests.
      animate: true,
    );
  }

  double getMaxValue() {
    double maxValue = -999999999.0;
    for (charts.Series s in this.seriesList)
      for (TempByHour point in s.data)
        if (point.temperature > maxValue) maxValue = point.temperature;
    return maxValue;
  }

  double getMinValue() {
    double minValue = 999999999.0;
    for (charts.Series s in this.seriesList)
      for (TempByHour point in s.data)
        if (point.temperature < minValue) minValue = point.temperature;
    return minValue;
  }

  charts.RangeAnnotation getRangeAnnotation() {
    double minValue = getMinValue();
    List<charts.LineAnnotationSegment> lines = List();
    for (charts.Series s in this.seriesList)
      for (TempByHour point in s.data)
        if (point.temperature != minValue)
          lines.add(new charts.LineAnnotationSegment(
              point.hour, charts.RangeAnnotationAxisType.domain,
              startLabel: domainFormat.format(point.hour)));
    return new charts.RangeAnnotation(lines);
  }

  @override
  Widget build(BuildContext context) {
    double maxValue = getMaxValue();
    return new charts.LineChart(
      seriesList,
      animate: animate,
      primaryMeasureAxis: new charts.NumericAxisSpec(
        viewport:
            new charts.NumericExtents(8.0, maxValue > 20.0 ? maxValue : 20.0),
        tickProviderSpec: new charts.BasicNumericTickProviderSpec(
            zeroBound: false, desiredTickCount: 14),
      ),
      domainAxis: new charts.NumericAxisSpec(
        viewport: new charts.NumericExtents(0, 2400),
        tickProviderSpec:
            new charts.BasicNumericTickProviderSpec(desiredTickCount: 10),
        tickFormatterSpec:
            new charts.BasicNumericTickFormatterSpec.fromNumberFormat(
                domainFormat),
      ),
      defaultRenderer: new charts.LineRendererConfig(includePoints: true),
      behaviors: [
        new charts.PanAndZoomBehavior(),
        new charts.SlidingViewport(),
        getRangeAnnotation(),
      ],
    );
  }

  static List<charts.Series<TempByHour, int>> createSeries(
      List<TempByHour> timeTempPoints) {
    return [
      new charts.Series<TempByHour, int>(
        id: 'Temperature',
        colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
        domainFn: (TempByHour tt, _) => tt.hour,
        measureFn: (TempByHour tt, _) => tt.temperature,
        data: timeTempPoints,
      )
    ];
  }

  /// Create one series with sample hard coded data.
  static List<charts.Series<TempByHour, int>> _createSampleData() {
    final data = [
      new TempByHour(900, 17.0),
      new TempByHour(1100, 17.0),
      new TempByHour(1115, 10.0),
      new TempByHour(1629, 10.0),
      new TempByHour(1630, 18.5),
      new TempByHour(2200, 18.5),
      new TempByHour(2201, 10.0),
    ];

    return createSeries(data);
  }
}
