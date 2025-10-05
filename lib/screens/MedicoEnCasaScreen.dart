import 'dart:convert';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../widgets/docya_snackbar.dart'; 
import 'package:docya_pro/screens/chat_medico_screen.dart';
import 'package:docya_pro/screens/certificado_screen.dart';
import 'package:docya_pro/screens/receta_screen.dart';
import 'package:docya_pro/screens/historia_clinica_screen.dart';

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

//
// ==================== PANTALLA PRINCIPAL ====================
//

class MedicoEnCasaScreen extends StatefulWidget {
  final VoidCallback? onFinalizar;
  final int consultaId;
  final int medicoId;
  final String pacienteUuid;
  final String pacienteNombre;
  final String direccion;
  final String motivo;
  final String telefono;
  final double lat;
  final double lng;
  final UbicacionMedicoManager? ubicacionManager; // 👈 agregado

  const MedicoEnCasaScreen({
    super.key,
    this.onFinalizar,
    required this.consultaId,
    required this.medicoId,
    required this.pacienteUuid,
    required this.pacienteNombre,
    required this.direccion,
    required this.motivo,
    required this.telefono,
    required this.lat,
    required this.lng,
    this.ubicacionManager,
  });

  @override
  State<MedicoEnCasaScreen> createState() => _MedicoEnCasaScreenState();
}

