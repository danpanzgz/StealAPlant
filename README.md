# Steal a Plant — Estructura del proyecto (v0.5)

Simulador multiplayer de cultivo, colección, mutaciones y robo entre
jugadores. Clasificación de madurez: **MinimalViolence (Occasional/Mild)** —
todo el conflicto se resuelve mediante alarmas, persecuciones, bloqueos
temporales y efectos cómicos, nunca violencia gráfica.

Este documento describe la arquitectura y el estado actual. El proyecto
está pensado para sincronizarse a Roblox Studio con **Rojo**
(`rojo serve` / `rojo build`) usando `default.project.json`.

## Filosofía de arquitectura

1. **Config-driven**: todo el balance del juego (precios, tiempos de
   crecimiento, rarezas, mutaciones, niveles de jardín) vive en
   `ReplicatedStorage/Shared/Config/*.lua`. Nunca hay números "mágicos"
   sueltos en la lógica de los Services.
2. **Servidor autoritativo**: el cliente nunca concede Cash, plantas,
   mutaciones ni resultados de robo. Todo pasa por un Service de servidor
   que valida antes de aplicar cualquier cambio.
3. **Un Service, una responsabilidad**: `EconomyService` es la única
   puerta para tocar Cash, `DataService` es la única puerta para tocar
   DataStore, etc. Esto evita condiciones de carrera y hace el código
   testeable.
4. **Remotos centralizados**: todos los RemoteEvents/RemoteFunctions se
   declaran una vez en `Net.lua` y se crean al arrancar el servidor
   (`RemoteBootstrap`). Nada se crea "sobre la marcha".

## Estructura de carpetas

```
StealAPlant/
├── default.project.json          # Config de Rojo
├── src/
│   ├── ReplicatedStorage/
│   │   └── Shared/
│   │       ├── Config/
│   │       │   ├── GameConfig.lua          # Ajustes globales
│   │       │   ├── RarityConfig.lua        # 7 rarezas: Common → Celestial
│   │       │   ├── MutationConfig.lua      # Gold/Diamond para nuevas flores
│   │       │   ├── ZoneConfig.lua          # Zonas con requisito de desbloqueo
│   │       │   ├── PlantConfig.lua         # Catálogo de semillas y especies
│   │       │   ├── PlantInstanceConfig.lua # Tamaños y cupo de flores colocadas
│   │       │   ├── ShopConfig.lua          # Packs, gear y peso de stock
│   │       │   ├── PetConfig.lua           # Compañero mascota
│   │       │   └── GardenConfig.lua        # Niveles de jardín
│   │       └── Modules/
│   │           ├── Signal.lua          # Pub/sub interno entre Services
│   │           └── Net.lua             # Wrapper único de Remotes
│   ├── ServerScriptService/
│   │   └── Server/
│   │       ├── Remotes/
│   │       │   └── RemoteBootstrap.lua # Crea todos los remotos al iniciar
│   │       └── Services/                  # Servicios autoritativos del servidor
│   └── StarterPlayer/
│       └── StarterPlayerScripts/
│           └── Client/                 # HUD, tienda, mochila y controles
```

## Estado actual (v0.5 — Mascotas cúbicas y mundo blocky)

Servidor (`Services/`): `DataService`, `EconomyService`, `GardenService`,
`InventoryService`, `PlantService`, `ShopService`, `StealService`,
`DefenseService`, `QuestService`, `DailyRewardService`, `EventService`
(Rain Shower y Gold Rush), `LeaderboardService`, `MonetizationService`
(Game Passes + `ProcessReceipt` idempotente), `MapBuilder` (mapa por código),
`RemoteHandlers` (única entrada de remotos, con rate limit),
`OfflineEarningsService` (bónus por desconexión) y `RebirthService`
(reinicio de progresión con bonificación persistente), además de
`PetService` para crear, equipar y acompañar mascotas cúbicas.

Cliente (`Client/`): `HUDController`, `ShopController`, `InventoryController`,
`GardenController`, `QuestController`, `LeaderboardController`,
`StoreController`, `PlantController`, `SlapController`, `PromptController` y `UI.lua`.
`FarmArt.lua` genera iconos pixelados de cultivos, packs de semillas, huevos,
mascotas y herramientas para la tienda y el inventario.

Nuevos configs: `PlantInstanceConfig`, `ShopConfig`, `DefenseConfig`, `QuestConfig`, `EventConfig`,
`DailyRewardConfig`, `MonetizationConfig`, además del catálogo completo de
plantas y del balance de rebirth/offline earnings en `GameConfig.lua`.

