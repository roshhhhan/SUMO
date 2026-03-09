import 'package:mysql1/mysql1.dart';

void main() async {
  final settings = ConnectionSettings(
    host: 'localhost',
    port: 3306,
    user: 'sumo_app',
    password: 'sumo_password',
  );

  print('Testing MySQL connection as sumo_app...');
  try {
    final conn = await MySqlConnection.connect(settings);
    print('✓ Connected successfully!\n');
    
    final results = await conn.query('SELECT VERSION()');
    print('MySQL version: ${results.first[0]}\n');
    
    // Create database and table if they don't exist
    print('Setting up database and tables...');
    await conn.query('CREATE DATABASE IF NOT EXISTS sumo');
    await conn.query('USE sumo');
    await conn.query('''
      CREATE TABLE IF NOT EXISTS brackets (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(100),
        structure JSON,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    
    final dbCheck = await conn.query('SELECT DATABASE()');
    print('Current database: ${dbCheck.first[0]}\n');
    
    final tableCheck = await conn.query('SHOW TABLES');
    print('Tables in sumo database:');
    for (var row in tableCheck) {
      print('  ✓ ${row[0]}');
    }
    
    await conn.close();
    print('\n✓ Setup complete! Server is ready to run.');
  } catch (e) {
    print('✗ Connection failed: $e');
    print('\nIf this persists, manually run in phpMyAdmin:');
    print('CREATE DATABASE sumo;');
  }
}
