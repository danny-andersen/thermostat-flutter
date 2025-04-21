import 'dart:io';
import 'dart:convert';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:dart_ping/dart_ping.dart';
import 'package:flutter/material.dart';
import 'package:sprintf/sprintf.dart';
import 'package:fast_csv/csv_converter.dart' as csv;

import 'dropbox-api.dart';
import 'local_settings.dart';

part 'providers.g.dart';

const String controlStnCommandFile = "/command.txt";
const String thermostatLocalCommandFile = "/home/danny/thermostat/command.txt";
const String remoteStnCommandFile = "command-cam";
const String nodeTemperatureFile = "/clusterNodesTemp.txt";

void toggleLights(stationId, onLocalLan, lightStatus) {
  String contents = "$stationId: Lights ${lightStatus > 0 ? 'OFF' : 'ON'}";
  if (onLocalLan) {
    Future<bool> localSend = LocalSendReceive.sendLocalFile(
        fileName: "/home/danny/control_station$controlStnCommandFile",
        contents: contents);
    localSend.then((success) {
      if (!success) {
        print("On local Lan but failed to send, so send again using Dropbox");
        toggleLights(stationId, false, lightStatus);
      }
    });
  } else {
    //Remote from control station - use Dropbox to send command
    DropBoxAPIFn.sendDropBoxFile(
        // oauthToken: state.oauthToken,
        fileToUpload: controlStnCommandFile,
        contents: contents);
  }
}

void toggleCamera(stationId, onLocalLan, camStatus) {
  String contents = "camera-${camStatus > 0 ? 'off' : 'on'}";
  sendCommandToHost(stationId, onLocalLan, contents);
}

void resetStation(stationId, onLocalLan) {
  String contents = "reset";
  sendCommandToHost(stationId, onLocalLan, contents);
}

void sendCommandToHost(stationId, onLocalLan, contents) {
  if (onLocalLan) {
    Future<bool> localSend = LocalSendReceive.sendLocalFile(
        fileName:
            "/home/danny/${stationId == 0 ? "monitor_home" : stationsWithSwitch.contains(stationId) ? "camera_with_switch" : "camera_station"}$controlStnCommandFile",
        contents: contents,
        hostToSend: hostNameById[stationId]);
    localSend.then((success) {
      if (!success) {
        print("On local Lan but failed to send, so send again using Dropbox");
        resetStation(stationId, false);
      }
    });
  } else {
    //Remote from control station - use Dropbox to send command
    DropBoxAPIFn.sendDropBoxFile(
        // oauthToken: state.oauthToken,
        fileToUpload: stationId == 0
            ? controlStnCommandFile
            : "/$remoteStnCommandFile$stationId.txt",
        contents: contents);
  }
}

