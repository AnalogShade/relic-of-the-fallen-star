# Combat réactif

Les scripts des ennemis existants utilisent tous scripts/enemy_combat.gd : aucune
modification des instances de la carte n'est nécessaire. Les trois tailles de golems
sont couvertes. Les patrouilles, la navigation, les points de vie et les contrôles du
joueur restent propres aux scripts existants.

## Tester

- F5 : jouer normalement dans le monde.
- Ouvrir tests/combat_training.tscn et F6 : duel de test. Touches 1/2/3 :
  bandit/araignée/golem ; 4/5 : petit/grand golem. Chaque sélection remet les deux
  combattants en état. La relique de feu est disponible pour cette session.
- T dans l'entraînement : changer de tempérament (le duel recommence).
- Clic gauche : griffe ; clic droit : boule de feu ; déplacements habituels.
- Orange : anticipation ; rouge : frappe/charge ; bleu : interruption/esquive ;
  vert : récupération vulnérable, qui augmente de 25 % les dégâts reçus
  (50 % pour un ennemi agressif).

Avec le profil équilibré, le bandit est interrompu par une griffe, recule et prépare une contre-attaque.
L'araignée se décale latéralement et revient plus vite. Les deux peuvent percevoir
le début d'une attaque à proximité et esquiver après 180 ms, avec un délai de
réutilisation : l'esquive déplace réellement le corps, sans invulnérabilité.
Le golem accumule les dégâts de posture avant d'être déséquilibré (55 points,
25 par griffe, 60 par boule de feu, dissipation de 7/s). Sa frappe lente laisse
une ouverture plus longue. Une protection temporaire contre les interruptions
évite de bloquer indéfiniment l'adversaire ; les dégâts continuent de passer.

Avec le profil équilibré, deux coups rapprochés peuvent provoquer la furie : une charge annoncée dont la
direction est verrouillée et qui finit en récupération. L'agressivité décroît
de 5/s ; les charges ont un délai de réutilisation de 5 secondes. La seconde moitié
de l'anticipation d'une frappe est également verrouillée : sortir de son arc
permet de la faire rater. Les murs bloquent les dégâts, les déplacements utilisent
move_and_slide, les esquives/reculs/charges sondent le sol et respectent la laisse.

## Tempéraments et nouvelles rencontres

Sur la racine de chaque bandit, araignée ou golem, le champ **Temperament** propose :

| Profil | Comportement |
| --- | --- |
| auto | Profil choisi une fois, avec un rythme individuel variant de ±8 % |
| equilibre | Référence du combat initial |
| agressif | Attaque plus vite, esquive rarement, ne recule pas après interruption, charge plus tôt ; sa récupération est plus longue et reçoit +50 % de dégâts |
| prudent | Esquives plus fréquentes, davantage de pauses, peut fuir à faible vie |
| peureux | Esquives fréquentes, hésite davantage et fuit souvent après un coup ; fuite garantie sous 65 % de vie quand disponible |

La fuite dure au plus 1,4 s et ne se redéclenche pas pendant 6 s. L'ennemi essaie
des directions latérales s'il est coincé, puis reprend son comportement normal.
Un golem garde sa résistance et ses déplacements lourds quel que soit son tempérament.
Les profils n'altèrent ni les PV ni les dégâts de base.

Les nouvelles instances utilisent auto par défaut, y compris les araignées et
golems existants qui n'ont pas de réglage explicite. Le résultat reste stable pour
un même chemin de nœud : dupliquer/renommer peut changer le profil, mais il ne
change jamais au milieu d'un combat. **Behavior Seed** permet de fixer ce résultat
indépendamment du nom (0 utilise le chemin). Un profil explicite garantit le choix.
Si vous dupliquez le garde actuel, passez son Temperament de equilibre à auto
ou choisissez le profil voulu dans l'inspecteur.

Quatre bandits ont été ajoutés sous **Sectors/BanditsForestiers** dans open_world.tscn :
bois à l'ouest (-30, -18), lisière est (32, 20), fougères au sud-ouest (-50, 40),
hauts prés au sud-est (45, 35), coordonnées X/Z. Le garde du camp reste équilibré
à sa place. Les nouveaux bandits ont une détection de 6 à 8 m et une laisse de
11 à 13 m, loin du départ. Ils utilisent un évitement local des obstacles et du vide ;
le garde conserve la navigation du camp. Ces nœuds sont déplaçables dans l'éditeur.

Les valeurs des profils sont centralisées dans scripts/combat_temperaments.gd.
Les tests test_temperaments.gd et test_forest_bandits.gd vérifient les différences,
la reproductibilité, la fuite et les rencontres placées dans le véritable monde.

## Brancher les futures animations

Sur la racine d'un ennemi, remplir le dictionnaire exporté Combat Animations avec
des noms exacts de clips de son AnimationPlayer. Clés :

| Clé | Action |
| --- | --- |
| windup | Anticipation de frappe (contre-attaque comprise) |
| strike | Impact |
| recover | Récupération vulnérable |
| stagger | Réaction à une interruption |
| retreat | Recul du bandit |
| dodge | Déplacement d'esquive |
| flee | Course de fuite |
| charge_windup | Anticipation de charge |
| charge | Charge |

Sans clip assigné, les animations existantes servent de remplacement. Les attaques
existantes sont accélérées/ralenties pour caler leur pose d'impact sur l'anticipation.
Les clips personnalisés doivent correspondre à la durée de leur état : le contrôleur
est l'autorité des dégâts, aucun événement d'animation ne doit les infliger une
seconde fois. Le signal Combat.action_started(action) permet aussi de brancher des
effets ultérieurs. Les durées et seuils sont centralisés dans enemy_combat.gd.

## Vérification

Exécuter Godot avec --headless --path godot --script res://tests/test_reactive_combat.gd
depuis la racine du dépôt. Ce test utilise les véritables scènes, vérifie les
transitions, l'absence de dégâts après interruption, la résistance, les ouvertures,
les charges, les murs, la pause inventaire, la mort et la boucle physique.
Les tests existants test_bandit.gd, test_claw_combat.gd et test_cave_golems.gd
couvrent les régressions de navigation, griffe et déploiement dans la grotte.

Les exécutions headless signalent une ressource musicale MP3 encore référencée
à la fermeture (MusicManager/main_music.mp3), indépendamment du combat.
Le ressenti et l'équilibrage demandent maintenant un essai à la manette/souris.
