# Steal a Plant — Estructura del proyecto (v0.9)

Simulador multiplayer de cultivo, colección, mutaciones y robo entre
jugadores. Clasificación de madurez: **MinimalViolence (Occasional/Mild)** —
todo el conflicto se resuelve mediante alarmas, persecuciones, bloqueos
temporales y efectos cómicos, nunca violencia gráfica.

El proyecto se sincroniza con Roblox Studio mediante **Rojo**
(`rojo serve` / `rojo build`) usando `default.project.json`; la versión de
Rojo está fijada en `rokit.toml` (`rokit install`).

> **Cómo saber qué versión corre en tu Studio:** el HUD muestra
> `Steal a Plant vX.Y` abajo a la izquierda (`GameConfig.Version`). Si no
> coincide con este README, Studio está sincronizando otra rama.

## Filosofía de arquitectura

1. **Config-driven**: balance, precios, tiempos, rarezas, mutaciones,
   estilos de valla, sonidos y eventos viven en
   `ReplicatedStorage/Shared/Config/*.lua`. No hay números mágicos en la
   lógica.
2. **Servidor autoritativo**: el cliente nunca concede Cash, plantas,
   mutaciones, compras ni resultados de robo. Cada remoto valida tipos y
   tiene límite de frecuencia por jugador (`RemoteHandlers`).
3. **Un Service, una responsabilidad**: `EconomyService` es la única puerta
   al Cash (rechaza NaN/infinito) y `DataService` la única al DataStore.
4. **Remotos centralizados**: se declaran en `Net.lua` y se crean al arrancar
   (`RemoteBootstrap`).
5. **Cliente aislado**: cada controlador se inicia con `safeInit` (pcall), de
   modo que un error en uno no rompe el resto de la interfaz.

## Estructura

```
StealAPlant/
├── default.project.json
├── rokit.toml
└── src/
    ├── ReplicatedStorage/
    │   ├── Shared/Config/      # Balance y contenido (ver tabla)
    │   ├── Shared/Modules/     # Net, Signal, PlantBlueprints, PlantModels,
    │   │                       # MutationUtil, MutationVisuals
    │   └── InputController/    # Acciones de entrada (slap, mochila...)
    ├── ServerScriptService/Server/
    │   ├── Main.server.lua     # Arranque, jugadores y red de seguridad
    │   ├── Remotes/RemoteBootstrap.lua
    │   └── Services/           # Lógica autoritativa
    └── StarterPlayer/StarterPlayerScripts/Client/
        ├── Main.client.lua     # Arranque con safeInit
        ├── Controllers/        # HUD, tienda, mochila, audio, efectos, cielo...
        ├── Modules/FarmArt.lua # Iconos pixelados (cultivos, huevos, mascotas)
        └── UI.lua              # Helpers de interfaz
```

### Configs (`Shared/Config`)
| Archivo | Contenido |
|---|---|
| `GameConfig` | Ajustes globales, versión, DataStore, robo, rebirth, offline |
| `PlantConfig` / `PlantInstanceConfig` | Catálogo de especies; tamaños (Normal/Big/Giant), peso, nombre mostrado y cupo de flores colocadas |
| `MutationConfig` | Efectos: Wet, Frozen, Shiny, Gold, Rainbow, Diamond (probabilidad y multiplicador) |
| `RarityConfig` | 7 rarezas, Common → Celestial |
| `PetConfig` | 35 mascotas (5 por rareza), bonus por rareza y animal de cada una |
| `GardenConfig` | Niveles, layout de 12 jardines y **6 estilos de valla por Rebirth** |
| `EventConfig` | RainShower (crecimiento x1.2 + Wet) y GoldRush (venta x1.5) |
| `SoundConfig` | Efectos, ambiente por evento y música (ids vacíos = silencio) |
| `ShopConfig`, `DefenseConfig`, `QuestConfig`, `DailyRewardConfig`, `ZoneConfig`, `MonetizationConfig` | Tienda, defensas, misiones, recompensa diaria, zonas, pases y productos |

