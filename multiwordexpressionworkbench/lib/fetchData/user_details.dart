import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:multiwordexpressionworkbench/services/secureStorageService.dart';

Future<bool> sendOtp(String email) async {
  var url = Uri.parse(
      'https://www.cfilt.iitb.ac.in/annotation_tool_apis/user/send-reset-otp');

  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({"email": email}),
  );

  return response.statusCode == 200;
}

Future<bool> verifyOtp(String email, String otp) async {
  var url = Uri.parse(
      'https://www.cfilt.iitb.ac.in/annotation_tool_apis/user/verify-reset-otp');

  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({"email": email, "otp": otp}),
  );

  return response.statusCode == 200;
}

Future<bool> resetPassword(String email, String password) async {
  var url = Uri.parse(
      'https://www.cfilt.iitb.ac.in/annotation_tool_apis/user/reset-password');

  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({"email": email, "new_password": password}),
  );

  return response.statusCode == 200;
}

Future<Map<String, dynamic>?> getUserDetails() async {
  var url = Uri.parse(
      'https://www.cfilt.iitb.ac.in/annotation_tool_apis/user/user-details');

  // Retrieve JWT token
  String? token = await SecureStorage().readSecureData('jwtToken');

  final response = await http.get(
    url,
    headers: {
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token',
    },
  );

  if (response.statusCode == 200) {
    return jsonDecode(response.body); // Return user details
  } else {
    return null; // Error case
  }
}

Future<bool> updateUserProfile({
  required String name,
  required String newEmail,
  required String language,
  required String role,
  required String organisation,
  String? password, // Optional password update
}) async {
  var url = Uri.parse(
      'https://www.cfilt.iitb.ac.in/annotation_tool_apis/user/update-profile');

  // Retrieve JWT token
  String? token = await SecureStorage().readSecureData('jwtToken');

  // Request body
  var body = {
    "name": name,
    "new_email": newEmail,
    "language": language,
    "role": role,
    "organisation": organisation,
  };

  // Include password only if updating it
  if (password != null && password.isNotEmpty) {
    body["password"] = password;
  }

  String bodyJson = jsonEncode(body);

  final response = await http.put(
    url,
    headers: {
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token',
    },
    body: bodyJson,
  );

  if (response.statusCode == 200) {
    return true; // Success
  } else {
    return false; // Failure
  }
}

Future<void> submitFeedback(String feedbackText) async {
  var url = Uri.parse(
      'https://www.cfilt.iitb.ac.in/annotation_tool_apis/user/submit-feedback');
  var token = await SecureStorage().readSecureData("jwtToken");
  var userName = await SecureStorage().readSecureData(
    "user_name",
  ); // Fetch user name

  var headers = {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  var body = jsonEncode({
    'user_name': userName, // Send the user name
    'feedback_text': feedbackText, // Use the correct key
  });

  final response = await http.post(url, headers: headers, body: body);

  if (response.statusCode == 200) {
    print('Feedback submitted successfully');
  } else {
    print('Failed to submit feedback: ${response.body}');
  }
}
