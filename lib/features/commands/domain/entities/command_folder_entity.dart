import 'package:equatable/equatable.dart';

class CommandFolderEntity extends Equatable {
  final String id;
  final String name;
  final String? icon;
  final int order;
  final DateTime createdAt;

  const CommandFolderEntity({
    required this.id,
    required this.name,
    this.icon,
    this.order = 0,
    required this.createdAt,
  });

  CommandFolderEntity copyWith({
    String? id,
    String? name,
    String? icon,
    int? order,
    DateTime? createdAt,
  }) {
    return CommandFolderEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      order: order ?? this.order,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, name, icon, order, createdAt];
}