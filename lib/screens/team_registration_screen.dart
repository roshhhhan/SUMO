import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import '../services/api.dart';

class TeamRegistrationScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? initialTeams;
  const TeamRegistrationScreen({super.key, this.initialTeams});

  @override
  State<TeamRegistrationScreen> createState() => _TeamRegistrationScreenState();
}

class _TeamRegistrationScreenState extends State<TeamRegistrationScreen> {
  late List<Map<String, dynamic>> _teams;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _schoolController = TextEditingController();
  final List<TextEditingController> _memberControllers = [];

  @override
  void initState() {
    super.initState();
    _teams = widget.initialTeams != null ? List.from(widget.initialTeams!) : [];
    _memberControllers.add(TextEditingController());
    // Load teams from server so persisted teams show when opening the screen
    ApiService().getTeams().then((list) {
      setState(() {
        // prefer server list; keep initialTeams as fallback
        _teams = list;
      });
    }).catchError((e) {
      // ignore errors here; UI will still allow local registration
      developer.log('Failed to load teams: $e');
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _schoolController.dispose();
    for (var c in _memberControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _registerTeam() async {
    final name = _nameController.text.trim();
    final school = _schoolController.text.trim();
    final members = _memberControllers.map((c) => c.text.trim()).where((m) => m.isNotEmpty).toList();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Team name required')));
      return;
    }
    try {
      final created = await ApiService().registerTeam(name, school, members);
      setState(() {
        // insert created team (with id/created_at) so list reflects DB state
        _teams.insert(0, created);
        _nameController.clear();
        _schoolController.clear();
        for (var c in _memberControllers) {
          c.clear();
        }
        if (_memberControllers.length > 1) {
          _memberControllers.removeRange(1, _memberControllers.length);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Team registered and saved')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save team: $e')));
    }
  }

  void _removeTeam(int idx) {
    setState(() => _teams.removeAt(idx));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Team unregistered')));
  }

  void _save() {
    Navigator.pop(context, _teams);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Registration'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
        actions: [
          TextButton(
            onPressed: _save,
            child: Text('Save (${_teams.length})', style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Register New Team',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Team Name',
                        prefixIcon: Icon(Icons.group),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _schoolController,
                      decoration: const InputDecoration(
                        labelText: 'School',
                        prefixIcon: Icon(Icons.school),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Participants',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    ...List.generate(_memberControllers.length, (idx) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _memberControllers[idx],
                                decoration: InputDecoration(
                                  labelText: 'Member ${idx + 1}',
                                  prefixIcon: const Icon(Icons.person),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: _memberControllers.length > 1
                                  ? () => setState(() => _memberControllers.removeAt(idx))
                                  : null,
                            ),
                          ],
                        ),
                      );
                    }),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setState(() => _memberControllers.add(TextEditingController())),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Member'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _registerTeam,
                      icon: const Icon(Icons.add),
                      label: const Text('Register'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _teams.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.group_add, size: 64, color: Theme.of(context).colorScheme.outline),
                          const SizedBox(height: 16),
                          Text(
                            'No teams registered yet',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Register teams to use in tournaments',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                'Registered Teams (${_teams.length})',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Expanded(
                              child: ListView.separated(
                                itemCount: _teams.length,
                                separatorBuilder: (_, _) => const Divider(height: 1),
                                itemBuilder: (context, idx) {
                                  final team = _teams[idx];
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                      child: Text('${idx + 1}', style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer)),
                                    ),
                                    title: Text(team['name'] ?? ''),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if ((team['school'] ?? '').isNotEmpty)
                                          Text('School: ${team['school']}'),
                                        if ((team['members'] as List?)?.isNotEmpty ?? false)
                                          Text('Members: ${(team['members'] as List).join(', ')}'),
                                      ],
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () => _removeTeam(idx),
                                      tooltip: 'Unregister team',
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
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
