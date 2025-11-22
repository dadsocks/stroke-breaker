import 'dart:convert';

import 'putt_scenario.dart';

enum FirstPuttFeedback {
  fastLeft,
  fast,
  fastRight,
  left,
  right,
  slowLeft,
  slow,
  slowRight,
  made,
}

enum SecondPuttDistance {
  tapIn(2),
  three(3),
  four(4),
  five(5),
  six(6),
  seven(7),
  eight(8),
  overNine(10);

  const SecondPuttDistance(this.feet);
  final int feet;
}

class HoleResult {
  const HoleResult({
    required this.holeNumber,
    required this.scenario,
    required this.firstFeedback,
    this.secondDistance,
    this.secondMade,
  });

  final int holeNumber;
  final PuttScenario scenario;
  final FirstPuttFeedback firstFeedback;
  final SecondPuttDistance? secondDistance;
  final bool? secondMade;

  bool get firstPuttMade => firstFeedback == FirstPuttFeedback.made;

  bool get hasSecondPutt => !firstPuttMade && secondDistance != null;

  int get totalPutts {
    if (firstPuttMade) return 1;
    if (secondMade == true) return 2;
    return 3;
  }

  double? get secondLeaveFeet => secondDistance?.feet.toDouble();

  Map<String, dynamic> toMap() {
    return {
      'holeNumber': holeNumber,
      'scenario': scenario.toMap(),
      'firstFeedback': firstFeedback.name,
      'secondDistance': secondDistance?.name,
      'secondMade': secondMade,
    };
  }

  factory HoleResult.fromMap(Map<String, dynamic> map) {
    return HoleResult(
      holeNumber: map['holeNumber'] as int,
      scenario: PuttScenario.fromMap(map['scenario'] as Map<String, dynamic>),
      firstFeedback:
          FirstPuttFeedback.values.firstWhere((value) => value.name == map['firstFeedback']),
      secondDistance: (map['secondDistance'] as String?) == null
          ? null
          : SecondPuttDistance.values
              .firstWhere((value) => value.name == map['secondDistance']),
      secondMade: map['secondMade'] as bool?,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory HoleResult.fromJson(String source) =>
      HoleResult.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

extension FirstPuttFeedbackLabels on FirstPuttFeedback {
  String get label {
    switch (this) {
      case FirstPuttFeedback.fastLeft:
        return 'Fast Left';
      case FirstPuttFeedback.fast:
        return 'Fast';
      case FirstPuttFeedback.fastRight:
        return 'Fast Right';
      case FirstPuttFeedback.left:
        return 'Left';
      case FirstPuttFeedback.right:
        return 'Right';
      case FirstPuttFeedback.slowLeft:
        return 'Slow Left';
      case FirstPuttFeedback.slow:
        return 'Slow';
      case FirstPuttFeedback.slowRight:
        return 'Slow Right';
      case FirstPuttFeedback.made:
        return 'Made!';
    }
  }
}

extension SecondPuttDistanceLabels on SecondPuttDistance {
  String get label {
    switch (this) {
      case SecondPuttDistance.tapIn:
        return 'Tap-in';
      case SecondPuttDistance.three:
        return '3 ft';
      case SecondPuttDistance.four:
        return '4 ft';
      case SecondPuttDistance.five:
        return '5 ft';
      case SecondPuttDistance.six:
        return '6 ft';
      case SecondPuttDistance.seven:
        return '7 ft';
      case SecondPuttDistance.eight:
        return '8 ft';
      case SecondPuttDistance.overNine:
        return '>9 ft';
    }
  }
}
