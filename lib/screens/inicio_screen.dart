import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../widgets/consulta_entrante_modal.dart';

class InicioScreen extends StatefulWidget {
  final String userId;
  final Function(Map<String, dynamic>)? onAceptarConsulta; // 👈 callback opcional

  const InicioScreen({
    super.key,
    required this.userId,
    this.onAceptarConsulta,
  });

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> {
  bool disponible = false;
  late GoogleMapController _mapController;

  int totalConsultas = 0;
  int totalGanancias = 0;

  WebSocketChannel? _channel;
  Timer? _heartbeatTimer;

  final String _mapStyle = '''
  [
    {"elementType": "geometry","stylers":[{"color":"#212121"}]},
    {"elementType": "labels.icon","stylers":[{"visibility":"off"}]},
    {"elementType": "labels.text.fill","stylers":[{"color":"#757575"}]},
    {"elementType": "labels.text.stroke","stylers":[{"color":"#212121"}]},
    {"featureType":"road","elementType":"geometry.fill","stylers":[{"color":"#2c2c2c"}]},
    {"featureType":"water","elementType":"geometry","stylers":[{"color":"#000000"}]}
  ]
  ''';

  @override
  void initState() {
    super.initState();
    _cargarDisponibilidad();
    _cargarStats();
  }

  @override
  void dispose() {
    _desconectarWS();
    super.dispose();
  }

  // 📌 Cargar disponibilidad desde prefs
  Future<void> _cargarDisponibilidad() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      disponible = prefs.getBool("disponible") ?? false;
    });

    if (disponible) {
      _conectarWS();
    }
  }

  Future<void> _guardarDisponibilidad(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("disponible", value);
  }

  // 📊 Stats del médico
  Future<void> _cargarStats() async {
    try {
      final response = await http.get(
        Uri.parse("https://docya-railway-production.up.railway.app/auth/medico/${widget.userId}/stats"),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (!mounted) return; // 👈 protección
        setState(() {
          totalConsultas = data["consultas"] ?? 0;
          totalGanancias = data["ganancias"] ?? 0;
        });
      }
    } catch (e) {
      print("Error cargando stats: $e");
    }
  }

  // 📡 Conectar al WebSocket con heartbeat
  void _conectarWS() {
    final url = "wss://docya-railway-production.up.railway.app/ws/medico/${widget.userId}";
    print("🔌 Conectando WS: $url");

    _channel = IOWebSocketChannel.connect(Uri.parse(url));

    _channel!.stream.listen((event) async {
      print("📨 Evento WS: $event");
      final data = jsonDecode(event);

      if (data["tipo"] == "consulta_nueva") {
        if (!mounted) return; // 👈 protección
        final aceptada = await mostrarConsultaEntrante(context, widget.userId);

        if (aceptada == true) {
          // 📌 Pasamos todos los datos que necesita HomeMenu/MedicoEnCasaScreen
          widget.onAceptarConsulta?.call({
            "id": data["consulta_id"],
            "paciente_uuid": data["paciente_uuid"],
            "paciente_nombre": data["paciente_nombre"] ?? "Paciente",
            "direccion": data["direccion"],
            "motivo": data["motivo"],
            "lat": data["lat"],
            "lng": data["lng"],
            "medico_id": int.parse(widget.userId), // 👈 el médico logueado
          });
        }

        _cargarStats(); // refrescar stats después de aceptar/rechazar
      }
    }, onError: (err) {
      print("❌ Error WS: $err");
    }, onDone: () {
      print("🔌 Conexión WS cerrada");
      _heartbeatTimer?.cancel();
    });

    // 🔁 Enviar ping cada 25 segundos
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (_channel != null) {
        try {
          _channel!.sink.add(jsonEncode({"tipo": "ping"}));
          print("❤️ Ping enviado");
        } catch (e) {
          print("⚠️ Error enviando ping: $e");
        }
      }
    });
  }

  void _desconectarWS() {
    _heartbeatTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
  }

  // 📌 Actualizar disponibilidad en backend
  Future<void> _actualizarDisponibilidadBackend(bool value) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print("❌ Servicio de ubicación deshabilitado");
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print("❌ Permisos de ubicación denegados");
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print("❌ Permisos de ubicación denegados permanentemente");
        return;
      }

      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final url = Uri.parse(
        "https://docya-railway-production.up.railway.app/medico/${widget.userId}/ubicacion",
      );

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "lat": pos.latitude,
          "lng": pos.longitude,
          "disponible": value,
        }),
      );

      if (response.statusCode == 200) {
        print("✅ Disponibilidad y ubicación actualizadas en backend");
      } else {
        print("❌ Error backend: ${response.body}");
      }
    } catch (e) {
      print("⚠️ Error actualizando disponibilidad: $e");
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _mapController.setMapStyle(_mapStyle);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GoogleMap(
          onMapCreated: _onMapCreated,
          initialCameraPosition: const CameraPosition(
            target: LatLng(-34.6037, -58.3816), // CABA
            zoom: 12,
          ),
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
        ),

        // 📌 Logo
        Positioned(
          top: 45,
          left: 0,
          right: 0,
          child: Center(
            child: Image.asset("assets/DOCYAPROBLANCO.png", height: 40),
          ),
        ),

        // 🔘 Toggle disponibilidad
        Positioned(
          top: 100,
          left: 20,
          right: 20,
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        disponible ? Icons.check_circle : Icons.cancel,
                        color: disponible ? Colors.green : Colors.red,
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        disponible ? "Disponible para consultas" : "No disponible",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  Switch.adaptive(
                    value: disponible,
                    activeColor: const Color(0xFF14B8A6),
                    onChanged: (value) async {
                      if (!mounted) return; // 👈 protección
                      setState(() => disponible = value);
                      await _guardarDisponibilidad(value);
                      await _actualizarDisponibilidadBackend(value);

                      if (value) {
                        _conectarWS();
                      } else {
                        _desconectarWS();
                      }
                    },
                  )
                ],
              ),
            ),
          ),
        ),

        // 📊 Métricas
        Positioned(
          bottom: 30,
          left: 20,
          right: 20,
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text("Consultas", style: TextStyle(fontSize: 14)),
                      const SizedBox(height: 5),
                      Text(
                        "$totalConsultas",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      const Text("Ganancias", style: TextStyle(fontSize: 14)),
                      const SizedBox(height: 5),
                      Text(
                        "\$${totalGanancias.toString()}",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}