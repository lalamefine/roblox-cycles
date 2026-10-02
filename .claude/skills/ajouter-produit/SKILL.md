---
name: ajouter-produit
description: Ajoute un Game Pass ou un Developer Product à un jeu basé sur roblox-kit (config, effet serveur, bouton UI, analytics).
---

1. Ajoute l'offre dans `src/shared/Config.luau` sous `Config.Shop` avec `id = 0` tant qu'elle n'est pas créée dans le Creator Hub (une offre à 0 est ignorée).
2. Côté serveur, déclare-la dans `Shop.configure` :
   - produit : `grant(player, profile)` applique l'effet et renvoie `true`, ou `false` si impossible maintenant ;
   - passe : `onOwned(player)` applique l'avantage permanent ; teste-le ailleurs avec `Shop.owns(player, nom)`.
3. Le client demande l'achat via un remote limité (`Net.onServerEvent`) qui appelle `Shop.promptPass` / `Shop.promptProduct`.
4. Logue l'achat avec `Analytics.custom(player, "Achat_<nom>")`.
5. Note dans la PR : nom, prix suggéré en Robux, description, et la création à faire dans le Creator Hub (seul le propriétaire peut le faire), puis l'id à reporter dans Config.
