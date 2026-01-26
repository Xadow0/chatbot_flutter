import 'package:flutter_test/flutter_test.dart';

// =============================================================================
// CÓDIGO BAJO PRUEBA
// =============================================================================

enum SystemCommandType {
  none,
  evaluarPrompt,
  traducir,
  resumir,
  codigo,
  corregir,
  explicar,
  comparar,
}

class CommandEntity {
  final String id;
  final String trigger;
  final String title;
  final String description;
  final String promptTemplate;
  final bool isSystem;
  final SystemCommandType systemType;
  final bool isEditable;
  final String? folderId;

  const CommandEntity({
    required this.id,
    required this.trigger,
    required this.title,
    required this.description,
    required this.promptTemplate,
    this.isSystem = false,
    this.systemType = SystemCommandType.none,
    this.isEditable = false,
    this.folderId,
  });

  CommandEntity copyWith({
    String? id,
    String? trigger,
    String? title,
    String? description,
    String? promptTemplate,
    bool? isSystem,
    SystemCommandType? systemType,
    bool? isEditable,
    String? folderId,
    bool clearFolderId = false,
  }) {
    return CommandEntity(
      id: id ?? this.id,
      trigger: trigger ?? this.trigger,
      title: title ?? this.title,
      description: description ?? this.description,
      promptTemplate: promptTemplate ?? this.promptTemplate,
      isSystem: isSystem ?? this.isSystem,
      systemType: systemType ?? this.systemType,
      isEditable: isEditable ?? this.isEditable,
      folderId: clearFolderId ? null : (folderId ?? this.folderId),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CommandEntity &&
        other.id == id &&
        other.trigger == trigger &&
        other.title == title &&
        other.description == description &&
        other.promptTemplate == promptTemplate &&
        other.isSystem == isSystem &&
        other.systemType == systemType &&
        other.isEditable == isEditable &&
        other.folderId == folderId;
  }

  @override
  int get hashCode => Object.hash(
        id,
        trigger,
        title,
        description,
        promptTemplate,
        isSystem,
        systemType,
        isEditable,
        folderId,
      );
}

// =============================================================================
// TESTS
// =============================================================================

void main() {
  // ---------------------------------------------------------------------------
  // SystemCommandType Tests
  // ---------------------------------------------------------------------------
  group('SystemCommandType', () {
    test('contiene todos los valores esperados', () {
      expect(SystemCommandType.values.length, equals(8));
      expect(SystemCommandType.values, contains(SystemCommandType.none));
      expect(SystemCommandType.values, contains(SystemCommandType.evaluarPrompt));
      expect(SystemCommandType.values, contains(SystemCommandType.traducir));
      expect(SystemCommandType.values, contains(SystemCommandType.resumir));
      expect(SystemCommandType.values, contains(SystemCommandType.codigo));
      expect(SystemCommandType.values, contains(SystemCommandType.corregir));
      expect(SystemCommandType.values, contains(SystemCommandType.explicar));
      expect(SystemCommandType.values, contains(SystemCommandType.comparar));
    });

    test('none tiene índice 0', () {
      expect(SystemCommandType.none.index, equals(0));
    });

    test('valores tienen nombres correctos', () {
      expect(SystemCommandType.none.name, equals('none'));
      expect(SystemCommandType.traducir.name, equals('traducir'));
      expect(SystemCommandType.evaluarPrompt.name, equals('evaluarPrompt'));
    });
  });

  // ---------------------------------------------------------------------------
  // CommandEntity Constructor Tests
  // ---------------------------------------------------------------------------
  group('CommandEntity - constructor', () {
    test('crea instancia con parámetros requeridos', () {
      final command = CommandEntity(
        id: 'cmd-1',
        trigger: '/test',
        title: 'Test Command',
        description: 'A test command',
        promptTemplate: 'Process: {{content}}',
      );

      expect(command.id, equals('cmd-1'));
      expect(command.trigger, equals('/test'));
      expect(command.title, equals('Test Command'));
      expect(command.description, equals('A test command'));
      expect(command.promptTemplate, equals('Process: {{content}}'));
    });

    test('usa valores por defecto para parámetros opcionales', () {
      final command = CommandEntity(
        id: 'cmd-1',
        trigger: '/test',
        title: 'Test',
        description: 'Desc',
        promptTemplate: 'Template',
      );

      expect(command.isSystem, isFalse);
      expect(command.systemType, equals(SystemCommandType.none));
      expect(command.isEditable, isFalse);
      expect(command.folderId, isNull);
    });

    test('crea instancia con todos los parámetros', () {
      final command = CommandEntity(
        id: 'cmd-1',
        trigger: '/translate',
        title: 'Traducir',
        description: 'Traduce texto',
        promptTemplate: 'Traduce a {{targetLanguage}}: {{content}}',
        isSystem: true,
        systemType: SystemCommandType.traducir,
        isEditable: true,
        folderId: 'folder-1',
      );

      expect(command.isSystem, isTrue);
      expect(command.systemType, equals(SystemCommandType.traducir));
      expect(command.isEditable, isTrue);
      expect(command.folderId, equals('folder-1'));
    });

    test('permite crear comando con folderId null explícito', () {
      final command = CommandEntity(
        id: 'cmd-1',
        trigger: '/test',
        title: 'Test',
        description: 'Desc',
        promptTemplate: 'Template',
        folderId: null,
      );

      expect(command.folderId, isNull);
    });

    test('es const constructible', () {
      const command = CommandEntity(
        id: 'const-id',
        trigger: '/const',
        title: 'Const',
        description: 'Const desc',
        promptTemplate: 'Const template',
      );

      expect(command.id, equals('const-id'));
    });
  });

  // ---------------------------------------------------------------------------
  // CommandEntity copyWith Tests
  // ---------------------------------------------------------------------------
  group('CommandEntity - copyWith', () {
    late CommandEntity baseCommand;

    setUp(() {
      baseCommand = CommandEntity(
        id: 'original-id',
        trigger: '/original',
        title: 'Original Title',
        description: 'Original description',
        promptTemplate: 'Original template',
        isSystem: false,
        systemType: SystemCommandType.none,
        isEditable: false,
        folderId: 'original-folder',
      );
    });

    test('retorna copia idéntica sin parámetros', () {
      final copy = baseCommand.copyWith();

      expect(copy, equals(baseCommand));
      expect(copy.id, equals(baseCommand.id));
      expect(copy.trigger, equals(baseCommand.trigger));
      expect(copy.title, equals(baseCommand.title));
      expect(copy.description, equals(baseCommand.description));
      expect(copy.promptTemplate, equals(baseCommand.promptTemplate));
      expect(copy.isSystem, equals(baseCommand.isSystem));
      expect(copy.systemType, equals(baseCommand.systemType));
      expect(copy.isEditable, equals(baseCommand.isEditable));
      expect(copy.folderId, equals(baseCommand.folderId));
    });

    test('modifica solo id', () {
      final copy = baseCommand.copyWith(id: 'new-id');

      expect(copy.id, equals('new-id'));
      expect(copy.trigger, equals(baseCommand.trigger));
    });

    test('modifica solo trigger', () {
      final copy = baseCommand.copyWith(trigger: '/new-trigger');

      expect(copy.trigger, equals('/new-trigger'));
      expect(copy.id, equals(baseCommand.id));
    });

    test('modifica solo title', () {
      final copy = baseCommand.copyWith(title: 'New Title');

      expect(copy.title, equals('New Title'));
    });

    test('modifica solo description', () {
      final copy = baseCommand.copyWith(description: 'New description');

      expect(copy.description, equals('New description'));
    });

    test('modifica solo promptTemplate', () {
      final copy = baseCommand.copyWith(promptTemplate: 'New template');

      expect(copy.promptTemplate, equals('New template'));
    });

    test('modifica solo isSystem', () {
      final copy = baseCommand.copyWith(isSystem: true);

      expect(copy.isSystem, isTrue);
      expect(baseCommand.isSystem, isFalse);
    });

    test('modifica solo systemType', () {
      final copy = baseCommand.copyWith(systemType: SystemCommandType.traducir);

      expect(copy.systemType, equals(SystemCommandType.traducir));
      expect(baseCommand.systemType, equals(SystemCommandType.none));
    });

    test('modifica solo isEditable', () {
      final copy = baseCommand.copyWith(isEditable: true);

      expect(copy.isEditable, isTrue);
      expect(baseCommand.isEditable, isFalse);
    });

    test('modifica solo folderId', () {
      final copy = baseCommand.copyWith(folderId: 'new-folder');

      expect(copy.folderId, equals('new-folder'));
      expect(baseCommand.folderId, equals('original-folder'));
    });

    test('clearFolderId establece folderId a null', () {
      final copy = baseCommand.copyWith(clearFolderId: true);

      expect(copy.folderId, isNull);
      expect(baseCommand.folderId, equals('original-folder'));
    });

    test('clearFolderId tiene prioridad sobre folderId', () {
      final copy = baseCommand.copyWith(
        folderId: 'ignored-folder',
        clearFolderId: true,
      );

      expect(copy.folderId, isNull);
    });

    test('folderId se mantiene cuando clearFolderId es false', () {
      final copy = baseCommand.copyWith(clearFolderId: false);

      expect(copy.folderId, equals('original-folder'));
    });

    test('modifica múltiples campos a la vez', () {
      final copy = baseCommand.copyWith(
        id: 'multi-id',
        trigger: '/multi',
        title: 'Multi Title',
        isSystem: true,
        systemType: SystemCommandType.resumir,
      );

      expect(copy.id, equals('multi-id'));
      expect(copy.trigger, equals('/multi'));
      expect(copy.title, equals('Multi Title'));
      expect(copy.isSystem, isTrue);
      expect(copy.systemType, equals(SystemCommandType.resumir));
      // Campos no modificados
      expect(copy.description, equals(baseCommand.description));
      expect(copy.promptTemplate, equals(baseCommand.promptTemplate));
    });

    test('no modifica la instancia original', () {
      final originalId = baseCommand.id;
      final originalTrigger = baseCommand.trigger;

      baseCommand.copyWith(id: 'modified', trigger: '/modified');

      expect(baseCommand.id, equals(originalId));
      expect(baseCommand.trigger, equals(originalTrigger));
    });

    test('permite asignar folderId a comando sin carpeta', () {
      final commandWithoutFolder = CommandEntity(
        id: 'no-folder',
        trigger: '/nofolder',
        title: 'No Folder',
        description: 'Desc',
        promptTemplate: 'Template',
        folderId: null,
      );

      final copy = commandWithoutFolder.copyWith(folderId: 'new-folder');

      expect(copy.folderId, equals('new-folder'));
    });
  });

  // ---------------------------------------------------------------------------
  // CommandEntity Equality Tests (Equatable)
  // ---------------------------------------------------------------------------
  group('CommandEntity - equality', () {
    test('dos comandos con mismos valores son iguales', () {
      final command1 = CommandEntity(
        id: 'same-id',
        trigger: '/same',
        title: 'Same',
        description: 'Same desc',
        promptTemplate: 'Same template',
        isSystem: true,
        systemType: SystemCommandType.codigo,
        isEditable: true,
        folderId: 'folder-1',
      );

      final command2 = CommandEntity(
        id: 'same-id',
        trigger: '/same',
        title: 'Same',
        description: 'Same desc',
        promptTemplate: 'Same template',
        isSystem: true,
        systemType: SystemCommandType.codigo,
        isEditable: true,
        folderId: 'folder-1',
      );

      expect(command1, equals(command2));
      expect(command1.hashCode, equals(command2.hashCode));
    });

    test('comandos con diferente id no son iguales', () {
      final command1 = _createBaseCommand(id: 'id-1');
      final command2 = _createBaseCommand(id: 'id-2');

      expect(command1, isNot(equals(command2)));
    });

    test('comandos con diferente trigger no son iguales', () {
      final command1 = _createBaseCommand(trigger: '/trigger1');
      final command2 = _createBaseCommand(trigger: '/trigger2');

      expect(command1, isNot(equals(command2)));
    });

    test('comandos con diferente title no son iguales', () {
      final command1 = _createBaseCommand(title: 'Title 1');
      final command2 = _createBaseCommand(title: 'Title 2');

      expect(command1, isNot(equals(command2)));
    });

    test('comandos con diferente description no son iguales', () {
      final command1 = _createBaseCommand(description: 'Desc 1');
      final command2 = _createBaseCommand(description: 'Desc 2');

      expect(command1, isNot(equals(command2)));
    });

    test('comandos con diferente promptTemplate no son iguales', () {
      final command1 = _createBaseCommand(promptTemplate: 'Template 1');
      final command2 = _createBaseCommand(promptTemplate: 'Template 2');

      expect(command1, isNot(equals(command2)));
    });

    test('comandos con diferente isSystem no son iguales', () {
      final command1 = _createBaseCommand(isSystem: true);
      final command2 = _createBaseCommand(isSystem: false);

      expect(command1, isNot(equals(command2)));
    });

    test('comandos con diferente systemType no son iguales', () {
      final command1 = _createBaseCommand(systemType: SystemCommandType.traducir);
      final command2 = _createBaseCommand(systemType: SystemCommandType.resumir);

      expect(command1, isNot(equals(command2)));
    });

    test('comandos con diferente isEditable no son iguales', () {
      final command1 = _createBaseCommand(isEditable: true);
      final command2 = _createBaseCommand(isEditable: false);

      expect(command1, isNot(equals(command2)));
    });

    test('comandos con diferente folderId no son iguales', () {
      final command1 = _createBaseCommand(folderId: 'folder-1');
      final command2 = _createBaseCommand(folderId: 'folder-2');

      expect(command1, isNot(equals(command2)));
    });

    test('comando con folderId null vs no null no son iguales', () {
      final command1 = _createBaseCommand(folderId: null);
      final command2 = _createBaseCommand(folderId: 'folder-1');

      expect(command1, isNot(equals(command2)));
    });

    test('comando no es igual a otro tipo de objeto', () {
      final command = _createBaseCommand();

      expect(command, isNot(equals('not a command')));
      expect(command, isNot(equals(123)));
      expect(command, isNot(equals(null)));
    });

    test('comando es igual a sí mismo', () {
      final command = _createBaseCommand();

      expect(command, equals(command));
    });
  });

  // ---------------------------------------------------------------------------
  // CommandEntity Edge Cases
  // ---------------------------------------------------------------------------
  group('CommandEntity - casos edge', () {
    test('maneja trigger con caracteres especiales', () {
      final command = CommandEntity(
        id: 'special',
        trigger: '/búsqueda_ñ',
        title: 'Especial',
        description: 'Desc',
        promptTemplate: 'Template',
      );

      expect(command.trigger, equals('/búsqueda_ñ'));
    });

    test('maneja promptTemplate con múltiples placeholders', () {
      const template = '''
Analiza el siguiente contenido: {{content}}
Idioma destino: {{targetLanguage}}
Formato: {{format}}
Extra: {{extra}}
''';
      final command = CommandEntity(
        id: 'multi',
        trigger: '/multi',
        title: 'Multi',
        description: 'Desc',
        promptTemplate: template,
      );

      expect(command.promptTemplate, contains('{{content}}'));
      expect(command.promptTemplate, contains('{{targetLanguage}}'));
      expect(command.promptTemplate, contains('{{format}}'));
    });

    test('maneja strings vacíos', () {
      final command = CommandEntity(
        id: '',
        trigger: '',
        title: '',
        description: '',
        promptTemplate: '',
      );

      expect(command.id, isEmpty);
      expect(command.trigger, isEmpty);
    });

    test('maneja strings muy largos', () {
      final longString = 'A' * 10000;
      final command = CommandEntity(
        id: longString,
        trigger: '/long',
        title: 'Long',
        description: longString,
        promptTemplate: longString,
      );

      expect(command.id.length, equals(10000));
      expect(command.promptTemplate.length, equals(10000));
    });

    test('maneja caracteres unicode y emojis', () {
      final command = CommandEntity(
        id: 'emoji-🎉',
        trigger: '/emoji',
        title: '🔥 Fire Command 🔥',
        description: 'Descripción con émojis 🚀',
        promptTemplate: 'Process 你好 {{content}}',
      );

      expect(command.id, contains('🎉'));
      expect(command.title, contains('🔥'));
    });

    test('todos los SystemCommandType pueden asignarse', () {
      for (final type in SystemCommandType.values) {
        final command = CommandEntity(
          id: 'type-${type.name}',
          trigger: '/${type.name}',
          title: type.name,
          description: 'Desc',
          promptTemplate: 'Template',
          systemType: type,
        );

        expect(command.systemType, equals(type));
      }
    });
  });
}

// =============================================================================
// HELPERS
// =============================================================================

CommandEntity _createBaseCommand({
  String id = 'base-id',
  String trigger = '/base',
  String title = 'Base Title',
  String description = 'Base description',
  String promptTemplate = 'Base template',
  bool isSystem = false,
  SystemCommandType systemType = SystemCommandType.none,
  bool isEditable = false,
  String? folderId,
}) {
  return CommandEntity(
    id: id,
    trigger: trigger,
    title: title,
    description: description,
    promptTemplate: promptTemplate,
    isSystem: isSystem,
    systemType: systemType,
    isEditable: isEditable,
    folderId: folderId,
  );
}