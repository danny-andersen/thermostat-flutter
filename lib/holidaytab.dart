import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dropbox-api.dart';

class HolidayPage extends StatefulWidget {
  HolidayPage({@required this.oauthToken});

  final String oauthToken;

  @override
  State createState() => _HolidayPageState(oauthToken: oauthToken);
}

class _HolidayPageState extends State<HolidayPage> {
  _HolidayPageState({@required this.oauthToken});

  final String oauthToken;
  final Uri downloadUri =
      Uri.parse("https://content.dropboxapi.com/2/files/download");
  final String currentHolidayFile = "/holiday.txt.current";
  final String holidayFile = "/holiday.txt";
  HttpClient client = new HttpClient();

  DateTime _fromDate;
  TimeOfDay _fromTime;
  DateTime _toDate;
  TimeOfDay _toTime;
  double holidayTemp = 10.0;
  int nextHours = 1;

  @override
  void initState() {
    //Retrieve any current holiday dates
    getDropBoxFile(
        client: this.client,
        oauthToken: this.oauthToken,
        fileToDownload: this.currentHolidayFile,
        callback: processCurrentHoliday);
    DateTime now = DateTime.now();
    _fromDate = DateTime(now.year, now.month, now.day, now.hour);
    _fromTime = TimeOfDay(hour: _fromDate.hour, minute: 0);
    _toDate = _fromDate.add(Duration(hours: 1));
    _toTime = TimeOfDay(hour: _toDate.hour, minute: _toDate.minute, );
    super.initState();
  }

  void processCurrentHoliday(String contents) {
//    print("Got current holiday: " + contents);
    setState(() {
      contents.split('\n').forEach((line) {
        List<String> fields = line.split(',');
        if (line.startsWith('Start,')) {
          try {
            DateTime newfromDate = DateTime(
                (2000 + int.parse(fields[1])),
                int.parse(fields[2]),
                int.parse(fields[3]),
                int.parse(fields[4]));
            if (newfromDate.isAfter(_fromDate)) {
              _fromDate = newfromDate;
              _fromTime = TimeOfDay(hour: int.parse(fields[4]), minute: 0);
            }
          } on FormatException {
            print("Received incorrect holiday start line: $line");
          }
        } else if (line.startsWith('End,')) {
          try {
            DateTime newToDate = DateTime(
                (2000 + int.parse(fields[1])),
                int.parse(fields[2]),
                int.parse(fields[3]),
                int.parse(fields[4]));
            if (newToDate.isAfter(_toDate)) {
              _toDate = newToDate;
              _toTime = TimeOfDay(hour: int.parse(fields[4]), minute: 0);
            }
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
    });
  }

  void minusPressed() {
    setState(() {
      if (nextHours >= 1) {
        nextHours -= 1;
        _toDate =
            DateTime.fromMillisecondsSinceEpoch(_toDate.millisecondsSinceEpoch)
                .add(Duration(hours: -1));
        _toTime = TimeOfDay.fromDateTime(_toDate);
      }
    });
  }

  void plusPressed() {
    setState(() {
      nextHours += 1;
      _toDate =
          DateTime.fromMillisecondsSinceEpoch(_toDate.millisecondsSinceEpoch)
              .add(Duration(hours: 1));
      _toTime = TimeOfDay.fromDateTime(_toDate);
    });
  }

  void sendNewHoliday() {
    StringBuffer buff = StringBuffer();
    buff.writeln(
        "Start,${_fromDate.year - 2000},${_fromDate.month},${_fromDate.day},${_fromTime.hour}");
    buff.writeln(
        "End,${_toDate.year - 2000},${_toDate.month},${_toDate.day},${_toTime.hour}");
    buff.writeln("Temp,$holidayTemp");
    String contents = buff.toString();
    sendDropBoxFile(
        client: this.client,
        oauthToken: this.oauthToken,
        fileToUpload: currentHolidayFile,
        contents: contents);
    sendDropBoxFile(
        client: this.client,
        oauthToken: this.oauthToken,
        fileToUpload: holidayFile,
        contents: contents);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: <Widget>[
        Text(
          'Set Holiday dates',
          style:
              Theme.of(context).textTheme.display1.apply(fontSizeFactor: 0.5),
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
              _fromDate = DateTime(_fromDate.year, _fromDate.month, _fromDate.day, _fromTime.hour, _fromTime.minute);
              _toTime = TimeOfDay.fromDateTime(_fromDate.add(Duration(hours: 1)));
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
              _toDate = DateTime(_toDate.year, _toDate.month, _toDate.day, _toTime.hour, _toTime.minute);
            });
          },
        ),
        const SizedBox(height: 32.0),
        Text(
          'Or set in holiday mode for next $nextHours hours ',
          style:
              Theme.of(context).textTheme.display1.apply(fontSizeFactor: 0.5),
        ),
        const SizedBox(height: 16.0),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            RaisedButton(
              child: Icon(Icons.remove),
//                      tooltip: "Increase holiday time by 1 hour",
              onPressed: minusPressed,
            ),
            RaisedButton(
              child: Icon(Icons.add),
//                        tooltip: "Decrease holiday time by 1 hour",
              onPressed: plusPressed,
            ),
          ],
        ),
        const SizedBox(height: 32.0),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
          RaisedButton(
            child: Text("Send"),
            onPressed: sendNewHoliday,
          )
        ]),
      ],
    );
//      ),
//    );
  }
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
