# Brief para reporte: Cierre de sesión por inactividad

> **Instrucción para Claude (navegador):** Con la información de este documento, redacta un
> reporte de práctica formal y bien estructurado sobre la implementación de la funcionalidad
> de *cierre de sesión automático por inactividad* en una app Flutter. Incluye: introducción,
> objetivo, justificación de seguridad, descripción técnica de la solución, explicación del
> flujo, fragmentos de código relevantes y conclusiones. El proyecto es una práctica de la
> materia de Seguridad (Móvil). Usa un tono académico/profesional en español.

---

## 1. Contexto del proyecto

- **Tipo de proyecto:** Aplicación móvil en **Flutter / Dart**.
- **Materia:** Seguridad — Práctica Móvil 1.
- **Funcionalidad implementada:** Detección de inactividad del usuario y cierre automático de
  sesión, con un aviso previo (cuenta regresiva) para que el usuario pueda mantener la sesión.
- **Archivos involucrados:**
  - `lib/inactivity_detector.dart` — **nuevo**, contiene toda la lógica de detección.
  - `lib/home_screen.dart` — **modificado**, integra el detector y define el cierre de sesión.

## 2. Objetivo

Mejorar la seguridad de la sesión del usuario evitando que una sesión quede abierta
indefinidamente si el dispositivo se deja desatendido. Si no hay interacción durante un
periodo configurable, la aplicación:

1. Muestra un diálogo de advertencia con una **cuenta regresiva**.
2. Permite al usuario **continuar la sesión** pulsando un botón.
3. Si la cuenta llega a cero sin respuesta, **cierra la sesión** y vuelve a la pantalla de login.

## 3. Justificación de seguridad

- **Mitiga el riesgo de acceso no autorizado** en dispositivos desatendidos (un atacante con
  acceso físico no encuentra una sesión abierta).
- **Reduce la ventana de exposición** de datos sensibles tras el último uso real.
- Es una práctica recomendada (alineada con controles de *session timeout* de OWASP MASVS /
  ASVS) en aplicaciones que manejan autenticación.

## 4. Diseño de la solución

Se creó un widget reutilizable, **`InactivityDetector`**, que envuelve la parte autenticada de
la aplicación (en este caso, la `HomeScreen`). El enfoque es:

- Usar un **`Listener`** con `HitTestBehavior.translucent` para capturar **toques y arrastres**
  (`onPointerDown`, `onPointerMove`) sin interferir con los widgets hijos.
- Cada interacción **reinicia un temporizador** (`Timer`) de inactividad.
- Al cumplirse `inactivityDuration` sin actividad, se dispara un **diálogo modal** con cuenta
  regresiva (`countdownSeconds`).
- Mientras el diálogo está abierto, las interacciones **no** reinician el temporizador: el
  usuario debe pulsar explícitamente *"Seguir conectado"* (evita que un toque accidental
  mantenga viva la sesión sin intención clara).

### Parámetros configurables

| Parámetro            | Tipo       | Valor por defecto         | Valor usado en la práctica |
|----------------------|------------|---------------------------|----------------------------|
| `inactivityDuration` | `Duration` | `Duration(minutes: 2)`    | `Duration(seconds: 10)`    |
| `countdownSeconds`   | `int`      | `30`                      | `10`                       |
| `onTimeout`          | `VoidCallback` | (requerido)           | Cierra sesión + SnackBar   |

> Nota: en la práctica se usaron 10 s / 10 s para poder **probar el comportamiento rápidamente**.
> En producción se usarían valores mayores (p. ej. 2 minutos de inactividad).

## 5. Flujo de funcionamiento

1. El usuario inicia sesión y llega a `HomeScreen`, que está envuelta por `InactivityDetector`.
2. Al montarse, el detector arranca el temporizador de inactividad (`initState` →
   `_restartInactivityTimer`).
3. Cualquier toque o arrastre reinicia el temporizador (`_handleUserInteraction`).
4. Si pasan `inactivityDuration` sin interacción, se ejecuta `_onInactive`, que abre el
   `_CountdownDialog` (modal, **no descartable** tocando fuera: `barrierDismissible: false`).
5. El diálogo muestra un **anillo de progreso circular** con el número de segundos restantes.
   El color cambia a rojo cuando queda poco tiempo (umbral en 33%).
6. Dos desenlaces:
   - El usuario pulsa **"Seguir conectado"** → el diálogo devuelve `true` → se reinicia el ciclo.
   - La cuenta llega a **cero** → el diálogo devuelve `false` → se invoca `onTimeout`, que
     cierra la sesión y muestra un `SnackBar`: *"Sesión cerrada por inactividad."*

