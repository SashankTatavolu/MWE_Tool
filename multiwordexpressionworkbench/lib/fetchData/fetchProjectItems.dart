// ignore_for_file: non_constant_identifier_names, avoid_print

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:multiwordexpressionworkbench/fetchData/fetchSentenceItems.dart';
import 'package:multiwordexpressionworkbench/models/sentence_model.dart';

import '../models/project.dart';
import '../services/secureStorageService.dart';

Future<List<Project>> FetchProjectItems() async {
  var url = Uri.parse(
      'https://www.cfilt.iitb.ac.in/annotation_tool_apis/project/get_project_list');
  var token = await SecureStorage().readSecureData("jwtToken");

  var header = {'Authorization': 'Bearer $token'};

  final response = await http.get(url, headers: header);

  if (response.statusCode == 200) {
    print(response.body);
    final parsed = json.decode(response.body).cast<Map<String, dynamic>>();
    return parsed.map<Project>((json) => Project.fromJson(json)).toList();
  } else {
    throw Exception('Failed to load project items');
  }
}

Future<List<Map<String, dynamic>>> fetchUsersByOrganization(
  String organizationName,
) async {
  var url = Uri.parse(
    'https://www.cfilt.iitb.ac.in/annotation_tool_apis/user/organisation/$organizationName',
  );
  var token = await SecureStorage().readSecureData("jwtToken");

  var headers = {'Authorization': 'Bearer $token'};

  final response = await http.get(url, headers: headers);

  if (response.statusCode == 200) {
    final List<dynamic> parsed = json.decode(response.body);
    print(response.body);

    // Ensure the response is a list of maps with 'id', 'name', and 'languages'
    return parsed
        .map(
          (user) => {
            'id': user['id'],
            'name': user['name'],
            'languages': user['languages'], // Include languages
          },
        )
        .toList();
  } else {
    throw Exception('Failed to load users for organization $organizationName');
  }
}