### Services (servidor)
`DataService` (session locking + `UpdateAsync`), `EconomyService`,
`GardenService` (jardines, vallas, carteles), `InventoryService`,
`PlantService` (crecimiento, mutaciones, flores colocadas),
`ShopService` + `StockService`, `StealService`, `SlapService`,
`DefenseService`, `QuestService`, `DailyRewardService`, `EventService`,
`LeaderboardService`, `MonetizationService` (`ProcessReceipt` idempotente),
`OfflineEarningsService`, `RebirthService`, `PetService`, `ZoneService`,
`MapBuilder` (mapa y atmósfera por código) y `RemoteHandlers`.

### Controladores (cliente)
`HUDController`, `ShopController`, `InventoryController`, `GardenController`,
`QuestController`, `LeaderboardController`, `StoreController`,
`PlantController`, `SlapController`, `StealController`, `PromptController`,
`ProgressController`, `IndexController` (Plant Index), `AudioController`,
`EffectsController` (animaciones, clima de eventos) y `SkyController`
(sol cuadrado, nubes voxel y luciérnagas).

## Datos y seguridad
- **Session locking**: cada perfil queda bloqueado por el servidor que lo
  usa. Un segundo servidor espera unos segundos y, si sigue bloqueado,
  expulsa al jugador con un mensaje. Un servidor que pierde el bloqueo deja
  de guardar. El bloqueo caduca a los 6 min si el servidor cae.
- Guardado con reintentos y backoff, autosave, `BindToClose` y guardado
  final que libera el bloqueo. Un perfil que no pudo cargarse es temporal y
  **nunca** sobrescribe datos reales.
- Perfiles antiguos (sin formato) se migran solos; se sanean Cash, nivel y
  rebirths imposibles al cargar.
- Compras: `ProcessReceipt` guarda antes de confirmar y es idempotente por
  `PurchaseId`.
- Red de seguridad del mapa: muros gruesos, seto perimetral, suelo invisible
  bajo el mapa y teletransporte automático si alguien queda fuera de límites.

## Jugabilidad

### Controles
- **Plantar**: equipa semillas y haz clic/toca la tierra de tu jardín.
- **Colocar una flor de la mochila**: elígela en la mochila y toca/clic en el
  suelo de tu jardín, o usa **📍 Colocar aquí** (delante de ti). **Cancelar**
  con el botón, **Esc/X**. Mando: **A** coloca delante de ti. Cupo base: 6,
  más 2 por Rebirth.
- **Cosechar**: **E** o botón táctil sobre una parcela madura.
- **Robar**: mantén **F** o el botón táctil en una planta madura ajena.
- **Mochila**: tecla **º** (Backquote) o botón. Mando: **Y**.
- **Palo (SLAP)**: botón, **G** o **R2**; empuja sin daño.
- Botones: Tienda · Mochila · Jardín · Tareas · Top · Pases · Palo · 📖 Índice
  · 🔊 Audio (3 estados).
- La interfaz es pixel-art con degradados suaves y animación al pulsar.
  Los controles de teclado/mando se definen con el Input Action System
  (`Workspace > Behavior > PlayerScriptsUseInputActionSystem = Enabled`).

### Mapa (12 jugadores)
Dos filas de 6 jardines frente a frente con una calle y plaza central
(fuente, puestos de semillas/herramientas/huevos, faroles, estanque, bosque).
Cada puerta lleva un **cartel "Jardín de <nombre>"** legible desde ambos
lados con el Rebirth del dueño. Los jardines son patios con parcelas,
incubadora (en el pasillo lateral), jardineras y suelo de tierra sobre el
césped.

**Vallas por Rebirth** (se actualizan al renacer): rústica → blanca → muro de
piedra → hierro forjado → cristal → real dorada (las dos últimas con luz y
destellos).

