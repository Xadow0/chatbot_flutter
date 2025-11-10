import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:process_run/shell.dart';
import '../models/local_ollama_models.dart';

/// Servicio para instalar Ollama automáticamente en el sistema del usuario
class LocalOllamaInstaller {
  static const String _windowsDownloadUrl = 'https://ollama.com/download/OllamaSetup.exe';
  // El script de Linux funciona perfectamente en macOS para instalar la CLI
  static const String _linuxInstallCommand = 'curl -fsSL https://ollama.com/install.sh | sh';

  /// Busca el ejecutable de Ollama en las rutas por defecto
  static Future<String?> _findOllamaExecutable() async {
    // 1. (Windows) Buscar en AppData
    if (Platform.isWindows) {
      final userProfile = Platform.environment['UserProfile'];
      if (userProfile != null) {
        final winPath = '$userProfile\\AppData\\Local\\Programs\\Ollama\\ollama.exe';
        if (await File(winPath).exists()) {
          debugPrint('   ✅ Ejecutable encontrado en: $winPath');
          return winPath;
        }
      }
    }
    // 2. (macOS/Linux) Buscar en /usr/local/bin
    else if (Platform.isMacOS || Platform.isLinux) {
      const unixPath = '/usr/local/bin/ollama';
      if (await File(unixPath).exists()) {
        debugPrint('   ✅ Ejecutable encontrado en: $unixPath');
        return unixPath;
      }
      // (macOS) Fallback por si el CLI no está linkeado pero la app sí
      if (Platform.isMacOS) {
        const appPath = '/Applications/Ollama.app/Contents/Resources/ollama';
        if (await File(appPath).exists()) {
          debugPrint('   ✅ Ejecutable encontrado dentro de Ollama.app: $appPath');
          return appPath;
        }
      }
    }
    
    // 3. (Linux) Fallback a /usr/bin
    if (Platform.isLinux) {
        const linuxFallback = '/usr/bin/ollama';
        if (await File(linuxFallback).exists()) {
          debugPrint('   ✅ Ejecutable encontrado en: $linuxFallback');
          return linuxFallback;
        }
    }

    debugPrint('   ℹ️ No se encontró el ejecutable en rutas por defecto');
    return null;
  }
  
  /// Verificar si Ollama está instalado en el sistema
  static Future<OllamaInstallationInfo> checkInstallation() async {
    debugPrint('🔍 [LocalOllamaInstaller] Verificando instalación de Ollama...');
    
    String? executableCommand = 'ollama';
    String? installPath;
    ProcessResult? result;

    try {
      // --- Intento 1: Usar PATH (si ya está configurado) ---
      result = await Process.run(
        executableCommand,
        ['--version'],
        runInShell: true,
      );
    } catch (e) {
      debugPrint('   ℹ️ Comando "ollama" no encontrado en PATH: $e');
      result = null; 
    }

    if (result == null || result.exitCode != 0) {
      // --- Intento 2: Buscar en rutas por defecto ---
      debugPrint('   ℹ️ "ollama" no está en PATH o falló. Buscando en rutas por defecto...');
      executableCommand = await _findOllamaExecutable();
      
      if (executableCommand != null) {
        try {
          result = await Process.run(
            executableCommand, // Usar la ruta completa
            ['--version'],
            runInShell: true,
          );
          installPath = executableCommand; // Guardar la ruta
        } catch (e) {
          debugPrint('   ❌ Error ejecutando desde ruta completa ($executableCommand): $e');
          result = null;
        }
      } else {
          debugPrint('   ❌ No se encontró el ejecutable en PATH ni en rutas por defecto.');
      }
    }

    // --- Evaluación Final ---
    if (result != null && result.exitCode == 0) {
      final version = result.stdout.toString().trim();
      debugPrint('   ✅ Ollama instalado: $version');
      
      // Si el Intento 1 funcionó, 'installPath' es null.
      // Usamos 'where' o 'which' para encontrarlo.
      if (installPath == null) {
        try {
          if (Platform.isWindows) {
            final whereResult = await Process.run('where', ['ollama']);
            if (whereResult.exitCode == 0) {
              installPath = whereResult.stdout.toString().trim().split('\n').first;
            }
          } else {
            final whichResult = await Process.run('which', ['ollama']);
            if (whichResult.exitCode == 0) {
              installPath = whichResult.stdout.toString().trim();
            }
          }
        } catch(e) { /* Ignorar error si 'where/which' falla */ }
      }

      return OllamaInstallationInfo(
        isInstalled: true,
        installPath: installPath ?? 'Desconocida (en PATH)',
        version: version,
        canExecute: true,
      );
    } else {
      debugPrint('   ❌ Ollama no encontrado o no responde');
      return OllamaInstallationInfo(
        isInstalled: false,
        canExecute: false,
      );
    }
  }

