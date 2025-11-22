import 'hole_result.dart';

class SessionStats {
  SessionStats({
    required this.holesLogged,
    required this.totalPutts,
    required this.firstPuttMakeRate,
    required this.twoPuttRate,
    required this.threePlusRate,
    required this.averageSecondLeave,
    required this.averageStrokesGained,
  });

  final int holesLogged;
  final int totalPutts;
  final double firstPuttMakeRate;
  final double twoPuttRate;
  final double threePlusRate;
  final double averageSecondLeave;
  final double averageStrokesGained;

  static SessionStats fromHoles(List<HoleResult> holes) {
    final totalHoles = holes.length;
    if (totalHoles == 0) {
      return SessionStats(
        holesLogged: 0,
        totalPutts: 0,
        firstPuttMakeRate: 0,
        twoPuttRate: 0,
        threePlusRate: 0,
        averageSecondLeave: 0,
        averageStrokesGained: 0,
      );
    }

    final totalPutts = holes.fold<int>(0, (sum, hole) => sum + hole.totalPutts);
    final firstMakes = holes.where((hole) => hole.firstPuttMade).length;
    final twoPutts = holes.where((hole) => hole.totalPutts == 2).length;
    final threePlus = holes.where((hole) => hole.totalPutts >= 3).length;

    final leaves = holes
        .map((hole) => hole.secondLeaveFeet)
        .whereType<double>()
        .toList(growable: false);

	    final double avgLeave = leaves.isEmpty
	        ? 0.0
	        : leaves.fold<double>(0.0, (sum, value) => sum + value) / leaves.length.toDouble();

    return SessionStats(
      holesLogged: totalHoles,
      totalPutts: totalPutts,
      firstPuttMakeRate: firstMakes / totalHoles,
      twoPuttRate: twoPutts / totalHoles,
      threePlusRate: threePlus / totalHoles,
      averageSecondLeave: avgLeave,
      averageStrokesGained: 0,
    );
  }

  static SessionStats empty() => SessionStats(
        holesLogged: 0,
        totalPutts: 0,
        firstPuttMakeRate: 0,
        twoPuttRate: 0,
        threePlusRate: 0,
        averageSecondLeave: 0,
        averageStrokesGained: 0,
      );
}
