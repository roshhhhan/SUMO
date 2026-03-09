import 'package:mysql1/mysql1.dart';

void main() async {
  // Try common XAMPP MySQL password combinations
  final passwords = ['', 'password', 'root', '1234', 'mysql'];
  
  for (final pwd in passwords) {
    print('\nTrying root with password: "${pwd.isEmpty ? "(empty)" : pwd}"');
    
    final settings = ConnectionSettings(
      host: 'localhost',
      port: 3306,
      user: 'root',
      password: pwd,
    );

    try {
      final conn = await MySqlConnection.connect(settings);
      print('✓ SUCCESS! Connected with password: "${pwd.isEmpty ? "(empty)" : pwd}"');
      
      final results = await conn.query('SELECT VERSION()');
      print('MySQL version: ${results.first[0]}');
      
      await conn.close();
      break;
    } catch (e) {
      print('  ✗ Failed: ${e.toString().split('\n').first}');
    }
  }
}
