import 'dart:io';
import 'package:flutter/material.dart';
// import 'package:charts_flutter_new/flutter.dart' as charts;
import 'package:fl_chart/fl_chart.dart';
import 'package:sprintf/sprintf.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:format/format.dart';
import 'package:fast_csv/csv_converter.dart' as csv;
import 'package:syncfusion_flutter_sliders/sliders.dart';

import 'dropbox-api.dart';
import 'schedule.dart';

class AirQualityHistoryPage extends StatefulWidget {
  const AirQualityHistoryPage({super.key, required this.oauthToken});

  final String oauthToken;

  @override
  State createState() => AirQualityHistoryPageState(oauthToken: oauthToken);
}

class AirQualityHistoryPageState extends State<AirQualityHistoryPage> {
  AirQualityHistoryPageState({required this.oauthToken});

  final String oauthToken;
  final String gasSensorPattern = "_gassensor.csv";
  final String airqualityPattern = "_airquality.csv";
  final String co2SensorPattern = "_co2sensor.csv";

  // HttpClient httpClient = HttpClient();
  List<DropdownMenuItem<String>>? changeEntries;
  String todayFile = "";
  bool enabled = false;
  bool localUI = false;

  LineChartBarData nh3ChgSeries = LineChartBarData();
  LineChartBarData reducerChgSeries = LineChartBarData();
  LineChartBarData oxChgSeries = LineChartBarData();
  LineChartBarData airQualitySeries = LineChartBarData();
  LineChartBarData cO2Series = LineChartBarData();
  List<LineChartBarData> lineChartData =
      List.filled(0, LineChartBarData(), growable: true);
  late List<FlSpot> nh3ChgList;
  List<FlSpot> reducerChgList =
      List.filled(0, const FlSpot(0, 0.0), growable: true);
  List<FlSpot> oxChgList = List.filled(0, const FlSpot(0, 0.0), growable: true);
  List<FlSpot> airQualityList =
      List.filled(0, const FlSpot(0, 0.0), growable: true);
  List<FlSpot> cO2List = List.filled(0, const FlSpot(0, 0.0), growable: true);

  String? selectedDate;

