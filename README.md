# Steal a Plant — Estructura del proyecto (v0.1)

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
│   │       │   ├── GameConfig.lua      # Ajustes globales (ticks, cooldowns, autosave...)
│   │       │   ├── RarityConfig.lua    # 5 rarezas: Common → Legendary
│   │       │   ├── MutationConfig.lua  # 5 mutaciones: Wet, Frozen, Shiny, Golden, Rainbow
│   │       │   ├── ZoneConfig.lua      # 3 zonas con requisito de desbloqueo
│   │       │   ├── PlantConfig.lua     # 20 plantas (catálogo completo)
│   │       │   └── GardenConfig.lua    # 3 niveles de jardín (plots, defensas, precio)
│   │       └── Modules/
│   │           ├── Signal.lua          # Pub/sub interno entre Services
│   │           └── Net.lua             # Wrapper único de Remotes
│   ├── ServerScriptService/
│   │   └── Server/
│   │       ├── Remotes/
│   │       │   └── RemoteBootstrap.lua # Crea todos los remotos al iniciar
│   │       └── Services/
│   │           ├── DataService.lua     # DataStore + autosave + retries + BindToClose
│   │           └── EconomyService.lua  # Única puerta para modificar Cash
│   └── StarterPlayer/
│       └── StarterPlayerScripts/
│           └── Client/                 # (siguiente iteración)
```

## Estado actual (esta entrega)

✅ Estructura de proyecto Rojo
✅ Módulos de configuración: `GameConfig`, `RarityConfig` (5), `MutationConfig` (5),
   `ZoneConfig` (3), `PlantConfig` (20 plantas), `GardenConfig` (3 niveles)
✅ `Net.lua` + `RemoteBootstrap` — sistema de comunicación cliente/servidor
✅ `DataService` — persistencia con reintentos, autosave y protección ante shutdown
✅ `EconomyService` — Cash validado 100% en servidor

## Próximos pasos (siguiente iteración, en orden de prioridad — Core Loop primero)

1. `GardenService` — asignar un jardín físico por jugador en Workspace,
   generar plots según `GardenConfig`.
2. `PlantService` — plantar semilla, crecimiento por fases (server-side
   con timestamps, nunca confiar en el cliente), cosecha e ingreso pasivo.
3. `ShopService` — Seed Shop server-validado (`BuySeed` RemoteFunction).
4. `Main.server.lua` — bootstrap que arranca todos los Services en orden.
5. Cliente: `Main.client.lua` + `UIController` mobile-first (HUD de Cash,
   botón de plantar, Seed Shop) para que el jugador reciba su primera
   planta y su primera recompensa en los primeros minutos.
6. `StealService` + `DefenseService` — robo no gráfico (temporizador de
   robo, alarma, teletransporte corto si te atrapan, defensas que bajan
   la probabilidad de éxito).
7. Sistemas de retención: `QuestService`, `DailyRewardService`,
   `EventService` (2 eventos temporales), `LeaderboardService`.
8. `MonetizationService` — Game Passes (ventajas permanentes) y
   Developer Products (`ProcessReceipt` idempotente) para compras
   repetibles.

Cada punto se implementará como módulo independiente, sin tocar los
anteriores, siguiendo el mismo patrón: lógica en `Services/`, balance en
`Config/`, comunicación por `Net.lua`.
