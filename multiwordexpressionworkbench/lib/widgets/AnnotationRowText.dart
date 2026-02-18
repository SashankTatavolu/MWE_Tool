// ignore_for_file: file_names

import 'package:flutter/material.dart';

class AnnotationRowText extends StatefulWidget {
  const AnnotationRowText({super.key});

  @override
  State<AnnotationRowText> createState() => _AnnotationRowTextState();
}

class _AnnotationRowTextState extends State<AnnotationRowText> {
  Color rowColor = Colors.white;

  @override
  Widget build( BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: rowColor,
          borderRadius: BorderRadius.circular(5)
      ),
      padding: const EdgeInsets.all(4),
      margin: const EdgeInsets.all(4),
      child: TextField(
        decoration: const InputDecoration(
            border: InputBorder.none
        ),
        controller: TextEditingController(
            text:
            "Sample Text"),
        readOnly: true,
        showCursor: false,

        onTap: (){
          setState(() {
            rowColor = Colors.yellow;
          });
        },
      ),
    );
  }
}
