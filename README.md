# roblox-kit

Modèle commun pour les jeux Roblox du projet RobloxExperienceBuilder : squelette Rojo,
modules Luau réutilisables, outillage, CI, et configuration Claude Code (règles, sous-agents, skills, hooks).

Chaque jeu part de ce repo (« Use this template ») ; chaque amélioration générique y remonte.

## Contenu

| Chemin | Rôle |
|---|---|
| `src/shared/Kit/Net` | Remotes centralisés, entrées client limitées en débit |
| `src/shared/Kit/RateLimiter` | Seau de jetons par joueur (pur, testé) |
| `src/shared/Kit/SpatialHash` | Requêtes de proximité rapides pour les .io (pur, testé) |
| `src/shared/Kit/Steering` | Pilotage des bots : chercher, fuir, errer, rester dans l'arène (pur, testé) |
| `src/shared/Kit/Signal` | Signal minimal (pur, testé) |
| `src/server/KitServer/Data` | Sauvegarde joueur avec verrou de session, migrations, sauvegarde auto |
| `src/server/KitServer/Shop` | Game Passes et Developer Products, reçus idempotents |
| `src/server/KitServer/Leaderboard` | Classement global OrderedDataStore, écritures regroupées |
| `src/server/KitServer/Analytics` | Couche AnalyticsService (entonnoirs, économie, événements custom) |
| `tests/` | Mini framework + tests Lune des modules purs |
| `CLAUDE.md` | Règles pour Claude Code (client/serveur, sécurité, perf, monétisation) |
| `.claude/agents/` | Sous-agents : game-designer, luau-engineer, playtester, liveops |
| `.claude/skills/` | nouveau-jeu, ajouter-produit, playtest, publier-place-test, remonter-au-kit, synchroniser-kit |
| `.claude/settings.json` | Hook : format + lint après chaque édition de Claude |
| `.github/workflows/` | CI (format, lint, tests, build, typage) et publication sur la place de test |
| `scripts/publish.sh` | Publication Open Cloud (`test` ou `prod`) |

## Installation sur le PC Windows (une fois)

1. Installer [Git for Windows](https://git-scm.com/download/win) (fournit Git Bash, utilisé par Claude Code et les scripts).
2. Installer [Rokit](https://github.com/rojo-rbx/rokit) puis, dans le repo : `rokit install`.
3. Installer Roblox Studio et le plugin Rojo (`rojo plugin install`).
4. Installer Claude Code, puis dans Studio : Assistant Settings → MCP Servers → Quick connect → Claude Code.
5. Dans le repo : `rojo serve`, puis « Connect » dans le plugin Rojo de Studio.

## Commandes

```bash
stylua src tests          # format
selene src                # lint
lune run tests/run        # tests des modules purs
rojo build -o build.rbxl  # build local
bash scripts/publish.sh test   # publie sur la place de test (.env requis)
```

## Publication automatique

Pour que `main` soit publié sur la place de test à chaque fusion, ajouter dans les réglages GitHub du repo :
- secret `ROBLOX_API_KEY` (clé Open Cloud avec le droit `universe-places:write` sur l'expérience) ;
- variables `ROBLOX_UNIVERSE_ID` et `ROBLOX_TEST_PLACE_ID`.

Sans eux, le workflow ne fait rien. La place publique ne se publie jamais automatiquement.
