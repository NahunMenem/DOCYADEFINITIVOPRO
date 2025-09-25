import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // URL del backend en Railway
  static const String BASE_URL =
      'https://docya-railway-production.up.railway.app';

  // 🔑 Client ID de Google (solo pacientes de momento)
  static const String GOOGLE_CLIENT_ID =
      "130001297631-u4ekqs9n0g88b7d574i04qlngmdk7fbq.apps.googleusercontent.com";

  /// Guardar token en SharedPreferences
  Future<void> saveToken(String key, String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, token);
  }

  Future<String?> getToken(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  Future<void> clearToken(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  /// Login paciente
  Future<Map<String, dynamic>?> loginPaciente(
      String email, String password) async {
    try {
      final res = await http.post(
        Uri.parse('$BASE_URL/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        await saveToken("auth_token", data['access_token']);
        return {
          "access_token": data['access_token'],
          "user_id": data['user']['id'].toString(),
          "full_name": data['user']['full_name'],
        };
      }
      return null;
    } catch (e) {
      print("❌ Error en loginPaciente: $e");
      return null;
    }
  }

  /// Login médico o enfermero
  Future<Map<String, dynamic>?> loginMedico(
      String email, String password) async {
    try {
      final res = await http.post(
        Uri.parse('$BASE_URL/auth/login_medico'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        // ✅ aceptar tanto si viene plano como si viene dentro de "medico"
        final medico = data['medico'] ?? {};

        final medicoId =
            data['medico_id']?.toString() ?? medico['id']?.toString();
        final fullName = data['full_name'] ?? medico['full_name'];
        final tipo = data['tipo'] ?? medico['tipo'] ?? "medico";

        await saveToken("auth_token_medico", data['access_token']);

        return {
          "access_token": data['access_token'],
          "medico_id": medicoId,
          "full_name": fullName,
          "tipo": tipo,
          "validado": medico['validado'] ?? true,
        };
      } else {
        print("❌ Error backend loginMedico: ${res.statusCode} - ${res.body}");
        return null;
      }
    } catch (e) {
      print("❌ Error en loginMedico: $e");
      return null;
    }
  }

  /// Registro paciente
  Future<Map<String, dynamic>?> registerPaciente(
    String name,
    String email,
    String password, {
    String? dni,
    String? telefono,
    String? pais,
    String? provincia,
    String? localidad,
    String? fechaNacimiento,
    bool aceptoCondiciones = false,
    String versionTexto = "v1.0",
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$BASE_URL/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'full_name': name,
          'email': email,
          'password': password,
          'dni': dni,
          'telefono': telefono,
          'pais': pais,
          'provincia': provincia,
          'localidad': localidad,
          'fecha_nacimiento': fechaNacimiento,
          'acepto_condiciones': aceptoCondiciones,
          'version_texto': versionTexto,
        }),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        await saveToken("auth_token", data['access_token']);
        return {
          "access_token": data['access_token'],
          "user_id": data['user']['id'].toString(),
          "full_name": data['user']['full_name'],
        };
      } else {
        print("❌ Error backend registerPaciente: ${res.body}");
        return null;
      }
    } catch (e) {
      print("❌ Error en registerPaciente: $e");
      return null;
    }
  }

  /// Registro profesional (médico o enfermero)
  Future<Map<String, dynamic>> registerMedico({
    required String name,
    required String email,
    required String password,
    required String matricula,
    required String especialidad,
    String tipo = "medico",
    String? telefono,
    String? provincia,
    String? localidad,
    String? dni,
    String? fotoPerfil,
    String? fotoDniFrente,
    String? fotoDniDorso,
    String? selfieDni,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$BASE_URL/auth/register_medico'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'full_name': name,
          'email': email,
          'password': password,
          'matricula': matricula,
          'especialidad': especialidad,
          'tipo': tipo,
          'telefono': telefono,
          'provincia': provincia,
          'localidad': localidad,
          'dni': dni,
          'foto_perfil': fotoPerfil,
          'foto_dni_frente': fotoDniFrente,
          'foto_dni_dorso': fotoDniDorso,
          'selfie_dni': selfieDni,
        }),
      );

      final data = jsonDecode(res.body);

      if (res.statusCode == 200 || res.statusCode == 201) {
        await saveToken("auth_token_medico", data['access_token'] ?? "");
        final medico = data['medico'];

        return {
          "ok": data["ok"] ?? true,
          "mensaje": data["mensaje"] ??
              "Cuenta creada correctamente. Revisa tu correo para activarla.",
          "access_token": data['access_token'],
          "medico_id": medico?['id']?.toString(),
          "full_name": medico?['full_name'],
          "tipo": medico?['tipo'] ?? tipo,
          "validado": medico?['validado'] ?? false,
        };
      } else {
        print("❌ Error backend registerMedico: ${res.body}");
        return {
          "ok": false,
          "detail": data["detail"] ?? "No se pudo registrar."
        };
      }
    } catch (e) {
      print("❌ Error en registerMedico: $e");
      return {"ok": false, "detail": "Error de conexión: $e"};
    }
  }
}
