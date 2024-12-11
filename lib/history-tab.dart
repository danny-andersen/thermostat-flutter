import 'dart:io';
import 'package:flutter/material.dart';
// import 'package:charts_flutter_new/flutter.dart' as charts;
import 'package:fl_chart/fl_chart.dart';
import 'package:sprintf/sprintf.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:format/format.dart';

import 'package:syncfusion_flutter_sliders/sliders.dart';

import 'dropbox-api.dart';
import 'schedule.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, required this.oauthToken});

  final String oauthToken;

  @override
  State createState() => HistoryPageState(oauthToken: oauthToken);
}

class HistoryPageState extends State<HistoryPage> {
  HistoryPageState({required this.oauthToken});

  final String oauthToken;
  final String deviceChangePattern = "_device_change.txt";
  final String externalChangePattern1 = "_cam4_change.txt";
  final String externalChangePattern2 = "_cam2_change.txt";

  // HttpClient httpClient = HttpClient();
  List<DropdownMenuItem<String>>? changeEntries;
  String todayFile = "";
  bool enabled = false;
  bool localUI = false;

  LineChartBarData measuredTempSeries = LineChartBarData();
  LineChartBarData extMeasuredTempSeries1 = LineChartBarData();
  LineChartBarData extMeasuredTempSeries2 = LineChartBarData();
  LineChartBarData measuredHumiditySeries = LineChartBarData();
  LineChartBarData extMeasuredHumiditySeries = LineChartBarData();
  List<LineChartBarData> lineChartData =
      List.filled(0, LineChartBarData(), growable: true);
  List<FlSpot> temperatureList =
      List.filled(0, const FlSpot(0, 0.0), growable: true);
  List<FlSpot> extTemperatureList1 =
      List.filled(0, const FlSpot(0, 0.0), growable: true);
  List<FlSpot> extTemperatureList2 =
      List.filled(0, const FlSpot(0, 0.0), growable: true);
  List<FlSpot> humidityList =
      List.filled(0, const FlSpot(0, 0.0), growable: true);
  List<FlSpot> extHumidityList =
      List.filled(0, const FlSpot(0, 0.0), growable: true);
  List<FlSpot> boilerList =
      List.filled(0, const FlSpot(0, 0.0), growable: true);
  int boilerOnTime = 0; //Number or mins boiler has been on that day
  // List<double> temps = List.filled(0, 0.0, growable: true);
  // List<double> humids = List.filled(0, 0.0, growable: true);
  String? selectedDate;
  Map<String, bool> plotSelectMap = {
    'temp': true,
    'exttemp1': true,
    'exttemp2': true,
    'humid': false,
    'exthumid': false
  };

  @override
  void initState() {
    // temperatureList = [FlSpot(0, 10.0), FlSpot(2400, 10.0)];
    // humidityList = [FlSpot(0, 30.0), FlSpot(2400, 30.0)];
    // extTemperatureList = [FlSpot(0, 10.0), FlSpot(2400, 10.0)];
    // extHumidityList = [FlSpot(0, 30.0), FlSpot(2400, 30.0)];

    FileStat thermStat = FileStat.statSync("/home/danny/thermostat");
    if (thermStat.type != FileSystemEntityType.notFound) {
      localUI = true;
    }
    DateTime now = DateTime.now();
    todayFile = sprintf(
        "%s%02i%02i%s", [now.year, now.month, now.day, deviceChangePattern]);
    // selectedDate = sprintf("%s%02i%02i", [now.year, now.month, now.day]);
    getChangeFileList();
    getChangeFile(todayFile);
    super.initState();
  }

