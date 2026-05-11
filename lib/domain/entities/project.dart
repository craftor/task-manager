class Project {
  final String id;
  final String? parentId;
  final String name;
  final String? description;
  final String color;
  final String icon;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime createdAt;
  final bool isDefault;

  const Project({
    required this.id,
    this.parentId,
    required this.name,
    this.description,
    required this.color,
    required this.icon,
    this.startDate,
    this.endDate,
    required this.createdAt,
    this.isDefault = false,
  });

  Project copyWith({
    String? id,
    String? parentId,
    String? name,
    String? description,
    String? color,
    String? icon,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? createdAt,
    bool? isDefault,
  }) {
    return Project(
      id: id ?? this.id,
      parentId: parentId ?? this.parentId,
      name: name ?? this.name,
      description: description ?? this.description,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      createdAt: createdAt ?? this.createdAt,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}