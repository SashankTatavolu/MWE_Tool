// ignore_for_file: sized_box_for_whitespace

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:multiwordexpressionworkbench/fetchData/fetchProjectItems.dart';
import 'package:multiwordexpressionworkbench/services/secureStorageService.dart';
import 'package:multiwordexpressionworkbench/ui/home_page.dart';
import '../models/annotation_model.dart';
import '../models/project.dart';
import '../models/sentence_model.dart';
import '../services/annotationService.dart';
import 'package:pdfrx/pdfrx.dart';

class AnnotateSentencePage extends StatefulWidget {
  final List<Sentence> sentences;
  final Project project;

  const AnnotateSentencePage(
      {super.key, required this.sentences, required this.project});

  @override
  State<AnnotateSentencePage> createState() => _AnnotateSentencePageState();
}

class _AnnotateSentencePageState extends State<AnnotateSentencePage> {
  List<Annotation> annotationList = [];
  int selectedIndex = -1;
  TextEditingController? _controller;
  int currentPage = 0;
  final int sentencesPerPage = 6;
  List<int> assignedSentenceIds = [];
  bool isValidTextSelected = false;
  String selectedText = "";
  final List<String> _dropdownAnnotationValues = [
    "Noun Compound",
    "Reduplicated",
    "Echo",
    "Opaque",
    "Opaque-Idiom"
  ];
  String? _selectedValue;
  bool unsavedChanges = false;
  AnnotationService annotationService = AnnotationService();
  String _selectedType = 'Multiword Expression';
  String? userRole;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();

    fetchAssignedSentenceIds().then((ids) {
      setState(() {
        assignedSentenceIds = ids;
      });
    });

    SecureStorage().readSecureData('role').then((role) {
      setState(() {
        userRole = role;
      });
    });
    _restoreProgress();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _checkSelectedText(TextEditingController controller) {
    if (controller.selection.isValid) {
      String selectedText = controller.text
          .substring(controller.selection.start, controller.selection.end);
      if (selectedText.trim().split(RegExp(r'\s+')).length > 1) {
        print("Selected text: $selectedText");
        isValidTextSelected = true;
        setState(() {
          this.selectedText = selectedText;
        });
      } else {
        setState(() {
          isValidTextSelected = false;
        });
      }
    }
  }