  void getChangeFile(String changeFile) {
    // Reset lists
    temperatureList = List.filled(0, const FlSpot(0, 0.0), growable: true);
    humidityList = List.filled(0, const FlSpot(0, 0.0), growable: true);
    extTemperatureList1 = List.filled(0, const FlSpot(0, 0.0), growable: true);
    extTemperatureList2 = List.filled(0, const FlSpot(0, 0.0), growable: true);
    extHumidityList = List.filled(0, const FlSpot(0, 0.0), growable: true);
    boilerList = List.filled(0, const FlSpot(0, 0.0), growable: true);
    // print("Downloading file: $changeFile");
    DropBoxAPIFn.getDropBoxFile(
        oauthToken: oauthToken,
        fileToDownload: "/$changeFile",
        callback: processChangeFile,
        contentType: ContentType.text,
        timeoutSecs: 60);
    String extChangeFile = "${changeFile.split('_')[0]}$externalChangePattern1";
    DropBoxAPIFn.getDropBoxFile(
        oauthToken: oauthToken,
        fileToDownload: "/$extChangeFile",
        callback: processExtChangeFile,
        contentType: ContentType.text,
        timeoutSecs: 60);
    extChangeFile = "${changeFile.split('_')[0]}$externalChangePattern2";
    DropBoxAPIFn.getDropBoxFile(
        oauthToken: oauthToken,
        fileToDownload: "/$extChangeFile",
        callback: processExtChangeFile,
        contentType: ContentType.text,
        timeoutSecs: 60);
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

  void processChangeFile(String filename, String contents) {
//    double lastTemp = 10.0;
    // temperatureList = List.filled(0, TempByHour(0, 0.0), growable: true);
    processCommonContents(contents, temperatureList, humidityList);
    // Process boiler on time
    DateTime lastOnTime = DateTime(0, 1, 1, 0, 0);
    boilerOnTime = 0;
    bool lastBoilerState = false;
    for (FlSpot boilerState in boilerList) {
      int hour = boilerState.x ~/ 100;
      int min = (0.6 * (boilerState.x - (100 * hour))).round();
      DateTime time = DateTime(0, 1, 1, hour, min);
      // print(
      //     "Hour = ${boilerState.hour} ${hour}:${min} State = ${boilerState.value}");
      if (boilerState.y == 1) {
        lastOnTime = time;
      } else {
        // print("${(time.difference(lastOnTime)).inMinutes}");
        boilerOnTime += time.difference(lastOnTime).inMinutes;
      }
      lastBoilerState = boilerState.y == 1 ? true : false;
    }
    if (lastBoilerState && lastOnTime != DateTime(0, 1, 1, 0, 0)) {
      DateTime nowDT = DateTime.now();
      DateTime nowTime = DateTime(0, 1, 1, nowDT.hour, nowDT.minute);
      boilerOnTime += nowTime.difference(lastOnTime).inMinutes;
    }

    // print("Rx $tempCount temps $humidCount humids");
    // measuredTempSeries = HistoryLineChart.createMeasuredSeries(temperatureList);
    // measuredHumiditySeries =
    //     HistoryLineChart.createMeasuredSeries(humidityList);
    // // print("Plotting chart");
    measuredTempSeries = LineChartBarData(
      spots: temperatureList,
      color: Colors.red[600],
    );
    measuredHumiditySeries =
        LineChartBarData(spots: humidityList, color: Colors.purple);

    if (mounted) {
      LineChartBarData emptySeries = LineChartBarData();
      setState(() {
        //Convert temperatures to the series
        lineChartData = [
          plotSelectMap['temp']! ? measuredTempSeries : emptySeries,
          plotSelectMap['humid']! ? measuredHumiditySeries : emptySeries,
          plotSelectMap['exttemp1']! ? extMeasuredTempSeries1 : emptySeries,
          plotSelectMap['exttemp2']! ? extMeasuredTempSeries2 : emptySeries,
          plotSelectMap['exthumid']! ? extMeasuredHumiditySeries : emptySeries,
        ];
      });
    }
  }

  void processExtChangeFile(String filename, String contents) {
    if (filename.contains("cam4")) {
      processCommonContents(contents, extTemperatureList1, extHumidityList);
      extMeasuredTempSeries1 = LineChartBarData(
          spots: extTemperatureList1, color: Colors.green[400]);
      extMeasuredHumiditySeries =
          LineChartBarData(spots: extHumidityList, color: Colors.amber[600]);
    } else {
      processCommonContents(contents, extTemperatureList2, extHumidityList);
      extMeasuredTempSeries2 = LineChartBarData(
          spots: extTemperatureList2, color: Colors.green[800]);
    }
    // print("Rx $tempCount temps $humidCount humids");
    // extMeasuredTempSeries =
    //     HistoryLineChart.createMeasuredSeries(extTemperatureList);
    // extMeasuredHumiditySeries =
    //     HistoryLineChart.createMeasuredSeries(extHumidityList);
    // print("Plotting chart");

    if (mounted) {
      LineChartBarData emptySeries = LineChartBarData();
      setState(() {
        //Convert temperatures to the series
        lineChartData = [
          plotSelectMap['temp']! ? measuredTempSeries : emptySeries,
          plotSelectMap['humid']! ? measuredHumiditySeries : emptySeries,
          plotSelectMap['exttemp1']! ? extMeasuredTempSeries1 : emptySeries,
          plotSelectMap['exttemp2']! ? extMeasuredTempSeries2 : emptySeries,
          plotSelectMap['exthumid']! ? extMeasuredHumiditySeries : emptySeries,
        ];
      });
    }
  }

  void processCommonContents(contents, tempList, humidList) {
    contents.split('\n').forEach((line) {
      if (line.contains(':Temp:')) {
        try {
          List<String> parts = line.split(':');
          int time = getTime(parts[0].trim());
          double temp = double.parse(parts[2].trim());
          tempList.add(FlSpot(time.toDouble(), temp));
        } on FormatException {
          print("Received incorrect temp format: $line");
        }
      } else if (line.contains(':Humidity:')) {
        try {
          List<String> parts = line.split(':');
          int time = getTime(parts[0].trim());
          double humid = double.parse(parts[2].trim());
          if (humid > 0) {
            humidList.add(FlSpot(time.toDouble(), humid));
          }
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
            boilerList.add(FlSpot(time.toDouble(), 1));
          } else {
            boilerList.add(FlSpot(time.toDouble(), 0));
          }
        } on FormatException {
          print("Received incorrect boiler format: $line");
        }
      }
    });
  }

