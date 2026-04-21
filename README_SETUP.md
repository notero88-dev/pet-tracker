# PetTrack - Setup en Mac

## 🚀 Instrucciones Rápidas

### 1. Verificar Xcode
```bash
# Verificar que Xcode esté instalado
xcode-select -p

# Si no está instalado, descargarlo del App Store
# Luego instalar command line tools:
xcode-select --install
```

### 2. Abrir el proyecto
```bash
cd pettrack/app

# Instalar dependencias
flutter pub get

# Verificar que todo esté bien
flutter doctor
```

### 3. Ver dispositivos disponibles
```bash
flutter devices

# Deberías ver:
# - iOS Simulator (si Xcode está instalado)
# - iPhone de Nico (si está conectado por USB)
```

### 4. Ejecutar la app

**En el simulador:**
```bash
flutter run
```

**En tu iPhone físico:**
```bash
# Conecta el iPhone por USB
# Confía en la computadora cuando te lo pida

flutter run -d "nombre-de-tu-iphone"

# O simplemente elige cuando Flutter te pregunte
flutter run
```

### 5. Hot Reload durante desarrollo
Una vez que la app esté corriendo:
- `r` = Hot reload (recarga cambios sin reiniciar)
- `R` = Hot restart (reinicia la app completa)
- `q` = Salir

---

## 🔥 Credenciales de prueba

### Traccar (Backend GPS)
- **URL:** http://64.23.156.25:8082
- **Usuario:** nicolasotero2@gmail.com
- **Password:** R2D2¡

### Firebase (Auth)
Ya está configurado, solo necesitas crear una cuenta nueva desde la app.

---

## ⚠️ Notas Importantes

### Google Maps API Key
La app usa Google Maps. Necesitás una API Key:

1. Ve a: https://console.cloud.google.com/
2. Crea/selecciona proyecto "pettrack-colombia"
3. Habilita: **Maps SDK for iOS**
4. Crea API Key (restringida a iOS)
5. Edita `ios/Runner/AppDelegate.swift` línea ~10:
   ```swift
   GMSServices.provideAPIKey("TU_API_KEY_AQUI")
   ```

**Sin API key, el mapa aparecerá gris pero la funcionalidad seguirá funcionando.**

### Primer Build puede tardar
El primer `flutter run` en iOS puede tardar 5-10 minutos porque:
- Compila todas las dependencias
- Genera el bundle de iOS
- Indexa símbolos en Xcode

Los builds siguientes son mucho más rápidos (~30 segundos).

### Dispositivo de prueba
Si ves el error "Developer Mode disabled":
1. Ve a Ajustes → Privacidad y Seguridad → Modo Desarrollador
2. Actívalo
3. Reinicia el iPhone
4. Intenta nuevamente

---

## 🧪 Qué Probar

### ✅ Flujos Completos
1. **Registro**: Crear cuenta nueva (email + password)
2. **Login**: Entrar con cuenta creada
3. **Onboarding**: Escanear QR del dispositivo (o ingresar IMEI manualmente)
4. **Mapa**: Ver ubicación en tiempo real
5. **Modo LIVE**: Activar tracking de 10 segundos
6. **Geofences**: Crear zonas seguras (hasta 3)
7. **Notificaciones**: Recibir alertas (entrada/salida de zona, batería baja)
8. **Perfil**: Editar info de usuario y mascota
9. **Ajustes**: Configurar notificaciones, DND, etc.

### ⚠️ Limitaciones Conocidas
- **No hay device real conectado** → La ubicación será simulada o fija
- **Push notifications** → Necesitan configuración extra de certificados iOS
- **Pagos (Wompi)** → Sprint 5 no implementado aún
- **Algunos iconos/assets** → Pueden estar usando placeholders

---

## 🐛 Si Algo Falla

### Error: "No iOS devices found"
- Conecta el iPhone por USB
- Confía en la Mac cuando te lo pida
- Ejecuta `flutter devices` para verificar

### Error: "Signing requires a development team"
- Abre `ios/Runner.xcworkspace` en Xcode
- Ve a Runner → Signing & Capabilities
- Selecciona tu Apple ID como Team
- Xcode generará el perfil automáticamente

### Error: "CocoaPods not installed"
```bash
sudo gem install cocoapods
cd ios && pod install
cd .. && flutter run
```

### App se crashea al abrir
```bash
# Limpia y recompila
flutter clean
flutter pub get
flutter run
```

---

## 📱 Testing con Device Real

Si querés probar con un **tracker GPS real** (MT710):
1. El device debe estar encendido y con SIM activa
2. Debe estar reportando a: `64.23.156.25:5030`
3. En la app, ingresá el IMEI: **867284062538543**
4. La ubicación debería aparecer en tiempo real

Sin device real, podés usar el **simulador de Traccar**:
- Entrá a http://64.23.156.25:8082
- Crea un device de prueba
- Usa "Tools → Replay" para simular movimiento

---

## 📊 Estado del Proyecto

**Sprints Completos:**
- ✅ Sprint 1: Backend (Traccar, API, Push, Database)
- ✅ Sprint 2: Flutter Core (Auth, API client, Onboarding)
- ✅ Sprint 3: Mapa y Tracking en tiempo real
- ✅ Sprint 4: Geofences
- ⏭️  Sprint 5: Pagos (SALTADO)
- ✅ Sprint 6: Notificaciones
- ✅ Sprint 7: Perfil y Settings
- ⏳ Sprint 8: Testing & Polish (EN PROGRESO)

**Código Total:** ~6,500 líneas Dart (~155KB)

---

## 🆘 Ayuda

Si encontrás bugs o tenés preguntas:
1. Revisá los logs: `flutter logs`
2. Chequea console en Xcode
3. Avisame con captura de pantalla del error

¡Feliz testing! 🎉
