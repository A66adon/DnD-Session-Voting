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
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Winner
            if (_results!.winnerTimeSlot != null)
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
                            const Text(
                              'Winner',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              DateFormat(
                                'EEEE, dd.MM.yyyy HH:mm',
                              ).format(_results!.winnerTimeSlot!.datetime),
                              style: const TextStyle(fontSize: 16),
                            ),
                            Text(
                              '${_results!.winnerTimeSlot!.voteCount} votes',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
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
                  (slot) => Card(
                    color: slot.winner ? Colors.green.shade50 : null,
                    child: ListTile(
                      leading: slot.winner
                          ? const Icon(Icons.star, color: Colors.amber)
                          : const Icon(Icons.access_time),
                      title: Text(
                        DateFormat('EEEE, dd.MM. HH:mm').format(slot.datetime),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: slot.winner
                              ? Colors.green
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${slot.voteCount}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: slot.winner ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

            const SizedBox(height: 24),

            // Voters
            Text('Votes', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),

            if (_results!.votes.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No votes yet'),
                ),
              )
            else
              ..._results!.votes.map(
                (voter) => Card(
                  child: ExpansionTile(
                    leading: const Icon(Icons.person),
                    title: Text(voter.voterName),
                    subtitle: Text('${voter.votedTimeslots.length} votes'),
                    children: voter.votedTimeslots
                        .map(
                          (dt) => ListTile(
                            leading: const Icon(
                              Icons.check,
                              color: Colors.green,
                            ),
                            title: Text(
                              DateFormat('EEEE, dd.MM. HH:mm').format(dt),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
