// import 'package:charts_flutter_new/flutter.dart' as charts;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:format/format.dart';
import 'dropbox-api.dart';
import 'schedule.dart';
import 'package:sprintf/sprintf.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key, required this.oauthToken});

  final String oauthToken;
  @override
  State createState() => SchedulePageState(oauthToken: oauthToken);
}

class SchedulePageState extends State<SchedulePage> {
  SchedulePageState({required this.oauthToken});

  final String oauthToken;
  final String scheduleFilesPattern = "setSchedule.txt.";
  final String currentScheduleFile = "setSchedule.txt.current";
  final String deviceChangeFile = "device_change.txt";

  List<Schedule>? schedules;
  ScheduleEntry? selectedScheduleEntry;
  List<DropdownMenuItem<ScheduleEntry>> scheduleEntries =
      List.filled(0, const DropdownMenuItem(child: Text("")), growable: true);

  Schedule? selectedSchedule; //The schedule that was selected and graphed
  Schedule? newSchedule; //A copy of the selected schedule that has been updated
  List<DropdownMenuItem<String>> scheduleDays = List.filled(
      0, const DropdownMenuItem(child: Text("")),
      growable: true); //A list of schedule days from the selected schedule file
  ScheduleDay?
      selectedScheduleTimeRange; //Time range that has been selected to update
  List<DropdownMenuItem<ScheduleDay>>?
      timeRanges; //A list of time ranges in the selected schedule
  String? selectedDayRange = ScheduleDay.weekDaysByInt[
      DateTime.now().weekday]; //which day ranges has been selecteed

  bool showNowEnabled = false;
  bool showNowSchedulePressed = false;
  LineChartBarData hourTempSeries = LineChartBarData();
  LineChartBarData measuredTempSeries = LineChartBarData();
  List<LineChartBarData> chartsToPlot =
      List.filled(0, LineChartBarData(), growable: true);
  List<FlSpot> hourTempList =
      List.filled(0, const FlSpot(0, 0.0), growable: true);
  List<FlSpot> temperatureList =
      List.filled(0, const FlSpot(0, 0.0), growable: true);

  TextEditingController newTempFieldController = TextEditingController();

  @override
  void initState() {
    showNowEnabled = false;
    // hourTempSeries = PointsLineChart.createScheduleSeries(
    //     [ValueByHour(0, 10.0), ValueByHour(2400, 10.0)], null);
    // measuredTempSeries = PointsLineChart.createMeasuredSeries(
    //     [ValueByHour(0, 10.0), ValueByHour(2400, 10.0)]);
    chartsToPlot = [hourTempSeries, measuredTempSeries];
    getSchedules();
    getChangeFile();
    // getScheduleFile("./$currentScheduleFile");
    super.initState();
  }

  void getChangeFile() {
    DateTime now = DateTime.now();
    String changeFile = sprintf(
        "/%s%02i%02i_%s", [now.year, now.month, now.day, deviceChangeFile]);
    DropBoxAPIFn.getDropBoxFile(
      oauthToken: oauthToken,
      fileToDownload: changeFile,
      callback: processChangeFile,
      contentType: ContentType.text,
      timeoutSecs: 60,
    );
  }

  void processChangeFile(String filename, String contents) {
    double lastTemp = 10.0;
    contents.split('\n').forEach((line) {
      if (line.contains(':Temp:')) {
        try {
          List<String> parts = line.split(':');
          int hour = getTime(parts[0].trim());
          double temp = double.parse(parts[2].trim());
          temperatureList.add(FlSpot(hour.toDouble(), temp));
          lastTemp = temp;
        } on FormatException {
          print("Received incorrect temp format: $line");
        }
      }
    });
    //Extend measured graph to current time
    if (lastTemp != 10.0) {
      DateTime now = DateTime.now();
      int nowHour = (now.hour * 100) + now.minute;
      temperatureList.add(FlSpot(nowHour.toDouble(), lastTemp));
    }
    measuredTempSeries = LineChartBarData(
      spots: temperatureList,
      color: Colors.red[600],
    );

    if (mounted) {
      setState(() {
        chartsToPlot = [
          hourTempSeries,
          measuredTempSeries,
        ];
      });
    }
  }

  void getSchedules() {
    DropBoxAPIFn.searchDropBoxFileNames(
        oauthToken: oauthToken,
        filePattern: scheduleFilesPattern,
        callback: processScheduleFiles);
  }

