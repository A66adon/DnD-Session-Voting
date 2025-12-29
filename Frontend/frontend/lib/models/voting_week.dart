import 'time_slot.dart';

class VotingWeek {
  final int id;
  final DateTime deadline;
  final List<TimeSlot> timeSlots;

  VotingWeek({
    required this.id,
    required this.deadline,
    required this.timeSlots,
  });

  factory VotingWeek.fromJson(Map<String, dynamic> json) {
    return VotingWeek(
      id: json['id'] as int,
      deadline: DateTime.parse(json['deadline'] as String),
      timeSlots: (json['timeSlots'] as List<dynamic>)
          .map((e) => TimeSlot.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
