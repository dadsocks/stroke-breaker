import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/hole_result.dart';
import '../models/putt_scenario.dart';
import '../models/putting_session.dart';
import '../models/round_summary.dart';
import '../models/session_stats.dart';
import '../models/strokes_gained_baseline.dart';
import '../services/auth_service.dart';
import '../services/session_manager.dart';
import '../services/strokes_gained_calculator.dart';
import '../widgets/end_of_round_summary.dart';
import 'session_history_screen.dart';

class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key, required this.authService});

  final AuthService authService;

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  int _selectedHoleCount = 9;
  bool _startingSession = false;
  String? _shownSummarySessionId;

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<SessionManager>();
    final session = manager.session;
    final stats = manager.stats ?? SessionStats.fromHoles(const <HoleResult>[]);
    final scenario = manager.currentScenario;

    if (session == null) {
      _shownSummarySessionId = null;
    } else if (session.isComplete && _shownSummarySessionId != session.id) {
      _shownSummarySessionId = session.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showEndOfRoundSummary(context, manager, session, stats);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Putting Practice'),
        actions: [
          IconButton(
            tooltip: 'Session settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _showSettingsSheet(context),
          ),
          IconButton(
            tooltip: 'Session history',
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SessionHistoryScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () async {
              await widget.authService.signOut();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (session == null)
            _SessionStarter(
              selectedHoleCount: _selectedHoleCount,
              starting: _startingSession,
              onHoleCountSelected: (count) {
                setState(() => _selectedHoleCount = count);
              },
              onStartSession: () async {
                setState(() => _startingSession = true);
                try {
                  await manager.startNewSession(_selectedHoleCount);
                } finally {
                  if (mounted) {
                    setState(() => _startingSession = false);
                  }
                }
              },
            )
          else
            _HoleWorkflowSection(manager: manager, scenario: scenario),
          const SizedBox(height: 16),
          StatsOverviewCard(session: session),
          const SizedBox(height: 16),
          AverageSgBreakdownCard(session: session),
          if (session != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: manager.endSession,
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('End Session'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showEndOfRoundSummary(
    BuildContext context,
    SessionManager manager,
    PuttingSession session,
    SessionStats stats,
  ) async {
    final summary = RoundSummary.fromSession(session);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EndOfRoundSummarySheet(
        session: session,
        summary: summary,
        onStartNewSession: (holes) => _handleStartNew(manager, holes),
      ),
    );
  }

  Future<void> _handleStartNew(SessionManager manager, int holeCount) async {
    if (!mounted) return;
    setState(() {
      _selectedHoleCount = holeCount;
      _startingSession = true;
      _shownSummarySessionId = null;
    });
    try {
      await manager.startNewSession(holeCount);
    } finally {
      if (mounted) {
        setState(() => _startingSession = false);
      }
    }
  }

  void _showSettingsSheet(BuildContext context) {
    final manager = context.read<SessionManager>();
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Practice settings',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SwitchListTile(
                    title: const Text('Include slope %'),
                    subtitle: const Text('When off, slope always shows “—”'),
                    value: manager.includeSlope,
                    onChanged: (value) {
                      manager.toggleIncludeSlope(value);
                      setState(() {});
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _SessionStarter extends StatelessWidget {
  const _SessionStarter({
    required this.selectedHoleCount,
    required this.starting,
    required this.onHoleCountSelected,
    required this.onStartSession,
  });

  final int selectedHoleCount;
  final bool starting;
  final ValueChanged<int> onHoleCountSelected;
  final Future<void> Function() onStartSession;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Start a new session',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text('Choose 9 or 18 holes. Progress is stored locally.'),
            const SizedBox(height: 16),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 9, label: Text('9 holes')),
                ButtonSegment(value: 18, label: Text('18 holes')),
              ],
              selected: {selectedHoleCount},
              showSelectedIcon: false,
              onSelectionChanged: (selection) {
                if (selection.isNotEmpty) onHoleCountSelected(selection.first);
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 56,
              child: FilledButton.icon(
                onPressed: starting ? null : onStartSession,
                icon: const Icon(Icons.play_arrow),
                label: Text(starting ? 'Starting...' : 'New Session'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HoleWorkflowSection extends StatelessWidget {
  const _HoleWorkflowSection({
    required this.manager,
    required this.scenario,
  });

  final SessionManager manager;
  final PuttScenario? scenario;

  @override
  Widget build(BuildContext context) {
    final session = manager.session;
    if (session == null) {
      return const SizedBox.shrink();
    }

    final progress =
        session.holeCount == 0 ? 0.0 : session.holes.length / session.holeCount;

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress.clamp(0, 1),
            minHeight: 10,
            backgroundColor: Colors.grey.shade200,
          ),
        ),
        const SizedBox(height: 12),
        HoleScenarioCard(
          manager: manager,
          session: session,
          scenario: scenario,
        ),
        const SizedBox(height: 16),
        PuttPanelSwitcher(
          manager: manager,
          scenario: scenario,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: manager.session?.holes.isNotEmpty == true
                    ? manager.undoLastHole
                    : null,
                icon: const Icon(Icons.undo),
                label: const Text('Undo hole'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: manager.session != null
                    ? () async {
                        await manager.endSession();
                      }
                    : null,
                icon: const Icon(Icons.close),
                label: const Text('Cancel round'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class HoleScenarioCard extends StatelessWidget {
  const HoleScenarioCard({
    super.key,
    required this.manager,
    required this.session,
    required this.scenario,
  });

  final SessionManager manager;
  final PuttingSession session;
  final PuttScenario? scenario;

  @override
  Widget build(BuildContext context) {
    final nextHole = manager.nextHoleNumber.clamp(1, session.holeCount);
    final scenario = this.scenario;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hole $nextHole / ${session.holeCount}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (scenario == null)
              const Text('Session finished. Start another to continue.')
            else
              _ScenarioChips(
                scenario: scenario,
                includeSlope: manager.includeSlope,
              ),
          ],
        ),
      ),
    );
  }
}

class FirstPuttPanel extends StatelessWidget {
  const FirstPuttPanel({
    super.key,
    required this.manager,
    required this.enabled,
  });

  final SessionManager manager;
  final bool enabled;

  static const _layout = [
    [FirstPuttFeedback.fastLeft, FirstPuttFeedback.fast, FirstPuttFeedback.fastRight],
    [FirstPuttFeedback.left, FirstPuttFeedback.made, FirstPuttFeedback.right],
    [FirstPuttFeedback.slowLeft, FirstPuttFeedback.slow, FirstPuttFeedback.slowRight],
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'How did the first putt roll?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Column(
              children: List.generate(_layout.length, (rowIndex) {
                final row = _layout[rowIndex];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: List.generate(row.length, (colIndex) {
                      final feedback = row[colIndex];
                      if (feedback == FirstPuttFeedback.made) {
                        return Expanded(
                          child: Center(
                            child: InkWell(
                              onTap: enabled
                                  ? () => manager.recordFirstPutt(FirstPuttFeedback.made)
                                  : null,
                              borderRadius: BorderRadius.circular(36),
                              child: Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.green.shade600,
                                ),
                                alignment: Alignment.center,
                                child: const Icon(Icons.check, color: Colors.white, size: 32),
                              ),
                            ),
                          ),
                        );
                      }
                      final icon = _iconForFeedback(feedback);
                      final color = _colorForFeedback(feedback);
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              backgroundColor: color,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: enabled ? () => manager.recordFirstPutt(feedback) : null,
                            child: Icon(icon, color: Colors.black87),
                          ),
                        ),
                      );
                    }),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _iconForFeedback(FirstPuttFeedback feedback) {
    switch (feedback) {
      case FirstPuttFeedback.fastLeft:
        return Icons.north_west;
      case FirstPuttFeedback.fast:
        return Icons.north;
      case FirstPuttFeedback.fastRight:
        return Icons.north_east;
      case FirstPuttFeedback.left:
        return Icons.west;
      case FirstPuttFeedback.right:
        return Icons.east;
      case FirstPuttFeedback.slowLeft:
        return Icons.south_west;
      case FirstPuttFeedback.slow:
        return Icons.south;
      case FirstPuttFeedback.slowRight:
        return Icons.south_east;
      case FirstPuttFeedback.made:
        return Icons.check;
    }
  }

  static Color _colorForFeedback(FirstPuttFeedback feedback) {
    const orangeTint = Color(0xFFFFE5CC);
    const blueTint = Color(0xFFD6E6FF);
    switch (feedback) {
      case FirstPuttFeedback.fastLeft:
      case FirstPuttFeedback.fast:
      case FirstPuttFeedback.fastRight:
        return orangeTint;
      case FirstPuttFeedback.slowLeft:
      case FirstPuttFeedback.slow:
      case FirstPuttFeedback.slowRight:
        return blueTint;
      default:
        return Colors.grey.shade200;
    }
  }
}

class PuttPanelSwitcher extends StatelessWidget {
  const PuttPanelSwitcher({
    super.key,
    required this.manager,
    required this.scenario,
  });

  final SessionManager manager;
  final PuttScenario? scenario;

  @override
  Widget build(BuildContext context) {
    final showSecond = manager.waitingForSecondPutt;
    final enabled = scenario != null && !showSecond;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: showSecond
          ? SecondPuttPanel(
              key: const ValueKey('second'),
              manager: manager,
            )
          : FirstPuttPanel(
              key: const ValueKey('first'),
              manager: manager,
              enabled: enabled,
            ),
    );
  }
}

class SecondPuttPanel extends StatelessWidget {
  const SecondPuttPanel({super.key, required this.manager});

  final SessionManager manager;

  @override
  Widget build(BuildContext context) {
    final selected = manager.selectedSecondDistance;
    final requireChoice =
        selected != null && selected != SecondPuttDistance.tapIn && manager.waitingForSecondPutt;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Second putt leave distance',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: SecondPuttDistance.values.map((distance) {
                return ChoiceChip(
                  label: Text(distance.label),
                  selected: selected == distance,
                  onSelected: manager.waitingForSecondPutt
                      ? (value) {
                          if (value) {
                            manager.chooseSecondPuttDistance(distance);
                          }
                        }
                      : null,
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            const Text('Tap-in automatically records the second putt as made.'),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton(
                  onPressed: requireChoice ? () => manager.submitSecondPutt(made: true) : null,
                  child: const Text('Made'),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: requireChoice ? () => manager.submitSecondPutt(made: false) : null,
                  child: const Text('Missed'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class StatsOverviewCard extends StatelessWidget {
  const StatsOverviewCard({super.key, this.session});

  final PuttingSession? session;

  @override
  Widget build(BuildContext context) {
    if (session != null) {
      return _StatsGrid(stats: session!.stats, title: 'Current round stats');
    }

    final manager = context.watch<SessionManager>();
    return FutureBuilder<SessionStats>(
      future: manager.fetchAverageStats(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator.adaptive()),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Unable to load average stats.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          );
        }

        return _StatsGrid(stats: snapshot.data!, title: 'Average stats');
      },
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats, required this.title});

  final SessionStats stats;
  final String title;

  @override
  Widget build(BuildContext context) {
    String percent(double value) => '${(value * 100).toStringAsFixed(0)}%';
    final metrics = [
      _SummaryMetric('Sessions', '${stats.holesLogged}'),
      _SummaryMetric('Avg putts', '${stats.totalPutts}'),
      _SummaryMetric('1 putt %', percent(stats.firstPuttMakeRate)),
      _SummaryMetric('2 putt %', percent(stats.twoPuttRate)),
      _SummaryMetric('3 putt %', percent(stats.threePlusRate)),
      _SummaryMetric('Avg 2nd leave', '${stats.averageSecondLeave.toStringAsFixed(1)} ft'),
    ];

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 1.6,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: metrics
                  .map(
                    (metric) => Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            metric.value,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            metric.label.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryMetric {
  _SummaryMetric(this.label, this.value);

  final String label;
  final String value;
}

class _ScenarioChips extends StatelessWidget {
  const _ScenarioChips({required this.scenario, required this.includeSlope});

  final PuttScenario scenario;
  final bool includeSlope;

  @override
  Widget build(BuildContext context) {
    final chips = [
      _ChipData('Distance', '${scenario.distanceFeet} ft', Icons.straighten),
      _ChipData('Lie', scenario.lie.label, Icons.terrain),
      _ChipData('Break', scenario.breakType.label, Icons.compare_arrows),
      _ChipData(
        'Slope %',
        (!includeSlope ||
                scenario.breakType == BreakType.straight ||
                scenario.slopePercent == null)
            ? '—'
            : '${scenario.slopePercent!.toStringAsFixed(1)}%',
        Icons.trending_up,
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: chips
            .map(
              (chip) => Container(
                width: 130,
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(chip.icon, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          chip.label.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      chip.value,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ChipData {
  _ChipData(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;
}

class AverageSgBreakdownCard extends StatelessWidget {
  const AverageSgBreakdownCard({super.key, required this.session});

  final PuttingSession? session;

  @override
  Widget build(BuildContext context) {
    if (session != null) {
      final summary = RoundSummary.fromSession(session!);
      final data = _sgByDistance(summary.strokeBreakdown);
      final maxAbs =
          data.values.fold<double>(0, (prev, element) => element.abs() > prev ? element.abs() : prev);
      final combinedMax = math.max(maxAbs, summary.strokesGained.abs());
      final safeMax = combinedMax == 0 ? 1.0 : combinedMax;
      return _SgCard(
        title: 'Current round strokes gained',
        data: data,
        overallSg: summary.strokesGained,
        maxAbs: safeMax,
      );
    }

    final manager = context.watch<SessionManager>();
    return FutureBuilder<_AverageSgPayload>(
      future: _loadAverageData(manager),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator.adaptive()),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No strokes gained data yet.'),
            ),
          );
        }

        final payload = snapshot.data!;
        if (payload.byDistance.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No strokes gained data yet.'),
            ),
          );
        }

        final data = payload.byDistance;
        final maxAbs =
            data.values.fold<double>(0, (prev, element) => element.abs() > prev ? element.abs() : prev);
        final combinedMax = math.max(maxAbs, payload.stats.averageStrokesGained.abs());
        final safeMax = combinedMax == 0 ? 1.0 : combinedMax;
        return _SgCard(
          title: 'Average strokes gained',
          data: data,
          overallSg: payload.stats.averageStrokesGained,
          maxAbs: safeMax,
        );
      },
    );
  }

  Future<_AverageSgPayload> _loadAverageData(SessionManager manager) async {
    final byDistance = await manager.fetchAverageSgByDistance();
    final stats = await manager.fetchAverageStats();
    return _AverageSgPayload(byDistance: byDistance, stats: stats);
  }

  Map<String, double> _sgByDistance(List<PuttStrokeSummary> strokes) {
    final buckets = {
      for (final label in _sgBucketOrder) label: 0.0,
    };

    for (final summary in strokes) {
      final bucket = _bucketForDistance(summary.distanceFeet);
      buckets[bucket] = (buckets[bucket] ?? 0) + summary.strokesGained;
    }
    return buckets;
  }

  String _bucketForDistance(double distance) {
    if (distance <= 3) return '0-3 ft';
    if (distance <= 6) return '4-6 ft';
    if (distance <= 9) return '7-9 ft';
    if (distance <= 15) return '11-15 ft';
    if (distance <= 20) return '16-20 ft';
    if (distance <= 25) return '21-25 ft';
    if (distance <= 30) return '26-30 ft';
    if (distance <= 35) return '31-35 ft';
    if (distance <= 40) return '36-40 ft';
    return '>40 ft';
  }
}

class _AverageSgPayload {
  _AverageSgPayload({required this.byDistance, required this.stats});

  final Map<String, double> byDistance;
  final SessionStats stats;
}

const List<String> _sgBucketOrder = [
  '0-3 ft',
  '4-6 ft',
  '7-9 ft',
  '11-15 ft',
  '16-20 ft',
  '21-25 ft',
  '26-30 ft',
  '31-35 ft',
  '36-40 ft',
  '>40 ft',
];

class _SgCard extends StatelessWidget {
  const _SgCard({
    required this.title,
    required this.data,
    required this.overallSg,
    required this.maxAbs,
  });

  final String title;
  final Map<String, double> data;
  final double overallSg;
  final double maxAbs;

  @override
  Widget build(BuildContext context) {
    final ordered = {
      for (final label in _sgBucketOrder) label: data[label] ?? 0,
    };

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total strokes gained',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Text(
                        _formatSgValue(overallSg),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 12,
                    child: _ZeroCenteredBar(value: overallSg, maxAbs: maxAbs),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...ordered.entries.map(
              (entry) => _SgRow(
                label: entry.key,
                value: entry.value,
                maxAbs: maxAbs,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SgRow extends StatelessWidget {
  const _SgRow({
    required this.label,
    required this.value,
    required this.maxAbs,
  });

  final String label;
  final double value;
  final double maxAbs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 8,
              child: _ZeroCenteredBar(value: value, maxAbs: maxAbs),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 56,
            child: Text(
              _formatSgValue(value),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontFeatures: [ui.FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatSgValue(double value) {
  final normalized = value.abs() < 0.005 ? 0.0 : value;
  final text = normalized.toStringAsFixed(2);
  return normalized > 0 ? '+$text' : text;
}

class _ZeroCenteredBar extends StatelessWidget {
  const _ZeroCenteredBar({required this.value, required this.maxAbs});

  final double value;
  final double maxAbs;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ZeroCenteredBarPainter(value: value, maxAbs: maxAbs),
    );
  }
}

class _ZeroCenteredBarPainter extends CustomPainter {
  _ZeroCenteredBarPainter({required this.value, required this.maxAbs});

  final double value;
  final double maxAbs;

  @override
  void paint(Canvas canvas, Size size) {
    final basePaint = Paint()..color = Colors.grey.shade300;
    final radius = Radius.circular(size.height / 2);
    final rect = RRect.fromLTRBR(0, 0, size.width, size.height, radius);
    canvas.drawRRect(rect, basePaint);
    final centerX = size.width / 2;
    final centerPaint = Paint()
      ..color = Colors.grey.shade500
      ..strokeWidth = 1;
    canvas.drawLine(Offset(centerX, 0), Offset(centerX, size.height), centerPaint);

    if (maxAbs <= 0 || value == 0) {
      final zeroPaint = Paint()..color = Colors.grey.shade600;
      canvas.drawCircle(Offset(centerX, size.height / 2), size.height / 4, zeroPaint);
      return;
    }

    double fraction = value / maxAbs;
    fraction = fraction.clamp(-1.0, 1.0);
    final fillWidth = centerX * fraction.abs();
    final fillRect = fraction >= 0
        ? Rect.fromLTRB(centerX, 0, centerX + fillWidth, size.height)
        : Rect.fromLTRB(centerX - fillWidth, 0, centerX, size.height);
    final fillPaint = Paint()
      ..color = fraction >= 0 ? Colors.green.shade600 : Colors.red.shade600;
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        fillRect,
        topLeft: radius,
        topRight: radius,
        bottomLeft: radius,
        bottomRight: radius,
      ),
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ZeroCenteredBarPainter oldDelegate) {
    return oldDelegate.value != value || oldDelegate.maxAbs != maxAbs;
  }
}
