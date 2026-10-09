---
tags: [positive, database]
max_turns: 20
allowed_tools: [Skill, Read, Glob, Grep]
---

Écris un Funprog Sage X3 qui réserve une quantité sur un lot : il décrémente le champ Y_FREEQTY de ma table spécifique YSTOCKLOT (abréviation YSL, clé Y_LOT) seulement si la quantité libre suffit, puis crée une ligne dans ma table YRESERV (abréviation YRS, champs Y_LOT, Y_QTY, Y_USR). Il doit pouvoir être appelé dans ou hors d'une transaction existante.
