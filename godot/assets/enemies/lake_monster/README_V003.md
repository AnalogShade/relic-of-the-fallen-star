# Crystalmaw V003 — intégration jouable

La V3 remplace le modèle du premier prototype dans le monde principal. Source Blender : `3D MODELS/monstre lac/monstre_lac_v003.blend`, conservée intacte pendant l'export. Le fichier de jeu est `crystalmaw_v003.glb` : un maillage texturé, trois images intégrées, 26 os et quatre clips (`Lake_Idle`, `Lake_Emerge`, `Lake_Spit`, `Lake_Walk`). Les contraintes IK des petites pattes ont été échantillonnées en transformations d'os pour que la marche fonctionne sans contraintes Blender dans Godot. Les guides FX, le studio et le modèle source masqué sont exclus de l'export.

## Essayer

Lancer `3D MODELS/monstre lac/Voir le monstre du lac.cmd`, puis avancer vers le lac. Départ sans feu; F9 active ou désactive le pouvoir uniquement dans cette session de test. Maintenir le clic droit pour viser puis relâcher pour lancer. F8 recommence avec Naël à 100 PV et le monstre à 320 PV en conservant le choix avec ou sans feu. R esquive. Quatre boules de feu dans la gueule suffisent; celles sur le corps n'enlèvent aucun PV. Le point de départ normal du monde reste inchangé.

## Adaptation au jeu

`scripts/lake_monster.gd` conserve le point d'entrée existant et hérite de `scripts/lake_monster_v3.gd`. Le boss est désormais un `CharacterBody3D` : le déplacement lent utilise les collisions du terrain plutôt qu'une simple translation du modèle.

- Taille : modèle Blender à 100 %, environ 26 m de longueur avec la queue. Le repère avant du GLB est +Z. La hauteur du modèle dans l'eau est réglée par rapport à la surface réelle et non par un décalage fixe depuis le fond; cela conserve la gueule au-dessus du ponton et la partie inférieure immergée.
- Apparition : toujours caché au départ, approche à 27 m du point central, surgissement de 5 s avec des gerbes sur plans texturés transparents.
- Combat : veille de 1,4 s puis attaque de 4,5 s. Cible verrouillée à 1,65 s; tir à 2,33 s. La position de la bouche et de son collider suivent la tête animée de la V3.
- Marche : après un tir, avance pendant au plus 5 s vers le joueur, à 0,45 m/s, avec le cycle sur place exporté. S'arrête pour tirer ou à 18 m du joueur. La poursuite ne dépasse pas 20 m du point d'origine.
- Retraite : si Naël s'éloigne à plus de 48 m, le monstre cesse de tirer, fait demi-tour, marche vers son point d'origine puis inverse le surgissement pour replonger. Il récupère ses PV une fois caché. Les tirs encore présents sont supprimés au début du retour.
- Progression : griffes sans effet; seules les boules de feu dans l'intérieur de la gueule accessible au-dessus de l'eau diminuent les 320 PV, à raison de 80 par impact actuel, soit quatre coups. Aucune sphère cible orange et aucune fenêtre imposée pendant la charge : la gueule elle-même est le point faible. Les tirs ennemis enlèvent 60 PV. La défaite conserve `story/lake_monster_defeated` dans les sauvegardes existantes.

### Projectile et gueule — rendu approuvé le 20 octobre 2026

La sphère orange et sa lumière ont été supprimées du monstre. La hitbox invisible suit toujours la tête et couvre l'intérieur de la bouche. Elle accepte les boules de feu quand le monstre est visible et que la bouche se trouve au-dessus de l'eau, y compris hors de la préparation du tir; la carapace reste invulnérable.

Le projectile utilise `scripts/lake_projectile_fx.gd` : cœur déformé parcouru de filaments cyan, halo additif et trois traînées sur plans (cyan, volutes violettes, fines étincelles). Les shaders procéduraux sont `shaders/lake_projectile_core.gdshader` et `shaders/lake_projectile_energy.gdshader`. Matériaux partagés, 66 particules maximum par projectile, pas d'ombres ni de lumière dynamique supplémentaire. Le rendu fonctionne avec le moteur Compatibility actuel sans dépendre du bloom. La vitesse de 13 m/s, la collision balayée et les 60 dégâts sont conservés.

Le raccourci F9 est défini exclusivement par le contrôleur de l'aperçu dans `tests/`. Il annule la visée ou le lancer en préparation lors du changement de mode et ne modifie aucun drapeau de progression. `tests/test_lake_preview_controls.gd` vérifie les deux modes avec la vraie logique de lancement du joueur, les impacts sur le corps, quatre vrais projectiles contre la gueule et la remise à zéro par F8. Journal : `diagnostics/lake_preview_toggle_test.log`.

À l'impact, le cœur disparaît, le halo se dilate brièvement et la traînée cesse d'émettre puis se dissipe pendant 0,75 s avant suppression. `tests/test_lake_projectile_fx.gd` contrôle les plans, le budget, la conservation de la position de l'effet détaché et son nettoyage. `tests/test_lake_monster.gd` vérifie aussi la vulnérabilité de la gueule hors de l'ancienne fenêtre de charge. Captures : `tests/lake_projectile_close.png` et `tests/lake_projectile_world.png`. Journaux : `diagnostics/lake_projectile_gameplay.log`, `lake_projectile_fx_tests.log`, `lake_projectile_world.log`.

