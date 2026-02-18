// ignore_for_file: file_names, unused_local_variable, avoid_print, non_constant_identifier_names

import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:multiwordexpressionworkbench/services/secureStorageService.dart';

import '../models/annotation_model.dart';
import 'dart:html' as html;

class AnnotationService {
  Future<bool> addAnnotation(List<Annotation> annotations) async {
    var url = Uri.parse(
        'https://www.cfilt.iitb.ac.in/annotation_tool_apis/annotation/add_annotations');
    var token = await SecureStorage().readSecureData("jwtToken");
    var body = json.encode(annotations.map((a) => a.toJson()).toList());
    print("Called");

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: body,
    );
    if (response.statusCode == 201) {
      return true;
    } else {
      print("Error: ${response.statusCode} - ${response.body}");
      return false;
    }
  }

  Future<bool> clearAnnotation(int sentenceId, int projectId) async {
    var url = Uri.parse(
        'https://www.cfilt.iitb.ac.in/annotation_tool_apis/annotation/clear_annotations');
    var token = await SecureStorage().readSecureData("jwtToken");

    final body = json.encode({
      "sentence_id": sentenceId,
      "project_id": projectId,
    });

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: body,
    );

    if (response.statusCode == 200) {
      return true;
    } else {
      print(
        "Clear Annotation Error: ${response.statusCode} - ${response.body}",
      );
      return false;
    }
  }

  Future<List<Annotation>> fetchAnnotations(int sentenceId) async {
    print(sentenceId);
    var url = Uri.parse(
        'https://www.cfilt.iitb.ac.in/annotation_tool_apis/annotation/get_annotations');
    var token = await SecureStorage().readSecureData("jwtToken");
    var body = json.encode({"sentence_id": sentenceId});

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: body,
    );

    if (response.statusCode == 200) {
      List<dynamic> jsonResponse = json.decode(response.body);
      return jsonResponse.map((data) => Annotation.fromJson(data)).toList();
    } else {
      throw Exception('Failed to load annotations');
    }
  }

  Future<bool> deleteProject(int projectId) async {
    var url = Uri.parse(
      'https://www.cfilt.iitb.ac.in/annotation_tool_apis/project/delete_project/$projectId',
    );
    var token = await SecureStorage().readSecureData("jwtToken");

    final response = await http.delete(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    return response.statusCode == 200;
  }

  Future<void> downloadAnnotationsXML(
    int project_id,
    String project_title,
  ) async {
    var url = Uri.parse(
      'https://www.cfilt.iitb.ac.in/annotation_tool_apis/annotation/download_annotations_xml',
    );
    var token = await SecureStorage().readSecureData("jwtToken");
    var body = json.encode({"project_id": project_id});

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: body,
    );

    if (response.statusCode == 200) {
      // Use the 'dart:html' library to create an anchor element and trigger the download
      final blob = html.Blob([response.bodyBytes]);
      final downloadUrl = html.Url.createObjectUrlFromBlob(
        blob,
      ); // Changed variable name to avoid conflict
      final anchor = html.AnchorElement(
        href: downloadUrl,
      ) // Use the new variable name here
        ..setAttribute(
          "download",
          "project_${project_title}_annotations.xml",
        )
        ..click();
      html.Url.revokeObjectUrl(downloadUrl); // And here
    } else {
      // Handle error or unsuccessful download here, e.g., show an alert or a message to the user
      print(
        'Error downloading file: Server responded with status code ${response.statusCode}.',
      );
    }
  }

  Future<void> downloadAnnotationsTXT(
    int project_id,
    String project_title,
  ) async {
    var url = Uri.parse(
      'https://www.cfilt.iitb.ac.in/annotation_tool_apis/annotation/download_annotations_text',
    );
    var token = await SecureStorage().readSecureData("jwtToken");
    var body = json.encode({"project_id": project_id});

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: body,
    );

    if (response.statusCode == 200) {
      // Use the 'dart:html' library to create an anchor element and trigger the download
      final blob = html.Blob([response.bodyBytes]);
      final downloadUrl = html.Url.createObjectUrlFromBlob(
        blob,
      ); // Changed variable name to avoid conflict
      final anchor = html.AnchorElement(
        href: downloadUrl,
      ) // Use the new variable name here
        ..setAttribute(
          "download",
          "project_${project_title}_annotations.txt",
        )
        ..click();
      html.Url.revokeObjectUrl(downloadUrl); // And here
    } else {
      // Handle error or unsuccessful download here, e.g., show an alert or a message to the user
      print(
        'Error downloading file: Server responded with status code ${response.statusCode}.',
      );
    }
  }

  Future<bool> updateAnnotation(Annotation annotation) async {
    assert(annotation.id != null);
    final url = Uri.parse(
        'https://www.cfilt.iitb.ac.in/annotation_tool_apis/annotation.id}');
    final response = await http.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(annotation.toJson()),
    );
    return response.statusCode == 200;
  }

  Future<int?> fetchLastAnnotatedSentence(int projectId) async {
    final url = Uri.parse(
        'https://www.cfilt.iitb.ac.in/annotation_tool_apis/annotation/last_progress');

    final token = await SecureStorage().readSecureData("jwtToken");

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({"project_id": projectId}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      // If user has not annotated anything yet
      if (data["sentence_id"] == null) {
        return null;
      }

      return data["sentence_id"] as int;
    } else {
      print("Fetch progress failed: ${response.statusCode} - ${response.body}");
      return null;
    }
  }

  Future<bool> updateSentenceText(int sentenceId, String newText) async {
    final url = Uri.parse(
      'https://www.cfilt.iitb.ac.in/annotation_tool_apis/sentence/update_sentence_text',
    );

    final token = await SecureStorage().readSecureData("jwtToken");

    final response = await http.put(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        "sentence_id": sentenceId,
        "new_text": newText,
      }),
    );

    if (response.statusCode == 200) {
      return true;
    } else {
      print(
        "Update Sentence Error: ${response.statusCode} - ${response.body}",
      );
      return false;
    }
  }

  Future<bool> markSentenceComplete(int sentenceId) async {
    final url = Uri.parse(
      'https://www.cfilt.iitb.ac.in/annotation_tool_apis/sentence/mark_sentence_complete',
    );

    final token = await SecureStorage().readSecureData("jwtToken");

    final response = await http.put(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        "sentence_id": sentenceId,
      }),
    );

    return response.statusCode == 200;
  }
}
