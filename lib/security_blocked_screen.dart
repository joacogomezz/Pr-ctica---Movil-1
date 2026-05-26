import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:untitled/security_checker.dart';

/// Pantalla premium con diseño Glassmorphism para bloquear el acceso a la aplicación
/// en caso de detectarse Fake GPS o falta de permisos obligatorios de ubicación.
class SecurityBlockedScreen extends StatefulWidget {
  final SecurityStatus status;
  final VoidCallback onRetrySuccess;

  const SecurityBlockedScreen({
    super.key,
    required this.status,
    required this.onRetrySuccess,
  });

  @override
  State<SecurityBlockedScreen> createState() => _SecurityBlockedScreenState();
}

class _SecurityBlockedScreenState extends State<SecurityBlockedScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticOut,
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleRetry() async {
    if (_isVerifying) return;
    setState(() {
      _isVerifying = true;
    });

    // Pequeña vibración simulada/espera visual premium
    await Future.delayed(const Duration(milliseconds: 1200));

    final newStatus = await SecurityChecker.checkDeviceSecurity();

    if (mounted) {
      setState(() {
        _isVerifying = false;
      });

      if (newStatus == SecurityStatus.secure) {
        // Ejecutar callback para navegar al Login
        widget.onRetrySuccess();
      } else {
        // Animación de rebote si sigue bloqueado
        _animationController.reset();
        _animationController.forward();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFE53935),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                const Icon(Icons.security, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    newStatus == SecurityStatus.fakeGpsDetected
                        ? 'Alerta: Sigue detectándose Fake GPS activo.'
                        : 'Permisos insuficientes para validar el dispositivo.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
  }

  Future<void> _openSettings() async {
    await openAppSettings();
  }

  @override
  Widget build(BuildContext context) {
    final bool isFakeGps = widget.status == SecurityStatus.fakeGpsDetected;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0C1B), // Color de fondo espacial profundo
      body: Stack(
        children: [
          // 1. Fondo de gradientes neón interactivos
          Positioned(
            top: -100,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isFakeGps 
                    ? const Color(0xFFFF3D00).withValues(alpha: 0.2) // Crimson/Naranja para alerta Fake GPS
                    : const Color(0xFF7C4DFF).withValues(alpha: 0.2), // Morado para permisos
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00E5FF).withValues(alpha: 0.15), // Turquesa cian
              ),
            ),
          ),
          
          // 2. Contenido principal centrado
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          padding: const EdgeInsets.all(32.0),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 30,
                                spreadRadius: 5,
                              )
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Icono de alerta con halo de luz
                              Container(
                                width: 88,
                                height: 88,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: isFakeGps
                                        ? [const Color(0xFFFF5252), const Color(0xFFFF1744)]
                                        : [const Color(0xFF7C4DFF), const Color(0xFF651FFF)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (isFakeGps 
                                              ? const Color(0xFFFF1744) 
                                              : const Color(0xFF7C4DFF))
                                          .withValues(alpha: 0.4),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    )
                                  ],
                                ),
                                child: Icon(
                                  isFakeGps ? Icons.location_off_rounded : Icons.security_rounded,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              ),
                              const SizedBox(height: 28),
                              
                              // Título principal
                              Text(
                                isFakeGps ? '¡Fake GPS Detectado!' : 'Acceso Restringido',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Explicación de seguridad
                              Text(
                                isFakeGps
                                    ? 'Hemos detectado el uso de una aplicación para simular tu ubicación geográfica. Por políticas de seguridad, no está permitido el uso de Fake GPS.'
                                    : 'Esta aplicación requiere permisos de ubicación precisos para validar la integridad del dispositivo y garantizar una sesión segura.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 32),

                              // Separador sutil
                              Divider(
                                color: Colors.white.withValues(alpha: 0.1),
                                thickness: 1,
                              ),
                              const SizedBox(height: 20),

                              // Botón de reintento interactivo
                              InkWell(
                                onTap: _isVerifying ? null : _handleRetry,
                                borderRadius: BorderRadius.circular(16),
                                child: Ink(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: _isVerifying
                                          ? [Colors.grey.shade800, Colors.grey.shade900]
                                          : [const Color(0xFF00E5FF), const Color(0xFF2979FF)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: _isVerifying
                                        ? []
                                        : [
                                            BoxShadow(
                                              color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                                              blurRadius: 16,
                                              offset: const Offset(0, 4),
                                            )
                                          ],
                                  ),
                                  child: Container(
                                    height: 56,
                                    alignment: Alignment.center,
                                    child: _isVerifying
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          )
                                        : const Text(
                                            'Verificar de nuevo',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                              
                              // Botón complementario para abrir ajustes del sistema si faltan permisos
                              if (!isFakeGps) ...[
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: _openSettings,
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white.withValues(alpha: 0.6),
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                                  ),
                                  child: const Text(
                                    'Abrir Ajustes del Sistema',
                                    style: TextStyle(
                                      decoration: TextDecoration.underline,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ]
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
