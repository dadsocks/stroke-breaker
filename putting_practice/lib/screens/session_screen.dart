import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/hole_result.dart';
import '../models/putt_scenario.dart';
import '../models/putting_session.dart';
import '../models/round_summary.dart';
import '../models/session_stats.dart';
import '../services/auth_service.dart';
import '../services/session_manager.dart';
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
          const LiveStatsCard(),
          const SizedBox(height: 16),
          const AverageSgBreakdownCard(),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Start a new session',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text('Choose 9 or 18 holes. Progress is stored locally.'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: [9, 18].map((count) {
                return ChoiceChip(
                  label: Text('$count holes'),
                  selected: selectedHoleCount == count,
                  onSelected: (value) {
                    if (value) onHoleCountSelected(count);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: starting ? null : onStartSession,
              icon: const Icon(Icons.play_arrow),
              label: Text(starting ? 'Starting...' : 'New Session'),
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

    return Column(
      children: [
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Hole $nextHole / ${session.holeCount}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (session.isComplete)
                  Chip(
                    backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
                    label: const Text('Complete'),
                  ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Include slope %'),
              subtitle: const Text('When off, slope always shows “—”'),
              value: manager.includeSlope,
              onChanged: session.isComplete
                  ? null
                  : (value) {
                      manager.toggleIncludeSlope(value);
                    },
            ),
            const Divider(),
            if (scenario == null)
              const Text('Session finished. Start another to continue.')
            else
              _ScenarioDetails(
                scenario: scenario!,
                includeSlope: manager.includeSlope,
              ),
          ],
        ),
      ),
    );
  }
}

class _ScenarioDetails extends StatelessWidget {
  const _ScenarioDetails({
    required this.scenario,
    required this.includeSlope,
  });

  final PuttScenario scenario;
  final bool includeSlope;

  @override
  Widget build(BuildContext context) {
    final rows = [
      _Detail(label: 'Distance', value: '${scenario.distanceFeet} ft'),
      _Detail(label: 'Lie', value: scenario.lie.label),
      _Detail(label: 'Break', value: scenario.breakType.label),
      _Detail(
        label: 'Slope %',
        value: (!includeSlope ||
                scenario.breakType == BreakType.straight ||
                scenario.slopePercent == null)
            ? '—'
            : '${scenario.slopePercent!.toStringAsFixed(1)}%',
      ),
    ];

    return Column(
      children: rows
          .map(
            (row) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(row.label),
                  Text(
                    row.value,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          )
          .toList(),
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

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'First putt result',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Column(
              children: [
                _FirstPuttRow(
                  manager: manager,
                  enabled: enabled,
                  row: const [
                    FirstPuttFeedback.fastLeft,
                    FirstPuttFeedback.fast,
                    FirstPuttFeedback.fastRight,
                  ],
                ),
                _FirstPuttRow(
                  manager: manager,
                  enabled: enabled,
                  row: const [
                    FirstPuttFeedback.left,
                    FirstPuttFeedback.made,
                    FirstPuttFeedback.right,
                  ],
                ),
                _FirstPuttRow(
                  manager: manager,
                  enabled: enabled,
                  row: const [
                    FirstPuttFeedback.slowLeft,
                    FirstPuttFeedback.slow,
                    FirstPuttFeedback.slowRight,
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FirstPuttRow extends StatelessWidget {
  const _FirstPuttRow({
    required this.manager,
    required this.enabled,
    required this.row,
  });

  final SessionManager manager;
  final bool enabled;
  final List<FirstPuttFeedback> row;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: row.map((feedback) {
          final onPressed = enabled
              ? () {
                  manager.recordFirstPutt(feedback);
                }
              : null;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: feedback == FirstPuttFeedback.made
                  ? FilledButton(
                      onPressed: onPressed,
                      child: Text(feedback.label),
                    )
                  : FilledButton.tonal(
                      onPressed: onPressed,
                      child: Text(feedback.label),
                    ),
            ),
          );
        }).toList(),
      ),
    );
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

class LiveStatsCard extends StatelessWidget {
  const LiveStatsCard({super.key});

  @override
  Widget build(BuildContext context) {
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

        final stats = snapshot.data!;
        String percent(double value) => '${(value * 100).toStringAsFixed(0)}%';
        final avgLeave = '${stats.averageSecondLeave.toStringAsFixed(1)} ft';

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Average stats',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 24,
                  runSpacing: 12,
                  children: [
                    _StatTile(label: 'Sessions', value: '${stats.holesLogged}'),
                    _StatTile(label: 'Avg putts/round', value: '${stats.totalPutts}'),
                    _StatTile(label: '1st putt makes', value: percent(stats.firstPuttMakeRate)),
                    _StatTile(label: '2-putt rate', value: percent(stats.twoPuttRate)),
                    _StatTile(label: '3+ putt rate', value: percent(stats.threePlusRate)),
                    _StatTile(label: 'Avg 2nd leave', value: avgLeave),
                    _StatTile(
                      label: 'Avg strokes gained',
                      value: stats.averageStrokesGained >= 0
                          ? '+${stats.averageStrokesGained.toStringAsFixed(2)}'
                          : stats.averageStrokesGained.toStringAsFixed(2),
                      valueColor:
                          stats.averageStrokesGained >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Detail {
  const _Detail({required this.label, required this.value});
  final String label;
  final String value;
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(color: valueColor),
        ),
        Text(label),
      ],
    );
  }
}

class AverageSgBreakdownCard extends StatelessWidget {
  const AverageSgBreakdownCard({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<SessionManager>();
    return FutureBuilder<Map<String, double>>(
      future: manager.fetchAverageSgByDistance(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator.adaptive()),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No strokes gained data yet.'),
            ),
          );
        }

        final data = snapshot.data!;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Average strokes gained by distance',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                ...data.entries.map(
                  (entry) {
                    final value = entry.value;
                    final text =
                        value >= 0 ? '+${value.toStringAsFixed(2)}' : value.toStringAsFixed(2);
                    final color = value >= 0 ? Colors.green.shade700 : Colors.red.shade700;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(child: Text(entry.key)),
                          Text(
                            text,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(color: color),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