  /// Instalar Ollama en el sistema
  static Stream<LocalOllamaInstallProgress> installOllama() async* {
    debugPrint('📦 [LocalOllamaInstaller] ========================================');
    debugPrint('📦 [LocalOllamaInstaller] Iniciando instalación de Ollama...');
    debugPrint('📦 [LocalOllamaInstaller] Plataforma: ${Platform.operatingSystem}');
    
    try {
      if (Platform.isWindows) {
        yield* _installOnWindows();
      } else if (Platform.isMacOS) {
        yield* _installOnMacOS();
      } else if (Platform.isLinux) {
        yield* _installOnLinux();
      } else {
        throw LocalOllamaException(
          'Plataforma no soportada',
          details: 'Sistema operativo: ${Platform.operatingSystem}',
        );
      }
    } catch (e) {
      debugPrint('❌ [LocalOllamaInstaller] Error en instalación: $e');
      yield LocalOllamaInstallProgress(
        status: LocalOllamaStatus.error,
        progress: 0.0,
        message: 'Error: ${e.toString()}',
      );
      rethrow;
    }
  }

  /// Instalar en Windows
  static Stream<LocalOllamaInstallProgress> _installOnWindows() async* {
    debugPrint('🪟 [LocalOllamaInstaller] Instalando en Windows...');
    
    try {
      yield LocalOllamaInstallProgress(
        status: LocalOllamaStatus.downloadingInstaller,
        progress: 0.0,
        message: 'Preparando descarga...',
      );

      final tempDir = await getTemporaryDirectory();
      final installerPath = '${tempDir.path}\\OllamaSetup.exe';
      final installerFile = File(installerPath);

      debugPrint('   ⬇️ Descargando instalador desde $_windowsDownloadUrl');
      
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(_windowsDownloadUrl));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw LocalOllamaException(
          'Error descargando instalador',
          details: 'HTTP ${response.statusCode}',
        );
      }

      final contentLength = response.contentLength ?? 0;
      var downloadedBytes = 0;
      final sink = installerFile.openWrite();

      await for (var chunk in response.stream) {
        sink.add(chunk);
        downloadedBytes += chunk.length;
        
        final progress = contentLength > 0 ? downloadedBytes / contentLength : 0.5;
        
        yield LocalOllamaInstallProgress(
          status: LocalOllamaStatus.downloadingInstaller,
          progress: progress,
          message: 'Descargando instalador...',
          bytesDownloaded: downloadedBytes,
          totalBytes: contentLength,
        );
      }

      await sink.close();
      client.close();
      
      debugPrint('   ✅ Instalador descargado: ${(downloadedBytes / 1024 / 1024).toStringAsFixed(1)} MB');

      yield LocalOllamaInstallProgress(
        status: LocalOllamaStatus.installing,
        progress: 0.8,
        message: 'Ejecutando instalador silencioso...\nPuede requerir permisos de administrador',
      );

      debugPrint('   🚀 Ejecutando instalador: $installerPath');
      
      final installResult = await Process.run(
        installerPath,
        ['/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART'],
        runInShell: true,
      );

      if (installResult.exitCode != 0) {
        // No lanzar error aún, la post-verificación es más fiable
        debugPrint('   ⚠️ Instalador retornó código no cero: ${installResult.exitCode}');
      }

      try {
        await installerFile.delete();
        debugPrint('   🧹 Instalador temporal eliminado');
      } catch (e) {
        debugPrint('   ⚠️ No se pudo eliminar instalador: $e');
      }

      yield LocalOllamaInstallProgress(
        status: LocalOllamaStatus.installing,
        progress: 0.95,
        message: 'Verificando instalación...',
      );

      // Aumentar espera para que el sistema registre la instalación
      debugPrint('   ⏳ Esperando 5s para que el sistema registre la instalación...');
      await Future.delayed(const Duration(seconds: 5));
      
      // Usar la NUEVA 'checkInstallation' que es más robusta
      final verification = await checkInstallation();

      if (!verification.isInstalled) {
        throw LocalOllamaException(
          'Error instalando Ollama',
          details: 'La instalación completó pero Ollama no está disponible (post-check falló)',
        );
      }

      debugPrint('   ✅ Ollama instalado correctamente');
      debugPrint('   📍 Ubicación: ${verification.installPath}');

