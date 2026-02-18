class Sentence {
  String content;
  int id;
  bool isAnnotated;
  bool? isCompleted;

  Sentence({
    required this.content,
    required this.id,
    required this.isAnnotated,
    required this.isCompleted,
  });

  factory Sentence.fromJson(Map<String, dynamic> json) {
    return Sentence(
      content: json['content'],
      id: json['id'],
      isAnnotated: json['is_annotated'],
      isCompleted: json['is_completed'],
    );
  }
}
