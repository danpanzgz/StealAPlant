# Steal a Plant — Estructura del proyecto (v1.2)

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
| `PlantConfig` / `PlantInstanceConfig` | Catálogo de **57 especies** (9 Common, 10 Uncommon, 10 Rare, 9 Epic, 7 Legendary, 6 Mythic, 6 Celestial);  tamaños (Normal/Big/Giant), peso, nombre mostrado y cupo de flores colocadas |
| `MutationConfig` | Efectos: Wet, Frozen, Shiny, Gold, Rainbow, Diamond (probabilidad y multiplicador) |
| `RarityConfig` | 7 rarezas, Common → Celestial |
| `PetConfig` | 35 mascotas (5 por rareza), bonus por rareza y animal de cada una |
| `GardenConfig` | Niveles, layout de 12 jardines y **6 estilos de valla por Rebirth** |
| `EventConfig` | RainShower (crecimiento x1.2 + Wet) y GoldRush (venta x1.5) |
| `SoundConfig` | Efectos, ambiente por evento y música (ids vacíos = silencio) |
| `SeasonConfig` | Pase de Temporada: 30 niveles, XP por acción, premios free/premium, ciclo de 30 días |
| `RebirthConfig` (sacrificios, suerte, cobro, palos), `ShopConfig`, `DefenseConfig`, `QuestConfig`, `DailyRewardConfig`, `MonetizationConfig` | Tienda, defensas, misiones, recompensa diaria, zonas, pases y productos |

### Services (servidor)
`DataService` (session locking + `UpdateAsync`), `EconomyService`,
`GardenService` (jardines, vallas, carteles), `InventoryService`,
`PlantService` (crecimiento, mutaciones, flores colocadas),
`ShopService` + `StockService`, `StealService`, `SlapService`,
`DefenseService`, `QuestService`, `DailyRewardService`, `EventService`,
`LeaderboardService`, `SeasonService` (XP, niveles y premios), `MonetizationService` (`ProcessReceipt` idempotente),
`OfflineEarningsService`, `RebirthService`, `PetService`, `LeaderboardDisplay` (estatuas + tablón),
`MapBuilder` (mapa y atmósfera por código) y `RemoteHandlers`.

### Controladores (cliente)
`HUDController`, `ShopController`, `InventoryController`, `GardenController`,
`QuestController`, `SeasonController`, `LeaderboardController`, `StoreController`,
`PlantController`, `HotbarController` (barra rápida), `RebirthController`, `SettingsController`,
`SellController`, `SlapController` (empujón), `PromptController`, `IndexController` (Plant Index), `AudioController`,
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
- **Barra rápida** (6 casillas, teclas **1-6**): palo, semillas, flores y herramientas.
  Se rellena desde 🎒 Mochila: **mantén y arrastra** un cuadradito a una casilla
  (o pulsa 📌 Barra). Se guarda en tu perfil.
- **Plantar**: equipa una semilla (casilla o "En mano") y toca el suelo marrón
  de tu jardín. La semilla sigue en la mano mientras te queden.
- **Colocar una flor**: casilla con la flor o **Colocar** en la mochila.
- **Cosechar**: **E** o botón táctil. **Robar**: mantén **F** en una planta ajena.
- **Palo**: equípalo en la casilla 1 y toca/clic para empujar (sin daño).
- **Menú ☰** agrupa Mochila, Jardín, Índice, Tareas, Temporada, Top, Tienda Robux
  y Ajustes (música, efectos, gráficos). Fuera del menú solo **Menú** y **Renacer**.
- **Domo antirrobo**: pisa la placa azul del patio, junto a la puerta.
- Los errores salen en rojo y claros ("No tienes suficiente dinero").

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

### Pase de Temporada
Temporadas de 30 días calculadas con `os.time()` (sin mantenimiento): al
cambiar, el XP y los premios reclamados se reinician. 30 niveles con **pista
gratis** y **pista premium** (Game Pass `SeasonPass`, 449 R$). El XP sale de
jugar (plantar 4, cosechar 12, robar 50, defender 40, misión 60, recompensa
diaria 40, abrir huevo 30). Se puede comprar +1 / +5 niveles (Developer
Products `SeasonSkip` / `SeasonSkip5`). Los premios premium ya ganados se
pueden reclamar al comprar el pase más tarde. Servidor autoritativo: el
cliente solo pide `ClaimSeasonReward(nivel, pista)`.

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
- Rebirth (botón ♻️): cuesta dinero **y sacrificar una planta concreta** (la ve el panel).
  Cobras **x2, x3, x4...**, la **suerte** (`Luck`) se duplica, ganas +2 huecos de
  plantar y el palo sube de nivel. Máximo 20 huecos; el jardín empieza con 6 y los
  huecos son parcelas invisibles dentro del patio.

