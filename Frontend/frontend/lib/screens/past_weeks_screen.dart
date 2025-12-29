import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/week_result.dart';
import '../services/voting_service.dart';

class PastWeeksScreen extends StatefulWidget {
  const PastWeeksScreen({super.key});

  @override
  State<PastWeeksScreen> createState() => _PastWeeksScreenState();
}

class _PastWeeksScreenState extends State<PastWeeksScreen> {
  final VotingService _votingService = VotingService();
  
  List<WeekResult>? _weeks;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPastWeeks();
  }

  Future<void> _loadPastWeeks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final weeks = await _votingService.getPastWeeks();
      setState(() {
        _weeks = weeks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _showWeekDetails(WeekResult week) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => _buildWeekDetails(week, scrollController),
      ),
    );
  }

  Widget _buildWeekDetails(WeekResult week, ScrollController scrollController) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        controller: scrollController,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Week ${week.weekId}',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          Text(
            'Deadline: ${DateFormat('dd.MM.yyyy').format(week.deadline)}',
            textAlign: TextAlign.center,
          ),
          Text(
            'Total voters: ${week.votes.length}',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          
          if (week.hasWinner) ...[
            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.emoji_events, color: Colors.amber, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            week.winnerTimeSlots.length > 1 ? 'Winners (Tie)' : 'Winner',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          ...week.winnerTimeSlots.map((slot) => Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${DateFormat('EEEE, dd.MM. HH:mm').format(slot.datetime)} - ${slot.voteCount} votes',
                            ),
                          )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          const Text(
            'All Time Slots:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          
          if (week.timeSlots.isEmpty)
            const Text('No time slots')
          else
            ...week.timeSlots.map((slot) {
              final isWinner = week.winnerTimeSlots
                  .any((w) => w.timeSlotId == slot.timeSlotId);
              return Card(
                color: isWinner ? Colors.green.shade50 : null,
                child: ListTile(
                  leading: isWinner
                      ? const Icon(Icons.star, color: Colors.amber)
                      : const Icon(Icons.access_time),
                  title: Text(DateFormat('EEEE, dd.MM. HH:mm').format(slot.datetime)),
                  trailing: Text(
                    '${slot.voteCount} votes (${slot.preferredVoteCount} preferred)',
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Past Weeks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPastWeeks,
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
    
    if (_errorMessage != null) {
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
              onPressed: _loadPastWeeks,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    
    if (_weeks == null || _weeks!.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No past weeks yet'),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadPastWeeks,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _weeks!.length,
        itemBuilder: (context, index) {
          final week = _weeks![index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: const Icon(Icons.calendar_month),
              title: Text('Week ${week.weekId}'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Deadline: ${DateFormat('dd.MM.yyyy').format(week.deadline)}'),
                  if (week.hasWinner)
                    Row(
                      children: [
                        const Icon(Icons.emoji_events, size: 16, color: Colors.amber),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            DateFormat('EEEE, dd.MM. HH:mm').format(week.primaryWinner!.datetime),
                            style: const TextStyle(color: Colors.green),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showWeekDetails(week),
            ),
          );
        },
      ),
    );
  }
}
