import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/putting_session.dart';
import '../models/round_summary.dart';
import '../services/session_manager.dart';
import '../widgets/end_of_round_summary.dart';

class SessionHistoryScreen extends StatefulWidget {
  const SessionHistoryScreen({super.key});

  @override
  State<SessionHistoryScreen> createState() => _SessionHistoryScreenState();
}

class _SessionHistoryScreenState extends State<SessionHistoryScreen> {
  late Future<List<PuttingSession>> _sessionsFuture;

  @override
  void initState() {
    super.initState();
    _sessionsFuture = _loadSessions();
  }

  Future<List<PuttingSession>> _loadSessions() {
    final manager = context.read<SessionManager>();
    return manager.fetchPastSessions();
  }

  Future<void> _refresh() async {
    setState(() {
      _sessionsFuture = _loadSessions();
    });
    await _sessionsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session History'),
      ),
      body: FutureBuilder<List<PuttingSession>>(
        future: _sessionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Unable to load sessions.\n${snapshot.error}'),
            );
          }

          final sessions = snapshot.data;
          if (sessions == null || sessions.isEmpty) {
            return const Center(
              child: Text('No sessions found yet.'),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              itemCount: sessions.length,
              separatorBuilder: (context, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final session = sessions[index];
                return ListTile(
                  title: Text(_formatDate(session.startedAt)),
                  subtitle: Text('${session.holeCount} holes • ${session.stats.totalPutts} putts'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showSummary(session),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _showSummary(PuttingSession session) async {
    final summary = RoundSummary.fromSession(session);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EndOfRoundSummarySheet(
        session: session,
        summary: summary,
        onStartNewSession: (holes) async {
          Navigator.of(context).pop();
          final manager = context.read<SessionManager>();
          await manager.startNewSession(holes);
          if (mounted) Navigator.of(context).pop();
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    final month = _twoDigits(date.month);
    final day = _twoDigits(date.day);
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = _twoDigits(date.minute);
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$month/$day/${date.year} • $hour:$minute $period';
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');
}