  void getChangeFileList() {
    DropBoxAPIFn.searchDropBoxFileNames(
        oauthToken: oauthToken,
        filePattern: deviceChangePattern,
        callback: processChangeFileList,
        maxResults: 31);
  }

  void onPlotSelectChange(stateMap) {
    if (mounted) {
      setState(() {
        plotSelectMap = stateMap;
        LineChartBarData emptySeries = LineChartBarData();
        lineChartData = [
          plotSelectMap['temp']! ? measuredTempSeries : emptySeries,
          plotSelectMap['humid']! ? measuredHumiditySeries : emptySeries,
          plotSelectMap['exttemp1']! ? extMeasuredTempSeries1 : emptySeries,
          plotSelectMap['exttemp2']! ? extMeasuredTempSeries2 : emptySeries,
          plotSelectMap['exthumid']! ? extMeasuredHumiditySeries : emptySeries,
        ];
      });
    }
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
    // String dateStr = todayFile.split('_')[0];
    // entries.insert(
    //     0, DropdownMenuItem<String>(value: todayFile, child: Text(dateStr)));
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
    List<FlSpot> extTempList = List.from(extTemperatureList1);
    extTempList.addAll(extTemperatureList2);
    Widget returnWidget = ListView(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Container(
          padding: const EdgeInsets.only(left: 8.0, top: 5.0, right: 10.0),
          child: Text(
            'Choose date:',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        Container(
          padding: const EdgeInsets.only(top: 5.0, right: 8.0),
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
      Container(
        padding: const EdgeInsets.only(left: 8.0, top: 5.0, right: 8.0),
        child: SelectPlots(onPlotSelectChange, plotSelectMap),
      ),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Container(
          padding: const EdgeInsets.only(left: 8.0, top: 0.0, right: 5.0),
          child: Text(
              (selectedDate != null
                  ? formattedDateStr(selectedDate!)
                  : formattedDateStr(todayFile)),
              style: localUI
                  ? Theme.of(context).textTheme.headlineMedium
                  : Theme.of(context).textTheme.bodyLarge),
        )
      ]),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.only(left: 0.0, top: 8.0, right: 15.0),
            height: 400.0,
            width: MediaQuery.of(context).size.width,
            //            child: TimeSeriesRangeAnnotationMarginChart.withSampleData(),
            child: HistoryLineChart(lineChartData),
          ),
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Text(
              "Boiler on for: ${boilerOnTime ~/ 60} hours, ${boilerOnTime - 60 * (boilerOnTime ~/ 60)} mins ($boilerOnTime mins)",
              style: localUI
                  ? Theme.of(context).textTheme.bodyLarge
                  : Theme.of(context).textTheme.bodyMedium),
          Text(
              "Gas Cost: £${sprintf("%2i.%02i", [
                    ((evening ? 2 : 1) + (boilerOnTime * 2.5 / 100)).toInt(),
                    ((boilerOnTime * 2.5) % 100).toInt()
                  ])}",
              style: localUI
                  ? Theme.of(context).textTheme.bodyLarge
                  : Theme.of(context).textTheme.bodyMedium),
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.only(top: 0.0, right: 0.0, left: 8.0),
            // height: 40.0,
            // width: 400.0,
            width: MediaQuery.of(context).size.width,
            child: ShowRange(
                localUI: localUI,
                label: "Int Temp:",
                valsByHour: temperatureList),
          ),
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.only(top: 0.0, right: 0.0, left: 8.0),
            // height: 40.0,
            // width: 400.0,
            width: MediaQuery.of(context).size.width,
            child: ShowRange(
                localUI: localUI, label: "Ext Temp:", valsByHour: extTempList),
          ),
        ],
      ),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.only(top: 0.0, right: 0.0, left: 8.0),
          // height: 40.0,
          width: MediaQuery.of(context).size.width,
          // width: MediaQuery.of(context).size.width,
          child: ShowRange(
              localUI: localUI,
              label: "Int Humidity %:  ",
              valsByHour: humidityList),
        ),
      ]),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
              padding: const EdgeInsets.only(
                  top: 0.0, right: 0.0, left: 8.0, bottom: 5.0),
              // height: 40.0,
              width: MediaQuery.of(context).size.width,
              // width: MediaQuery.of(context).size.width,
              child: ShowRange(
                localUI: localUI,
                label: "Ext Humidity %:",
                valsByHour: extHumidityList,
              )),
        ],
      ),
    ]);
    return returnWidget;
  }
}

