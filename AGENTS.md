# JJS working notes

Read this first. Keep changes small and match the surrounding Lua style.

## Read only what the task needs

Use the map below to choose files. Do not scan every module or read bundle.lua.
Check current source before editing: these notes are a navigation guide, not a substitute for code.
If a file moved or the map no longer matches, search for that specific name/symbol.
Update these notes in the same commit when changing module names, dependencies, loading, config, or UI wiring. Do not repeat versions or slider defaults here; source remains authoritative.

## File map

| Task | Start here |
| --- | --- |
| Entry point / downloads | loader.lua, then main.lua |
| UI layout, feature wiring, defaults | main.lua |
| Drawing UI, animations, sliders, typing, scrolling | Menu.lua |
| Config saving/loading | Config.lua; bindings/defaults in main.lua |
| Version display / update checks | Version.lua, VERSION |
| Bundling | tools/bundle.py, .github/workflows/bundle.yml |
| Player ESP lifecycle / shared helpers | ESP.lua |
| ESP feature rendering | HealthBar.lua, EvadeBar.lua, SpecialMeter.lua, UltimateBar.lua, Moveset.lua, PlayerInfo.lua, Tracers.lua: read only the relevant feature |
| Other visuals | BeamESP.lua, DomainESP.lua, DummyESP.lua, ItemESP.lua |
| Aim / reach / target filtering | Aimbot.lua, Reach.lua, TargetFilter.lua |
| M1 behavior | M1DownslamAssist.lua, M1PingFix.lua |
| BlackFlash aliases and animation timing | BlackFlash.lua; AddBlackFlashOptions in main.lua |
| Other combat automation | Ratio.lua, AutoBurst.lua, QTE.lua |
| Movement / protection | Noclip.lua, AntiVoid.lua, AntiBlackhole.lua, DiamondInTheSky.lua |
| Emote unlocks and calibration | Gamepasses.lua; its button in main.lua |
| Kill sounds | KillSound.lua |
| Chat translation | Aura.lua |
| Notifications | Notifications.lua |
| Roulette character selection | RouletteAutoCharacter.lua; mode controls in main.lua |
| Utility buttons | Rejoin.lua, Train.lua |
| Startup fixes | fixes.lua |

## Loading and state

- Existing names are case-sensitive filename stems: Load("BlackFlash") means BlackFlash.lua.
- Modules generally return a table and expose Init(State). main.lua contains exceptions and their initialization arguments.
- main.lua loads modules asynchronously and initializes each once. ESP receives seven dependencies from main.lua; its feature modules use Init(State, Helpers).
- State.Toggles and State.Variables are Roblox Value objects. main.lua creates them lazily, applies config, and wires UI bindings.
- Config.lua saves CatstarJJS.json using readfile/writefile/isfile. Groups: Toggles, Variables, RouletteCharacters. Values are boolean/string/number; nested emote data is JSON inside Variables.SecondEmotes.
- New toggles default false. Numbers and strings need appropriate defaults and bounds in main.lua.
- Menu.lua draws the visible UI with Drawing.new and uses an invisible ScreenGui for input. Keep the single scrolling layout; no tabs.
- BlackFlash delays are milliseconds in config/UI and converted to seconds for task.delay. Multiple animation IDs can share one option.
- Free Gamepasses owns emote page visibility/MaxPage. Calibration separately captures slots 9–16 and saves their cache. Knit require restores the caller's thread identity.

## Publishing

- Finish edits and focused verification locally before GitHub mutations. Publish one final source commit.
- Never hand-edit bundle.lua or build.json. The action generates both after relevant source changes on main; generated commits do not trigger another run.
- loader.lua fetches bundle.lua once. The bundler replaces only main's local request with in-memory module sources and preserves module error names.
- Local generation: python tools/bundle.py (requires Git history; no Python packages).
- VERSION uses major.minor.patch. Bump it for behavior changes, not documentation-only edits.
- After source publication, check the Bundle Lua action and build.json revision. Do not claim live Roblox testing when only mocks/syntax checks ran.
