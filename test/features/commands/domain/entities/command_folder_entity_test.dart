import 'package:flutter_test/flutter_test.dart';

// =============================================================================
// CÓDIGO BAJO PRUEBA
// =============================================================================

class CommandFolderEntity {
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
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CommandFolderEntity &&
        other.id == id &&
        other.name == name &&
        other.icon == icon &&
        other.order == order &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(id, name, icon, order, createdAt);
}

// =============================================================================
// TESTS
// =============================================================================

void main() {
  // ---------------------------------------------------------------------------
  // CommandFolderEntity Constructor Tests
  // ---------------------------------------------------------------------------
  group('CommandFolderEntity - constructor', () {
    test('crea instancia con parámetros requeridos', () {
      final createdAt = DateTime(2024, 1, 15, 10, 30);
      final folder = CommandFolderEntity(
        id: 'folder-1',
        name: 'My Folder',
        createdAt: createdAt,
      );

      expect(folder.id, equals('folder-1'));
      expect(folder.name, equals('My Folder'));
      expect(folder.createdAt, equals(createdAt));
    });

    test('usa valores por defecto para parámetros opcionales', () {
      final folder = CommandFolderEntity(
        id: 'folder-1',
        name: 'Folder',
        createdAt: DateTime.now(),
      );

      expect(folder.icon, isNull);
      expect(folder.order, equals(0));
    });

    test('crea instancia con todos los parámetros', () {
      final createdAt = DateTime(2024, 6, 20);
      final folder = CommandFolderEntity(
        id: 'folder-complete',
        name: 'Complete Folder',
        icon: '📁',
        order: 5,
        createdAt: createdAt,
      );

      expect(folder.id, equals('folder-complete'));
      expect(folder.name, equals('Complete Folder'));
      expect(folder.icon, equals('📁'));
      expect(folder.order, equals(5));
      expect(folder.createdAt, equals(createdAt));
    });

    test('permite icon null explícito', () {
      final folder = CommandFolderEntity(
        id: 'folder-1',
        name: 'Folder',
        icon: null,
        createdAt: DateTime.now(),
      );

      expect(folder.icon, isNull);
    });

    test('permite order negativo', () {
      final folder = CommandFolderEntity(
        id: 'folder-1',
        name: 'Folder',
        order: -5,
        createdAt: DateTime.now(),
      );

      expect(folder.order, equals(-5));
    });
  });

  // ---------------------------------------------------------------------------
  // CommandFolderEntity copyWith Tests
  // ---------------------------------------------------------------------------
  group('CommandFolderEntity - copyWith', () {
    late CommandFolderEntity baseFolder;
    late DateTime baseCreatedAt;

    setUp(() {
      baseCreatedAt = DateTime(2024, 3, 15, 12, 0, 0);
      baseFolder = CommandFolderEntity(
        id: 'original-id',
        name: 'Original Name',
        icon: '🗂️',
        order: 10,
        createdAt: baseCreatedAt,
      );
    });

    test('retorna copia idéntica sin parámetros', () {
      final copy = baseFolder.copyWith();

      expect(copy, equals(baseFolder));
      expect(copy.id, equals(baseFolder.id));
      expect(copy.name, equals(baseFolder.name));
      expect(copy.icon, equals(baseFolder.icon));
      expect(copy.order, equals(baseFolder.order));
      expect(copy.createdAt, equals(baseFolder.createdAt));
    });

    test('modifica solo id', () {
      final copy = baseFolder.copyWith(id: 'new-id');

      expect(copy.id, equals('new-id'));
      expect(copy.name, equals(baseFolder.name));
      expect(copy.icon, equals(baseFolder.icon));
      expect(copy.order, equals(baseFolder.order));
      expect(copy.createdAt, equals(baseFolder.createdAt));
    });

    test('modifica solo name', () {
      final copy = baseFolder.copyWith(name: 'New Name');

      expect(copy.name, equals('New Name'));
      expect(copy.id, equals(baseFolder.id));
    });

    test('modifica solo icon', () {
      final copy = baseFolder.copyWith(icon: '📂');

      expect(copy.icon, equals('📂'));
      expect(copy.name, equals(baseFolder.name));
    });

    test('modifica solo order', () {
      final copy = baseFolder.copyWith(order: 99);

      expect(copy.order, equals(99));
      expect(copy.name, equals(baseFolder.name));
    });

    test('modifica solo createdAt', () {
      final newDate = DateTime(2025, 1, 1);
      final copy = baseFolder.copyWith(createdAt: newDate);

      expect(copy.createdAt, equals(newDate));
      expect(copy.name, equals(baseFolder.name));
    });

    test('modifica múltiples campos a la vez', () {
      final newDate = DateTime(2024, 12, 31);
      final copy = baseFolder.copyWith(
        id: 'multi-id',
        name: 'Multi Name',
        icon: '🎯',
        order: 42,
        createdAt: newDate,
      );

      expect(copy.id, equals('multi-id'));
      expect(copy.name, equals('Multi Name'));
      expect(copy.icon, equals('🎯'));
      expect(copy.order, equals(42));
      expect(copy.createdAt, equals(newDate));
    });

    test('no modifica la instancia original', () {
      final originalId = baseFolder.id;
      final originalName = baseFolder.name;
      final originalOrder = baseFolder.order;

      baseFolder.copyWith(
        id: 'modified-id',
        name: 'Modified Name',
        order: 999,
      );

      expect(baseFolder.id, equals(originalId));
      expect(baseFolder.name, equals(originalName));
      expect(baseFolder.order, equals(originalOrder));
    });

    test('copyWith icon mantiene icon existente cuando no se especifica', () {
      final copy = baseFolder.copyWith(name: 'New Name');

      expect(copy.icon, equals('🗂️'));
    });

    test('copyWith no puede establecer icon a null (limitación de copyWith)', () {
      // Nota: El copyWith actual no permite establecer icon a null
      // porque usa `icon ?? this.icon`
      final folderWithIcon = CommandFolderEntity(
        id: 'with-icon',
        name: 'With Icon',
        icon: '📁',
        createdAt: DateTime.now(),
      );

      final copy = folderWithIcon.copyWith(icon: null);
      
      // Debido a la implementación, icon no se puede establecer a null
      expect(copy.icon, equals('📁'));
    });
  });

  // ---------------------------------------------------------------------------
  // CommandFolderEntity Equality Tests (Equatable)
  // ---------------------------------------------------------------------------
  group('CommandFolderEntity - equality', () {
    test('dos carpetas con mismos valores son iguales', () {
      final createdAt = DateTime(2024, 5, 10);
      
      final folder1 = CommandFolderEntity(
        id: 'same-id',
        name: 'Same Name',
        icon: '📁',
        order: 5,
        createdAt: createdAt,
      );

      final folder2 = CommandFolderEntity(
        id: 'same-id',
        name: 'Same Name',
        icon: '📁',
        order: 5,
        createdAt: createdAt,
      );

      expect(folder1, equals(folder2));
      expect(folder1.hashCode, equals(folder2.hashCode));
    });

    test('carpetas con diferente id no son iguales', () {
      final folder1 = _createBaseFolder(id: 'id-1');
      final folder2 = _createBaseFolder(id: 'id-2');

      expect(folder1, isNot(equals(folder2)));
    });

    test('carpetas con diferente name no son iguales', () {
      final folder1 = _createBaseFolder(name: 'Name 1');
      final folder2 = _createBaseFolder(name: 'Name 2');

      expect(folder1, isNot(equals(folder2)));
    });

    test('carpetas con diferente icon no son iguales', () {
      final folder1 = _createBaseFolder(icon: '📁');
      final folder2 = _createBaseFolder(icon: '📂');

      expect(folder1, isNot(equals(folder2)));
    });

    test('carpeta con icon null vs no null no son iguales', () {
      final folder1 = _createBaseFolder(icon: null);
      final folder2 = _createBaseFolder(icon: '📁');

      expect(folder1, isNot(equals(folder2)));
    });

    test('carpetas con diferente order no son iguales', () {
      final folder1 = _createBaseFolder(order: 1);
      final folder2 = _createBaseFolder(order: 2);

      expect(folder1, isNot(equals(folder2)));
    });

    test('carpetas con diferente createdAt no son iguales', () {
      final folder1 = _createBaseFolder(createdAt: DateTime(2024, 1, 1));
      final folder2 = _createBaseFolder(createdAt: DateTime(2024, 1, 2));

      expect(folder1, isNot(equals(folder2)));
    });

    test('carpetas con mismo DateTime pero diferente instancia son iguales', () {
      final folder1 = _createBaseFolder(createdAt: DateTime(2024, 6, 15, 10, 30, 0));
      final folder2 = _createBaseFolder(createdAt: DateTime(2024, 6, 15, 10, 30, 0));

      expect(folder1, equals(folder2));
    });

    test('carpeta no es igual a otro tipo de objeto', () {
      final folder = _createBaseFolder();

      expect(folder, isNot(equals('not a folder')));
      expect(folder, isNot(equals(123)));
      expect(folder, isNot(equals(null)));
      expect(folder, isNot(equals(['list'])));
    });

    test('carpeta es igual a sí misma', () {
      final folder = _createBaseFolder();

      expect(folder, equals(folder));
    });
  });

  // ---------------------------------------------------------------------------
  // CommandFolderEntity Edge Cases
  // ---------------------------------------------------------------------------
  group('CommandFolderEntity - casos edge', () {
    test('maneja nombre con caracteres especiales', () {
      final folder = CommandFolderEntity(
        id: 'special',
        name: 'Carpeta Ñoña 你好 🎉',
        createdAt: DateTime.now(),
      );

      expect(folder.name, equals('Carpeta Ñoña 你好 🎉'));
    });

    test('maneja icon como emoji complejo', () {
      final folder = CommandFolderEntity(
        id: 'emoji',
        name: 'Emoji Folder',
        icon: '👨‍👩‍👧‍👦', // Emoji compuesto
        createdAt: DateTime.now(),
      );

      expect(folder.icon, equals('👨‍👩‍👧‍👦'));
    });

    test('maneja icon como texto', () {
      final folder = CommandFolderEntity(
        id: 'text-icon',
        name: 'Text Icon Folder',
        icon: 'folder_icon_name',
        createdAt: DateTime.now(),
      );

      expect(folder.icon, equals('folder_icon_name'));
    });

    test('maneja strings vacíos', () {
      final folder = CommandFolderEntity(
        id: '',
        name: '',
        icon: '',
        createdAt: DateTime.now(),
      );

      expect(folder.id, isEmpty);
      expect(folder.name, isEmpty);
      expect(folder.icon, isEmpty);
    });

    test('maneja nombre muy largo', () {
      final longName = 'A' * 1000;
      final folder = CommandFolderEntity(
        id: 'long',
        name: longName,
        createdAt: DateTime.now(),
      );

      expect(folder.name.length, equals(1000));
    });

    test('maneja order con valor máximo de int', () {
      final folder = CommandFolderEntity(
        id: 'max-order',
        name: 'Max Order',
        order: 9223372036854775807, // Max int64
        createdAt: DateTime.now(),
      );

      expect(folder.order, equals(9223372036854775807));
    });

    test('maneja order con valor mínimo de int', () {
      final folder = CommandFolderEntity(
        id: 'min-order',
        name: 'Min Order',
        order: -9223372036854775808, // Min int64
        createdAt: DateTime.now(),
      );

      expect(folder.order, equals(-9223372036854775808));
    });

    test('maneja DateTime con microsegundos', () {
      final preciseDate = DateTime(2024, 6, 15, 10, 30, 45, 123, 456);
      final folder = CommandFolderEntity(
        id: 'precise',
        name: 'Precise Date',
        createdAt: preciseDate,
      );

      expect(folder.createdAt.microsecond, equals(456));
    });

    test('maneja DateTime UTC', () {
      final utcDate = DateTime.utc(2024, 6, 15, 10, 30);
      final folder = CommandFolderEntity(
        id: 'utc',
        name: 'UTC Date',
        createdAt: utcDate,
      );

      expect(folder.createdAt.isUtc, isTrue);
    });

    test('maneja DateTime local', () {
      final localDate = DateTime(2024, 6, 15, 10, 30);
      final folder = CommandFolderEntity(
        id: 'local',
        name: 'Local Date',
        createdAt: localDate,
      );

      expect(folder.createdAt.isUtc, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // CommandFolderEntity Sorting Tests
  // ---------------------------------------------------------------------------
  group('CommandFolderEntity - sorting', () {
    test('puede ordenarse por order', () {
      final folders = [
        _createBaseFolder(id: 'c', name: 'C', order: 3),
        _createBaseFolder(id: 'a', name: 'A', order: 1),
        _createBaseFolder(id: 'b', name: 'B', order: 2),
      ];

      folders.sort((a, b) => a.order.compareTo(b.order));

      expect(folders[0].name, equals('A'));
      expect(folders[1].name, equals('B'));
      expect(folders[2].name, equals('C'));
    });

    test('puede ordenarse por name', () {
      final folders = [
        _createBaseFolder(id: 'c', name: 'Zebra'),
        _createBaseFolder(id: 'a', name: 'Apple'),
        _createBaseFolder(id: 'b', name: 'Banana'),
      ];

      folders.sort((a, b) => a.name.compareTo(b.name));

      expect(folders[0].name, equals('Apple'));
      expect(folders[1].name, equals('Banana'));
      expect(folders[2].name, equals('Zebra'));
    });

    test('puede ordenarse por createdAt', () {
      final folders = [
        _createBaseFolder(id: 'c', createdAt: DateTime(2024, 3, 1)),
        _createBaseFolder(id: 'a', createdAt: DateTime(2024, 1, 1)),
        _createBaseFolder(id: 'b', createdAt: DateTime(2024, 2, 1)),
      ];

      folders.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      expect(folders[0].id, equals('a'));
      expect(folders[1].id, equals('b'));
      expect(folders[2].id, equals('c'));
    });

    test('carpetas con mismo order mantienen orden de inserción', () {
      final folders = [
        _createBaseFolder(id: 'first', order: 1),
        _createBaseFolder(id: 'second', order: 1),
        _createBaseFolder(id: 'third', order: 1),
      ];

      // Sort estable debería mantener el orden original para elementos iguales
      final sorted = List<CommandFolderEntity>.from(folders)
        ..sort((a, b) => a.order.compareTo(b.order));

      expect(sorted[0].id, equals('first'));
      expect(sorted[1].id, equals('second'));
      expect(sorted[2].id, equals('third'));
    });
  });

  // ---------------------------------------------------------------------------
  // CommandFolderEntity Collection Operations Tests
  // ---------------------------------------------------------------------------
  group('CommandFolderEntity - operaciones con colecciones', () {
    test('puede usarse en Set (elimina duplicados)', () {
      final createdAt = DateTime(2024, 1, 1);
      final folder1 = CommandFolderEntity(
        id: 'same',
        name: 'Same',
        createdAt: createdAt,
      );
      final folder2 = CommandFolderEntity(
        id: 'same',
        name: 'Same',
        createdAt: createdAt,
      );

      final set = {folder1, folder2};

      expect(set.length, equals(1));
    });

    test('puede usarse como key en Map', () {
      final createdAt = DateTime(2024, 1, 1);
      final folder = CommandFolderEntity(
        id: 'key',
        name: 'Key Folder',
        createdAt: createdAt,
      );

      final map = {folder: 'value'};

      final sameFolder = CommandFolderEntity(
        id: 'key',
        name: 'Key Folder',
        createdAt: createdAt,
      );

      expect(map[sameFolder], equals('value'));
    });

    test('puede buscarse con contains en List', () {
      final createdAt = DateTime(2024, 1, 1);
      final folders = [
        CommandFolderEntity(id: 'a', name: 'A', createdAt: createdAt),
        CommandFolderEntity(id: 'b', name: 'B', createdAt: createdAt),
      ];

      final searchFolder = CommandFolderEntity(
        id: 'a',
        name: 'A',
        createdAt: createdAt,
      );

      expect(folders.contains(searchFolder), isTrue);
    });

    test('puede filtrarse con where', () {
      final folders = [
        _createBaseFolder(id: 'a', order: 1),
        _createBaseFolder(id: 'b', order: 5),
        _createBaseFolder(id: 'c', order: 3),
      ];

      final highOrder = folders.where((f) => f.order > 2).toList();

      expect(highOrder.length, equals(2));
      expect(highOrder.map((f) => f.id), containsAll(['b', 'c']));
    });
  });
}

// =============================================================================
// HELPERS
// =============================================================================

CommandFolderEntity _createBaseFolder({
  String id = 'base-id',
  String name = 'Base Folder',
  String? icon,
  int order = 0,
  DateTime? createdAt,
}) {
  return CommandFolderEntity(
    id: id,
    name: name,
    icon: icon,
    order: order,
    createdAt: createdAt ?? DateTime(2024, 1, 1),
  );
}