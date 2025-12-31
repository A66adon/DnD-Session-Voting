import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/voting_week.dart';
import '../models/week_result.dart';
import 'auth_service.dart';

class VotingService {
  final AuthService _authService = AuthService();

  /// Get the current voting week
  Future<VotingWeek> getCurrentWeek() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.currentWeekEndpoint}'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      developer.log('getCurrentWeek response: $data', name: 'VotingService');
      return VotingWeek.fromJson(data);
    } else {
      throw Exception('Failed to load current week: ${response.statusCode}');
    }
  }
  
  /// Get current week results
  Future<WeekResult> getCurrentResults() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.currentResultsEndpoint}'),
      headers: {'Content-Type': 'application/json'},
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return WeekResult.fromJson(data);
    } else {
      throw Exception('Failed to load current results: ${response.statusCode}');
    }
  }
  
  /// Get results for a specific week
  Future<WeekResult> getWeekResults(int weekId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.weekResultsEndpoint(weekId)}'),
      headers: {'Content-Type': 'application/json'},
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return WeekResult.fromJson(data);
    } else {
      throw Exception('No Week found');
    }
  }
  
  /// Get all past weeks
  Future<List<WeekResult>> getPastWeeks() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.pastWeeksEndpoint}'),
      headers: {'Content-Type': 'application/json'},
    );
    
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => WeekResult.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load past weeks: ${response.statusCode}');
    }
  }
  
  /// Get all weeks
  Future<List<WeekResult>> getAllWeeks() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.allWeeksEndpoint}'),
      headers: {'Content-Type': 'application/json'},
    );
    
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => WeekResult.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load all weeks: ${response.statusCode}');
    }
  }
  
  /// Submit a vote (requires authentication)
  /// [timeSlotIds] - List of time slot IDs the user is available for
  /// [preferredTimeSlotId] - The user's preferred time slot ID (must be in timeSlotIds)
  Future<void> submitVote(List<int> timeSlotIds, {int? preferredTimeSlotId}) async {
    if (!_authService.isLoggedIn) {
      throw Exception('Not authenticated. Please login first.');
    }

    final body = <String, dynamic>{
      'timeSlotIds': timeSlotIds,
    };
    if (preferredTimeSlotId != null) {
      body['preferredTimeSlotId'] = preferredTimeSlotId;
    }

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.voteEndpoint}'),
      headers: _authService.authHeaders,
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      return;
    } else if (response.statusCode == 401) {
      throw Exception('Authentication expired. Please login again.');
    } else {
      throw Exception('Failed to submit vote: ${response.statusCode}');
    }
  }
  
  /// Reset week (requires authentication, for testing)
  Future<VotingWeek> resetWeek() async {
    if (!_authService.isLoggedIn) {
      throw Exception('Not authenticated. Please login first.');
    }
    
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.resetWeekEndpoint}'),
      headers: _authService.authHeaders,
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return VotingWeek.fromJson(data);
    } else if (response.statusCode == 401) {
      throw Exception('Authentication expired. Please login again.');
    } else {
      throw Exception('Failed to reset week: ${response.statusCode}');
    }
  }
}
