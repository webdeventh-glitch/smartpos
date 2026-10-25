import 'package:flutter_test/flutter_test.dart';
import 'package:mysql_client_plus/mysql_client_plus.dart';

void main() {
  test('Test MySQL provisioning on local XAMPP/MySQL', () async {
    print('Testing direct MySQL connection...');
    try {
      final conn = await MySQLConnection.createConnection(
        host: 'localhost',
        port: 3306,
        userName: 'root',
        password: '',
        secure: false,
      );
      await conn.connect();
      print('Direct localhost connection SUCCESS!');
      await conn.close();
    } catch (e, st) {
      print('Direct localhost error: $e\n$st');
    }

    try {
      final conn2 = await MySQLConnection.createConnection(
        host: '127.0.0.1',
        port: 3306,
        userName: 'root',
        password: '',
        secure: false,
      );
      await conn2.connect();
      print('Direct 127.0.0.1 connection SUCCESS!');
      await conn2.close();
    } catch (e, st) {
      print('Direct 127.0.0.1 error: $e\n$st');
    }
  });
}
