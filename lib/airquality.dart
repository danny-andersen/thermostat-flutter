import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';


class AirQualityPage extends ConsumerStatefulWidget {
  AirQualityPage({super.key, required this.oauthToken});
  String oauthToken;
  late _AirQualityPageState statePage;
  //  =
  //     _ThermostatPageState(oauthToken: "BLANK", localUI: false);
  // // _ThermostatPageState state = _ThermostatPageState(oauthToken: "BLANK");

  @override
  ConsumerState<AirQualityPage> createState() {
    statePage = _AirQualityPageState(oauthToken: oauthToken);
    return statePage;
  }
}

class _AirQualityPageState extends ConsumerState< AirQualityPage> {
  _AirQualityPageState({required this.oauthToken});
  String oauthToken;
  late Timer timer;

  final List<Map<String, dynamic>> data = [
    {'label': 'Value 1', 'value': 30.0},
    {'label': 'Value 2', 'value': 70.0},
    {'label': 'Value 3', 'value': 50.0},
    {'label': 'Value 4', 'value': 85.0},
    {'label': 'Value 5', 'value': 15.0},
  ];

  @override
  void initState() {
    //Trigger first refresh shortly after widget initialised, to allow state to be initialised
    timer = Timer(const Duration(seconds: 1), updateStatus);
    super.initState();
  }

  void updateStatus() {
    //Note: Set timer before we call refresh otherwise will always have a get in progress
    timer = Timer(
        Duration(milliseconds: 30000), updateStatus);
    ref.read(thermostatStatusNotifierProvider.notifier).refreshStatus();
    ref.read(cameraStatusNotifierProvider.notifier).refreshStatus();
  }

