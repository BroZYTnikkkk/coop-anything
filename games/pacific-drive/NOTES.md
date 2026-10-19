# Pacific Drive — working notes

## Session 2026-10-19 — Phase 0 triage + Phase 1 research

### Observations (checked this session)
- Store: Steam, appid 1458140, buildid 21896301 (from appmanifest).
- Main exe: `<game dir>/PenDriverPro/Binaries/Win64/PenDriverPro-Win64-Shipping.exe`,
  SHA-256 `568bb63476c6de5fc2b1878572a655dd631dd25bb44fe304e3d96a51f6b98f7e`,
  timestamp in Manifest_NonUFSFiles_Win64.txt: 2026-02-12. No version resource in the exe.
- Internal project name: `PenDriverPro`. Paks: `pakchunk0..4-WindowsNoEditor.pak`, pak format version 11.
- `Engine/Binaries/ThirdParty/PhysX3` present. `steam_api64.dll` shipped.
- OS: Windows 11 x64.
- Repo: no Pacific Drive entry in DIRECTORY.md or games/; no issues/PRs matching "pacific".
- GitHub repo search "pacific drive": no co-op project. Related single-player mods:
  keton/pacific-drive-uevr (UEVR profile), itsloopyo/pacific-drive-headtracking (native hooks,
  has offsets for Steam and GDK builds), MrPerruche/PDCmdMod (UE4SS Lua). Several
  "Pacific-Drive-Cheats/Trainer" repos with "File Size: 156 MB" blurbs look like malware bait — not opened.
- NorthernForce/PacificDrive is unrelated (FRC robot Java code).
- Nexus: many UE4SS mods (UE4SS 3.0.1 stable / experimental used); none multiplayer.

### Derived
- Engine: Unreal Engine 4, most likely 4.26 or 4.27 (pak v11 + WindowsNoEditor + PhysX3). Exact version: unknown.
- UE4 has built-in replication / NetDriver, but a single-player game may have stripped or
  never set up replication on its Blueprints. Whether the shipping exe contains IpNetDriver /
  OnlineSubsystemSteam: unknown (check pending).

### Guesses
- Route: UE4SS (Lua + C++ mod) for hooking, SDK dump via UE4SS, then either (a) try UE4's own
  netcode (open listen server, replicate the car/player), or (b) own sync layer over Steam
  networking with puppet players.

### Unknowns
- Whether earlier co-op attempt exists: web search result text mentions a 2024 Steam forum
  modder whose work was "frozen indefinitely" (loot sync, stable player movement). The thread
  https://steamcommunity.com/app/1458140/discussions/0/4291439538013940878/ redirected to the
  forum index on fetch (deleted/hidden?). Author, code, builds: unknown.

### Sources
- https://steamcommunity.com/app/1458140/discussions/0/4291439538013940878/
- https://steamcommunity.com/app/1458140/discussions/0/682986927120449638/
- https://www.nexusmods.com/pacificdrive/mods/206
- https://github.com/keton/pacific-drive-uevr
- https://github.com/itsloopyo/pacific-drive-headtracking

## Session 2026-10-19 — Phase 2 workspace

### Observations
- Test copy: `<test dir>/client1` made with robocopy, 86/86 files, 25.03 GB, 0 failed.
  Copied exe SHA-256 matches the original. The original install is not modified.
- No existing Pacific Drive save folder was found under %LOCALAPPDATA%, %APPDATA%, Documents,
  Saved Games or Steam userdata before the first test launch.
- UE4SS used: `experimental-latest` dev build `zDEV-UE4SS_v3.0.1-1181-g83330635.zip`,
  SHA-256 `82378cd7f679d055026286f11347355ac67c712f21eb892060c902bb0184b907` (matches GitHub release digest,
  asset dated 2026-10-17). Also downloaded stable `v3.0.1` (no published digest; local SHA-256:
  UE4SS_v3.0.1.zip `4b47d4bceddd2f561a4e395bfa00924ccfc945af576a2d0c613e6537846c57ec`,
  zDEV-UE4SS_v3.0.1.zip `af777d2af33fce4d520de35a8665e417376bcc530fec647778012ce6cdf51b2b`).
- Installed as `dwmapi.dll` proxy + `ue4ss/` folder in `PenDriverPro/Binaries/Win64` of the test copy.
  `steam_appid.txt` (1458140) added so the copy does not restart through Steam into the original install.
- No `CustomGameConfigs/Pacific Drive` entry ships with UE4SS.
- UE4SS ships `SplitScreenMod` (sets GameMapsSettings.bUseSplitscreen and calls
  GameplayStatics.CreatePlayer). Idea to test: local split screen + Steam Remote Play Together
  as a quick "online" path before real netcode (see playbook/split-screen.md).
