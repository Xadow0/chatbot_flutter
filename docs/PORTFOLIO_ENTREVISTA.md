# TRAINING.IA — Guía de presentación en entrevista

Documento de referencia para explicar el proyecto en una entrevista técnica: qué es,
cómo está construido, por qué se eligió cada tecnología y qué problemas reales
hubo que resolver.

---

## 1. El pitch (30 segundos)

> TRAINING.IA es una aplicación multiplataforma —Windows, Linux, macOS y Android— que
> enseña a usar IA generativa y, en la misma app, deja practicar con ella. Combina cinco
> módulos formativos interactivos con un chat que habla con cuatro proveedores distintos:
> Gemini, OpenAI, un servidor Ollama privado y un modelo ejecutándose en local, que la
> propia app instala y gestiona sin que el usuario toque una terminal. El historial se
> cifra extremo a extremo antes de subirse a la nube. Son unas 32.000 líneas de Dart en
> arquitectura limpia, con 870 tests unitarios.

**Los tres ganchos que conviene soltar pronto**, porque son los que generan preguntas:

1. **IA local zero-config**: la app detecta, descarga, instala y arranca Ollama, y
   descarga el modelo, mostrando progreso real. En tres sistemas operativos.
2. **Cifrado E2E multi-dispositivo**: AES-256-GCM con una clave que el servidor nunca
   ve, y que aun así funciona al cambiar de dispositivo.
3. **Cuatro proveedores de IA tras una sola interfaz**: añadir uno nuevo son ~100 líneas
   y cero cambios en la UI.

---

## 2. El problema que resuelve

El proyecto nace de una observación: la gente usa IA generativa sin entender qué hace,
y las barreras de entrada empujan a malos hábitos.

| Barrera | Cómo la aborda la app |
|---|---|
| No se entiende el funcionamiento | Cinco módulos de aprendizaje **interactivos**, no texto estático |
| No hay dónde practicar lo aprendido | El chat está en la misma app: aprendes y pruebas sin cambiar de contexto |
| Requiere pagar una API o ceder datos | Modo local: el modelo se ejecuta en el dispositivo, sin internet ni claves |
| Se repiten los mismos prompts a mano | Gestor de comandos: plantillas de prompt reutilizables y organizables |
| Preocupación por la privacidad del historial | Historial local por defecto; si se sincroniza, va cifrado E2E |

La decisión de producto importante: **no obligar a elegir entre nube y privacidad**.
Hay tres caminos de ejecución (nube con clave propia, servidor privado, local) y el
usuario cambia entre ellos en caliente sin perder la conversación.

---

## 3. Stack técnico y por qué

| Tecnología | Para qué | Por qué esa y no otra |
|---|---|---|
| **Flutter / Dart** | Todo el cliente | Un solo código para móvil **y escritorio**. El escritorio no era opcional: la IA local solo tiene sentido ahí. React Native no cubre desktop con la misma madurez; Electron no cubre móvil |
| **Provider** (`ChangeNotifier`) | Estado de UI | Estado del chat = una lista + un stream. BLoC habría añadido eventos y estados por cada interacción sin aportar nada. Es además la opción recomendada por el equipo de Flutter |
| **GetIt** | Inyección de dependencias | Construye el grafo de objetos **fuera** de Flutter, así que los tests instancian repositorios y providers sin `WidgetTester` ni contexto |
| **Firebase Auth + Firestore** | Cuentas y sincronización opcional | Sin backend propio que mantener; el modelo de datos es documental y por usuario, que es exactamente lo que Firestore hace bien. La sincronización es *opcional*: la app funciona entera sin cuenta |
| **flutter_secure_storage** | API keys y salt de cifrado | Keystore/EncryptedSharedPreferences en Android, Keychain en iOS, almacén de credenciales en escritorio. `SharedPreferences` habría sido texto plano |
| **encrypt + crypto** | AES-256-GCM y HMAC-SHA256 | GCM da cifrado *y* autenticación en una pasada; más rápido y más seguro que CBC + HMAC manual |
| **google_generative_ai** | Gemini | SDK oficial: streaming y `safetySettings` sin parsear SSE a mano |
| **http / dio** | OpenAI y Ollama | Ninguno de los dos necesita SDK: son REST con streaming, y controlar el parseo permite cancelar descargas cerrando el cliente |
| **process_run** | Instalación de Ollama | Ejecutar procesos del sistema (instaladores, `ollama serve`) con captura de stdout/stderr |
| **mocktail / mockito** | Tests | `mocktail` no necesita generación de código, lo que agiliza escribir mocks de repositorios |
| **markdown_widget** | Render de respuestas | Los modelos responden en Markdown; había que renderizar tablas, listas y bloques de código |

