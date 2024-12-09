import 'package:flutter/material.dart';
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
  final List<Map<String, dynamic>> data = [
    {'label': 'Value 1', 'value': 30.0},
    {'label': 'Value 2', 'value': 70.0},
    {'label': 'Value 3', 'value': 50.0},
    {'label': 'Value 4', 'value': 85.0},
    {'label': 'Value 5', 'value': 15.0},
  ];

  @override
  Widget build(BuildContext context) {
    // Determine the available size dynamically
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    final ThermostatStatus status = ref.watch(thermostatStatusNotifierProvider);

    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Dynamically adjust gauge size
              _AirQualityGauge(status, screenWidth * 0.7),
              // SizedBox(height: 20),
              _CO2Gauge(status, screenWidth * 0.7),
              SizedBox(height: 20),
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Air Quality Index (IAQ)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SizedBox(
          width: size,
          height: size,
          child: SfRadialGauge(axes: <RadialAxis>[
            RadialAxis(
              minimum: 0,
              maximum: 100,
              ranges: <GaugeRange>[
                GaugeRange(startValue: 0, endValue: 50, color: Colors.red),
                GaugeRange(startValue: 50, endValue: 75, color: Colors.orange),
                GaugeRange(startValue: 75, endValue: 100, color: Colors.green),
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
                    status.iaq.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 22, // Larger text for larger gauges
                      fontWeight: FontWeight.bold,
                      color: _getValueColor(status.iaq), 
                    ), 
                  ),
                  angle: 90,
                  positionFactor: 0.5,
                ),
                GaugeAnnotation(
                  widget: 
                      Text(
                        "Accuracy: " + "Good",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _getAccuracyColor(2)
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'CO2 Level (ppm)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SizedBox(
          width: size,
          height: size,
          child: SfRadialGauge(axes: <RadialAxis>[
            RadialAxis(
              minimum: 0,
              maximum: 100,
              ranges: <GaugeRange>[
                GaugeRange(startValue: 0, endValue: 50, color: Colors.red),
                GaugeRange(startValue: 50, endValue: 75, color: Colors.orange),
                GaugeRange(startValue: 75, endValue: 100, color: Colors.green),
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
                      fontSize: 22, // Larger text for larger gauges
                      fontWeight: FontWeight.bold,
                      color: _getValueColor(status.co2), 
                    ), 
                  ),
                  angle: 90,
                  positionFactor: 0.5,
                ),
                GaugeAnnotation(
                  widget: 
                      Text(
                        "Accuracy: " + "Good",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _getAccuracyColor(2)
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