**Atardecer**: iluminación de puesta de sol con atmósfera, bloom y rayos; sol
cuadrado en capas y nubes voxel rosas (`SkyController`), colinas de fondo.

### Plantas, mutaciones y eventos
- Las plantas se dibujan con voxels (`PlantBlueprints` + `PlantModels`) por
  fases (brote → joven → madura) y escalan con el tamaño: Normal, **Big** y
  **Giant** (mucho más grandes).
- **Efectos apilables sin límite**: cada efecto (Wet, Frozen, Shiny, Gold,
  Rainbow, Diamond) se tira por separado; el valor es el producto de todos.
  El nombre muestra todo: `Giant Apple · Wet · Gold · 3.20 kg`.
- **Lluvia**: crecimiento x1.2 y el efecto **Wet** (solo posible con lluvia,
  se ve como gotas cayendo de la planta); lluvia visual y tinte frío en el
  cliente. **Gold Rush**: venta x1.5 con chispas doradas.
- **Mascotas**: huevos por rareza, bonus de Cash/crecimiento/suerte según la
  rareza de la mascota equipada. Al abrir un huevo: silueta → revelado del
  animal con su emoji y nombre.
- **Plant Index**: la primera vez que consigues una especie se anima y se
  registra en el índice (`IndexController`).

### Ciclo de colección y tienda
- Las semillas se consumen al plantar; el jardín crea parcelas adicionales
  cuando hacen falta. Cosechar da una flor individual persistente (rareza,
  peso, tamaño, efectos, valor e ingreso por minuto).
- Las flores se pueden conservar, vender, regalar (semillas y flores; sin
  trading) o colocar en el jardín. Solo las colocadas generan Cash.
- Offline: se calcula sobre las flores colocadas, máx. 3 h y $100,000.
- Stock compartido de 5 min (packs, gear y huevos) con límite por jugador y
  MemoryStore entre servidores. Gear: regadera, aspersor, tótem de mutación y
  de tamaño.
- Robo: hay que llevar la flor hasta tu base; el portador va más lento. Si
  te pillan vuelves a tu jardín con efecto cómico. Escudo al entrar y tras
  ser robado; domo de jardín (45 s, 180 s de recarga).
- Rebirth: reinicia progresión con bonificación persistente, más cupo de
  flores y valla nueva.

## Audio
`SoundConfig.lua` define clic, menú, plantar/colocar, huevos, eventos,
ambiente y música. Los ids por defecto son archivos internos de Roblox que
pueden no existir en tu versión; los **ambientes y la música están vacíos**.
Sube tus sonidos a Roblox y pega los ids. Al jugar, la consola avisa de los
ids que fallan (`[Audio] No carga el sonido ...`).

### Pases propuestos
x2 Cash (79 Robux), Lucky Mutation (199), Pulgar verde —crecimiento 25% más
rápido— (99) y Granjero incansable —hasta 6 h offline y 25% más de ingresos
offline— (149). Los IDs están en `0` hasta crearlos en Creator Hub.

### Antes de publicar
1. Crea Game Passes y Developer Products en Creator Hub y pega los IDs en
   `MonetizationConfig.lua`.
2. Activa *Game Settings → Security → Enable Studio Access to API Services*
   para probar DataStore, MemoryStore y el leaderboard en Studio.
3. Sube tus sonidos y música y pega los ids en `SoundConfig.lua`.
4. Ajusta la capacidad del place a 13 jugadores y 12 en Custom Social Slots
   (los scripts no pueden cambiarlo).

### Validación en Studio (histórico, v0.5)
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
- Probar todo en Studio y en móvil de gama baja (las vallas de piedra,
  hierro, cristal y oro añaden varios cientos de piezas por jardín).
- Sonidos y música propios; tutorial guiado con pasos bloqueantes; más
  defensas; prueba con mando físico.
- Nombres de las vallas/efectos y precios de pases/productos por afinar con
  datos reales. Sin trading (los regalos se limitan a semillas y flores).
