import 'time_slot.dart';

/// Response from the POST /vote endpoint
class VoteResponse {
  final int id;
  final String username;
  final DateTime votedAt;
  final List<TimeSlot> selectedTimeSlots;
  final TimeSlot? preferredTimeSlot;

  VoteResponse({
    required this.id,
    required this.username,
    required this.votedAt,
    required this.selectedTimeSlots,
    this.preferredTimeSlot,
  });

  factory VoteResponse.fromJson(Map<String, dynamic> json) {
    return VoteResponse(
      id: json['id'] as int,
      username: json['username'] as String,
      votedAt: DateTime.parse(json['votedAt'] as String),
      selectedTimeSlots: (json['selectedTimeSlots'] as List<dynamic>)
          .map((e) => TimeSlot.fromJson(e as Map<String, dynamic>))
          .toList(),
      preferredTimeSlot: json['preferredTimeSlot'] != null
          ? TimeSlot.fromJson(json['preferredTimeSlot'] as Map<String, dynamic>)
          : null,
    );
  }
}
