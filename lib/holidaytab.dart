import 'package:flutter/material.dart';

class HolidayPage extends StatefulWidget {
  HolidayPage({@required this.oauthToken});

  String oauthToken;

  @override
  State createState() => _HolidayPageState(oauthToken: oauthToken);
}

class _HolidayPageState extends State<HolidayPage> {
  _HolidayPageState({@required this.oauthToken});

  final String oauthToken;

  @override
  Widget build(BuildContext context) {
    return               Icon(Icons.directions_bike);

  }
}
