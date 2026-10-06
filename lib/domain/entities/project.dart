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
  final int sortOrder;

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
    this.sortOrder = 0,
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
    int? sortOrder,
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
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  /// Serialize to the snake_case JSON shape used by the WebDAV snapshot
  /// and (historically) the Appwrite schema.
  Map<String, dynamic> toJson() => {
        'id': id,
        'parent_id': parentId,
        'name': name,
        'description': description,
        'color': color,
        'icon': icon,
        'start_date': startDate?.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'is_default': isDefault,
        'sort_order': sortOrder,
      };
}