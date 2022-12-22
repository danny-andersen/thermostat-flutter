import 'package:flutter/material.dart';
import 'package:charts_flutter_new/flutter.dart' as charts;
import 'dropbox-api.dart';
import 'schedule.dart';
import 'package:sprintf/sprintf.dart';
import 'package:intl/intl.dart';

class HistoryPage extends StatefulWidget {
  HistoryPage({required this.oauthToken});

  final String oauthToken;

  @override
  State createState() => HistoryPageState(oauthToken: oauthToken);
}

class HistoryPageState extends State<HistoryPage> {
  HistoryPageState({required this.oauthToken});

  final String oauthToken;
  final String deviceChangePattern = "_device_change.txt";

  // HttpClient httpClient = HttpClient();
  List<DropdownMenuItem<String>>? changeEntries;
  String todayFile = "";
  bool enabled = false;
  charts.Series<TempByHour, int> measuredTempSeries =
      HistoryLineChart.createMeasuredSeries(List.filled(0, TempByHour(0, 0.0)));
  List<charts.Series<TempByHour, int>> chartsToPlot = List.filled(
      0,
      HistoryLineChart.createMeasuredSeries(
          List.filled(0, TempByHour(0, 0.0))));
  List<TempByHour> temperatureList =
      List.filled(0, TempByHour(0, 0.0), growable: true);
  String? selectedDate;

  @override
  void initState() {
    measuredTempSeries = HistoryLineChart.createMeasuredSeries(
        [TempByHour(0, 10.0), TempByHour(2400, 10.0)]);
    chartsToPlot = List.filled(1, measuredTempSeries, growable: true);
    DateTime now = DateTime.now();
    todayFile = sprintf(
        "%s%02i%02i%s", [now.year, now.month, now.day, deviceChangePattern]);
    // selectedDate = sprintf("%s%02i%02i", [now.year, now.month, now.day]);
    getChangeFileList();
    super.initState();
  }

  void getTodaysFile() {
    selectedDate = todayFile;
    getChangeFile(todayFile);
  }

  void getChangeFile(String changeFile) {
    print("Downloading file: $changeFile");
    DropBoxAPIFn.getDropBoxFile(
        oauthToken: oauthToken,
        fileToDownload: "/$changeFile",
        callback: processChangeFile);
  }

  void newChangeFileSelected(String? changeFile) {
    changeFile ??= "Select a file"; //Set to blank if null
    selectedDate = changeFile;
    getChangeFile(changeFile);
  }

  void processChangeFile(String contents) {
//    double lastTemp = 10.0;
    temperatureList = List.filled(0, TempByHour(0, 0.0), growable: true);
    contents.split('\n').forEach((line) {
      if (line.contains(':Temp:')) {
        try {
          List<String> parts = line.split(':');
          int hour = int.parse(parts[0].trim());
          double temp = double.parse(parts[2].trim());
          temperatureList.add(TempByHour(hour, temp));
//          lastTemp = temp;
        } on FormatException {
          print("Received incorrect temp format: $line");
        }
      }
    });
    measuredTempSeries = HistoryLineChart.createMeasuredSeries(temperatureList);
    // print("Plotting chart");
    setState(() {
      //Convert temperatures to the series
      chartsToPlot = [measuredTempSeries];
    });
  }

  void getChangeFileList() {
    DropBoxAPIFn.searchDropBoxFileNames(
        oauthToken: oauthToken,
        filePattern: deviceChangePattern,
        callback: processChangeFileList,
        maxResults: 31);
  }

  String formattedDateStr(String fileName) {
    //Convert yyyymmdd to dd Month Year
    DateTime dateTime = DateTime.parse(fileName.split('_')[0]);
    return DateFormat.yMMMMd("en_US").format(dateTime);
  }

  void processChangeFileList(FileListing files) {
    //Process each file and add to dropdown
    List<FileEntry> fileEntries = files.fileEntries;
    List<DropdownMenuItem<String>> entries =
        List.generate(fileEntries.length, (index) {
      String fileName = fileEntries[index].fileName;
      String dateStr = fileName.split('_')[0];
      return DropdownMenuItem<String>(value: fileName, child: Text(dateStr));
    });
    setState(() {
      changeEntries = entries;
      enabled = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget returnWidget = ListView(children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
            padding: const EdgeInsets.only(top: 8.0),
            child: ElevatedButton(
              child: Text('Show today'),
              onPressed: enabled ? getTodaysFile : null,
//              color: Colors.blue,
            )),
      ]),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Container(
          padding: const EdgeInsets.only(left: 8.0, top: 15.0, right: 10.0),
          child: Text(
            'Or select a previous day::',
            // style: Theme.of(context).textTheme.body1,
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
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Container(
          padding: const EdgeInsets.only(left: 8.0, top: 15.0, right: 10.0),
          child: Text(
            "Temperature Chart of " +
                (selectedDate != null ? formattedDateStr(selectedDate!) : ''),
            // style: Theme.of(context).textTheme.title,
          ),
        )
      ]),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.only(left: 3.0, top: 20.0, right: 0.0),
            height: 300.0,
            width: MediaQuery.of(context).size.width,
            //            child: TimeSeriesRangeAnnotationMarginChart.withSampleData(),
            child: HistoryLineChart(chartsToPlot, null),
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
  final List<charts.Series<TempByHour, int>> seriesList;
  final void Function(charts.SelectionModel<num>)? onSelectionChanged;

  HistoryLineChart(this.seriesList, this.onSelectionChanged);

  double getMaxValue() {
    double maxValue = -999999999.0;
    for (charts.Series s in seriesList)
      for (TempByHour point in s.data)
        if (point.temperature > maxValue) maxValue = point.temperature;
    return maxValue;
  }

  double getMinValue() {
    double minValue = 999999999.0;
    for (charts.Series s in seriesList)
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
//    for (charts.Series s in seriesList)
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
          changedListener: onSelectionChanged,
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
    print("Creating new chart with $len");
    return new charts.Series<TempByHour, int>(
      id: 'Measured',
      colorFn: ((TempByHour tempByHour, __) {
        var color;
        color = charts.MaterialPalette.green.shadeDefault;
        return color;
      }),
      domainFn: (TempByHour tt, _) => tt.hour,
      measureFn: (TempByHour tt, _) => tt.temperature,
      data: timeTempPoints,
    );
  }
}
