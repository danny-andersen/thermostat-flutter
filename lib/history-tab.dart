import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/material.dart';
import 'dart:io';
import 'dropbox-api.dart';
import 'schedule.dart';
import 'package:sprintf/sprintf.dart';
import 'package:intl/intl.dart';

class HistoryPage extends StatefulWidget {
  HistoryPage({@required this.client, @required this.oauthToken});

  final String oauthToken;
  final HttpClient client;

  @override
  State createState() =>
      HistoryPageState(client: this.client, oauthToken: this.oauthToken);
}

class HistoryPageState extends State<HistoryPage> {
  HistoryPageState({@required this.client, @required this.oauthToken});

  final String oauthToken;
  final HttpClient client;
  final String deviceChangePattern = "_device_change.txt";

  HttpClient httpClient = new HttpClient();
  List<DropdownMenuItem<String>> changeEntries;
  String todayFile;
  bool enabled = false;
  charts.Series<TempByHour, int> measuredTempSeries;
  List<charts.Series<TempByHour, int>> chartsToPlot;
  List<TempByHour> temperatureList;
  String selectedDate;

  @override
  void initState() {
    measuredTempSeries = HistoryLineChart.createMeasuredSeries([TempByHour(0, 10.0), TempByHour(2400, 10.0)]);
    chartsToPlot = [measuredTempSeries];
    DateTime now = DateTime.now();
    this.todayFile = sprintf("%s%02i%02i%s", [now.year, now.month, now.day, deviceChangePattern]);
    getChangeFileList();
//    this.scheduleEntries = List();
//    this.scheduleEntries.add(DropdownMenuItem<ScheduleEntry>(value: null, child: Text('     ')));
//    this.scheduleDays = List();
//    this.scheduleDays.add(DropdownMenuItem<String>(value: null, child: Text('     ')));
//    this.timeRanges = List();
//    this.timeRanges.add(DropdownMenuItem<ScheduleDay>(value: null, child: Text('     ')));
    super.initState();
  }

  void getTodaysFile() {
    temperatureList = List();
    this.selectedDate = todayFile;
    getChangeFile(todayFile);
  }

  void getChangeFile(String changeFile) {
    print("Downloading file: $changeFile");
    DropBoxAPIFn.getDropBoxFile(
        client: this.client,
        oauthToken: this.oauthToken,
        fileToDownload: "/" + changeFile,
        callback: processChangeFile);
  }

  void newChangeFileSelected(String changeFile) {
    this.temperatureList = List();
    this.selectedDate = changeFile;
    getChangeFile(changeFile);
  }

  void processChangeFile(String contents) {
//    double lastTemp = 10.0;
    contents.split('\n').forEach((line) {
      if (line.contains(':Temp:')) {
        try {
          List<String> parts = line.split(':');
          int hour = int.parse(parts[0].trim());
          double temp = double.parse(parts[2].trim());
          this.temperatureList.add(TempByHour(hour, temp));
//          lastTemp = temp;
        } on FormatException {
          print("Received incorrect temp format: $line");
        }
      }
    });
//    //Extend measured graph to current time
//    if (lastTemp != 10.0) {
//      DateTime now = DateTime.now();
//      int nowHour =  (now.hour * 100) + now.minute;
//      tempList.add(TempByHour(nowHour, lastTemp));
//    }
    measuredTempSeries = HistoryLineChart.createMeasuredSeries(this.temperatureList);
    print ("Plotting chart");
    setState(() {
      //Convert temperatures to the series
      chartsToPlot = [measuredTempSeries];
    });
  }

  void getChangeFileList() {
    DropBoxAPIFn.searchDropBoxFileNames(
        client: httpClient,
        oauthToken: oauthToken,
        filePattern: deviceChangePattern,
        callback: processChangeFileList,
        maxResults: 14
    );
  }

