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

class _AirQualityPageState extends ConsumerState<AirQualityPage> {
  _AirQualityPageState({required this.oauthToken});
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
    timer = Timer(Duration(milliseconds: 30000), updateStatus);
    ref.read(thermostatStatusNotifierProvider.notifier).refreshStatus();
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine the available size dynamically
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    final ThermostatStatus status = ref.watch(thermostatStatusNotifierProvider);

    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Column(
            children: [
              // Dynamically adjust gauge size
              _AirQualityGauge(status, screenHeight * 0.3),
              _CO2Gauge(status, screenHeight * 0.3),
              _GasSensorWidget(status),
              // SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _AirQualityGauge(ThermostatStatus status, double size) {
    Color iaqColor =
        status.airqAccuracy == 0 ? Colors.grey : _getIaqColor(status.iaq);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Air Quality Index (IAQ)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        getLastHeardText(status.lastQtime),
        SizedBox(
          width: size,
          height: size,
          child: SfRadialGauge(axes: <RadialAxis>[
            RadialAxis(
              minimum: 0,
              maximum: 500,
              ranges: <GaugeRange>[
                GaugeRange(
                    startValue: 0, endValue: 50, color: Colors.greenAccent),
                GaugeRange(
                    startValue: 51, endValue: 100, color: Colors.green[800]),
                GaugeRange(
                    startValue: 101, endValue: 150, color: Colors.yellow),
                GaugeRange(startValue: 151, endValue: 200, color: Colors.amber),
                GaugeRange(startValue: 201, endValue: 250, color: Colors.red),
                GaugeRange(
                    startValue: 251, endValue: 350, color: Colors.purple[800]),
                GaugeRange(startValue: 351, endValue: 500, color: Colors.brown),
              ],
              pointers: <GaugePointer>[
                NeedlePointer(
                  value: status.iaq,
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
                  widget: Text(
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
                  widget: Text(
                    status.airqAccuracy == 0
                        ? "Not Calibrated!!"
                        : "Accuracy: ${getAccuracyText(status.airqAccuracy)}",
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _getAccuracyColor(status.airqAccuracy)),
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
    Color co2Color =
        status.airqAccuracy == 0 ? Colors.grey : _getCo2Color(status.iaq);
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
                GaugeRange(
                    startValue: 400, endValue: 1000, color: Colors.green),
                GaugeRange(
                    startValue: 1001, endValue: 2000, color: Colors.orange),
                GaugeRange(startValue: 2001, endValue: 5000, color: Colors.red),
              ],
              pointers: <GaugePointer>[
                NeedlePointer(
                  value: status.co2,
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
                  widget: Text(
                    status.airqAccuracy == 0
                        ? "Not Calibrated!!"
                        : "Accuracy: ${getAccuracyText(status.airqAccuracy)}",
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _getAccuracyColor(status.airqAccuracy)),
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

  Widget _GasSensorWidget(ThermostatStatus status) {
    return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        // crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Dangerous Gas Sensor  ',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(getBatteryIcon(status.batteryV)),
              Text("${status.batteryV}V"),
            ],
          ),
          getLastHeardText(status.lastGasTime),
          const SizedBox(height: 16),
          Column(children: [
            _buildLabeledStatus(
                label: "Carbon Monoxide", value: status.gasAlarm & 0x03),
            _buildLabeledStatus(
                label: "Ammonia/Propane/Butane",
                value: (status.gasAlarm & 0x0C) >> 2),
            _buildLabeledStatus(
                label: "Nitrogen Dioxide",
                value: (status.gasAlarm & 0x30) >> 4),
          ])
        ]);
  }

  IconData getBatteryIcon(batteryVoltage) {
    if (batteryVoltage >= 4.2) {
      return Icons.battery_charging_full;
    } else if (batteryVoltage >= 4.1) {
      return Icons.battery_full;
    } else if (batteryVoltage >= 4.0) {
      return Icons.battery_5_bar;
    } else if (batteryVoltage >= 3.8) {
      return Icons.battery_4_bar;
    } else if (batteryVoltage >= 3.7) {
      return Icons.battery_3_bar;
    } else if (batteryVoltage >= 3.6) {
      return Icons.battery_2_bar;
    } else if (batteryVoltage >= 3.5) {
      return Icons.battery_0_bar;
    } else {
      return Icons.battery_alert;
    }
  }

  Text getLastHeardText(lastTime) {
    DateTime currentTime = DateTime.now();
    Color textColor = Colors.red;
    DateFormat formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
    String lastHeard = 'Never';
    if (lastTime != null) {
      lastHeard = formatter.format(lastTime);
      int timezoneDifference = currentTime.timeZoneOffset.inMinutes;
      if (currentTime.timeZoneName == 'BST' ||
          currentTime.timeZoneName == 'GMT') {
        timezoneDifference = 0;
      }
      int diff =
          currentTime.difference(lastTime!).inMinutes - timezoneDifference;
      if (diff == 60) {
        //If exactly 60 mins then could be daylight savings
        diff = 0;
      }
      if (diff > 15) {
        textColor = Colors.red;
      } else if (diff > 8) {
        textColor = Colors.amber;
      } else {
        textColor = Colors.green;
      }
    }
    return Text(
      'Last Update: ${lastHeard}',
      style: TextStyle(
          fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
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
    if (val <= 50) return Colors.greenAccent;
    if (val <= 100) return Colors.green[800]!;
    if (val <= 150) return Colors.yellow;
    if (val <= 200) return Colors.amber;
    if (val <= 250) return Colors.red;
    if (val <= 350) return Colors.purple[800]!;
    return Colors.brown;
  }

  Color _getCo2Color(double val) {
    if (val <= 1000) return Colors.green;
    if (val <= 2000) return Colors.orange;
    return Colors.grey;
  }

  String getCO2Text(double val) {
    if (val <= 1000) return "Normal";
    if (val <= 2000) return "Ventilate";
    return "Danger!!!";
  }

  String getAccuracyText(int calibrationStatus) {
    if (calibrationStatus == 0) return "Not calibrated";
    if (calibrationStatus == 1) return "Poor";
    if (calibrationStatus == 2) return "Good";
    return "Excellent";
  }

  Color _getAccuracyColor(int calibrationStatus) {
    if (calibrationStatus == 0) return Colors.red;
    if (calibrationStatus == 1) return Colors.orange;
    if (calibrationStatus == 2) return Colors.yellow;
    return Colors.green;
  }

  Color _getValueColor(int val) {
    if (val == 3) return Colors.red;
    if (val == 2) return Colors.orange;
    if (val == 1) return Colors.yellow;
    return Colors.green;
  }

  Widget _buildLabeledStatus({required String label, required int value}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            children: [
              Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _getValueColor(value), fontSize: 16)),
            ],
          ),
        ),
        // const SizedBox(width: 8),
        Expanded(
          child: Column(
            children: [
              Text(_getAlarmStatus(value),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _getValueColor(value), fontSize: 16)),
            ],
          ),
        ),
      ],
    );
    //                     return Padding(
    //   padding: const EdgeInsets.symmetric(vertical: 4.0),
    //   child: Row(
    //     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    //     children: [
    //       Text(
    //         label,
    //         style: TextStyle(color: _getValueColor(value), fontSize: 16),
    //       ),
    //       Text(
    //         _getAlarmStatus(value),
    //         style: TextStyle(color: _getValueColor(value), fontSize: 16),
    //       ),
    //     ],
    //   ),
    // );
  }

  _getAlarmStatus(int status) {
    if (status == 3) {
      return "Critical!";
    } else if (status == 2) {
      return "High!";
    } else if (status == 1) {
      return "Warning!";
    } else {
      return "Normal";
    }
  }
}
