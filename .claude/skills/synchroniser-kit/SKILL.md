---
name: synchroniser-kit
description: Ramène dans un jeu les nouveautés de roblox-kit depuis la version notée dans KIT_VERSION.
---

1. Lis `KIT_VERSION` (commit du Kit d'origine) et récupère `roblox-kit` à jour.
2. Compare les dossiers partagés (`src/shared/Kit/`, `src/server/KitServer/`, `.claude/agents/`, `.claude/skills/`, `tests/framework.luau`, `scripts/`) entre ce commit et le dernier.
3. Applique les différences dans le jeu, en gardant les adaptations locales voulues.
4. Mets à jour `KIT_VERSION`, lance toutes les vérifications, ouvre une PR.
