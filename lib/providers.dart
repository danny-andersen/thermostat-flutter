import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'dropbox-api.dart';

part 'providers.g.dart';

void toggleLights(stationId, lightStatus) {
  String contents = "$stationId: Lights ${lightStatus > 0 ? 'OFF' : 'ON'}";
  DropBoxAPIFn.sendDropBoxFile(
      // oauthToken: state.oauthToken,
      fileToUpload: "/command.txt",
      contents: contents);
}

class ThermostatStatus {
  ThermostatStatus({required this.localUI});
  ThermostatStatus.fromStatus(ThermostatStatus oldState) {
    localUI = oldState.localUI;
    oauthToken = oldState.oauthToken;
    currentTemp = oldState.currentTemp;
    lastStatusReadTime = oldState.lastStatusReadTime;
    forecastExtTemp = oldState.forecastExtTemp;
    windStr = oldState.windStr;
    lastForecastReadTime = oldState.lastForecastReadTime;
    motdStr = oldState.motdStr;
    lastMotdReadTime = oldState.lastMotdReadTime;
    setTemp = oldState.setTemp;
    requestedTemp = oldState.requestedTemp;
    humidity = oldState.humidity;
    lastHeardFrom = oldState.lastHeardFrom;
    intPirState = oldState.intPirState;
    intPirLastEvent = oldState.intPirLastEvent;

    boilerOn = oldState.boilerOn;
    minsToSetTemp = oldState.minsToSetTemp;

    requestOutstanding = oldState.requestOutstanding;
  }

  ThermostatStatus.fromParams(
      this.localUI,
      this.oauthToken,
      this.currentTemp,
      this.lastStatusReadTime,
      this.forecastExtTemp,
      this.windStr,
      this.lastForecastReadTime,
      this.motdStr,
      this.lastMotdReadTime,
      this.setTemp,
      this.requestedTemp,
      this.humidity,
      this.lastHeardFrom,
      this.intPirState,
      this.intPirLastEvent,
      this.boilerOn,
      this.minsToSetTemp,
      this.requestOutstanding);

  ThermostatStatus copyWith(
      {bool? localUI,
      String? oauthToken,
      double? currentTemp,
      DateTime? lastStatusReadTime,
      double? forecastExtTemp,
      String? windStr,
      DateTime? lastForecastReadTime,
      String? motdStr,
      DateTime? lastMotdReadTime,
      double? setTemp,
      double? requestedTemp,
      double? humidity,
      DateTime? lastHeardFrom,
      bool? intPirState,
      String? intPirLastEvent,
      bool? boilerOn,
      int? minsToSetTemp,
      bool? requestOutstanding}) {
    return ThermostatStatus.fromParams(
        localUI ?? this.localUI,
        oauthToken ?? this.oauthToken,
        currentTemp ?? this.currentTemp,
        lastStatusReadTime ?? this.lastStatusReadTime,
        forecastExtTemp ?? this.forecastExtTemp,
        windStr ?? this.windStr,
        lastForecastReadTime ?? this.lastForecastReadTime,
        motdStr ?? this.motdStr,
        lastMotdReadTime ?? this.lastMotdReadTime,
        setTemp ?? this.setTemp,
        requestedTemp ?? this.requestedTemp,
        humidity ?? this.humidity,
        lastHeardFrom ?? this.lastHeardFrom,
        intPirState ?? this.intPirState,
        intPirLastEvent ?? this.intPirLastEvent,
        boilerOn ?? this.boilerOn,
        minsToSetTemp ?? this.minsToSetTemp,
        requestOutstanding ?? this.requestOutstanding);
  }

  late bool localUI;
  String oauthToken = "";
  double currentTemp = -100.0;
  DateTime lastStatusReadTime = DateTime(2000);
  double forecastExtTemp = -100.0;
  String windStr = "";
  DateTime lastForecastReadTime = DateTime(2000);
  String motdStr = "";
  DateTime lastMotdReadTime = DateTime(2000);
  double setTemp = 0.0;
  double requestedTemp = 0.0;
  double humidity = 0.0;
  DateTime? lastHeardFrom;
  bool intPirState = false;
  String intPirLastEvent = "";

  bool boilerOn = false;
  int minsToSetTemp = 0;

  bool requestOutstanding = false;
}

@riverpod
class ThermostatStatusNotifier extends _$ThermostatStatusNotifier {
  final String statusFile = "/thermostat_status.txt";
  final String localStatusFile = "/home/danny/thermostat/status.txt";

  final String setTempFile = "/setTemp.txt";
  final String localSetTempFile = "/home/danny/thermostat/setTemp.txt";
  final String localForecastExt = "/home/danny/thermostat/setExtTemp.txt";
  final String localMotd = "/home/danny/thermostat/motd.txt";
  final String localDisplayOnFile = "/home/danny/thermostat/displayOn.txt";
  final String boostFile = "/boost.txt";
  final String localBoostFile = "/home/danny/thermostat/boost.txt";