  void processScheduleFiles(FileListing files) {
    //Process each file and add to dropdown
    scheduleEntries.clear();
    if (mounted) {
      setState(() {
        String? currentFile;
        for (FileEntry file in files.fileEntries) {
          //      print("Adding ${file.fileName}");
          ScheduleEntry schedule = ScheduleEntry.fromFileEntry(file);
          scheduleEntries.add(DropdownMenuItem<ScheduleEntry>(
            value: schedule,
            child: Text(schedule.name),
          ));
          if (file.fileName.compareTo(currentScheduleFile) == 0) {
            currentFile = file.fullPathName;
            selectedScheduleEntry = schedule;
          }
        }
        if (currentFile != null) {
          getScheduleFile(currentFile);
        }
        showNowEnabled = true;
      });
    }
  }

  void scheduleSelected(ScheduleEntry? scheduleEntry) {
//    print('Selected ${scheduleEntry.name}');
    DropBoxAPIFn.getDropBoxFile(
      oauthToken: oauthToken,
      fileToDownload: scheduleEntry!.fileListing.fullPathName,
      callback: processScheduleFile,
      contentType: ContentType.text,
      timeoutSecs: 300,
    );
    generateHourTempSeries(selectedDayRange!);
    if (mounted) {
      setState(() {
        selectedScheduleEntry = scheduleEntry;
        chartsToPlot = [
          hourTempSeries,
          measuredTempSeries,
        ];
      });
    }
  }

  void processScheduleFile(String filename, String contents) {
    selectedSchedule = Schedule.fromFile(selectedScheduleEntry!, contents);
    newSchedule = selectedSchedule!.copy();
    Set<String> dayRangeSet = {};
    for (ScheduleDay day in selectedSchedule!.days) {
      dayRangeSet.add(day.dayRange);
    }
    for (String day in ScheduleDay.daysofWeek) {
      dayRangeSet.add(day);
    }
    scheduleDays.clear();
    if (mounted) {
      setState(() {
        for (String dayRange in dayRangeSet) {
          scheduleDays.add(DropdownMenuItem<String>(
            value: dayRange,
            child: Text(dayRange),
          ));
        }
        if (selectedDayRange != null) {
          generateHourTempSeries(selectedDayRange!);
          selectedScheduleEntry = selectedScheduleEntry;
          chartsToPlot = [
            hourTempSeries,
            measuredTempSeries,
          ];
        }
      });
    }
    // if (showNowSchedulePressed) {
    //   daySelected(ScheduleDay.weekDaysByInt[DateTime.now().weekday]);
    //   showNowSchedulePressed = false;
    // }
  }

  void daySelected(String? day) {
    if (mounted) {
      setState(() {
        selectedDayRange = day;
        generateHourTempSeries(day!);
        timeRanges = getScheduleTimes();
        selectedScheduleTimeRange =
            selectedSchedule!.filterEntriesByDayRange(day)[0];
        //      print (this.selectedScheduleTimeRange .getStartToEndStr());
      });
    }
  }

  void timeRangeSelected(ScheduleDay? day) {
    if (mounted) {
      setState(() {
        selectedScheduleTimeRange = day;
        newTempFieldController.text = day!.temperature.toStringAsFixed(1);
        newTempFieldController.addListener(newTempSet);
        //      print (this.selectedScheduleTimeRange .getStartToEndStr());
      });
    }
  }

  void newTempSet() {
    double newTemp = double.parse(newTempFieldController.text);
    print(newTemp);
//    this.selectedScheduleTimeRange.temperature
  }

  //Process schedule for selected day to create Series to plot
  void generateHourTempSeries(String day) {
    List<ScheduleDay> dayEntries =
        selectedSchedule!.filterEntriesByDayRange(day);
    List<ValueByHour> tempPoints =
        Schedule.generateTempByHourForEntries(dayEntries);
    hourTempList.clear();
    for (var valByHour in tempPoints) {
      hourTempList.add(FlSpot(valByHour.hour.toDouble(), valByHour.value));
    }
//    tempPoints.forEach((th) => print("Time: ${th.hour} Temp: ${th.temperature}"));
    hourTempSeries = LineChartBarData(
      spots: hourTempList,
      color: Colors.blue[800],
    );
  }

