import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dropbox-api.dart';

class HolidayPage extends StatefulWidget {
  HolidayPage({@required this.client, @required this.oauthToken});

  final String oauthToken;
  final HttpClient client;

  @override
  State createState() => _HolidayPageState(client: this.client, oauthToken: oauthToken);
}

class _HolidayPageState extends State<HolidayPage> {
  _HolidayPageState({@required this.client, @required this.oauthToken});

  final String oauthToken;
  final HttpClient client;
  final Uri downloadUri =
      Uri.parse("https://content.dropboxapi.com/2/files/download");
  final String currentHolidayFile = "/holiday.txt.current";
  final String holidayFile = "/holiday.txt";

  DateTime _fromDate;
  TimeOfDay _fromTime;
  DateTime _toDate;
  TimeOfDay _toTime;
  double holidayTemp = 10.0;
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
        client: this.client,
        oauthToken: this.oauthToken,
        fileToDownload: this.currentHolidayFile,
        callback: processCurrentHoliday);
    resetDates();
  }

  void resetDates() {
    DateTime now = DateTime.now();
    _fromDate = DateTime(now.year, now.month, now.day, now.hour);
    _fromTime = TimeOfDay(hour: _fromDate.hour, minute: 0);
    _toDate = _fromDate.add(Duration(hours: 1));
    _toTime = TimeOfDay(
      hour: _toDate.hour,
      minute: _toDate.minute,
    );
  }

  void processCurrentHoliday(String contents) {
//    print("Got current holiday: " + contents);
    DateTime newFromDate;
    DateTime newToDate;
    if (this.mounted) {
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
                  int.parse(fields[4]));
            } on FormatException {
              print("Received incorrect holiday start line: $line");
            }
          } else if (line.startsWith('End,')) {
            try {
              newToDate = DateTime(
                  (2000 + int.parse(fields[1])),
                  int.parse(fields[2]),
                  int.parse(fields[3]),
                  int.parse(fields[4]));
            } on FormatException {
              print("Received incorrect holiday end line: $line");
            }
          } else if (line.startsWith('Temp,')) {
            try {
              holidayTemp = double.parse(fields[1]);
            } on FormatException {
              print("Couldn't parse temp double: $line");
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
            _fromTime = TimeOfDay(hour: _fromDate.hour, minute: 0);
            _toDate = newToDate;
            _toTime = TimeOfDay(hour: _toDate.hour, minute: 0);
          }
        }
      });
    }
  }

  void minusPressed() {
    if (this.mounted) {
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
    if (this.mounted) {
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
        "Start,${_fromDate.year - 2000},${_fromDate.month},${_fromDate.day},${_fromTime.hour}");
    buff.writeln(
        "End,${_toDate.year - 2000},${_toDate.month},${_toDate.day},${_toTime.hour}");
    buff.writeln("Temp,$holidayTemp");
    String contents = buff.toString();
    DropBoxAPIFn.sendDropBoxFile(
        client: this.client,
        oauthToken: this.oauthToken,
        fileToUpload: currentHolidayFile,
        contents: contents);
    DropBoxAPIFn.sendDropBoxFile(
      client: this.client,
      oauthToken: this.oauthToken,
      fileToUpload: holidayFile,
      contents: contents,
      callback: notifyFileSent,
      callbackMsg: 'New Holiday Schedule sent!',
    );
    if (this.mounted) {
      setState(() {
        refreshCurrent();
      });
    }
  }

  void cancelHoliday() {
    StringBuffer buff = StringBuffer();
    buff.writeln("Start,19,01,01,01");
    buff.writeln("End,19,01,01,02");
    buff.writeln("Temp,$holidayTemp");
    String contents = buff.toString();
    DropBoxAPIFn.sendDropBoxFile(
        client: this.client,
        oauthToken: this.oauthToken,
        fileToUpload: currentHolidayFile,
        contents: contents);
    DropBoxAPIFn.sendDropBoxFile(
        client: this.client,
        oauthToken: this.oauthToken,
        fileToUpload: holidayFile,
        contents: contents,
        callback: notifyFileSent,
        callbackMsg: 'Holiday cancelled!');
    if (this.mounted) {
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [const Text('OK')],
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
    final textStyle = Theme.of(context).textTheme.title;
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
          labelText: 'From',
          selectedDate: _fromDate,
          selectedTime: _fromTime,
          selectDate: (DateTime date) {
            setState(() {
              _fromDate = date;
              _toDate = _fromDate.add(Duration(hours: 1));
            });
          },
          selectTime: (TimeOfDay time) {
            setState(() {
              _fromTime = time;
              _fromDate = DateTime(_fromDate.year, _fromDate.month,
                  _fromDate.day, _fromTime.hour, _fromTime.minute);
              _toTime =
                  TimeOfDay.fromDateTime(_fromDate.add(Duration(hours: 1)));
            });
          },
        ),
        _DateTimePicker(
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
            RaisedButton(
              child: Icon(
                Icons.remove,
                color: Colors.white,
              ),
              elevation: 15,
              onPressed: minusPressed,
              color: Colors.blue,
            ),
            Text(
              ' $nextHours hours  ',
              style: textStyle,
//              Theme.of(context)
//                  .textTheme
//                  .display1
//                  .apply(fontSizeFactor: 0.5),
            ),
            RaisedButton(
              child: Icon(
                Icons.add,
                color: Colors.white,
              ),
            elevation: 15,
              onPressed: plusPressed,
              color: Colors.blue,
            ),
          ],
        ),
        const SizedBox(height: 32.0),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
          RaisedButton(
            child: Text(
              "Send New Holiday Schedule",
              style: textStyle.apply(
                color: Colors.white,
              ),
            ),
            onPressed: sendNewHoliday,
            elevation: 15,
            color: Colors.blue,
          )
        ]),
        const SizedBox(height: 32.0),
        Text(
          'OR:',
          style: textStyle,
        ),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
          RaisedButton(
            child: Text(
              "Cancel",
              style: textStyle.apply(
                color: Colors.white,
              ),
            ),
            onPressed: holidaySet ? cancelHoliday : null,
            color: Colors.blue,
            disabledElevation: 10,
            elevation: 15,
          )
        ]),
      ],
    );
  }
//      ),
//    );

}

class _DateTimePicker extends StatelessWidget {
  const _DateTimePicker(
      {Key key,
      this.labelText,
      this.selectedDate,
      this.selectedTime,
      this.selectDate,
      this.selectTime})
      : super(key: key);

  final String labelText;
  final DateTime selectedDate;
  final TimeOfDay selectedTime;
  final ValueChanged<DateTime> selectDate;
  final ValueChanged<TimeOfDay> selectTime;

  Future<void> _selectDate(BuildContext context) async {
    final DateTime picked = await showDatePicker(
        context: context,
        initialDate: selectedDate,
        firstDate: DateTime(2015, 8),
        lastDate: DateTime(2101));
    if (picked != null && picked != selectedDate) selectDate(picked);
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay picked =
        await showTimePicker(context: context, initialTime: selectedTime);
    if (picked != null && picked != selectedTime) selectTime(picked);
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle valueStyle = Theme.of(context).textTheme.title;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(
          flex: 4,
          child: _InputDropdown(
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
  const _InputDropdown(
      {Key key,
      this.child,
      this.labelText,
      this.valueText,
      this.valueStyle,
      this.onPressed})
      : super(key: key);

  final String labelText;
  final String valueText;
  final TextStyle valueStyle;
  final VoidCallback onPressed;
  final Widget child;

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
