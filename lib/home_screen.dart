import 'package:flutter/material.dart';
import 'package:untitled/inactivity_detector.dart';
import 'package:untitled/login_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  /// Cierra la sesión y regresa al login, limpiando la pila de navegación.
  void _logout(BuildContext context, {bool byInactivity = false}) {
    // Capturamos el messenger antes de navegar para no usar el context
    // una vez que HomeScreen se desmonta.
    final messenger = ScaffoldMessenger.of(context);

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );

    if (byInactivity) {
      messenger.showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF2979FF),
          behavior: SnackBarBehavior.floating,
          content: Text('Sesión cerrada por inactividad.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return InactivityDetector(
      // Ajusta estos valores a tu gusto (p. ej. minutes: 1 para probar más rápido).
      inactivityDuration: const Duration(seconds: 10),
      countdownSeconds: 10,
      onTimeout: () => _logout(context, byInactivity: true),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Home'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Cerrar sesión',
              onPressed: () => _logout(context),
            ),
          ],
        ),
        body: const Center(
          child: Text('Welcome!'),
        ),
      ),
    );
  }
}