class _MedicoEnCasaScreenState extends State<MedicoEnCasaScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _consultaIniciada = false;
  bool _puedeIniciar = false;
  double? _distancia;
  UbicacionMedicoManager? _ubicacionManager;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _chequearUbicacion();
    _ubicacionManager = widget.ubicacionManager;
  }

  Future<void> _chequearUbicacion() async {
    try {
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      double distancia = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        widget.lat,
        widget.lng,
      );
      setState(() {
        _distancia = distancia;
        _puedeIniciar = distancia <= 200;
      });
    } catch (e) {
      debugPrint("⚠️ Error ubicacion: $e");
    }
  }

  Future<void> iniciarConsulta() async {
    final url = Uri.parse(
        "https://docya-railway-production.up.railway.app/consultas/${widget.consultaId}/iniciar");
    final resp = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"medico_id": widget.medicoId}),
    );

    if (resp.statusCode == 200 && mounted) {
      setState(() => _consultaIniciada = true);
      DocYaSnackbar.show(
        context,
        title: "✅ Consulta iniciada",
        message: "Podés comenzar con la atención",
        type: SnackType.success,
      );
    } else {
      DocYaSnackbar.show(
        context,
        title: "⚠️ Error",
        message: "No se pudo iniciar: ${resp.body}",
        type: SnackType.error,
      );
    }
  }

  Future<void> marcarEnCamino() async {
    final url = Uri.parse(
        "https://docya-railway-production.up.railway.app/consultas/${widget.consultaId}/encamino");
    await http.post(url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"medico_id": widget.medicoId}));
  }

  Future<void> finalizarConsulta() async {
    final url = Uri.parse(
        "https://docya-railway-production.up.railway.app/consultas/${widget.consultaId}/finalizar");
    final resp = await http.post(url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"medico_id": widget.medicoId}));
    if (resp.statusCode == 200 && mounted) {
      // 👇 detener envío de ubicación
      _ubicacionManager?.stop();

      Navigator.pop(context);
      DocYaSnackbar.show(
        context,
        title: "✅ Consulta finalizada",
        message: "Se registró correctamente la finalización",
        type: SnackType.success,
      );
    } else {
      DocYaSnackbar.show(
        context,
        title: "⚠️ Error",
        message: "No se pudo finalizar: ${resp.body}",
        type: SnackType.error,
      );
    }
  }

  Future<void> _abrirEnGoogleMaps(String direccion) async {
    final query = Uri.encodeComponent(direccion);
    final url = "https://www.google.com/maps/search/?api=1&query=$query";
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildTabButton(
      BuildContext context, String text, IconData icon, VoidCallback onTap) {
    return Center(
      child: ElevatedButton.icon(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF14B8A6),
          minimumSize: const Size(220, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: Icon(icon, color: Colors.white),
        label: Text(text,
            style: const TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _openModal(BuildContext context, Widget formWidget) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: const Color(0xFF203A43).withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            controller: controller,
            child: formWidget,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Consulta en curso"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.chat),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatMedicoScreen(
                    consultaId: widget.consultaId,
                    medicoId: widget.medicoId,
                    nombreMedico: "Dr. ${widget.medicoId}",
                  ),
                ),
              );
            },
          )
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: kToolbarHeight + 20),

            // HEADER
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    border: Border.all(color: Colors.white24),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Image.asset("assets/DOCYAPROBLANCO.png", height: 60),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.person,
                              color: Color(0xFF14B8A6), size: 28),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(widget.pacienteNombre,
                                style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.phone, color: Color(0xFF14B8A6)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(widget.telefono,
                                style: const TextStyle(color: Colors.white70)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on,
                              color: Color(0xFF14B8A6)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(widget.direccion,
                                style: const TextStyle(color: Colors.white70)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.healing, color: Color(0xFF14B8A6)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text("Motivo: ${widget.motivo}",
                                style: const TextStyle(color: Colors.white70)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () async {
                          await marcarEnCamino();
                          _abrirEnGoogleMaps(widget.direccion);
                          _chequearUbicacion();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.tealAccent,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.navigation, color: Colors.black),
                        label: const Text("Abrir en Google Maps",
                            style: TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _puedeIniciar ? iniciarConsulta : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF14B8A6),
                          disabledBackgroundColor: Colors.grey,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.play_circle, color: Colors.white),
                        label: Text(
                          _puedeIniciar ? "Iniciar Consulta" : "Acérquese al domicilio",
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                      if (_distancia != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            "Distancia actual: ${_distancia!.toStringAsFixed(0)} m",
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // TABS
            TabBar(
              controller: _tabController,
              labelColor: Colors.tealAccent,
              unselectedLabelColor: Colors.white54,
              indicatorColor: Colors.tealAccent,
              tabs: const [
                Tab(icon: Icon(Icons.assignment), text: "Certificado"),
                Tab(icon: Icon(Icons.medication), text: "Receta"),
                Tab(icon: Icon(Icons.note_alt), text: "Historia Clínica"),
              ],
            ),

            // CONTENIDO
            Expanded(
              child: !_consultaIniciada
                  ? const Center(
                      child: Text(
                        "⚠️ Debe iniciar la consulta al llegar al domicilio",
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildTabButton(
                          context,
                          "Generar Certificado",
                          Icons.assignment,
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CertificadoScreen(
                                consultaId: widget.consultaId,
                                medicoId: widget.medicoId,
                                pacienteUuid: widget.pacienteUuid,
                              ),
                            ),
                          ),
                        ),
                        _buildTabButton(
                          context,
                          "Generar Receta",
                          Icons.medication,
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RecetaScreen(
                                consultaId: widget.consultaId,
                                medicoId: widget.medicoId,
                                pacienteUuid: widget.pacienteUuid,
                              ),
                            ),
                          ),
                        ),
                        _buildTabButton(
                          context,
                          "Historia Clínica",
                          Icons.note_alt,
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => HistoriaClinicaScreen(
                                consultaId: widget.consultaId,
                                medicoId: widget.medicoId,
                                pacienteUuid: widget.pacienteUuid,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),

      // BOTÓN FINALIZAR
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: _consultaIniciada ? finalizarConsulta : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              disabledBackgroundColor: Colors.grey,
              minimumSize: const Size(double.infinity, 55),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.check_circle, color: Colors.white),
            label: const Text("Finalizar Consulta",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ),
        ),
      ),
    );
  }
}