## Cambios v1.2 (rediseño)
- Jardín con **una sola puerta**; el patio ya no crece hacia la calle.
- Sin zonas (eliminadas `ZoneConfig`/`ZoneService`) ni pase de huecos extra.
- **Índice** en cuadrícula: estadísticas (dinero total, plantas plantadas, suerte,
  renacimientos) y, al descubrir una planta, ficha con peso mín./máx.
- **Mochila** en cuadrícula con pestañas, detalle abajo, arrastrar a la barra y
  apertura instantánea (usa la caché del cliente). La venta ya no está en la mochila.
- **Tiendas** físicas con cartel de madera, cada una solo con lo que vende;
  **puesto de venta** (mano, comunes, repetidas, todo). El botón del HUD es solo Robux.
- **Plaza**: 3 estatuas de los más ricos y tablón de madera Top 50 (`LeaderboardDisplay`;
  clave de OrderedDataStore nueva `..._LifetimeCash_v2`).
- Temporada con scroll horizontal; cielo sin popping de nubes y sol siempre cuadrado.

## Audio
`SoundConfig.lua` define clic, menú, plantar/colocar, huevos, eventos,
ambiente y música. Los ids por defecto son archivos internos de Roblox que
pueden no existir en tu versión; los **ambientes y la música están vacíos**.
Sube tus sonidos a Roblox y pega los ids. **Música sin ids verificados** (no pude comprobar ids de terceros: busca en Creator Store > Audio, gratis, y pruébalos en Studio). Al jugar, la consola avisa de los
ids que fallan (`[Audio] No carga el sonido ...`).

### Monetización (Robux)
Inspirada en lo que funciona en Grow a Garden / Steal a Brainrot: ofertas de
bienvenida de una sola compra, boosts baratos y repetibles, paquetes de
semillas/huevos y pases de comodidad. Nada bloquea el juego gratuito. Todo se
concede en servidor (`MonetizationService`, `ProcessReceipt` idempotente) y
los precios son puntos de partida a ajustar con datos reales. Los IDs están en
`0` hasta crearlos en Creator Hub y pegarlos en `MonetizationConfig.lua`.

| Tipo | Contenido |
|---|---|
| **Ofertas (1 vez)** | 🎁 Starter Pack 149 R$ (25k Cash, 3 packs Rare, 1 Epic, huevo Rare, 5 regaderas, 30 min x2 Cash) · 👑 Pro Pack 399 R$ |
| **Boosts** | x2 Cash / Crecimiento 19 R$ · x2 Suerte 49 R$ (10 min, se acumulan) · 🚀 Super Boost 30 min 99 R$ |
| **Utilidades** | ⏩ Crecimiento instantáneo 29 R$ · 🛡️ Escudo 30 min 39 R$ |
| **Paquetes** | Pack Epic x3 79 R$ · Huevos Rare x3 59 R$ · Pack Legendary x2 199 R$ |
| **Cash** | 19 / 49 / 149 / 399 R$ (10k / 60k / 250k / 1M) |
| **Temporada** | 🏆 Pase 449 R$ (pista premium) · +1 nivel 39 R$ · +5 niveles 149 R$ |
| **Pases** | x2 Cash 79 · VIP 299 (+15% Cash, pack Rare diario) · +3 huecos de flores 149 · Pulgar verde 99 · Granjero incansable 149 · Lucky Mutation 199 · Velocidad extra 149 · Maestro del escudo 249 |

Los boosts se guardan como hora de fin en el perfil; la tienda muestra los
activos y un aviso recomienda la oferta de bienvenida tras 2,5 min de juego.

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
- **Nada de v1.2 se ha probado en Studio**: probar mochila/arrastre, barra, renacer,
  placa del domo, estatuas (avatar vía `CreateHumanoidModelFromUserIdAsync`), tablón,
  tiendas y venta; ajustar posiciones del mapa si algo se solapa.
- Música ambiente (ids) y sonidos propios (alarma/robo usan sonidos internos provisionales).
- IDs de Game Passes y Developer Products siguen en 0.
- Estadísticas guardadas de jugadores antiguos: `lifetimeCash` parte de su total ganado.
- Controles de mando para la barra rápida y la mochila (solo táctil/ratón/teclado).
- Rendimiento en móvil de gama baja (vallas de piedra/cristal/oro); tutorial guiado;
  más defensas; precios por afinar. Sin trading.
