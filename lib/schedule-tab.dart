import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/material.dart';
import 'dart:io';
import 'dropbox-api.dart';
import 'schedule.dart';
import 'package:sprintf/sprintf.dart';

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
  final String deviceChangeFile = "device_change.txt";
  String currentSchedulePath;

  List<Schedule> schedules;
  HttpClient httpClient = new HttpClient();
  ScheduleEntry selectedScheduleEntry;
  List<DropdownMenuItem<ScheduleEntry>> scheduleEntries;
  Schedule selectedSchedule; //The schedule that was selected and graphed
  Schedule newSchedule; //A copy of the selected schedule that has been updated
  List<DropdownMenuItem<String>> scheduleDays; //A list of schedule days from the selected schedule file
  ScheduleDay selectedScheduleTimeRange; //Time range that has been selected to update
  List<DropdownMenuItem<ScheduleDay>> timeRanges; //A list of time ranges in the selected schedule
  String selectedDayRange; //which day reanges has been selecteed
  charts.Series hourTempSeries;
  bool showNowEnabled = false;
  bool showNowSchedulePressed = false;
  charts.Series<TempByHour, int> measuredTempSeries;
  List<charts.Series<TempByHour, int>> chartsToPlot;

  TextEditingController newTempFieldController = TextEditingController();

  @override
  void initState() {
    showNowEnabled = false;
    hourTempSeries = PointsLineChart.createScheduleSeries([TempByHour(0, 10.0), TempByHour(2400, 10.0)], null);
    measuredTempSeries = PointsLineChart.createMeasuredSeries([TempByHour(0, 10.0), TempByHour(2400, 10.0)]);
    chartsToPlot = [hourTempSeries, measuredTempSeries];
    getSchedules();
    getChangeFile();
//    this.scheduleEntries = List();
//    this.scheduleEntries.add(DropdownMenuItem<ScheduleEntry>(value: null, child: Text('     ')));
//    this.scheduleDays = List();
//    this.scheduleDays.add(DropdownMenuItem<String>(value: null, child: Text('     ')));
//    this.timeRanges = List();
//    this.timeRanges.add(DropdownMenuItem<ScheduleDay>(value: null, child: Text('     ')));
    super.initState();
  }

  void getChangeFile() {
    DateTime now = DateTime.now();
    String changeFile = sprintf("/%s%02i%02i_%s", [now.year, now.month, now.day, deviceChangeFile]);
    DropBoxAPIFn.getDropBoxFile(
        client: this.client,
        oauthToken: this.oauthToken,
        fileToDownload: changeFile,
        callback: processChangeFile);
  }

  void processChangeFile(String contents) {
    List<TempByHour> tempList = List();
    double lastTemp = 10.0;
    contents.split('\n').forEach((line) {
      if (line.contains(':Temp:')) {
        try {
          List<String> parts = line.split(':');
          int hour = int.parse(parts[0].trim());
          double temp = double.parse(parts[2].trim());
          tempList.add(TempByHour(hour, temp));
          lastTemp = temp;
        } on FormatException {
          print("Received incorrect temp format: $line");
        }
      }
    });
    //Extend measured graph to current time
    if (lastTemp != 10.0) {
      DateTime now = DateTime.now();
      int nowHour =  (now.hour * 100) + now.minute;
      tempList.add(TempByHour(nowHour, lastTemp));
    }
    measuredTempSeries = PointsLineChart.createMeasuredSeries(tempList);
    setState(() {
      //Convert temperatures to the series
      chartsToPlot = [hourTempSeries, measuredTempSeries];
    });
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
      generateHourTempSeries(this.selectedDayRange );
    });
  }

  void processScheduleFile(String contents) {
    setState(() {
      this.selectedSchedule =
          Schedule.fromFile(this.selectedScheduleEntry, contents);
      this.newSchedule = this.selectedSchedule.copy();
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
      this.timeRanges = getScheduleTimes();
      this.selectedScheduleTimeRange = this.selectedSchedule.filterEntriesByDayRange(day)[0];
//      print (this.selectedScheduleTimeRange .getStartToEndStr());
    });
  }

  void timeRangeSelected(ScheduleDay day) {
    setState(() {
      this.selectedScheduleTimeRange = day;
      this.newTempFieldController.text = day.temperature.toStringAsFixed(1);
      this.newTempFieldController.addListener(newTempSet);
//      print (this.selectedScheduleTimeRange .getStartToEndStr());
    });
  }

  void newTempSet() {
    double newTemp = double.parse(newTempFieldController.text);
    print (newTemp);
//    this.selectedScheduleTimeRange.temperature
  }

  //Process schedule for selected day to create Series to plot
  void generateHourTempSeries(String day) {
    List<ScheduleDay> dayEntries =
        this.selectedSchedule.filterEntriesByDayRange(day);
    List<TempByHour> tempPoints =
        Schedule.generateTempByHourForEntries(dayEntries);
//    tempPoints.forEach((th) => print("Time: ${th.hour} Temp: ${th.temperature}"));
    this.hourTempSeries = PointsLineChart.createScheduleSeries(tempPoints, this.selectedScheduleTimeRange);
    chartsToPlot = [hourTempSeries, measuredTempSeries];
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

  void onChartSelectionChanged(charts.SelectionModel model) {
    final selectedDatum = model.selectedDatum;
    ScheduleDay selectedDay;
    ScheduleDay defaultDay;
    if (selectedDatum.isNotEmpty) {
      String timeStr =
          TempByHour.hourFormat.format(selectedDatum.first.datum.hour);
      DateTime dtime = DateTime(2000, 1, 1, int.parse(timeStr.substring(0, 2)),
          int.parse(timeStr.substring(2, 4)));
      double temp = selectedDatum.first.datum.temperature;
      print('$timeStr : $temp');
      selectedSchedule.filterEntriesByDayRange(this.selectedDayRange).forEach((day) {
      if (day.isInTimeRange(dtime, temp)) {
          selectedDay = day;
        } else if (day.isDefaultTimeRange())
          defaultDay = day;
      });
    }
    if (selectedDay == null) {
      selectedDay = defaultDay;
    }
    setState(() {
      this.selectedScheduleTimeRange = selectedDay;
      this.timeRanges = getScheduleTimes();
//      print (selectedDay.getStartToEndStr());
    });
  }

  List<DropdownMenuItem<ScheduleDay>> getScheduleTimes() {
    List<DropdownMenuItem<ScheduleDay>> retList = List();
    selectedSchedule.filterEntriesByDayRange(this.selectedDayRange).forEach((day) => retList.add(DropdownMenuItem<ScheduleDay>(value: day,
      child: new Text(day.getStartToEndStr()),
    )));
    return retList;
  }

  @override
  Widget build(BuildContext context) {
    Widget returnWidget = ListView(children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
            padding: const EdgeInsets.only(top: 8.0),
            child: RaisedButton(
              child: Text('Show current schedule'),
              elevation: 5,
              onPressed: showNowEnabled ? showNowSchedule : null,
//              color: Colors.blue,
            )),
      ]),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Container(
          padding: const EdgeInsets.only(left: 8.0, top: 15.0, right: 10.0),
          child: Text(
            'Or select a schedule to view/modify:',
            style: Theme.of(context).textTheme.body1,
          ),
        ),
        Container(
          padding: const EdgeInsets.only(top:15.0, right: 8.0),
          width: 100.0,
          height: 24.0,
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
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Container(
          padding: const EdgeInsets.only(left: 8.0, top: 15.0),
          child: Text(
            'Select Day Range to show: ',
            style: Theme.of(context).textTheme.body1,
          ),
        ),
        Container(
          padding: const EdgeInsets.only(right: 8.0,  top: 15.0),
          width: 100.0,
          height: 24.0,
//          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width, maxHeight: 30),
          child: DropdownButton<String>(
            items: this.scheduleDays,
            onChanged: daySelected,
            elevation: 25,
            isExpanded: true,
            value: this.selectedDayRange,
            isDense: false,
            style: Theme.of(context).textTheme.subtitle,
          ),
        ),
      ]),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.only(left: 3.0, top: 20.0, right: 0.0),
            height: 300.0,
            width: MediaQuery.of(context).size.width,
            //            child: TimeSeriesRangeAnnotationMarginChart.withSampleData(),
            child:
                PointsLineChart(this.chartsToPlot, onChartSelectionChanged),
          ),
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.max,
        children: [
          Container(
            padding: const EdgeInsets.only(left: 8.0, top: 15.0),
            child: Text(
              'Selected Time Range: ',
              style: Theme.of(context).textTheme.body1,
            ),
          ),
          Container(
            padding: const EdgeInsets.only(left: 8.0, top: 15.0),
            width: 120.0,
//            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width, minWidth: 50.0),
            child: DropdownButton<ScheduleDay>(
              items: this.timeRanges,
              onChanged: timeRangeSelected,
              elevation: 25,
              isExpanded: true,
              value: this.selectedScheduleTimeRange,
              isDense: true,
              style: Theme.of(context).textTheme.subtitle,
            ),
          ),
          Container(
            padding: const EdgeInsets.only(left: 8.0, top: 15.0, right: 8.0),
            child: Text(
              this.selectedScheduleTimeRange == null ?  '   ': 'Temp: ${this.selectedScheduleTimeRange.temperature}\u00B0C',
              style: Theme.of(context).textTheme.body1,
            ),
          ),
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.max,
        children: [
          Container(
            padding: const EdgeInsets.only(left: 8.0, top: 5.0),
            child: Text(
              'Enter new temperature: ',
              style: Theme.of(context).textTheme.body1,
            ),
          ),
          Container(
            padding: const EdgeInsets.only(left: 8.0, top: 5.0, right: 8.0),
            width: 50.0,
//            height: 40.0,
            child: TextField(
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              style: Theme.of(context).textTheme.body1,

//              decoration: InputDecoration(
////                  border: ,
//                  labelStyle: Theme.of(context).textTheme.subtitle,
//                  labelText: 'Set New Temperature for Time Range:',

              ),
          ),
          Container(
            padding: const EdgeInsets.only(left: 8.0, top: 5.0),
            child: Text(
              '\u00B0C',
              style: Theme.of(context).textTheme.body1,
            ),
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
  final Function onSelectionChanged;

  PointsLineChart(this.seriesList, this.onSelectionChanged);

  /// Creates a [LineChart] with sample data and no transition.
  factory PointsLineChart.withSampleData() {
    return new PointsLineChart(_createSampleData(), null
        // Disable animations for image tests.
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
    int nowTime = TempByHour.from(DateTime.now(), 0.0).hour;
    lines.add(new charts.LineAnnotationSegment(
      nowTime,
      charts.RangeAnnotationAxisType.domain,
      color: charts.MaterialPalette.red.shadeDefault,
      startLabel: TempByHour.hourFormat.format(nowTime),
      labelAnchor: charts.AnnotationLabelAnchor.middle,
    ));
    for (charts.Series s in this.seriesList)
      if (s.id.contains("Scheduled")) {
        for (TempByHour point in s.data)
          if (point.temperature != minValue)
            lines.add(new charts.LineAnnotationSegment(
                point.hour, charts.RangeAnnotationAxisType.domain,
                startLabel: TempByHour.hourFormat.format(point.hour)));
      }
    return new charts.RangeAnnotation(lines);
  }

  @override
  Widget build(BuildContext context) {
    double maxValue = getMaxValue();
    return new charts.LineChart(
      seriesList,
      animate: true,
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
                TempByHour.hourFormat),
      ),
      defaultRenderer: new charts.LineRendererConfig(includePoints: true),
      selectionModels: [
        new charts.SelectionModelConfig(
          type: charts.SelectionModelType.info,
          changedListener: this.onSelectionChanged,
        )
      ],
      behaviors: [
        getRangeAnnotation(),
      ],
    );
  }

  static charts.Series<TempByHour, int> createScheduleSeries(
      List<TempByHour> timeTempPoints,
      ScheduleDay selectedDay) {
    return new charts.Series<TempByHour, int>(
        id: 'Scheduled',
        colorFn: ((TempByHour tempByHour, __) {
      var color;
      DateTime hourTime = ScheduleDay.hourToDateTime(tempByHour.hour);
      if (selectedDay != null && selectedDay.isInTimeRange(hourTime, tempByHour.temperature)) {
        color = charts.MaterialPalette.red.shadeDefault;
      } else {
        color = charts.MaterialPalette.blue.shadeDefault;
      }
        return color;}),
        domainFn: (TempByHour tt, _) => tt.hour,
        measureFn: (TempByHour tt, _) => tt.temperature,
        data: timeTempPoints,
    );
  }

  static charts.Series<TempByHour, int> createMeasuredSeries(
      List<TempByHour> timeTempPoints) {
    return new charts.Series<TempByHour, int>(
        id: 'Measured',
        colorFn: ((TempByHour tempByHour, __) {
          var color;
          color = charts.MaterialPalette.green.shadeDefault;
          return color;}),
        domainFn: (TempByHour tt, _) => tt.hour,
        measureFn: (TempByHour tt, _) => tt.temperature,
        data: timeTempPoints,
    );
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

    return [createScheduleSeries(data, null)];
  }
}
