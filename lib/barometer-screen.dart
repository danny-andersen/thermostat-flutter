import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:format/format.dart';

import 'providers.dart';

const double minPressure = 940;
const double maxPressure = 1050;

class BarometerPage extends ConsumerStatefulWidget {
  BarometerPage({super.key, required this.oauthToken});
  String oauthToken;
  late _BarometerPageState statePage;

  @override
  ConsumerState<BarometerPage> createState() {
    statePage = _BarometerPageState(oauthToken: oauthToken);
    return statePage;
  }
}

class _BarometerPageState extends ConsumerState<BarometerPage> {
  _BarometerPageState({required this.oauthToken});
  String oauthToken;
  late Timer timer;
  String trend12hr = "??";
  String trend24hr = "??";
  String trend48hr = "??";
  String forecast = "??";

  @override
  void initState() {
    //Trigger first refresh shortly after widget initialised, to allow state to be initialised
    timer = Timer(const Duration(seconds: 1), updateStatus);
    super.initState();
  }

  void updateStatus() {
    //Note: Set timer before we call refresh otherwise will always have a get in progress
    timer = Timer(Duration(milliseconds: 120000), updateStatus);
    ref.read(barometerStatusNotifierProvider.notifier).refreshStatus();
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final BarometerStatus status = ref.watch(barometerStatusNotifierProvider);

    return Scaffold(
        body: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Column(
          children: [
            _BarometerGauge(
                status, screenHeight * (status.localUI ? 0.35 : 0.45)),
            Text(
              "Barometric Forecast: $forecast",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Container(
                padding: const EdgeInsets.only(left: 0.0, top: 5.0, right: 5.0),
                height: 300.0,
                width: MediaQuery.of(context).size.width,
                //            child: TimeSeriesRangeAnnotationMarginChart.withSampleData(),
                child: HistoryLineChart(status)),
          ],
        ),
      ),
    ));
  }

  double getMedianPressure(
      BarometerStatus status, List<DateTime> keys, int offset) {
    final int medianSize = 10;
    List<double?> pressures = [];
    for (int i = 0; i < medianSize; i++) {
      pressures.add(status.pressureByDateTime[keys[offset + i]]);
    }
    pressures.sort();
    return pressures[(medianSize / 2).toInt()]!;
  }

  String setForecast(double delta, double currentPressure, int hours) {
    String trend = "Stable";
    String fc = "";
    if (delta > (15 * hours / 12)) {
      trend = "Rising Rapidly";
      if (currentPressure > 1020) {
        fc = "Staying Fair and warm";
      } else if (currentPressure > 1000) {
        fc = "No change but warmer";
      } else {
        fc = "Clearing but cooler";
      }
    } else if (delta > (3 * hours / 12)) {
      trend = "Rising";
      if (currentPressure > 1020) {
        fc = "Staying Fair";
      } else if (currentPressure > 1000) {
        fc = "No change";
      } else {
        fc = "Improving slowly";
      }
    } else if (delta < (-15 * hours / 12)) {
      trend = "Falling Rapidly";
      if (currentPressure < 1000) {
        fc = "Stormy";
      } else if (currentPressure < 1020) {
        fc = "Rain very likely";
      } else {
        fc = "Cloudy";
      }
    } else if (delta < (-3 * hours / 12)) {
      trend = "Falling";
      if (currentPressure < 1000) {
        fc = "Rain likely";
      } else if (currentPressure < 1020) {
        fc = "Cloudy with possible rain";
      } else if (currentPressure < 1040) {
        fc = "Fair";
      }
    }
    if (fc != "" && forecast == "??") {
      forecast = fc;
    }
    return trend;
  }

  void setTrend(status) {
    final int hours12 = 12 * 60 * 2;
    if (status.pressureByDateTime.length < hours12) {
      return;
    }
    final int hours24 = 24 * 60 * 2;
    final int hours48 = 48 * 60 * 2;
    forecast = "??";
    List<DateTime> keys = status.pressureByDateTime.keys.toList();
    keys.sort();
    double _12hourAgo = getMedianPressure(
        status, keys, status.pressureByDateTime.length - hours12);
    double delta = status.currentPressure - _12hourAgo;
    trend12hr = setForecast(delta, status.currentPressure, 12);
    if (status.pressureByDateTime.length < hours24) {
      return;
    }
    double _24hourAgo = getMedianPressure(
        status, keys, status.pressureByDateTime.length - hours24);
    delta = status.currentPressure - _24hourAgo;
    trend24hr = setForecast(delta, status.currentPressure, 24);
    if (status.pressureByDateTime.length < hours48) {
      return;
    }
    double _48hourAgo = getMedianPressure(
        status, keys, status.pressureByDateTime.length - hours48);
    delta = status.currentPressure - _48hourAgo;
    trend48hr = setForecast(delta, status.currentPressure, 48);
    if (forecast == "??") {
      //If we haven't set the forecast yet, then all trends are stable
      forecast = "No change";
    }
  }

  Widget _BarometerGauge(BarometerStatus status, double size) {
    if (status.pressureByDateTime.isNotEmpty) {
      setTrend(status);
    }
    return SizedBox(
      height: size,
      child: SfRadialGauge(
        axes: <RadialAxis>[
          RadialAxis(
            minimum: minPressure,
            maximum: maxPressure,
            startAngle: 120,
            endAngle: 60,
            axisLineStyle: AxisLineStyle(
              thickness: 20,
              thicknessUnit: GaugeSizeUnit.logicalPixel,
            ),
            ranges: <GaugeRange>[
              GaugeRange(
                startValue: minPressure,
                endValue: 980,
                color: Colors.deepPurpleAccent,
                label: 'Stormy',
                sizeUnit: GaugeSizeUnit.factor,
                labelStyle:
                    GaugeTextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              GaugeRange(
                startValue: 980,
                endValue: 1000,
                color: Colors.lightBlueAccent,
                label: 'Rain',
                sizeUnit: GaugeSizeUnit.factor,
                labelStyle:
                    GaugeTextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              GaugeRange(
                startValue: 1000,
                endValue: 1020,
                color: Colors.lightGreen,
                label: 'Change',
                sizeUnit: GaugeSizeUnit.factor,
                labelStyle:
                    GaugeTextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              GaugeRange(
                startValue: 1020,
                endValue: 1040,
                color: Colors.yellow,
                label: 'Fair',
                sizeUnit: GaugeSizeUnit.factor,
                labelStyle:
                    GaugeTextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              GaugeRange(
                startValue: 1040,
                endValue: maxPressure,
                color: Colors.red,
                label: 'Very Dry',
                sizeUnit: GaugeSizeUnit.factor,
                labelStyle:
                    GaugeTextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
            pointers: <GaugePointer>[
              NeedlePointer(
                value: status.currentPressure,
                // needleColor: Colors.black,
                needleEndWidth: 5,
                lengthUnit: GaugeSizeUnit.factor,
                needleLength: 0.8,
                tailStyle: TailStyle(
                    // color: Colors.black,
                    width: 4,
                    length: 0.2,
                    lengthUnit: GaugeSizeUnit.factor),
                knobStyle: KnobStyle(
                    color: Colors.black,
                    borderWidth: 0.05,
                    borderColor: Colors.grey,
                    sizeUnit: GaugeSizeUnit.factor),
              )
            ],
            annotations: <GaugeAnnotation>[
              GaugeAnnotation(
                widget: Text(
                  status.currentPressure == 0
                      ? '?? hPa'
                      : '${status.currentPressure.toStringAsFixed(1)} hPa',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                angle: 90,
                positionFactor: 0.3,
              ),
              GaugeAnnotation(
                widget: Text(
                  "12hr Trend: $trend12hr",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                angle: 90,
                positionFactor: 0.45,
              ),
              GaugeAnnotation(
                widget: Text(
                  "24hr Trend: $trend24hr",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                angle: 90,
                positionFactor: 0.55,
              ),
              GaugeAnnotation(
                widget: Text(
                  "48hr Trend: $trend48hr",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                angle: 90,
                positionFactor: 0.65,
              )
            ],
          )
        ],
      ),
    );
  }
}

class HistoryLineChart extends StatelessWidget {
  final BarometerStatus status;
  // final void Function(charts.SelectionModel<num>)? onSelectionChanged;

  // const HistoryLineChart(this.seriesList, this.onSelectionChanged, {super.key});
  const HistoryLineChart(this.status, {super.key});

  double getMaxValue(LineChartBarData series) {
    double maxValue = -999999999;
    for (FlSpot point in series.spots) {
      if (point.y > maxValue) maxValue = point.y.ceil().toDouble();
    }
    return maxValue;
  }

  double getMinValue(LineChartBarData series) {
    double minValue = 999999999.0;
    for (FlSpot point in series.spots) {
      if (point.y < minValue) minValue = point.y.round().toDouble() - 1;
    }
    return minValue;
  }

  List<String> getLabels(List<DateTime> keys) {
    List<String> labels = [];
    NumberFormat nf = NumberFormat("00");
    keys.forEach((dt) {
      labels.add(
          '${nf.format(dt.day)}-${nf.format(dt.hour)}:${nf.format(dt.minute)}');
      // labels.add('{day:02d}-{hour:02d}:{min:02d}'
      //     .format({#day: dt.day, #hour: dt.hour, #min: dt.minute}));
    });
    return labels;
  }

  List<FlSpot> createLineData(List<DateTime> keys) {
    List<FlSpot> spots = [];
    double index = 0;
    keys.forEach((dt) {
      spots.add(FlSpot(index, status.pressureByDateTime[dt]!));
      index++;
    });
    return spots;
  }

  @override
  Widget build(BuildContext context) {
    final List<DateTime> keys = status.pressureByDateTime.keys.toList();
    keys.sort();
    final List<String> xLabels = getLabels(keys);
    final LineChartBarData series =
        LineChartBarData(spots: createLineData(keys));
    double maxValue = getMaxValue(series);
    double minValue = getMinValue(series);
    maxValue = maxValue < maxPressure ? maxPressure : maxValue;
    minValue = minValue > minPressure ? minPressure : minValue;
    return LineChart(LineChartData(
      lineBarsData: [series],
      minX: 0,
      maxX: (keys.length - 1).toDouble(),
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
                ].contains(touchedSpot.barIndex)) ? '%' : touchedSpot.barIndex == 1 ? 'ppm' : ''}@${xLabels[touchedSpot.x.toInt()]}',
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
        leftTitles: AxisTitles(
            // axisNameWidget: Text("\u00B0C"),
            sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 35,
          getTitlesWidget: (value, meta) {
            return SideTitleWidget(
              axisSide: AxisSide.left,
              child: Text(value.toStringAsFixed(0),
                  style: Theme.of(context)
                      .textTheme
                      .displaySmall!
                      .apply(fontSizeFactor: 0.3)),
            );
          },
        )),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
            // axisNameWidget: Text("Time"),
            sideTitles: SideTitles(
                showTitles: true,
                interval: 240,
                maxIncluded: false,
                minIncluded: false,
                getTitlesWidget: (value, meta) {
                  // Get the formatted timestamp for the x-axis labels
                  String label = "";
                  if (xLabels.length > 0) {
                    label = xLabels[value.toInt()];
                    //Extract the minute part and round to the nearest 30 minutes
                    int minute = int.parse(label.substring(7, 8));
                    minute = (minute / 30).round() * 30;
                    //Add back into the label
                    label = label.substring(1, 6) +
                        minute.toString().padLeft(2, '0');
                  }
                  return SideTitleWidget(
                      axisSide: AxisSide.bottom,
                      angle: 120,
                      child: Text(label,
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall!
                              .apply(fontSizeFactor: 0.3)));
                })),
      ),
    ));
  }
}
