// ignore_for_file: non_constant_identifier_names, avoid_print

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/sentence_model.dart';
import '../services/secureStorageService.dart';

Future<List<Sentence>> FetchSentenceItems(int projectId) async {
  var url = Uri.parse(
      'https://www.cfilt.iitb.ac.in/annotation_tool_apis/sentence/get_sentences');
  var token = await SecureStorage().readSecureData("jwtToken");

  var body = {"project_id": projectId};
  String bodyJson = jsonEncode(body);

  var header = {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json; charset=UTF-8',
  };

  final response = await http.post(url, headers: header, body: bodyJson);

  print(response);

  if (response.statusCode == 200) {
    final parsed = json.decode(response.body).cast<Map<String, dynamic>>();
    return parsed.map<Sentence>((json) => Sentence.fromJson(json)).toList();
  } else {
    throw Exception('Failed to load Sentence items');
  }
}

// Future<List<Sentence>> fetchSentencesByUser(int userId, int projectId) async {
//   var url = Uri.parse('https://www.cfilt.iitb.ac.in/annotation_tool_apis/sentence/get_sentences_by_user');
//   var token = await SecureStorage().readSecureData("jwtToken");

//   var body = {"user_id": userId, "project_id": projectId};
//   String bodyJson = jsonEncode(body);

//   var headers = {
//     'Authorization': 'Bearer $token',
//     'Content-Type': 'application/json; charset=UTF-8',
//   };

//   final response = await http.post(url, headers: headers, body: bodyJson);

//   print(response);

//   if (response.statusCode == 200) {
//     final parsed =
//         json.decode(response.body)['sentences'].cast<Map<String, dynamic>>();
//     return parsed.map<Sentence>((json) => Sentence.fromJson(json)).toList();
//   } else if (response.statusCode == 404) {
//     print("No sentences found for this user and project.");
//     return [];
//   } else {
//     throw Exception('Failed to load sentences for user and project');
//   }
// }

Future<List<Map<String, dynamic>>> searchAnnotationsWithResults(
  String query,
  String? language,
) async {
  // API endpoint
  var url = Uri.parse(
      'https://www.cfilt.iitb.ac.in/annotation_tool_apis/annotation/search_annotations');

  var token = await SecureStorage().readSecureData("jwtToken");

  // Set up headers
  var headers = {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  // Construct request body
  var body = jsonEncode({
    'word_phrase': query,
    if (language != null)
      'language': language, // Include language only if provided
  });

  // Send the POST request
  final response = await http.post(url, headers: headers, body: body);

  if (response.statusCode == 200) {
    // Parse the JSON response into a list of annotations
    return List<Map<String, dynamic>>.from(jsonDecode(response.body));
  } else if (response.statusCode == 404) {
    // No annotations found, return an empty list
    return [];
  } else {
    // Handle error
    throw Exception('Failed to fetch annotations: ${response.body}');
  }
}
