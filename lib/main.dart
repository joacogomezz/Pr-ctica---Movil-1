import 'package:flutter/material.dart';
import 'package:untitled/login_screen.dart';
import 'package:untitled/security_checker.dart';
import 'package:untitled/security_blocked_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const SecurityGateway(),
    );
  }
}

/// Controla la entrada a la aplicación mediante una verificación de seguridad proactiva.
class SecurityGateway extends StatefulWidget {
  const SecurityGateway({super.key});

  @override
  State<SecurityGateway> createState() => _SecurityGatewayState();
}

class _SecurityGatewayState extends State<SecurityGateway> {
  SecurityStatus? _securityStatus;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _runSecurityCheck();
  }

  Future<void> _runSecurityCheck() async {
    setState(() {
      _isLoading = true;
    });

    final status = await SecurityChecker.checkDeviceSecurity();

    if (mounted) {
      setState(() {
        _securityStatus = status;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0C1B), // Color de fondo espacial premium
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
                strokeWidth: 3.5,
              ),
              SizedBox(height: 24),
              Text(
                'Iniciando Auditoría de Seguridad...',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_securityStatus == SecurityStatus.secure) {
      return const LoginScreen();
    } else {
      return SecurityBlockedScreen(
        status: _securityStatus!,
        onRetrySuccess: _runSecurityCheck,
      );
    }
  }
}