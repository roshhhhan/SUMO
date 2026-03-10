import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import '../services/api.dart';
import 'bracket_view_screen.dart';

class CreateBracketScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? initialTeams;
  const CreateBracketScreen({super.key, this.initialTeams});

  @override
  State<CreateBracketScreen> createState() => _CreateBracketScreenState();
}

class _CreateBracketScreenState extends State<CreateBracketScreen> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _type = 'single';
  int _teamCount = 4; // Default to 4 teams
  List<Map<String, TextEditingController>> _teamControllers = [];
  List<Map<String, dynamic>> _registeredTeams = [];
  List<dynamic> _selectedTeamIds = [];
  bool _creating = false;
  bool _testingConnection = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialTeams != null && [2, 4, 8, 16].contains(widget.initialTeams!.length)) {
      _teamCount = widget.initialTeams!.length;
      _teamControllers = widget.initialTeams!
          .map((team) => {
                'name': TextEditingController(text: team['name'] ?? ''),
                'school': TextEditingController(text: team['school'] ?? ''),
                'members': TextEditingController(text: (team['members'] is List && team['members'].isNotEmpty) ? (team['members'] as List).join(', ') : ''),
              })
          .toList();
    } else {
      _buildControllers();
    }
    _loadRegisteredTeams();
  }

  void _buildControllers() {
    _teamControllers = List.generate(_teamCount, (_) => {
      'name': TextEditingController(),
      'school': TextEditingController(),
      'members': TextEditingController(),
    });
    _selectedTeamIds = List<dynamic>.filled(_teamCount, null);
  }

  void _loadRegisteredTeams() async {
    try {
      final list = await ApiService().getTeams();
      setState(() {
        _registeredTeams = list;
        // ensure selected ids array matches current team count
        _selectedTeamIds = List<dynamic>.filled(_teamCount, null);
      });
    } catch (e) {
      // ignore load errors; user can still create custom teams
      print('Failed to load registered teams: $e');
    }
  }

  @override
  void dispose() {
    for (var team in _teamControllers) {
      team['name']?.dispose();
      team['school']?.dispose();
      team['members']?.dispose();
    }
    super.dispose();
  }

  void _testConnection() async {
    setState(() => _testingConnection = true);
    print('Testing connection to server...');
    try {
      await ApiService().getTournaments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('✓ Server connection successful!'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
      print('✓ Connection test passed');
    } catch (e) {
      print('✗ Connection test failed: $e');
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red),
                SizedBox(width: 8),
                Text('Connection Failed'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Error: $e'),
                const SizedBox(height: 16),
                const Text(
                  'Make sure:\n'
                  '• API server is running (from /server: dart run bin/server.dart)\n'
                  '• MySQL database is running (XAMPP)\n'
                  '• Network connection is available',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _testingConnection = false);
    }
  }

  void _create() async {
    // Capture tournament name from form
    _formKey.currentState?.save();
    
    if (_name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tournament name is required')),
      );
      return;
    }
    
    // Build teams payload directly from controllers, ensuring zero non-JSON-safe values
    List<Map<String, dynamic>> finalTeams = [];
    
    for (final team in _teamControllers) {
      String nameVal = '';
      String schoolVal = '';
      List<String> membersVal = [];

      // Extract name: must be a TextEditingController
      final nameCtrl = team['name'];
      if (nameCtrl is TextEditingController) {
        nameVal = nameCtrl.text.trim();
      }

      // Extract school: must be a TextEditingController
      final schoolCtrl = team['school'];
      if (schoolCtrl is TextEditingController) {
        schoolVal = schoolCtrl.text.trim();
      }

      // Extract members: must be a TextEditingController
      final membersCtrl = team['members'];
      if (membersCtrl is TextEditingController) {
        final raw = membersCtrl.text.trim();
        membersVal = raw.isEmpty ? [] : raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      }

      // Build final team object (guaranteed JSON-safe)
      finalTeams.add({
        'name': nameVal,
        'school': schoolVal,
        'members': membersVal,
      });
    }
    
    developer.log('Final teams payload: $finalTeams');
    developer.log('Final teams payload: $finalTeams');
    
    // Validate every team has a name
    for (var i = 0; i < finalTeams.length; i++) {
      if ((finalTeams[i]['name'] as String).isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Team ${i + 1} is missing a name')),
        );
        return;
      }
    }

    // Check team count is power of 2
    if (finalTeams.length & (finalTeams.length - 1) != 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Team count must be power of 2 (2,4,8,16), got ${finalTeams.length}'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _creating = true);
    try {
      print('Creating bracket: $_name with ${finalTeams.length} teams, type: $_type');
      final bracket = await ApiService().createBracket(_name, finalTeams, _type);
      if (mounted) {
        print('Bracket created successfully: ${bracket.id}');
        Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) => BracketViewScreen(bracket: bracket)));
      }
    } catch (e) {
      print('ERROR creating bracket: $e');
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red),
                SizedBox(width: 8),
                Text('Creation Failed'),
              ],
            ),
            content: Text(e.toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Tournament'),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.create,
                                color: Theme.of(context).colorScheme.primary,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Tournament Setup',
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Configure your sumo robot tournament bracket',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Tournament Name
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Tournament Name',
                      hintText: 'e.g., Spring Championship 2026',
                      prefixIcon: Icon(Icons.event),
                    ),
                    onSaved: (v) => _name = v ?? '',
                    validator: (v) => (v == null || v.isEmpty) ? 'Tournament name is required' : null,
                  ),
                  const SizedBox(height: 20),

                  // Elimination Type
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Elimination Type',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildEliminationOption(
                                  'Single',
                                  'single',
                                  'Winner stays, loser out',
                                  Icons.trending_up,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildEliminationOption(
                                  'Double',
                                  'double',
                                  'Losers bracket available',
                                  Icons.call_split,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Team Count
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Number of Teams',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [2, 4, 8, 16].map((count) {
                              return ChoiceChip(
                                label: Text('$count Teams'),
                                selected: _teamCount == count,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      _teamCount = count;
                                      _buildControllers();
                                    });
                                  }
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Team Info
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Team Info',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...List.generate(_teamControllers.length, (idx) {
                            final team = _teamControllers[idx];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Registered team selector
                                  DropdownButtonFormField<dynamic>(
                                    initialValue: _selectedTeamIds.length > idx ? _selectedTeamIds[idx] : null,
                                    decoration: const InputDecoration(
                                      labelText: 'Registered team (optional)',
                                      prefixIcon: Icon(Icons.check_box_outlined),
                                    ),
                                    items: [
                                      const DropdownMenuItem(value: null, child: Text('Custom / Select team')),
                                      ..._registeredTeams.map((t) => DropdownMenuItem(value: t['id'], child: Text(t['name'] ?? '')))
                                    ],
                                    onChanged: (val) {
                                      setState(() {
                                        if (_selectedTeamIds.length <= idx) {
                                          _selectedTeamIds = List<dynamic>.filled(_teamCount, null);
                                        }
                                        _selectedTeamIds[idx] = val;
                                        if (val != null) {
                                          // Find the registered team by ID (nullable)
                                          Map<String, dynamic>? selected;
                                          try {
                                            final found = _registeredTeams.firstWhere((r) => r['id'] == val);
                                            selected = found;
                                          } catch (_) {
                                            selected = null;
                                          }
                                          if (selected != null) {
                                            // Safely extract and convert values
                                            String nameStr = '';
                                            String schoolStr = '';
                                            String membersStr = '';

                                            final rawName = selected['name'];
                                            final rawSchool = selected['school'];
                                            final rawMembers = selected['members'];

                                            if (rawName is String) {
                                              nameStr = rawName;
                                            } else if (rawName != null) nameStr = rawName.toString();

                                            if (rawSchool is String) {
                                              schoolStr = rawSchool;
                                            } else if (rawSchool != null) schoolStr = rawSchool.toString();

                                            if (rawMembers is List) {
                                              membersStr = rawMembers.map((m) => m is String ? m : (m?.toString() ?? '')).where((m) => m.isNotEmpty).join(', ');
                                            } else if (rawMembers != null) {
                                              membersStr = rawMembers.toString();
                                            }

                                            team['name']?.text = nameStr;
                                            team['school']?.text = schoolStr;
                                            team['members']?.text = membersStr;
                                          }
                                        } else {
                                          // clear to allow custom entry
                                          team['name']?.clear();
                                          team['school']?.clear();
                                          team['members']?.clear();
                                        }
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: team['name'],
                                    decoration: InputDecoration(
                                      labelText: 'Team Name',
                                      prefixIcon: const Icon(Icons.group),
                                    ),
                                    validator: (v) => (v == null || v.isEmpty) ? 'Team name is required' : null,
                                    enabled: _selectedTeamIds.length > idx ? _selectedTeamIds[idx] == null : true,
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: team['school'],
                                    decoration: InputDecoration(
                                      labelText: 'School',
                                      prefixIcon: const Icon(Icons.school),
                                    ),
                                    enabled: _selectedTeamIds.length > idx ? _selectedTeamIds[idx] == null : true,
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: team['members'],
                                    decoration: InputDecoration(
                                      labelText: 'Members (comma separated)',
                                      prefixIcon: const Icon(Icons.person),
                                    ),
                                    enabled: _selectedTeamIds.length > idx ? _selectedTeamIds[idx] == null : true,
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _testingConnection ? null : _testConnection,
                          icon: _testingConnection
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.wifi),
                          label: const Text('Test Connection'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _creating ? null : _create,
                          icon: _creating
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.play_arrow),
                          label: const Text('Create Tournament'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEliminationOption(String title, String value, String description, IconData icon) {
    final isSelected = _type == value;
    return InkWell(
      onTap: () => setState(() => _type = value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.1) : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? Theme.of(context).colorScheme.primary : null,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
