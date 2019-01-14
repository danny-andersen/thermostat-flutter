/// Line chart example
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dropbox-api.dart';
import 'schedule.dart';

class SchedulePage extends StatefulWidget {
  SchedulePage({@required this.client, @required this.oauthToken});

  final String oauthToken;
  final HttpClient client;

  @override
  State createState() =>
      SchedulePageState(client: this.client, oauthToken: this.oauthToken);
}

class SchedulePageState extends State<SchedulePage> {
  SchedulePageState({@required this.client, @required this.oauthToken});

  final String oauthToken;
  final HttpClient client;
  final String scheduleFilesPattern = "setSchedule.txt.";
  final String currentScheduleFile = "setSchedule.txt.current";
  String currentSchedulePath;

  List<Schedule> schedules;
  HttpClient httpClient = new HttpClient();
  ScheduleEntry selectedScheduleEntry;
  List<DropdownMenuItem<ScheduleEntry>> scheduleEntries;
  Schedule selectedSchedule;
  List<DropdownMenuItem<String>> scheduleDays;
  String selectedDayRange;
  List<charts.Series> hourTempSeries;
  bool showNowEnabled = false;
  bool showNowSchedulePressed = false;

  @override
  void initState() {
    getSchedules();
    showNowEnabled = false;
    hourTempSeries = PointsLineChart.createSeries(
        [TempByHour(0, 10.0), TempByHour(2400, 10.0)]);
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
    setState(() {
      for (FileEntry file in files.fileEntries) {
//      print("Adding ${file.fileName}");
        ScheduleEntry schedule = ScheduleEntry.fromFileEntry(file);
        this.scheduleEntries.add(DropdownMenuItem<ScheduleEntry>(
              value: schedule,
              child: new Text(schedule.name),
            ));
        if (file.fileName.compareTo(currentScheduleFile) == 0) {
          this.currentSchedulePath = file.fullPathName;
          this.selectedScheduleEntry = schedule;
        }
      }
      showNowEnabled = true;
    });
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
    if (showNowSchedulePressed) {
      daySelected(ScheduleDay.weekDaysByInt[DateTime.now().weekday]);
      showNowSchedulePressed = false;
    }
  }

  void daySelected(String day) {
    setState(() {
      this.selectedDayRange = day;
      generateHourTempSeries(day);
    });
  }

  //Process schedule for selected day to create Series to plot
  void generateHourTempSeries(String day) {
    List<ScheduleDay> dayEntries =
        this.selectedSchedule.filterEntriesByDayRange(day);
    List<TempByHour> tempPoints =
        Schedule.generateTempByHourForEntries(dayEntries);
//    tempPoints.forEach((th) => print("Time: ${th.hour} Temp: ${th.temperature}"));
    hourTempSeries = PointsLineChart.createSeries(tempPoints);
  }

  void showNowSchedule() {
    showNowSchedulePressed = true;
    DropBoxAPIFn.getDropBoxFile(
      client: this.httpClient,
      oauthToken: this.oauthToken,
      fileToDownload: currentSchedulePath,
      callback: processScheduleFile,
    );
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
            padding: const EdgeInsets.only(top: 10.0),
            child: RaisedButton(
              child: Text('Show current schedule'),
              elevation: 5,
              onPressed: showNowEnabled ? showNowSchedule : null,
//              color: Colors.blue,
            ),
          )
        ],
      ),
      Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.only(top: 10.0, bottom: 16.0),
              child: Text(
                'Or select a schedule to view/modify:',
                style: Theme.of(context).textTheme.body1,
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
                style: Theme.of(context).textTheme.body1,
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
    int nowTime = TempByHour.from(DateTime.now(),0.0).hour;
    lines.add(new charts.LineAnnotationSegment(
        nowTime, charts.RangeAnnotationAxisType.domain,
        strokeWidthPx: 30,
//        color: charts.Color.fromHex('#ff0000');,
        startLabel: domainFormat.format(nowTime)));
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
