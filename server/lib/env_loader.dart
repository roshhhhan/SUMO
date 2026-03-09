import 'dart:io';

/// Simple .env file loader
Map<String, String> loadEnv({String? filePath}) {
  final env = <String, String>{};
  
  try {
    // If no path provided, look for .env in script directory or current directory
    final envFile = File(filePath ?? '.env');
    final file = envFile.existsSync() 
        ? envFile 
        : File('server/.env');
    
    if (!file.existsSync()) {
      print('Note: .env file not found at ${file.path}, using defaults');
      return env;
    }
    
    final lines = file.readAsLinesSync();
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      
      final idx = trimmed.indexOf('=');
      if (idx > 0) {
        final key = trimmed.substring(0, idx).trim();
        final val = trimmed.substring(idx + 1).trim();
        env[key] = val;
      }
    }
    print('✓ Loaded .env from ${file.path}');
  } catch (e) {
    print('Warning: Error loading .env: $e');
  }
  
  return env;
}

/// Get a value from .env first, then system environment
String getEnv(String key, {String defaultValue = ''}) {
  final envVars = loadEnv();
  final value = Platform.environment[key] ?? envVars[key] ?? defaultValue;
  print('  $key=${value.isEmpty ? '(empty)' : value}');
  return value;
}
