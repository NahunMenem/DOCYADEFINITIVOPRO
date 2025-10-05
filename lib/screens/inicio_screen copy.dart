import 'package:flutter/material.dart';

class InicioScreen extends StatelessWidget {
  final String userId;
  const InicioScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Inicio")),
      body: Center(
        child: Text(
          "✅ Bienvenido! Tu ID es $userId",
          style: const TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
