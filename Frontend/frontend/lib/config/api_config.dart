/// API Configuration
/// Change baseUrl to match your backend server
class ApiConfig {
  // For Android emulator use: http://10.0.2.2:8080
  // For iOS simulator use: http://localhost:8080
  // For physical device use your computer's IP: http://192.168.x.x:8080
  // For web use: http://localhost:8080
  //For deployed backen use: https://dnd-session-voting-production.up.railway.app
  static const String baseUrl = 'https://dnd-session-voting-production.up.railway.app';
  
  // Auth endpoints
  static const String loginEndpoint = '/api/auth/login';
  
  // Voting endpoints
  static const String currentWeekEndpoint = '/api/voting/current-week';
  static const String currentResultsEndpoint = '/api/voting/current-results';
  static const String voteEndpoint = '/api/voting/vote';
  static const String pastWeeksEndpoint = '/api/voting/past-weeks';
  static const String allWeeksEndpoint = '/api/voting/all-weeks';
  static const String resetWeekEndpoint = '/api/voting/reset-week';
  
  static String weekResultsEndpoint(int weekId) => '/api/voting/week/$weekId/results';
}
