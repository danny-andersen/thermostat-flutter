import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dropbox-api.dart';

class HolidayPage extends StatefulWidget {
  const HolidayPage({super.key, required this.oauthToken});

  final String oauthToken;
  @override
  State createState() => _HolidayPageState(oauthToken: oauthToken);
}

class _HolidayPageState extends State<HolidayPage> {
  _HolidayPageState({required this.oauthToken});

  final String oauthToken;
  final Uri downloadUri =
      Uri.parse("https://content.dropboxapi.com/2/files/download");
  final String currentHolidayFile = "/holiday.txt.current";
  final String holidayFile = "/holiday.txt";
  final double holidayTemp = 10.0;

  DateTime _fromDate = DateTime(2022);
  TimeOfDay _fromTime = const TimeOfDay(hour: 0, minute: 0);
  DateTime _toDate = DateTime(2022);
  TimeOfDay _toTime = const TimeOfDay(hour: 0, minute: 0);
  int nextHours = 1;
  bool holidaySet = false;
  bool onHoliday = false;

  @override
  void initState() {
    //Retrieve any current holiday dates
    refreshCurrent();
    super.initState();
  }

  void refreshCurrent() {
    //Retrieve any current holiday dates
    DropBoxAPIFn.getDropBoxFile(
      oauthToken: oauthToken,
      fileToDownload: currentHolidayFile,
      callback: processCurrentHoliday,
      contentType: ContentType.text,
      timeoutSecs: 0,
    );
    resetDates();
  }

  void resetDates() {
    DateTime now = DateTime.now();
    _fromDate = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    _fromTime = TimeOfDay(hour: _fromDate.hour, minute: _fromDate.minute);
    _toDate = _fromDate.add(const Duration(hours: 1));
    _toTime = TimeOfDay(
      hour: _toDate.hour,
      minute: _toDate.minute,
    );
  }

  void processCurrentHoliday(String filename, String contents) {
//    print("Got current holiday: " + contents);
    DateTime newFromDate = DateTime(2022);
    DateTime newToDate = DateTime(2022);
    if (mounted) {
      setState(() {
        contents.split('\n').forEach((line) {
          List<String> fields = line.split(',');
          if (line.startsWith('Start,')) {
            holidaySet = true;
            try {
              newFromDate = DateTime(
                  (2000 + int.parse(fields[1])),
                  int.parse(fields[2]),
                  int.parse(fields[3]),
                  int.parse(fields[4]),
                  fields.length > 5 ? int.parse(fields[5]) : 0);
            } on FormatException {
              print("Received incorrect holiday start line: $line");
            }
          } else if (line.startsWith('End,')) {
            try {
              newToDate = DateTime(
                  (2000 + int.parse(fields[1])),
                  int.parse(fields[2]),
                  int.parse(fields[3]),
                  int.parse(fields[4]),
                  fields.length > 5 ? int.parse(fields[5]) : 0);
            } on FormatException {
              print("Received incorrect holiday end line: $line");
            }
          }
        });
        if (holidaySet) {
          //Check if holiday period still active
          if (newFromDate.isAfter(_fromDate)) {
            //Holiday in future
            onHoliday = false;
          } else if (newToDate.isAfter(_fromDate)) {
            //On Holiday
            onHoliday = true;
          } else {
            //Holiday in past - ignore
            onHoliday = false;
            holidaySet = false;
          }
          if (holidaySet) {
            _fromDate = newFromDate;
            _fromTime =
                TimeOfDay(hour: _fromDate.hour, minute: _fromDate.minute);
            _toDate = newToDate;
            _toTime = TimeOfDay(hour: _toDate.hour, minute: _toDate.minute);
          }
        }
      });
    }
  }

  void minusPressed() {
    if (mounted) {
      setState(() {
        if (nextHours > 1) {
          nextHours -= 1;
          resetDates();
          _toDate = _fromDate.add(Duration(hours: nextHours));
          _toTime = TimeOfDay.fromDateTime(_toDate);
        }
      });
    }
  }

