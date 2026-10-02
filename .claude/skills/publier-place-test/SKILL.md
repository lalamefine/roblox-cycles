---
name: publier-place-test
description: Publie le build courant sur la place de test Roblox via Open Cloud. Jamais sur la place publique sans accord explicite du propriétaire.
---

1. Vérifie que `.env` contient `ROBLOX_API_KEY`, `ROBLOX_UNIVERSE_ID`, `ROBLOX_TEST_PLACE_ID` (sinon arrête-toi et demande-les).
2. Vérifie que tout passe : `stylua --check src tests && selene src && lune run tests/run`.
3. Lance `bash scripts/publish.sh test`.
4. Indique le numéro de version renvoyé. La place publique (`bash scripts/publish.sh prod`) n'est publiée que sur demande explicite.
