import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

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
  String trend24hr = "??";
  String trend48hr = "??";

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
                status, screenHeight * (status.localUI ? 0.35 : 0.5)),
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

  void setTrend(status) {
    final int hours24 = 24 * 60 * 2;
    if (status.pressureByDateTime.length < hours24) {
      return;
    }
    final int hours48 = 48 * 60 * 2;
    List<DateTime> keys = status.pressureByDateTime.keys.toList();
    keys.sort();
    double _24hourAgo = getMedianPressure(
        status, keys, status.pressureByDateTime.length - hours24);
    double delta = status.currentPressure - _24hourAgo;
    if (delta > 30) {
      trend24hr = "Rising Rapidly";
    } else if (delta > 5) {
      trend24hr = "Rising";
    } else if (delta < -30) {
      trend24hr = "Falling Rapidly";
    } else if (delta < -5) {
      trend24hr = "Falling";
    } else {
      trend24hr = "Stable";
    }
    if (status.pressureByDateTime.length < hours48) {
      return;
    }
    double _48hourAgo = getMedianPressure(
        status, keys, status.pressureByDateTime.length - hours48);
    delta = status.currentPressure - _48hourAgo;
    if (delta > 60) {
      trend48hr = "Rising Rapidly";
    } else if (delta > 10) {
      trend48hr = "Rising";
    } else if (delta < -60) {
      trend48hr = "Falling Rapidly";
    } else if (delta < -10) {
      trend48hr = "Falling";
    } else {
      trend48hr = "Stable";
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
            minimum: 950,
            maximum: 1050,
            startAngle: 120,
            endAngle: 60,
            axisLineStyle: AxisLineStyle(
              thickness: 20,
              thicknessUnit: GaugeSizeUnit.logicalPixel,
            ),
            ranges: <GaugeRange>[
              GaugeRange(
                startValue: 950,
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
                endValue: 1050,
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
                  "24hr Trend: $trend24hr",
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
                  "48hr Trend: $trend48hr",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                angle: 90,
                positionFactor: 0.55,
              )
            ],
          )
        ],
      ),
    );
  }
}