- Probe mod `PDCoopProbe` (Lua): after 45 s logs net driver classes, GameInstance, World,
  player/vehicle actors, then runs DumpAllObjects, GenerateSDK, GenerateUHTCompatibleHeaders,
  GenerateLuaTypes, DumpUSMAP.

## Session 2026-10-19 — Phase 3 first look (UE4SS dumps)

### Observations
- UE4SS log: `Found EngineVersion: 4.27`, shipping build; usmap named `PenDriverPro-4.27.2-0+++UE4+Release-4.27`.
  So the engine is **UE 4.27.2**.
- UE4SS experimental build 83330635 loads with no custom game config; Lua mods run.
- Main menu map: `/Game/Maps/RunProto/RB_MainMenu`. GameEngine `DrivingGameEngine`, GameInstance
  `DrivingGameInstance`, menu PC `BP_MainMenu_PlayerController_C`, menu GM `BP_MainMenuGamemode_C`.
- Class presence (StaticFindObject): `IpNetDriver` FOUND, `NetDriver` FOUND, `DemoNetDriver` FOUND,
  `OnlineEngineInterfaceImpl` FOUND; `SteamNetDriver` and `SteamSocketsNetDriver` missing.
  `/Script/Engine.GameMapsSettings` reported missing (it lives in `/Script/EngineSettings`, probe path was wrong).
- Native game modules in the UHT dump: PenDriverPro (593 headers), PenDriverInventory (165),
  PenDriverUtils (55), IWCarPhysics (29), PenDriverDataBlocks, PenDriverUI, EntityFramework,
  DuctTape, IWHaptics, IWPhotoMode, IWAnalytics. Plugins: SMSystem (Logic Driver state machines),
  AkAudio/Wwise, Houdini, MinimapPlugin, PrefabAsset, Sentry, GameAnalytics.
