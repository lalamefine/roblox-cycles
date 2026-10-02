---
name: playtest
description: Lance un playtest automatisé dans Roblox Studio via le MCP de Studio et produit un rapport. Uniquement sur le PC Windows où Studio est ouvert.
---

1. Vérifie que les outils MCP de Studio sont disponibles (`get_studio_state`). Sinon, arrête-toi et dis que le playtest demande Studio sur le PC Windows.
2. Lance `rojo serve` dans le repo (en arrière-plan) et vérifie dans Studio que le plugin Rojo est connecté (`search_game_tree` doit montrer `ServerScriptService.Server`).
3. Délègue au sous-agent `playtester` avec le scénario à jouer.
4. Enregistre le rapport et les captures dans `docs/playtests/<date>-<sujet>.md`.
