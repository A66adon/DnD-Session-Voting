import 'time_slot.dart';

class VoterInfo {
  final String voterName;
  final List<DateTime> votedTimeslots;
  final DateTime? preferredTimeslot;

  VoterInfo({
    required this.voterName,
    required this.votedTimeslots,
    this.preferredTimeslot,
  });

  factory VoterInfo.fromJson(Map<String, dynamic> json) {
    return VoterInfo(
      voterName: json['voterName'] as String,
      votedTimeslots: (json['votedTimeslots'] as List<dynamic>)
          .map((e) => DateTime.parse(e as String))
          .toList(),
      preferredTimeslot: json['preferredTimeslot'] != null && json['preferredTimeslot'] != ''
          ? DateTime.parse(json['preferredTimeslot'] as String)
          : null,
    );
  }
}

class WeekResult {
  final int weekId;
  final DateTime deadline;
  final List<TimeSlotResult> timeSlots;
  final List<VoterInfo> votes;
  final List<TimeSlotResult> winnerTimeSlots;

  WeekResult({
    required this.weekId,
    required this.deadline,
    required this.timeSlots,
    required this.votes,
    required this.winnerTimeSlots,
  });

  factory WeekResult.fromJson(Map<String, dynamic> json) {
    return WeekResult(
      weekId: json['weekId'] as int,
      deadline: DateTime.parse(json['deadline'] as String),
      timeSlots: (json['timeSlots'] as List<dynamic>)
          .map((e) => TimeSlotResult.fromJson(e as Map<String, dynamic>))
          .toList(),
      votes: (json['votes'] as List<dynamic>)
          .map((e) => VoterInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      winnerTimeSlots: (json['winnerTimeSlots'] as List<dynamic>)
          .map((e) => TimeSlotResult.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Check if there's a winner
  bool get hasWinner => winnerTimeSlots.isNotEmpty;

  /// Get the primary winning time slot
  TimeSlotResult? get primaryWinner =>
      winnerTimeSlots.isNotEmpty ? winnerTimeSlots.first : null;
}