- No OnlineSubsystemSteam module in the dump.
- **Replication specifiers in game native code: zero** (`Replicated`, `ReplicatedUsing`, `NetMulticast`,
  `Server`, `Client` all 0 in PenDriverPro, PenDriverInventory, IWCarPhysics, EntityFramework,
  PenDriverUtils, DuctTape). Sanity check: the same dumper finds 255 `Replicated` + 47 `ReplicatedUsing`
  in Engine, so the dumper does emit them. Only SMSystem has some (plugin's generic support).
- Core classes: `ABaseCharacter : ACharacter`; `ABaseNewCar : ANewVehiclePawn` (IWCarPhysics, custom,
  not PhysXVehicles); `ABaseDrivingGameMode : AGameModeBase`; `ABasePlayerController : APlayerController`;
  managers `UBaseSaveGameManager`, `UBaseCarManager`, `UBaseCharacterManager`, `UBaseInventoryManager`
  derive from `UBaseManager`. Player animation uses ALS (Advanced Locomotion System) Blueprint assets.
- Save manager exposes SaveGame/LoadGame/SaveCheckpoint/LoadFromCheckpoint/MakeBookmark/QuitToMenu UFUNCTIONs.
- The first test launch created `%LOCALAPPDATA%/PenDriverPro/Saved` (Config, Logs; no SaveGames yet).
  This folder is shared with the original install.

### Derived
- UE's own netcode (IpNetDriver, listen server) is compiled in, so engine-level replication is
  available: ACharacter movement replicates via CharacterMovementComponent once the pawn replicates.
- The game logic itself (car physics, inventory, managers, saves) has no replication at all, so the
  car, loot, car parts, damage and run state need our own sync (host authority), either as replicated
  properties/RPCs added from a C++ UE4SS mod or as a separate transport. This matches the 2024 attempt
  stalling on "loot synchronization and stable player movement".

### Next experiments (planned, not run)
1. Second test instance (`client2`): hardlink paks from client1, real copy of Binaries; isolate
   `%LOCALAPPDATA%/PenDriverPro` per instance (test `-userdir=`; else hook SHGetKnownFolderPath).
2. Host: `open <map>?listen` from a Lua mod; client: `open 127.0.0.1`. Record whether the client
   loads, spawns a pawn, and whether players see each other move (Stage 2 "puppet" via engine replication).
3. Probe car: `NewVehiclePawn` properties, whether bReplicates / ReplicateMovement can be forced.
4. Quick alternative to evaluate: UE local split screen (`GameMapsSettings.bUseSplitscreen` +
   `GameplayStatics.CreatePlayer`, UE4SS SplitScreenMod) + Steam Remote Play Together.

## Session 2026-10-19 — Phase 3/Stage 2: engine listen server experiments

### Setup (observations)
- `client2`: 82 files hardlinked from `client1` (paks, Engine), `PenDriverPro/Binaries/Win64` copied
  (own UE4SS config, logs and mods). Disk cost of client2 is only the Binaries folder.
- Per-instance settings: `-NotInstalled` on the command line makes the shipping build write
  `Saved/` into `<instance>/PenDriverPro/Saved` instead of `%LOCALAPPDATA%/PenDriverPro/Saved`.
  Checked: the instance folder gets `Config/` and `Logs/`, and `%LOCALAPPDATA%/PenDriverPro` got no new
  writes during any `-NotInstalled` run. Where SaveGames go under `-NotInstalled`: unknown (no save made yet).
- Two instances of the Steam build run at the same time on one PC with Steam running (no mutex block seen).
- Pak index: pak v11, not encrypted, compression Zlib. `tools/paklist.py` / `tools/pakextract.py`
  (kept locally, small pure-Python) list and extract files. 70,547 files in pakchunk0.
- `DefaultEngine.ini`: no NetDriverDefinitions override (engine default IpNetDriver),
  `GameDefaultMap=/Game/Maps/RunProto/RB_MainMenu`, `GlobalDefaultGameMode=/Game/Systems/GameModes/BP_DrivingGameMode`,
  `GameInstanceClass=/Script/PenDriverPro.DrivingGameInstance`, `bUseSplitscreen=False`,
  `TwoPlayerSplitscreenLayout=Vertical`. Hub map: `/Game/Maps/RunProto/RB_Garage`.
- Test mod `PDCoopNet` (Lua, UE4SS): role file per instance; host runs `open <map>?listen` at +40 s,
  client runs `open 127.0.0.1:7777` at +90 s; both log a `PDNET|` status line every 5 s; host teleports
  its own pawn ±150 uu every 5 s so the client can check movement replication.

### Experiment 1: main menu map (`RB_MainMenu?listen`) — ran, PASS
- Host: `standalone=false`, IpNetDriver created, listening on 7777.
- Client log: `Welcomed by server (Level: /Game/Maps/RunProto/RB_MainMenu, Game: .../BP_MainMenuGamemode_C)`;
  host log: `Join succeeded`.
- Host: 2 PlayerControllers, a second `DefaultPawn` owned by the remote PC.
- Client: own DefaultPawn is AutonomousProxy (role 2); host DefaultPawn is SimulatedProxy (role 1) and its
  X position alternates 0 / -150 in step with the host nudges, so movement replication works.
- `LogNetVersion: PenDriverPro 1.15.0 ... EngineNetVer: 17, GameNetVer: 0` on both sides.

### Experiment 2: hub map (`RB_Garage?listen`) — ran, PARTIAL
- Host loads RB_Garage as listen server with no save loaded; spawns `PDP_MainCharacter_C` (player) and
  `BP_PlayerCarNew_C` (car). Client joins (`Join succeeded`) and loads RB_Garage.
- Host character replicates to the client: `PDP_MainCharacter_C` role 1 on the client, X alternates
  3046 / 3196 with the host nudges.
- The car replicates as an actor (client sees `BP_PlayerCarNew_C` role 1 at the host's position), **but the
  client also has its own local car** (`BP_PlayerCarNew_C` role 3, ~2 uu away): level/Blueprint spawn logic runs
  on the client too, so there are two cars on the client.
- **The joining player gets no character**: host has 2 PCs but only its own `PDP_MainCharacter_C`; the client
  only has a local `SpectatorPawn`. The game mode spawns the character for the first player only.
- Host log error on join: `LogPlayerController: Error: EnableInput can only be specified on a PlayerController for itself`.
- Client log: many content errors, e.g. missing DLC package `/PDFeature_Fig/.../BP_Fig_Mission_Chapter08`
  requested by `AEntitlementSpawner`, DataTable `Missing RowStruct` on RoadSplineActors (also on host).

### Derived
- Engine replication is a working base: connection, travel, Character movement and actor replication
  all work without native patches. Co-op can be built "the UE way" from a UE4SS mod.
- Work items, in order: (1) spawn and possess a `PDP_MainCharacter_C` for each joining PC on the host
  (hook game mode PostLogin / HandleStartingNewPlayer); (2) stop client-side duplicate spawns (car, world
  actors) — run spawner logic on authority only, or destroy non-replicated duplicates on clients;
  (3) car: physics is IWCarPhysics (custom, no replication) → host-authoritative car with replicated
  transform/velocity, client as passenger first; (4) inventory, loot, car parts, damage via RPCs/replicated
  state; (5) saves on host only; (6) Steam transport for internet play (no SteamNetDriver in the build;
  options: IpNetDriver + port forward/VPN first, a Steam sockets driver later).

### Unknowns
- Whether `PDP_MainCharacter_C` controls (interaction, inventory UI) work for a non-first player.
- Whether running a real save/run (not a raw `open`) keeps the listen server alive across level travel
  (runs load new maps; needs seamless/server travel with clients following).
