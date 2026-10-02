# Règles du projet (jeu Roblox basé sur roblox-kit)

Ce repo est un jeu Roblox écrit en Luau et synchronisé avec Studio par Rojo.
Le code source vit dans les fichiers : **Rojo est la vérité**. N'édite jamais un script
directement dans Studio (via MCP ou autre) : Rojo l'écraserait.

## Architecture (obligatoire)

| Dossier | Arrive dans | Contenu |
|---|---|---|
| `src/server/` | `ServerScriptService.Server` | Logique de jeu, DataStores, achats, classements, bots, physique autoritaire |
| `src/shared/` | `ReplicatedStorage.Shared` | Config, formules pures, types, `Kit/` (modules partagés) |
| `src/client/` | `StarterPlayerScripts.Client` | Entrées, caméra, rendu local, UI |

- Un seul `Main.server.luau` et un seul `Main.client.luau` ; tout le reste est en ModuleScripts.
- `src/server/KitServer/` et `src/shared/Kit/` viennent de roblox-kit. Améliore-les de façon générique
  (sans logique propre au jeu) pour pouvoir les remonter au Kit (skill `remonter-au-kit`).

## Sécurité : le serveur fait autorité
- Le client n'envoie que des **intentions** (direction, bouton pressé), jamais des résultats (score, collision, achat).
- Tout remote client → serveur passe par `Net.onServerEvent` (limité en débit) et valide ses arguments
  (`typeof`, bornes, NaN : `x ~= x`).
- Les achats passent par `KitServer/Shop` (reçus idempotents). Jamais d'achat accordé sur parole du client.

## Luau
- `--!strict` en tête de chaque fichier. Types exportés pour les structures partagées.
- Formules et logique pure dans `src/shared/` **sans API Roblox**, pour être testées sous Lune (`tests/`).
- Pas de `wait()`, `spawn()`, `delay()` : utilise `task.*`.
- Pas de boucle `while true` sans `task.wait` ; déconnecte les connexions des objets détruits.

## Performance (mobile d'abord)
- Ne réplique pas des centaines de Parts : le serveur envoie des données, le client rend (pool d'instances).
- Regroupe les envois réseau (par tick), utilise `UnreliableRemoteEvent` pour l'état éphémère.
- Requêtes de proximité via `Kit/SpatialHash`, pas de boucle O(n²) sur tous les joueurs.

## Monétisation et viralité
- Prévois dès la conception un point d'accroche : Game Pass (permanent), Developer Product (consommable),
  cosmétique. Pas de pay-to-win qui ruine l'équité d'un duel.
- Objets aléatoires payants : probabilités affichées et vérification `PolicyService` obligatoires.
- Boucle de récompense < 30 s, règles compréhensibles en 5 s, moments spectaculaires « clipables ».

## Vérifications (avant chaque commit)
```
stylua src tests
selene src
lune run tests/run
rojo build -o build.rbxl
```
Le hook Claude Code lance format + lint après chaque édition. La CI relance tout sur chaque PR.

## Studio et MCP
- Le serveur MCP intégré à Studio (Assistant Settings → MCP Servers → Quick connect → Claude Code)
  sert à **observer et tester** : arbre (`search_game_tree`, `inspect_instance`), console (`get_console_output`),
  playtests (`start_stop_play`, `character_navigation`, `user_keyboard_input`), captures (`screen_capture`),
  `execute_luau` pour sonder l'état.
- Studio n'existe que sur le PC Windows du propriétaire. En session cloud, limite-toi au code et aux tests Lune.

## Langue
Commentaires, docs et messages de commit en français.
