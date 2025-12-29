import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/voting_week.dart';
import '../models/week_result.dart';
import '../models/time_slot.dart';
import '../services/auth_service.dart';
import '../services/voting_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final VotingService _votingService = VotingService();
  final AuthService _authService = AuthService();

  VotingWeek? _currentWeek;
  WeekResult? _weekResult;
  List<WeekResult>? _allWeeks;
  int _currentWeekIndex = 0;
  bool _isViewingCurrentWeek = true;
  final Set<int> _selectedSlots = {};
  Set<int> _originalSelectedSlots = {};
  int? _preferredSlotId;
  int? _originalPreferredSlotId;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

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
      final week = await _votingService.getCurrentWeek();
      WeekResult? result;
      try {
        result = await _votingService.getCurrentResults();
      } catch (_) {
        // Results may not be available yet
      }

      // Pre-populate selected slots from user's existing votes
      final currentUsername = _authService.username;
      if (result != null && currentUsername != null) {
        final userVote = result.votes
            .where((v) => v.voterName == currentUsername)
            .firstOrNull;
        if (userVote != null) {
          _selectedSlots.clear();
          _preferredSlotId = null;

          for (final votedTime in userVote.votedTimeslots) {
            // Find matching slot by datetime
            for (final slot in week.timeSlots) {
              if (slot.datetime.year == votedTime.year &&
                  slot.datetime.month == votedTime.month &&
                  slot.datetime.day == votedTime.day &&
                  slot.datetime.hour == votedTime.hour &&
                  slot.datetime.minute == votedTime.minute) {
                _selectedSlots.add(slot.id);
                break;
              }
            }
          }

          // Set preferred slot
          if (userVote.preferredTimeslot != null) {
            for (final slot in week.timeSlots) {
              if (slot.datetime.year == userVote.preferredTimeslot!.year &&
                  slot.datetime.month == userVote.preferredTimeslot!.month &&
                  slot.datetime.day == userVote.preferredTimeslot!.day &&
                  slot.datetime.hour == userVote.preferredTimeslot!.hour &&
                  slot.datetime.minute == userVote.preferredTimeslot!.minute) {
                _preferredSlotId = slot.id;
                break;
              }
            }
          }
        }
      }

      setState(() {
        _currentWeekIndex = 0;
        _isViewingCurrentWeek = true;
        _currentWeek = week;
        _weekResult = result;
        _originalSelectedSlots = Set.from(_selectedSlots);
        _originalPreferredSlotId = _preferredSlotId;
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
    if (!_authService.isLoggedIn) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await _votingService.submitVote(
        _selectedSlots.toList(),
        preferredTimeSlotId: _preferredSlotId,
      );
      setState(() {
        _isSubmitting = false;
      });
      // Refresh the page to show updated results
      await _loadCurrentWeek();
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
        if (_preferredSlotId == slotId) {
          _preferredSlotId = null;
        }
      } else {
        _selectedSlots.add(slotId);
      }
    });
  }

  void _setPreferredSlot(int slotId) {
    setState(() {
      _preferredSlotId = slotId;
    });
  }

  Future<void> _navigateToPreviousWeek() async {
    // Lazy load all weeks on first navigation
    if (_allWeeks == null) {
      try {
        final allWeeks = await _votingService.getAllWeeks();
        allWeeks.sort((a, b) => b.weekId.compareTo(a.weekId));
        setState(() {
          _allWeeks = allWeeks;
        });
      } catch (e) {
        setState(() {
          _errorMessage = 'Failed to load week history';
        });
        return;
      }
    }

    if (_currentWeekIndex >= _allWeeks!.length - 1) return;
    setState(() {
      _currentWeekIndex++;
      _isViewingCurrentWeek = false;
      _weekResult = _allWeeks![_currentWeekIndex];
    });
  }

  void _navigateToNextWeek() {
    if (_allWeeks == null || _currentWeekIndex <= 0) return;
    setState(() {
      _currentWeekIndex--;
      _isViewingCurrentWeek = _currentWeekIndex == 0;
      if (_isViewingCurrentWeek && _currentWeek != null) {
        // Reload current week result when going back to current
        _loadCurrentWeek();
      } else {
        _weekResult = _allWeeks![_currentWeekIndex];
      }
    });
  }

  int _getWeekOfYear(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysDifference = date.difference(firstDayOfYear).inDays;
    return ((daysDifference + firstDayOfYear.weekday) / 7).ceil();
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.logout();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth * 0.1;

    final displayedDeadline = _weekResult?.deadline ?? _currentWeek?.deadline;
    final weekNumber = displayedDeadline != null
        ? _getWeekOfYear(displayedDeadline)
        : 0;
    final canGoBack =
        _allWeeks != null && _currentWeekIndex < _allWeeks!.length - 1;
    final canGoForward = _currentWeekIndex > 0;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: _currentWeek != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back_ios,
                          color: canGoBack
                              ? Colors.white
                              : Colors.grey.shade700,
                          size: 20,
                        ),
                        onPressed: canGoBack ? _navigateToPreviousWeek : null,
                        tooltip: 'Previous week',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Week $weekNumber',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: Icon(
                          Icons.arrow_forward_ios,
                          color: canGoForward
                              ? Colors.white
                              : Colors.grey.shade700,
                          size: 20,
                        ),
                        onPressed: canGoForward ? _navigateToNextWeek : null,
                        tooltip: 'Next week',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isViewingCurrentWeek
                        ? 'Deadline: ${DateFormat('EEEE, dd.MM.yyyy').format(_currentWeek!.deadline)}'
                        : 'Results: ${DateFormat('dd.MM.yyyy').format(displayedDeadline!)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _isViewingCurrentWeek
                          ? Colors.white
                          : Colors.grey.shade400,
                    ),
                  ),
                  if (_authService.isLoggedIn) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Logged in as: ${_authService.username}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ],
              )
            : const Text('Loading...'),
        toolbarHeight: 110,
        actions: [
          if (_authService.isLoggedIn) ...[
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: _handleLogout,
                child: Tooltip(
                  message: 'Tap to logout',
                  child: ClipOval(
                    child: Image.network(
                      'https://api.dicebear.com/7.x/bottts/png?seed=${_authService.username}&size=88',
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.shade700,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person, color: Colors.white),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.shade700,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                onPressed: _handleLogout,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.login),
                label: const Text('Login'),
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed('/login');
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.deepPurple.shade900,
              Colors.black,
              Colors.deepPurple.shade900.withOpacity(0.8),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: _buildBody(horizontalPadding),
      ),
    );
  }

  bool _hasChanges() {
    if (_selectedSlots.length != _originalSelectedSlots.length) return true;
    if (!_selectedSlots.every((id) => _originalSelectedSlots.contains(id)))
      return true;
    if (_preferredSlotId != _originalPreferredSlotId) return true;
    return false;
  }

  Widget _buildBody(double horizontalPadding) {
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

    final slotsByDate = <DateTime, List<TimeSlot>>{};
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
        // Show "Viewing History" banner when not on current week
        if (!_isViewingCurrentWeek)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            color: Colors.deepPurple.shade800,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.history, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Viewing Past Results',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 16),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _currentWeekIndex = 0;
                      _isViewingCurrentWeek = true;
                      if (_allWeeks != null && _allWeeks!.isNotEmpty) {
                        _weekResult = _allWeeks![0];
                      }
                    });
                  },
                  child: const Text('Back to Current Week'),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 16,
            ),
            itemCount: sortedDates.length,
            itemBuilder: (context, index) {
              final date = sortedDates[index];
              final slots = slotsByDate[date]!
                ..sort((a, b) => a.datetime.compareTo(b.datetime));

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...slots.map((slot) => _buildTimeSlotCard(slot, date)),
                ],
              );
            },
          ),
        ),
        if (_errorMessage != null)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
        if (_authService.isLoggedIn && _isViewingCurrentWeek && _hasChanges())
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 16,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitVote,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.how_to_vote, size: 28),
                label: Text(
                  _isSubmitting ? 'Submitting...' : 'Submit Vote',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildTimeSlotCard(TimeSlot slot, DateTime date) {
    final isSelected = _selectedSlots.contains(slot.id);
    final isPreferred = _preferredSlotId == slot.id;

    // Get voters for this timeslot
    final voters =
        _weekResult?.votes
            .where(
              (v) => v.votedTimeslots.any(
                (t) =>
                    t.year == slot.datetime.year &&
                    t.month == slot.datetime.month &&
                    t.day == slot.datetime.day &&
                    t.hour == slot.datetime.hour &&
                    t.minute == slot.datetime.minute,
              ),
            )
            .toList() ??
        [];

    // Determine card styling based on selection
    final cardColor = isSelected
        ? Colors.deepPurple.shade700
        : Colors.deepPurple.shade900.withOpacity(0.5);
    final borderColor = isPreferred
        ? Colors.amber
        : isSelected
        ? Colors.deepPurple.shade300
        : Colors.deepPurple.shade800;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: _authService.isLoggedIn && _isViewingCurrentWeek
              ? () => _toggleSlot(slot.id)
              : null,
          onLongPress:
              _authService.isLoggedIn && _isViewingCurrentWeek && isSelected
              ? () => _setPreferredSlot(slot.id)
              : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 2),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat('EEEE, dd.MM.yyyy').format(date),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? Colors.white : Colors.white70,
                    ),
                  ),
                ),
                if (voters.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: SizedBox(
                      width: voters.length * 18.0 + 10,
                      height: 28,
                      child: Stack(
                        children: voters.asMap().entries.map((entry) {
                          final index = entry.key;
                          final voter = entry.value;
                          final isPreferredVote =
                              voter.preferredTimeslot != null &&
                              voter.preferredTimeslot!.year ==
                                  slot.datetime.year &&
                              voter.preferredTimeslot!.month ==
                                  slot.datetime.month &&
                              voter.preferredTimeslot!.day ==
                                  slot.datetime.day &&
                              voter.preferredTimeslot!.hour ==
                                  slot.datetime.hour &&
                              voter.preferredTimeslot!.minute ==
                                  slot.datetime.minute;
                          return Positioned(
                            left: index * 18.0,
                            child: Tooltip(
                              message:
                                  voter.voterName +
                                  (isPreferredVote ? ' (preferred)' : ''),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: isPreferredVote
                                      ? Border.all(
                                          color: Colors.amber,
                                          width: 2,
                                        )
                                      : Border.all(
                                          color: Colors.deepPurple.shade900,
                                          width: 1,
                                        ),
                                ),
                                child: ClipOval(
                                  child: Image.network(
                                    'https://api.dicebear.com/7.x/bottts/png?seed=${voter.voterName}&size=56',
                                    width: 26,
                                    height: 26,
                                    fit: BoxFit.cover,
                                    loadingBuilder:
                                        (context, child, loadingProgress) {
                                          if (loadingProgress == null)
                                            return child;
                                          return Container(
                                            width: 26,
                                            height: 26,
                                            color: Colors.deepPurple.shade400,
                                          );
                                        },
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Container(
                                              width: 26,
                                              height: 26,
                                              color: Colors.deepPurple.shade400,
                                              child: const Icon(
                                                Icons.person,
                                                size: 14,
                                                color: Colors.white,
                                              ),
                                            ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                Text(
                  DateFormat('HH:mm').format(slot.datetime),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