  Future<void> _restoreProgress() async {
    final lastSentenceId = await annotationService.fetchLastAnnotatedSentence(
      widget.project.id,
    );

    if (lastSentenceId == null) return;

    final globalIndex = widget.sentences.indexWhere(
      (s) => s.id == lastSentenceId,
    );

    if (globalIndex == -1) return;

    final restoredPage = globalIndex ~/ sentencesPerPage;
    final restoredIndex = globalIndex % sentencesPerPage;

    final sentence = widget.sentences[globalIndex];

    final existingAnnotations =
        await annotationService.fetchAnnotations(sentence.id);

    setState(() {
      currentPage = restoredPage;
      selectedIndex = restoredIndex;
      _controller?.text = sentence.content;
      annotationList = existingAnnotations;
      isValidTextSelected = false;
      unsavedChanges = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = (widget.sentences.length / sentencesPerPage).ceil();
    final currentPageSentences = getCurrentPageSentences();

    return Scaffold(
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.all(10),
          child: Column(
            children: [
              _buildProjectHeader(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildMainContent(currentPageSentences, pages),
                  _buildAnnotationsSidebar(),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  List<Sentence> getCurrentPageSentences() {
    final startIndex = currentPage * sentencesPerPage;
    final endIndex =
        min(startIndex + sentencesPerPage, widget.sentences.length);
    return widget.sentences.getRange(startIndex, endIndex).toList();
  }

  Widget _buildMainContent(List<Sentence> currentPageSentences, int pages) {
    return Row(
      children: [
        Container(
          width: 900,
          height: 600,
          child: Column(
            children: [
              _buildSentenceList(currentPageSentences),
              isValidTextSelected && userRole != 'Admin'
                  ? _buildAnnotationControls()
                  : _buildSelectTextPrompt(),
              _buildPaginationControls(pages),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnnotationControls() {
    return Container(
      child: Column(
        children: [
          Container(
            child: Row(
              children: [
                Text("Annotation Type"),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text("Selected Text : $selectedText"),
              _buildDropdownAnnotation(),
              _buildAddButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildRadioTile(String title) {
    return ListTile(
      title: Text(title),
      leading: Radio<String>(
        value: title,
        groupValue: _selectedType,
        onChanged: (String? value) {
          setState(() {
            _selectedType = value!;
          });
        },
      ),
    );
  }

  Widget _buildDropdownAnnotation() {
    return DropdownButton<String>(
      value: _selectedValue,
      hint: const Text("Select Annotation"),
      items: _dropdownAnnotationValues.map((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
      onChanged: (newValue) {
        setState(() {
          _selectedValue = newValue;
        });
      },
    );
  }

  Widget _buildAddButton() {
    return ElevatedButton(
      onPressed: _onAddButtonPressed,
      child: Text("Add"),
    );
  }

  void _onAddButtonPressed() {
    if (_selectedValue != null) {
      Annotation annotation = Annotation(
        wordPhrase: selectedText,
        annotation: _selectedValue!,
        sentenceId: widget
            .sentences[selectedIndex + (currentPage * sentencesPerPage)].id,
        projectId: widget.project.id,
      );
      print(annotation.toJson());
      setState(() {
        unsavedChanges = true;
        annotationList.add(annotation);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please Select Annotation")),
      );
    }
  }

  Widget _buildSelectTextPrompt() {
    return Text(
      "Select at least two words to Annotate",
      style: TextStyle(fontWeight: FontWeight.bold),
    );
  }

  Widget _buildAnnotationsSidebar() {
    return Container(
      width: 400,
      height: 500,
      margin: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildAnnotationsList(),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildAnnotationsList() {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(),
        ),
        child: ListView.builder(
          itemCount: annotationList.length,
          itemBuilder: (context, index) {
            return _buildAnnotationListItem(index);
          },
        ),
      ),
    );
  }

  Widget _buildAnnotationListItem(int index) {
    final annotation = annotationList[index];

    final TextEditingController wordPhraseController =
        TextEditingController(text: annotation.wordPhrase);

    wordPhraseController.addListener(() {
      annotation.wordPhrase = wordPhraseController.text;
    });

    bool isEditingDisabled = annotation.annotation.startsWith('ENAMEX') ||
        annotation.annotation.startsWith('NUMEX') ||
        annotation.annotation.startsWith('TIMEX');

    return ListTile(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: wordPhraseController,
                  enabled: !isEditingDisabled,
                  onSubmitted: (newValue) {
                    if (!isEditingDisabled) {
                      setState(() {
                        annotation.wordPhrase = newValue;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: Text(
                  annotation.annotation,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          if (annotationList.length == 1)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                "Hint: Use the Reset button to clear annotations.",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
      leading: Text(
        (index + 1).toString(),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      trailing: (annotation.annotation.startsWith('ENAMEX') ||
              annotation.annotation.startsWith('NUMEX') ||
              annotation.annotation.startsWith('TIMEX') ||
              annotationList.length == 1)
          ? null // Hide delete button
          : IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _deleteAnnotation(index),
            ),
    );
  }

  void _deleteAnnotation(int index) {
    setState(() {
      annotationList.removeAt(index);
    });
  }

  Widget _buildActionButtons() {
    if (userRole == 'Admin') return Container(); // 👈 completely hide for admin
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildSubmitButton(),
        _buildResetButton(),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: userRole == 'Admin' ? null : _handleSubmit,
      child: const Text("Submit"),
    );
  }

  void _handleSubmit() async {
    bool submitStatus = await annotationService.addAnnotation(annotationList);

    if (!submitStatus) return;

    final globalIndex = selectedIndex + (currentPage * sentencesPerPage);

    widget.sentences[globalIndex].isAnnotated = true;

    final nextGlobalIndex = globalIndex + 1;

    setState(() {
      unsavedChanges = false;
      annotationList.clear();
      isValidTextSelected = false;
    });

    if (nextGlobalIndex < widget.sentences.length) {
      final nextPage = nextGlobalIndex ~/ sentencesPerPage;
      final nextIndex = nextGlobalIndex % sentencesPerPage;

      final nextSentence = widget.sentences[nextGlobalIndex];
      final annotations =
          await annotationService.fetchAnnotations(nextSentence.id);

      setState(() {
        currentPage = nextPage;
        selectedIndex = nextIndex;
        _controller?.text = nextSentence.content;
        annotationList = annotations;
      });
    }
  }

  Widget _buildResetButton() {
    return ElevatedButton(
      onPressed: _handleReset,
      child: const Text("Reset"),
    );
  }

  void _handleReset() async {
    if (selectedIndex == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No sentence selected to reset.")),
      );
      return;
    }

    final sentence =
        widget.sentences[selectedIndex + (currentPage * sentencesPerPage)];
    final projectId = widget.project.id;

    final success =
        await annotationService.clearAnnotation(sentence.id, projectId);

    if (success) {
      setState(() {
        annotationList = [];
        sentence.isAnnotated = false; // Update UI status
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Annotations cleared successfully.")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to clear annotations.")),
      );
    }
  }

  void _handleSentenceUpdate() async {
    if (selectedIndex == -1) return;

    final globalIndex = selectedIndex + (currentPage * sentencesPerPage);
    final sentence = widget.sentences[globalIndex];

    print("----- DEBUG UPDATE -----");
    print("User Role: $userRole");
    print("Sentence ID: ${sentence.id}");
    print("Assigned Sentence IDs: $assignedSentenceIds");
    print(
        "Is sentence assigned to user? ${assignedSentenceIds.contains(sentence.id)}");

    final newText = _controller?.text.trim();

    final success = await annotationService.updateSentenceText(
      sentence.id,
      newText!,
    );

    print("Update response success: $success");

    if (success) {
      setState(() {
        sentence.content = newText;
        sentence.isAnnotated = false;
        annotationList.clear();
        unsavedChanges = false;
        isValidTextSelected = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Sentence updated successfully")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to update sentence")),
      );
    }
  }

  void _handleMarkComplete() async {
    if (selectedIndex == -1) return;

    final globalIndex = selectedIndex + (currentPage * sentencesPerPage);
    final sentence = widget.sentences[globalIndex];

    final success = await annotationService.markSentenceComplete(sentence.id);

    if (success) {
      setState(() {
        sentence.isCompleted = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Sentence marked as complete")),
      );
    }
  }

  Widget _buildProjectHeader() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [Text(widget.project.title), Text(widget.project.language)],
      );

  Widget _buildSentenceList(List<Sentence> sentences) => Expanded(
        child: ListView.builder(
          itemCount: sentences.length,
          itemBuilder: (context, index) {
            return _buildSentenceTile(index, sentences);
          },
        ),
      );

  Widget _buildSentenceTile(int index, List<Sentence> sentences) {
    final isSelected = selectedIndex == index;
    final sentence = sentences[index];
    return ListTile(
      onTap: () async {
        if (unsavedChanges) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  "Please submit the annotations, before moving on to next sentence")));
        } else {
          List<Annotation> existingAnnotationList =
              await annotationService.fetchAnnotations(sentence.id);
          print(existingAnnotationList);
          setState(() {
            selectedIndex = index;
            isValidTextSelected = false;
            _controller?.text = sentence.content;
            annotationList = existingAnnotationList;
          });
        }
      },
      leading: sentence.isCompleted == true
          ? Icon(Icons.verified, color: Colors.blue)
          : sentence.isAnnotated == true
              ? Icon(Icons.done_outline_outlined, color: Colors.green)
              : null,
      title: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey),
          color: isSelected ? Colors.yellow : Colors.grey[300],
        ),
        padding: const EdgeInsets.all(8),
        constraints: BoxConstraints(minHeight: 60),
        child: isSelected
            ? TextField(
                decoration: const InputDecoration(border: InputBorder.none),
                controller: _controller,
                readOnly: userRole == 'Admin',
                showCursor: userRole != 'Admin',
                autofocus: true,
                maxLines: null, // 👈 This allows it to wrap and grow
                minLines: 1,
                scrollPhysics: const NeverScrollableScrollPhysics(),
              )
            : Text(
                sentence.content,
                style: const TextStyle(fontSize: 16.5),
              ),
      ),
      trailing: selectedIndex == index && userRole != 'Admin'
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  onPressed: () {
                    _checkSelectedText(_controller!);
                  },
                  child: const Text("Identify"),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text("Confirm Update"),
                        content: const Text(
                          "Updating the sentence will remove all annotations. Continue?",
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("Cancel"),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _handleSentenceUpdate();
                            },
                            child: const Text("Yes"),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text("Update"),
                ),
                ElevatedButton(
                  onPressed: _handleMarkComplete,
                  child: const Text("Mark Complete"),
                ),
              ],
            )
          : null,
    );
  }

  Widget _buildPaginationControls(int pages) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: currentPage > 0
                ? () => setState(() {
                      currentPage--;
                      selectedIndex = -1;
                      annotationList.clear();
                      _controller?.clear();
                    })
                : null,
          ),
          Text('Page ${currentPage + 1} of $pages'),
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: currentPage < pages - 1
                ? () => setState(() {
                      currentPage++;
                      selectedIndex = -1;
                      annotationList.clear();
                      _controller?.clear();
                    })
                : null,
          ),
        ],
      );

  void _showPdf(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("PDF Content"),
          content: SizedBox(
            width: 1000,
            height: 600,
            child: PdfViewer.asset(
                'assets/files/MWE Tool - User Guidelines.pdf'), // Update path as necessary
          ),
          actions: <Widget>[
            TextButton(
              child: const Text("Close"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showPDF(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("PDF Content"),
          content: SizedBox(
            width: 1000,
            height: 600,
            child: PdfViewer.asset(
                'assets/files/MWE_Guidelines.pdf'), // Update path as necessary
          ),
          actions: <Widget>[
            TextButton(
              child: const Text("Close"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    // Clear any existing user data if needed (optional)
    await SecureStorage().deleteSecureData('jwtToken');
    // Navigate to the login page and remove all previous routes from the stack
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => HomePage()),
      (Route<dynamic> route) => false, // This removes all previous routes
    );
  }

  AppBar _buildAppBar() => AppBar(
        leading: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                // Navigate back to the ProjectsPage
                Navigator.pop(context);
              },
            ),
            Expanded(
              child: Image.asset("images/logo.png", fit: BoxFit.contain),
            ),
          ],
        ),
        toolbarHeight: 100,
        leadingWidth:
            400, // Adjust leading width to accommodate the back button
        backgroundColor: Colors.blue[100],
        title: Row(
          mainAxisAlignment:
              MainAxisAlignment.spaceBetween, // Adjusted alignment
          children: [
            ElevatedButton(
              onPressed: () {
                _showPdf(context);
              },
              child: const Text("Show User Guidelines"),
            ),
            const Text('Multiword Expression Workbench'),
            ElevatedButton(
              onPressed: () {
                _showPDF(context);
              },
              child: const Text("Show Annotation Guidelines"),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisSize: MainAxisSize.min, // Prevents unnecessary space
              children: [
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    _showSearchPopup(context);
                  },
                ),
                const SizedBox(width: 8), // Add spacing between icon and text
                const Text(
                  "Search MWE",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

          Container(
            margin: const EdgeInsets.all(20.0),
            child: ElevatedButton(
              onPressed: () {
                _handleLogout(context);
              },
              child: const Text("Log Out"),
            ),
          ),
          // Search button added to AppBar
        ],
      );

  void _showSearchPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String query = '';
        List<Map<String, dynamic>> results = [];
        bool isLoading = false;
        String? errorMessage;

        Future<void> performSearch() async {
          try {
            isLoading = true;
            errorMessage = null;
            results = await searchAnnotations(
                query); // Now only searching by word_phrase
            isLoading = false;

            if (results.isEmpty) {
              errorMessage = 'No annotations found matching the criteria.';
            }
          } catch (e) {
            isLoading = false;
            errorMessage = 'An error occurred while searching: $e';
          }
        }

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Dialog(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: 500, // Minimum width
                  maxWidth: MediaQuery.of(context).size.width *
                      0.8, // Max 80% of screen width
                ),
                child: IntrinsicWidth(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Search Annotations',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 10),

                            // Search Input Field
                            TextField(
                              onChanged: (value) {
                                query = value;
                              },
                              decoration: const InputDecoration(
                                labelText: 'Search Word/Phrase',
                              ),
                            ),
                            const SizedBox(height: 20),

                            if (isLoading)
                              const Center(child: CircularProgressIndicator()),

                            if (errorMessage != null) ...[
                              const SizedBox(height: 10),
                              Text(errorMessage!,
                                  style: const TextStyle(color: Colors.red)),
                            ],

                            if (results.isNotEmpty) ...[
                              const Text(
                                'Search Results:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 10),

                              // Table inside Scrollable Container
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Table(
                                  border: TableBorder.all(),
                                  columnWidths: const {
                                    0: FixedColumnWidth(120),
                                    1: FixedColumnWidth(120),
                                    2: FixedColumnWidth(120),
                                    3: FixedColumnWidth(150),
                                    4: FixedColumnWidth(100),
                                  },
                                  children: [
                                    // Table Headers
                                    TableRow(
                                      children: [
                                        tableHeaderCell('Word/Phrase'),
                                        tableHeaderCell('Sentence'),
                                        tableHeaderCell('Annotation'),
                                        tableHeaderCell('Project Title'),
                                        tableHeaderCell('Sentence ID'),
                                      ],
                                    ),
                                    // Table Data
                                    for (var annotation in results)
                                      TableRow(
                                        children: [
                                          tableCell(annotation['word_phrase']),
                                          tableCell(
                                              annotation['sentence_text']),
                                          tableCell(annotation['annotation']),
                                          tableCell(
                                              annotation['project_title']),
                                          tableCell(annotation['sentence_id']
                                              .toString()),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Action Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () async {
                              setState(() {
                                isLoading = true;
                                results.clear();
                                errorMessage = null;
                              });
                              await performSearch();
                              setState(() {
                                isLoading = false;
                              });
                            },
                            child: const Text('Search'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

// Helper function for table header cells
  Widget tableHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

// Helper function for table data cells
  Widget tableCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(text),
    );
  }
}