### Controles
- Plantar: equipa semillas y haz clic/toca cualquier punto de tierra dentro
  de tu jardín; el servidor comprueba los límites y evita solapar cultivos.
  Cosechar: **E** o botón táctil sobre una parcela madura.
- Robar: mantén **F** o botón táctil en una planta madura ajena.
- Abrir la mochila: tecla **º** (tecla física Backquote) o botón **Mochila**.
  La mochila predeterminada de Roblox está desactivada para que esa tecla no
  abra dos inventarios a la vez.
- Mando: **Y** abre la mochila, **R2** usa el palo, **A** confirma una
  colocación y **B** la cancela. En móvil se usan los botones táctiles del HUD.
- Palo: botón **SLAP**, tecla **G** o **R2**. Empuja sin causar daño; el
  impulso sube con cada renacimiento.
- La mochila permite buscar en cada sección y, en Plantas, filtrar por rareza
  o mutación y ordenar por peso, rareza, mutación o valor.
- Botones de acción: Tienda · Mochila · Jardín · Tareas · Top · Pases · Palo.
- Los botones de la interfaz se adaptan a móvil, tablet y escritorio; también
  admiten navegación por selección para mando.
- La interfaz usa paneles cuadrados, bordes pixelados y colores de madera,
  tierra, pergamino y cultivos.
- Los controles se definen en `ReplicatedStorage/Inputs` con el Input Action
  System. En Studio habilita `Workspace > Behavior >
  PlayerScriptsUseInputActionSystem = Enabled`; usa `Window > Input > Input
  Action Manager` para revisar o cambiar los bindings.

### Mapa
El mapa se genera con una estética blocky: plaza central con fuente y tres
puestos atendidos por granjeros distintos (semillas, herramientas y huevos),
bancos, faroles y parterres con flores cúbicas; camino de adoquines con
pequeñas islas florales; pradera con variaciones de césped y tierra; y un
estanque escalonado rodeado de flores y un pequeño bosquecillo. Hay cuatro
tipos de árboles con copas cúbicas (roble, pino, cerezo y abedul). Los jardines
son patios vallados, con parcelas y jardineras de entrada. `default.project.json`
configura 13 visitantes para los nuevos builds. El servidor mantiene 12 plazas
sociales personalizadas. En un place ya abierto o publicado, ajusta la capacidad
de visitantes a 13 en Basic Settings y conserva 12 en Server Settings → Custom
Social Slots; guarda/publica el place. Estos ajustes son de solo lectura para
scripts.

### Features nuevas añadidas
- `PlantConfig.GetCatalog()`: índice de especies por zona con nombre,
  rareza, precio y tiempo de crecimiento.
- `RebirthService`: reinicio de progreso, coste escalonado y bonificación por
  descargar la energía del jugador.
- `OfflineEarningsService`: recompensa por minutos desconectados según plantas
  maduras disponibles en el jardín.
- Plaza blocky regenerada sin duplicar el mapa anterior, con base segura,
  parches de terreno y árboles cúbicos variados.

### Ciclo de colección y tienda
- Las semillas se consumen al plantar. El jardín crea parcelas adicionales
  cuando las existentes están ocupadas, por lo que no hay un límite fijo de
  cultivos simultáneos.
- Al reclamar un cultivo maduro se obtiene una flor individual persistente
  con rareza, peso, tamaño (Normal/Large/Giant), mutación (ninguna/Gold/
  Diamond), valor de venta e ingreso por minuto.
- Las parcelas guardan la hora de siembra: su progreso usa tiempo real y
  continúa mientras el jugador está desconectado. Las plantas muestran
  siluetas y frutos distintos por especie, con fases de brote, crecimiento
  y madurez. Las flores maduras emiten polen; Gold y Diamond añaden brillo,
  aura, partículas y luz propios.
- Las flores pueden quedarse en la colección, venderse, regalarse a otro
  jugador o colocarse en el jardín. Solo las colocadas ocupan cupo y generan
  Cash; cada renacimiento aumenta ese cupo. No existe trading.
- Los ingresos offline se calculan sobre las flores colocadas, se limitan a
  3 horas y tienen un tope de $100,000 por ausencia. Los pases propuestos
  amplían el máximo; las plantas que estaban creciendo también avanzan con
  el tiempo real y pueden estar maduras al volver.
- El inventario separa Seeds, Plants, Gear y Pets. La colección de flores se
  puede ordenar por peso, rareza, mutación o valor.
