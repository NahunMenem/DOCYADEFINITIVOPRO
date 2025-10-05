import 'package:flutter/material.dart';

class TestScreen extends StatelessWidget {
  final String medicoId;
  final String nombre;

  const TestScreen({super.key, required this.medicoId, required this.nombre});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Test Screen")),
      body: Center(
        child: Text(
          "🚀 Entraste OK\nID: $medicoId\nNombre: $nombre",
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
