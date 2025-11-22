import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/hole_result.dart';
import '../models/putting_session.dart';
import '../models/session_stats.dart';
import '../models/strokes_gained_baseline.dart';

class PracticeRepository {
  PracticeRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<void> ensureUserDocument(User user) async {
    final doc = _firestore.collection('users').doc(user.uid);
    await doc.set({
      'displayName': user.displayName ?? '',
      'email': user.email ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'handicapTarget': '',
    }, SetOptions(merge: true));
  }

  Future<void> saveSession(PuttingSession session) async {
    final user = _auth.currentUser;
    if (user == null || session.holes.isEmpty) return;

    final stats = session.stats;
    final now = DateTime.now();
    final durationMinutes = now.difference(session.startedAt).inMinutes;
    final attempts = stats.totalPutts;
    final shotResult = _buildShotsPayload(session, user.uid, now);
    final shotsPayload = shotResult.shots;
    final totalMade = shotsPayload.where((shot) => shot['made'] == true).length;
    final firstMakes = session.holes.where((hole) => hole.firstPuttMade).length;
    final twoPutts = session.holes.where((hole) => hole.totalPutts == 2).length;
    final threePlus = session.holes.where((hole) => hole.totalPutts >= 3).length;

    double secondLeaveSum = 0;
    int secondLeaveCount = 0;
    for (final hole in session.holes) {
      final leave = hole.secondLeaveFeet;
      if (leave != null) {
        secondLeaveSum += leave;
        secondLeaveCount++;
      }
    }
    final avgSecondLeave = secondLeaveCount == 0 ? 0.0 : secondLeaveSum / secondLeaveCount;

    final sessionData = {
      'Score': stats.totalPutts,
      'createdAt': Timestamp.fromDate(now),
      'durationMinutes': durationMinutes,
      'holes': session.holes.length,
      'mode': 'putting_practice',
      'practiceDate': Timestamp.fromDate(session.startedAt),
      'strokesGainedEstimate': shotResult.totalStrokesGained,
      'totalAttempts': attempts,
      'totalMade': totalMade,
      'totalPutts': stats.totalPutts,
      'firstPuttMakes': firstMakes,
      'twoPutts': twoPutts,
      'threePlus': threePlus,
      'averageSecondLeave': avgSecondLeave,
      'secondLeaveCount': secondLeaveCount,
      'userId': user.uid,
      'sessionJson': session.toJson(),
    };

    final sessionRef = _firestore.collection('sessions').doc(session.id);
    await sessionRef.set(sessionData);

    final batch = _firestore.batch();
    final shotsCollection = _firestore.collection('shots');
    for (final shot in shotsPayload) {
      batch.set(shotsCollection.doc(), shot);
    }
    await batch.commit();
  }

  _ShotPayloadResult _buildShotsPayload(
    PuttingSession session,
    String userId,
    DateTime now,
  ) {
    final timestamp = Timestamp.fromDate(now);
    final List<Map<String, dynamic>> payload = [];
    double totalStrokesGained = 0;

    for (final hole in session.holes) {
      final scenario = hole.scenario;
      final baseMeta = {
        'sessionID': session.id,
        'userId': userId,
        'createdAt': timestamp,
        'breakType': scenario.breakType.name,
        'lieType': scenario.lie.name,
      };

      final firstEndDistance =
          hole.firstPuttMade ? 0.0 : (hole.secondDistance?.feet ?? 0).toDouble();
      final firstShotSg = strokesGainedForPutt(
        startDistanceFeet: scenario.distanceFeet.toDouble(),
        endDistanceFeet: firstEndDistance,
      );
      payload.add({
        ...baseMeta,
        'sequenceIndex': 1,
        'distanceFeet': scenario.distanceFeet.toDouble(),
        'isTapIn': false,
        'made': hole.firstPuttMade,
        'resultFeetPast': firstEndDistance,
        'strokesGained': firstShotSg,
      });
      totalStrokesGained += firstShotSg;

      if (!hole.firstPuttMade) {
        final secondDistanceFeet = (hole.secondDistance?.feet ?? 2).toDouble();
        final secondIsTapIn = hole.secondDistance == SecondPuttDistance.tapIn;
        final secondMade = hole.secondMade ?? false;
        final secondEnd = secondMade ? 0.0 : 2.0;
        final secondShotSg = strokesGainedForPutt(
          startDistanceFeet: secondDistanceFeet,
          endDistanceFeet: secondEnd,
        );

        payload.add({
          ...baseMeta,
          'sequenceIndex': 2,
          'distanceFeet': secondDistanceFeet,
          'isTapIn': secondIsTapIn,
          'made': secondMade,
          'resultFeetPast': secondEnd,
          'strokesGained': secondShotSg,
        });
        totalStrokesGained += secondShotSg;

        if (!secondMade) {
          final thirdShotSg = strokesGainedForPutt(
            startDistanceFeet: 2,
            endDistanceFeet: 0,
          );
          payload.add({
            ...baseMeta,
            'sequenceIndex': 3,
            'distanceFeet': 2.0,
            'isTapIn': true,
            'made': true,
            'resultFeetPast': 0.0,
            'strokesGained': thirdShotSg,
          });
          totalStrokesGained += thirdShotSg;
        }
      }
    }

    return _ShotPayloadResult(
      shots: payload,
      totalStrokesGained: double.parse(totalStrokesGained.toStringAsFixed(3)),
      puttCount: payload.length,
    );
  }

