import 'package:flutter_test/flutter_test.dart';
import 'package:chatbot_app/core/constants/commands_help.dart';

void main() {
  group('CommandsHelp Tests', () {

    // 1. Test de Constructor
    // Necesario para cubrir la línea de declaración de la clase
    test('Debe poder instanciarse (cobertura de constructor)', () {
      final instance = CommandsHelp();
      expect(instance, isA<CommandsHelp>());
    });

    // 2. Test de Constantes (Sanity Check)
    test('Las constantes de texto no deben estar vacías', () {
      expect(CommandsHelp.evaluarPrompt, isNotEmpty);
      expect(CommandsHelp.traducir, isNotEmpty);
      expect(CommandsHelp.resumir, isNotEmpty);
      expect(CommandsHelp.codigo, isNotEmpty);
      expect(CommandsHelp.corregir, isNotEmpty);
      expect(CommandsHelp.explicar, isNotEmpty);
      expect(CommandsHelp.comparar, isNotEmpty);
    });

    // 3. Test Exhaustivo de getCommandHelp
    // Se prueba CADA case del switch individualmente
    group('getCommandHelp - Cobertura de todos los casos', () {

      test('Case: evaluarPrompt', () {
        // Cubre: case '/evaluarprompt':
        expect(CommandsHelp.getCommandHelp('/evaluarprompt'), equals(CommandsHelp.evaluarPrompt));
        // Cubre: case 'evaluarprompt':
        expect(CommandsHelp.getCommandHelp('evaluarprompt'), equals(CommandsHelp.evaluarPrompt));
      });

      test('Case: traducir', () {
        // Cubre: case '/traducir':
        expect(CommandsHelp.getCommandHelp('/traducir'), equals(CommandsHelp.traducir));
        // Cubre: case 'traducir':
        expect(CommandsHelp.getCommandHelp('traducir'), equals(CommandsHelp.traducir));
      });

      test('Case: resumir', () {
        // Cubre: case '/resumir':
        expect(CommandsHelp.getCommandHelp('/resumir'), equals(CommandsHelp.resumir));
        // Cubre: case 'resumir':
        expect(CommandsHelp.getCommandHelp('resumir'), equals(CommandsHelp.resumir));
      });

      test('Case: codigo (incluye variante con tilde)', () {
        // Cubre: case '/codigo':
        expect(CommandsHelp.getCommandHelp('/codigo'), equals(CommandsHelp.codigo));
        // Cubre: case 'codigo':
        expect(CommandsHelp.getCommandHelp('codigo'), equals(CommandsHelp.codigo));
        // Cubre: case 'código':
        expect(CommandsHelp.getCommandHelp('código'), equals(CommandsHelp.codigo));
      });

      test('Case: corregir', () {
        // Cubre: case '/corregir':
        expect(CommandsHelp.getCommandHelp('/corregir'), equals(CommandsHelp.corregir));
        // Cubre: case 'corregir':
        expect(CommandsHelp.getCommandHelp('corregir'), equals(CommandsHelp.corregir));
      });

      test('Case: explicar', () {
        // Cubre: case '/explicar':
        expect(CommandsHelp.getCommandHelp('/explicar'), equals(CommandsHelp.explicar));
        // Cubre: case 'explicar':
        expect(CommandsHelp.getCommandHelp('explicar'), equals(CommandsHelp.explicar));
      });

      test('Case: comparar', () {
        // Cubre: case '/comparar':
        expect(CommandsHelp.getCommandHelp('/comparar'), equals(CommandsHelp.comparar));
        // Cubre: case 'comparar':
        expect(CommandsHelp.getCommandHelp('comparar'), equals(CommandsHelp.comparar));
      });

      test('Lógica de normalización (toLowerCase)', () {
        // Prueba que el .toLowerCase() al inicio del switch funciona
        expect(CommandsHelp.getCommandHelp('/CoDiGo'), equals(CommandsHelp.codigo));
        expect(CommandsHelp.getCommandHelp('TRADUCIR'), equals(CommandsHelp.traducir));
      });

      test('Default case (null)', () {
        // Cubre el return null del default
        expect(CommandsHelp.getCommandHelp('comando_inexistente'), isNull);
        expect(CommandsHelp.getCommandHelp(''), isNull);
        expect(CommandsHelp.getCommandHelp('   '), isNull);
      });
    });

    // 4. Test de getAllCommands
    test('getAllCommands retorna el string formateado correctamente', () {
      final result = CommandsHelp.getAllCommands();
      expect(result, contains('🤖 Comandos Disponibles'));
      // Verificamos que contenga referencias a los comandos clave
      expect(result, contains('/evaluarprompt'));
      expect(result, contains('/traducir'));
      expect(result, contains('/resumir'));
      expect(result, contains('/codigo'));
      expect(result, contains('/corregir'));
      expect(result, contains('/explicar'));
      expect(result, contains('/comparar'));
    });

    // 5. Test de getWelcomeMessage
    test('getWelcomeMessage integra getAllCommands', () {
      final result = CommandsHelp.getWelcomeMessage();
      
      expect(result, contains('¡Bienvenido al chat!'));
      expect(result, contains('Proveedores disponibles'));
      expect(result, contains('Ollama Local'));
      
      // Verificamos que el contenido de getAllCommands está presente
      expect(result, contains('🤖 Comandos Disponibles'));
      expect(result, contains('Escribe "ayuda" o "comandos"'));
    });
  });
}