  // late ThermostatStatus newState;

  @override
  ThermostatStatus build() {
    //Determine if running local to thermostat by the presence of the thermostat dir
    bool local = false;
    FileStat thermStat = FileStat.statSync("/home/danny/thermostat");
    if (thermStat.type != FileSystemEntityType.notFound) {
      local = true;
    }
    ThermostatStatus status = ThermostatStatus(localUI: local);
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
      FileStat statusStat = FileStat.statSync(localStatusFile);
      FileStat motdStat = FileStat.statSync(localMotd);
      FileStat fcStat = FileStat.statSync(localForecastExt);
      //Only update state (and so the display) if something has changed
      if (statusStat.changed.isAfter(state.lastStatusReadTime) ||
          motdStat.changed.isAfter(state.lastMotdReadTime) ||
          fcStat.changed.isAfter(state.lastForecastReadTime)) {
        if (statusStat.type != FileSystemEntityType.notFound &&
            statusStat.changed.isAfter(state.lastStatusReadTime)) {
          String statusStr = File(localStatusFile).readAsStringSync();
          processStatus(localStatusFile, statusStr);
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
          requestedTemp: state.setTemp + 0.5, requestOutstanding: true);
    }
    sendNewTemp(state.requestedTemp, true);
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
    sendNewTemp(state.requestedTemp, true);
  }

  void sendNewTemp(double temp, bool send) {
    if (send) {
      String contents = state.requestedTemp.toStringAsFixed(1);
      if (state.localUI) {
        File(localSetTempFile).writeAsStringSync(contents);
      } else {
        DropBoxAPIFn.sendDropBoxFile(
            // oauthToken: state.oauthToken,
            fileToUpload: setTempFile,
            contents: contents);
      }
    }
  }

  void sendBoost() {
    String contents = state.boilerOn ? "OFF" : "ON";
    print("Sending boost: $contents");
    if (state.localUI) {
      File(localBoostFile).writeAsStringSync(contents);
    } else {
      DropBoxAPIFn.sendDropBoxFile(
          // oauthToken: state.oauthToken,
          fileToUpload: boostFile,
          contents: contents);
    }
  }
}

class CameraStatus {
  CameraStatus({required this.localUI});
  CameraStatus.fromStatus(CameraStatus oldState) {
    localUI = oldState.localUI;
    oauthToken = oldState.oauthToken;

    extTemp = oldState.extTemp;
    lastExtReadTime = oldState.lastExtReadTime;
    extHumidity = oldState.extHumidity;
    extLastHeardFrom = oldState.extLastHeardFrom;
    extPirState = oldState.extPirState;
    extPirLastEvent = oldState.extPirLastEvent;
    lightStatus = oldState.lightStatus;
  }

  CameraStatus.fromParams(
      this.localUI,
      this.oauthToken,
      this.extTemp,
      this.lastExtReadTime,
      this.extHumidity,
      this.extLastHeardFrom,
      this.extPirState,
      this.extPirLastEvent,
      this.lightStatus);

  CameraStatus copyWith({
    bool? localUI,
    String? oauthToken,
    Map<int, double>? extTemp,
    Map<String, DateTime>? lastExtReadTime,
    Map<int, double>? extHumidity,
    Map<int, DateTime?>? extLastHeardFrom,
    Map<int, bool>? extPirState,
    Map<int, String>? extPirLastEvent,
    Map<int, double>? lightStatus,
  }) {
    return CameraStatus.fromParams(
      localUI ?? this.localUI,
      oauthToken ?? this.oauthToken,
      extTemp ?? this.extTemp,
      lastExtReadTime ?? this.lastExtReadTime,
      extHumidity ?? this.extHumidity,
      extLastHeardFrom ?? this.extLastHeardFrom,
      extPirState ?? this.extPirState,
      extPirLastEvent ?? this.extPirLastEvent,
      lightStatus ?? this.lightStatus,
    );
  }

  late bool localUI;
  String oauthToken = "";

  Map<int, double> extTemp = {2: -100.0, 4: -100.0};
  Map<String, DateTime> lastExtReadTime = {};
  Map<int, double> extHumidity = {2: 0.0, 4: 0.0};
  Map<int, DateTime?> extLastHeardFrom = {5: null, 4: null, 3: null, 2: null};
  Map<int, bool> extPirState = {4: false, 3: false, 2: false};
  Map<int, String> extPirLastEvent = {5: "", 4: "", 3: "", 2: ""};
  Map<int, double> lightStatus = {6: 0};
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
    CameraStatus status = CameraStatus(localUI: local);
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
      getExternalStatus();
    }
  }

  void getExternalStatus() {
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
    } else {
      for (final extfile in externalstatusFile) {
        DropBoxAPIFn.getDropBoxFile(
          // oauthToken: state.oauthToken,
          fileToDownload: extfile,
          callback: processExternalStatus,
          contentType: ContentType.text,
          timeoutSecs: 5,
        );
      }
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
      }
    });
  }
}
