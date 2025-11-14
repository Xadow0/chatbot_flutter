# 🧠 TRAINING.IA

> Aplicación/juego interactivo para aprender y comprender el funcionamiento de las **Inteligencias Artificiales Generativas**, usando tecnologías abiertas y gratuitas.

---

## 📖 Descripción del Proyecto

**TRAINING.IA** nace de la necesidad de **divulgar y enseñar** cómo funcionan las inteligencias artificiales generativas y cómo utilizarlas de forma correcta, segura y eficiente.  
La aplicación está diseñada como una experiencia **interactiva y educativa**, permitiendo que cualquier usuario —sin conocimientos técnicos previos— pueda entender los fundamentos de estas herramientas y aprovecharlas al máximo.

El objetivo **no es crear prompts perfectos**, sino **ayudar a comprender cómo y por qué las IAs generan ciertos resultados** y como enfocarlas hacia el objetivo que tengamos, fomentando un uso responsable y consciente de estas tecnologías.

---

## 🚀 Tecnologías Utilizadas (en desarrollo)

- **[Flutter](https://flutter.dev/)** — Framework multiplataforma desarrollado por Google.  
  - Lenguaje: **Dart**
  - Compilación nativa (AOT) para producción y **Hot Reload (JIT)** durante el desarrollo.
- **API de Gemini (Google AI Studio)** — Para integración con modelos de IA generativa de Google.
- **API de ChatGPT (OpenAI)** — Para integración con modelos de IA generativa de OpenAI.
- **Ollama Local (phi3, mistral, etc.)** — Para ejecución de modelos de IA generativa en local, de forma transparente y automatizada para el usuario.
- **Servidor de Ollama (UbuntuServer)** — Para integración con modelos de IA generativa Open Source, ejecutados en un dispositivo con potencia pero de forma totalmente privada. (Tailscale)
- **VSCode** + **Android Studio** — Entornos de desarrollo utilizados.
- Compatibilidad: **Android**, **Windows**, **Linux**, **iOS** y **Web** (en desarrollo).

---

## 🚀 Ejecución del Proyecto

Ejecutar los comandos en la terminal Dart de VSCode en la raíz del programa ("/chatbot_flutter").

### 📱 En Android (emulado o dispositivo real)

1. Abre el proyecto en **VSCode** o **Android Studio**.  
2. Inicia un dispositivo virtual (por ejemplo, *Google Pixel 7*).  
3. Ejecuta los siguientes comandos en la terminal Dart:

```bash
$ flutter devices      # Verifica que el dispositivo está conectado
$ flutter run          # Ejecuta la app en el emulador o dispositivo
```

### 💻 En Windows (emulado o dispositivo real)

1. Asegúrate de tener Flutter configurado para escritorio:
   
 ```bash
$ flutter config --enable-windows-desktop
```

3. Ejecuta la aplicación:
   
```bash
$ flutter run -d windows               # Modo debug
$ flutter run --release -d windows     # Modo release
```

### Para compilar el ejecutable final (.exe):

```bash
$ flutter build windows --release
```

### 💾 Gestión del Historial de Conversaciones

Cada conversación se guarda automáticamente como un fichero .json de forma local, con la fecha y hora de la conversación, en la siguiente ruta:

```bash
Application/Documents/conversations/
```
