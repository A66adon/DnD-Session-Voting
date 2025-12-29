import 'time_slot.dart';
import 'vote.dart';

class WeekResult {
  final int weekId;
  final DateTime deadline;
  final List<TimeSlotResult> timeSlots;
  final List<VoterInfo> votes;
  final TimeSlotResult? winnerTimeSlot;
  
  WeekResult({
    required this.weekId,
    required this.deadline,
    required this.timeSlots,
    required this.votes,
    this.winnerTimeSlot,
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
      winnerTimeSlot: json['winnerTimeSlot'] != null
          ? TimeSlotResult.fromJson(json['winnerTimeSlot'] as Map<String, dynamic>)
          : null,
    );
  }
}
