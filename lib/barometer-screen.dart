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
  String _trend = "Stable";
  String oauthToken;
  late Timer timer;

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
    final screenWidth = MediaQuery.of(context).size.width;
    final BarometerStatus status = ref.watch(barometerStatusNotifierProvider);

    return Scaffold(
        body: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Column(
          children: [
            _BarometerGauge(
                status, screenWidth * (status.localUI ? 0.35 : 0.3)),
          ],
        ),
      ),
    ));
  }

  Widget _BarometerGauge(BarometerStatus status, double size) {
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
                positionFactor: 0.4,
              ),
              GaugeAnnotation(
                widget: Text(
                  "Trend: $_trend",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: _trend == "Rising"
                        ? Colors.green
                        : _trend == "Falling"
                            ? Colors.red
                            : Colors.blue,
                  ),
                ),
                angle: 90,
                positionFactor: 0.5,
              )
            ],
          )
        ],
      ),
    );
  }
}