---

## 4. Arquitectura

**Clean Architecture con organización feature-first.** No hay carpetas `models/`,
`views/`, `controllers/` a nivel global: cada funcionalidad es una vertical completa.

```
lib/
├── core/            # transversal: cifrado, secure storage, DI, utilidades
├── config/          # rutas y temas
├── shared/          # widgets reutilizables
└── features/
    ├── auth/        # ┐
    ├── chat/        # │
    ├── commands/    # ├─ cada una con domain / data / presentation
    ├── learning/    # │
    ├── settings/    # │
    └── menu/        # ┘
```

Las tres capas de cada feature:

- **`domain/`** — Entidades (`MessageEntity`, `CommandEntity`, con `Equatable`),
  interfaces de repositorio (`IChatRepository`, `ICommandRepository`,
  `IConversationRepository`, `AuthRepository`) y casos de uso (`CommandProcessor`).
  No importa Flutter, ni Firebase, ni `http`. Es Dart puro.
- **`data/`** — Modelos DTO con serialización JSON, *datasources* (Gemini, OpenAI,
  Ollama remoto, Ollama local, Firestore, ficheros locales) e implementaciones de los
  repositorios.
- **`presentation/`** — Providers (`ChangeNotifier`) y páginas/widgets.

**La regla de dependencia**: `presentation → domain ← data`. Los providers dependen de
interfaces, nunca de Firebase ni de `http`. Esa única decisión es la que permite tener
870 tests que corren en segundos sin emulador, sin red y sin proyecto de Firebase.

### Inyección de dependencias

Todo el grafo se declara en `lib/core/di/injection_container.dart`:

- **Singletons** para lo que mantiene estado o conexiones: `AuthProvider`,
  `AIServiceSelector`, los datasources, los servicios de cifrado.
- **Factories** para lo que debe nacer limpio: `ChatProvider`, `ThemeProvider`.

**Por qué GetIt *y* Provider, si parecen redundantes**: hacen cosas distintas. GetIt
construye el grafo de objetos (y es utilizable desde un test unitario sin Flutter);
Provider solo se encarga de que los widgets se reconstruyan cuando ese objeto notifica.
`ChangeNotifierProvider.value(value: di.sl<AuthProvider>())` es literalmente la costura
entre ambos.

### Cómo se rompió una dependencia circular

`Auth` necesita saber de `Commands` (al borrar cuenta, hay que borrar comandos),
`Commands` necesita saber de `Auth` (¿está la sincronización activa?) y `Chat` necesita
ambas. Inyectar las instancias entre sí habría creado un ciclo irresoluble en GetIt.

La solución fue **inyectar funciones en lugar de objetos**:

```dart
sl.registerLazySingleton<ICommandRepository>(() => CommandRepositoryImpl(
  sl(), sl(), sl(), sl(),
  () => sl<AuthProvider>().isCloudSyncEnabled,   // callback, no la instancia
));
```

El repositorio no conoce `AuthProvider`; conoce un `bool Function()`. En los tests eso
es `() => true` o `() => false`, sin montar autenticación.

---

## 5. El patrón central: Strategy + Adapter para los proveedores de IA

**El problema**: cuatro backends con interfaces completamente distintas.

| Proveedor | Cómo se habla con él | Formato del stream |
|---|---|---|
| Gemini | SDK oficial `google_generative_ai` | `Stream<GenerateContentResponse>` |
| OpenAI | REST manual | SSE: líneas `data: {...}` con `delta.content` |
| Ollama remoto | REST contra servidor propio (Tailscale) | NDJSON, un objeto por línea |
| Ollama local | REST contra `localhost:11434` | NDJSON |

Y un requisito: la UI no debe enterarse de ninguna de esas diferencias.

**La solución**, en tres piezas:

1. **`AIServiceBase`** — la interfaz. Solo dos métodos, ambos devuelven
   `Stream<String>`:
   - `generateContentStream(prompt)` — **con** memoria de conversación
   - `generateContentStreamWithoutHistory(prompt)` — **sin** memoria

2. **Un adaptador por proveedor** (`GeminiServiceAdapter`, `OpenAIServiceAdapter`,
   `OllamaServiceAdapter`, `LocalOllamaServiceAdapter`) que traduce el formato nativo
   a ese contrato común.

