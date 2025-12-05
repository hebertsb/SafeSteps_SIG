import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const baseUrl = 'http://localhost:3000';
  final client = http.Client();
  


  // 1. Registrar Tutor
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final tutorEmail = 'tutor_$timestamp@test.com';
  final password = 'password123';
  

  try {
    final regResponse = await client.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'nombre': 'Tutor Test',
        'email': tutorEmail,
        'password': password,
        'tipo': 'tutor'
      }),
    );

    
    // Si falla porque ya existe (poco probable por el timestamp), intentamos login directo
    if (regResponse.statusCode != 201 && regResponse.statusCode != 200) {
      ('⚠️ No se pudo registrar (quizás ya existe). Intentando login...');
    } else {
      ('✅ Tutor registrado.');
    }
  } catch (e) {
    ('❌ Error de conexión en registro: $e');
    return;
  }

  // 2. Login Tutor

  String tutorToken = '';
  try {
    final loginResponse = await client.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': tutorEmail,
        'password': password,
      }),
    );
    
    if (loginResponse.statusCode == 200 || loginResponse.statusCode == 201) {
      final data = jsonDecode(loginResponse.body);
      tutorToken = data['access_token'];

    } else {
      ('❌ Error login tutor: ${loginResponse.body}');
      return;
    }
  } catch (e) {
    ('❌ Error login: $e');
    return;
  }

  // 3. Crear Hijo
  final childEmail = 'child_$timestamp@test.com';

  try {
    final childResponse = await client.post(
      Uri.parse('$baseUrl/hijos'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $tutorToken',
      },
      body: jsonEncode({
        'nombre': 'Hijo Test',
        'email': childEmail,
        'password': password,
        'latitud': -16.5,
        'longitud': -68.1
      }),
    );
    

    
    if (childResponse.statusCode == 201) {
      ('✅ Hijo creado exitosamente.');
    } else {
      ('❌ Error creando hijo: ${childResponse.body}');
      return;
    }
  } catch (e) {
    ('❌ Error creando hijo: $e');
    return;
  }

  // 4. Login Hijo

  try {
    final childLoginResponse = await client.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': childEmail,
        'password': password,
      }),
    );
    
    if (childLoginResponse.statusCode == 200 || childLoginResponse.statusCode == 201) {
      final data = jsonDecode(childLoginResponse.body);
      final user = data['user'];
      final token = data['access_token'];
      

      
      // Decodificar JWT para buscar el rol
      final parts = token.split('.');
      if (parts.length == 3) {
        final payload = parts[1];
        final normalized = base64Url.normalize(payload);
        final resp = utf8.decode(base64Url.decode(normalized));
        final payloadMap = jsonDecode(resp);
        ('📦 JWT Payload: $payloadMap');
        
        // Verificar rol en JWT
        final jwtRole = payloadMap['tipo'] ?? payloadMap['role'];
        ('Rol en JWT: "$jwtRole"');
      }

      // Verificar Rol en objeto usuario
      final role = user['tipo'] ?? user['role'];
      

      
      if (role == 'hijo') {
        ('✅ Rol encontrado en objeto User.');
      } else {
        ('⚠️ Rol NO encontrado en objeto User.');
        
        // 5. Prueba Heurística: Intentar obtener hijos con token de hijo
        ('\n5️⃣ Prueba Heurística: Accediendo a GET /hijos con token de hijo...');
        try {
          final hijosResponse = await client.get(
            Uri.parse('$baseUrl/hijos'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          );
          ('Status GET /hijos: ${hijosResponse.statusCode}');
          if (hijosResponse.statusCode == 200) {
            ('⚠️ El hijo PUEDE ver la lista de hijos (No sirve para distinguir).');
          } else {
            ('✅ El hijo NO puede ver la lista (Status ${hijosResponse.statusCode}). Sirve para distinguir.');
          }
        } catch (e) {
          ('Error en prueba heurística: $e');
        }
      }
    } else {
      ('❌ Error login hijo: ${childLoginResponse.body}');
    }
  } catch (e) {
    ('❌ Error login hijo: $e');
  }
}
