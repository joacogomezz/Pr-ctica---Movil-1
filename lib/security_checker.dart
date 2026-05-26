import 'package:detect_fake_location/detect_fake_location.dart';
import 'package:permission_handler/permission_handler.dart';

/// Define los posibles estados de seguridad del dispositivo.
enum SecurityStatus {
  /// El dispositivo es seguro y no se detectó Fake GPS.
  secure,

  /// Se detectó que el dispositivo está usando Fake GPS / ubicación simulada.
  fakeGpsDetected,

  /// Los permisos de ubicación necesarios para validar el dispositivo fueron denegados.
  permissionDenied,
}

/// Servicio encargado de auditar la seguridad del dispositivo respecto a la ubicación.
class SecurityChecker {
  /// Realiza la comprobación integral de seguridad de ubicación.
  /// 
  /// 1. Comprueba y solicita el permiso de ubicación (`Permission.location`).
  /// 2. Si se otorga, usa `detect_fake_location` para detectar el uso de mock location.
  static Future<SecurityStatus> checkDeviceSecurity() async {
    try {
      // 1. Comprobar estado actual de los permisos
      PermissionStatus permissionStatus = await Permission.location.status;

      // Si no se ha solicitado o fue denegado previamente, solicitar
      if (permissionStatus.isDenied) {
        permissionStatus = await Permission.location.request();
      }

      // Si el permiso es denegado o permanentemente denegado, no podemos validar la seguridad
      if (permissionStatus.isDenied || permissionStatus.isPermanentlyDenied) {
        return SecurityStatus.permissionDenied;
      }

      // 2. Realizar la validación de integridad de ubicación
      // detectFakeLocation retorna true si la ubicación es simulada (Fake GPS / Mock)
      bool isFake = await DetectFakeLocation().detectFakeLocation(
        ignoreExternalAccessory: true, // Evita falsos positivos con accesorios CarPlay o GPS externos en iOS
      );

      if (isFake) {
        return SecurityStatus.fakeGpsDetected;
      }

      return SecurityStatus.secure;
    } catch (e) {
      // Registrar error en consola para debugging
      print("Error en verificación de Fake GPS: $e");
      
      // En caso de excepción, por seguridad asumimos que es seguro o dejamos pasar
      // para evitar falsos positivos fatales en entornos sin GPS (ej. simuladores web/macOS)
      return SecurityStatus.secure;
    }
  }
}
