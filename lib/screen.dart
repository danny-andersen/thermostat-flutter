import 'package:flutter/material.dart';

enum ScreenType { desktop, tablet, handset, embedded }

class FormFactor {
  //Widths of associated devices
  static double desktop = 900;
  static double tablet = 600;
  static double handset = 400;

  static ScreenType getScreenType(BuildContext context) {
    // Use .shortestSide to detect device type regardless of orientation
    double deviceWidth = MediaQuery.of(context).size.shortestSide;
    if (deviceWidth > FormFactor.desktop) return ScreenType.desktop;
    if (deviceWidth > FormFactor.tablet) return ScreenType.tablet;
    if (deviceWidth > FormFactor.handset) return ScreenType.handset;
    return ScreenType.embedded;
  }
}
