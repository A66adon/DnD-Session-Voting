class TimeSlot {
  final int id;
  final DateTime datetime;

  TimeSlot({
    required this.id,
    required this.datetime,
  });

  factory TimeSlot.fromJson(Map<String, dynamic> json) {
    // Handle both 'id' and 'timeSlotId' field names from backend
    final id = json['id'] ?? json['timeSlotId'];
    if (id == null) {
      throw FormatException('TimeSlot JSON missing id field: $json');
    }
    return TimeSlot(
      id: id as int,
      datetime: DateTime.parse(json['datetime'] as String),
    );
  }
}

class TimeSlotResult {
  final int timeSlotId;
  final DateTime datetime;
  final int voteCount;
  final int preferredVoteCount;
  final double weightedVoteCount;
  final bool winner;

  TimeSlotResult({
    required this.timeSlotId,
    required this.datetime,
    required this.voteCount,
    required this.preferredVoteCount,
    required this.weightedVoteCount,
    required this.winner,
  });

  factory TimeSlotResult.fromJson(Map<String, dynamic> json) {
    return TimeSlotResult(
      timeSlotId: json['timeSlotId'] as int,
      datetime: DateTime.parse(json['datetime'] as String),
      voteCount: json['voteCount'] as int,
      preferredVoteCount: json['preferredVoteCount'] as int? ?? 0,
      weightedVoteCount: (json['weightedVoteCount'] as num?)?.toDouble() ?? 0.0,
      winner: json['winner'] as bool? ?? false,
    );
  }
}
