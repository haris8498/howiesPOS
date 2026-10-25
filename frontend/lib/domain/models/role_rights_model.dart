class ModulePermission {
  final String id;
  final String moduleName;
  final String actionName;
  final String description;
  final bool isGranted;
  final bool isSensitive;

  const ModulePermission({
    required this.id,
    required this.moduleName,
    required this.actionName,
    required this.description,
    required this.isGranted,
    this.isSensitive = false,
  });

  ModulePermission copyWith({
    String? id,
    String? moduleName,
    String? actionName,
    String? description,
    bool? isGranted,
    bool? isSensitive,
  }) {
    return ModulePermission(
      id: id ?? this.id,
      moduleName: moduleName ?? this.moduleName,
      actionName: actionName ?? this.actionName,
      description: description ?? this.description,
      isGranted: isGranted ?? this.isGranted,
      isSensitive: isSensitive ?? this.isSensitive,
    );
  }

  factory ModulePermission.fromBackendJson(Map<String, dynamic> json) {
    return ModulePermission(
      id: json['id']?.toString() ?? '',
      moduleName: json['module_name']?.toString() ?? '',
      actionName: json['action_name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      isGranted: json['is_granted'] == true,
      isSensitive: json['is_sensitive'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'module_name': moduleName,
      'action_name': actionName,
      'description': description,
      'is_granted': isGranted,
      'is_sensitive': isSensitive,
    };
  }
}