  @override
  Widget build(BuildContext context) {
    // Determine the available size dynamically
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    final ThermostatStatus status = ref.watch(thermostatStatusNotifierProvider);

    DateTime currentTime = DateTime.now();
    Color textColor = Colors.red;
    String lastQHeardStr = "Never";

    if (status.lastQtime != null) {
      DateFormat formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
      lastQHeardStr = formatter.format(status.lastQtime!);
      int timezoneDifference = currentTime.timeZoneOffset.inMinutes;
      if (currentTime.timeZoneName == 'BST' ||
          currentTime.timeZoneName == 'GMT') {
        timezoneDifference = 0;
      }
      int diff =
          currentTime.difference(status.lastQtime!).inMinutes - timezoneDifference;
      if (diff == 60) {
        //If exactly 60 mins then could be daylight savings
        diff = 0;
      }
      if (diff > 15) {
        textColor = Colors.red;
      } else if (diff > 5) {
        textColor = Colors.amber;
      } else {
        textColor = Colors.green;
      }
    }

    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Column(
            children: [
              Text(
                'Last Update: ${lastQHeardStr}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
              ),
              // Dynamically adjust gauge size
              _AirQualityGauge(status, screenHeight * 0.3),
              _CO2Gauge(status, screenHeight * 0.3),
              // SizedBox(height: 10),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: data
                    .map((item) => _buildLabeledValue(
                          label: item['label'],
                          value: item['value'],
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
}

Widget _AirQualityGauge(ThermostatStatus status, double size) {
    Color iaqColor = status.airqAccuracy == 0 ? Colors.grey : _getIaqColor(status.iaq);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Air Quality Index (IAQ)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SizedBox(
          width: size,
          height: size,
          child: SfRadialGauge(axes: <RadialAxis>[
            RadialAxis(
              minimum: 0,
              maximum: 500,
              ranges: <GaugeRange>[
                GaugeRange(startValue: 0, endValue: 50, color: Colors.greenAccent),
                GaugeRange(startValue: 51, endValue: 100, color: Colors.green[800]),
                GaugeRange(startValue: 101, endValue: 150, color: Colors.yellow),
                GaugeRange(startValue: 151, endValue: 200, color: Colors.amber),
                GaugeRange(startValue: 201, endValue: 250, color: Colors.red),
                GaugeRange(startValue: 251, endValue: 350, color: Colors.purple[800]),
                GaugeRange(startValue: 351, endValue: 500, color: Colors.brown),
              ],
              pointers: <GaugePointer>[
                NeedlePointer(value: status.iaq,
                      enableAnimation: true,
                      animationType: AnimationType.ease,
                      needleEndWidth: 5,
                      lengthUnit: GaugeSizeUnit.factor,
                      needleLength: 0.8,
                ),
              ],
              annotations: <GaugeAnnotation>[
                GaugeAnnotation(
                  widget: Text(
                    "${status.iaq.toStringAsFixed(1)}",
                    style: TextStyle(
                      fontSize: 20, // Larger text for larger gauges
                      fontWeight: FontWeight.bold,
                      color: iaqColor, 
                    ), 
                  ),
                  angle: 90,
                  positionFactor: 0.2,
                ),
                GaugeAnnotation(
                  widget: Text(
                    "${getIaqText(status.iaq)}",
                    style: TextStyle(
                      fontSize: 16, // Larger text for larger gauges
                      fontWeight: FontWeight.bold,
                      color: iaqColor, 
                    ), 
                  ),
                  angle: 90,
                  positionFactor: 0.35,
                ),
                GaugeAnnotation(
                  widget: 
                      Text(
                        "VOC: ${status.voc.toStringAsFixed(2)}",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: iaqColor, 
                        ),
                      ),
                  angle: 90,
                  positionFactor: 0.5, // Adjust to position accuracy label
                ),
                GaugeAnnotation(
                  widget: 
                      Text(
                        status.airqAccuracy == 0 ? "Not Calibrated!!" : "Accuracy: ${getAccuracyText(status.airqAccuracy)}",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _getAccuracyColor(status.airqAccuracy)
                        ),
                      ),
                  angle: 90,
                  positionFactor: 0.7, // Adjust to position accuracy label
                ),
              ],
            ),
          ]),
        ),
      ],
    );
  }

Widget _CO2Gauge(ThermostatStatus status, double size) {
    Color co2Color = status.airqAccuracy == 0 ? Colors.grey : _getCo2Color(status.iaq);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'CO2 Level (ppm)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SizedBox(
          width: size,
          height: size,
          child: SfRadialGauge(axes: <RadialAxis>[
            RadialAxis(
              minimum: 400,
              maximum: 5000,
              ranges: <GaugeRange>[
                GaugeRange(startValue: 400, endValue: 1000, color: Colors.green),
                GaugeRange(startValue: 1001, endValue: 2000, color: Colors.orange),
                GaugeRange(startValue: 2001, endValue: 5000, color: Colors.red),
              ],
              pointers: <GaugePointer>[
                NeedlePointer(value: status.co2,
                      enableAnimation: true,
                      animationType: AnimationType.ease,
                      needleEndWidth: 5,
                      lengthUnit: GaugeSizeUnit.factor,
                      needleLength: 0.8,
                ),
              ],
              annotations: <GaugeAnnotation>[
                GaugeAnnotation(
                  widget: Text(
                    status.co2.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 20, // Larger text for larger gauges
                      fontWeight: FontWeight.bold,
                      color: co2Color, 
                    ), 
                  ),
                  angle: 90,
                  positionFactor: 0.3,
                ),
                GaugeAnnotation(
                  widget: Text(
                    "${getCO2Text(status.co2)}",
                    style: TextStyle(
                      fontSize: 16, // Larger text for larger gauges
                      fontWeight: FontWeight.bold,
                      color: co2Color, 
                    ), 
                  ),
                  angle: 90,
                  positionFactor: 0.45,
                ),
                GaugeAnnotation(
                  widget: 
                      Text(
                        status.airqAccuracy == 0 ? "Not Calibrated!!" : "Accuracy: ${getAccuracyText(status.airqAccuracy)}",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _getAccuracyColor(status.airqAccuracy)
                        ),
                      ),
                  angle: 90,
                  positionFactor: 0.7, // Adjust to position accuracy label
                ),
              ],
            ),
          ]),
        ),
      ],
    );
  }

  String getIaqText(double iaq) {
    if (iaq <= 50) return "Excellent";
    if (iaq <= 100) return "Good";
    if (iaq <= 150) return "Lightly polluted";
    if (iaq <= 200) return "Polluted - Ventilate";
    if (iaq <= 250) return "Heavily Polluted";
    if (iaq <= 350) return "Severely Polluted";
    return "Extreme Pollution";

  }

  Color _getIaqColor(double val) {
    if (val <= 50) return  Colors.greenAccent;
    if (val <= 100) return Colors.green[800]!;
    if (val <= 150) return Colors.yellow;
    if (val <= 200) return Colors.amber;
    if (val <= 250) return Colors.red;
    if (val <= 350) return Colors.purple[800]!;
    return Colors.brown;
  }

  Color _getCo2Color(double val) {
    if (val <= 1000) return  Colors.green;
    if (val <= 2000) return Colors.orange;
    return Colors.grey;
  }

  String getCO2Text(double val) {
    if (val <= 1000) return  "Normal";
    if (val <= 2000) return "Ventilate";
    return "Danger!!!";

  }

  String getAccuracyText(int calibrationStatus) {
    if (calibrationStatus == 0) return "Not calibrated";
    if (calibrationStatus == 1) return  "Poor";
    if (calibrationStatus == 2) return "Good";
    return "Excellent";
  }

  Color _getAccuracyColor(int calibrationStatus) {
    if (calibrationStatus == 0) return Colors.red;
    if (calibrationStatus == 1) return Colors.orange;
    if (calibrationStatus == 2) return Colors.yellow;
    return Colors.green;
  }

 Color _getValueColor(double val) {
      if (val < 50) return Colors.red;
      if (val < 75) return Colors.orange;
      return Colors.green;
    }

  Widget _buildLabeledValue({required String label, required double value}) {

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: _getValueColor(value), fontSize: 16),
          ),
          Text(
            value.toString(),
            style: TextStyle(color: _getValueColor(value), fontSize: 16),
          ),
        ],
      ),
    );
  }
}
