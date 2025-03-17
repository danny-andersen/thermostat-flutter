import 'package:flutter/material.dart';

class RelayControlPage extends StatefulWidget {
  @override
  _RelayControlPageState createState() => _RelayControlPageState();
}

class _RelayControlPageState extends State<RelayControlPage> {
  List<bool> relayStates = [false, false, false, false];
  String? selectedCommand;
  List<String> commandFiles = ['command1.sh', 'command2.sh', 'command3.sh'];

  void toggleRelay(int index) {
    setState(() {
      relayStates[index] = !relayStates[index];
    });
    // Add logic to send command to hardware
  }

  void executeCommand() {
    if (selectedCommand != null) {
      // Add logic to execute selected command file
      print('Executing $selectedCommand');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Relay Control')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ...List.generate(4, (index) {
              return SwitchListTile(
                title: Text('Relay ${index + 1}'),
                value: relayStates[index],
                onChanged: (value) => toggleRelay(index),
              );
            }),
            SizedBox(height: 20),
            DropdownButton<String>(
              value: selectedCommand,
              hint: Text('Select Command'),
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
              child: Text('Execute Command'),
            ),
          ],
        ),
      ),
    );
  }
}
