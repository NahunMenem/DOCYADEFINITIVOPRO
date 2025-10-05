import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

import '../screens/MedicoEnCasaScreen.dart';
import '../screens/EnfermeroEnCasaScreen.dart';

// 🚨 Bandera global para evitar abrir más de un modal
bool _modalConsultaAbierto = false;

/// 🚀 Modal de consulta entrante tipo Uber con distancia y ETA
Future<bool?> mostrarConsultaEntrante(BuildContext context, String profesionalId) async {
  if (_modalConsultaAbierto) {
    print("⚠️ Ya hay un modal abierto, no se muestra otro");
    return null;
  }
  _modalConsultaAbierto = true;

  int segundosRestantes = 20;
  Timer? timer;

  // 🔹 Pedimos la consulta real al backend
  final response = await http.get(
    Uri.parse("https://docya-railway-production.up.railway.app/consultas/asignadas/$profesionalId"),
    headers: {"Content-Type": "application/json"},
  );

  if (response.statusCode != 200) {
    _modalConsultaAbierto = false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("⚠️ No se pudo obtener la consulta")),
    );
    return null;
  }

  final consulta = jsonDecode(response.body);
  final datos = consulta["consulta"] ?? consulta;

  if (datos == null || datos["id"] == null) {
    _modalConsultaAbierto = false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("📭 No hay consultas disponibles")),
    );
    return null;
  }

  // ✅ nombre del paciente
  String pacienteNombre = datos["paciente_nombre"] ?? "Paciente #${datos["paciente_uuid"]}";
  String iniciales = pacienteNombre.isNotEmpty
      ? pacienteNombre.trim().split(" ").map((e) => e[0]).take(2).join().toUpperCase()
      : "P";

  // ✅ distancia y ETA
  String distanciaInfo =
      "${datos["distancia_km"] ?? "?"} km • ${datos["tiempo_estimado_min"] ?? "?"} min";

  // ✅ tipo de profesional (médico o enfermero)
  String tipo = datos["tipo"] ?? "medico";

  final result = await showModalBottomSheet<bool>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        minChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              // ⏱️ Timer
              timer ??= Timer.periodic(const Duration(seconds: 1), (t) {
                if (segundosRestantes > 0) {
                  setModalState(() {
                    segundosRestantes--;
                  });
                } else {
                  t.cancel();
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context, rootNavigator: true).pop(null);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("⏰ Consulta no respondida, fue reasignada"),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                }
              });

              double progreso = segundosRestantes / 20;

              return SingleChildScrollView(
                controller: scrollController,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🔹 Header con avatar y contador
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: const Color(0xFF14B8A6),
                            child: Text(
                              iniciales,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              pacienteNombre,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 60,
                            width: 60,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CircularProgressIndicator(
                                  value: progreso,
                                  strokeWidth: 6,
                                  backgroundColor: Colors.grey[200],
                                  color: const Color(0xFF14B8A6),
                                ),
                                Text(
                                  "$segundosRestantes",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // 🔹 Cards con info
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                        child: ListTile(
                          leading: const Icon(Icons.location_on, color: Color(0xFF14B8A6)),
                          title: Text(datos["direccion"] ?? "Dirección desconocida"),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                        child: ListTile(
                          leading: const Icon(Icons.healing, color: Color(0xFF14B8A6)),
                          title: Text(datos["motivo"] ?? "Sin motivo"),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                        child: ListTile(
                          leading: const Icon(Icons.directions_car, color: Color(0xFF14B8A6)),
                          title: Text(distanciaInfo),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                        child: const ListTile(
                          leading: Icon(Icons.monetization_on, color: Color(0xFF14B8A6)),
                          title: Text(
                            "Pago: \$30.000",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 🔹 Botones
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade600,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              onPressed: () async {
                                timer?.cancel();
                                Navigator.of(context, rootNavigator: true).pop(false);

                                await http.post(
                                  Uri.parse(
                                    "https://docya-railway-production.up.railway.app/consultas/${datos["id"]}/rechazar",
                                  ),
                                  headers: {"Content-Type": "application/json"},
                                  body: jsonEncode({"medico_id": profesionalId}),
                                );
                              },
                              child: const Text(
                                "Rechazar",
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF14B8A6),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              onPressed: () async {
                                timer?.cancel();

                                final resp = await http.post(
                                  Uri.parse(
                                    "https://docya-railway-production.up.railway.app/consultas/${datos["id"]}/aceptar",
                                  ),
                                  headers: {"Content-Type": "application/json"},
                                  body: jsonEncode({"medico_id": profesionalId}),
                                );

                                if (resp.statusCode == 200) {
                                  // 👇 Arranca el envío de ubicación
                                  final ubicacionManager = UbicacionMedicoManager(
                                    medicoId: int.parse(profesionalId),
                                    baseUrl: "https://docya-railway-production.up.railway.app",
                                  );
                                  ubicacionManager.start();

                                  if (context.mounted) {
                                    Navigator.of(context, rootNavigator: true).pop(true);

                                    Future.microtask(() {
                                      if (tipo == "enfermero") {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => EnfermeroEnCasaScreen(
                                              consultaId: datos["id"],
                                              enfermeroId: int.parse(profesionalId),
                                              pacienteUuid: datos["paciente_uuid"],
                                              pacienteNombre: pacienteNombre,
                                              direccion: datos["direccion"] ?? "Dirección desconocida",
                                              telefono: datos["paciente_telefono"] ?? "Sin número",
                                              motivo: datos["motivo"] ?? "Sin motivo",
                                              lat: (datos["lat"] as num?)?.toDouble() ?? 0.0,
                                              lng: (datos["lng"] as num?)?.toDouble() ?? 0.0,
                                              onFinalizar: () {
                                                Navigator.of(context).popUntil((r) => r.isFirst);
                                              },
                                            ),
                                          ),
                                        );
                                      } else {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => MedicoEnCasaScreen(
                                              consultaId: datos["id"],
                                              medicoId: int.parse(profesionalId),
                                              pacienteUuid: datos["paciente_uuid"],
                                              pacienteNombre: pacienteNombre,
                                              direccion: datos["direccion"] ?? "Dirección desconocida",
                                              telefono: datos["paciente_telefono"] ?? "Sin número",
                                              motivo: datos["motivo"] ?? "Sin motivo",
                                              lat: (datos["lat"] as num?)?.toDouble() ?? 0.0,
                                              lng: (datos["lng"] as num?)?.toDouble() ?? 0.0,
                                              onFinalizar: () {
                                                Navigator.of(context).popUntil((r) => r.isFirst);
                                              },
                                            ),
                                          ),
                                        );
                                      }
                                    });
                                  }
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text("⚠️ Error al aceptar la consulta: ${resp.body}"),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                              child: const Text(
                                "Aceptar",
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    },
  ).whenComplete(() {
    timer?.cancel();
    _modalConsultaAbierto = false; // ✅ liberar bandera al cerrar
  });

  return result;
}

// ===================================================
// 📍 Servicio de ubicación del médico
// ===================================================
class UbicacionMedicoManager {
  final int medicoId;
  final String baseUrl;
  Timer? _timer;

  UbicacionMedicoManager({required this.medicoId, required this.baseUrl});

  void start() {
    Geolocator.requestPermission();

    _timer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        final body = jsonEncode({
          "lat": pos.latitude,
          "lng": pos.longitude,
          "disponible": false,
        });

        await http.post(
          Uri.parse("$baseUrl/medico/$medicoId/ubicacion"),
          headers: {"Content-Type": "application/json"},
          body: body,
        );
      } catch (e) {
        print("❌ Error ubicacion: $e");
      }
    });
  }

  void stop() {
    _timer?.cancel();
  }
}