void areWeOnLocalNetwork(Function callback) {
  NetworkInterface.list().then((interfaces) {
    for (NetworkInterface interface in interfaces) {
      for (InternetAddress addr in interface.addresses) {
        if (addr.address.contains('192.168.')) {
          //On a private network
          //Need to ping local thermostat to check we are on the same lan
          Ping('thermostat-host', count: 1).stream.first.then((pingData) {
            if (pingData.error == null) {
              callback(true);
            } else {
              callback(false);
            }
          }).catchError((onError) {
            callback(false);
          });
          break;
        }
      }
    }
  });
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

Color getIaqColor(double val) {
  if (val <= 50) return Colors.greenAccent;
  if (val <= 100) return Colors.green[800]!;
  if (val <= 150) return Colors.yellow;
  if (val <= 200) return Colors.amber;
  if (val <= 250) return Colors.red;
  if (val <= 350) return Colors.purple[800]!;
  return Colors.brown;
}

Color getCo2Color(double val) {
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

Color getAccuracyColor(int calibrationStatus) {
  if (calibrationStatus == 0) return Colors.red;
  if (calibrationStatus == 1) return Colors.orange;
  if (calibrationStatus == 2) return Colors.yellow;
  return Colors.green;
}

Color getAlarmColor(int val) {
  if (val == 3) return Colors.red;
  if (val == 2) return Colors.orange;
  if (val == 1) return Colors.yellow;
  return Colors.green;
}

Widget getAllGasAlarmStatus(ThermostatStatus status) {
  String statusStr = "All OK";
  Color alarmColor = Colors.green;
  if (status.lastGasTime != null) {
    if (status.gasAlarm == 0x80) {
      statusStr = "Possible Gas Event";
      alarmColor = Colors.deepOrange;
    }
    int co2Status = status.gasAlarm & 0x03;
    int nh3Status = (status.gasAlarm & 0x0C) >> 2;
    int no2Status = (status.gasAlarm & 0x30) >> 4;
    if (co2Status > 0) {
      statusStr = "Carbon Dioxide ${getAlarmStatus(co2Status)}";
      alarmColor = getAlarmColor(co2Status);
    } else if (nh3Status > 0) {
      statusStr = "Ammonia/Propane/Butane ${getAlarmStatus(nh3Status)}";
      alarmColor = getAlarmColor(nh3Status);
    } else if (no2Status > 0) {
      statusStr = "Nitrogen Dioxide ${getAlarmStatus(no2Status)}";
      alarmColor = getAlarmColor(no2Status);
    }
  } else {
    statusStr = "??";
    alarmColor = Colors.deepOrange;
  }
  return Text('Gas Sensor: $statusStr',
      textAlign: TextAlign.left,
      style: TextStyle(
        fontSize: status.localUI ? 20 : 15,
        fontWeight: FontWeight.bold,
        color: alarmColor,
      ));
}

String getAlarmStatus(int status) {
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

class ThermostatStatus {
  ThermostatStatus({required this.localUI, required this.onLocalLan});
  ThermostatStatus.fromStatus(ThermostatStatus oldState) {
    localUI = oldState.localUI;
    onLocalLan = oldState.onLocalLan;
    localGetInProgress = oldState.localGetInProgress;
    oauthToken = oldState.oauthToken;
    currentTemp = oldState.currentTemp;
    lastStatusReadTime = oldState.lastStatusReadTime;
    forecastExtTemp = oldState.forecastExtTemp;
    windStr = oldState.windStr;
    lastForecastReadTime = oldState.lastForecastReadTime;
    motdStr = oldState.motdStr;
    lastMotdReadTime = oldState.lastMotdReadTime;
    setTemp = oldState.setTemp;
    nextSetTempStr = oldState.nextSetTempStr;
    requestedTemp = oldState.requestedTemp;
    humidity = oldState.humidity;
    lastHeardFrom = oldState.lastHeardFrom;
    intPirState = oldState.intPirState;
    intPirLastEvent = oldState.intPirLastEvent;

    boilerOn = oldState.boilerOn;
    minsToSetTemp = oldState.minsToSetTemp;

    iaq = oldState.iaq;
    co2 = oldState.co2;
    voc = oldState.voc;
    airqAccuracy = oldState.airqAccuracy;
    lastQtime = oldState.lastQtime;
    gasAlarm = oldState.gasAlarm;
    lastGasTime = oldState.lastGasTime;
    batteryV = oldState.batteryV;

    requestOutstanding = oldState.requestOutstanding;
  }

  ThermostatStatus.fromParams(
      this.localUI,
      this.onLocalLan,
      this.localGetInProgress,
      this.oauthToken,
      this.currentTemp,
      this.lastStatusReadTime,
      this.forecastExtTemp,
      this.windStr,
      this.lastForecastReadTime,
      this.motdStr,
      this.lastMotdReadTime,
      this.setTemp,
      this.nextSetTempStr,
      this.requestedTemp,
      this.humidity,
      this.lastHeardFrom,
      this.intPirState,
      this.intPirLastEvent,
      this.boilerOn,
      this.minsToSetTemp,
      this.iaq,
      this.co2,
      this.voc,
      this.airqAccuracy,
      this.lastQtime,
      this.gasAlarm,
      this.lastGasTime,
      this.batteryV,
      this.requestOutstanding);

  ThermostatStatus copyWith(
      {bool? localUI,
      bool? onLocalLan,
      bool? localGetInProgress,
      String? oauthToken,
      double? currentTemp,
      DateTime? lastStatusReadTime,
      double? forecastExtTemp,
      String? windStr,
      DateTime? lastForecastReadTime,
      String? motdStr,
      DateTime? lastMotdReadTime,
      double? setTemp,
      String? nextSetTempStr,
      double? requestedTemp,
      double? humidity,
      DateTime? lastHeardFrom,
      bool? intPirState,
      String? intPirLastEvent,
      bool? boilerOn,
      int? minsToSetTemp,
      double? iaq,
      double? co2,
      double? voc,
      int? airqAccuracy,
      DateTime? lastQtime,
      int? gasAlarm,
      DateTime? lastGasTime,
      double? batteryV,
      bool? requestOutstanding}) {
    return ThermostatStatus.fromParams(
        localUI ?? this.localUI,
        onLocalLan ?? this.onLocalLan,
        localGetInProgress ?? this.localGetInProgress,
        oauthToken ?? this.oauthToken,
        currentTemp ?? this.currentTemp,
        lastStatusReadTime ?? this.lastStatusReadTime,
        forecastExtTemp ?? this.forecastExtTemp,
        windStr ?? this.windStr,
        lastForecastReadTime ?? this.lastForecastReadTime,
        motdStr ?? this.motdStr,
        lastMotdReadTime ?? this.lastMotdReadTime,
        setTemp ?? this.setTemp,
        nextSetTempStr ?? this.nextSetTempStr,
        requestedTemp ?? this.requestedTemp,
        humidity ?? this.humidity,
        lastHeardFrom ?? this.lastHeardFrom,
        intPirState ?? this.intPirState,
        intPirLastEvent ?? this.intPirLastEvent,
        boilerOn ?? this.boilerOn,
        minsToSetTemp ?? this.minsToSetTemp,
        iaq ?? this.iaq,
        co2 ?? this.co2,
        voc ?? this.voc,
        airqAccuracy ?? this.airqAccuracy,
        lastQtime ?? this.lastQtime,
        gasAlarm ?? this.gasAlarm,
        lastGasTime ?? this.lastGasTime,
        batteryV ?? this.batteryV,
        requestOutstanding ?? this.requestOutstanding);
  }

  late bool localUI;
  late bool onLocalLan;
  bool localGetInProgress = false;
  String oauthToken = "";
  double currentTemp = -100.0;
  DateTime lastStatusReadTime = DateTime(2000);
  double forecastExtTemp = -100.0;
  String windStr = "";
  DateTime lastForecastReadTime = DateTime(2000);
  String motdStr = "";
  DateTime lastMotdReadTime = DateTime(2000);
  double setTemp = 0.0;
  String nextSetTempStr = "";
  double requestedTemp = 0.0;
  double humidity = 0.0;
  DateTime? lastHeardFrom;
  bool intPirState = false;
  String intPirLastEvent = "";

  bool boilerOn = false;
  int minsToSetTemp = 0;

  double iaq = 0.0;
  double co2 = 400.0;
  double voc = 0.0;
  int airqAccuracy = 0;
  DateTime? lastQtime;
  int gasAlarm = 0;
  DateTime? lastGasTime;
  double batteryV = 0.0;

  bool requestOutstanding = false;
}

@riverpod
class ThermostatStatusNotifier extends _$ThermostatStatusNotifier {
  final String statusFile = "/thermostat_status.txt";
  final String localControlStatusFile =
      "/home/danny/control_station/status.txt";

  final String setTempFile = "/setTemp.txt";
  final String localSetTempFile = "/home/danny/thermostat/setTemp.txt";
  final String localForecastExt = "/home/danny/thermostat/setExtTemp.txt";
  final String localMotd = "/home/danny/thermostat/motd.txt";
  final String localDisplayOnFile = "/home/danny/thermostat/displayOn.txt";

  // late ThermostatStatus newState;

  @override
  ThermostatStatus build() {
    //Determine if running local to thermostat by the presence of the thermostat dir
    bool local = false;
    ThermostatStatus status;
    FileStat thermStat = FileStat.statSync("/home/danny/thermostat");
    if (thermStat.type != FileSystemEntityType.notFound) {
      local = true;
    }
    status = ThermostatStatus(localUI: local, onLocalLan: local ? true : false);
    //Check if we are on local LAN
    areWeOnLocalNetwork((onlan) => status.onLocalLan = onlan);
    return status;
  }

  void refreshStatus() {
    // getSetTemp();
    bool updateState = true;
    if (state.localUI) {
      //Check that thermostat has turned backlight on
      //if not then do nothing as display not visible
      updateState = FileStat.statSync(localDisplayOnFile).type !=
          FileSystemEntityType.notFound;
    }
    if (updateState) {
      getStatus();
    }
  }

  void getStatus() {
    if (state.localUI) {
      FileStat statusStat = FileStat.statSync(localControlStatusFile);
      FileStat motdStat = FileStat.statSync(localMotd);
      FileStat fcStat = FileStat.statSync(localForecastExt);
      //Only update state (and so the display) if something has changed
      if (statusStat.changed.isAfter(state.lastStatusReadTime) ||
          motdStat.changed.isAfter(state.lastMotdReadTime) ||
          fcStat.changed.isAfter(state.lastForecastReadTime)) {
        if (statusStat.type != FileSystemEntityType.notFound &&
            statusStat.changed.isAfter(state.lastStatusReadTime)) {
          String statusStr = File(localControlStatusFile).readAsStringSync();
          processStatus(localControlStatusFile, statusStr);
          state = state.copyWith(lastStatusReadTime: statusStat.changed);
        }
        if (motdStat.type != FileSystemEntityType.notFound &&
            motdStat.changed.isAfter(state.lastMotdReadTime)) {
          String contents = File(localMotd).readAsStringSync();
          String motd = contents.split('\n')[0];
          state = state.copyWith(
              motdStr: motd.replaceAll(RegExp(r'\.'), '.\n'),
              lastMotdReadTime: motdStat.changed);
        }
        if (fcStat.type != FileSystemEntityType.notFound &&
            fcStat.changed.isAfter(state.lastForecastReadTime)) {
          String contents = File(localForecastExt).readAsStringSync();
          processForecast(contents);
          state = state.copyWith(lastForecastReadTime: fcStat.changed);
        }
      }
    } else if (state.onLocalLan && !state.localGetInProgress) {
      //Use ftp to retrieve status file direct from control station
      Future<Map<String, String>> localReceive =
          LocalSendReceive.getLocalFile([localControlStatusFile]);
      state.localGetInProgress = true;
      localReceive.then((files) {
        bool success = false;
        state.localGetInProgress = false;
        if (files.containsKey(localControlStatusFile)) {
          String? statusStr = files[localControlStatusFile];
          if (statusStr != null) {
            processStatus(localControlStatusFile, statusStr);
            success = true;
          }
        }
        if (!success) {
          //Failed to get some status files locally, use dropbox
          DropBoxAPIFn.getDropBoxFile(
            // oauthToken: state.oauthToken,
            fileToDownload: statusFile,
            callback: processStatus,
            contentType: ContentType.text,
            timeoutSecs: 5,
          );
        }
      });
    } else {
      DropBoxAPIFn.getDropBoxFile(
        // oauthToken: state.oauthToken,
        fileToDownload: statusFile,
        callback: processStatus,
        contentType: ContentType.text,
        timeoutSecs: 5,
      );
    }
  }

  void processStatus(String filename, String contents) {
    //Note: filename parameter is not used but is required by File loader callback
    contents.split('\n').forEach((line) {
      if (line.startsWith('Current temp:')) {
        double newTemp = state.currentTemp;
        if (line.split(':')[1].trim().startsWith('Not Set')) {
          newTemp = -100.0;
        } else {
          try {
            newTemp = double.parse(line.split(':')[1].trim());
          } on FormatException {
            print("Received non-double Current temp format: $line");
          }
        }
        if (newTemp != state.currentTemp) {
          state = state.copyWith(currentTemp: newTemp);
        }
      } else if (line.startsWith('Current set temp:')) {
        double newSetTemp = state.setTemp;
        if (line.split(':')[1].trim().startsWith('Not Set')) {
          newSetTemp = -100.0;
        } else {
          try {
            newSetTemp = double.parse(line.split(':')[1].trim());
//              print("Req Temp: $requestedTemp, request out? $requestOutstanding");
            if (state.requestedTemp.toStringAsFixed(1) ==
                    state.setTemp.toStringAsFixed(1) &&
                state.requestOutstanding) {
              state = state.copyWith(requestOutstanding: false);
            }
            if (!state.requestOutstanding &&
                state.requestedTemp.toStringAsFixed(1) !=
                    state.setTemp.toStringAsFixed(1)) {
              state = state.copyWith(requestedTemp: state.setTemp);
            }
            if (newSetTemp != state.setTemp) {
              state = state.copyWith(setTemp: newSetTemp);
            }
          } on FormatException {
            print("Received non-double setTemp format: $line");
          }
        }
      } else if (line.startsWith('Next set temp:')) {
        String newNextSetTempStr = state.nextSetTempStr;
        List<String> fields = line.split(':');
        newNextSetTempStr = "${fields[1].trim()}:${fields[2].trim()}";
        if (newNextSetTempStr != state.nextSetTempStr) {
          state = state.copyWith(nextSetTempStr: newNextSetTempStr);
        }
      } else if (line.startsWith('External temp:')) {
        double newForecastExtTemp = state.forecastExtTemp;
        if (line.split(':')[1].trim().startsWith('Not Set')) {
          newForecastExtTemp = -100.0;
        } else {
          try {
            newForecastExtTemp = double.parse(line.split(':')[1].trim());
          } on FormatException {
            print("Received non-double forecast extTemp format: $line");
          }
          if (newForecastExtTemp != state.forecastExtTemp) {
            state = state.copyWith(forecastExtTemp: newForecastExtTemp);
          }
        }
      } else if (line.startsWith('Heat on?')) {
        bool newBoilerOn = (line.split('?')[1].trim() == 'Yes');
        if (newBoilerOn != state.boilerOn) {
          state = state.copyWith(boilerOn: newBoilerOn);
        }
      } else if (line.startsWith('Mins to set temp')) {
        int newMinsToSetTemp = state.minsToSetTemp;
        try {
          newMinsToSetTemp = int.parse(line.split(':')[1].trim());
        } on FormatException {
          try {
            newMinsToSetTemp = double.parse(line.split(':')[1].trim()).toInt();
          } on FormatException {
            print("Received non-int minsToSetTemp format: $line");
          }
          if (newMinsToSetTemp != state.minsToSetTemp) {
            state = state.copyWith(minsToSetTemp: newMinsToSetTemp);
          }
        }
      } else if (line.startsWith('Last heard time')) {
        String dateStr = line.substring(line.indexOf(':') + 2, line.length);
        DateTime newLastHeardFrom = DateTime.parse(dateStr);
        if (newLastHeardFrom != state.lastHeardFrom) {
          state = state.copyWith(lastHeardFrom: newLastHeardFrom);
        }
      } else if (line.startsWith('Current humidity')) {
        String str = line.substring(line.indexOf(':') + 2, line.length);
        double newhumidity = double.parse(str);
        if (newhumidity != state.humidity) {
          state = state.copyWith(humidity: newhumidity);
        }
      } else if (line.startsWith('Last PIR')) {
        String newPirLastEvent =
            line.substring(line.indexOf(':') + 1, line.length);
        if (newPirLastEvent != state.intPirLastEvent) {
          state = state.copyWith(intPirLastEvent: newPirLastEvent);
        }
      } else if (line.startsWith('PIR:')) {
        String str = line.substring(line.indexOf(':') + 1, line.length);
        bool newPirState = str.contains('1');
        if (newPirState != state.intPirState) {
          state = state.copyWith(intPirState: newPirState);
        }
      }
      processGasStatus(contents);
    });
  }

  void processGasStatus(String contents) {
    contents.split('\n').forEach((line) {
      if (line.startsWith('IAQ:')) {
        String str = line.substring(line.indexOf(':') + 1, line.length);
        double newIaq = double.parse(str);
        if (newIaq != state.iaq) {
          state = state.copyWith(iaq: newIaq);
        }
      } else if (line.startsWith('CO2:')) {
        String str = line.substring(line.indexOf(':') + 1, line.length);
        double newCO2 = double.parse(str);
        if (newCO2 != state.co2) {
          state = state.copyWith(co2: newCO2);
        }
      } else if (line.startsWith('VOC:')) {
        String str = line.substring(line.indexOf(':') + 1, line.length);
        double newVOC = double.parse(str);
        if (newVOC != state.voc) {
          state = state.copyWith(voc: newVOC);
        }
      } else if (line.startsWith('AIRQ_ACC:')) {
        String str = line.substring(line.indexOf(':') + 1, line.length);
        int newacc = int.parse(str);
        if (newacc != state.airqAccuracy) {
          state = state.copyWith(airqAccuracy: newacc);
        }
      } else if (line.startsWith('Last Q time:')) {
        String dateStr = line.substring(line.indexOf(':') + 2, line.length);
        if (!dateStr.contains('Never')) {
          DateTime newLastQ = DateTime.parse(dateStr);
          if (newLastQ != state.lastQtime) {
            state = state.copyWith(lastQtime: newLastQ);
          }
        }
      } else if (line.startsWith('GAS:')) {
        String str = line.substring(line.indexOf(':') + 1, line.length);
        int newgas = int.parse(str);
        if (newgas != state.gasAlarm) {
          state = state.copyWith(gasAlarm: newgas);
        }
      } else if (line.startsWith('Last Gas time:')) {
        String dateStr = line.substring(line.indexOf(':') + 2, line.length);
        if (!dateStr.contains('Never')) {
          DateTime newLastG = DateTime.parse(dateStr);
          if (newLastG != state.lastQtime) {
            state = state.copyWith(lastGasTime: newLastG);
          }
        }
      } else if (line.startsWith('Gas BV:')) {
        String str = line.substring(line.indexOf(':') + 2, line.length);
        double newbv = double.parse(str);
        if (newbv != state.batteryV) {
          state = state.copyWith(batteryV: newbv);
        }
      }
    });
  }

  void processForecast(String contents) {
    List<String> lines = contents.split('\n');
    double newForecastTemp = state.forecastExtTemp;
    try {
      newForecastTemp = double.parse(lines[0].trim());
    } on FormatException {
      print("Received non-double forecast temp format: $lines[0]");
    }
    if (newForecastTemp != state.forecastExtTemp) {
      state = state.copyWith(forecastExtTemp: newForecastTemp);
    }
    String newWindStr = lines[1].trim();
    if (newWindStr != state.windStr) {
      state = state.copyWith(windStr: newWindStr);
    }
  }

  void decRequestedTemp() {
//      print("Minus pressed");
    if (state.requestedTemp > 10) {
      //Only use existing requestTemp if its in a sensible range
      state = state.copyWith(
          requestedTemp: state.requestedTemp - 0.5, requestOutstanding: true);
    } else {
      state = state.copyWith(
          requestedTemp: state.setTemp - 0.5, requestOutstanding: true);
    }
    sendNewTemp(temp: state.requestedTemp, send: true);
  }

  void incrementRequestedTemp() {
    // print("Plus pressed");
    if (state.requestedTemp > 10) {
      //Only use existing requestTemp if its in a sensible range
      state = state.copyWith(
          requestedTemp: state.requestedTemp + 0.5, requestOutstanding: true);
    } else {
      state = state.copyWith(
          requestedTemp: state.setTemp + 0.5, requestOutstanding: true);
    }
    sendNewTemp(temp: state.requestedTemp, send: true);
  }

  void sendNewTemp(
      {required double temp, required bool send, bool dropboxOnly = false}) {
    if (send) {
      String contents = state.requestedTemp.toStringAsFixed(1);
      bool sendByDropbox = true;
      if (!dropboxOnly) {
        if (state.localUI) {
          try {
            File(localSetTempFile).writeAsStringSync(contents);
            sendByDropbox = false;
          } catch (e) {
            print("On thermostat host and cannot write locally");
          }
        } else if (state.onLocalLan) {
          sendByDropbox = false;
          Future<bool> localSend = LocalSendReceive.sendLocalFile(
              fileName: localSetTempFile, contents: contents);
          localSend.then((success) {
            if (!success) {
              print(
                  "On local Lan but failed to send settemp, so send again using Dropbox");
              sendNewTemp(temp: temp, send: send, dropboxOnly: true);
            }
          });
        }
      }
      if (sendByDropbox) {
        DropBoxAPIFn.sendDropBoxFile(
            // oauthToken: state.oauthToken,
            fileToUpload: setTempFile,
            contents: contents);
      }
    }
  }

  void sendBoost() {
    String contents = "1: Boost ${state.boilerOn ? 'OFF' : 'ON'}";
    // print("Sending boost: $contents");
    bool sendByDropbox = true;
    if (state.localUI) {
      try {
        File(thermostatLocalCommandFile).writeAsStringSync(contents);
        sendByDropbox = false;
      } catch (e) {
        print("On thermostat host and cannot write locally");
      }
    } else if (state.onLocalLan) {
      Future<bool> localSend = LocalSendReceive.sendLocalFile(
          fileName: thermostatLocalCommandFile, contents: contents);
      localSend.then((success) {
        if (!success) {
          print(
              "On local Lan but failed to send boost, so send again using Dropbox");
        } else {
          sendByDropbox = false;
        }
      });
    }
    if (sendByDropbox) {
      DropBoxAPIFn.sendDropBoxFile(
          // oauthToken: state.oauthToken,
          fileToUpload: controlStnCommandFile,
          contents: contents);
    }
  }
}

class BarometerStatus {
  BarometerStatus({required this.localUI, required this.onLocalLan});
  BarometerStatus.fromStatus(BarometerStatus oldState) {
    localUI = oldState.localUI;
    onLocalLan = oldState.onLocalLan;
    localGetInProgress = oldState.localGetInProgress;
    oauthToken = oldState.oauthToken;

    pressureByDateTime = oldState.pressureByDateTime;
    lastPressureTime = oldState.lastPressureTime;
    currentPressure = oldState.currentPressure;
  }

  BarometerStatus.fromParams(
    this.localUI,
    this.onLocalLan,
    this.localGetInProgress,
    this.oauthToken,
    this.pressureByDateTime,
    this.lastPressureTime,
    this.currentPressure,
  );

  BarometerStatus copyWith({
    Map<DateTime, double>? pressureByDateTime,
  }) {
    Map<DateTime, double> newPressureByDateTime =
        Map.from(this.pressureByDateTime);
    double newCurrentPressure = currentPressure;
    DateTime newlastPressureTime = lastPressureTime;
    if (pressureByDateTime != null && pressureByDateTime.isNotEmpty) {
      newPressureByDateTime.addAll(pressureByDateTime);
      List<DateTime> pressureDates = newPressureByDateTime.keys.toList();
      pressureDates.sort();
      DateTime lastTime = pressureDates.last;
      if (lastTime.isAfter(lastPressureTime)) {
        newCurrentPressure = newPressureByDateTime[lastTime] ?? 0.0;
        newlastPressureTime = DateTime.fromMillisecondsSinceEpoch(
            lastTime.millisecondsSinceEpoch);
      }
    }
    return BarometerStatus.fromParams(
        localUI,
        onLocalLan,
        localGetInProgress,
        oauthToken,
        newPressureByDateTime,
        newlastPressureTime,
        newCurrentPressure);
  }

  late bool localUI;
  late bool onLocalLan;
  bool localGetInProgress = false;
  String oauthToken = "";

  Map<DateTime, double> pressureByDateTime = {};
  DateTime lastPressureTime = DateTime(2000);
  double currentPressure = 0.0;
}

@riverpod
class BarometerStatusNotifier extends _$BarometerStatusNotifier {
  final String pressureFile = "_airquality.csv";
  final String localDisplayOnFile = "/home/danny/thermostat/displayOn.txt";
  final String localStatusFile = "/home/danny/control_station/airquality.txt";

  @override
  BarometerStatus build() {
    //Determine if running local to thermostat by the presence of the thermostat dir
    bool local = false;
    final FileStat thermStat = FileStat.statSync("/home/danny/thermostat");
    if (thermStat.type != FileSystemEntityType.notFound) {
      local = true;
    }
    BarometerStatus status =
        BarometerStatus(localUI: local, onLocalLan: local ? true : false);
    //Check if we are on local LAN
    areWeOnLocalNetwork((onlan) => status.onLocalLan = onlan);
    return status;
  }

  void refreshStatus() {
    // getSetTemp();
    bool updateState = true;
    if (state.localUI) {
      //Check that thermostat has turned backlight on
      //if not then do nothing as display not visible
      updateState = FileStat.statSync(localDisplayOnFile).type !=
          FileSystemEntityType.notFound;
    }
    if (updateState) {
      // newState = CameraStatus.fromStatus(state);
      getStatus();
    }
  }

  void getStatus({bool dropboxOnly = false}) {
    DateTime now = DateTime.now();
    bool localRead = false;
    String todayFile =
        sprintf("%s%02i%02i%s", [now.year, now.month, now.day, pressureFile]);
    if (!dropboxOnly && state.localUI) {
      //Get todays file from local storage
      FileStat stat = FileStat.statSync(localStatusFile);
      if (stat.type != FileSystemEntityType.notFound) {
        String statusStr = File(localStatusFile).readAsStringSync();
        localRead = true;
        processPressureFile(localStatusFile, statusStr);
      }
    }
    if (!localRead) {
      DropBoxAPIFn.getDropBoxFile(
        // oauthToken: state.oauthToken,
        fileToDownload: '/$todayFile',
        callback: processPressureFile,
        contentType: ContentType.text,
        timeoutSecs: 300, //Cache entry timeout
      );
    }
    for (int i = 1; i < 3; i++) {
      DateTime prevDay = now.subtract(Duration(days: i));
      String histFile = sprintf("/%s%02i%02i%s",
          [prevDay.year, prevDay.month, prevDay.day, pressureFile]);
      //retrieve from dropbox
      DropBoxAPIFn.getDropBoxFile(
        // oauthToken: state.oauthToken,
        fileToDownload: histFile,
        callback: processPressureFile,
        contentType: ContentType.text,
        timeoutSecs: 300, //Cache entry timeout
      );
    }
  }

  void processPressureFile(String filename, String contents) {
    if (!contents.contains("error")) {
      Map<DateTime, double> pressureMap = {};
      final result = csv.CsvConverter().convert(contents);
      for (int i = 1; i < result.length; i++) {
        final row = result[i];
        try {
          var t = DateTime.parse(row[0].trim());
          double pressure = double.parse(row[2].trim());
          pressureMap[t] = pressure / 100.0;
        } on Exception {
          //ignore row
        }
      }
      state = state.copyWith(pressureByDateTime: pressureMap);
    }
  }
}

class CameraStatus {
  CameraStatus({required this.localUI, required this.onLocalLan});
  CameraStatus.fromStatus(CameraStatus oldState) {
    localUI = oldState.localUI;
    onLocalLan = oldState.onLocalLan;
    localGetInProgress = oldState.localGetInProgress;
    oauthToken = oldState.oauthToken;

    extTemp = oldState.extTemp;
    lastExtReadTime = oldState.lastExtReadTime;
    extHumidity = oldState.extHumidity;
    extLastHeardFrom = oldState.extLastHeardFrom;
    extPirState = oldState.extPirState;
    extPirLastEvent = oldState.extPirLastEvent;
    lightStatus = oldState.lightStatus;
    camStatus = oldState.camStatus;
  }

  CameraStatus.fromParams(
      this.localUI,
      this.onLocalLan,
      this.localGetInProgress,
      this.oauthToken,
      this.extTemp,
      this.lastExtReadTime,
      this.extHumidity,
      this.extLastHeardFrom,
      this.extPirState,
      this.extPirLastEvent,
      this.lightStatus,
      this.camStatus);

  CameraStatus copyWith({
    bool? localUI,
    bool? onLocalLan,
    bool? localGetInProgress,
    String? oauthToken,
    Map<int, double>? extTemp,
    Map<String, DateTime>? lastExtReadTime,
    Map<int, double>? extHumidity,
    Map<int, DateTime?>? extLastHeardFrom,
    Map<int, bool>? extPirState,
    Map<int, String>? extPirLastEvent,
    Map<int, double>? lightStatus,
    Map<int, int>? camStatus,
  }) {
    return CameraStatus.fromParams(
      localUI ?? this.localUI,
      onLocalLan ?? this.onLocalLan,
      localGetInProgress ?? this.localGetInProgress,
      oauthToken ?? this.oauthToken,
      extTemp ?? this.extTemp,
      lastExtReadTime ?? this.lastExtReadTime,
      extHumidity ?? this.extHumidity,
      extLastHeardFrom ?? this.extLastHeardFrom,
      extPirState ?? this.extPirState,
      extPirLastEvent ?? this.extPirLastEvent,
      lightStatus ?? this.lightStatus,
      camStatus ?? this.camStatus,
    );
  }

  late bool localUI;
  late bool onLocalLan;
  bool localGetInProgress = false;
  String oauthToken = "";

  Map<int, double> extTemp = {2: -100.0, 4: -100.0};
  Map<String, DateTime> lastExtReadTime = {};
  Map<int, double> extHumidity = {2: 0.0, 4: 0.0};
  Map<int, DateTime?> extLastHeardFrom = {5: null, 4: null, 3: null, 2: null};
  Map<int, bool> extPirState = {4: false, 3: false, 2: false};
  Map<int, String> extPirLastEvent = {5: "", 4: "", 3: "", 2: ""};
  Map<int, double> lightStatus = {6: 0};
  Map<int, int> camStatus = {2: 0, 3: 0, 4: 0, 5: 0, 6: 0};
}

@riverpod
class CameraStatusNotifier extends _$CameraStatusNotifier {
  final List<String> externalstatusFile = [
    "/2_status.txt",
    "/3_status.txt",
    "/4_status.txt",
    "/5_status.txt",
    "/6_status.txt",
  ];
  final List<String> localExternalstatusFile = [
    "/home/danny/control_station/2_status.txt",
    "/home/danny/control_station/3_status.txt",
    "/home/danny/control_station/4_status.txt",
    "/home/danny/control_station/5_status.txt",
    "/home/danny/control_station/6_status.txt",
  ];
  final int STATION_WITH_EXT_TEMP = 2;
  final String localDisplayOnFile = "/home/danny/thermostat/displayOn.txt";

  // late CameraStatus newState;

  @override
  CameraStatus build() {
    //Determine if running local to thermostat by the presence of the thermostat dir
    bool local = false;
    FileStat thermStat = FileStat.statSync("/home/danny/thermostat");
    if (thermStat.type != FileSystemEntityType.notFound) {
      local = true;
    }
    CameraStatus status =
        CameraStatus(localUI: local, onLocalLan: local ? true : false);
    //Check if we are on local LAN
    areWeOnLocalNetwork((onlan) => status.onLocalLan = onlan);
    return status;
  }

  void refreshStatus() {
    // getSetTemp();
    bool updateState = true;
    if (state.localUI) {
      //Check that thermostat has turned backlight on
      //if not then do nothing as display not visible
      updateState = FileStat.statSync(localDisplayOnFile).type !=
          FileSystemEntityType.notFound;
    }
    if (updateState) {
      // newState = CameraStatus.fromStatus(state);
      getExternalStatus(extFiles: externalstatusFile);
    }
  }

  void getExternalStatus({required extFiles, bool dropboxOnly = false}) {
    //Copy external files required into local list so it can be safely changed
    List<String> filesFromDropbox = [];
    if (!dropboxOnly) {
      if (state.localUI) {
        for (final extfile in localExternalstatusFile) {
          FileStat stat = FileStat.statSync(extfile);
          DateTime? lastTime = state.lastExtReadTime[extfile];
          lastTime ??= DateTime(2000);
          if (stat.changed.isAfter(lastTime)) {
            String statusStr = File(extfile).readAsStringSync();
            processExternalStatus(extfile, statusStr);
            Map<String, DateTime> newMap =
                Map<String, DateTime>.from(state.lastExtReadTime);
            newMap[extfile] = stat.changed;
            state = state.copyWith(lastExtReadTime: newMap);
          }
        }
      } else if (state.onLocalLan && !state.localGetInProgress) {
        //Use ftp to retrieve status files direct from control station
        Future<Map<String, String>> localReceive =
            LocalSendReceive.getLocalFile(localExternalstatusFile);
        state.localGetInProgress = true;
        localReceive.then((files) {
          filesFromDropbox.addAll(extFiles);
          state.localGetInProgress = false;
          for (final extfile in localExternalstatusFile) {
            if (files.containsKey(extfile)) {
              String? statusStr = files[extfile];
              if (statusStr != null) {
                List<String> parts = extfile.split('/');
                String filename = parts[parts.length - 1];
                //Succeeded getting file locally, remove from dropbox list
                String fileToRemove = '';
                for (final ext in filesFromDropbox) {
                  if (ext.contains(filename)) fileToRemove = ext;
                  break;
                }
                filesFromDropbox.remove(fileToRemove);
                processExternalStatus(extfile, statusStr);
              }
            }
          }
          if (filesFromDropbox.isNotEmpty) {
            //Failed to get some status files locally, use dropbox
            getExternalStatus(extFiles: filesFromDropbox, dropboxOnly: true);
          }
        });
      } else {
        //retrieve from dropbox
        filesFromDropbox.addAll(extFiles);
      }
    }

    for (final extfile in filesFromDropbox) {
      DropBoxAPIFn.getDropBoxFile(
        // oauthToken: state.oauthToken,
        fileToDownload: extfile,
        callback: processExternalStatus,
        contentType: ContentType.text,
        timeoutSecs: 15,
      );
    }
  }

  void processExternalStatus(String filename, String contents) {
    int stationNo = STATION_WITH_EXT_TEMP;
    if (filename != "") {
      //Retrieve station number from file name
      List<String> parts = filename.split('/');
      stationNo = int.parse(parts[parts.length - 1].split('_')[0]);
    }
    contents.split('\n').forEach((line) {
      double? newExtTemp = state.extTemp[stationNo];
      if (line.startsWith('Current temp:')) {
        String tempStr = line.split(':')[1].trim();
        if (!tempStr.startsWith("Not Set")) {
          try {
            newExtTemp = double.parse(tempStr);
          } on FormatException {
            print("Received non-double External temp format: $line");
          }
        }
        if (newExtTemp != null && newExtTemp != state.extTemp[stationNo]) {
          Map<int, double> newMap = Map<int, double>.from(state.extTemp);
          newMap[stationNo] = newExtTemp;
          state = state.copyWith(extTemp: newMap);
        }
      } else if (line.startsWith('Last heard time')) {
        String dateStr = line.substring(line.indexOf(':') + 2, line.length);
        DateTime newExtLastHeard = DateTime.parse(dateStr);
        if (newExtLastHeard != state.extLastHeardFrom[stationNo]) {
          Map<int, DateTime?> newMap = {...state.extLastHeardFrom};
          // Map<int, DateTime>.from(state.extLastHeardFrom);
          newMap[stationNo] = newExtLastHeard;
          state = state.copyWith(extLastHeardFrom: newMap);
        }
      } else if (line.startsWith('Current humidity')) {
        String str = line.substring(line.indexOf(':') + 2, line.length);
        double newExtHumid = double.parse(str);
        if (newExtHumid != state.extHumidity[stationNo]) {
          Map<int, double> newMap = Map<int, double>.from(state.extHumidity);
          newMap[stationNo] = newExtHumid;
          state = state.copyWith(extHumidity: newMap);
        }
      } else if (line.startsWith('Mins to set temp')) {
        double? light = state.lightStatus[stationNo];
        try {
          light = double.parse(line.split(':')[1].trim());
        } on FormatException {
          print("Received non-double minsToSetTemp format: $line");
        }
        if (light != null && light != state.lightStatus[stationNo]) {
          Map<int, double> newMap = Map<int, double>.from(state.lightStatus);
          newMap[stationNo] = light;
          state = state.copyWith(lightStatus: newMap);
        }
      } else if (line.startsWith('Last PIR')) {
        String lastEvent = line.substring(line.indexOf(':') + 1, line.length);
        Map<int, String> newMap = Map<int, String>.from(state.extPirLastEvent);
        newMap[stationNo] = lastEvent;
        state = state.copyWith(extPirLastEvent: newMap);
      } else if (line.startsWith('PIR:')) {
        String str = line.substring(line.indexOf(':') + 1, line.length);
        Map<int, bool> newMap = Map<int, bool>.from(state.extPirState);
        newMap[stationNo] = str.contains('1');
        state = state.copyWith(extPirState: newMap);
      } else if (line.startsWith('CAMERA:')) {
        String camStr = line.split(':')[1].trim();
        int cam = camStr == "ON" ? 1 : 0;
        if (cam != state.camStatus[stationNo]) {
          Map<int, int> newMap = Map<int, int>.from(state.camStatus);
          newMap[stationNo] = cam;
          state = state.copyWith(camStatus: newMap);
        }
      }
    });
  }
}

class RelayStatus {
  RelayStatus({required this.onLocalLan});
  static const Map<String, int> hostToFanSpeed = {
    "pi4desktop": 3,
    "pi4node0": 2,
    "pi4node1": 1,
    "pi4node2": 0,
  };

  RelayStatus.fromParams(
    this.onLocalLan,
    this.localGetInProgress,
    this.oauthToken,
    this.lastUpdateTime,
    this.lastTempUpdateTime,
    this.nodeHosts,
    this.nodeTemperatures,
    this.fanSpeeds,
    this.actualRelayStates,
    this.requestedRelayStates,
  );

  RelayStatus copyWith({
    List<bool>? actualRelayStates,
    List<bool>? requestedRelayStates,
    DateTime? updateTime,
    DateTime? tempUpdateTime,
    List<String>? hosts,
    List<double>? temps,
    List<int>? speeds,
  }) {
    List<bool> newRelayStates = List<bool>.from(this.actualRelayStates);
    if (actualRelayStates != null && actualRelayStates.isNotEmpty) {
      for (int i = 0; i < actualRelayStates.length; i++) {
        if (actualRelayStates[i] != newRelayStates[i]) {
          newRelayStates[i] = actualRelayStates[i];
        }
      }
    }
    List<bool> newReqRelayStates = List<bool>.from(this.requestedRelayStates);
    if (requestedRelayStates != null && requestedRelayStates.isNotEmpty) {
      for (int i = 0; i < requestedRelayStates.length; i++) {
        if (requestedRelayStates[i] != newReqRelayStates[i]) {
          newReqRelayStates[i] = requestedRelayStates[i];
        }
      }
    }
    if (updateTime != null) {
      lastUpdateTime = updateTime;
    }
    List<String> newNodes = List<String>.from(this.nodeHosts);
    if (hosts != null && hosts.isNotEmpty) {
      newNodes = hosts;
    }
    List<double> newTemps = List<double>.from(this.nodeTemperatures);
    if (temps != null && temps.isNotEmpty) {
      newTemps = temps;
    }
    List<int> newSpeeds = List<int>.from(this.fanSpeeds);
    if (speeds != null && speeds.isNotEmpty) {
      newSpeeds = speeds;
    }

    if (tempUpdateTime != null) {
      lastTempUpdateTime = tempUpdateTime;
    }
    return RelayStatus.fromParams(
        onLocalLan,
        localGetInProgress,
        oauthToken,
        lastUpdateTime,
        lastTempUpdateTime,
        newNodes,
        newTemps,
        newSpeeds,
        newRelayStates,
        newReqRelayStates);
  }

  RelayStatus setRelayState({required int relayIndex, required bool state}) {
    List<bool> newReqRelayStates = List<bool>.from(requestedRelayStates);
    newReqRelayStates[relayIndex] = state;
    return copyWith(requestedRelayStates: newReqRelayStates);
  }

  late bool onLocalLan;
  bool localGetInProgress = false;
  String oauthToken = "";
  DateTime? lastUpdateTime;
  DateTime? lastTempUpdateTime;
  List<String> nodeHosts = [];
  List<double> nodeTemperatures = [];
  List<int> fanSpeeds = [];

  List<bool> actualRelayStates = [false, false, false, false, false, false];
  List<bool> requestedRelayStates = [false, false, false, false, false, false];
}

@riverpod
class RelayStatusNotifier extends _$RelayStatusNotifier {
  final String relayFile = "relay_status.txt";
  final String relayCommandFile = "relay_command.txt";
  final String localRelayStatusFile =
      "/home/danny/control_station/relay_status.txt";

  @override
  RelayStatus build() {
    RelayStatus status = RelayStatus(onLocalLan: false);
    //Check if we are on local LAN
    areWeOnLocalNetwork((onlan) => status.onLocalLan = onlan);
    return status;
  }

  void refreshStatus() {
    getStatus();
  }

  void setRelayState(int index, bool reqState) {
    state = state.setRelayState(relayIndex: index, state: reqState);
    //Send command to control station
    sendRelayCommandToHost(index: index, reqState: reqState);
  }

  void sendRelayCommandToHost(
      {required int index, required bool reqState, bool dropboxOnly = false}) {
    String contents = "${index + 1}=${reqState ? '1' : '0'}\n";
    bool onLocalLan = state.onLocalLan;
    if (!dropboxOnly && onLocalLan) {
      //Send command to control station
      Future<bool> localSend = LocalSendReceive.sendLocalFile(
          fileName: "/home/danny/control_station/$relayCommandFile",
          contents: contents,
          append: true);
      localSend.then((success) {
        if (!success) {
          print("On local Lan but failed to send, so send again using Dropbox");
          sendRelayCommandToHost(
              index: index, reqState: reqState, dropboxOnly: true);
        }
      });
    } else {
      //Remote from control station - use Dropbox to send command
      DropBoxAPIFn.sendDropBoxFile(
          // oauthToken: state.oauthToken,
          fileToUpload: "/$relayCommandFile",
          contents: contents,
          append: true);
    }
  }

  void getStatus({bool dropboxOnly = false}) {
    bool localRead = false;
    if (!dropboxOnly && state.onLocalLan && !state.localGetInProgress) {
      //Use ftp to retrieve status file direct from control station
      Future<Map<String, String>> localReceive =
          LocalSendReceive.getLocalFile([localRelayStatusFile]);
      state.localGetInProgress = true;
      localReceive.then((files) {
        bool success = false;
        state.localGetInProgress = false;
        if (files.containsKey(localRelayStatusFile)) {
          String? statusStr = files[localRelayStatusFile];
          if (statusStr != null) {
            processRelayStateFile(localRelayStatusFile, statusStr);
            success = true;
          }
        }
        if (!success) {
          //Failed to get some status files locally, use dropbox
          DropBoxAPIFn.getDropBoxFile(
            // oauthToken: state.oauthToken,
            fileToDownload: "/$relayFile",
            callback: processRelayStateFile,
            contentType: ContentType.text,
            timeoutSecs: 5,
          );
        }
      });
    } else {
      if (!dropboxOnly) {
        //Get status file from local storage
        FileStat stat = FileStat.statSync(relayFile);
        if (stat.type != FileSystemEntityType.notFound) {
          String statusStr = File(relayFile).readAsStringSync();
          localRead = true;
          processRelayStateFile(relayFile, statusStr);
        }
      }
      if (!localRead) {
        DropBoxAPIFn.getDropBoxFile(
          // oauthToken: state.oauthToken,
          fileToDownload: '/$relayFile',
          callback: processRelayStateFile,
          contentType: ContentType.text,
          timeoutSecs: 1, //Cache entry timeout
        );
      }
    }
    //Now get cluster node temp file sent by the fan controller
    DropBoxAPIFn.getDropBoxFile(
      // oauthToken: state.oauthToken,
      fileToDownload: nodeTemperatureFile,
      callback: processNodeTempFile,
      contentType: ContentType.text,
      timeoutSecs: 1, //Cache entry timeout
    );
  }

  void processRelayStateFile(String filename, String contents) {
    if (contents.isEmpty || contents.contains("error")) {
      return;
    }
    try {
      List<String> parts = contents.split('@');
      if (parts.length < 2) {
        print("Received invalid relay state format: $contents");
        return;
      }
      String dateStr = parts[0].trim();
      DateTime newLastHeard = DateTime.parse(dateStr);
      int relayState = int.parse(parts[1].trim());
      List<bool> newRelayStates = [false, false, false, false, false, false];
      if (relayState & 1 == 1) {
        newRelayStates[0] = true;
      }
      if (relayState & 2 == 2) {
        newRelayStates[1] = true;
      }
      if (relayState & 4 == 4) {
        newRelayStates[2] = true;
      }
      if (relayState & 8 == 8) {
        newRelayStates[3] = true;
      }
      if (relayState & 0x10 == 0x10) {
        newRelayStates[4] = true;
      }
      if (relayState & 0x20 == 0x20) {
        newRelayStates[5] = true;
      }
      state = state.copyWith(
          updateTime: newLastHeard, actualRelayStates: newRelayStates);
    } on FormatException {
      print("Received non-int relay state format or timestamp: $contents");
    }
  }

  void processNodeTempFile(String filename, String contents) {
    //Format is <data time>={<hostname>:<temp>}]}
    if (contents.isEmpty || contents.contains("error")) {
      return;
    }
    try {
      // print("Received node temp file: $contents");
      List<String> parts = contents.split('@');
      String dateStr = parts[0].trim();
      dateStr = dateStr.replaceAll('/', '-');
      DateTime newLastHeard = DateTime.parse(dateStr);
      String nodeStr = parts[1].trim();
      nodeStr = nodeStr.replaceAll("'", '"');
      Map<String, dynamic> tempData = jsonDecode(nodeStr);
      List<dynamic> fanData = [];
      if (parts.length == 3) {
        //Parse fan speeds
        fanData = jsonDecode(parts[2]);
      }
      List<String> newNodes = [];
      List<double> newTemps = [];
      List<int> fanSpeeds = [];
      for (String key in tempData.keys) {
        var t = tempData[key];
        double temp = double.parse(t.toString());
        newNodes.add(key);
        newTemps.add(temp);
        if (fanData.isNotEmpty) {
          if (RelayStatus.hostToFanSpeed[key] != null) {
            int fanIndex = RelayStatus.hostToFanSpeed[key]!;
            int fanSpeed = fanData[fanIndex];
            fanSpeeds.add(fanSpeed);
          }
        }
      }
      state = state.copyWith(
        tempUpdateTime: newLastHeard,
        hosts: newNodes,
        temps: newTemps,
        speeds: fanSpeeds,
      );
    } on FormatException catch (e) {
      print(
          "Received invalid node and temp or timestamp: $contents: Error: $e");
    }
  }
}
