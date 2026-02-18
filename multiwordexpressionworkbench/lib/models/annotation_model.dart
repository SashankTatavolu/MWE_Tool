class Annotation {
  int? id; // Assuming there's an ID field to identify existing annotations
  String wordPhrase;
  String annotation;
  int sentenceId;
  int projectId;

  Annotation(
      {this.id,
      required this.wordPhrase,
      required this.annotation,
      required this.sentenceId,
      required this.projectId});

  factory Annotation.fromJson(Map<String, dynamic> json) => Annotation(
        id: json['id'],
        wordPhrase: json['word_phrase'],
        annotation: json['annotation'],
        sentenceId: json['sentence_id'],
        projectId: json['project_id'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'word_phrase': wordPhrase,
        'annotation': annotation,
        'sentence_id': sentenceId,
        'project_id': projectId,
      };
}
