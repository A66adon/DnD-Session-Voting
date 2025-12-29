class VoterInfo {
  final String voterName;
  final List<DateTime> votedTimeslots;
  
  VoterInfo({
    required this.voterName,
    required this.votedTimeslots,
  });
  
  factory VoterInfo.fromJson(Map<String, dynamic> json) {
    return VoterInfo(
      voterName: json['voterName'] as String,
      votedTimeslots: (json['votedTimeslots'] as List<dynamic>)
          .map((e) => DateTime.parse(e as String))
          .toList(),
    );
  }
}
