---
name: remonter-au-kit
description: Remonte vers roblox-kit une amélioration générique faite dans un jeu (modules Kit/KitServer, agents, skills, CI).
---

1. Liste les fichiers modifiés sous `src/shared/Kit/`, `src/server/KitServer/`, `.claude/`, `tests/framework.luau`, `.github/` depuis le commit noté dans `KIT_VERSION`.
2. Retire toute logique propre au jeu : le Kit ne doit connaître aucun jeu.
3. Applique les changements dans un clone de `roblox-kit` sur une branche, avec tests Lune pour les modules purs.
4. Ouvre une PR sur `roblox-kit` qui explique d'où vient l'amélioration.
