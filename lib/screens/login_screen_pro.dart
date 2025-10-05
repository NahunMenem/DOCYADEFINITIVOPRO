import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../services/auth_service.dart';
import 'register_screen_pro.dart';
import 'home_menu.dart';

/// 🔹 Tipos de snackbar
enum SnackType { success, error, info, warning }

/// 🔹 Widget reutilizable DocYaSnackbar
class DocYaSnackbar {
  static void show(
    BuildContext context, {
    required String title,
    required String message,
    SnackType type = SnackType.success,
  }) {
    Color startColor;
    Color endColor;
    IconData icon;

    switch (type) {
      case SnackType.success:
        startColor = const Color(0xFF14B8A6);
        endColor = const Color(0xFF0F2027);
        icon = Icons.check_circle_rounded;
        break;
      case SnackType.error:
        startColor = Colors.redAccent;
        endColor = const Color(0xFF2C5364);
        icon = Icons.error_rounded;
        break;
      case SnackType.info:
        startColor = Colors.blueAccent;
        endColor = const Color(0xFF2C5364);
        icon = Icons.info_rounded;
        break;
      case SnackType.warning:
        startColor = Colors.amber;
        endColor = const Color(0xFF2C5364);
        icon = Icons.warning_amber_rounded;
        break;
    }

    final snackBar = SnackBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      content: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [startColor, endColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      duration: const Duration(seconds: 3),
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }
}

class LoginScreenPro extends StatefulWidget {
  const LoginScreenPro({super.key});

  @override
  State<LoginScreenPro> createState() => _LoginScreenProState();
}

class _LoginScreenProState extends State<LoginScreenPro> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  final _auth = AuthService();

  String _lastLog = ""; // 👈 para mostrar logs en pantalla

  void _addLog(String msg) {
    setState(() {
      _lastLog += "$msg\n";
    });
    debugPrint(msg);
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("auth_token_medico", token);
    _addLog("💾 Token guardado en SharedPreferences");
  }

  // 👉 Guardar FCM token en backend
  Future<void> _enviarFcmTokenAlBackend(String medicoId) async {
    try {
      String? fcmToken = await FirebaseMessaging.instance.getToken();
      _addLog("🔑 Token FCM obtenido: $fcmToken");

      if (fcmToken != null) {
        final url = Uri.parse(
          "https://docya-railway-production.up.railway.app/medicos/$medicoId/fcm_token",
        );
        _addLog("📡 Enviando token a backend: $url");

        final response = await http.post(
          url,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"fcm_token": fcmToken}),
        );

        _addLog("📡 Respuesta backend: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      _addLog("⚠️ Error enviando token al backend: $e");
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    _addLog("⏳ Enviando credenciales...");

    final loginData = await _auth.loginMedico(
      _email.text.trim(),
      _password.text.trim(),
    );

    setState(() => _loading = false);

    if (loginData != null) {
      _addLog("📥 Respuesta loginData: $loginData");

      await _saveToken(loginData["access_token"]);
      await _enviarFcmTokenAlBackend(loginData["medico_id"].toString());

      DocYaSnackbar.show(
        context,
        title: "✅ Bienvenido",
        message: "Hola ${loginData["full_name"]}, inicio de sesión exitoso.",
        type: SnackType.success,
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _goHome(loginData["full_name"], loginData["medico_id"].toString());
      });
    } else {
      _addLog("❌ Credenciales inválidas");
      DocYaSnackbar.show(
        context,
        title: "⚠️ Error",
        message: "Email o contraseña inválidos.",
        type: SnackType.error,
      );
    }
  }

  void _goHome(String nombreMedico, String medicoId) {
    _addLog("➡️ Navegando a Home con medicoId=$medicoId");
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomeMenu(
          userId: medicoId,
          nombreUsuario: nombreMedico,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF14B8A6);
    const dark = Color(0xFF111827);

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Image.asset('assets/docyapro.png', height: 200),
                      const SizedBox(height: 16),
                      const Text(
                        "DocYa Pro – Médicos",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: dark,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _email,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: const InputDecoration(
                                    labelText: 'Email',
                                    prefixIcon: Icon(Icons.email_outlined),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) {
                                      return 'Ingresá tu email';
                                    }
                                    if (!v.contains('@')) return 'Email inválido';
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _password,
                                  obscureText: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Contraseña',
                                    prefixIcon: Icon(Icons.lock_outline),
                                  ),
                                  validator: (v) => (v == null || v.length < 6)
                                      ? 'Mínimo 6 caracteres'
                                      : null,
                                ),
                                const SizedBox(height: 20),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _loading ? null : _submit,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primary,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: _loading
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white),
                                          )
                                        : const Text('Ingresar',
                                            style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text('¿No tenés cuenta?'),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const RegisterScreenPro(),
                                          ),
                                        );
                                      },
                                      child: const Text('Registrate'),
                                    )
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 🟢 Panel Debug
        
        ],
      ),
    );
  }
}