  void plusPressed() {
    if (mounted) {
      setState(() {
        nextHours += 1;
        resetDates();
        _toDate = _fromDate.add(Duration(hours: nextHours));
        _toTime = TimeOfDay.fromDateTime(_toDate);
      });
    }
  }

  void sendNewHoliday() {
    StringBuffer buff = StringBuffer();
    buff.writeln(
        "Start,${_fromDate.year - 2000},${_fromDate.month},${_fromDate.day},${_fromTime.hour},${_fromTime.minute}");
    buff.writeln(
        "End,${_toDate.year - 2000},${_toDate.month},${_toDate.day},${_toTime.hour},${_toTime.minute}");
    buff.writeln("Temp,$holidayTemp");
    String contents = buff.toString();
    DropBoxAPIFn.sendDropBoxFile(
        oauthToken: oauthToken,
        fileToUpload: currentHolidayFile,
        contents: contents);
    DropBoxAPIFn.sendDropBoxFile(
      oauthToken: oauthToken,
      fileToUpload: holidayFile,
      contents: contents,
      callback: notifyFileSent,
      callbackMsg: 'New Holiday Schedule sent!',
    );
    if (mounted) {
      setState(() {
        refreshCurrent();
      });
    }
  }

  void cancelHoliday() {
    StringBuffer buff = StringBuffer();
    buff.writeln("Start,19,01,01,01,00");
    buff.writeln("End,19,01,01,02,00");
    buff.writeln("Temp,$holidayTemp");
    String contents = buff.toString();
    DropBoxAPIFn.sendDropBoxFile(
        oauthToken: oauthToken,
        fileToUpload: currentHolidayFile,
        contents: contents);
    DropBoxAPIFn.sendDropBoxFile(
        oauthToken: oauthToken,
        fileToUpload: holidayFile,
        contents: contents,
        callback: notifyFileSent,
        callbackMsg: 'Holiday cancelled!');
    if (mounted) {
      setState(() {
        refreshCurrent();
      });
    }
  }

  void notifyFileSent(String contents, String message) {
    showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return SimpleDialog(
          title: Text(message),
          children: <Widget>[
            SimpleDialogOption(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [Text('OK')],
              ),
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String title = 'Set Holiday dates';
    final textStyle = Theme.of(context).textTheme.titleMedium;
    if (onHoliday) {
      title = 'On holiday! Change dates to reset';
    } else if (holidaySet) {
      title = 'Holiday already set. Change dates to reset';
    }
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: <Widget>[
        Text(
          title,
          style: textStyle,
//              Theme.of(context).textTheme.display1.apply(fontSizeFactor: 0.5),
        ),
        const SizedBox(height: 8.0),
        _DateTimePicker(
          key: const Key("From"),
          labelText: 'From',
          selectedDate: _fromDate,
          selectedTime: _fromTime,
          selectDate: (DateTime date) {
            setState(() {
              _fromDate = date;
              _toDate = _fromDate.add(const Duration(hours: 1));
            });
          },
          selectTime: (TimeOfDay time) {
            setState(() {
              _fromTime = time;
              _fromDate = DateTime(_fromDate.year, _fromDate.month,
                  _fromDate.day, _fromTime.hour, _fromTime.minute);
              _toTime = TimeOfDay.fromDateTime(
                  _fromDate.add(const Duration(hours: 1)));
            });
          },
        ),
        _DateTimePicker(
          key: const Key("To"),
          labelText: 'To',
          selectedDate: _toDate,
          selectedTime: _toTime,
          selectDate: (DateTime date) {
            setState(() {
              _toDate = date;
            });
          },
          selectTime: (TimeOfDay time) {
            setState(() {
              _toTime = time;
              _toDate = DateTime(_toDate.year, _toDate.month, _toDate.day,
                  _toTime.hour, _toTime.minute);
            });
          },
        ),
        const SizedBox(height: 32.0),
        Text(
          'OR\n\nSet in holiday mode for next',
          style: textStyle,
//              Theme.of(context).textTheme.display1.apply(fontSizeFactor: 0.5),
        ),
        const SizedBox(height: 16.0),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
                onPressed: minusPressed,
                style: const ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(Colors.blue)),
                child: const Icon(
                  Icons.remove,
                  color: Colors.white,
                )),
            Text(
              ' $nextHours hours  ',
              style: textStyle,
//              Theme.of(context)
//                  .textTheme
//                  .display1
//                  .apply(fontSizeFactor: 0.5),
            ),
            ElevatedButton(
                onPressed: plusPressed,
                style: const ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(Colors.blue)),
                child: const Icon(
                  Icons.add,
                  color: Colors.white,
                ))
          ],
        ),
        const SizedBox(height: 32.0),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
          ElevatedButton(
              onPressed: sendNewHoliday,
              style: const ButtonStyle(
                  backgroundColor: WidgetStatePropertyAll(Colors.blue)),
              child: Text(
                "Send New Holiday Schedule",
                style: textStyle!.apply(
                  color: Colors.white,
                ),
              ))
        ]),
        const SizedBox(height: 32.0),
        Text(
          'OR:',
          style: textStyle,
        ),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
          ElevatedButton(
              onPressed: cancelHoliday,
              style: const ButtonStyle(
                  backgroundColor: WidgetStatePropertyAll(Colors.blue)),
              child: Text(
                "Cancel",
                style: textStyle.apply(
                  color: Colors.white,
                ),
              ))
        ]),
      ],
    );
  }