## 6. Detalles técnicos relevantes

- **Gestión de ciclo de vida:** los `Timer` se cancelan en `dispose()` para evitar fugas de
  memoria y callbacks sobre widgets ya desmontados.
- **Verificación `mounted`:** antes de usar el `context` o llamar a `setState` tras una
  operación asíncrona, se comprueba `mounted` para evitar errores.
- **Bandera `_dialogOpen`:** evita abrir múltiples diálogos simultáneos y desactiva el reinicio
  por interacción mientras la cuenta regresiva está visible.
- **Captura del `ScaffoldMessenger` antes de navegar:** en `_logout` se obtiene el `messenger`
  *antes* de `pushAndRemoveUntil`, porque tras navegar el `context` de `HomeScreen` deja de ser
  válido para mostrar el `SnackBar`.
- **Limpieza de pila de navegación:** `pushAndRemoveUntil(..., (route) => false)` elimina todas
  las rutas anteriores, de modo que el usuario no pueda volver atrás a la sesión cerrada.

## 7. Fragmentos de código clave

### 7.1 Detección de interacción y temporizador (`inactivity_detector.dart`)

```dart
void _restartInactivityTimer() {
  _inactivityTimer?.cancel();
  _inactivityTimer = Timer(widget.inactivityDuration, _onInactive);
}

/// Cualquier interacción reinicia el contador, salvo cuando el diálogo ya está abierto.
void _handleUserInteraction([_]) {
  if (_dialogOpen) return;
  _restartInactivityTimer();
}

@override
Widget build(BuildContext context) {
  return Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: _handleUserInteraction,
    onPointerMove: _handleUserInteraction,
    child: widget.child,
  );
}
```

### 7.2 Apertura del diálogo y decisión final

```dart
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
    _restartInactivityTimer();   // El usuario sigue activo
  } else {
    widget.onTimeout();          // Tiempo agotado: cerrar sesión
  }
}
```

### 7.3 Cuenta regresiva del diálogo

```dart
_timer = Timer.periodic(const Duration(seconds: 1), (timer) {
  if (!mounted) { timer.cancel(); return; }
  if (_remaining <= 1) {
    timer.cancel();
    Navigator.of(context).pop(false); // tiempo agotado
  } else {
    setState(() => _remaining--);
  }
});
```

### 7.4 Integración y cierre de sesión (`home_screen.dart`)

```dart
return InactivityDetector(
  inactivityDuration: const Duration(seconds: 10),
  countdownSeconds: 10,
  onTimeout: () => _logout(context, byInactivity: true),
  child: Scaffold(/* ... contenido de la pantalla Home ... */),
);

void _logout(BuildContext context, {bool byInactivity = false}) {
  final messenger = ScaffoldMessenger.of(context);

  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (route) => false,
  );

  if (byInactivity) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Sesión cerrada por inactividad.')),
    );
  }
}
```

## 8. Interfaz del diálogo (UX)

- Título *"¿Sigues ahí?"* con ícono de temporizador.
- Texto: *"Tu sesión se cerrará por inactividad en:"*.
- **Anillo de progreso circular** (`CircularProgressIndicator`) con el contador en el centro;
  cambia de cian (`#00E5FF`) a rojo (`#FF5252`) cuando queda poco tiempo.
- Botón único de ancho completo: **"Seguir conectado"**.
- Estética oscura coherente con el resto de la app (fondo `#1A1530`, bordes redondeados).

## 9. Pruebas realizadas

- Se dejó la pantalla `Home` sin tocar y, tras 10 s, apareció el diálogo de cuenta regresiva.
- Al pulsar *"Seguir conectado"*, la sesión continuó y el ciclo se reinició.
- Al dejar correr la cuenta hasta cero, la app regresó al login mostrando el `SnackBar` de aviso.
- Se verificó que tocar la pantalla durante uso normal reinicia el contador (no se dispara el
  diálogo mientras hay actividad).

## 10. Conclusiones (puntos a desarrollar en el reporte)

- La funcionalidad refuerza la seguridad de la sesión con un costo de implementación bajo y un
  componente **reutilizable** (`InactivityDetector`) que puede envolver cualquier pantalla
  autenticada.
- El diseño separa responsabilidades: detección de inactividad vs. UI del diálogo.
- Se cuidaron buenas prácticas de Flutter (cancelación de timers, verificación de `mounted`,
  manejo seguro del `BuildContext` tras navegación).
- Como mejora futura, los tiempos podrían leerse de configuración remota o ajustarse según el
  nivel de sensibilidad de cada pantalla.
