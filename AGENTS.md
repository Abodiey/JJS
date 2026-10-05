# JJS agent notes

## Start here
- Read this file, then only the source files needed for the request.
- Do not read bundle.lua or scan every module. Search a specific filename/symbol if needed.
- Verify current code before changing it. This map may lag manual edits.
- Update this file in the same commit if files, dependencies, or wiring change. Keep it short; do not duplicate current settings, versions, or implementation code.
- Match nearby Lua style. Keep fixes simple; avoid unrelated refactors.

## Where to edit
| Request | Files / symbols |
| --- | --- |
| Feature UI, defaults, module registration | main.lua: UiLayout, ModuleList, VariableDefaults, Ranges |
| Drawing UI, scrolling, sliders, text entry, animations | Menu.lua |
| Config | Config.lua; main.lua: BindToFolder |
| Loader or bundling | loader.lua, tools/bundle.py, .github/workflows/bundle.yml |
| Update/version display | Version.lua, VERSION |
| Player ESP | ESP.lua for shared lifecycle; the specific feature below for rendering |
| Aim / reach | Aimbot.lua, Reach.lua; TargetFilter.lua for shared filtering |
| M1 | M1DownslamAssist.lua or M1PingFix.lua |
| BlackFlash | BlackFlash.lua; main.lua: AddBlackFlashOptions |
| Emotes / free gamepasses | Gamepasses.lua; main.lua for its button |
| Translation | Aura.lua |
| Notifications | Notifications.lua |
| Roulette | RouletteAutoCharacter.lua; main.lua for mode controls |

Other modules are named after their feature: AutoBurst, Ratio, QTE, Noclip, AntiVoid, AntiBlackhole, DiamondInTheSky, BeamESP, DomainESP, DummyESP, ItemESP, KillSound, Rejoin, Train. Startup fixes are in fixes.lua.

ESP feature files: HealthBar.lua, EvadeBar.lua, SpecialMeter.lua, UltimateBar.lua, Moveset.lua, PlayerInfo.lua, Tracers.lua. Read only the requested feature and any shared helper it uses.

## Wiring rules
- Load("Name") maps to Name.lua, with exact case. Modules return their API table; inspect main.lua for Init arguments and exceptions.
- main.lua loads modules asynchronously, initializes each once, and supplies ESP.Dependencies. ESP features use Init(State, Helpers).
- State.Toggles / State.Variables contain Value objects. main.lua handles defaults, config binding, and numeric bounds. New toggles default false.
- Config.lua persists CatstarJJS.json: Toggles, Variables, RouletteCharacters. Stored values are booleans, numbers, or strings.
- Menu.lua uses Drawing.new for visuals and an invisible ScreenGui for input. Keep one scrolling page, no tabs.
- Keep feature settings/animation mappings in their source files, not these notes.

## Finish
- Complete local edits and focused checks before GitHub mutations; publish one final source commit.
- Edit separate source modules, never generated bundle.lua/build.json.
- tools/bundle.py bundles root Lua modules, excluding loader.lua/bundle.lua. It supplies main.lua with in-memory request responses; other modules retain normal request behavior.
- loader.lua downloads the bundle with retries. Preserve module names, dependencies, error names, and behavior.
- Source changes on main trigger .github/workflows/bundle.yml; generated commits do not retrigger it. Local generation: python tools/bundle.py.
- VERSION uses major.minor.patch. Bump for behavior changes, not docs alone.
- Verify the bundle action/build revision after source changes. Distinguish mocked/syntax checks from live Roblox testing.
