import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, debugPrint;
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// Define los posibles estados de seguridad del dispositivo.
enum SecurityStatus {
  /// El dispositivo es seguro y no se detectó Fake GPS.
  secure,

  /// Se detectó que el dispositivo está usando Fake GPS / ubicación simulada.
  fakeGpsDetected,

  /// Los permisos de ubicación necesarios para validar el dispositivo fueron denegados,
  /// o el servicio de ubicación del sistema está apagado.
  permissionDenied,
}

/// Servicio encargado de auditar la seguridad del dispositivo respecto a la ubicación.
class SecurityChecker {
  /// Tiempo máximo de espera para obtener una ubicación *fresca*.
  static const Duration _locationTimeout = Duration(seconds: 10);

  /// Realiza la comprobación integral de seguridad de ubicación.
  ///
  /// 1. Comprueba/solicita el permiso de ubicación (`Permission.location`).
  /// 2. Verifica que el servicio de ubicación del sistema esté activo.
  /// 3. Pide una ubicación **fresca** y comprueba si es simulada (`Position.isMocked`).
  ///
  /// IMPORTANTE: se solicita un *fix* nuevo a propósito en lugar de leer la última
  /// ubicación conocida. La última ubicación conocida (`getLastKnownLocation`) queda
  /// cacheada y marcada como simulada aunque el usuario ya haya apagado el Fake GPS,
  /// lo que provocaba que la app siguiera reportando "Fake GPS detectado" para siempre.
  /// Al pedir un fix nuevo, en cuanto el Fake GPS se apaga la lectura vuelve a ser real.
  static Future<SecurityStatus> checkDeviceSecurity() async {
    try {
      // 1. Comprobar/solicitar permiso de ubicación.
      PermissionStatus permissionStatus = await Permission.location.status;
      if (permissionStatus.isDenied) {
        permissionStatus = await Permission.location.request();
      }
      if (permissionStatus.isDenied || permissionStatus.isPermanentlyDenied) {
        return SecurityStatus.permissionDenied;
      }

      // 2. El servicio de ubicación debe estar encendido para poder validar.
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return SecurityStatus.permissionDenied;
      }

      // 3. Pedir una ubicación FRESCA (no la cacheada) y evaluar si es simulada.
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: _buildLocationSettings(),
      );

      if (position.isMocked) {
        return SecurityStatus.fakeGpsDetected;
      }

      return SecurityStatus.secure;
    } on TimeoutException catch (_) {
      // No se obtuvo un fix a tiempo (mala señal/interior): no bloqueamos al usuario.
      debugPrint("Verificación de Fake GPS: tiempo de espera agotado al obtener ubicación.");
      return SecurityStatus.secure;
    } on LocationServiceDisabledException catch (_) {
      return SecurityStatus.permissionDenied;
    } on PermissionDeniedException catch (_) {
      return SecurityStatus.permissionDenied;
    } catch (e) {
      // En entornos sin GPS (simuladores web/escritorio) evitamos falsos positivos fatales.
      debugPrint("Error en verificación de Fake GPS: $e");
      return SecurityStatus.secure;
    }
  }

  /// Configura cómo se pide la ubicación según la plataforma.
  ///
  /// En Android usamos `forceLocationManager: true` para leer el flag `isMock`
  /// directamente del `LocationManager` nativo (más fiable para detectar simulación
  /// que el proveedor fusionado de Google Play Services).
  static LocationSettings _buildLocationSettings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.medium,
        forceLocationManager: true,
        timeLimit: _locationTimeout,
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.medium,
      timeLimit: _locationTimeout,
    );
  }
}
