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

## Session 2026-10-19 — Stage 2: second player character + client car duplicate (PDCoopNet v2)

### What the mod does now (host = listen server on RB_Garage, client = joins 127.0.0.1)
- Host: every 5 s, for each remote PlayerController without a `PDP_MainCharacter_C`, spawns one with
  `GameplayStatics.BeginDeferredActorSpawnFromClass` + `FinishSpawningActor` (class taken from the host's
  own character, 250 uu beside it) and calls `Controller.Possess`.
- Host: after the spawn, `BP_MainCharacterManager_C.CharacterActor` has switched to the new character
  (single-player manager keeps one reference); the mod sets it back to the host's character.
- Client: finds `BP_PlayerCarNew_C` actors with Role = Authority (the client's own local car) while a
  SimulatedProxy copy from the host exists, calls `K2_DestroyActor` on the local one and points
  `BP_CarManager_C.NewCarActor` at the replicated car.
- Client: walks forward with `AddMovementInput` in 3 s bursts (client -> host movement check).

### Observations
- `BP_DrivingGameMode_C`: `DefaultPawnClass=PDP_MainCharacter_C`, `bStartPlayersAsSpectators=true`
  (this is why joining players stayed spectators: the game spawns the character for player 1 itself).
- Spawn + Possess works: client gets `PDP_MainCharacter_C` as AutonomousProxy (role 2); host sees it as a
  remote character; client input moves it and the host's copy follows (server-authoritative
  CharacterMovement with client prediction, stock UE).
- Client `BP_MainCharacterManager_C.CharacterActor` points at the client's own character without the mod
  doing it (the mod's bind step found it already set).
- `K2_DestroyActor` on the client's local car works: the actor is PendingKill with 0 live components right
  after the call. It stays visible to `FindAllOf` (and `IsValid()` in UE4SS Lua stays true) until garbage
  collection, which did not happen within ~2 min; early runs misread this zombie (location 0,0,0) as
  "destroy failed". Lesson: in UE4SS Lua treat `HasAnyInternalFlags(EInternalObjectFlags.PendingKill)` as gone.
- Survey on the client after joining: the player car was the only actor class with
  `bReplicates && Role == Authority` (i.e. the only locally spawned duplicate of a replicated actor).
  Non-replicated local actors (loot, props spawned by client-side logic) are not covered by this survey.
- Remaining host log error on join: `LogPlayerController: Error: EnableInput can only be specified on a
  PlayerController for itself` (also on the client side once).
- Test UE4SS Lua binding note: `K2_GetComponentsByClass` result is neither a Lua table of objects usable with
  `ipairs` nor a TArray with `:ForEach` in this build (exp5 error `attempt to call a nil value (method 'ForEach')`,
  exp6 found 0 components on a destroyed actor) — container type still to be confirmed on a live actor.

### Automated test (tools/run_test.ps1) — ran 2026-10-19, run "exp7-final", 200 s
```
PASS  client connected to host (serverConn=yes)
PASS  host has 2 PlayerControllers
PASS  client possesses own PDP_MainCharacter (local, role=2)
PASS  client sees host character (role=1)
PASS  host sees remote PDP_MainCharacter
PASS  client has exactly one player car
PASS  client car is the replicated one (role=1)
PASS  client walking moves its character on the host (>=3 distinct positions)
PASS  host movement visible on client (>=2 distinct positions)
SUMMARY: 9/9 checks passed
```
Earlier runs: exp3 (spawn OK, dedupe misread), exp4/exp5/exp6 (dedupe diagnostics), each with the character
checks passing.

### Not tested yet
- Anything a human sees: camera, HUD, animation of the remote character, interaction/inventory for player 2.
- Entering/driving the car with two players, car physics on the client, leaving the garage for a run
  (level travel), saves, internet play.

## Session 2026-10-19 — Stage 3: host drives, client rides as passenger (PDCoopNet v3)

### How it works now
- Client -> host command channel without new RPCs: the client calls the stock reliable Server RPC
  `PlayerController.ServerChangeName("PDCOOP:SEAT")`; the host reads remote `PlayerState` names every 5 s,
  acts on the `PDCOOP:` prefix and then renames the player ("Passenger").
- Host on `SEAT`: `CharacterMovement:DisableMovement()`, collision off, teleport the remote character to
  `TempSocket_Seat` + 70 uu to the car's right, `K2_AttachToActor(car, None, KeepWorld x3)`. Attachment replicates.
- Host bot drive: `PDP_MainCharacter_C.CommandEnterCar(true, nil, false)` (called as a UFunction object: the
  managers only have a *delegate* of that name, `cm:CommandEnterCar()` hits the delegate and fails with
  `attempt to call a MulticastDelegateProperty value`), then fallbacks (driver door highlight event,
  `PlayerController:Possess(car)` + `BP_CarManager_C."Register Car Possessed"(true)`),
  `ManualSetIgnition_NoAnim(2)`, `ManualActivate_Gearbox(...)`, `VehicleController:SetParkingBrakeActive(false)`,
  then every frame `AccelerateBrake(dir)`, `DriveControl(dir)`, `VehicleController.ThrottleInput = dir`
  (forward 4 s / back 4 s). `car:SetReplicateMovement(true)` on the host.
- Client when attached: own CharacterMovement disabled and its tick off, collision off, re-seated at the same
  seat point and re-attached locally; the replicated car's `Chassis` made kinematic and its
  `VehicleController` tick off; every frame the client sets the car transform from `car.ReplicatedMovement`
  (Location/Rotation). The host is the only physics simulation of the car.
- All mod loops run on the game thread (`LoopInGameThreadWithDelay`, `ExecuteInGameThreadWithDelay`).

### Observations
- exp8: with the client still simulating the replicated car's physics, the car on the client jittered
  (Z 95..280 while the host car was flat) and the passenger-to-car distance on the client ranged 36..699 uu,
  while on the host it was a constant 36 uu.
- exp9: client crash `EXCEPTION_ACCESS_VIOLATION reading address 0x000000000000000d`, call stack entirely inside
  `UE4SS.dll`, a few seconds after the client got its character, before any car code ran on the client.
  The client code on that path was the same as in the passing exp8. Suspected cause: `LoopAsync(16)` loops
  (run on a UE4SS worker thread) touching the Lua state / UObjects while the game thread also ran mod code.
  After moving every loop to the game thread: no crash in exp10 and exp11. Not proven, one run each.
- exp10: making the client's replicated car kinematic stopped it moving on the client (physics replication
  only drives simulating bodies). Following `ReplicatedMovement` by hand fixed it (exp11).
