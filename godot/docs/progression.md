# Expérience et attributs

Le personnage commence au niveau 1, sans bonus ni point disponible. Les dégâts,
les vitesses et les 100 PV initiaux restent ceux du jeu existant.

- Chaque niveau donne **2 points**, à répartir librement ou à conserver.
- Force : +5 % des dégâts physiques de base par point (griffes, hache et charge).
- Vitalité : +10 PV maximum par point. Ne soigne pas lors de l'attribution.
- Rapidité : bonus à la marche et à la course, avec rendements décroissants :
  `1 + 0,5 × points / (25 + points)`. La nage, les sauts, le vol plané et
  l'esquive conservent leurs réglages actuels.
- Magie : +5 % des dégâts de base des boules de feu par point.

La jauge reste visible en bas de l'écran. Ouvrir **Inventaire (I) → Personnage → Attributs**
pour répartir les points. La navigation suit le fonctionnement existant du sac.

Il n'y a pas de plafond de niveau dans la progression. Le seuil du niveau `n`
est `100 + 50 × (n − 1)` XP. Le surplus est conservé, y compris si une récompense
fait gagner plusieurs niveaux.

Récompenses actuelles : araignée 30 XP, bandit 40 XP, golem 60 XP,
Dévoreur du lac 250 XP. L'XP vient de l'élimination et ne nécessite pas de
ramasser le butin. Chaque instance ennemie ne peut récompenser qu'une fois.
Le gardien ogre conserve son comportement invulnérable et sa quête.

La progression est partagée entre les joueurs des différentes zones via
l'autoload `Progression`. Les sauvegardes v3 contiennent niveau, XP, points
disponibles et attributs. Charger une sauvegarde ancienne initialise ces données
au niveau 1. Les fichiers anciens restent intacts et les budgets de points
incohérents sont rejetés avant l'application de la sauvegarde.

La mort conserve la progression. Les soins, aliments, repos au feu, affichages
de santé et réapparitions utilisent le maximum de PV issu de la vitalité.
Les ennemis réapparaissant au chargement peuvent donner de l'XP à nouveau,
conformément au fonctionnement existant du monde.

Tests : `tests/test_progression.gd`, `tests/test_save_system.gd`,
`tests/test_claw_combat.gd`, `tests/test_reactive_combat.gd`,
`tests/test_nael_dodge.gd`, `tests/test_fireball_aim.gd` (mode graphique),
`tests/test_lake_monster.gd`.

Le nombre d'ennemis sur la carte n'a pas été modifié. Les futurs ennemis peuvent
utiliser `Progression.reward_enemy(self, montant)` lors de leur élimination.
