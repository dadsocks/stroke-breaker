import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/distance_bucket.dart';
import '../models/hole_result.dart';
import '../models/putt_scenario.dart';
import '../models/putting_session.dart';
import '../models/session_stats.dart';
import 'random_putt_generator.dart';
import 'session_storage_service.dart';
import 'practice_repository.dart';

class SessionManager extends ChangeNotifier {
  SessionManager({
    required this.generator,
    required this.storage,
    this.practiceRepository,
  });

  final RandomPuttGenerator generator;
  final SessionStorageService storage;
  final PracticeRepository? practiceRepository;
  final Random _bucketRandom = Random();

  PuttingSession? _session;
  PuttScenario? _currentScenario;
  FirstPuttFeedback? _pendingFirstFeedback;
  SecondPuttDistance? _selectedSecondDistance;

  PuttingSession? get session => _session;
  List<HoleResult> get holes => _session?.holes ?? const [];
  SessionStats? get stats => _session?.stats;
  bool get includeSlope => _session?.includeSlope ?? true;
  bool get hasActiveSession => _session != null;
  int get holeTarget => _session?.holeCount ?? 0;
  int get nextHoleNumber => (_session?.holes.length ?? 0) + 1;
  bool get waitingForSecondPutt =>
      _pendingFirstFeedback != null && _pendingFirstFeedback != FirstPuttFeedback.made;
  PuttScenario? get currentScenario => _currentScenario;
  FirstPuttFeedback? get pendingFirstFeedback => _pendingFirstFeedback;
  SecondPuttDistance? get selectedSecondDistance => _selectedSecondDistance;

  Future<void> loadPersistedSession() async {
    _session = await storage.loadSession();
    if (_session != null && !_session!.isComplete && _currentScenario == null) {
      _currentScenario = _createScenarioForNextHole();
    }
    notifyListeners();
  }

  Future<void> startNewSession(int holeCount) async {
    final slopeSetting = _session?.includeSlope ?? true;
    _session = PuttingSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      holeCount: holeCount,
      startedAt: DateTime.now(),
      includeSlope: slopeSetting,
      holes: const [],
    );
    _currentScenario = _createScenarioForNextHole();
    _pendingFirstFeedback = null;
    _selectedSecondDistance = null;
    await storage.saveSession(_session!);
    notifyListeners();
  }

  Future<void> toggleIncludeSlope(bool value) async {
    if (_session == null) return;
    _session = _session!.copyWith(includeSlope: value);
    await storage.saveSession(_session!);
    notifyListeners();
  }

  Future<void> recordFirstPutt(FirstPuttFeedback feedback) async {
    if (_session == null || _currentScenario == null) return;

    _pendingFirstFeedback = feedback;
    _selectedSecondDistance = null;
    if (feedback == FirstPuttFeedback.made) {
      await _finalizeHole();
    } else {
      notifyListeners();
    }
  }

  Future<void> chooseSecondPuttDistance(SecondPuttDistance distance) async {
    _selectedSecondDistance = distance;
    notifyListeners();

    if (distance == SecondPuttDistance.tapIn) {
      await submitSecondPutt(made: true);
    }
  }

  Future<void> submitSecondPutt({required bool made}) async {
    if (!waitingForSecondPutt || _session == null || _currentScenario == null) return;

    final distance = _selectedSecondDistance ?? SecondPuttDistance.tapIn;
    final resolvedMade = distance == SecondPuttDistance.tapIn ? true : made;
    await _finalizeHole(secondDistance: distance, secondMade: resolvedMade);
  }

  Future<void> _finalizeHole({
    SecondPuttDistance? secondDistance,
    bool? secondMade,
  }) async {
    final session = _session;
    final scenario = _currentScenario;
    final firstFeedback = _pendingFirstFeedback;

    if (session == null || scenario == null || firstFeedback == null) return;

    final holeResult = HoleResult(
      holeNumber: session.holes.length + 1,
      scenario: scenario,
      firstFeedback: firstFeedback,
      secondDistance: secondDistance,
      secondMade: secondMade,
    );

    _session = session.copyWith(holes: [...session.holes, holeResult]);
    _pendingFirstFeedback = null;
    _selectedSecondDistance = null;

    final isComplete = _session!.isComplete;
    final completedSession = _session!;

    if (isComplete) {
      _currentScenario = null;
    } else {
      _currentScenario = _createScenarioForNextHole();
    }

    await storage.saveSession(_session!);
    notifyListeners();

    if (isComplete && practiceRepository != null) {
      unawaited(_uploadSession(completedSession));
    }
  }

  Future<void> endSession() async {
    _session = null;
    _currentScenario = null;
    _pendingFirstFeedback = null;
    _selectedSecondDistance = null;
    await storage.clearSession();
    notifyListeners();
  }

  Future<void> _uploadSession(PuttingSession session) async {
    try {
      await practiceRepository!.saveSession(session);
    } catch (error, stackTrace) {
      debugPrint('Failed to upload session: $error');
      debugPrint(stackTrace.toString());
    }
  }

  PuttScenario _createScenarioForNextHole() {
    final bucket = _selectBucketForNextHole();
    final slope = _session?.includeSlope ?? true;
    return generator.generate(includeSlope: slope, bucket: bucket);
  }

  DistanceBucket _selectBucketForNextHole() {
    final session = _session;
    if (session == null) {
      return DistanceBucket.values[_bucketRandom.nextInt(DistanceBucket.values.length)];
    }
    final targetPerBucket = (session.holeCount / DistanceBucket.values.length).floor();
    final counts = <DistanceBucket, int>{
      for (final bucket in DistanceBucket.values) bucket: 0,
    };
    for (final hole in session.holes) {
      final bucket = bucketForDistance(hole.scenario.distanceFeet);
      counts[bucket] = (counts[bucket] ?? 0) + 1;
    }
    final available = DistanceBucket.values
        .where((bucket) => (counts[bucket] ?? 0) < targetPerBucket)
        .toList();
    if (available.isEmpty) {
      return DistanceBucket.values[_bucketRandom.nextInt(DistanceBucket.values.length)];
    }
    return available[_bucketRandom.nextInt(available.length)];
  }

  Future<SessionStats> fetchAverageStats() async {
    if (practiceRepository == null) {
      return SessionStats.empty();
    }
    return practiceRepository!.fetchAverageStats();
  }

  Future<List<PuttingSession>> fetchPastSessions() async {
    if (practiceRepository == null) return const [];
    return practiceRepository!.fetchSessions();
  }

  Future<Map<String, double>> fetchAverageSgByDistance() async {
    if (practiceRepository == null) return const {};
    return practiceRepository!.fetchAverageStrokesGainedByDistance();
  }

  Future<void> undoLastHole() async {
    final session = _session;
    if (session == null || session.holes.isEmpty) return;

    final updatedHoles = [...session.holes];
    final removed = updatedHoles.removeLast();
    _session = session.copyWith(holes: updatedHoles);
    _currentScenario = removed.scenario;
    _pendingFirstFeedback = null;
    _selectedSecondDistance = null;
    await storage.saveSession(_session!);
    notifyListeners();
  }
}