Future<void> assignSentencesToUsers(
  int projectId,
  List<Map<String, dynamic>> assignments,
) async {
  var url = Uri.parse(
      'https://www.cfilt.iitb.ac.in/annotation_tool_apis/sentence/assign_sentences');
  var token = await SecureStorage().readSecureData("jwtToken");

  var headers = {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  var body = json.encode({
    "project_id": projectId,
    "assignments": assignments, // List of {user_id, sentence_ids}
  });

  try {
    final response = await http.post(url, headers: headers, body: body);

    if (response.statusCode == 200) {
      print('Sentences assigned successfully for project $projectId');
    } else {
      print('Failed to assign sentences: ${response.body}');
      throw Exception('Failed to assign sentences');
    }
  } catch (e) {
    print('Error assigning sentences: $e');
    throw Exception('Error occurred while assigning sentences');
  }
}

Future<List<Map<String, dynamic>>> searchAnnotationsWithProjectFilter(
  String annotationText,
  String? projectTitle,
) async {
  var url = Uri.parse(
    'https://www.cfilt.iitb.ac.in/annotation_tool_apis/annotation/search_sentences_by_annotation',
  );

  var token = await SecureStorage().readSecureData("jwtToken");

  var headers = {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  // Construct the request body
  var body = jsonEncode({
    'annotation_text': annotationText,
    'project_title':
        projectTitle ?? '', // Send empty string if no project is selected
  });

  // Send the POST request with body
  final response = await http.post(url, headers: headers, body: body);

  if (response.statusCode == 200) {
    List<dynamic> data = json.decode(response.body);
    if (data.isNotEmpty) {
      return data.map((result) {
        return {
          'word_phrase': result['word_phrase'],
          'sentence_text': result['sentence_text'],
          'project_title': result['project_title'], // Include project title
          'sentence_id': result['sentence_id'], // Include sentence ID
        };
      }).toList();
    } else {
      return []; // Return empty list if no results found
    }
  } else {
    throw Exception('Failed to search annotations');
  }
}

Future<List<int>> fetchSentenceIds(int projectId) async {
  var url = Uri.parse(
      'https://www.cfilt.iitb.ac.in/annotation_tool_apis/sentence/get_sentence_ids');
  var token = await SecureStorage().readSecureData("jwtToken");

  var headers = {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  var body = json.encode({"project_id": projectId});

  final response = await http.post(url, headers: headers, body: body);

  if (response.statusCode == 200) {
    var jsonResponse = json.decode(response.body);
    List<int> sentenceIds = List<int>.from(jsonResponse["sentence_ids"]);
    return sentenceIds;
  } else {
    throw Exception('Failed to fetch sentence IDs for project $projectId');
  }
}

Future<List<int>> fetchAssignedSentenceIds() async {
  var url = Uri.parse(
    'https://www.cfilt.iitb.ac.in/annotation_tool_apis/sentence/check_assigned_sentences',
  );
  var token = await SecureStorage().readSecureData("jwtToken");

  var headers = {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  final response = await http.get(url, headers: headers);

  if (response.statusCode == 200) {
    var jsonResponse = json.decode(response.body);
    if (jsonResponse.containsKey("assigned_sentence_ids")) {
      List<int> assignedSentenceIds = List<int>.from(
        jsonResponse["assigned_sentence_ids"],
      );
      return assignedSentenceIds;
    }
    return [];
  } else {
    throw Exception('Failed to fetch assigned sentence IDs');
  }
}

Future<Map<String, dynamic>> assignUserToProject(
  int projectId,
  int userId, {
  bool force = false,
}) async {
  var url = Uri.parse(
    'https://www.cfilt.iitb.ac.in/annotation_tool_apis/project/assign_user_to_project/$projectId',
  );

  var token = await SecureStorage().readSecureData("jwtToken");

  var headers = {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  var body = json.encode({
    "user_id": userId,
    "force": force, // 🔥 important
  });

  final response = await http.post(url, headers: headers, body: body);

  final data = jsonDecode(response.body);

  return {"statusCode": response.statusCode, "data": data};
}

Future<bool> isUserAssigned(int projectId) async {
  // Build the API endpoint
  var url = Uri.parse(
    'https://www.cfilt.iitb.ac.in/annotation_tool_apis/project/is_user_assigned/$projectId',
  );

  // Retrieve the JWT token from secure storage
  var token = await SecureStorage().readSecureData("jwtToken");

  // Set up the headers with the token
  var headers = {'Authorization': 'Bearer $token'};

  // Send the GET request
  final response = await http.get(url, headers: headers);

  // Check the response status and parse the result
  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    return data['is_assigned'] ??
        false; // Return true/false based on the response
  } else {
    // Handle errors by throwing an exception or logging the error
    throw Exception('Failed to check assignment status for project $projectId');
  }
}

Future<Map<String, List<int>>> fetchSentenceStatus(int projectId) async {
  var url = Uri.parse(
      'https://www.cfilt.iitb.ac.in/annotation_tool_apis/sentence/get_sentence_status');
  var token = await SecureStorage().readSecureData("jwtToken");

  var headers = {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  var body = json.encode({"project_id": projectId});

  final response = await http.post(url, headers: headers, body: body);

  if (response.statusCode == 200) {
    var jsonResponse = json.decode(response.body);
    return {
      "assigned_sentences": List<int>.from(jsonResponse["assigned_sentences"]),
      "unassigned_sentences": List<int>.from(
        jsonResponse["unassigned_sentences"],
      ),
    };
  } else {
    throw Exception('Failed to fetch sentence status for project $projectId');
  }
}

Future<int> fetchAnnotatedSentences(int projectId) async {
  // Replace this with your actual data-fetching logic
  List<Sentence> sentences = await FetchSentenceItems(projectId);
  return sentences.where((sentence) => sentence.isAnnotated == true).length;
}

Future<int> fetchTotalSentences(int projectId) async {
  // Fetch the sentences for the project (you can use your existing method to fetch sentences)
  List<Sentence> sentences = await FetchSentenceItems(projectId);
  return sentences.length; // Return the total number of sentences
}

Future<List<Map<String, dynamic>>> searchAnnotations(String wordPhrase) async {
  var url = Uri.parse(
      'https://www.cfilt.iitb.ac.in/annotation_tool_apis/annotation/search_annotations');

  var token = await SecureStorage().readSecureData("jwtToken");

  var headers = {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  var body = jsonEncode({
    'word_phrase': wordPhrase, // Only sending word_phrase
  });

  final response = await http.post(url, headers: headers, body: body);

  if (response.statusCode == 200) {
    List<dynamic> data = json.decode(response.body);
    if (data.isNotEmpty) {
      return data.map((annotation) {
        return {
          'id': annotation['id'],
          'word_phrase': annotation['word_phrase'],
          'annotation': annotation['annotation'],
          'sentence_text': annotation['sentence_text'],
          'sentence_id': annotation['sentence_id'], // Include sentence ID
          'project_id': annotation['project_id'], // Include project ID
          'project_title': annotation['project_title'], // Include project title
        };
      }).toList();
    } else {
      return [];
    }
  } else {
    throw Exception('Failed to search annotations');
  }
}

Future<void> updateProjectTitle(int projectId, String newTitle) async {
  var url = Uri.parse(
    'https://www.cfilt.iitb.ac.in/annotation_tool_apis/project/update_project_title/$projectId',
  );
  var token = await SecureStorage().readSecureData("jwtToken");

  var headers = {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  var body = json.encode({'title': newTitle});

  final response = await http.put(url, headers: headers, body: body);

  if (response.statusCode == 200) {
    print('Project title updated successfully');
  } else {
    print('Failed to update project title: ${response.body}');
    throw Exception('Failed to update project title');
  }
}

Future<Map<String, dynamic>> registerUser(
  String name,
  String email,
  String password,
  String language,
  String role,
  String organisation,
) async {
  try {
    var url = Uri.parse(
        'https://www.cfilt.iitb.ac.in/annotation_tool_apis/user/register');
    var body = {
      "name": name,
      "email": email,
      "password": password,
      "language": language,
      "role": role,
      "organisation": organisation,
    };

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode(body),
    );

    final responseData = jsonDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final user = responseData['user'];

      await SecureStorage().writeSecureData('user_id', user['id'].toString());
      await SecureStorage().writeSecureData('user_email', user['email']);
      await SecureStorage().writeSecureData('user_name', user['name']);

      return {'success': true, 'user': user};
    } else {
      // Handle different error cases
      String errorMessage = 'Registration failed';
      String suggestion = 'Please try again later';

      if (response.statusCode == 409) {
        errorMessage = responseData['message'] ?? 'User already exists';
        suggestion = responseData['suggestion'] ??
            'Try using a different email or username';
      } else if (response.statusCode == 400) {
        errorMessage = 'Invalid registration data';
        suggestion = 'Please check all fields and try again';
      }

      return {
        'success': false,
        'error': errorMessage,
        'suggestion': suggestion,
        'statusCode': response.statusCode,
      };
    }
  } catch (e) {
    return {
      'success': false,
      'error': 'Network error occurred',
      'suggestion': 'Please check your internet connection and try again',
      'exception': e.toString(),
    };
  }
}
