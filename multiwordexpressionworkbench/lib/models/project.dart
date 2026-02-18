class Project {
  final String description;
  final int id;
  final String language;
  String title;
  int completed;
  int total;
  int mweCount;

  Project({
    required this.description,
    required this.id,
    required this.language,
    required this.title,
    required this.completed,
    required this.total,
    required this.mweCount,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      description: json['description'] ?? '',
      id: json['id'],
      language: json['language'] ?? '',
      title: json['title'] ?? '',
      completed: json['completed'] ?? 0,
      total: json['total'] ?? 0,
      mweCount: json['mwe_count'] ?? 0,
    );
  }
}
