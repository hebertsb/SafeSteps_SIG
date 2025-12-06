/// Configuración de la API y endpoints del backend
class ApiConfig {
  // ========================================
  // 🔧 CONFIGURACIÓN PRINCIPAL
  // ========================================

  /// URL base del backend
  ///
  /// **IMPORTANTE**: Actualiza esta IP según tu configuración de red
  ///
  /// - Para dispositivo físico: usa tu IP WiFi (ipconfig → Wi-Fi → IPv4)
  /// - Para emulador Android: usa 10.0.2.2:3000
  /// - Para iOS Simulator: usa tu IP WiFi
  /// - Para desarrollo web: usa localhost:3000
  static const String baseUrl = 'http://192.168.0.8:3000';

  // ========================================
  // 📡 ENDPOINTS
  // ========================================

  // Auth endpoints
  static const String loginEndpoint = '/auth/login';
  static const String loginCodeEndpoint = '/auth/login-codigo';
  static const String registerEndpoint = '/auth/register';
  static const String updateFcmTokenEndpoint = '/users/fcm-token';

  // Children endpoints
  static const String childrenEndpoint = '/hijos';
  static String childByIdEndpoint(String id) => '/hijos/$id';
  static String childLocationEndpoint(String id) => '/hijos/$id/location';

  // Safe zones endpoints
  static const String safeZonesEndpoint = '/zonas-seguras';
  static String safeZoneByIdEndpoint(String id) => '/zonas-seguras/$id';

  // Notifications endpoints
  static const String notificationsEndpoint = '/notifications';
  static const String unreadCountEndpoint = '/notifications/unread-count';
  static const String markAllReadEndpoint = '/notifications/mark-all-read';
  static String notificationByIdEndpoint(String id) => '/notifications/$id';

  // ========================================
  // ⚙️ CONFIGURACIÓN DE RED
  // ========================================

  /// Timeout para las peticiones HTTP
  static const Duration connectionTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);

  /// Headers comunes
  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  /// Genera headers con autorización
  static Map<String, String> headersWithAuth(String token) {
    return {...defaultHeaders, 'Authorization': 'Bearer $token'};
  }

  // ========================================
  // 🔍 DEBUGGING
  // ========================================

  /// Habilita logs de peticiones HTTP (solo para desarrollo)
  static const bool enableHttpLogs = true;

  /// Imprime la configuración actual
  static void printConfig() {
    print('🔧 API Configuration');
    print('   Base URL: $baseUrl');
    print('   Timeout: ${connectionTimeout.inSeconds}s');
    print('   HTTP Logs: $enableHttpLogs');
  }
}