  String formattedDateStr(String fileName) {
    //Convert yyyymmdd to dd Month Year
    String retStr;
    if (fileName != null) {
      DateTime dateTime = DateTime.parse(fileName.split('_')[0]);
      retStr = new DateFormat.yMMMMd("en_US").format(dateTime);
    }
    return retStr;
  }
  
  void processChangeFileList(FileListing files) {
    //Process each file and add to dropdown
    List<DropdownMenuItem<String>> entries = List();
    for (FileEntry file in files.fileEntries) {
      //Get date of file and add to drop down
      String dateStr = formattedDateStr(file.fileName);
//      String dateStr = file.fileName.split('_')[0];
      print("Adding ${file.fileName}");
      entries.add(DropdownMenuItem<String>(
        value: file.fileName,
        child: new Text(dateStr),
      ));
    }
    setState(() {
      this.changeEntries = entries;
      enabled = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget returnWidget = ListView(children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
            padding: const EdgeInsets.only(top: 8.0),
            child: RaisedButton(
              child: Text('Show today'),
              elevation: 5,
              onPressed: this.enabled ? getTodaysFile : null,
//              color: Colors.blue,
            )),
      ]),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Container(
          padding: const EdgeInsets.only(left: 8.0, top: 15.0, right: 10.0),
          child: Text(
            'Or select a previous day::',
            style: Theme.of(context).textTheme.body1,
          ),
        ),
        Container(
          padding: const EdgeInsets.only(top:15.0, right: 8.0),
          width: 100.0,
          height: 50.0,
          child: DropdownButton<String>(
            items: changeEntries,
            onChanged: enabled ? newChangeFileSelected : null,
            elevation: 20,
            isExpanded: true,
            value: this.selectedDate,
            isDense: false,
            style: Theme.of(context).textTheme.body1,
          ),
        ),
      ]),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Container(
      padding: const EdgeInsets.only(left: 8.0, top: 15.0, right: 10.0),
      child: Text(
        "Temperature Chart of " + formattedDateStr(this.selectedDate) ,
        style: Theme.of(context).textTheme.title,
        ),
      )]),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.only(left: 3.0, top: 20.0, right: 0.0),
            height: 300.0,
            width: MediaQuery.of(context).size.width,
            //            child: TimeSeriesRangeAnnotationMarginChart.withSampleData(),
            child:
                HistoryLineChart(this.chartsToPlot, null),
          ),
        ],
      ),
    ]);
//      ],
//    );
    return returnWidget;
  }
}

class HistoryLineChart extends StatelessWidget {
  final List<charts.Series> seriesList;
  final Function onSelectionChanged;

  HistoryLineChart(this.seriesList, this.onSelectionChanged);

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

//  charts.RangeAnnotation getRangeAnnotation() {
//    double minValue = getMinValue();
//    List<charts.LineAnnotationSegment> lines = List();
//    int nowTime = TempByHour.from(DateTime.now(), 0.0).hour;
//    lines.add(new charts.LineAnnotationSegment(
//      nowTime,
//      charts.RangeAnnotationAxisType.domain,
//      color: charts.MaterialPalette.red.shadeDefault,
//      startLabel: TempByHour.hourFormat.format(nowTime),
//      labelAnchor: charts.AnnotationLabelAnchor.middle,
//    ));
//    for (charts.Series s in this.seriesList)
//      if (s.id.contains("Scheduled")) {
//        for (TempByHour point in s.data)
//          if (point.temperature != minValue)
//            lines.add(new charts.LineAnnotationSegment(
//                point.hour, charts.RangeAnnotationAxisType.domain,
//                startLabel: TempByHour.hourFormat.format(point.hour)));
//      }
//    return new charts.RangeAnnotation(lines);
//  }

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
//      behaviors: [
//        getRangeAnnotation(),
//      ],
    );
  }

  static charts.Series<TempByHour, int> createMeasuredSeries(
      List<TempByHour> timeTempPoints) {
    int len = timeTempPoints.length;
    print ("Creating new chart with $len");
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

}
