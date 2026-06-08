import 'dart:async';

import 'package:flutter/material.dart';

/// Envuelve la parte autenticada de la app y detecta la inactividad del usuario.
///
/// Funcionamiento:
/// 1. Cada interacción (toque/arrastre) reinicia el temporizador de inactividad.
/// 2. Tras [inactivityDuration] sin actividad, se abre un diálogo con una cuenta
///    regresiva de [countdownSeconds] segundos.
/// 3. Si el usuario pulsa "Seguir conectado", la sesión continúa.
/// 4. Si la cuenta llega a cero, se invoca [onTimeout] para cerrar la sesión.
class InactivityDetector extends StatefulWidget {
  final Widget child;

  /// Acción a ejecutar cuando se agota el tiempo (cerrar sesión).
  final VoidCallback onTimeout;

  /// Tiempo de inactividad permitido antes de mostrar la cuenta regresiva.
  final Duration inactivityDuration;

  /// Segundos de la cuenta regresiva antes de cerrar la sesión.
  final int countdownSeconds;

  const InactivityDetector({
    super.key,
    required this.child,
    required this.onTimeout,
    this.inactivityDuration = const Duration(minutes: 2),
    this.countdownSeconds = 30,
  });

  @override
  State<InactivityDetector> createState() => _InactivityDetectorState();
}

class _InactivityDetectorState extends State<InactivityDetector> {
  Timer? _inactivityTimer;
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    _restartInactivityTimer();
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }

  void _restartInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(widget.inactivityDuration, _onInactive);
  }

  /// Cualquier interacción del usuario reinicia el contador de inactividad,
  /// salvo cuando ya está abierto el diálogo de cuenta regresiva (ahí el usuario
  /// debe pulsar explícitamente "Seguir conectado").
  void _handleUserInteraction([_]) {
    if (_dialogOpen) return;
    _restartInactivityTimer();
  }

  Future<void> _onInactive() async {
    if (_dialogOpen || !mounted) return;
    _dialogOpen = true;

    final bool? continued = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CountdownDialog(seconds: widget.countdownSeconds),
    );

    _dialogOpen = false;
    if (!mounted) return;

    if (continued == true) {
      // El usuario sigue activo: reiniciamos el ciclo.
      _restartInactivityTimer();
    } else {
      // Tiempo agotado: cerrar sesión.
      widget.onTimeout();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listener captura los toques sin interferir con los widgets hijos.
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handleUserInteraction,
      onPointerMove: _handleUserInteraction,
      child: widget.child,
    );
  }
}

/// Diálogo modal con la cuenta regresiva.
///
/// Devuelve `true` (vía `Navigator.pop`) si el usuario decide seguir conectado,
/// y `false` si la cuenta llega a cero.
class _CountdownDialog extends StatefulWidget {
  final int seconds;

  const _CountdownDialog({required this.seconds});

  @override
  State<_CountdownDialog> createState() => _CountdownDialogState();
}

class _CountdownDialogState extends State<_CountdownDialog> {
  late int _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.seconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remaining <= 1) {
        timer.cancel();
        Navigator.of(context).pop(false); // tiempo agotado
      } else {
        setState(() => _remaining--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double progress = _remaining / widget.seconds;

    return AlertDialog(
      backgroundColor: const Color(0xFF1A1530),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          const Icon(Icons.timer_outlined, color: Color(0xFF00E5FF)),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '¿Sigues ahí?',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Tu sesión se cerrará por inactividad en:',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), height: 1.4),
          ),
          const SizedBox(height: 24),
          // Anillo de progreso con el contador en el centro.
          SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 96,
                  height: 96,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 6,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress > 0.33 ? const Color(0xFF00E5FF) : const Color(0xFFFF5252),
                    ),
                  ),
                ),
                Text(
                  '$_remaining',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2979FF),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Seguir conectado',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }
}