  Future<SessionStats> fetchAverageStats() async {
    final user = _auth.currentUser;
    if (user == null) return SessionStats.empty();

    final snapshot =
        await _firestore.collection('sessions').where('userId', isEqualTo: user.uid).get();

    if (snapshot.docs.isEmpty) {
      return SessionStats.empty();
    }

    int sessionCount = snapshot.docs.length;
    int totalHoles = 0;
    int totalPutts = 0;
    int firstPuttMakes = 0;
    int twoPutts = 0;
    int threePlus = 0;
    double secondLeaveSum = 0;
    int secondLeaveCount = 0;
    double totalStrokesGained = 0;
    int sgSessions = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      totalHoles += (data['holes'] as num?)?.toInt() ?? 0;
      totalPutts += (data['totalPutts'] as num?)?.toInt() ?? 0;
      firstPuttMakes += (data['firstPuttMakes'] as num?)?.toInt() ?? 0;
      twoPutts += (data['twoPutts'] as num?)?.toInt() ?? 0;
      threePlus += (data['threePlus'] as num?)?.toInt() ?? 0;
      final avgLeave = (data['averageSecondLeave'] as num?)?.toDouble();
      final leaveCount = (data['secondLeaveCount'] as num?)?.toInt() ?? 0;
      if (avgLeave != null && leaveCount > 0) {
        secondLeaveSum += avgLeave * leaveCount;
        secondLeaveCount += leaveCount;
      }
      final sgValue = (data['strokesGainedEstimate'] as num?)?.toDouble();
      if (sgValue != null) {
        totalStrokesGained += sgValue;
        sgSessions++;
      }
    }

    final avgPuttsPerRound = sessionCount == 0 ? 0 : (totalPutts / sessionCount).round();
    final makeRate = totalHoles == 0 ? 0.0 : firstPuttMakes / totalHoles;
    final twoPuttRate = totalHoles == 0 ? 0.0 : twoPutts / totalHoles;
    final threePlusRate = totalHoles == 0 ? 0.0 : threePlus / totalHoles;
    final avgLeave = secondLeaveCount == 0 ? 0.0 : secondLeaveSum / secondLeaveCount;
    final avgSg = sgSessions == 0 ? 0.0 : totalStrokesGained / sgSessions;

    return SessionStats(
      holesLogged: sessionCount,
      totalPutts: avgPuttsPerRound,
      firstPuttMakeRate: makeRate,
      twoPuttRate: twoPuttRate,
      threePlusRate: threePlusRate,
      averageSecondLeave: avgLeave,
      averageStrokesGained: avgSg,
    );
  }

  Future<List<PuttingSession>> fetchSessions() async {
    final user = _auth.currentUser;
    if (user == null) return const [];

    final snapshot = await _firestore
        .collection('sessions')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .get();

    final sessions = <PuttingSession>[];
    for (final doc in snapshot.docs) {
      final json = doc.data()['sessionJson'] as String?;
      if (json == null) continue;
      try {
        sessions.add(PuttingSession.fromJson(json));
      } catch (error) {
        debugPrint('Failed to parse session ${doc.id}: $error');
      }
    }
    return sessions;
  }

  Future<Map<String, double>> fetchAverageStrokesGainedByDistance() async {
    final user = _auth.currentUser;
    if (user == null) return const {};

    final snapshot =
        await _firestore.collection('shots').where('userId', isEqualTo: user.uid).get();

    final totals = {
      for (final bucket in _sgBuckets) bucket.label: 0.0,
    };
    final counts = {
      for (final bucket in _sgBuckets) bucket.label: 0,
    };

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final distance = (data['distanceFeet'] as num?)?.toDouble();
      final sg = (data['strokesGained'] as num?)?.toDouble();
      if (distance == null || sg == null) continue;

      final bucket = _bucketForDistance(distance);
      totals[bucket.label] = totals[bucket.label]! + sg;
      counts[bucket.label] = counts[bucket.label]! + 1;
    }

    return {
      for (final bucket in _sgBuckets)
        bucket.label: (counts[bucket.label] ?? 0) == 0
            ? 0
            : totals[bucket.label]! / counts[bucket.label]!
    };
  }
}

class _ShotPayloadResult {
  _ShotPayloadResult({
    required this.shots,
    required this.totalStrokesGained,
    required this.puttCount,
  });

  final List<Map<String, dynamic>> shots;
  final double totalStrokesGained;
  final int puttCount;
}

class _SgBucket {
  const _SgBucket({required this.label, required this.min, this.max});

  final String label;
  final double min;
  final double? max;

  bool contains(double value) {
    final withinMin = value >= min;
    final withinMax = max == null ? true : value <= max!;
    return withinMin && withinMax;
  }
}

const List<_SgBucket> _sgBuckets = [
  _SgBucket(label: '0-3 ft', min: 0, max: 3),
  _SgBucket(label: '4-6 ft', min: 4, max: 6),
  _SgBucket(label: '7-9 ft', min: 7, max: 10),
  _SgBucket(label: '11-15 ft', min: 11, max: 15),
  _SgBucket(label: '16-20 ft', min: 16, max: 20),
  _SgBucket(label: '21-25 ft', min: 21, max: 25),
  _SgBucket(label: '26-30 ft', min: 26, max: 30),
  _SgBucket(label: '31-35 ft', min: 31, max: 35),
  _SgBucket(label: '36-40 ft', min: 36, max: 40),
  _SgBucket(label: '>40 ft', min: 41, max: null),
];

_SgBucket _bucketForDistance(double distance) {
  for (final bucket in _sgBuckets) {
    if (bucket.contains(distance)) {
      return bucket;
    }
  }
  if (distance < _sgBuckets.first.min) {
    return _sgBuckets.first;
  }
  return _sgBuckets.last;
}
