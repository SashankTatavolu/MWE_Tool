// // ignore_for_file: must_be_immutable, library_private_types_in_public_api, no_logic_in_create_state, avoid_print, file_names, use_build_context_synchronously

// import 'package:flutter/material.dart';
// import 'package:multiwordexpressionworkbench/services/secureStorageService.dart';
// import 'package:multiwordexpressionworkbench/ui/home_page.dart';

// import '../models/annotation_model.dart';
// import '../models/sentence_model.dart';
// import '../services/annotationService.dart';

// class EditableTextFields extends StatefulWidget {
//   List<Sentence>? sentences;

//   EditableTextFields({super.key, this.sentences});

//   @override
//   _EditableTextFieldsState createState() =>
//       _EditableTextFieldsState(sentences!);
// }

// class _EditableTextFieldsState extends State<EditableTextFields> {
//   List<TextEditingController> controllers = [];
//   int currentPage = 1;
//   final int pageSize = 6;
//   int totalPages = 0;
//   int? selectedField;
//   late int selectedIndex;
//   String selectedText = '';
//   final List<String> _dropdownAnnotationValues = [
//     "Noun Compound",
//     "Reduplicated",
//     "Echo",
//     "Opaque",
//     "Opaque-Idiom"
//   ];
//   String? _selectedValue;
//   final bool _isEnabled = true;
//   bool _enableSubmitAnnotationButton = false;
//   final List<Annotation> _annotationList = [];
//   List<Sentence> sentences;
//   AnnotationService annotationService = AnnotationService();

//   _EditableTextFieldsState(this.sentences);

//   @override
//   void initState() {
//     super.initState();
//     totalPages = (sentences.length / pageSize).ceil();
//     _initializeControllersForPage(currentPage);
//   }

//   void _initializeControllersForPage(int pageNumber) {
//     controllers.clear();
//     int start = (pageNumber - 1) * pageSize;
//     int end = start + pageSize;
//     for (int i = start; i < end && i < sentences.length; i++) {
//       var sent = sentences[i].content;
//       controllers.add(TextEditingController(text: sent));
//     }
//   }

//   @override
//   void dispose() {
//     for (var controller in controllers) {
//       controller.dispose();
//     }
//     super.dispose();
//   }

//   void _checkSelectedText(TextEditingController controller, int index) {
//     if (controller.selection.isValid) {
//       String selectedText = controller.text
//           .substring(controller.selection.start, controller.selection.end);
//       print("Selected text: $selectedText");
//       setState(() {
//         this.selectedText = selectedText;
//         selectedIndex = index;
//       });
//     }
//   }

//   Future<void> _logout(BuildContext context) async {
//     // Navigate to Login Page
//     await SecureStorage().deleteSecureData('jwtToken');
//     Navigator.pushReplacement(
//       context,
//       MaterialPageRoute(builder: (context) => HomePage()),
//     );
//   }

