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
  WeekResult? _currentWeekResult;
  int _currentWeekIndex = 0;
  bool _isViewingCurrentWeek = true;
  final Set<int> _selectedSlots = {};
  Set<int> _originalSelectedSlots = {};
  final Set<int> _preferredSlotIds = {};
  Set<int> _originalPreferredSlotIds = {};
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
          _preferredSlotIds.clear();

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

          // Set preferred slots
          for (final preferredTime in userVote.preferredTimeslots) {
            for (final slot in week.timeSlots) {
              if (slot.datetime.year == preferredTime.year &&
                  slot.datetime.month == preferredTime.month &&
                  slot.datetime.day == preferredTime.day &&
                  slot.datetime.hour == preferredTime.hour &&
                  slot.datetime.minute == preferredTime.minute) {
                _preferredSlotIds.add(slot.id);
                break;
              }
            }
          }
        }
      }

      setState(() {
        _isViewingCurrentWeek = true;
        _currentWeek = week;
        _currentWeekIndex = _currentWeek!.id;
        _weekResult = result;
        _currentWeekResult = result;
        _originalSelectedSlots = Set.from(_selectedSlots);
        _originalPreferredSlotIds = Set.from(_preferredSlotIds);
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
        preferredTimeSlotIds: _preferredSlotIds.isNotEmpty ? _preferredSlotIds.toList() : null,
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
        _preferredSlotIds.remove(slotId);
      } else {
        _selectedSlots.add(slotId);
      }
    });
  }

  void _togglePreferredSlot(int slotId) {
    setState(() {
      if (_preferredSlotIds.contains(slotId)) {
        _preferredSlotIds.remove(slotId);
      } else {
        _preferredSlotIds.add(slotId);
      }
    });
  }

  Future<void> _navigateToPreviousWeek() async {
    if (_currentWeek == null) return;

    final targetWeekIndex = _currentWeekIndex - 1;
    if (targetWeekIndex < 1) return; // Already at the first week

    WeekResult viewPreviousWeek;
    try {
      viewPreviousWeek = await _votingService.getWeekResults(targetWeekIndex);
    } catch (_) {
      return; // No previous week available or failed to load
    }

    setState(() {
      _currentWeekIndex = targetWeekIndex;
      _isViewingCurrentWeek = _currentWeekIndex == _currentWeek!.id;
      _weekResult = viewPreviousWeek;
    });
  }

  Future<void> _navigateToNextWeek() async {
    if (_currentWeek == null) return;

    final targetWeekIndex = _currentWeekIndex + 1;

    WeekResult viewNextWeek;
    try {
      viewNextWeek = await _votingService.getWeekResults(targetWeekIndex);
    } catch (_) {
      return; // No next week available or failed to load
    }

    setState(() {
      _currentWeekIndex = targetWeekIndex;
      _isViewingCurrentWeek = _currentWeekIndex == _currentWeek!.id;
      _weekResult = viewNextWeek;
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
                          color:  Colors.white,
                          size: 20,
                        ),
                        onPressed: _navigateToPreviousWeek,
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
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: _navigateToNextWeek,
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
      body: Stack(
        children: [
          // Base gradient layer
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1a0a2e), // Deep purple-black
                  Color(0xFF0d0d1a), // Almost black with hint of blue
                  Color(0xFF16213e), // Dark blue
                  Color(0xFF1a0a2e), // Deep purple-black
                ],
                stops: [0.0, 0.35, 0.65, 1.0],
              ),
            ),
          ),
          // Large ambient glow - top left
          Positioned(
            top: -150,
            left: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.deepPurple.withValues(alpha: 0.25),
                    Colors.deepPurple.withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),
          // Large ambient glow - bottom right
          Positioned(
            bottom: -200,
            right: -150,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.indigo.withValues(alpha: 0.2),
                    Colors.purple.withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),
          // Mid-screen accent glow
          Positioned(
            top: MediaQuery.of(context).size.height * 0.4,
            right: -80,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.purple.shade900.withValues(alpha: 0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Left side mid glow
          Positioned(
            top: MediaQuery.of(context).size.height * 0.55,
            left: -120,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.deepPurple.shade800.withValues(alpha: 0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Subtle top center glow
          Positioned(
            top: -50,
            left: MediaQuery.of(context).size.width * 0.3,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.4,
              height: 200,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.0,
                  colors: [
                    Colors.deepPurple.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Decorative stars/magic particles
          ..._buildStarField(context),
          // Main content
          _buildBody(horizontalPadding),
        ],
      ),
    );
  }

  bool _hasChanges() {
    if (_selectedSlots.length != _originalSelectedSlots.length) return true;
    if (!_selectedSlots.every((id) => _originalSelectedSlots.contains(id)))
      return true;
    if (_preferredSlotIds.length != _originalPreferredSlotIds.length) return true;
    if (!_preferredSlotIds.every((id) => _originalPreferredSlotIds.contains(id)))
      return true;
    return false;
  }

  List<Widget> _buildStarField(BuildContext context) {
    // Pre-defined star positions for consistent, performant rendering
    const starData = [
      // (xPercent, yPercent, size, opacity, hasGlow)
      (0.05, 0.08, 2.0, 0.7, true),
      (0.92, 0.05, 1.5, 0.5, false),
      (0.15, 0.18, 1.0, 0.4, false),
      (0.88, 0.15, 2.5, 0.8, true),
      (0.03, 0.32, 1.5, 0.5, false),
      (0.95, 0.28, 2.0, 0.6, true),
      (0.08, 0.45, 1.0, 0.3, false),
      (0.90, 0.42, 1.5, 0.5, false),
      (0.12, 0.58, 2.0, 0.6, true),
      (0.94, 0.55, 1.0, 0.4, false),
      (0.06, 0.72, 1.5, 0.5, false),
      (0.88, 0.68, 2.5, 0.7, true),
      (0.15, 0.85, 2.0, 0.6, true),
      (0.92, 0.82, 1.0, 0.4, false),
      (0.04, 0.92, 1.5, 0.5, false),
      (0.96, 0.95, 2.0, 0.6, true),
      // Extra stars
      (0.25, 0.12, 1.0, 0.35, false),
      (0.75, 0.10, 1.5, 0.45, false),
      (0.35, 0.25, 0.8, 0.3, false),
      (0.65, 0.22, 1.2, 0.4, false),
      (0.45, 0.35, 1.0, 0.35, false),
      (0.55, 0.48, 0.8, 0.3, false),
      (0.28, 0.62, 1.0, 0.35, false),
      (0.72, 0.58, 1.2, 0.4, false),
      (0.38, 0.78, 0.8, 0.3, false),
      (0.62, 0.75, 1.0, 0.35, false),
      (0.48, 0.88, 1.2, 0.4, false),
      (0.22, 0.95, 0.8, 0.3, false),
      (0.78, 0.92, 1.0, 0.35, false),
    ];

    final size = MediaQuery.of(context).size;

    return starData.map((star) {
      final (xPct, yPct, starSize, opacity, hasGlow) = star;
      return Positioned(
        left: size.width * xPct,
        top: size.height * yPct,
        child: Container(
          width: starSize,
          height: starSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: opacity),
            boxShadow: hasGlow
                ? [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: opacity * 0.6),
                      blurRadius: 6,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: Colors.purple.withValues(alpha: opacity * 0.3),
                      blurRadius: 10,
                      spreadRadius: 3,
                    ),
                  ]
                : null,
          ),
        ),
      );
    }).toList();
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

    // Use timeSlots from the currently viewed week (from _weekResult if viewing past week)
    final List<TimeSlot> displayedTimeSlots;
    if (_isViewingCurrentWeek) {
      displayedTimeSlots = _currentWeek!.timeSlots;
    } else if (_weekResult != null) {
      // Convert TimeSlotResult to TimeSlot for past weeks
      displayedTimeSlots = _weekResult!.timeSlots
          .map((tsr) => TimeSlot(id: tsr.timeSlotId, datetime: tsr.datetime))
          .toList();
    } else {
      displayedTimeSlots = _currentWeek!.timeSlots;
    }

    final slotsByDate = <DateTime, List<TimeSlot>>{};
    for (final slot in displayedTimeSlots) {
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
        if (!_isViewingCurrentWeek)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 16,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.deepPurple.shade800,
                border: Border.all(
                  color: Colors.deepPurple.shade300,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.history, color: Colors.white70, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Viewing Past Results',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 16),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _currentWeekIndex = _currentWeek!.id;
                        _isViewingCurrentWeek = true;
                        _weekResult = _currentWeekResult;
                      });
                    },
                    child: const Text(
                      'Back to Current Week', 
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                        ),
                    ),
                  ),
                ],
              ),
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
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: _isSubmitting ? null : _submitVote,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.deepPurple.shade600,
                          Colors.deepPurple.shade800,
                          Colors.indigo.shade800,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.deepPurple.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(
                        color: Colors.deepPurple.shade300,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _isSubmitting
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.how_to_vote,
                                size: 28,
                                color: Colors.white,
                              ),
                        const SizedBox(width: 12),
                        Text(
                          _isSubmitting ? 'Submitting...' : 'Submit Vote',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
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
    final isSelected = _isViewingCurrentWeek ? _selectedSlots.contains(slot.id) : false;
    final isPreferred = _isViewingCurrentWeek ? _preferredSlotIds.contains(slot.id) : false;

    // Check if this slot is a winner
    final isWinner =
        _weekResult?.winnerTimeSlots.any(
          (w) =>
              w.datetime.year == slot.datetime.year &&
              w.datetime.month == slot.datetime.month &&
              w.datetime.day == slot.datetime.day &&
              w.datetime.hour == slot.datetime.hour &&
              w.datetime.minute == slot.datetime.minute,
        ) ??
        false;

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
    final borderColor = isPreferred
        ? Colors.amber
        : isSelected
        ? Colors.deepPurple.shade300
        : Colors.deepPurple.shade800;

    // Card gradient colors for more interesting look
    final gradientColors = isSelected
        ? [
            Colors.deepPurple.shade700.withValues(alpha: 0.85),
            Colors.deepPurple.shade800.withValues(alpha: 0.7),
            Colors.indigo.shade900.withValues(alpha: 0.6),
          ]
        : [
            Colors.deepPurple.shade900.withValues(alpha: 0.5),
            const Color(0xFF1a0a2e).withValues(alpha: 0.6),
            Colors.indigo.shade900.withValues(alpha: 0.4),
          ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: _authService.isLoggedIn && _isViewingCurrentWeek
              ? () => _toggleSlot(slot.id)
              : null,
          onLongPress:
              _authService.isLoggedIn && _isViewingCurrentWeek && isSelected
              ? () => _togglePreferredSlot(slot.id)
              : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 2),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.deepPurple.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Icon(
                    isWinner ? Icons.emoji_events : Icons.emoji_events_outlined,
                    color: isWinner
                        ? Colors.amber.shade300
                        : Colors.grey.shade600,
                    size: 28,
                  ),
                ),
                Expanded(
                  child: Text(
                    DateFormat('EEEE, dd.MM.yyyy').format(date),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isWinner ? FontWeight.bold : FontWeight.w500,
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
                              voter.preferredTimeslots.any(
                                (t) =>
                                    t.year == slot.datetime.year &&
                                    t.month == slot.datetime.month &&
                                    t.day == slot.datetime.day &&
                                    t.hour == slot.datetime.hour &&
                                    t.minute == slot.datetime.minute,
                              );
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
