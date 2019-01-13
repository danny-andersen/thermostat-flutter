import 'dropbox-api.dart';
import 'package:sprintf/sprintf.dart';


//Used to represent the schedule as a series of Time + Temp points in a graph
class TempByHour {
  final int hour; //Hours and mins time of day
  final double temperature; //temperature at this time
  TempByHour(this.hour, this.temperature);
  factory TempByHour.from(DateTime time, temp) {
    String tStr = sprintf("%2i%02i", [time.hour, time.minute]);
    int hour = int.parse(tStr);
    print ('${time.toString()} : $tStr : $hour');
    return TempByHour(hour, temp);
  }
}

//A schedule entry. This represents the temperature to set the thermostat
//for a particular time range on a particular set of days
//It may be overwritten by a more specific entry, e.g. one for a particular day rather than day range
class ScheduleDay {
  final String dayRange; //e.g. Mon-Fri
  final DateTime start; // Start time in the day of this schedule
  final DateTime end; //End time
  final double temperature; //Temperature to set during the schedule
  ScheduleDay(this.dayRange, this.start, this.end, this.temperature);

  //Determine if the given day (or dayRange) is in the range of this entry
  bool isDayInRange(String day) {
    bool isInRange = false;
    if (day == this.dayRange) isInRange = true;
    else if (dayRangeDays.keys.contains(this.dayRange) && daysofWeek.contains(day)) {
      //Its a single day and we are a dayrange
      isInRange = dayRangeDays[this.dayRange].contains(day);
    }
    return isInRange;
  }

  //The more days the schedule entry covers, the less its precedence
  //in other words a schedule entry that specifies the temperature at a time on a Monday only
  //has a higher precedence than one that specified a temperature for the same time but for a day range, say Mon-Fri
  int getPrecedence() {
    int precedence = 99;
    if (dayRangeDays.containsKey(this.dayRange)) {
      precedence = dayRangeDays[this.dayRange].length;
    } else if (daysofWeek.contains(this.dayRange)) {
      precedence = 1;
    } else {
      throw new FormatException("Day range in schedule not recognised: $this.dayRange");
    }
    return precedence;
  }

  static final Map<String, List<String>> dayRangeDays = {
    'Mon-Sun': ['Mon', 'Tues', 'Wed', 'Thurs', 'Fri', 'Sat', 'Sun'],
    'Mon-Fri': [
      'Mon',
      'Tues',
      'Wed',
      'Thurs',
      'Fri',
    ],
    'Sat-Sun': ['Sat', 'Sun'],
  };

  static final List<String> daysofWeek = [
    'Sun',
    'Mon',
    'Tues',
    'Wed',
    'Thurs',
    'Fri',
    'Sat'
  ];
}

//Schedule is a simple list of ScheduleDay entries
class Schedule {
  //The dropbox file holding this schedule
  final ScheduleEntry file;
  //Each schedule consists of a list of <dayrange>,<start>,<stop>,<temp> tuples
  final List<ScheduleDay> days;

  Schedule(this.file, this.days);

  factory Schedule.fromFile(ScheduleEntry file, String contents) {
    List<ScheduleDay> entries = List();
//    print (contents);
    contents.split('\n').forEach((line) {
      var fields = line.split(',');
      if (fields.length == 4) {
        String day = fields[0];
//        print("start: ${fields[1]} hour ${fields[1].substring(
//            0, 2)} min ${fields[1].substring(2, 4)}");        retEntries

        DateTime start = DateTime(2000, 1, 1,
            int.parse(fields[1].substring(0, 2)),
            int.parse(fields[1].substring(2, 4)));
        DateTime end = DateTime(2000, 1, 1,
            int.parse(fields[2].substring(0, 2)),
            int.parse(fields[2].substring(2, 4)));
        double temp = double.parse(fields[3]);
        entries.add(ScheduleDay(day, start, end, temp));
      }
    });
    return Schedule(file, entries);
  }

  //Returns the list of schedule entries that match this dayrange (or day)
  List<ScheduleDay> filterEntriesByDayRange(String dayRange) {
    List<ScheduleDay> dayEntries = List();
    for (ScheduleDay day in this.days) {
      if (day.isDayInRange(dayRange)) dayEntries.add(day);
    }
    return dayEntries;
  }

  //For each 15 mins, work out what the temperature is for the filtered list given
  static List<TempByHour> generateTempByHourForEntries(List<ScheduleDay> entries) {
    DateTime currentTime = DateTime(2000, 1,1,0,0);
    DateTime end = DateTime(2000, 1,1, 24, 1);
    //Sort entries by precedence so that most precedence (lower number) is last
    entries.sort((a, b) => b.getPrecedence().compareTo(a.getPrecedence()));
    List<TempByHour> retEntries = List();
    double currentTemp = getCurrentTemp(currentTime, entries);
    retEntries.add(TempByHour.from(currentTime, currentTemp));
    do {
      DateTime newTime = currentTime.add(Duration(minutes: 5));
      double newTemp = getCurrentTemp(newTime, entries);
      if (newTemp != currentTemp) {
        //Create an entry at old temp and new temp
        retEntries.add(TempByHour.from(currentTime, currentTemp));
        retEntries.add(TempByHour.from(newTime, newTemp));
      }
      currentTime = newTime;
      currentTemp = newTemp;
    } while (currentTime.isBefore(end));
    return retEntries;
  }

  //Return the current temperature for the given time
  //Sorted entries must be in reverse precedence order
  static double getCurrentTemp(DateTime now, List<ScheduleDay> sortedEntries) {
    double retTemp = 10.0;
    sortedEntries.forEach((entry) {
      if (now.compareTo(entry.start) >= 0 && now.compareTo(entry.end) <= 0) {
        retTemp = entry.temperature;
      }
    });
    return retTemp;
  }
}

//Details of the file holding schedule details
class ScheduleEntry {
  //Dropbox file entry details
  final FileEntry fileListing;
  final String name;
  ScheduleEntry(this.fileListing, this.name);
  factory ScheduleEntry.fromFileEntry(FileEntry fileEntry) {
    String fn = fileEntry.fileName;
    List<String> parts = fn.split('setSchedule.txt.');
    String n = parts[1];
    return ScheduleEntry(fileEntry, n);
  }
}
