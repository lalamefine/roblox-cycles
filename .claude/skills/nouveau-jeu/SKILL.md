---
name: nouveau-jeu
description: Crée un nouveau jeu Roblox à partir de roblox-kit (repo, renommage, Config, premier build). À utiliser quand on démarre un nouveau jeu.
---

1. Le repo du jeu est créé sur GitHub avec « Use this template » depuis `roblox-kit` (ou le Kit est copié dans un repo vide).
2. Renomme `name` dans `default.project.json` et le `storeName` de `Data.configure` (`PlayerData_v1` → `<Jeu>_PlayerData_v1`).
3. Crée `src/shared/Config.luau` (toutes les constantes d'équilibrage) et `src/shared/Formulas.luau` (logique pure) avec leurs tests dans `tests/`.
4. Remplace `src/server/Main.server.luau` et `src/client/Main.client.luau`.
5. Note dans `KIT_VERSION` le commit de roblox-kit d'origine.
6. Vérifie : `stylua src tests && selene src && lune run tests/run && rojo build -o build.rbxl`.
