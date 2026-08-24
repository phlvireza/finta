enum SquiPose { wave, empty, cheer, rest }

extension SquiPoseAsset on SquiPose {
  String get asset => 'assets/images/squi/squi_$name.png';
}

class SquiSizes {
  SquiSizes._();

  static const double sm = 48;
  static const double md = 96;
  static const double lg = 160;
}