class SelectPlots extends StatelessWidget {
  SelectPlots(this.onChange, this.stateMap, {super.key});

  Function onChange;
  Map<String, bool> stateMap;

  @override
  Widget build(BuildContext context) {
    Color getColor(Set<WidgetState> states) {
      const Set<WidgetState> interactiveStates = <WidgetState>{
        WidgetState.pressed,
        WidgetState.hovered,
        WidgetState.focused,
      };
      if (states.any(interactiveStates.contains)) {
        return Colors.blue;
      }
      return Colors.grey;
    }

    return Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text("Int Temp",
              style: TextStyle(
                fontSize: 11.0,
                // fontWeight: FontWeight.bold,
                color: Colors.red[600],
              )),
          Checkbox(
              checkColor: Colors.white,
              fillColor: WidgetStateProperty.resolveWith(getColor),
              value: stateMap['temp'] ?? false,
              onChanged: (bool? value) {
                stateMap['temp'] = value!;
                onChange(stateMap);
              }),
          Text("Ext Temp (Left)",
              style: TextStyle(
                fontSize: 11.0,
                // fontWeight: FontWeight.bold,
                color: Colors.green[400],
              )),
          Checkbox(
              checkColor: Colors.white,
              fillColor: WidgetStateProperty.resolveWith(getColor),
              value: stateMap['exttemp1'] ?? false,
              onChanged: (bool? value) {
                stateMap['exttemp1'] = value ?? false;
                onChange(stateMap);
              }),
          Text("Ext Temp (Right)",
              style: TextStyle(
                fontSize: 11.0,
                // fontWeight: FontWeight.bold,
                color: Colors.green[800],
              )),
          Checkbox(
              checkColor: Colors.white,
              fillColor: WidgetStateProperty.resolveWith(getColor),
              value: stateMap['exttemp2'] ?? false,
              onChanged: (bool? value) {
                stateMap['exttemp2'] = value ?? false;
                onChange(stateMap);
              }),
          const Text("Int Humid",
              style: TextStyle(
                  fontSize: 11.0,
                  // fontWeight: FontWeight.bold,
                  color: Colors.purple)),
          Checkbox(
              checkColor: Colors.white,
              fillColor: WidgetStateProperty.resolveWith(getColor),
              value: stateMap['humid'] ?? false,
              onChanged: (bool? value) {
                stateMap['humid'] = value ?? false;
                onChange(stateMap);
              }),
          Text("Ext Humid",
              style: TextStyle(
                  fontSize: 11.0,
                  // fontWeight: FontWeight.bold,
                  color: Colors.amber[600])),
          Checkbox(
              checkColor: Colors.white,
              fillColor: WidgetStateProperty.resolveWith(getColor),
              value: stateMap['exthumid'] ?? false,
              onChanged: (bool? value) {
                stateMap['exthumid'] = value ?? false;
                onChange(stateMap);
              })
        ]);
  }
}