//      ),
//    );
}

class _DateTimePicker extends StatelessWidget {
  const _DateTimePicker(
      {required Key key,
      required this.labelText,
      required this.selectedDate,
      required this.selectedTime,
      required this.selectDate,
      required this.selectTime})
      : super(key: key);

  final String labelText;
  final DateTime selectedDate;
  final TimeOfDay selectedTime;
  final ValueChanged<DateTime> selectDate;
  final ValueChanged<TimeOfDay> selectTime;

  Future<void> _selectDate(BuildContext context) async {
    final DateTime picked = (await showDatePicker(
        context: context,
        initialDate: selectedDate,
        firstDate: DateTime(2015, 8),
        lastDate: DateTime(2101)))!;
    if (picked != selectedDate) selectDate(picked);
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay picked =
        (await showTimePicker(context: context, initialTime: selectedTime))!;
    if (picked != selectedTime) selectTime(picked);
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle valueStyle = Theme.of(context).textTheme.titleMedium!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(
          flex: 4,
          child: _InputDropdown(
            key: Key(labelText),
            labelText: labelText,
            valueText: DateFormat.yMMMd().format(selectedDate),
            valueStyle: valueStyle,
            onPressed: () {
              _selectDate(context);
            },
          ),
        ),
        const SizedBox(width: 12.0),
        Expanded(
          flex: 3,
          child: _InputDropdown(
            key: Key(selectedTime.format(context)),
            valueText: selectedTime.format(context),
            valueStyle: valueStyle,
            onPressed: () {
              _selectTime(context);
            },
          ),
        ),
      ],
    );
  }
}

class _InputDropdown extends StatelessWidget {
  _InputDropdown(
      {required Key key,
      this.labelText,
      required this.valueText,
      required this.valueStyle,
      required this.onPressed})
      : super(key: key);

  final String? labelText;
  final String valueText;
  final TextStyle valueStyle;
  final VoidCallback onPressed;
  Widget? child;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: labelText,
        ),
        baseStyle: valueStyle,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(valueText, style: valueStyle),
            Icon(Icons.arrow_drop_down,
                color: Theme.of(context).brightness == Brightness.light
                    ? Colors.grey.shade700
                    : Colors.white70),
          ],
        ),
      ),
    );
  }
}
