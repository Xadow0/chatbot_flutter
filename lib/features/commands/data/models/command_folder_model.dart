import '../../domain/entities/command_folder_entity.dart';

class CommandFolderModel extends CommandFolderEntity {
  const CommandFolderModel({
    required super.id,
    required super.name,
    super.icon,
    super.order,
    required super.createdAt,
  });

  factory CommandFolderModel.fromJson(Map<String, dynamic> json) {
    return CommandFolderModel(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String?,
      order: json['order'] as int? ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'order': order,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CommandFolderModel.fromEntity(CommandFolderEntity entity) {
    return CommandFolderModel(
      id: entity.id,
      name: entity.name,
      icon: entity.icon,
      order: entity.order,
      createdAt: entity.createdAt,
    );
  }

  @override
  CommandFolderModel copyWith({
    String? id,
    String? name,
    String? icon,
    int? order,
    DateTime? createdAt,
  }) {
    return CommandFolderModel(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      order: order ?? this.order,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}