- La tienda y el inventario comparten iconos pixelados de granja para distinguir
  semillas, herramientas, huevos, mascotas y cultivos.
- Los jugadores nuevos reciben un pack Common gratuito. Incluye 3–4 semillas
  Common y 1–2 Uncommon; puede añadir Rare (25%), Legendary (5%) y Mythic
  (0,99%). Los packs Uncommon, Rare, Epic, Legendary, Mythic y Celestial
  tienen recetas acordes a su rareza.
- El stock de packs y gear se genera de forma determinista para un ciclo
  compartido de 5 minutos. El límite por artículo y jugador es aleatorio
  (5–15) y se registra con MemoryStore para evitar obtener compras extra al
  cambiar de servidor.
- Gear disponible: regadera de un uso (crecimiento 5× durante 20 segundos),
  aspersor (crecimiento 1,5× para cultivos nuevos), tótem de mutación y tótem
  de tamaño. Los efectos de los tótems se aplican al plantar.
- Hay un huevo por rareza (Common a Celestial); cada uno puede incubar
  cualquiera de sus cinco mascotas posibles con la misma probabilidad.
  Las mascotas son criaturas cúbicas construidas por código y se pueden
  equipar para que sigan al jugador. Rare, Epic, Legendary, Mythic y
  Celestial añaden brillos, partículas y luz según su rareza.
- Los perfiles antiguos que tenían el gato se migran a la mascota inicial
  cúbica; el sistema ya no requiere modelos externos en `ReplicatedStorage`.
- Los huevos comparten el stock y el límite personal de compra con los packs
  de semillas y el gear.
- Los puestos de semillas, herramientas y huevos abren categorías separadas
  del stock global.
- El incubador cúbico de cada jardín se desbloquea una sola vez por $1,000.
  Los huevos no se pueden incubar hasta comprarlo.
- Las flores pueden colocarse libremente dentro del patio vallado. Para el
  robo hay que llevar la flor hasta la base; el portador corre un 10% más
  despacio y no puede plantar, cosechar, usar gear ni incubar durante el
  trayecto. Si el trayecto se interrumpe, la flor vuelve a su dueño cuando
  sigue en el servidor.
- El domo del jardín protege durante 45 segundos, impide los robos y expulsa
  a los visitantes; tiene 180 segundos de recarga.
- El evento RainShower muestra lluvia local sincronizada con el evento global.
- El stock compartido y los límites entre servidores requieren acceso a
  MemoryStore; activa *Studio Access to API Services* para probarlo en Studio.

### Pases propuestos
Los precios sugeridos en `MonetizationConfig.lua` son: x2 Cash (79 Robux),
Lucky Mutation (199), Pulgar verde —crecimiento 25% más rápido— (99) y
Granjero incansable —hasta 6 horas offline y 25% más de ingresos offline—
(149). El límite de dinero offline sigue siendo $100,000. Los IDs permanecen
en `0` hasta crear cada pase en Creator Hub; Roblox requiere esos IDs para
habilitar las compras.

### Antes de publicar
1. Crea Game Passes y Developer Products en el Creator Hub y pega los IDs
   en `MonetizationConfig.lua` (con `id = 0` los botones avisan de que falta).
2. Activa *Game Settings → Security → Enable Studio Access to API Services*
   para probar DataStore y el leaderboard global en Studio.
3. No se necesitan modelos externos para las mascotas: `PetService` las crea
   usando partes cúbicas y efectos de Roblox.

### Validación en Studio
La compilación de Rojo pasó y el Play smoke test comprobó el suelo seguro, el
jardín inicial, el HUD y la apertura de la tienda. Se revisó el HUD en iPhone
17 Pro vertical, iPad Pro M5 horizontal, portátil y el viewport de Xbox One.
El simulador de Xbox no activa `GamepadEnabled`, así que la navegación con un
mando físico aún debe probarse en consola. El place que ya estaba abierto en
Studio conservaba `MaxPlayers = 60`; el nuevo build serializa el valor 13 y el
place existente debe ajustarse en Basic Settings. Studio sigue mostrando avisos por
dos IDs de recursos no aprobados o incompatibles y un `Workspace.Script`
externo que imprime `Hello world!`; no son errores de carga del juego.

### Pendiente
Sonidos, tutorial guiado con pasos bloqueantes, más defensas y una prueba con
mando físico siguen pendientes. El juego no incluye trading; los regalos se
limitan a semillas y flores.