  void getScheduleFile(scheduleFile) {
    showNowSchedulePressed = true;
    DropBoxAPIFn.getDropBoxFile(
      oauthToken: oauthToken,
      fileToDownload: scheduleFile,
      callback: processScheduleFile,
      contentType: ContentType.text,
      timeoutSecs: 60,
    );
  }

//   dynamic onChartSelectionChanged(charts.SelectionModel model) {
//     final selectedDatum = model.selectedDatum;
//     ScheduleDay? selectedDay;
//     ScheduleDay? defaultDay;
//     if (selectedDatum.isNotEmpty) {
//       String timeStr =
//           ValueByHour.hourFormat.format(selectedDatum.first.datum.hour);
//       DateTime dtime = DateTime(2000, 1, 1, int.parse(timeStr.substring(0, 2)),
//           int.parse(timeStr.substring(2, 4)));
// //      double temp = selectedDatum.first.datum.temperature;
// //      print('$timeStr : $temp');
//       selectedSchedule!
//           .filterEntriesByDayRange(selectedDayRange!)
//           .forEach((day) {
//         if (day.isInTimeRange(dtime)) {
//           selectedDay = day;
//         } else if (day.isDefaultTimeRange()) {
//           defaultDay = day;
//         }
//       });
//     }
//     selectedDay ??= defaultDay;
//     if (mounted) {
//       setState(() {
//         selectedScheduleTimeRange = selectedDay;
//         timeRanges = getScheduleTimes();
//         generateHourTempSeries(selectedDayRange!);
//         //      print (selectedDay.getStartToEndStr());
//       });
//     }
//   }

  List<DropdownMenuItem<ScheduleDay>> getScheduleTimes() {
    List<DropdownMenuItem<ScheduleDay>> retList = List.filled(
        0, const DropdownMenuItem(child: Text(" ")),
        growable: true);
    selectedSchedule!
        .filterEntriesByDayRange(selectedDayRange!)
        .forEach((day) => retList.add(DropdownMenuItem<ScheduleDay>(
              value: day,
              child: Text(day.getStartToEndStr()),
            )));
    return retList;
  }

