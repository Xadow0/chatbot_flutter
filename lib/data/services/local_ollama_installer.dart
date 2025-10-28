import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:process_run/shell.dart';
import '../models/local_ollama_models.dart';

/// Servicio para instalar Ollama automáticamente en el sistema del usuario
class LocalOllamaInstaller {
  static const String _windowsDownloadUrl = 'https://ollama.com/download/OllamaSetup.exe';
  static const String _macDownloadUrl = 'https://ollama.com/download/Ollama-darwin.zip';
  static const String _linuxInstallCommand = 'curl -fsSL https://ollama.com/install.sh | sh';
  
  /// Verificar si Ollama está instalado en el sistema
  static Future<OllamaInstallationInfo> checkInstallation() async {
    debugPrint('🔍 [LocalOllamaInstaller] Verificando instalación de Ollama...');
    
    try {
      // Intentar ejecutar ollama --version
      final result = await Process.run(
        'ollama',
        ['--version'],
        runInShell: true,
      );

      if (result.exitCode == 0) {
        final version = result.stdout.toString().trim();
        debugPrint('   ✅ Ollama instalado: $version');
        
        // Verificar ruta de instalación
        String? installPath;
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

        return OllamaInstallationInfo(
          isInstalled: true,
          installPath: installPath,
          version: version,
          canExecute: true,
        );
      } else {
        debugPrint('   ❌ Ollama no encontrado');
        return OllamaInstallationInfo(
          isInstalled: false,
          canExecute: false,
        );
      }
    } catch (e) {
      debugPrint('   ❌ Error verificando Ollama: $e');
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
        message: 'Ejecutando instalador...\nPuede requerir permisos de administrador',
      );

      debugPrint('   🚀 Ejecutando instalador: $installerPath');
      
      final installResult = await Process.run(
        installerPath,
        ['/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART'],
        runInShell: true,
      );

      if (installResult.exitCode != 0) {
        debugPrint('   ⚠️ Instalador retornó código: ${installResult.exitCode}');
        
        await Future.delayed(const Duration(seconds: 3));
        final verification = await checkInstallation();
        
        if (!verification.isInstalled) {
          throw LocalOllamaException(
            'Error instalando Ollama',
            details: 'El instalador falló. Código: ${installResult.exitCode}',
          );
        }
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

      await Future.delayed(const Duration(seconds: 2));
      final verification = await checkInstallation();

      if (!verification.isInstalled) {
        throw LocalOllamaException(
          'Error instalando Ollama',
          details: 'La instalación completó pero Ollama no está disponible',
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
    debugPrint('🍎 [LocalOllamaInstaller] Instalando en macOS...');
    
    try {
      yield LocalOllamaInstallProgress(
        status: LocalOllamaStatus.downloadingInstaller,
        progress: 0.0,
        message: 'Preparando descarga...',
      );

      final tempDir = await getTemporaryDirectory();
      final zipPath = '${tempDir.path}/Ollama.zip';
      final zipFile = File(zipPath);

      debugPrint('   ⬇️ Descargando desde $_macDownloadUrl');
      
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(_macDownloadUrl));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw LocalOllamaException(
          'Error descargando instalador',
          details: 'HTTP ${response.statusCode}',
        );
      }

      final contentLength = response.contentLength ?? 0;
      var downloadedBytes = 0;
      final sink = zipFile.openWrite();

      await for (var chunk in response.stream) {
        sink.add(chunk);
        downloadedBytes += chunk.length;
        
        final progress = contentLength > 0 ? downloadedBytes / contentLength : 0.5;
        
        yield LocalOllamaInstallProgress(
          status: LocalOllamaStatus.downloadingInstaller,
          progress: progress,
          message: 'Descargando Ollama...',
          bytesDownloaded: downloadedBytes,
          totalBytes: contentLength,
        );
      }

      await sink.close();
      client.close();

      debugPrint('   ✅ Descarga completada');

      yield LocalOllamaInstallProgress(
        status: LocalOllamaStatus.installing,
        progress: 0.7,
        message: 'Descomprimiendo...',
      );

      final shell = Shell();
      await shell.run('unzip -o ${zipFile.path} -d ${tempDir.path}');

      yield LocalOllamaInstallProgress(
        status: LocalOllamaStatus.installing,
        progress: 0.85,
        message: 'Instalando en /Applications...',
      );

      await shell.run('sudo mv ${tempDir.path}/Ollama.app /Applications/');
      await shell.run('sudo xattr -rd com.apple.quarantine /Applications/Ollama.app');

      debugPrint('   ✅ Ollama instalado en /Applications');

      try {
        await zipFile.delete();
        debugPrint('   🧹 Archivos temporales eliminados');
      } catch (e) {
        debugPrint('   ⚠️ Error limpiando temporales: $e');
      }

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

      final shell = Shell();
      await shell.run(_linuxInstallCommand);

      debugPrint('   ✅ Script de instalación completado');

      yield LocalOllamaInstallProgress(
        status: LocalOllamaStatus.installing,
        progress: 0.9,
        message: 'Verificando instalación...',
      );

      await Future.delayed(const Duration(seconds: 2));
      final verification = await checkInstallation();

      if (!verification.isInstalled) {
        throw LocalOllamaException(
          'Error instalando Ollama',
          details: 'El script completó pero Ollama no está disponible',
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

      if (Platform.isWindows) {
        await Process.start(
          'ollama',
          ['serve'],
          mode: ProcessStartMode.detached,
        );
      } else {
        final shell = Shell();
        await shell.run('ollama serve &');
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
      }
      
      debugPrint('   ✅ Servicio detenido');
    } catch (e) {
      debugPrint('   ⚠️ Error deteniendo servicio: $e');
    }
  }
}