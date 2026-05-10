class Project {
  final String id;
  final String? parentId;
  final String name;
  final String color;
  final String icon;
  final DateTime createdAt;

  const Project({
    required this.id,
    this.parentId,
    required this.name,
    required this.color,
    required this.icon,
    required this.createdAt,
  });

  Project copyWith({
    String? id,
    String? parentId,
    String? name,
    String? color,
    String? icon,
    DateTime? createdAt,
  }) {
    return Project(
      id: id ?? this.id,
      parentId: parentId ?? this.parentId,
      name: name ?? this.name,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}