import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/week_result.dart';
import '../models/time_slot.dart';
import '../services/auth_service.dart';
import '../services/voting_service.dart';

class VotingScreen extends StatefulWidget {
  const VotingScreen({super.key});

  @override
  State<VotingScreen> createState() => _VotingScreenState();
}

class _VotingScreenState extends State<VotingScreen> {
  final VotingService _votingService = VotingService();
  final AuthService _authService = AuthService();

  WeekResult? _currentWeek;
  final Set<int> _selectedSlots = {};
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _loadCurrentWeek();
  }

  Future<void> _loadCurrentWeek() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Use current-results endpoint which has proper JSON structure
      final week = await _votingService.getCurrentResults();
      setState(() {
        _currentWeek = week;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _submitVote() async {
    if (_selectedSlots.isEmpty) {
      setState(() {
        _errorMessage = 'Please select at least one time slot';
      });
      return;
    }

    if (!_authService.isLoggedIn) {
      setState(() {
        _errorMessage = 'Please login to vote';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await _votingService.submitVote(_selectedSlots.toList());
      setState(() {
        _successMessage = 'Vote submitted successfully!';
        _isSubmitting = false;
      });
      // Reload to show updated results
      _loadCurrentWeek();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isSubmitting = false;
      });
    }
  }

  void _toggleSlot(int slotId) {
    setState(() {
      if (_selectedSlots.contains(slotId)) {
        _selectedSlots.remove(slotId);
      } else {
        _selectedSlots.add(slotId);
      }
      _successMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vote for Session Time'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCurrentWeek,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _currentWeek == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadCurrentWeek,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_currentWeek == null) {
      return const Center(child: Text('No voting week available'));
    }

    // Group timeslots by date
    final slotsByDate = <DateTime, List<TimeSlotResult>>{};
    for (final slot in _currentWeek!.timeSlots) {
      final date = DateTime(
        slot.datetime.year,
        slot.datetime.month,
        slot.datetime.day,
      );
      slotsByDate.putIfAbsent(date, () => []).add(slot);
    }

    final sortedDates = slotsByDate.keys.toList()..sort();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(
                'Week ${_currentWeek!.weekId}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                'Deadline: ${DateFormat('EEEE, dd.MM.yyyy').format(_currentWeek!.deadline)}',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (_authService.isLoggedIn)
                Text(
                  'Voting as: ${_authService.username}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.green),
                )
              else
                Text(
                  'Login required to vote',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.orange),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: sortedDates.length,
            itemBuilder: (context, index) {
              final date = sortedDates[index];
              final slots = slotsByDate[date]!
                ..sort((a, b) => a.datetime.compareTo(b.datetime));

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        DateFormat('EEEE, dd.MM.yyyy').format(date),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    ...slots.map(
                      (slot) => CheckboxListTile(
                        title: Text(DateFormat('HH:mm').format(slot.datetime)),
                        subtitle: Text('${slot.voteCount} votes'),
                        value: _selectedSlots.contains(slot.timeSlotId),
                        onChanged: _authService.isLoggedIn
                            ? (_) => _toggleSlot(slot.timeSlotId)
                            : null,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
        if (_successMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _successMessage!,
              style: const TextStyle(color: Colors.green),
              textAlign: TextAlign.center,
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _authService.isLoggedIn && !_isSubmitting
                  ? _submitVote
                  : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _selectedSlots.isEmpty
                          ? 'Select time slots'
                          : 'Submit Vote (${_selectedSlots.length} selected)',
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
