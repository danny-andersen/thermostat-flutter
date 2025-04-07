import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

class RelayControlPage extends ConsumerStatefulWidget {
  RelayControlPage({super.key, required this.oauthToken});
  String oauthToken;
  late _RelayControlPageState statePage;
  //  =
  //     _ThermostatPageState(oauthToken: "BLANK", localUI: false);
  // // _ThermostatPageState state = _ThermostatPageState(oauthToken: "BLANK");

  @override
  ConsumerState<RelayControlPage> createState() {
    statePage = _RelayControlPageState(oauthToken: oauthToken);
    return statePage;
  }
}

class _RelayControlPageState extends ConsumerState<RelayControlPage> {
  _RelayControlPageState({required this.oauthToken});
  String oauthToken;

  String? selectedCommand;
  List<String> commandFiles = ['cluster_on.txt', 'cluster_off.txt'];
  late Timer timer;

  @override
  void initState() {
    //Trigger first refresh shortly after widget initialised, to allow state to be initialised
    timer = Timer(const Duration(seconds: 1), updateStatus);
    super.initState();
  }

  void setSecret(final String token) {
    oauthToken = token;
    ref.read(relayStatusNotifierProvider).oauthToken = token;
  }

  int getRefreshTimerDurationMs() {
    //If local UI refresh quickly to immediate feedback
    //If on Local lan can get files quickly directly from control station, unless there is an issue
    //e.g. request is hanging, in which case get from dropbox less frequently
    final provider = ref.read(relayStatusNotifierProvider);
    return provider.onLocalLan && !provider.localGetInProgress ? 10000 : 20000;
  }

  void updateStatus() {
    //Note: Set timer before we call refresh otherwise will always have a get in progress
    timer = Timer(
        Duration(milliseconds: getRefreshTimerDurationMs()), updateStatus);
    ref.read(relayStatusNotifierProvider.notifier).refreshStatus();
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  void setRelayState(int index, bool state) {
    ref.read(relayStatusNotifierProvider.notifier).setRelayState(index, state);
  }

  void fetchRelayStates() {
    ref.read(relayStatusNotifierProvider.notifier).refreshStatus();
  }

  void executeCommand() {
    if (selectedCommand != null) {
      // Add logic to execute selected command file
      print('Executing $selectedCommand');
    }
  }

  @override
  Widget build(BuildContext context) {
    final RelayStatus status = ref.watch(relayStatusNotifierProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text('Relay Control'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: fetchRelayStates,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                    child: Center(
                        child: Text('Relay',
                            style: TextStyle(fontWeight: FontWeight.bold)))),
                Expanded(
                    child: Center(
                        child: Text('Req State',
                            style: TextStyle(fontWeight: FontWeight.bold)))),
                Expanded(
                    child: Center(
                        child: Text('Actual State',
                            style: TextStyle(fontWeight: FontWeight.bold)))),
                Expanded(
                    child: Center(
                        child: Text('Controls',
                            style: TextStyle(fontWeight: FontWeight.bold)))),
                Expanded(
                    child: Center(
                        child: Text(' ',
                            style: TextStyle(fontWeight: FontWeight.bold)))),
              ],
            ),
            Divider(),
            ...List.generate(6, (index) {
              return Row(
                children: [
                  Expanded(child: Center(child: Text('${index + 1}'))),
                  Expanded(
                    child: Center(
                      child: Icon(
                        status.requestedRelayStates[index]
                            ? Icons.power
                            : Icons.power_off,
                        color: status.requestedRelayStates[index]
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Align(
                        alignment: Alignment.center,
                        child: Icon(
                          status.actualRelayStates[index]
                              ? Icons.check_circle
                              : Icons.cancel,
                          color: status.actualRelayStates[index]
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                      child: Center(
                          child: Align(
                    alignment: Alignment.center,
                    child: ElevatedButton(
                      onPressed: () => setRelayState(index, true),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.fromLTRB(0, 5, 0, 5),
                        backgroundColor: status.requestedRelayStates[index]
                            ? Colors.green
                            : Colors.grey,
                      ),
                      child: Text('ON'),
                    ),
                  ))),
                  Expanded(
                    child: Center(
                      child: Align(
                        alignment: Alignment.center,
                        child: ElevatedButton(
                          onPressed: () => setRelayState(index, false),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.fromLTRB(0, 5, 0, 5),
                            backgroundColor: !status.requestedRelayStates[index]
                                ? Colors.red
                                : Colors.grey,
                          ),
                          child: Text('OFF'),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 50),
                ],
              );
            }),
            SizedBox(height: 20),
            Text('Select Command Script',
                style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButton<String>(
              value: selectedCommand,
              hint: Text('Select Script'),
              items: commandFiles.map((cmd) {
                return DropdownMenuItem(
                  value: cmd,
                  child: Text(cmd),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedCommand = value;
                });
              },
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: executeCommand,
              child: Text('Execute Command Script'),
            ),
          ],
        ),
      ),
    );
  }
}