- Gearbox: with `ManualActivate_Gearbox(1)` and throttle the car did not move in 10 s; after
  `ManualActivate_Gearbox(0)` it drove (moved 2335 uu within the next 5 s). The garage start state was 0.
  Derived: `CarGearBoxState` 0 = drive, 1 = park (enum names in the dump are only NewEnumerator0/1).
- `CommandEnterCar` on the character returned without error, but 2.5 s later the host did not possess the car;
  possession came from the `Possess` fallback at 5 s. Whether the real enter sequence (timeline,
  dip to black) just needs longer: unknown.

### Automated test — run "exp11-car4", 300 s, 2026-10-19
```
PASS  client connected to host (serverConn=yes)
PASS  host has 2 PlayerControllers
PASS  client possesses own PDP_MainCharacter (local, role=2)
PASS  client sees host character (role=1)
PASS  host sees remote PDP_MainCharacter
PASS  client has exactly one player car
PASS  client car is the replicated one (role=1)
PASS  client walking moves its character on the host (>=3 distinct positions)
PASS  host movement visible on client (>=2 distinct positions)
PASS  client SEAT command reached host and seated the passenger
PASS  host is driving the car (host possesses car)
PASS  car moved on host > 500 uu (max 3510, mode=throttle)
PASS  host sees remote character attached to the car
PASS  client character attached to the car on the client
PASS  client sees the car move while riding (>=3 distinct car positions, got 24)
PASS  passenger stays with the car on the client (max char-to-car 67 uu < 400)
SUMMARY: 16/16 checks passed
```
History: exp8 14/16 (no host entry, client jitter), exp9 7/16 (client crash in UE4SS.dll), exp10 15/16
(kinematic car frozen on client), exp11 16/16.

### Not verified
- Visuals: passenger pose (no sitting animation is triggered), cameras, how smooth the car looks on the client
  (transform is set per frame from replicated movement, no interpolation), car sounds on the client.
- Real player input for driving (the bot calls the input handlers directly), the proper enter-car sequence,
  getting out of the car (passenger detach is not implemented), more than one passenger.
- Level travel out of the garage, saves, internet play.

## Session 2026-10-19 — Stage 4: map changes (ServerTravel, the game's own travel, re-host, rejoin)

### Tooling
- universal-modder skills installed for the owner (12 skills) and its `um` CLI 0.2.0, pinned to commit
  `6a8865ae171b406f50892c7f46fc5f45655269eb` (`uv tool install git+...@<sha>`), code read before install.
  `um scan <test dir>/client1`: Unreal Engine `UE4+Release-4.27`, no anti-cheat found, loader UE4SS. Matches triage.
  `um kb search "pacific drive"`: no note yet.

### Observations
- How the game changes maps: native C++ in `UBaseLevelManager` (delegates `OnPreTravel`/`OnPostTravel` with a
  `UMapLocation`), route logic in `UBaseRouteState::TravelTo(UBaseLegState*, ERouteEndReason) -> FString`
  (BlueprintCallable + BlueprintNativeEvent, so UE4SS `RegisterHook` sees every call). The actual map load does
  not go through hookable UFunctions: during the game's `QuitToMenu` none of the hooks on `GameplayStatics:OpenLevel`,
  `DrivingGameInstance:PreLoadMap/PostLoadMapWithWorld` or `PlayerController:ClientTravel` fired on the host;
  the host log shows `Browse: /Game/Maps/RunProto/RB_MainMenu` with no `?listen`. Result: the game's own travel
  shuts the listen server down (`World NetDriver shutdown`) and clients get `Host closed the connection`.
- Host `servertravel /Game/Maps/Wilderness/Forest/Wilderness_Forest_01` from RB_Garage: the client receives
  `ClientTravelInternal("/Game/Maps/Wilderness/Forest/Wilderness_Forest_01?listen", TRAVEL_Relative, false)`.
  exp12: client `ConnectionTimeout` after 20 s while the host loaded the zone (19.2 s, started 4 s late).
  exp13: client followed, got its own character there, 14/14 checks (host load 14.5 s that time, so whether the
  timeout change mattered is unknown).
- Setting `InitialConnectTimeout`/`ConnectionTimeout` on the IpNetDriver/NetDriver CDOs and on the live pending
  driver right after `open` does not change the pending-connect threshold: still `Threshold: 20` (exp15, exp16).
  Cause unknown. Retrying the `open` every 30 s works instead.
- Host crash, exp14: game's `QuitToMenu` from RB_Garage with a second `PDP_MainCharacter_C` present →
  `EXCEPTION_ACCESS_VIOLATION reading address 0x20` in game code right after `World NetDriver shutdown` during
  `BeginTearingDown for /Game/Maps/RunProto/RB_Garage`. With a pre-hook on `BaseSaveGameManager:QuitToMenu`
  that unpossesses and destroys remote players' characters first: no crash (exp15, exp16).