  Map<String, bool> plotSelectMap = {
    'IAQ': true,
    'CO2': false,
    'NH3': false,
    'Oxidiser': false,
    'Reducer': false,
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
        "%s%02i%02i%s", [now.year, now.month, now.day, airqualityPattern]);
    // selectedDate = sprintf("%s%02i%02i", [now.year, now.month, now.day]);
    getChangeFileList();
    getChangeFile(todayFile);
    super.initState();
  }

  void getChangeFile(todayFile) {
    // Reset lists
    nh3ChgList = List.filled(0, const FlSpot(0, 0.0), growable: true);
    reducerChgList = List.filled(0, const FlSpot(0, 0.0), growable: true);
    oxChgList = List.filled(0, const FlSpot(0, 0.0), growable: true);
    airQualityList = List.filled(0, const FlSpot(0, 0.0), growable: true);
    cO2List = List.filled(0, const FlSpot(0, 0.0), growable: true);
    String dateStr = todayFile.split('_')[0];
    // print("Downloading file: $changeFile");
    DropBoxAPIFn.getDropBoxFile(
        oauthToken: oauthToken,
        fileToDownload: "/$todayFile",
        callback: processAirQFile,
        contentType: ContentType.text,
        timeoutSecs: 60);
    String co2SensorFile = "$dateStr$co2SensorPattern";
    DropBoxAPIFn.getDropBoxFile(
        oauthToken: oauthToken,
        fileToDownload: "/$co2SensorFile",
        callback: processCO2File,
        contentType: ContentType.text,
        timeoutSecs: 60);
    String gasChangeFile = "$dateStr$gasSensorPattern";
    DropBoxAPIFn.getDropBoxFile(
        oauthToken: oauthToken,
        fileToDownload: "/$gasChangeFile",
        callback: processGasFile,
        contentType: ContentType.text,
        timeoutSecs: 60);
  }

  void newChangeFileSelected(String? changeFile) {
    if (changeFile != null) {
      selectedDate = changeFile;
      getChangeFile(changeFile);
    }
  }

  void processAirQFile(String filename, String contents) {
    if (contents.isEmpty || contents.contains("error")) {
      return;
    }
    final result = csv.CsvConverter().convert(contents);
    for (int i = 1; i < result.length; i++) {
      final row = result[i];
      try {
        var t = getHourMin(row[0].trim());
        double hourmin = t.$2;
        double iaq = double.parse(row[4].trim());
        if (iaq != 0) {
          airQualityList.add(FlSpot(hourmin, iaq));
        }
      } on Exception {
        //ignore row
      }
    }
    airQualitySeries = LineChartBarData(
      spots: airQualityList,
      color: Colors.red[600],
    );
    if (mounted) {
      setState(() {
        setChartData();
      });
    }
  }

  void processCO2File(String filename, String contents) {
    if (contents.isEmpty || contents.contains("error")) {
      return;
    }
    final result = csv.CsvConverter().convert(contents);
    for (int i = 1; i < result.length; i++) {
      final row = result[i];
      try {
        var t = getHourMin(row[0].trim());
        double hourmin = t.$2;
        double co2 = double.parse(row[1].trim());
        if (co2 != 400) {
          cO2List.add(FlSpot(hourmin, co2));
        }
      } on Exception {
        //ignore row
      }
    }

    cO2Series = LineChartBarData(spots: cO2List, color: Colors.blue);

    if (mounted) {
      setState(() {
        setChartData();
      });
    }
  }

  void processGasFile(String filename, String contents) {
    if (contents.isEmpty || contents.contains("error")) {
      return;
    }
    String filed = filename.split('_')[0].split('/')[1];
    String procDate =
        "${filed.substring(0, 4)}-${filed.substring(4, 6)}-${filed.substring(6, 8)}";
    DateTime processDate = DateTime.parse(procDate);
    final result = csv.CsvConverter().convert(contents);
    for (int i = 1; i < result.length; i++) {
      final row = result[i];
      try {
        var t = getHourMin(row[0].trim());
        double time = t.$2;
        if (t.$1 != processDate.day) {
          continue; //Skip entries that are from previous day
        }
        double redchg = double.parse(row[3].trim());
        reducerChgList.add(FlSpot(time, redchg));
        double nh3chg = double.parse(row[5].trim());
        nh3ChgList.add(FlSpot(time, nh3chg));
        double oxchg = double.parse(row[7].trim());
        oxChgList.add(FlSpot(time, oxchg));
      } on Exception {
        //ignore row
      }
    }

    reducerChgSeries =
        LineChartBarData(spots: reducerChgList, color: Colors.green[800]);
    nh3ChgSeries = LineChartBarData(spots: nh3ChgList, color: Colors.orange);
    oxChgSeries = LineChartBarData(spots: oxChgList, color: Colors.yellow);

    if (mounted) {
      setState(() {
        setChartData();
      });
    }
  }

  void getChangeFileList() {
    DropBoxAPIFn.searchDropBoxFileNames(
        oauthToken: oauthToken,
        filePattern: airqualityPattern,
        callback: processChangeFileList,
        maxResults: 31);
  }

  void onPlotSelectChange(stateMap) {
    if (mounted) {
      setState(() {
        plotSelectMap = stateMap;
        setChartData();
      });
    }
  }

  void setChartData() {
    LineChartBarData emptySeries = LineChartBarData();
    lineChartData = [
      plotSelectMap['IAQ']! ? airQualitySeries : emptySeries,
      plotSelectMap['CO2']! ? cO2Series : emptySeries,
      plotSelectMap['NH3']! ? nh3ChgSeries : emptySeries,
      plotSelectMap['Oxidiser']! ? oxChgSeries : emptySeries,
      plotSelectMap['Reducer']! ? reducerChgSeries : emptySeries,
    ];
  }

  String formattedDateStr(String fileName) {
    //Convert yyyymmdd to dd Month Year
    DateTime dateTime = DateTime.parse(fileName.split('_')[0]);
    return DateFormat.yMMMMd("en_US").format(dateTime);
  }

  void processChangeFileList(FileListing files) {
    //Process each file and add to dropdown
    List<FileEntry> fileEntries = files.fileEntries.toSet().toList();
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
          padding: const EdgeInsets.only(left: 8.0, top: 5.0, right: 5.0),
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
            padding: const EdgeInsets.only(left: 0.0, top: 20.0, right: 15.0),
            height: 600.0,
            width: MediaQuery.of(context).size.width,
            //            child: TimeSeriesRangeAnnotationMarginChart.withSampleData(),
            child: HistoryLineChart(lineChartData),
          ),
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
          Text("IAQ",
              style: TextStyle(
                fontSize: 11.0,
                // fontWeight: FontWeight.bold,
                color: Colors.red[600],
              )),
          Checkbox(
              checkColor: Colors.white,
              fillColor: WidgetStateProperty.resolveWith(getColor),
              value: stateMap['IAQ'] ?? false,
              onChanged: (bool? value) {
                stateMap['IAQ'] = value!;
                onChange(stateMap);
              }),
          Text("CO2",
              style: TextStyle(
                fontSize: 11.0,
                // fontWeight: FontWeight.bold,
                color: Colors.blue,
              )),
          Checkbox(
              checkColor: Colors.white,
              fillColor: WidgetStateProperty.resolveWith(getColor),
              value: stateMap['CO2'] ?? false,
              onChanged: (bool? value) {
                stateMap['CO2'] = value ?? false;
                onChange(stateMap);
              }),
          Text("Reducer",
              style: TextStyle(
                fontSize: 11.0,
                // fontWeight: FontWeight.bold,
                color: Colors.green[800],
              )),
          Checkbox(
              checkColor: Colors.white,
              fillColor: WidgetStateProperty.resolveWith(getColor),
              value: stateMap['Reducer'] ?? false,
              onChanged: (bool? value) {
                stateMap['Reducer'] = value ?? false;
                onChange(stateMap);
              }),
          const Text("NH3",
              style: TextStyle(
                  fontSize: 11.0,
                  // fontWeight: FontWeight.bold,
                  color: Colors.orange)),
          Checkbox(
              checkColor: Colors.white,
              fillColor: WidgetStateProperty.resolveWith(getColor),
              value: stateMap['NH3'] ?? false,
              onChanged: (bool? value) {
                stateMap['NH3'] = value ?? false;
                onChange(stateMap);
              }),
          Text("Oxidiser",
              style: TextStyle(
                  fontSize: 11.0,
                  // fontWeight: FontWeight.bold,
                  color: Colors.yellow)),
          Checkbox(
              checkColor: Colors.white,
              fillColor: WidgetStateProperty.resolveWith(getColor),
              value: stateMap['Oxidiser'] ?? false,
              onChanged: (bool? value) {
                stateMap['Oxidiser'] = value ?? false;
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
                  2,
                  3,
                  4
                ].contains(touchedSpot.barIndex)) ? '%' : touchedSpot.barIndex == 1 ? 'ppm' : ''}@${getTimeStrFromFraction(touchedSpot.x)}',
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