3. **`AIServiceSelector`** — un `ChangeNotifier` que mantiene el proveedor activo,
   vigila disponibilidad de cada uno y expone `getCurrentAdapter()`. Es Strategy
   (intercambia el algoritmo en caliente) y Factory (lo construye) a la vez.

**Por qué son dos métodos y no uno**: es una decisión de diseño deliberada. Un comando
`/traducir hola` no debe contaminar el contexto de la conversación —si lo hiciera, la
siguiente pregunta del usuario se respondería como si siguiera hablando de traducciones.
Los comandos van por la vía sin historial; el chat normal, por la vía con historial.

**El beneficio concreto**: añadir Claude o Mistral es un datasource nuevo, un adaptador
nuevo y un valor más en el enum. Cero cambios en `ChatProvider` y cero en la UI.

---

## 6. Streaming token a token

El chat no espera a la respuesta completa. El flujo en `ChatProvider`:

1. Se añade el mensaje del usuario y **un mensaje del bot vacío** con un ID conocido.
2. Se pide el `Stream<String>` al adaptador activo.
3. Cada *chunk* se acumula en un `StringBuffer` y se **reemplaza** el mensaje del bot
   por índice, seguido de `notifyListeners()` → efecto máquina de escribir.
4. Un `Completer<void>` permite hacer `await` del final del stream; `onDone` y `onError`
   lo completan. Se usa `cancelOnError: true`.
5. En el `finally` se limpia la suscripción, se bajan los flags y se marca
   `_hasUnsavedChanges = true`.

Dos detalles que merece la pena mencionar porque revelan cuidado:

- **Los errores se escriben dentro del propio mensaje**, concatenados a lo ya recibido.
  Si el modelo falla a mitad de respuesta, el usuario conserva lo generado hasta ahí en
  lugar de perderlo por un snackbar.
- **La suscripción se guarda en un campo** y se cancela en `dispose()`, para no dejar
  streams huérfanos al salir de la pantalla.

---

## 7. IA local zero-config: la parte más difícil

**El objetivo**: que alguien sin conocimientos técnicos ejecute un LLM en su ordenador
sin abrir una terminal ni saber qué es Ollama.

`OllamaManagedService.initialize()` es una máquina de estados de cinco pasos que emite
`Stream<LocalOllamaInstallProgress>` con progreso real:

