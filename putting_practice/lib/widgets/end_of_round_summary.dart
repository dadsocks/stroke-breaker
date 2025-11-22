import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/hole_result.dart';
import '../models/putting_session.dart';
import '../models/round_summary.dart';
import '../models/session_stats.dart';
import 'putt_dispersion_chart.dart';

class EndOfRoundSummarySheet extends StatelessWidget {
  const EndOfRoundSummarySheet({
    super.key,
    required this.session,
    required this.summary,
    required this.onStartNewSession,
  });

  final PuttingSession session;
  final RoundSummary summary;
  final Future<void> Function(int holeCount) onStartNewSession;

  SessionStats get stats => summary.stats;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Material(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            clipBehavior: Clip.antiAlias,
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'End of Round Summary',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                _kpiSection(),
                const SizedBox(height: 16),
                _missPatternSection(),
                const SizedBox(height: 16),
                _secondLeaveSection(),
                const SizedBox(height: 16),
                _bucketSection(),
                if (summary.dispersionResults.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _SummaryCard(
                    title: 'Putt dispersion',
                    child: PuttDispersionChart(results: summary.dispersionResults),
                  ),
                ],
                if (summary.strokeBreakdown.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _SummaryCard(
                    title: 'Stroke breakdown',
                    child: _StrokeBreakdownTable(strokes: summary.strokeBreakdown),
                  ),
                ],
                const SizedBox(height: 24),
                _buttonRow(context),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _kpiSection() {
    String percent(double value) => '${(value * 100).toStringAsFixed(0)}%';
    final avgLeave = '${stats.averageSecondLeave.toStringAsFixed(1)} ft';
    final sgValue = summary.strokesGained;
    final sgText = sgValue >= 0 ? '+${sgValue.toStringAsFixed(2)}' : sgValue.toStringAsFixed(2);
    final sgColor = sgValue >= 0 ? Colors.green.shade700 : Colors.red.shade700;

    return _SummaryCard(
      title: 'Key metrics',
      child: Wrap(
        spacing: 24,
        runSpacing: 12,
        children: [
          _StatTile(label: 'Holes logged', value: '${stats.holesLogged}/${session.holeCount}'),
          _StatTile(label: 'Total putts', value: '${stats.totalPutts}'),
          _StatTile(label: '1st putt makes', value: percent(stats.firstPuttMakeRate)),
          _StatTile(label: '2-putt rate', value: percent(stats.twoPuttRate)),
          _StatTile(label: '3+ putt rate', value: percent(stats.threePlusRate)),
          _StatTile(label: 'Avg 2nd leave', value: avgLeave),
          _StatTile(
            label: 'Strokes Gained Putting vs PGA Tour',
            value: sgText,
            valueColor: sgColor,
          ),
        ],
      ),
    );
  }

  Widget _missPatternSection() {
    return _SummaryCard(
      title: 'First putt miss patterns',
      child: Column(
        children: const [
          [
            FirstPuttFeedback.fastLeft,
            FirstPuttFeedback.fast,
            FirstPuttFeedback.fastRight,
          ],
          [
            FirstPuttFeedback.left,
            null,
            FirstPuttFeedback.right,
          ],
          [
            FirstPuttFeedback.slowLeft,
            FirstPuttFeedback.slow,
            FirstPuttFeedback.slowRight,
          ],
        ].map((row) => _MissPatternRow(row: row)).toList(),
      ),
    );
  }

  Widget _secondLeaveSection() {
    return _SummaryCard(
      title: 'Second-putt leave distribution',
      child: Row(
        children: summary.secondLeaveDistribution.entries
            .map(
              (entry) => Expanded(
                child: _StatTile(label: entry.key.label, value: '${entry.value}'),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _bucketSection() {
    return _SummaryCard(
      title: 'First putt make % by distance',
      child: Column(
        children: summary.bucketStats
            .map(
              (bucket) => ListTile(
                dense: true,
                title: Text(bucket.label),
                subtitle: Text('${bucket.attempts} attempts'),
                trailing: Text('${(bucket.makeRate * 100).toStringAsFixed(0)}%'),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buttonRow(BuildContext context) {
    return Column(
      children: [
        FilledButton.icon(
          icon: const Icon(Icons.download),
          label: const Text('Export CSV'),
          onPressed: () {
            final csv = RoundSummary.toCsv(session);
            Share.share(csv, subject: 'Putting Practice Round');
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonal(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await onStartNewSession(9);
                },
                child: const Text('New 9'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.tonal(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await onStartNewSession(18);
                },
                child: const Text('New 18'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleLarge?.copyWith(color: valueColor);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: style,
        ),
        Text(label),
      ],
    );
  }
}

class _MissPatternRow extends StatelessWidget {
  const _MissPatternRow({required this.row});

  final List<FirstPuttFeedback?> row;

  @override
  Widget build(BuildContext context) {
    final summaryWidget = context.findAncestorWidgetOfExactType<EndOfRoundSummarySheet>()!;
    final counts = summaryWidget.summary.missCounts;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: row.map((feedback) {
          if (feedback == null) {
            return const Expanded(child: SizedBox());
          }
          final count = counts[feedback] ?? 0;
          return Expanded(
            child: Card(
              color: Colors.grey.shade100,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    Text(
                      feedback.label,
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$count',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _StrokeBreakdownTable extends StatelessWidget {
  const _StrokeBreakdownTable({required this.strokes});

  final List<PuttStrokeSummary> strokes;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: const [
            Expanded(child: Text('Hole', style: TextStyle(fontWeight: FontWeight.bold))),
            Expanded(child: Text('Distance', style: TextStyle(fontWeight: FontWeight.bold))),
            Expanded(child: Text('Strokes Gained', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        const Divider(),
        ...strokes.map(
          (stroke) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(child: Text('${stroke.holeNumber}')),
                Expanded(child: Text('${stroke.distanceFeet.toStringAsFixed(1)} ft')),
                Expanded(
                  child: Text(
                    stroke.strokesGained >= 0
                        ? '+${stroke.strokesGained.toStringAsFixed(2)}'
                        : stroke.strokesGained.toStringAsFixed(2),
                    style: TextStyle(
                      color: stroke.strokesGained >= 0
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
