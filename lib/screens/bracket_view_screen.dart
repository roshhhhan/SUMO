import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import '../models/bracket.dart';
import '../services/api.dart';

class BracketViewScreen extends StatefulWidget {
  final Bracket bracket;
  const BracketViewScreen({super.key, required this.bracket});

  @override
  State<BracketViewScreen> createState() => _BracketViewScreenState();
}

class _BracketViewScreenState extends State<BracketViewScreen> {
  late Bracket _bracket;
  bool _saving = false;
  final Map<String, _ScoreDraft> _draftScores = {};

  @override
  void initState() {
    super.initState();
    _bracket = widget.bracket;
    developer.log(
      'Bracket loaded',
      name: 'BracketViewScreen',
      error: {
        'id': _bracket.id,
        'type': _bracket.type,
        'teams': _bracket.teams?.length,
        'rounds': _bracket.rounds?.length,
      },
    );
  }

  static int _clampPoint(int v) => v.clamp(0, 2);

  String _key(int round, int idx) => '$round:$idx';

  _ScoreDraft _draftFor(int round, int idx, MatchInfo match) {
    final k = _key(round, idx);
    final existing = _draftScores[k];
    if (existing != null) return existing;
    final draft = _ScoreDraft(_clampPoint(match.scoreA ?? 0), _clampPoint(match.scoreB ?? 0));
    _draftScores[k] = draft;
    return draft;
  }

  Future<void> _update(int round, int index, int scoreA, int scoreB) async {
    if (_bracket.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bracket ID not loaded')),
      );
      return;
    }

    final sa = _clampPoint(scoreA);
    final sb = _clampPoint(scoreB);
    if (sa == 2 && sb == 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid score: both sides cannot be 2')),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    setState(() => _saving = true);
    try {
      final updated = await ApiService().updateMatch(_bracket.id!, round, index, sa, sb);
      if (!mounted) return;
      setState(() {
        _bracket = updated;
        _draftScores[_key(round, index)] = _ScoreDraft(sa, sb);
      });
      messenger.showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Yuhkoh score saved!'),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _resolveTie(int round, int idx, MatchInfo match) async {
    final draft = _draftFor(round, idx, match);
    if (draft.a == 2 || draft.b == 2) return;
    if (draft.a != draft.b) return;

    final aName = match.teamA ?? 'Team A';
    final bName = match.teamB ?? 'Team B';

    final winner = await showDialog<_TieWinner>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Resolve tie'),
          content: const Text('Pick the winner for this match. This will award 2 Yuhkoh points to the winner.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, _TieWinner.a),
              child: Text(aName),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, _TieWinner.b),
              child: Text(bName),
            ),
          ],
        );
      },
    );

    if (winner == null) return;
    if (winner == _TieWinner.a) {
      setState(() => _draftScores[_key(round, idx)] = _ScoreDraft(2, 0));
      await _update(round, idx, 2, 0);
    } else {
      setState(() => _draftScores[_key(round, idx)] = _ScoreDraft(0, 2));
      await _update(round, idx, 0, 2);
    }
  }

  Widget _buildMatch(int round, int idx, MatchInfo match) {
    final scheme = Theme.of(context).colorScheme;
    final draft = _draftFor(round, idx, match);
    final aName = match.teamA ?? 'TBD';
    final bName = match.teamB ?? 'TBD';
    final decided = draft.a == 2 || draft.b == 2;
    final hasTie = (draft.a == draft.b) && !decided;

    final String? winner = decided
        ? (draft.a == 2 ? match.teamA : match.teamB)
        : null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: SizedBox(
        width: 300,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Match ${idx + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: scheme.onPrimaryContainer,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'First to 2 Yuhkoh (best-of-3)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
              if (winner != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.emoji_events, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Winner: $winner',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),

              _TeamYuhkohRow(
                name: aName,
                points: draft.a,
                disabled: _saving,
                onDecrement: () {
                  setState(() => draft.a = _clampPoint(draft.a - 1));
                },
                onIncrement: decided
                    ? null
                    : () {
                        setState(() => draft.a = _clampPoint(draft.a + 1));
                      },
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  'VS',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                ),
              ),
              const SizedBox(height: 10),
              _TeamYuhkohRow(
                name: bName,
                points: draft.b,
                disabled: _saving,
                onDecrement: () {
                  setState(() => draft.b = _clampPoint(draft.b - 1));
                },
                onIncrement: decided
                    ? null
                    : () {
                        setState(() => draft.b = _clampPoint(draft.b + 1));
                      },
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  if (hasTie)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _saving ? null : () => _resolveTie(round, idx, match),
                        icon: const Icon(Icons.gavel),
                        label: const Text('Resolve tie'),
                      ),
                    ),
                  if (hasTie) const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _saving ? null : () => _update(round, idx, draft.a, draft.b),
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save, size: 18),
                      label: Text(_saving ? 'Saving...' : 'Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_bracket.rounds == null || _bracket.rounds!.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Tournament #${_bracket.id ?? 'Unknown'}'),
          elevation: 0,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              const Text(
                'No rounds available for this tournament',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Text(
                'This might be a data loading issue.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Tournament #${_bracket.id}'),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.home),
            tooltip: 'Back to Home',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.25),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: Column(
          children: [
            // Tournament info header
            Container(
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.surface,
              child: Row(
                children: [
                  Icon(
                    Icons.emoji_events,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Type: ${_bracket.type == 'single' ? 'Single Elimination' : 'Double Elimination'}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_bracket.teams?.length ?? 0} Teams • ${_bracket.rounds!.length} Rounds',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Live',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bracket rounds
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: List.generate(_bracket.rounds!.length, (r) {
                        final roundMatches = _bracket.rounds![r];
                        return Container(
                          width: 320,
                          margin: const EdgeInsets.only(right: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Round header
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.flag,
                                      color: Theme.of(context).colorScheme.onPrimary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Round ${r + 1}',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${roundMatches.length} matches',
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onPrimary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Matches
                              ...roundMatches.map((match) {
                                final matchIndex = roundMatches.indexOf(match);
                                return _buildMatch(r, matchIndex, match);
                              }),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreDraft {
  int a;
  int b;
  _ScoreDraft(this.a, this.b);
}

enum _TieWinner { a, b }

class _TeamYuhkohRow extends StatelessWidget {
  final String name;
  final int points;
  final bool disabled;
  final VoidCallback onDecrement;
  final VoidCallback? onIncrement;

  const _TeamYuhkohRow({
    required this.name,
    required this.points,
    required this.disabled,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filledTonal(
            onPressed: disabled ? null : onDecrement,
            icon: const Icon(Icons.remove),
            tooltip: 'Decrease',
          ),
          const SizedBox(width: 8),
          Container(
            width: 44,
            alignment: Alignment.center,
            child: Text(
              '$points',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: (disabled || onIncrement == null || points >= 2) ? null : onIncrement,
            icon: const Icon(Icons.add),
            tooltip: 'Add Yuhkoh',
          ),
        ],
      ),
    );
  }
}