- `BaseSaveGameManager.UserNewGame(5, STORY)` (on `BP_SaveGameManager_C`) travels natively to
  `/Game/Maps/Narrative/Narrative_Forest_OlympicOpening_Sentry_01/...`. Saves go to the instance's own `Saved/`
  under `-NotInstalled`; the exe has no Steam Remote Storage calls (no `SteamRemoteStorage` strings).

### What the mod does now
- Host "re-host": if the host lands standalone in a gameplay map after having had clients, it runs
  `servertravel <same map>?listen` (one extra load).
- Pre-hooks on `QuitToMenu` and `BaseRouteState:TravelTo` remove remote players' characters before native travel.
- Client "rejoin": after dropping from a gameplay map to the menu it retries `open <host>` every 30 s until it is
  in a gameplay map again.
- Spawn rule (owner's requirement): a joining or re-joining player is always spawned next to what the host
  controls now (250 uu beside the host character, 320 uu beside the car), never at a saved position, a
  player start or the garage. If the host is driving, the new player is seated as a passenger right away
  (not tested yet).
- Per-map state of the mod resets on every map change.

### Automated test — run "exp16-gametravel3", 480 s
```
PASS  client connected to host (serverConn=yes)
PASS  host has 2 PlayerControllers
PASS  client possesses own PDP_MainCharacter (local, role=2)
PASS  client sees host character (role=1)
PASS  host sees remote PDP_MainCharacter
PASS  client has exactly one player car
PASS  client car is the replicated one (role=1)
PASS  game's own UserNewGame travelled the host to a gameplay map (Narrative_Forest_OlympicOpening_Sentry_01)
PASS  host re-hosted that map with ?listen
PASS  client rejoined the host in the new map
PASS  client has its own character there (local, role=2)
PASS  re-joined player spawned next to the host (first distance 250 uu < 800)
```
The two walking checks failed in that run because this scenario leaves the garage after ~20 s; they are marked
SKIP for `gametravel` in tools/run_test.ps1 from now on. Client rejoined after 2 tries.

### Not tested
- A real run travel (garage gateway → zone → zone → garage) triggered by gameplay; `TravelTo` hook has not fired yet.
- Seating a re-joined player directly into the car when the host is driving.
- Cost of the re-host double load on long zone maps; whether reloading a run map breaks run state.
- Anything visual.

### Car regression after the travel changes
- exp17 (14/16): the passenger rode along on the client at a constant 16506 uu from the car. The client's local
  re-seat (detach, teleport to seat socket, re-attach KeepWorld) read the car at (-15233,-9001,9669) in the frame
  where its chassis was switched to kinematic, so the attach offset was wrong. Removed the local re-seat; the
  client keeps the server's replicated attachment and only disables its movement and the car's physics.
- exp18 "car", 300 s: **16/16 PASS**, passenger-to-car distance on the client 83 then a constant 67 uu,
  car driven by throttle (max 3241 uu from start).

### Rejoin while the host is driving (owner requirement: a re-joining player appears next to the host)
- Scenario `rejoincar`: the client rides as passenger, disconnects itself (`disconnect`) after 40 s of riding,
  rejoins via the retry loop; the host spawns the new character 320 uu beside the car it is driving and seats
  it straight away.
- exp19 (19/21): one client sample at the seat moment had the kinematic car at a bogus position (Z 2845);
  fixed by putting the car on `ReplicatedMovement` in the same frame as the kinematic switch. The car later
  stopped on the host; exp20 diagnostics (`chassisSim=true awake=false`, stuck at the garage's far wall)
  show this is the test bot pushing the car into a wall until its body sleeps, not a co-op issue.
  The dropped passenger's character leaves the car's attached actors on logout.
- exp20 "rejoincar", 420 s: **21/21 PASS**:
```
PASS  client dropped out on purpose while riding
PASS  client rejoined the host in RB_Garage
PASS  host seated the re-joined player straight into the driven car
PASS  after rejoin the client rides in the car (39 samples, 17 car positions)
PASS  after rejoin the passenger stays with the car (max 69 uu < 400)
(+ the 16 car checks, all PASS; max passenger-to-car distance before the drop 70 uu)
```
- Host log: `SPAWNED ... at -3367,-1580,207 next to BP_PlayerCarNew_C (-3210,-1858,147)` then
  `SPAWN host is driving: seating ... as passenger`.

## Session 2026-10-19 — Stage 5: playable build, own repo

- Mod repository (MIT, no game files): https://github.com/BroZYTnikkkk/pacific-drive-coop (v0.1, commit e645cbf).
  `um publish check` against the clean Steam install: `PASS: 9 files, 0 failures, 0 warnings`
  (against the test copy it flagged the mod itself as a "game file", because the test copy has the mod installed).
- New `play` scenario (default): no test bots. Keys: host F8 = host the current map; client F8 = connect,
  F6 = sit in the car, F7 = get out. **The key bindings were not pressed in any test**; the tests run the same
  actions from bots. exp23 smoke run in `play`: both instances load the mod, no bot actions, no Lua errors.
- Get out of the car: client sends `UNSEAT`; host detaches the character next to the car and sets walking.
- Command channel fix: `PlayerState:SetPlayerName` did not clear the command name (exp21: every command ran again
  every 5 s); the host now acts once per distinct `PDCOOP:<cmd>:<seq>` string per controller.
- Client applies the server's `AttachmentReplication` offset in the frame the ride starts (exp21 had one sample
  with the passenger at a bogus position at attach time).
- exp22 "rejoincar", 480 s: **24/24 PASS** (car 16 + rejoin 5 + get out 3: host detached the passenger on UNSEAT,
  client left the car and walks again, its character moves on the host in 5 positions).

### Correction (2026-10-19): exp13 also crashed the host
- Three `CrashReportClient` windows were still open on the owner's screen after the runs. Crash contexts:
  client2 08:52 `EXCEPTION_ACCESS_VIOLATION reading address 0x000000000000000d` (exp9, UE4SS worker-thread loops);
  client1 09:59 `... 0x0000000000000020` (exp14, QuitToMenu from RB_Garage); client1 09:56 `... 0x0000000000000020`,
  i.e. **exp13 crashed the host on QuitToMenu from Wilderness_Forest_01 as well**. Earlier text saying the zone
  QuitToMenu "worked" is wrong: the test harness did not look for crashes after the checks it had.
- Same address as exp14, so the cause is most likely the same (a second PDP_MainCharacter during world teardown);
  no crash reporter appeared in exp15/exp16 with the pre-travel cleanup.
- tools/run_test.ps1 now records crash folders created during the run, closes the test copies'
  CrashReportClient processes by PID (nothing is sent), keeps the dumps under results/<run>/ and fails a
  "no game crash" check.

### Owner report: "start of the game, two cars inside each other" (v0.2, mod repo commit d878523)
- The new-game intro uses another car class, `BP_PlayerCar_Intro_C` (both derive from `ABaseNewCar`); the
  client's duplicate filter only knew `BP_PlayerCarNew_C`. Survey in exp25: `CLIENT-LOCAL REPLICATED ACTORS: BP_PlayerCar_Intro_C=1`,
  client had role 3 at -59029,64602 and role 1 at -58942,64602. Fix: all car logic uses `FindAllOf("BaseNewCar")`
  (UE4SS FindAllOf includes subclasses) and `IsA(/Script/PenDriverPro.BaseNewCar)`; a local copy is removed only if
  the host replicates the same class. exp26: duplicate removed, 1 car on the client.
- Same map: the intro starts with the player seated; after possession the game put player 2 into the driver's
  seat on top of the host (host-side distance 0 uu, exp26), although the mod had seated it as passenger.
  The game takes the seat from `PDP_MainCharacter_C.GetCarAttachTransformForCharacter(out FTransform)` (used by
  `EnterCarTimeline`), and asks for it every frame while seated. A UE4SS post-hook on that Blueprint function that
  moves the out transform 70 uu to the car's right for player 2 works (`transformParam:set()` on the out param
  changes what the game uses). exp27: player 2 at 70 uu from the host, 15/15; a host-side keeper (re-seat when
  player 2 is within 40 uu of the host while the host is in a car) never fired there; in exp28 it fired once
  while the host was getting into the car.