## Validation

### Correction des performances — 20 octobre 2026

Le ralentissement venait principalement du balayage de la grande capsule contre le terrain dense, et non du rig ou de l'animation de marche. Le déplacement utilise maintenant une capsule d'appui de rayon 0,5 m. Une capsule large séparée de rayon 3 m conserve le blocage du joueur et des projectiles; son masque de collision est nul et elle ne balaie pas le terrain. Les volumes de blocage sont désactivés lorsque le monstre est caché ou replonge. Aucun maillage détaillé de collision n'est utilisé.

`scripts/lake_water_lookup.gd` indexe les triangles d'eau proches dans une grille de 2 m préparée pendant la veille. Il conserve le calcul barycentrique exact de la surface et évite de parcourir les 4 992 triangles du lac à chaque déplacement. Le test compare 240 positions, dont des berges sèches et des limites de cellules.

`scripts/lake_monster_splash.gd` remplace les gouttes volumétriques simulées par 12 plans texturés pour une grande gerbe ou 4 pour une petite, avec animation de taille et fondu dans le shader. Le canal alpha est effectif. Un ordre de rendu après l'eau évite que la surface transparente masque les gerbes. Texture, provenance ImageGen et prompt exact : `assets/effects/lake_splash/README.md`.

Mesures sur cette machine, Godot 4.6.1 Compatibility / RTX 2060, même monde et même caméra, 60 échantillons par phase après échauffement :

| Mesure moyenne | Avant | Après |
| --- | ---: | ---: |
| Balayage physique du monstre | 16,66 ms | 0,87 ms |
| Callback de marche isolé | 19,97 ms | 1,26 ms |
| Recherche de hauteur d'eau du boss | 1,65 ms | 0,20 ms |
| Image pendant marche complète | 33,39 ms (~30 i/s) | 8,32 ms (~120 i/s) |
| Image pendant marche et plusieurs gerbes | non mesuré | 8,39 ms (~119 i/s) |

Ce sont des mesures locales dans un scénario contrôlé, pas une garantie pour toutes les situations. L'enregistrement PNG est exclu des mesures. L'animation seule restait à 8,33 ms avant la correction. Les résultats reproductibles sont dans `tests/profile_lake_monster.gd`, `tests/lake_monster_profile_before.json` et `tests/lake_monster_profile_after.json`. Journaux complets : `diagnostics/lake_perf_before.log`, `lake_perf_after_effects.log`. Les scripts précédents sont conservés dans `diagnostics/lake_perf_before_scripts/`.

**41 contrôles réussis** : les 27 scénarios de gameplay ci-dessous et 14 contrôles dans `tests/test_lake_monster_effects.gd` sur l'eau, les collisions larges, les plans RGBA et leur suppression. Capture du rendu final : `tests/lake_monster_splash_cards.png`. Les avertissements de ressources à la fermeture déjà observés dans le projet restent présents; aucun échec dans les scénarios testés.

**27 contrôles réussis**, dans `tests/test_lake_monster.gd` : modèle V3 actif, quatre clips, squelette de 26 os, mouvement effectif des pattes après export, apparition cachée, approche, éclaboussures, filtrage des dégâts, vraie boule de feu en vol contre la gueule, collision et 60 dégâts du tir ennemi, déplacement réel, limite de poursuite, retour à pied puis immersion, absence de tir pendant la retraite et persistance de la victoire.

Le premier essai a détecté une interception de la boule de feu par le ponton avec une gueule trop basse. Le réglage d'immersion a été corrigé et le test de collision réel passe ensuite. Les captures `tests/lake_monster_surface.png`, `lake_monster_tir.png` et `lake_monster_marche_v3.png` montrent le modèle dans le monde actuel. Journaux : `diagnostics/crystalmaw_godot_export.log`, `crystalmaw_godot_import.log`, `crystalmaw_godot_test.log`, `crystalmaw_godot_visual.log`.

Le serveur MCP Godot étant indisponible, l'export et les vérifications utilisent les exécutables locaux de Blender 5.1 et Godot 4.6.1. L'import conserve les textures. Les avertissements de ressources à la fermeture du projet observés précédemment restent présents; ils ne correspondent pas à des échecs des scénarios de gameplay testés.

## Limites du prototype et retour arrière

Le mouvement respecte les collisions et les pentes, mais n'utilise pas encore un système complet de navigation contournant les obstacles. Les appuis sont animés et ne s'adaptent pas individuellement au relief des berges. La vitesse, l'échelle, la cadence et le déplacement sur terre restent à régler avec l'essai du joueur.

Le GLB V002 est conservé dans ce dossier. Les anciennes versions des scripts sont dans `godot/backups/lake_monster_v002/`. Elles permettent de restaurer le prototype précédent sans réexporter Blender. `export_crystalmaw_godot.py` conserve la recette de l'export V3 et n'enregistre pas les modifications temporaires dans le `.blend` source.