  @override
  Widget build(BuildContext context) {
    Widget returnWidget = ListView(children: [
//       Row(mainAxisAlignment: MainAxisAlignment.center, children: [
//         Container(
//             padding: const EdgeInsets.only(top: 8.0),
//             child: ElevatedButton(
//               child: Text('Show current schedule'),
//               onPressed: showNowEnabled ? showNowSchedule : null,
// //              color: Colors.blue,
//             )),
//       ]),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.only(left: 8.0, top: 5.0, right: 10.0),
          child: Text(
            'Select a schedule to view:',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Container(
          padding: const EdgeInsets.only(top: 5.0, right: 8.0),
          width: 100.0,
          height: 50.0,
          child: DropdownButton<ScheduleEntry>(
            items: scheduleEntries,
            onChanged: scheduleSelected,
            elevation: 20,
            isExpanded: true,
            value: selectedScheduleEntry,
            isDense: false,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ]),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.only(left: 8.0, top: 0.0),
          child: Text('Select Day Range to show:    ',
              style: Theme.of(context).textTheme.bodyMedium),
        ),
        Container(
          padding: const EdgeInsets.only(right: 8.0, top: 0.0),
          width: 100.0,
          height: 50.0,
//          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width, maxHeight: 30),
          child: DropdownButton<String>(
            items: scheduleDays,
            onChanged: daySelected,
            elevation: 20,
            isExpanded: true,
            value: selectedDayRange,
            isDense: false,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ]),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          DefaultTextStyle.merge(
            style: const TextStyle(color: Colors.white),
            child: Container(
              padding: const EdgeInsets.only(left: 3.0, top: 5.0, right: 20.0),
              height: 400.0,
              width: MediaQuery.of(context).size.width,
              child: PointsLineChart(chartsToPlot),
            ),
          )
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: [
          Container(
            padding: const EdgeInsets.only(left: 8.0, top: 15.0),
            child: Text(
              'Selected Time Range: ',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Container(
            padding: const EdgeInsets.only(left: 8.0, top: 15.0),
            width: 110.0,
//            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width, minWidth: 50.0),
            child: DropdownButton<ScheduleDay>(
              items: timeRanges,
              onChanged: timeRangeSelected,
              elevation: 25,
              isExpanded: true,
              value: selectedScheduleTimeRange,
              isDense: true,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          Container(
            padding: const EdgeInsets.only(left: 8.0, top: 15.0, right: 8.0),
            child: Text(
              selectedScheduleTimeRange == null
                  ? '   '
                  : 'Temp: ${selectedScheduleTimeRange!.temperature}\u00B0C',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        ],
      ),
      // Row(
      //   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      //   mainAxisSize: MainAxisSize.max,
      //   children: [
      //     Container(
      //       padding: const EdgeInsets.only(left: 8.0, top: 5.0),
      //       child: Text('Enter new temperature: ',
      //           style: Theme.of(context).textTheme.bodyMedium),
      //     ),
      //     Container(
      //       padding: const EdgeInsets.only(left: 8.0, top: 5.0, right: 8.0),
      //       width: 50.0,
      //       child: TextField(
      //         keyboardType: TextInputType.numberWithOptions(decimal: true),
      //         style: Theme.of(context).textTheme.bodyMedium,

      //       ),
      //     ),
      //     Container(
      //       padding: const EdgeInsets.only(left: 8.0, top: 5.0),
      //       child: Text(
      //         '\u00B0C',
      //         style: Theme.of(context).textTheme.bodyMedium,
      //       ),
      //     ),
      //   ],
      // ),
    ]);
//      ],
//    );
    return returnWidget;
  }
}

class PointsLineChart extends StatelessWidget {
  final List<LineChartBarData> seriesList;
  // final Function(charts.SelectionModel)? onSelectionChanged;

  const PointsLineChart(this.seriesList, {super.key});

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

  // charts.ChartBehavior<num> getRangeAnnotation() {
  //   double minValue = getMinValue();
  //   List<charts.LineAnnotationSegment<Object>> lines = List.filled(0,
  //       charts.LineAnnotationSegment(0, charts.RangeAnnotationAxisType.domain),
  //       growable: true);
  //   int nowTime = ValueByHour.from(DateTime.now(), 0.0).hour;
  //   lines.add(charts.LineAnnotationSegment(
  //     nowTime,
  //     charts.RangeAnnotationAxisType.domain,
  //     color: charts.MaterialPalette.red.shadeDefault,
  //     startLabel: ValueByHour.hourFormat.format(nowTime),
  //     labelAnchor: charts.AnnotationLabelAnchor.middle,
  //   ));
  //   for (charts.Series s in seriesList) {
  //     if (s.id.contains("Scheduled")) {
  //       for (ValueByHour point in s.data) {
  //         if (point.value != minValue) {
  //           lines.add(charts.LineAnnotationSegment(
  //               point.hour, charts.RangeAnnotationAxisType.domain,
  //               startLabel: ValueByHour.hourFormat.format(point.hour),
  //               color: charts.MaterialPalette.white.darker,
  //               labelStyleSpec: charts.TextStyleSpec(
  //                   color: charts.MaterialPalette.white.darker)));
  //         }
  //       }
  //     }
  //   }
  //   return charts.RangeAnnotation(lines);
  // }

  @override
  Widget build(BuildContext context) {
    double maxValue = getMaxValue();
    return LineChart(LineChartData(
      lineBarsData: seriesList,
      minX: 0,
      maxX: 2400,
      minY: 8,
      maxY: maxValue > 20.0 ? maxValue : 20.0,
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          maxContentWidth: 100,
          tooltipBgColor: Colors.black,
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((LineBarSpot touchedSpot) {
              final textStyle = TextStyle(
                color: touchedSpot.bar.gradient?.colors[0] ??
                    touchedSpot.bar.color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              );
              return LineTooltipItem(
                '${touchedSpot.y.toStringAsFixed(1)}°C@${getTimeStrFromFraction(touchedSpot.x)}',
                textStyle,
              );
            }).toList();
          },
        ),
      ),
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
    // return charts.LineChart(
    //   seriesList,
    //   animate: true,
    //   primaryMeasureAxis: charts.NumericAxisSpec(
    //     viewport: charts.NumericExtents(8.0, maxValue > 20.0 ? maxValue : 20.0),
    //     tickProviderSpec: const charts.BasicNumericTickProviderSpec(
    //         zeroBound: false, desiredTickCount: 14),
    //   ),
    //   domainAxis: charts.NumericAxisSpec(
    //     viewport: const charts.NumericExtents(0, 2400),
    //     tickProviderSpec:
    //         const charts.BasicNumericTickProviderSpec(desiredTickCount: 10),
    //     tickFormatterSpec:
    //         charts.BasicNumericTickFormatterSpec.fromNumberFormat(
    //             ValueByHour.hourFormat),
    //   ),
    //   defaultRenderer: charts.LineRendererConfig(includePoints: true),
    //   selectionModels: [
    //     charts.SelectionModelConfig(
    //       type: charts.SelectionModelType.info,
    //       changedListener: onSelectionChanged,
    //     )
    //   ],
    //   behaviors: [
    //     getRangeAnnotation(),
    //   ],
    // );
  }
}
