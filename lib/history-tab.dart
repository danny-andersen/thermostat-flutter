import 'package:flutter/material.dart';
import 'package:charts_flutter_new/flutter.dart' as charts;
import 'dropbox-api.dart';
import 'schedule.dart';
import 'package:sprintf/sprintf.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

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
  charts.Series<ValueByHour, int> measuredTempSeries =
      HistoryLineChart.createMeasuredSeries(
          List.filled(0, ValueByHour(0, 0.0)));
  charts.Series<ValueByHour, int> measuredHumiditySeries =
      HistoryLineChart.createMeasuredSeries(
          List.filled(0, ValueByHour(0, 0.0)));
  List<charts.Series<ValueByHour, int>> chartsToPlot = List.filled(
      0,
      HistoryLineChart.createMeasuredSeries(
          List.filled(0, ValueByHour(0, 0.0))));
  List<ValueByHour> temperatureList =
      List.filled(0, ValueByHour(0, 0.0), growable: true);
  List<ValueByHour> humidityList =
      List.filled(0, ValueByHour(0, 0.0), growable: true);
  List<ValueByHour> boilerList =
      List.filled(0, ValueByHour(0, 0.0), growable: true);
  int boilerOnTime = 0; //Number or mins boiler has been on that day
  // List<double> temps = List.filled(0, 0.0, growable: true);
  // List<double> humids = List.filled(0, 0.0, growable: true);
  String? selectedDate;

  @override
  void initState() {
    measuredTempSeries = HistoryLineChart.createMeasuredSeries(
        [ValueByHour(0, 10.0), ValueByHour(2400, 10.0)]);
    measuredHumiditySeries = HistoryLineChart.createMeasuredSeries(
        [ValueByHour(0, 30.0), ValueByHour(2400, 30.0)]);
    chartsToPlot = List.filled(1, measuredTempSeries, growable: true);
    DateTime now = DateTime.now();
    todayFile = sprintf(
        "%s%02i%02i%s", [now.year, now.month, now.day, deviceChangePattern]);
    // selectedDate = sprintf("%s%02i%02i", [now.year, now.month, now.day]);
    getTodaysFile();
    getChangeFileList();
    super.initState();
  }

  void getTodaysFile() {
    selectedDate = todayFile;
    getChangeFile(todayFile);
  }

  void getChangeFile(String changeFile) {
    // Reset lists
    temperatureList = List.filled(0, ValueByHour(0, 0.0), growable: true);
    humidityList = List.filled(0, ValueByHour(0, 0.0), growable: true);
    boilerList = List.filled(0, ValueByHour(0, 0.0), growable: true);
    print("Downloading file: $changeFile");
    DropBoxAPIFn.getDropBoxFile(
        oauthToken: oauthToken,
        fileToDownload: "/$changeFile",
        callback: processChangeFile,
        timeoutSecs: 180);
  }

  void newChangeFileSelected(String? changeFile) {
    changeFile ??= "Select a file"; //Set to blank if null
    selectedDate = changeFile;
    getChangeFile(changeFile);
  }

  void processChangeFile(String contents) {
//    double lastTemp = 10.0;
    // temperatureList = List.filled(0, TempByHour(0, 0.0), growable: true);
    int tempCount = 0;
    int humidCount = 0;
    contents.split('\n').forEach((line) {
      if (line.contains(':Temp:')) {
        try {
          List<String> parts = line.split(':');
          int time = getTime(parts[0].trim());
          double temp = double.parse(parts[2].trim());
          temperatureList.add(ValueByHour(time, temp));
          tempCount++;
        } on FormatException {
          print("Received incorrect temp format: $line");
        }
      } else if (line.contains(':Humidity:')) {
        try {
          List<String> parts = line.split(':');
          int time = getTime(parts[0].trim());
          double humid = double.parse(parts[2].trim());
          humidityList.add(ValueByHour(time, humid));
          humidCount++;
        } on FormatException {
          print("Received incorrect humidity format: $line");
        }
      } else if (line.contains(':Boiler:')) {
        try {
          List<String> parts = line.split(':');
          int time = getTime(parts[0].trim());
          // print("timeStr = ${parts[0].trim()} time int: ${time}");
          String status = parts[2].trim();
          if (status == "On") {
            boilerList.add(ValueByHour(time, 1));
          } else {
            boilerList.add(ValueByHour(time, 0));
          }
        } on FormatException {
          print("Received incorrect boiler format: $line");
        }
      }
    });
    // Process boiler on time
    DateTime lastOnTime = DateTime(0, 1, 1, 0, 0);
    boilerOnTime = 0;
    for (ValueByHour boilerState in boilerList) {
      int hour = boilerState.hour ~/ 100;
      int min = (0.6 * (boilerState.hour - (100 * hour))).round();
      DateTime time = DateTime(0, 1, 1, hour, min);
      // print(
      //     "Hour = ${boilerState.hour} ${hour}:${min} State = ${boilerState.value}");
      if (boilerState.value == 1) {
        lastOnTime = time;
      } else {
        // print("${(time.difference(lastOnTime)).inMinutes}");
        boilerOnTime += (time.difference(lastOnTime)).inMinutes;
      }
    }

    // print("Rx $tempCount temps $humidCount humids");
    measuredTempSeries = HistoryLineChart.createMeasuredSeries(temperatureList);
    measuredHumiditySeries =
        HistoryLineChart.createMeasuredSeries(humidityList);
    // print("Plotting chart");
    if (mounted) {
      setState(() {
        //Convert temperatures to the series
        chartsToPlot = [measuredTempSeries, measuredHumiditySeries];
      });
    }
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
    if (mounted) {
      setState(() {
        changeEntries = entries;
        enabled = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool evening =
        (selectedDate == todayFile && DateTime.now().hour < 17) ? false : true;
    Widget returnWidget = ListView(children: [
//       Row(mainAxisAlignment: MainAxisAlignment.center, children: [
//         Container(
//             padding: const EdgeInsets.only(top: 8.0),
//             child: ElevatedButton(
//               child: Text('Show today'),
//               onPressed: enabled ? getTodaysFile : null,
// //              color: Colors.blue,
//             )),
//       ]),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Container(
          padding: const EdgeInsets.only(left: 8.0, top: 15.0, right: 10.0),
          child: Text(
            'Choose date:',
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
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Container(
          padding: const EdgeInsets.only(left: 8.0, top: 15.0, right: 10.0),
          child: Text(
            "Temperature Chart of ${(selectedDate != null ? formattedDateStr(selectedDate!) : '')}",
            style: Theme.of(context).textTheme.headlineSmall,
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
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.only(top: 15.0, right: 8.0, left: 8.0),
            height: 40.0,
            // width: 400.0,
            width: MediaQuery.of(context).size.width,
            child: ShowRange(
                label: "Temperature Range: ", valsByHour: temperatureList),
          ),
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.only(top: 5.0, right: 8.0, left: 8.0),
            height: 40.0,
            width: MediaQuery.of(context).size.width,
            // width: MediaQuery.of(context).size.width,
            child: ShowRange(
                label: "Rel Humidity Range: ", valsByHour: humidityList),
          ),
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.only(top: 5.0, right: 8.0, left: 8.0),
            height: 40.0,
            width: MediaQuery.of(context).size.width,
            // width: MediaQuery.of(context).size.width,
            child: Text(
                "Boiler on for: ${boilerOnTime ~/ 60} hours, ${boilerOnTime - 60 * (boilerOnTime ~/ 60)} mins ($boilerOnTime mins)",
                style: Theme.of(context).textTheme.titleMedium
                // .displaySmall!
                // .apply(fontSizeFactor: 0.4),
//                    style: TextStyle(
//                      fontSize: 18.0,
//                      fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.only(top: 5.0, right: 8.0, left: 8.0),
            height: 40.0,
            width: MediaQuery.of(context).size.width,
            // width: MediaQuery.of(context).size.width,
            child: Text(
                "Gas Cost:        £${sprintf("%2i.%02i", [
                      ((evening ? 2 : 1) + (boilerOnTime * 2.5 / 100)).toInt(),
                      ((boilerOnTime * 2.5) % 100).toInt()
                    ])}",
                style: Theme.of(context).textTheme.titleMedium
                // .displaySmall!
                // .apply(fontSizeFactor: 0.4),
//                    style: TextStyle(
//                      fontSize: 18.0,
//                      fontWeight: FontWeight.bold,
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

class ShowRange extends StatelessWidget {
  ShowRange({required this.label, required this.valsByHour});

  List<ValueByHour> valsByHour;
  String label;

  @override
  Widget build(BuildContext context) {
    final List<double> vals = valsByHour.map((val) => val.value).toList();
    if (vals.isEmpty) {
      vals.add(0.0);
    }
    return Container(
//      decoration: BoxDecoration(
//        border: Border.all(
//          color: Colors.black,
//          width: 1.0,
//        ),
//      ),
      // padding: const EdgeInsets.fromLTRB(10, 2, 10, 2),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Container(
                //   // padding: const EdgeInsets.only(left: 8.0, top: 15.0),
                //   // height: 40.0,
                //   // width: 150.0,
                //   child: Text(
                //     label,
                //     style: Theme.of(context).textTheme.titleMedium,
                //   ),
                // ),
                Container(
                  // padding: const EdgeInsets.only(bottom: 8.0, right: 10.0),
                  child: Text(
                      "${label} Max: ${vals.max}, Min: ${vals.min}, Avg: ${vals.average.toStringAsFixed(1)}",
                      style: Theme.of(context).textTheme.titleMedium
                      // .displaySmall!
                      // .apply(fontSizeFactor: 0.4),
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
}

class HistoryLineChart extends StatelessWidget {
  final List<charts.Series<ValueByHour, int>> seriesList;
  final void Function(charts.SelectionModel<num>)? onSelectionChanged;

  HistoryLineChart(this.seriesList, this.onSelectionChanged);

  double getMaxValue() {
    double maxValue = -999999999.0;
    for (charts.Series s in seriesList)
      for (ValueByHour point in s.data)
        if (point.value > maxValue) maxValue = point.value;
    return maxValue;
  }

  double getMinValue() {
    double minValue = 999999999.0;
    for (charts.Series s in seriesList)
      for (ValueByHour point in s.data)
        if (point.value < minValue) minValue = point.value;
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
                ValueByHour.hourFormat),
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

  static charts.Series<ValueByHour, int> createMeasuredSeries(
      List<ValueByHour> timeTempPoints) {
    int len = timeTempPoints.length;
    print("Creating new chart with $len");
    return new charts.Series<ValueByHour, int>(
      id: 'Measured',
      colorFn: ((ValueByHour tempByHour, __) {
        var color;
        color = charts.MaterialPalette.green.shadeDefault;
        return color;
      }),
      domainFn: (ValueByHour tt, _) => tt.hour,
      measureFn: (ValueByHour tt, _) => tt.value,
      data: timeTempPoints,
    );
  }
}
