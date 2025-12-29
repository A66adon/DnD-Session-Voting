class AuthResponse {
  final String token;
  final String username;
  final String message;
  
  AuthResponse({
    required this.token,
    required this.username,
    required this.message,
  });
  
  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'] as String,
      username: json['username'] as String,
      message: json['message'] as String,
    );
  }
}