      yield LocalOllamaInstallProgress(
        status: LocalOllamaStatus.installing,
        progress: 1.0,
        message: 'Instalación completada',
      );

    } catch (e) {
      debugPrint('❌ [LocalOllamaInstaller] Error en Windows: $e');
      if (e is LocalOllamaException) rethrow;
      throw LocalOllamaException(
        'Error instalando Ollama',
        details: e.toString(),
      );
    }
  }

  /// Instalar en macOS
  static Stream<LocalOllamaInstallProgress> _installOnMacOS() async* {
    debugPrint('🍎 [LocalOllamaInstaller] Instalando en macOS usando script oficial...');
    
    try {
      yield LocalOllamaInstallProgress(
        status: LocalOllamaStatus.installing,
        progress: 0.0,
        message: 'Descargando e instalando Ollama...',
      );

      debugPrint('   🚀 Ejecutando script oficial de instalación');
      debugPrint('   Comando: $_linuxInstallCommand'); // _linuxInstallCommand funciona en macOS

      final shell = Shell(verbose: false); // verbose: false para no llenar la consola
      
      // El script puede pedir sudo, lo que puede ser un problema si
      // la app no se corre desde una terminal.
      final process = await shell.run(_linuxInstallCommand);
      
      // Comprobar si 'shell.run' capturó un error
      if (process.first.exitCode != 0) { // <-- .first
          debugPrint('   ❌ Error del script de instalación (código ${process.first.exitCode}): ${process.first.stderr}'); // <-- .first
          throw LocalOllamaException(
            'Error ejecutando script de instalación',
            details: process.first.stderr.toString().isEmpty // <-- .first
                ? 'El script falló. Código: ${process.first.exitCode}. Puede requerir permisos (sudo).' // <-- .first
                : process.first.stderr.toString(), // <-- .first
          );
      }

      debugPrint('   ✅ Script de instalación completado');

      yield LocalOllamaInstallProgress(
        status: LocalOllamaStatus.installing,
        progress: 0.9,
        message: 'Verificando instalación...',
      );
      
      // Espera un poco más para que todo se asiente
      debugPrint('   ⏳ Esperando 5s para que el sistema registre la instalación...');
      await Future.delayed(const Duration(seconds: 5));
      
      // Usar la NUEVA 'checkInstallation' que es más robusta
      final verification = await checkInstallation();

      if (!verification.isInstalled) {
        throw LocalOllamaException(
          'Error instalando Ollama',
          details: 'El script completó pero Ollama no está disponible (post-check falló)',
        );
      }

      debugPrint('   ✅ Ollama instalado correctamente');
      debugPrint('   📍 Ubicación: ${verification.installPath}');

      yield LocalOllamaInstallProgress(
        status: LocalOllamaStatus.installing,
        progress: 1.0,
        message: 'Instalación completada',
      );

    } catch (e) {
      debugPrint('❌ [LocalOllamaInstaller] Error en macOS: $e');
      if (e is LocalOllamaException) rethrow;
      throw LocalOllamaException(
        'Error instalando Ollama',
        details: e.toString(),
      );
    }
  }

  /// Instalar en Linux
  static Stream<LocalOllamaInstallProgress> _installOnLinux() async* {
    debugPrint('🐧 [LocalOllamaInstaller] Instalando en Linux...');
    
    try {
      yield LocalOllamaInstallProgress(
        status: LocalOllamaStatus.installing,
        progress: 0.0,
        message: 'Descargando e instalando Ollama...',
      );

      debugPrint('   🚀 Ejecutando script oficial de instalación');
      debugPrint('   Comando: $_linuxInstallCommand');

      final shell = Shell(verbose: false);
      final process = await shell.run(_linuxInstallCommand);

      // Comprobar si 'shell.run' capturó un error
      if (process.first.exitCode != 0) { // <-- .first
          debugPrint('   ❌ Error del script de instalación (código ${process.first.exitCode}): ${process.first.stderr}'); // <-- .first
          throw LocalOllamaException(
            'Error ejecutando script de instalación',
            details: process.first.stderr.toString().isEmpty // <-- .first
                ? 'El script falló. Código: ${process.first.exitCode}. Puede requerir permisos (sudo).' // <-- .first
                : process.first.stderr.toString(), // <-- .first
          );
      }

      debugPrint('   ✅ Script de instalación completado');

      yield LocalOllamaInstallProgress(
        status: LocalOllamaStatus.installing,
        progress: 0.9,
        message: 'Verificando instalación...',
      );

      debugPrint('   ⏳ Esperando 5s para que el sistema registre la instalación...');
      await Future.delayed(const Duration(seconds: 5));
      
      // Usar la NUEVA 'checkInstallation' que es más robusta
      final verification = await checkInstallation();

      if (!verification.isInstalled) {
        throw LocalOllamaException(
          'Error instalando Ollama',
          details: 'El script completó pero Ollama no está disponible (post-check falló)',
        );
      }

      debugPrint('   ✅ Ollama instalado correctamente');
      debugPrint('   📍 Ubicación: ${verification.installPath}');

      yield LocalOllamaInstallProgress(
        status: LocalOllamaStatus.installing,
        progress: 1.0,
        message: 'Instalación completada',
      );

    } catch (e) {
      debugPrint('❌ [LocalOllamaInstaller] Error en Linux: $e');
      if (e is LocalOllamaException) rethrow;
      throw LocalOllamaException(
        'Error instalando Ollama',
        details: e.toString(),
      );
    }
  }

  /// Verificar que Ollama serve está corriendo
  static Future<bool> isOllamaRunning({int port = 11434}) async {
    try {
      final client = http.Client();
      final response = await client.get(
        Uri.parse('http://localhost:$port/api/version'),
      ).timeout(const Duration(seconds: 2));
      
      client.close();
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Iniciar el servicio Ollama
  static Future<bool> startOllamaService() async {
    debugPrint('🚀 [LocalOllamaInstaller] Iniciando servicio Ollama...');
    
    try {
      if (await isOllamaRunning()) {
        debugPrint('   ✅ Ollama ya está ejecutándose');
        return true;
      }

      // [!] MODIFICACIÓN IMPORTANTE: 
      // En lugar de 'ollama serve', usamos 'ollama' solo en Windows
      // y 'ollama serve &' en Unix.
      // El instalador de Windows configura 'ollama app' para que se
      // ejecute al inicio, pero si no lo está, 'ollama serve' es el comando.
      // 'ollama' como comando no existe, es 'ollama.exe'.
      
      // Vamos a usar el comando 'serve' explícitamente en todas las plataformas
      // pero debemos encontrar el ejecutable primero.
      
      String executableCommand = 'ollama'; // Asumir que está en PATH
      ProcessResult? findResult;
      
      try {
        if (Platform.isWindows) {
          findResult = await Process.run('where', ['ollama']);
        } else {
          findResult = await Process.run('which', ['ollama']);
        }
      } catch(e) { /* ignorar */ }

      if (findResult == null || findResult.exitCode != 0) {
        debugPrint('   ℹ️ No se encontró "ollama" en PATH, buscando en rutas por defecto...');
        executableCommand = await _findOllamaExecutable() ?? 'ollama';
      } else {
        executableCommand = findResult.stdout.toString().trim().split('\n').first;
      }
      
      debugPrint('   ℹ️ Usando comando: $executableCommand');

      if (Platform.isWindows) {
        // En Windows, 'ollama serve' se queda en primer plano.
        // 'ollama app' es el comando que lanza la app de bandeja.
        // El instalador DEBERÍA haberla iniciado.
        // Si no, 'ollama serve' es la única opción programática.
        await Process.start(
          executableCommand,
          ['serve'],
          mode: ProcessStartMode.detached,
        );
      } else {
        // En macOS/Linux, 'ollama serve &' funciona bien.
        final shell = Shell();
        await shell.run('$executableCommand serve &');
      }

      debugPrint('   ⏳ Esperando a que el servicio responda...');
      for (var i = 0; i < 30; i++) {
        await Future.delayed(const Duration(seconds: 1));
        if (await isOllamaRunning()) {
          debugPrint('   ✅ Servicio iniciado correctamente');
          return true;
        }
      }

      debugPrint('   ⚠️ Timeout esperando servicio');
      return false;

    } catch (e) {
      debugPrint('   ❌ Error iniciando servicio: $e');
      return false;
    }
  }

  /// Detener el servicio Ollama
  static Future<void> stopOllamaService() async {
    debugPrint('🛑 [LocalOllamaInstaller] Deteniendo servicio Ollama...');
    
    try {
      if (Platform.isWindows) {
        await Process.run('taskkill', ['/F', '/IM', 'ollama.exe']);
      } else {
        await Process.run('pkill', ['-f', 'ollama serve']);
        await Process.run('pkill', ['-f', 'Ollama']); // Por si acaso en macOS
      }
      
      debugPrint('   ✅ Servicio detenido');
    } catch (e) {
      debugPrint('   ⚠️ Error deteniendo servicio: $e');
    }
  }
}