- Also new: tools/run_test.ps1 fails a "no game crash" check (exp24 caught a client crash
  `Runnable thread RHIThread crashed`, `EXCEPTION_ACCESS_VIOLATION 0x000001daef0c67d0`, call stack in game code
  while loading the main menu after the host left; not seen in exp25-exp28; cause unknown).
- exp27 gametravel 15/15 (2 n/a); exp28 rejoincar 24/25 as printed; the one FAIL was the test's own pattern
  (log text changed to "SPAWN host is in <car>: seating"); the host log shows the event, so 25/25 with the fixed pattern.

## Session 2026-10-19 — Assets: what the game ships for a second player (mod v0.3, commit fd8a48c)

### Tooling
- `tools/assetdump` (C#, .NET 10 SDK, NuGet `UAssetAPI` 1.1.0 by atenfyr, repo commit 73530811): cooked
  .uasset+.uexp → JSON with the UE4SS `.usmap` (unversioned properties). `tools/assetinfo.py` summarizes the JSON
  (components, meshes, materials, transforms). Assets extracted with tools/pakextract.py. UAssetGUI v1.1.0 was not
  used: it needs the .NET Desktop Runtime 10 (only 6 installed) and its `tojson` mappings-path argument is v1.1.1+.

### Observations (from the dumps)
- `PDP_MainCharacter_C.CharacterMesh0`: `SkeletalMesh=Mannequin` (`/Game/AdvancedLocomotionV3/Characters/Mannequin`),
  `AnimClass=Mannequin_AnimBP_C`, `OverrideMaterials=[M_PlayerCharacter_Invist, M_PlayerCharacter_Invist]`,
  `CastShadow=False`. So the player body is the ALS mannequin made invisible; nobody ever sees a player body in
  single player. Cameras: `FP_Camera` (first person), `TP_Camera`, a `FirstPersonSkelMeshTransform` scene component.
- The Mannequin's own materials are not in the paks (only `Materials/Textures/uvsnap`).
- Skeletal meshes in all paks: 9; the only human ones are `SK_Firstperson` (5.6 KB uexp, an attach rig, no visible
  body) and the ALS `Mannequin`. Pak index has no seat/sit/enter-car animation names; entering the car is
  `EnterCarTimeline` transform curves.
- `BP_PlayerCarNew`: one seat `TempSocket_Seat` at (26.6, -45.8, -15.6); interaction only on the driver's door
  `UICollision_EnterDriverDoor` (57.8, -91.8, 30.6); `ExitPoint` (-15.2, -151.1, 0); `TempExitLocation`
  (-49.3, -168.2, 13.8). `SLOT_FrontLeft/FrontRight/RearLeft/RearRightDoor` and `SLOT_BackSeatLeft/Right` are
  car-part slots (doors and back-seat parts such as `BP_CarPart_FuelTank_Base_Backseat`, `BACKSEAT-RACK`), not seats.

### Derived
- The car is a four-door wagon modelled for one occupant. A front passenger seat can be the mirror of the
  driver's seat (Y +45.8); rear seats would need positions chosen by hand and can collide with back-seat parts.
- Making other players visible needs no new asset: give the mannequin any material from the paks.
  A real player model and a sitting pose would be new assets (skeletal mesh, animations), which need the editor.

### What the mod does now
- Every machine replaces the invisible material on *other* players' characters with
  `/Engine/EngineMaterials/DefaultMaterial` and turns their shadow on; your own body stays invisible.
- Passenger seat moved from +70 uu to the mirrored seat (+91.6 uu to the car's right of the driver's seat) in both
  the seat hook and the mod's own seating.
- tests: `HighResShot 1` screenshots, copied to results/<run>/shot-*.png.

### exp29 "rejoincar", 480 s: 25/25 PASS, no crash
- Host screenshot (host driving, camera turned to the passenger): a dark grey checkered figure in front of the
  centre console = player 2's mannequin, standing pose (no sitting animation), large in frame.
- Client screenshot (riding): the view looks into the car interior with brown blotches over the image, likely the
  camera inside glass/geometry with a dirt effect. Passenger camera placement is not handled yet.
- The "player 2 walking" screenshot did not trigger (timing condition), so a walking body was not seen yet.

## Session 2026-10-20 — Shared world items (mod v0.4, commit 41cb650)

### Observations
- Inventory model: items are `UItemInstance` data objects with "manifestations"; world items are
  `AItemWorldManifestation` actors (`BP_WorldItem_C` and subclasses), pooled (`APooledActor`; `IsPooled()` is true
  for live items too, it means "owned by a pool"), `bReplicates=false`. Inventory lives in the GameInstance
  (`UInventorySystem`), per process. Player containers: `BP_InventoryManager_C.Inventory_Player`, `Inventory_PlayerHand`
  (plus trunk, garage, gobbler, stations).
- Working primitives (exp34, host alone): `LoadAsset(<IA_ archetype>)`; `InventorySystem:SpawnItemActor(wco, xf, archetype, 0, 0)`
  spawns a `BP_WorldItem_C`; `Instance:Remove(true)` removes it; `BP_InventoryManager_C:GiveItemToPlayer(archetype)`
  returns without error (result in the inventory not checked there).
- Real pickup path: `PDP_MainCharacter_C."Pickup Actor"(AItemWorldManifestation*, bool ToHands)`.
- A raw `servertravel` into a zone has no loot (0 world items on both sides, exp30): loot is spawned by the run
  (route/leg state, `SpawnExecutorSettings.Seed`, `ERandomStateChannel`). Empty garage without a save: 6 items
  (narrative items, gas pump handles, two gameplay-event items at the origin). New-game intro: 2.
- UE4SS Lua objects have no `GetPathName()`; use `GetFullName()` and strip the class prefix.

### Host -> client channel (exp35/36)
- Host writes `PDW:<seq>:<cmdacks>:<payload>` into its PlayerState name with `GameMode:ChangeName`; clients ack in
  their own name. Payloads of 20 B ... 16 KB arrived intact in ~3 ticks of 200 ms; a 60 KB payload never arrived and
  blocked the queue. Payloads are capped at 8000 bytes. The client command queue now waits for the host's ack per
  `PlayerState.PlayerId`, so quick commands are not overwritten.

### Item sync design (host authoritative world, per-player inventories)
- Host: every second, diff of its world items (context World, not hidden, not attached, not at the origin, not
  `BP_GameplayEventItem_World_C`) → `A,<id>,<archetype>,x,y,z,p,y,r` / `M,...` / `D,<id>` in `ITEMS|` messages; a new
  set of clients starts with `IRESET` and the full list. Ids are `<actor name>#<instance name>` (pooled actors are reused).
- Client: removes its own world loot, spawns mirrors with `SpawnItemActor`, moves/deletes them on `M`/`D`. A mirror
  that leaves the world next to the player (within 500 uu) without being attached to something is a pickup: the
  client's own game code has already put it into the client's inventory; `PICKUP,<id>` makes the host remove the
  original. A new unmirrored item near the player 10 s after the list arrived is treated as a drop: `DROP,...` to
  the host, local copy removed (not tested).

### Bugs found by the tests
- exp37: every item skipped (`GetPathName`), fixed.
- exp38: false `PICKUP`s for the garage gas pump handles removed host items (the client's pumps took the mirrors);
  fixed with the near-player rule and a test check; exp41: a 3 s minimum-age rule missed a real pickup 1.4 s
  after the mirror appeared; replaced by "not attached" (exp42).
- exp40: the first host message (IRESET) was dropped after 5 s while the client was still loading; host now
  keeps waiting, clears queued diffs on a new client set, and the client also starts tracking on the first ITEMS.

### Automated test — run "exp42-loot5", 300 s: 21/21 PASS
Loot part: client got the list and removed its own local items; host spawned 3 steel scrap in front of player 2;
client mirrors all 3 at the same positions (max 0 uu off); client picked the nearest up with `Pickup Actor`;
the scrap is in the client's `Inventory_Player`; host removed that item; no false PICKUP of other items; host
picked one up itself; the client's mirror vanished. Regression exp40 rejoincar 25/25 (before the last two fixes).

### Not done / risks
- Player 2's inventory is not saved anywhere and not shown to the host; car trunk/storage, car parts, crafting,
  damage, quests are not synced. DROP not tested. Loot in a real run (zone) not tested: needs a run started by
  the game. The gas pump handles are protected only by the 500 uu rule.

## Session 2026-10-20 — Visible player bodies (mod v0.5, commit 7290d30)

### Owner report (watching the bot tests)
- Player 2 had no visible body; a mannequin stood in the driver's seat, the car looked raised, and the host
  partly saw that model in front of its own camera. (Owner also saw driving through a scrapyard container: the
  owner attributes it to the scrap the tests spawn, ignored. Red/brown screen patches are the game's blood /
  damage overlay per the owner, not a mod bug.)

### Observations
- `PDP_MainCharacter_C.CharacterMesh0` is the ALS mannequin with `M_PlayerCharacter_Invist` and
  `CastShadow=False`: in single player the body is never meant to be seen.
- While the host drives, its character has no controller (the car is possessed), so "locally controlled" is
  false for the host's own body: the old check showed the host its own body in the driver's seat (the model in
  front of its camera). The host's `BP_MainCharacterManager_C.CharacterActor` briefly pointed at a newly spawned
  player 2 (exp48), so the manager is not a reliable owner either. On the client the manager first points at the
  host's character (exp44).
- The game sets `bHidden` on the driving character, and hidden replicates: the passenger saw an empty driver's
  seat (exp45).
- The game resets the material sometimes; a few samples right after spawn/seat still had the invisible material
  (exp47-49), fixed by refreshing every 200 ms and right after spawn and seating.
- Camera relative to the car (CAMREL): driver 45,-46,62, passenger 45,46,62 — an exact mirror of the driver's
  seat (passenger offset 91.6 uu right, mirrored `TempSocket_Seat`).

### Fix
- Mine: host = every character not controlled by a remote `PlayerController`; client = `Role == 2`
  (autonomous proxy). Others get `/Engine/EngineMaterials/DefaultMaterial` on slots 0/1, a shadow, and are
  un-hidden (actor + mesh).
- Seated characters (attached to a car): mesh lowered 50 uu (no sitting animation), actor collision off; both
  undone on leaving the car.

### Automated tests
- exp50 rejoincar 33/33: each side shows the other's body and never its own (own taken from `[local]` status
  lines, plus `cmChar` on the host); the seated player is lowered and has collision off; BODYSTATE of the seated
  body: not hidden, `DefaultMaterial`.
- exp52 loot 25/25 (exp51 23/25 was a test bot that walked 863 uu away from the items; in `loot` the bot now
  walks only forward).

### Not done / risks
- Grey default material, no sitting pose, no held items/flashlight/animations except locomotion mirrored.
  Visuals were checked on bot screenshots only, not by a human in a real session.

## Session 2026-10-20 — Dev tools, shared trunk, car state, player 2 inventory (mod v0.6, commit 23d6957)

### Dev tools (dev/ in the mod repo, never in the playable build)
- `PDCoopDev` UE4SS mod polls `ue4ss/Mods/PDCoopDev/cmd.txt` every 250 ms in the game thread and answers in
  `out.txt`; `dev/dev.ps1` sends one command and prints the answer (~1 s round trip). Generic reflection
  (`props`, `funcs`, `find` via `ForEachProperty` / `ForEachFunction`), `lua <code>` with helpers, cheats.
  This replaced restart-per-probe: a question about live game state costs seconds, not a 60 s relaunch.
- Intro videos moved aside in the test copies (`Content/Movies` -> `Movies_disabled`, all but
  `CompiledIntroSequence.mp4`); the Nexus intro-skip mods do the same (PCGamingWiki documents the manual way).
  Nexus pages answer 403 to the fetch tool and downloads need an account, so nothing was downloaded.

### Observations
- Player health is not a component: `BP_ResourceManager_C` (GameInstance) holds `UGameResource` objects
  `PlayerHealth`, `CarHealth`, `Fuel`, `CarLim`, `Shield`, ... (`Current`/`Maximum`, `Fill`, `Adjust`). One per
  process, so each machine has its own player health. `ReplenishAll()` exists.
- Car parts are actors attached to the car (not replicated: each machine builds its own set), each with item
  property components `BP_HealthComponent_C` (`HC_GetHealth`, `HC_GetMaxHealth`, `SetHealth`),
  `BP_FuelableComponent_C` (`GetFuelStatus`, `Set Fuel`), `BP_BatteryComponent_C` (`GetBatteryStatus`,
  `Set Battery`); `GetOwner()` is the part. Attach sockets are all `None`; parts are matched by class + position
  in the car frame on a 50 uu grid (front wheels steer: 10 uu grid did not match).
- UE4SS out parameters: pass one table per out param, the game fills it by name (`{Fuel=24.5}`); functions that
  return a TArray (`InventorySystem:GetAllArchetypes`) return a Lua table of RemoteUnrealParam (`:get()`).
- Inventory: `BP_InventoryManager_C.Inventory_Trunk` is a `UItemContainer` (Slots -> `UItemSlot.Items`).
  `Archetype:CreateInstance(wco, 0)` + `Container:AddItem(inst, true)` adds; `RemoveItemsOfType(arch, n)`,
  `RemoveAllItems()` remove. `GetInventoryTrunk` returns the same container. Without a save (test garage) the
  player container has 0 slots, AddItem(..., true) creates them.
- In the garage the battery charger charges the car on both machines. A first version that sent every client-side
  increase to the host ran the charge port's battery away (70 -> 1840 / 160); now only part health increases
  (repairs) are sent, and the charge port component is skipped.

### Design (carsync.lua)
- Trunk: host sends the full list on change / new clients; client rebuilds; client changes go up as per-type
  count deltas (merge with concurrent host changes). A host list arriving while the client has an unsent change
  is not applied (the change is sent first), else the item would be duplicated.
- Car: host sends changed values (>= 0.5); client applies and holds them each second.
- Player 2 inventory: random client id file, HELLO per host session, INVSAVE on change (<= every 5 s), host file
  `save_<id>.txt`, INVLOAD on HELLO.

### Automated tests
- `dev/test_carsync.ps1` exp60: 15/15 (trunk both ways, simultaneous puts merge, car damage host->client,
  client-only damage undone, client repair -> host, no battery runaway, inventory saved and restored after a
  full restart of player 2's game, no errors/crashes).
- Regression with carsync loaded: exp61 rejoincar 33/33, exp62 loot 25/25.

### Not done / risks
- Item state is not carried (items recreated from archetype: durability, can fuel, charge reset).
- Refuel/charge by player 2 lost; parts installed/removed/torn off not synced; other car containers not synced.
- Player 2: equipment, hotbar, health not saved. A trunk taken by both players at once can duplicate an item
  (logged as "NOT ENOUGH ON THE HOST").

## Session 2026-10-21 — Item state, player 2 refuel, down / revive / team death, switches (mod v0.7, commit a69567d)

Owner decisions (grilling): item state transfers exactly; fallback 50 % of max but never more than it had; else
recreate (exploit accepted). Player 2's refuel/charge: only player actions count. Down instead of dead, 60 s,
revive both ways (hold 5 s, food/medicine 60 % else 20 %), team death = the game's death for both, player 2's
losses by the same rule into the host's tombstone. Feature switches + v0.6 fallback for the playtest (Radmin VPN).

### Observations
- Item state lives in the instance's property data (`IP_Fuelable.Fuel`, `IP_Battery.Battery`, `IP_Durability.Durability`
  (int), `IP_Health.Health`; the `IP_*` structs are UserDefinedStructs). `UInventoryBlueprintLibrary.GetItemProperties`
  is a wildcard thunk: from Lua it returns nothing. `GetDataBlockDump` shows archetype data, not current values.
- Property components can be re-pointed: `UItemPropertyComponent.SetItemInstance(inst, false)`. A component made
  with `StaticConstructObject(BP_FuelableComponent_C, InventorySystem)` (no actor) reads and writes any instance,
  also one in a container. `Set Fuel` does not clamp (999 in a 10 l can sticks).
- `SpawnItemInstanceActor(wco, xf, inst, ctx)` manifests an existing instance (contexts World/Attachment/Hand/
  AttachmentWorld) and leaves it in its container; not used.
- Player refuel = `BP_FuelableComponent_C:TransferFuel` (fuel can BP; also pump handle / siphon), charge =
  `BP_BatteryChargerComponent_C:DoCharge` (battery charger tool). Jumper cables are for anchors.
- The gas cap is a view of the tanks (capacity 50 = 25 + 25, whole litres): a 10 l can raises the tank by 10 and
  the cap by 10 in single player. On player 2's machine the cap-to-tank flow does not run; the host does it when it
  gets "+10 in the cap". The charge port's battery component is a pass-through (skipped).
- Player damage: `AC_PlayerHealthReceiverHelper` (BP) → `CheckForLifesaver(IncomingDamage, out UpdatedDMG)`; a
  post-hook can change UpdatedDMG (negative). The game has a one-time "magic health point" that already cuts the
  first lethal hit to leave 1 HP. `UGameResource:SetMinBoost` did not floor health (the player died).
  `res.PlayerHealth:Adjust` bypasses the receiver (kills directly).
- The garage protects the player (`playerProtected`), damage tests need a zone. After a team death the host's save
  changes; a zone opened directly afterwards took no damage, so zone tests restore a pre-death save.
- `MessageSystem:DispatchMessage(payload, recipient)` with a fresh `MSG_Damage_Physical_C` did nothing here; calling
  the receiver's `MessageBind_MSG_Base_Damage_C(msg, me, me)` applies damage.
- On death the game calls `BFL_ItemPropertyUtilityFns:RemoveRandomItems` for trunk (rate 0.075) and pockets/hand
  (rate 0, mode 0). In a directly opened zone the host kept its pockets; player 2's removal with the same
  arguments removed nothing either. Real-run behaviour not seen yet.
- HUD text: `UMG_Feedback_WarningList."Add Message"(text, level, category)` reports IsShowingMessage=true but
  nothing appeared in `shot showui` screenshots (the list is Collapsed on foot; made visible, still nothing seen).
  `HighResShot` never captures UI; `shot showui` does.
- Tooling: Git Bash rewrites `/Game/...` arguments into Windows paths (MSYS); use `MSYS_NO_PATHCONV=1`.
  `GetClass()` on a dead object crashed the host natively (exp67), pcall does not help: check validity first.

### Design
- itemstate.lua: accessor components per kind; state text `F7.25_D3`; trunk / saved inventory keys `<arch>@<state>`;
  world items `A,...,<state>` and `S,<id>,<state>` ops; drops carry state.
- carsync.lua: CARST full state, newest only in the queue (`hostSendLatest`); fuel/battery threshold 0.1, gas cap 1.0.
  Refuel: hooks only flag "player 2 acted this second", the actual change of every fuel/battery value is sent
  (CARADD) and added on the host.
- downed.lua: floor in the CheckForLifesaver post-hook (`<= 1 HP` → leave 1 and go down; down → damage 0); host
  keeps who is down and when, DOWNST each change; revive by holding E (or PDCoopDev `holdrevive`); first aid = any
  item with `IP_FirstAid` in pockets/hand (food, medicine; the medpack and medicine items went to no Inventory_
  container when given); team death: host `Adjust(-10*max)`, TEAMDEATH to player 2 (health to 20 %, no own death),
  the host's RemoveRandomItems call on its pockets is mirrored (PENALTY) while both are still in the zone; LOST
  items go to the tombstone container from `BP_LegStateBase_C:GetTombstoneInfo`.
- features.txt switches (itemstate, trunk, carstate, refuel, invsave, downed).

### Automated tests
- test_itemstate exp63 15/15; test_refuel exp69 10/10 (after: lost small amounts, cap rounding, queue lag, a host
  crash from GetClass on a dead object); test_downed exp75 14/18 (failed checks were test mistakes and the
  "losses > 0" expectation, see above).
- Full suite exp81 (dev/run_all.ps1): carsync 15/15, itemstate 15/15, refuel 10/10, downed 17/17, rejoincar 33/33,
  loot 25/25. The bot client now keeps reconnecting if its first connect fails (exp80: the host took 2 min to load
  the garage with the restored save and both garage tests ran without a client).
- Mutation (coop-qa): downed = off -> test_downed 8/17 (exp82). Without the mod two lethal hits in a row also left
  1 HP (the game's own magic health point lasts a while), so that one check does not tell the two apart; "down",
  revive and team death checks all failed as they should.

### Not done / risks
- Full save of player 2 (equipment, hotbar, health), car parts install/remove, other car containers: not done.
- Downed screen messages unconfirmed; losses/tombstone in a real run untested; the game's own death in a zone for
  player 2 if damage bypasses the receiver (e.g. a kill volume) would still take player 2 out of the session.

## Session 2026-10-21 — Code review (mod v0.7.1, commit da16e68)
Fixed: saved inventory of player 2 was re-applied on every host session (map change, rejoin) and could take
back fresh pickups or undo team-death losses -> once per launch; a downed player who left kept a team-death
timer -> dropped; player 2 could die in its own game during a team death -> no damage then; trunk could stay
out of sync after a client change that did nothing on the host -> host always answers; host messages over
8 KB were dropped -> sent in parts (channel exp84: 12 KB in 2, 20 KB in 3 parts, intact). A trunk does not get
near 8 KB (exp83: 15 cans fitted, the game dropped the rest into the world).
Suite exp83 all pass (115 checks). Left as known risks: client -> host commands have no size check
(INVSAVE of a full inventory), the host's own save and player 2's save file can diverge if the host reloads an
older save, item state other than fuel/charge/durability/health is not carried.

## Session 2026-10-22 — First internet playtest (Radmin VPN) and fixes (mod v0.8.0, commit bb5fe62, release v0.8.0)

Owner + friend played over Radmin VPN 2026-10-21. Worked: connecting, seeing each other (movement, look, jump,
crouch), body collision, item transfer with state, riding together. Reported bugs and what they were:
- "One HP for two": player health is one resource per process; each machine has both characters with their damage
  receivers, so damage to the other player's character (a fall seen through replicated movement, a hit) was taken
  from the local player's health. Fix: CheckForLifesaver post-hook zeroes damage for characters that are not mine.
  This also explained the broken revive (players went down from the partner's damage).
- Host Esc crash (EXCEPTION_ACCESS_VIOLATION reading 0x178, native, no Lua in the stack, client hangs ~2 min then
  crashes). Reproduced: pause + unpause with a client connected, and opening the pause menu after an earlier
  open/close (also with the world not paused). Not fixable without symbols; work-around: a pre-hook on the native
  GameplayStatics:SetGamePaused keeps the world running, and CanOpenPauseMenu answers no on the host while a client
  is connected (message on screen).
- Player 2 pressing E at the car: its game runs CommandEnterCar on its copy of the car (driver's seat, stuck).
  Fix: post-hook on the client, "Exit Car"(false, false) after 0.6 s, then SEAT (or UNSEAT when riding).
- After the host's death the client could not rejoin until the host pressed F8: re-host was once per map name per
  session (garage already done). Now once per arrival.
- Trunk duplicates (both take the same item; swap into a slot): trunk lock, host decides, the other's menu closes
  (hooks on OpenCarInventories / OpenPlayerInventory / OpenInventoryContainer, release when IsPlayerMenuOpen false).
- Car reset/teleport by player 2 only animated: StartCarReset / StopCarReset forwarded to the host.
- Dropped item hung in the air: placed at player 2's feet (turning physics on with SetSimulatePhysics crashed the
  host twice a few seconds later).
- Different worlds (doors, containers, props, map): the next big step. Owner chose same-world-from-the-host's-save
  (player 2 loads a copy in its own slot), one world state for both (quests, progress, achievement counters), shared
  look-at objects follow the nearest player, the car map stays per player. docs/WORLD_SYNC.md.

### Crashes found in the dev sessions
- Kept StaticConstructObject accessors were freed by GC (nothing references them) -> created per call.
- Reading fields of a pooled item actor's missing Instance crashes natively (0x18 in a UE4SS UObject member call,
  pcall does not catch it): instanceOf() guard everywhere, dev tools too.

### Tooling
- installer/PDCoop.bat + PDCoop.ps1: install/update from the GitHub release (UE4SS pinned by SHA-256, mod checked
  against SHA256SUMS.txt) or a local zip; update removes old mod files and keeps role/features/player_id/save_*;
  log report scrubs user/PC names, account ids, non-Radmin IPs, user paths. Verified on a fake game folder,
  local and from the release.
- Git Bash: `\t` / `\r` in Python heredoc strings turned paths in run_all.ps1 into tabs and CRs (two tests silently
  never ran in suite exp90); fixed.

### Tests (all pass): test_session 12/12 (exp92), gametravel 15/15, carsync 15/15, itemstate 15/15, refuel 10/10,
downed 20/20 (with separate-health checks), rejoincar 33/33, loot 25/25.

### Not done
Esc root cause (native), client crash in menu after the host vanished (no Lua in stack; likely downstream),
downed screen messages still unconfirmed by a human, world sync.
