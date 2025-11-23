# SafeSteps Mobile 📱

Aplicación móvil Flutter para el seguimiento y seguridad de niños mediante geolocalización en tiempo real.

## 🌟 Características

### ✅ Autenticación
- Login con email/contraseña
- Registro de nuevos usuarios
- Inicio de sesión con Google
- Gestión de sesiones con Firebase Auth

### 📍 Seguimiento en Tiempo Real
- Visualización de ubicación de niños en mapa interactivo
- Indicador de batería en cada marcador
- Historial de ubicaciones recientes

### 🛡️ Zonas Seguras
- Creación y gestión de zonas seguras
- Alertas al entrar/salir de zonas
- Visualización de zonas en el mapa

### 🔔 Notificaciones Push
- Alertas en tiempo real con Firebase Cloud Messaging
- Notificaciones de entrada/salida de zonas
- Alertas de batería baja
- Historial de notificaciones en la app

### 👤 Perfil de Usuario
- Gestión de información personal
- Lista de niños vinculados
- Configuración de la cuenta
- Cerrar sesión

## 🛠️ Tecnologías

- **Framework**: Flutter 3.9+
- **Lenguaje**: Dart
- **Estado**: Riverpod 3.0
- **Navegación**: GoRouter 17.0
- **Backend**: Firebase (Auth, Firestore, Cloud Messaging)
- **Mapas**: flutter_map + OpenStreetMap
- **HTTP**: Dio

## 📋 Requisitos Previos

- Flutter SDK 3.9.2 o superior
- Dart SDK 3.9.2 o superior
- Android Studio / VS Code
- Cuenta de Firebase
- Dispositivo Android (minSdk 21) o emulador

## 🚀 Instalación

### 1. Clonar el repositorio
```bash
git clone <tu-repositorio>
cd safe_steps_mobile
```

### 2. Instalar dependencias
```bash
flutter pub get
```

### 3. Configurar Firebase

#### Android
1. Crea un proyecto en [Firebase Console](https://console.firebase.google.com/)
2. Agrega una app Android con el package name: `com.safesteps.safe_steps_mobile`
3. Descarga `google-services.json`
4. Coloca el archivo en `android/app/google-services.json`
5. Habilita Authentication (Email/Password y Google Sign-In)
6. Habilita Cloud Messaging

**⚠️ IMPORTANTE**: El archivo `google-services.json` NO debe subirse a Git (ya está en .gitignore)

### 4. Ejecutar la aplicación
```bash
flutter run
```

## 📁 Estructura del Proyecto

```
lib/
├── main.dart                          # Punto de entrada
├── src/
│   ├── app_router.dart               # Configuración de rutas
│   ├── core/
│   │   └── theme/                    # Temas y colores
│   └── features/
│       ├── auth/                     # Autenticación
│       ├── map/                      # Mapa y ubicaciones
│       ├── zones/                    # Zonas seguras
│       ├── alerts/                   # Alertas y notificaciones
│       ├── profile/                  # Perfil de usuario
│       └── notifications/            # Push notifications
```

## 🔐 Variables de Entorno

Los siguientes archivos contienen información sensible y NO deben subirse a Git:

- `android/app/google-services.json` - Configuración de Firebase
- `ios/Runner/GoogleService-Info.plist` - Configuración de Firebase (iOS)
- Cualquier archivo con API keys o secrets

## 🧪 Testing

### Probar Autenticación
1. Ejecuta la app
2. Regístrate con un email y contraseña
3. Inicia sesión
4. Prueba el inicio de sesión con Google

### Probar Notificaciones Push
1. Busca el FCM Token en la consola (se imprime al iniciar)
2. Ve a Firebase Console → Cloud Messaging
3. Envía una notificación de prueba con tu token
4. Verifica que aparezca en la pantalla de Alertas

## 📝 Notas de Desarrollo

### Arquitectura
El proyecto sigue Clean Architecture con tres capas:
- **Presentation**: UI y providers de Riverpod
- **Domain**: Entidades y casos de uso
- **Data**: Repositorios y servicios

### Estado
Se usa Riverpod 3.x con la nueva API de `Notifier` en lugar de `StateNotifier`.

### Mapas
Se usa `flutter_map` con tiles de OpenStreetMap en lugar de Google Maps para evitar problemas de renderizado en Android.

## 🐛 Problemas Conocidos

- `flutter_local_notifications` temporalmente deshabilitado por problemas de compilación
- Las notificaciones funcionan correctamente con FCM nativo

## 📄 Licencia

Este proyecto es parte de un trabajo universitario de la Universidad Autónoma Gabriel René Moreno.

## 👥 Autores

- Hebert Suarez - Sistema de Información Geográfica
-  - Sistema de Información Geográfica
-  - Sistema de Información Geográfica
-  - Sistema de Información Geográfica
-  - Sistema de Información Geográfica

## 🙏 Agradecimientos

- Firebase por los servicios de backend
- OpenStreetMap por los tiles del mapa
- La comunidad de Flutter
