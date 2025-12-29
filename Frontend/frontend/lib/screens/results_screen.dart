import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/week_result.dart';
import '../services/voting_service.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  final VotingService _votingService = VotingService();

  WeekResult? _results;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await _votingService.getCurrentResults();
      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Current Results'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadResults,
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
            ElevatedButton(onPressed: _loadResults, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_results == null) {
      return const Center(child: Text('No results available'));
    }

    return RefreshIndicator(
      onRefresh: _loadResults,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Week info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Week ${_results!.weekId}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      'Deadline: ${DateFormat('EEEE, dd.MM.yyyy').format(_results!.deadline)}',
                    ),
                    Text(
                      'Total voters: ${_results!.votes.length}',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Winner
            if (_results!.hasWinner)
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.emoji_events,
                        color: Colors.amber,
                        size: 32,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _results!.winnerTimeSlots.length > 1 ? 'Winners (Tie)' : 'Winner',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            ..._results!.winnerTimeSlots.map((slot) => Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${DateFormat('EEEE, dd.MM. HH:mm').format(slot.datetime)} - ${slot.voteCount} votes (${slot.preferredVoteCount} preferred)',
                                style: const TextStyle(fontSize: 16),
                              ),
                            )),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Time slots with votes
            Text(
              'All Time Slots',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),

            ...(_results!.timeSlots.toList()
                  ..sort((a, b) => b.voteCount.compareTo(a.voteCount)))
                .map(
                  (slot) {
                    final isWinner = _results!.winnerTimeSlots
                        .any((w) => w.timeSlotId == slot.timeSlotId);
                    return Card(
                      color: isWinner ? Colors.green.shade50 : null,
                      child: ListTile(
                        leading: isWinner
                            ? const Icon(Icons.star, color: Colors.amber)
                            : const Icon(Icons.access_time),
                        title: Text(DateFormat('EEEE, dd.MM. HH:mm').format(slot.datetime)),
                        subtitle: Text(
                          '${slot.preferredVoteCount} preferred',
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isWinner
                                ? Colors.green
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${slot.voteCount}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isWinner ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
