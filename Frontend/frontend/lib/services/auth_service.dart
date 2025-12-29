import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/auth_response.dart';

class AuthService {
  static const String _tokenKey = 'jwt_token';
  static const String _usernameKey = 'username';
  
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();
  
  String? _token;
  String? _username;
  
  String? get token => _token;
  String? get username => _username;
  bool get isLoggedIn => _token != null;
  
  /// Initialize the service by loading stored token
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    _username = prefs.getString(_usernameKey);
  }
  
  /// Login with username and password
  Future<AuthResponse> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.loginEndpoint}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final authResponse = AuthResponse.fromJson(data);
      
      // Save token and username
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, authResponse.token);
      await prefs.setString(_usernameKey, authResponse.username);
      
      _token = authResponse.token;
      _username = authResponse.username;
      
      return authResponse;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Login failed');
    }
  }
  
  /// Logout - clear stored token
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_usernameKey);
    _token = null;
    _username = null;
  }
  
  /// Get authorization headers for authenticated requests
  Map<String, String> get authHeaders {
    return {
      'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
  }
}
