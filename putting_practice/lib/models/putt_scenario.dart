import 'dart:convert';

enum LieType { flat, uphill, downhill }

enum BreakType { straight, leftToRight, rightToLeft }

class PuttScenario {
  const PuttScenario({
    required this.distanceFeet,
    required this.lie,
    required this.breakType,
    this.slopePercent,
  });

  final int distanceFeet;
  final LieType lie;
  final BreakType breakType;
  final double? slopePercent;

  bool get hasSlope => slopePercent != null;

  Map<String, dynamic> toMap() {
    return {
      'distanceFeet': distanceFeet,
      'lie': lie.name,
      'breakType': breakType.name,
      'slopePercent': slopePercent,
    };
  }

  factory PuttScenario.fromMap(Map<String, dynamic> map) {
    return PuttScenario(
      distanceFeet: map['distanceFeet'] as int,
      lie: LieType.values.firstWhere((lie) => lie.name == map['lie']),
      breakType: BreakType.values.firstWhere((value) => value.name == map['breakType']),
      slopePercent: (map['slopePercent'] as num?)?.toDouble(),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory PuttScenario.fromJson(String source) =>
      PuttScenario.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

extension LieTypeLabels on LieType {
  String get label {
    switch (this) {
      case LieType.flat:
        return 'Flat';
      case LieType.uphill:
        return 'Uphill';
      case LieType.downhill:
        return 'Downhill';
    }
  }
}

extension BreakTypeLabels on BreakType {
  String get label {
    switch (this) {
      case BreakType.straight:
        return 'Straight';
      case BreakType.leftToRight:
        return 'Left → Right';
      case BreakType.rightToLeft:
        return 'Right → Left';
    }
  }
}
