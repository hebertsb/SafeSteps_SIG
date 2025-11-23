# Configuración de Firebase

Este archivo explica cómo configurar Firebase para el proyecto SafeSteps.

## ⚠️ IMPORTANTE

El archivo `google-services.json` contiene información sensible y NO debe subirse a Git.
Ya está incluido en `.gitignore` para tu seguridad.

## 📋 Pasos para Configurar Firebase

### 1. Crear Proyecto en Firebase

1. Ve a [Firebase Console](https://console.firebase.google.com/)
2. Haz clic en "Agregar proyecto"
3. Nombre del proyecto: `SafeSteps` (o el que prefieras)
4. Sigue los pasos del asistente

### 2. Agregar App Android

1. En la consola de Firebase, haz clic en el ícono de Android
2. Package name: `com.safesteps.safe_steps_mobile`
3. App nickname: `SafeSteps Mobile`
4. SHA-1: (opcional por ahora, necesario para Google Sign-In en producción)

### 3. Descargar google-services.json

1. Descarga el archivo `google-services.json`
2. Colócalo en: `android/app/google-services.json`
3. **NO LO SUBAS A GIT** (ya está en .gitignore)

### 4. Habilitar Servicios en Firebase

#### Authentication
1. Ve a Authentication → Sign-in method
2. Habilita:
   - Email/Password
   - Google (necesitarás configurar OAuth)

#### Cloud Messaging
1. Ve a Cloud Messaging
2. El servicio se habilita automáticamente
3. Aquí podrás enviar notificaciones de prueba

#### Firestore Database (Opcional)
1. Ve a Firestore Database
2. Crea una base de datos
3. Modo: Producción (configura reglas después)

## 🔑 Obtener SHA-1 para Google Sign-In

Para producción, necesitarás el SHA-1 de tu keystore:

### Debug (Desarrollo)
```bash
cd android
./gradlew signingReport
```

Busca el SHA-1 en la salida y agrégalo en Firebase Console.

### Release (Producción)
Necesitarás generar un keystore de release y obtener su SHA-1.

## 📝 Notas

- El archivo `google-services.json` es único para cada proyecto de Firebase
- Si trabajas en equipo, cada miembro debe descargar su propio archivo
- Para CI/CD, usa variables de entorno o secrets del repositorio

## 🆘 Problemas Comunes

### Error: "google-services.json not found"
- Verifica que el archivo esté en `android/app/google-services.json`
- Ejecuta `flutter clean` y vuelve a compilar

### Google Sign-In no funciona
- Verifica que hayas agregado el SHA-1 en Firebase Console
- Asegúrate de que Google Sign-In esté habilitado en Authentication

### Notificaciones no llegan
- Verifica que Cloud Messaging esté habilitado
- Revisa los permisos en AndroidManifest.xml
- Busca el FCM Token en los logs de la app