**Paso 1 — Detectar.** `ollama --version` desde el PATH. Si falla, se buscan rutas
conocidas por sistema operativo (`%UserProfile%\AppData\Local\Programs\Ollama\`,
`/usr/local/bin/ollama`, `/Applications/Ollama.app/Contents/Resources/ollama`,
`/usr/bin/ollama`) y, si funciona por PATH, se localiza con `where`/`which`.

**Paso 2 — Instalar si hace falta.**
- *Windows*: descarga del instalador por HTTP **en streaming**, con progreso calculado
  sobre `contentLength`, y ejecución silenciosa con `/VERYSILENT /SUPPRESSMSGBOXES
  /NORESTART`. Se borra el temporal al terminar.
- *macOS / Linux*: script oficial de instalación vía `process_run`.

**Paso 3 — Arrancar el servicio.** `ollama serve` en modo *detached* en Windows, con `&`
en Unix, y *polling* de hasta 30 segundos contra `/api/version` hasta que responde.

**Paso 4 — Descargar el modelo.** `POST /api/pull` con `stream: true`. La respuesta es
NDJSON: cada línea trae `status`, `completed` y `total`, lo que da una barra de progreso
en bytes reales. La descarga es cancelable cerrando el `http.Client`.

**Paso 5 — Verificar.** Prueba de inferencia real antes de marcar el estado como `ready`.

**La lección de ingeniería que conviene contar aquí**: *nunca confiar en el código de
salida del instalador*. En Windows devuelve valores distintos según versión, y el PATH
de la sesión actual no se refresca tras instalar. Por eso, después de cada instalación
se vuelve a ejecutar la detección completa; la única fuente de verdad es "¿responde el
binario ahora mismo?". Misma filosofía en el arranque: no se asume que el servicio está
listo, se hace *polling* hasta que contesta.

Además: *health check* periódico, temporizador de inactividad, gestión de modelos desde
la UI (listar con tamaño y fecha, borrar con la salvaguarda de no permitir eliminar el
último) y `isPlatformSupported`, que oculta la opción entera en Android en lugar de
dejar que falle.

---

## 8. Seguridad

### API keys

Nunca en `SharedPreferences`. `ApiKeysManager` sobre `flutter_secure_storage`, con una
jerarquía explícita: **clave del usuario > clave por defecto del `.env`**. Detalles:

- Validación de formato antes de guardar (`sk-` y ≥40 caracteres en OpenAI; longitud y
  charset en Gemini).
- *Preview* enmascarado en la UI (`••••••••...a1b2`); la clave por defecto **nunca** se
  muestra ni se expone al usuario.
- Migración automática desde `.env` en el primer arranque, y un *onboarding* si no hay
  ninguna clave configurada.
- `.env` y `firebase_options.dart` están en `.gitignore`.

### Cifrado del historial

Antes de subir nada a Firestore se cifra con **AES-256-GCM**, IV aleatorio de 96 bits
**por mensaje**, en formato `base64(iv):base64(ciphertext)`. Solo se cifra el campo
`content`: los metadatos quedan en claro para poder ordenar y consultar sin descifrar
la colección entera.

**El problema difícil fue la derivación de la clave.** La primera versión ataba la clave
al dispositivo. Funcionaba... hasta que el usuario cambiaba de móvil y sus conversaciones
quedaban ilegibles para siempre. Rediseño completo:

```
clave = HMAC-SHA256(uid_del_usuario, salt)
```

donde el `salt` son 32 bytes aleatorios que viven en el almacenamiento seguro local **y
se suben a Firebase cifrados con la contraseña del login**. Al entrar en un dispositivo
nuevo: se descarga el salt cifrado, se descifra con la contraseña que el usuario acaba
de teclear y se guarda localmente. Todo transparente — el usuario no introduce nada
extra, no hay frase de recuperación, y la contraseña vive solo en memoria durante el
flujo (se limpia siempre en el `finally`). Hay versionado del salt por *timestamp* y un
método de re-cifrado para cuando se cambia la contraseña.

Firebase almacena el salt cifrado y los mensajes cifrados, pero nunca la contraseña ni
la clave: **sin la contraseña del usuario, el contenido no es recuperable ni siquiera
por quien administre el proyecto.**

**Sé honesto sobre el límite si te preguntan**: la derivación es un HMAC-SHA256 de una
sola pasada, no un KDF con coste computacional. Para producción usaría Argon2id o
PBKDF2 con iteraciones altas, y un salt aleatorio por usuario también en esa capa (hoy
la constante de derivación desde contraseña es fija). Es la primera deuda técnica que
pagaría, y reconocerlo suele puntuar más que defenderlo.

---

## 9. Persistencia offline-first

**La regla**: *la escritura local nunca depende de la nube.*

`saveConversation()` escribe el JSON a disco y **solo después** intenta subirlo a
Firestore, dentro de un `try/catch` que **no propaga** el error. Si Firebase falla, está
caído o el cifrado no está inicializado, el usuario no pierde absolutamente nada: se
registra el aviso y se sincronizará más tarde.

- **Conversaciones**: un JSON por conversación en
  `ApplicationDocuments/conversations/`, nombrado con fecha y hora.
- **Comandos y carpetas**: almacenamiento local seguro + Firestore.
- **Sincronización bidireccional** al activar sync o al iniciar sesión: sube lo que
  falta, baja lo que no existe localmente, con deduplicación (por `trigger` en comandos,
  por nombre de fichero en conversaciones) y contadores ↑/↓ que se reportan a la UI.
- **Guardado por ciclo de vida**: un `WidgetsBindingObserver` guarda la conversación
  cuando la app pasa a segundo plano (`paused`, `detached`, `hidden`). Cerrar la app no
  pierde la conversación.

---

## 10. Sistema de comandos: un pequeño motor de prompts

`CommandProcessor` es el caso de uso del dominio. Detecta mensajes que empiezan por `/`,
**ordena los comandos por longitud de trigger descendente** —para que `/tra` no capture
lo que iba dirigido a `/traducir`— y despacha según el tipo.

Las plantillas usan marcadores: `{{content}}`, `{{targetLanguage}}`. Los comandos de
sistema no son editables ni borrables, y esa salvaguarda está **en el repositorio, no
solo en la UI** (`throw` explícito si alguien intenta modificarlos por otra vía).

Lo más entretenido de contar es `/traducir`, que usa un `LanguageDetector` propio: una
tabla con nombre del idioma en español, inglés y nativo, códigos ISO 639-1/639-3 y
alias comunes; el matching se hace ordenando las variantes por longitud descendente para
evitar falsos positivos (que `cat` no dispare "catalán"). Sin dependencias externas.

Los comandos alimentan además las *quick responses* del chat, organizables en carpetas
con arrastrar y soltar.

---

## 11. Módulos de aprendizaje

Cinco módulos: fundamentos de IA generativa, el arte del prompting, evaluar e iterar,
prompts avanzados, y ética y buenas prácticas. El progreso se persiste en
`SharedPreferences`.

El que conviene destacar es el **módulo 3**, porque no es contenido estático: el usuario
escribe un prompt real, la IA responde en streaming, y entonces se le guía por una
secuencia de iteraciones —*reformular → aclarar → ejemplificar → acotar*— reutilizando
la misma infraestructura de chat. El módulo 4 hace algo parecido enseñando el sistema de
comandos con ejercicios prácticos. Es aprender haciendo, sobre la infraestructura que ya
existía.

---

## 12. Testing

**870 casos de prueba en 26 ficheros (11.754 líneas), ~50 % de cobertura global**,
concentrada donde importa: dominio, capa de datos y providers.

Qué se prueba:

- **Entidades y modelos** — ida y vuelta de serialización JSON.
- **`CommandProcessor`** — detección, sustitución de plantillas, comandos inexistentes,
  contenido vacío, detección de idioma.
- **`ChatProvider`** — streaming simulado con `StreamController`, cambio de proveedor,
  degradación automática cuando cae Ollama, guardado y ciclo de vida.
- **`AuthProvider`** — login, registro, activación de sync, borrado de cuenta.
- **`ConversationEncryptionService`** — cifrado/descifrado de ida y vuelta, contraseña
  incorrecta, retrocompatibilidad con mensajes antiguos sin cifrar.
- **`ApiKeysManager`** — jerarquía usuario/defecto, validación de formatos.
- **Instalador de Ollama** — detección por plataforma y manejo de fallos.

**Lo importante no es el número, es por qué fue posible**: como los providers dependen
de interfaces y no de Firebase ni de `http`, los tests montan el grafo con mocks
(`mocktail`) y corren en segundos sin emulador, sin red y sin proyecto de Firebase.
La arquitectura no es decoración: es lo que hace que el proyecto sea testeable.

**Lo que falta, y hay que decirlo**: no hay *widget tests* ni tests de integración, y no
hay CI. Toda la cobertura es de lógica.

---

## 13. Multiplataforma

Un único código para Windows, Linux, macOS y Android. El código específico de sistema
operativo está **aislado en un solo fichero** (`local_ollama_installer.dart`, con
`Platform.isWindows / isMacOS / isLinux`) en lugar de repartido por la app, y se cierra
con `isPlatformSupported`, que hace desaparecer la funcionalidad local en Android en vez
de dejar que reviente. Tema claro/oscuro con Material 3 vía `ThemeProvider`.

---

## 14. Retos concretos (la pregunta "¿qué fue lo más difícil?")

Estos son los cinco que mejor funcionan como respuesta, con su moraleja:

1. **Instalación silenciosa fiable en tres sistemas operativos.**
   *Moraleja*: verificar siempre después de actuar, nunca confiar en el código de salida.

2. **Cifrado que sobreviva al cambio de dispositivo.**
   *Moraleja*: el primer diseño perdía datos del usuario; detectarlo obligó a rehacer el
   esquema entero de derivación de claves. Vale más rediseñar que parchear.

3. **Dependencia circular entre Auth, Commands y Chat.**
   *Moraleja*: inyectar una función (`bool Function()`) en lugar de un objeto rompe el
   ciclo y además simplifica los tests.

4. **El servidor Ollama que se cae a mitad de conversación.**
   *Moraleja*: la conexión se expone como `Stream<ConnectionInfo>`; al perderse, la app
   degrada automáticamente a Gemini y **escribe el aviso dentro del propio chat**, donde
   el usuario lo va a leer, en vez de en un snackbar que desaparece.

5. **Streaming cancelable sin fugas de memoria.**
   *Moraleja*: toda suscripción se guarda y se cancela en `dispose()` y en el `finally`.

---

## 15. Qué mejoraría (prepara esta respuesta: siempre la preguntan)

- **KDF real** (Argon2id o PBKDF2 con iteraciones) para derivar de la contraseña, y
  salt aleatorio por usuario también en esa capa.
- **CI en GitHub Actions**: `flutter analyze` + `flutter test` + build por plataforma.
  Hoy no existe y es lo más barato de añadir con más retorno.
- **Partir `ChatProvider`**, que tiene 1.161 líneas y demasiadas responsabilidades
  (estado de UI + orquestación de IA + persistencia). Lo dividiría en casos de uso:
  `SendMessageUseCase`, `SaveConversationUseCase`, `ManageProviderUseCase`.
- **Subir la cobertura al 80 %** y añadir *widget tests* y algún test de integración.
- **Reglas de seguridad de Firestore** versionadas en el repositorio y testeadas.
- **i18n real**: hoy los textos están en español directamente en el código.
- **Paginación del historial**: ahora se cargan todas las conversaciones de golpe.

---

## 16. Los números

| Métrica | Valor |
|---|---|
| Líneas de Dart (`lib/`) | 32.314 en 94 ficheros |
| Líneas de test | 11.754 en 26 ficheros |
| Casos de prueba | 870 |
| Cobertura global | ~50 % |
| Plataformas | 4 (Windows, Linux, macOS, Android) |
| Proveedores de IA | 4 |
| Features desacopladas | 6 |
| Commits | 65, entre noviembre de 2025 y febrero de 2026 |

---

## 17. Preguntas probables y respuestas cortas

**¿Por qué Flutter y no nativo o React Native?**
Necesitaba escritorio y móvil con un solo código, y el escritorio era innegociable
porque la ejecución local de modelos solo tiene sentido ahí. Flutter compila a nativo en
las cuatro plataformas y me daba la misma UI en todas.

**¿Por qué Provider y no BLoC o Riverpod?**
Por proporcionalidad. El estado del chat es una lista de mensajes y un stream; BLoC
habría añadido un evento y un estado por cada interacción sin resolver ningún problema
que yo tuviera. El coste que asumo es que `notifyListeners()` reconstruye de más, y lo
mitigo separando providers por feature y usando `Consumer` acotado en lugar de escuchar
desde la raíz. Si el proyecto creciera, Riverpod sería la migración natural.

**¿Para qué GetIt si ya tienes Provider?**
Resuelven cosas distintas. GetIt construye el grafo de dependencias y es usable desde un
test unitario puro; Provider solo propaga cambios al árbol de widgets. Los uso juntos:
GetIt crea, Provider expone.

**¿Cómo pruebas algo que depende de Firebase?**
No lo pruebo contra Firebase. Firebase solo existe en `data/datasources`; todo lo demás
depende de interfaces del dominio, que en los tests son mocks de `mocktail`.

**¿Cómo evitas filtrar una API key?**
Almacenamiento seguro del sistema operativo (Keystore/Keychain), nunca preferencias en
claro; `.env` y `firebase_options.dart` fuera de git; la clave por defecto jamás se
muestra en la UI; validación de formato antes de guardar.

**¿Qué pasa si el usuario no tiene internet?**
Funciona: modelo local, historial local y escritura siempre a disco antes que a la nube.
La sincronización es una capa opcional, no un requisito.

**¿Y si Firebase se cae?**
Nada se pierde. El guardado local es la operación primaria y el fallo de red se captura
sin propagarse; la conversación se sincroniza en el siguiente intento.

**¿Cómo añadirías Claude como proveedor?**
Un datasource que traduzca su API de streaming, un adaptador que implemente
`AIServiceBase`, un valor más en el enum `AIProvider` y su registro en el contenedor de
DI. Ni `ChatProvider` ni la UI se tocan.

**¿Qué harías distinto si empezaras hoy?**
Montaría CI desde el primer commit, usaría un KDF con coste en lugar de HMAC de una
pasada, y dividiría `ChatProvider` en casos de uso antes de que llegara a mil líneas.

---

## 18. Cómo enseñarlo en cinco minutos de demo

1. **Menú → Aprendizaje → Módulo 3.** Escribir un prompt malo a propósito y dejar que la
   app guíe la iteración. Enseña producto, no solo código.
2. **Chat → selector de modelo.** Cambiar de Gemini a Ollama local en caliente y señalar
   que la conversación se mantiene: ahí es donde se explica el patrón Adapter.
3. **Ajustes → Gestión de modelos locales.** Enseñar la descarga con progreso real. Aquí
   es donde surge la conversación sobre instalación multi-SO.
4. **Comandos.** Crear un comando propio con `{{content}}` y usarlo en el chat.
5. **Ajustes → Sincronización.** Contar el esquema de cifrado mientras se activa. Es el
   mejor cierre porque es la parte con más profundidad técnica.

---

*Proyecto: TRAINING.IA — Leonardo Sánchez Ferrer. Licencia CC BY 4.0.*
