import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // 🌐 URL del backend en Railway
  static const String BASE_URL =
      'https://docya-railway-production.up.railway.app';

  // 🔑 Client ID de Google (solo pacientes de momento)
  static const String GOOGLE_CLIENT_ID =
      "130001297631-u4ekqs9n0g88b7d574i04qlngmdk7fbq.apps.googleusercontent.com";

  /// Guardar token en SharedPreferences
  Future<void> saveToken(String key, String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, token);
    print("💾 Token guardado [$key]");
  }

  Future<String?> getToken(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(key);
    print("🔑 Token leído [$key]: $token");
    return token;
  }

  Future<void> clearToken(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
    print("🗑️ Token eliminado [$key]");
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

      print("📡 Respuesta cruda loginPaciente (${res.statusCode}): ${res.body}");

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['access_token'] == null) {
          print("❌ Backend no devolvió access_token en loginPaciente");
          return null;
        }

        await saveToken("auth_token", data['access_token']);
        final result = {
          "access_token": data['access_token'],
          "user_id": data['user']['id'].toString(),
          "full_name": data['user']['full_name'],
        };
        print("✅ loginPaciente parseado: $result");
        return result;
      }
      print("❌ Error backend loginPaciente: ${res.statusCode} - ${res.body}");
      return null;
    } catch (e) {
      print("❌ Excepción en loginPaciente: $e");
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

      print("📡 Respuesta cruda loginMedico (${res.statusCode}): ${res.body}");

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        if (data['access_token'] == null) {
          print("❌ Backend no devolvió access_token en loginMedico");
          return null;
        }

        // ✅ aceptar tanto si viene plano como si viene dentro de "medico"
        final medico = data['medico'] ?? {};

        final medicoId =
            data['medico_id']?.toString() ?? medico['id']?.toString();
        final fullName = data['full_name'] ?? medico['full_name'] ?? "Médico";

        if (medicoId == null) {
          print("❌ Backend no devolvió medico_id");
          return null;
        }

        await saveToken("auth_token_medico", data['access_token']);

        final result = {
          "access_token": data['access_token'],
          "medico_id": medicoId,
          "full_name": fullName,
          "tipo": data['tipo'] ?? medico['tipo'] ?? "medico",
          "validado": medico['validado'] ?? true,
        };

        print("✅ loginMedico parseado: $result");
        return result;
      } else {
        print("❌ Error backend loginMedico: ${res.statusCode} - ${res.body}");
        return null;
      }
    } catch (e) {
      print("❌ Excepción en loginMedico: $e");
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

      print("📡 Respuesta cruda registerPaciente (${res.statusCode}): ${res.body}");

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);

        await saveToken("auth_token", data['access_token']);
        final result = {
          "access_token": data['access_token'],
          "user_id": data['user']['id'].toString(),
          "full_name": data['user']['full_name'],
        };
        print("✅ registerPaciente parseado: $result");
        return result;
      } else {
        print("❌ Error backend registerPaciente: ${res.body}");
        return null;
      }
    } catch (e) {
      print("❌ Excepción en registerPaciente: $e");
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

      print("📡 Respuesta cruda registerMedico (${res.statusCode}): ${res.body}");

      final data = jsonDecode(res.body);

      if (res.statusCode == 200 || res.statusCode == 201) {
        await saveToken("auth_token_medico", data['access_token'] ?? "");
        final medico = data['medico'];

        final result = {
          "ok": data["ok"] ?? true,
          "mensaje": data["mensaje"] ??
              "Cuenta creada correctamente. Revisa tu correo para activarla.",
          "access_token": data['access_token'],
          "medico_id": medico?['id']?.toString(),
          "full_name": medico?['full_name'],
          "tipo": medico?['tipo'] ?? tipo,
          "validado": medico?['validado'] ?? false,
        };
        print("✅ registerMedico parseado: $result");
        return result;
      } else {
        print("❌ Error backend registerMedico: ${res.body}");
        return {
          "ok": false,
          "detail": data["detail"] ?? "No se pudo registrar."
        };
      }
    } catch (e) {
      print("❌ Excepción en registerMedico: $e");
      return {"ok": false, "detail": "Error de conexión: $e"};
    }
  }
}