class ShowRange extends StatelessWidget {
  ShowRange(
      {super.key,
      required this.localUI,
      required this.label,
      required this.valsByHour});

  List<FlSpot> valsByHour;
  String label;
  bool localUI;

  @override
  Widget build(BuildContext context) {
    final List<double> vals = valsByHour.map((val) => val.y).toList();
    if (vals.isEmpty) {
      vals.add(0.0);
    }
    return Center(
        child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          // .displaySmall!
          // .apply(fontSizeFactor: 0.4),

          Expanded(
              child: SfRangeSlider(
            min: vals.min < 10 ? vals.min.round() - 1.0 : 10.0,
            max: vals.max < 40 ? vals.max.round() + 5 : 100,
            values: SfRangeValues(vals.min, vals.max),
            interval: vals.max < 40 ? 2 : 10,
            // enableTooltip: true,
            showTicks: true,
            showLabels: true,
            inactiveColor: Colors.yellow,
            activeColor: Colors.blue,
            minorTicksPerInterval: 1,
            onChanged: (SfRangeValues newValues) {},
          ))
        ]));
  }
}

class HistoryLineChart extends StatelessWidget {
  final List<LineChartBarData> seriesList;
  // final void Function(charts.SelectionModel<num>)? onSelectionChanged;

  // const HistoryLineChart(this.seriesList, this.onSelectionChanged, {super.key});
  const HistoryLineChart(this.seriesList, {super.key});

  double getMaxValue() {
    double maxValue = -999999999;
    for (LineChartBarData s in seriesList)
      for (FlSpot point in s.spots) {
        if (point.y > maxValue) maxValue = point.y.ceil().toDouble();
      }
    return maxValue;
  }

  double getMinValue() {
    double minValue = 999999999.0;
    for (LineChartBarData s in seriesList)
      for (FlSpot point in s.spots) {
        if (point.y < minValue) minValue = point.y.round().toDouble() - 1;
      }
    return minValue;
  }

  @override
  Widget build(BuildContext context) {
    double maxValue = getMaxValue();
    double minValue = getMinValue();
    return LineChart(LineChartData(
      lineBarsData: seriesList,
      minX: 0,
      maxX: 2400,
      minY: minValue,
      maxY: maxValue,
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          maxContentWidth: 100,
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((LineBarSpot touchedSpot) {
              final textStyle = TextStyle(
                color: touchedSpot.bar.gradient?.colors[0] ??
                    touchedSpot.bar.color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              );
              return LineTooltipItem(
                '${touchedSpot.y.toStringAsFixed(1)}${([
                  1,
                  4
                ].contains(touchedSpot.barIndex)) ? '%' : '°C'}@${getTimeStrFromFraction(touchedSpot.x)}',
                textStyle,
              );
            }).toList();
          },
        ),
        handleBuiltInTouches: true,
        getTouchLineStart: (data, index) => 0,
      ),
      // showingTooltipIndicators:
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        leftTitles: const AxisTitles(
            // axisNameWidget: Text("\u00B0C"),
            sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
            // axisNameWidget: Text("Time"),
            sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  // Get the formatted timestamp for the x-axis labels
                  return Text('{:04d}'.format(value.toInt()),
                      style: Theme.of(context)
                          .textTheme
                          .displaySmall!
                          .apply(fontSizeFactor: 0.3));
                })),
      ),
    ));
  }
}
