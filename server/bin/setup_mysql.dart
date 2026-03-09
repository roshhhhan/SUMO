import 'package:mysql1/mysql1.dart';

void main() async {
  print('Attempting connection via Unix socket...\n');
  
  // Try socket-based connection
  final settings = ConnectionSettings(
    host: 'localhost',
    user: 'root',
    password: '',
    useSSL: false,
  );

  try {
    final conn = await MySqlConnection.connect(settings);
    print('✓ Connected successfully via socket!');
    
    final results = await conn.query('SELECT VERSION()');
    print('MySQL version: ${results.first[0]}\n');
    
    // Create database and user
    await conn.query('CREATE DATABASE IF NOT EXISTS sumo');
    print('✓ Database "sumo" ready');
    
    // Try to create a new user for the app (optional)
    try {
      await conn.query('CREATE USER IF NOT EXISTS "sumo_user"@"localhost" IDENTIFIED BY "sumo_password"');
      await conn.query('GRANT ALL PRIVILEGES ON sumo.* TO "sumo_user"@"localhost"');
      await conn.query('FLUSH PRIVILEGES');
      print('✓ Created app user: sumo_user / sumo_password');
    } catch (e) {
      print('Note: Could not create app user (might already exist)');
    }
    
    await conn.close();
    print('\nConnection successful! You can use root or sumo_user to connect.');
  } catch (e) {
    print('✗ Socket connection also failed: $e');
    print('\nThis might be a MySQL setup issue. Try:');
    print('1. Access phpMyAdmin: http://localhost/phpmyadmin');
    print('2. Or restart XAMPP completely');
    print('3. Or reinstall XAMPP with default MySQL settings');
  }
}
