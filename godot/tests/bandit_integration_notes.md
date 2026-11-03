# Bandit du camp

## Variantes de couleur (26 octobre 2026)

Tous les bandits utilisent maintenant une variante automatique, stable selon leur
position d'apparition : vert (9 dégâts), jaune (12 dégâts), noir (16 dégâts).
Ces valeurs sont celles d'un coup normal avec la base `damage = 12` ; les attaques
lourdes conservent leur multiplicateur de 1,35 et les défenses du joueur s'appliquent.
Les points de vie, déplacements et tempéraments ne changent pas.

Le champ `color_variant` permet de forcer `vert`, `jaune`, `noir`, ou `naturel`
(apparence d'origine et dégâts de base). Le shader `bandit_clothing.gdshader`
applique un réglage Teinte/Saturation à la gamme des rouges du tissu de la capuche
et du foulard, en conservant les variations de saturation et de luminosité. Le
calcul utilise l'espace sRGB adapté au moteur de rendu. Il préserve la peau,
le cuir, les métaux, les textures de relief et de rugosité. Les matériaux sont
partagés par variante sans modifier le GLB importé. Les indications de cible et
de vie affichent aussi le nom de la variante.

Validation : `--headless --path godot --script res://tests/test_bandit_variants.gd`
vérifie les impacts normaux/lourds, les matériaux et la stabilité des couleurs.
Avec `-- --preview` sans headless, ce test produit un aperçu comparatif dans
`diagnostics/bandit_black_20261026/preview.png` à la racine du projet, avec une
référence du modèle original sans effet. Les textures originales et les UV
restent inchangés ; le matériau lit directement la texture albédo importée.
La variante noire désature le tissu et multiplie sa luminosité par 0,30 pour
préserver ses plis. Le modèle original sans effet conserve son tissu rouge.

## Intégration du modèle et comportement

Source Blender : `3D MODELS/bandit 1/bandit1_001.blend` à la racine du dépôt.
Le GLB Meshy original est conservé à côté. Le fichier Blender contient les textures
embarquées, Walking, Running, restpose, ainsi que les actions Idle et Punch créées
sur le squelette Meshy. Le squelette ne possède pas d'os pour les doigts : Punch
anime le bras, le poignet et le torse, avec la forme de main du modèle d'origine.

Export pour le jeu : `res://assets/characters/bandit_01.glb`.
Scène réutilisable : `res://scenes/bandit.tscn`.
Placement dans le monde : `OpenWorld/Sectors/Bandit_Garde`, près de l'accès au camp.

Le garde détecte le joueur visible à 8 m, poursuit jusqu'à 15 m de son poste,
frappe à 1,15 m et inflige 12 points de dégâts au moment de l'extension du bras.
Les coups ne traversent pas les obstacles et ne touchent qu'une fois par attaque.
Le déplacement utilise une NavigationAgent3D et le maillage de navigation précalculé
`res://assets/navigation/bandit_camp.tres`, limité au camp et à ses alentours.
Il ne fait plus sept balayages de collision à chaque frame. La destination est
actualisée au maximum toutes les 0,35 s quand le joueur s'est déplacé de 0,5 m.
La vision est vérifiée toutes les 0,15 s (et au moment de l'impact), avec une mémoire
de quatre secondes de la dernière position visible pour contourner les obstacles.
La navigation garde 0,6 m de marge, refuse les marches de plus de 0,1 m et les
pentes de plus de 42 degrés. Le collider du garde reste une capsule de rayon 0,3 m.
Après déplacement d'obstacles du camp, relancer l'outil d'édition
`--headless --path godot --script res://tests/bake_camp_navigation.gd`.
Il revient en marchant à son poste quand le joueur s'éloigne.
L'inventaire suspend son attaque. À zéro vie, le joueur réapparaît à son point
de départ avec 100 points de vie et deux secondes d'invulnérabilité.

Validation :

- `--headless --path godot --script res://tests/test_bandit.gd` vérifie les clips,
  la poursuite, les dégâts, la portée, les murs et la réapparition.
- `--path godot res://tests/bandit_camp_preview.tscn` teste le vrai camp et produit
  `bandit_at_camp.png` et `bandit_combat.png`. La rencontre testée laisse le joueur
  à 64/100 et le garde revient à moins de 0,3 m de son poste.
- Godot signale une ressource encore utilisée à la fermeture de ces tests ;
  aucune erreur de script n'a été observée pendant la rencontre.
- `--headless --path godot --fixed-fps 60 --script res://tests/bandit_routes.gd`
  vérifie cinq directions autour du camp, avec contact et dégâts puis retour au
  poste. Les cinq passent ; le retour termine à moins de 0,3 m du poste. Le rapport
  est enregistré dans `bandit_routes_latest.json`, avec la référence antérieure
  dans `bandit_routes_before.json` (deux approches sur cinq échouaient auparavant).
