class AccessTokenResponse {
  final String accessToken;
  final String role;

  AccessTokenResponse({required this.accessToken, required this.role});

  factory AccessTokenResponse.fromJson(Map<String, dynamic> json) {
    return AccessTokenResponse(
      accessToken: json['access_token'],
      role: json['role'],
    );
  }
}
