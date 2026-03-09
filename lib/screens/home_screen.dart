import 'package:flutter/material.dart';
import '../services/api.dart';
import 'bracket_view_screen.dart';
import 'create_bracket_screen.dart';
import 'tournament_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _recent = [];

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final tournaments = await ApiService().getTournaments();
      final formatted = tournaments.map((t) {
        return {
          'id': t['id'],
          'name': t['name'],
          'teams': t['teams'] ?? 0,
          'type': t['type'] ?? 'single',
          'status': t['status'] ?? 'in_progress',
          'created': DateTime.tryParse((t['created'] ?? '').toString()),
        };
      }).toList();

      setState(() {
        _recent = formatted.take(5).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadRecent,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.sports_martial_arts,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sumo Tournament Manager',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.2,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Create brackets, score matches, and track winners.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _loadRecent,
                        tooltip: 'Refresh',
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const CreateBracketScreen()),
                            );
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('New Tournament'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const TournamentListScreen()),
                          );
                        },
                        icon: const Icon(Icons.list_alt),
                        label: const Text('All'),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                  child: _DashboardSectionHeader(
                    title: 'Recent tournaments',
                    trailing: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const TournamentListScreen()),
                        );
                      },
                      child: const Text('See all'),
                    ),
                  ),
                ),
              ),
              if (_loading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (_error != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Could not load tournaments',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _error!,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton(
                                onPressed: _loadRecent,
                                child: const Text('Try again'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              else if (_recent.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            Icon(Icons.emoji_events_outlined, color: scheme.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'No tournaments yet. Create one to get started.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  sliver: SliverList.separated(
                    itemBuilder: (context, index) {
                      final t = _recent[index];
                      return _TournamentTile(
                        name: (t['name'] ?? 'Unnamed').toString(),
                        status: (t['status'] ?? 'in_progress').toString(),
                        teams: (t['teams'] as int?) ?? 0,
                        type: (t['type'] ?? 'single').toString(),
                        onTap: () async {
                          final navigator = Navigator.of(context);
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            final bracket = await ApiService().getBracket(t['id'] as int);
                            if (!mounted) return;
                            navigator.push(
                              MaterialPageRoute(
                                builder: (_) => BracketViewScreen(bracket: bracket),
                              ),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            messenger.showSnackBar(
                              SnackBar(content: Text('Failed to open tournament: $e')),
                            );
                          }
                        },
                      );
                    },
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemCount: _recent.length,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardSectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const _DashboardSectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _TournamentTile extends StatelessWidget {
  final String name;
  final String status;
  final int teams;
  final String type;
  final VoidCallback onTap;

  const _TournamentTile({
    required this.name,
    required this.status,
    required this.teams,
    required this.type,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (statusLabel, statusIcon) = switch (status) {
      'completed' => ('Completed', Icons.check_circle),
      'upcoming' => ('Upcoming', Icons.schedule),
      _ => ('In Progress', Icons.play_circle),
    };

    final typeLabel = type == 'double' ? 'Double Elim' : 'Single Elim';

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.emoji_events,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.group, size: 16, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          '$teams teams',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.call_split, size: 16, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          typeLabel,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 16, color: scheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      statusLabel,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}