//   Widget _paginationControls() {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         IconButton(
//           icon: const Icon(Icons.arrow_back),
//           onPressed: currentPage > 1
//               ? () {
//                   setState(() {
//                     currentPage--;
//                     _initializeControllersForPage(currentPage);
//                   });
//                 }
//               : null,
//         ),
//         for (int i = 1; i <= totalPages; i++)
//           TextButton(
//             onPressed: () {
//               setState(() {
//                 currentPage = i;
//                 _initializeControllersForPage(currentPage);
//               });
//             },
//             child: Text(
//               '$i',
//               style:
//                   TextStyle(color: currentPage == i ? Colors.red : Colors.blue),
//             ),
//           ),
//         IconButton(
//           icon: const Icon(Icons.arrow_forward),
//           onPressed: currentPage < totalPages
//               ? () {
//                   setState(() {
//                     currentPage++;
//                     _initializeControllersForPage(currentPage);
//                   });
//                 }
//               : null,
//         ),
//       ],
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         leading: Image.asset(
//           "images/logo.png",
//         ),
//         toolbarHeight: 100,
//         leadingWidth: 300,
//         backgroundColor: Colors.blue[100],
//         title: const Align(
//             alignment: Alignment.center,
//             child: Text('Multiword Expression Workbench')),
//         actions: [
//           Container(
//               margin: const EdgeInsets.all(20.0),
//               child: ElevatedButton(
//                   onPressed: () => _logout(context),
//                   child: const Text("Log Out"))),
//         ],
//       ),
//       body: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//         children: [
//           SizedBox(
//             width: 750,
//             height: 600,
//             child: Column(
//               children: [
//                 Expanded(
//                   child: ListView.builder(
//                     itemCount: controllers.length,
//                     itemBuilder: (context, index) {
//                       return Container(
//                         margin: const EdgeInsets.all(4),
//                         decoration: BoxDecoration(
//                           color: selectedField ==
//                                   index + ((currentPage - 1) * pageSize)
//                               ? Colors.yellow
//                               : Colors.white,
//                           border: Border.all(color: Colors.grey),
//                           borderRadius: BorderRadius.circular(5),
//                         ),
//                         child: ListTile(
//                           title: TextField(
//                             decoration:
//                                 const InputDecoration(border: InputBorder.none),
//                             controller: controllers[index],
//                             readOnly: true,
//                             onTap: () {
//                               setState(() {
//                                 selectedField = index +
//                                     ((currentPage - 1) *
//                                         pageSize); // Adjust index for current page
//                               });
//                             },
//                           ),
//                           //leading: sentences[selectedIndex].isAnnotated?Icon(Icons.circle,color: Colors.green,):Icon(Icons.circle,color: Colors.red,),
//                           trailing: selectedField ==
//                                   index + ((currentPage - 1) * pageSize)
//                               ? ElevatedButton(
//                                   onPressed: () => _checkSelectedText(
//                                       controllers[index], index),
//                                   child: const Text("Annotate"),
//                                 )
//                               : const SizedBox(),
//                         ),
//                       );
//                     },
//                   ),
//                 ),
//                 if (selectedText.trim().split(RegExp(r'\s+')).length >= 2)
//                   Padding(
//                     padding: const EdgeInsets.all(8.0),
//                     child: Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                       children: [
//                         Text('Selected Text: $selectedText',
//                             style: const TextStyle(
//                                 fontSize: 16, fontWeight: FontWeight.bold)),
//                         DropdownButton<String>(
//                           value: _selectedValue,
//                           hint: const Text("Select Annotation"),
//                           items: _dropdownAnnotationValues.map((String value) {
//                             return DropdownMenuItem<String>(
//                               value: value,
//                               child: Text(value),
//                             );
//                           }).toList(),
//                           onChanged: _isEnabled
//                               ? (newValue) {
//                                   // This is where you toggle the enabled state
//                                   setState(() {
//                                     _selectedValue = newValue;
//                                     _enableSubmitAnnotationButton = true;
//                                   });
//                                 }
//                               : null, // Disable dropdown if _isEnabled is false
//                         ),
//                         if (_enableSubmitAnnotationButton)
//                           ElevatedButton(
//                               onPressed: () {
//                                 setState(() {
//                                   _enableSubmitAnnotationButton = false;
//                                   _annotationList.add(Annotation(
//                                     wordPhrase: selectedText,
//                                     annotation: _selectedValue!,
//                                     sentenceId: selectedField! + 1,
//                                     projectId: 1,
//                                   ));
//                                   _selectedValue = null;
//                                 });
//                               },
//                               child: const Text(
//                                 "+ Add",
//                               ))
//                       ],
//                     ),
//                   ),
//                 if (selectedText.trim().split(RegExp(r'\s+')).length < 2)
//                   const Text("Select aleast 2 words to annotate"),
//                 _paginationControls(),
//               ],
//             ),
//           ),
//           Container(
//             padding: const EdgeInsets.all(10),
//             margin: EdgeInsets.all(10),
//             width: 500,
//             height: 600,
//             decoration: BoxDecoration(
//               border: Border.all(color: Colors.blueAccent),
//               borderRadius: BorderRadius.circular(5),
//             ),
//             child: Column(children: [
//               const Text("Annotations",
//                   style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
//               SizedBox(
//                 width: 400,
//                 height: 500,
//                 child: ListView.builder(
//                   itemCount: _annotationList.length,
//                   itemBuilder: (BuildContext context, int index) {
//                     // Convert each map to a list of Widgets to display each key-value pair

//                     return Card(
//                       child: Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceAround,
//                         children: [
//                           TextField(
//                             controller: TextEditingController(
//                               text: _annotationList[index].wordPhrase,
//                             ),
//                             onChanged: (newValue) {
//                               setState(() {
//                                 _annotationList[index].wordPhrase = newValue;
//                               });
//                             },
//                             decoration:
//                                 InputDecoration(border: OutlineInputBorder()),
//                           ),
//                           Text(": ${_annotationList[index].annotation}"),
//                           IconButton(
//                             onPressed: () {
//                               setState(() {
//                                 print(_annotationList[index].sentenceId);
//                                 _annotationList.removeAt(index);
//                               });
//                             },
//                             icon: const Icon(Icons.delete),
//                           )
//                         ],
//                       ),
//                     );
//                   },
//                 ),
//               ),
//               Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
//                 ElevatedButton(
//                     onPressed: () {
//                       setState(() {
//                         sentences[selectedIndex].isAnnotated = true;
//                       });
//                     },
//                     child: const Text("Submit")),
//                 ElevatedButton(
//                   onPressed: () {},
//                   child: const Text("Reset"),
//                 ),
//               ])
//             ]),
//           ),
//         ],
//       ),
//     );
//   }
// }
