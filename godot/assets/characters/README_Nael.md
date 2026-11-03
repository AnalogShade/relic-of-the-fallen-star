# Nael — personnage animé

## Animation de charge avant — 15 octobre 2026

Double W joue `esquive_front`, exportée depuis l’action active de la version 015
ouverte dans Blender (images 1–9 à 30 i/s). Aucune clé ni pose source modifiée,
session Blender restaurée en mode Pose à l’image initialement affichée.
Lecture à 2,5× dans Godot : pose finale atteinte en environ 0,107 s, puis
maintenue sans boucle jusqu’à la fin du déplacement (0,36 s). Retour au repos
en fondu de 0,10 s. Déplacement, collisions, dégâts et effets de charge conservés.
Les quatorze animations précédentes et les données du personnage restent intactes.
Export, sauvegardes, rapport et test graphique : `front_dodge_20261015/`.
Test du maintien de la pose pendant le mouvement : zéro échec.

## Réglage sec et visibilité de jour — 15 octobre 2026

Esquive arrière : environ 4 m en 0,18 s, vitesse initiale de 25 m/s dès la
première image physique. Aucune accélération ni attente ; freinage limité aux
22 % finaux de l’impulsion. Intégration de la distance indépendante du pas
physique. Manœuvre totale : 0,30 s. Lecture de l’animation à 2× dans Godot,
sans modifier les clés Blender. Les autres directions gardent leur réglage.

Traînée renforcée : rubans plus larges et plus opaques, silhouettes plus denses
(toutes les 0,025 s, durée 0,20 s), rubans 0,22 s. Contour animé et aura mauve
à bord diffus suivent le personnage pendant l’impulsion puis s’effacent. Effets
sans éclairage, respectant la profondeur, indépendants du glow global du moteur.
Contrôle visuel dans la forêt en plein jour : `daylight_08.png`.
Tests : `test_burst_aura_final.log`, zéro échec, départ immédiat, collisions et
disparition de l’aura vérifiés.

## Traînée mauve d’esquive — 15 octobre 2026

`dodge_trail.gd` ajoute trois rubans effilés dans l’espace du monde et de brèves
silhouettes mauves du personnage, figées dans sa pose du moment. Émission
uniquement pendant une esquive/charge à plus de 2 m/s. Les silhouettes sont
espacées de 0,045 s, disparaissent en 0,16 s ; les rubans en 0,18 s.
Les surfaces respectent la profondeur du décor, sans ombre ni lumière ajoutée.
La réapparition, les menus, le repos et la souris libérée effacent l’effet.
Aucune modification des animations Blender. Tests graphiques :
`back_dodge_20261015/test_trail_final.log` ; rendu : `trail_12.png`.

## Animation de recul de l’utilisateur — 15 octobre 2026

Le premier appui sur S conserve l’orientation pendant la fenêtre de double appui
(0,25 s), tout en déplaçant immédiatement le personnage. Maintenir S au-delà de
cette fenêtre rétablit la rotation de marche normale. Test graphique : `test_turn_fix.log`.

Réglage plus vif : recul d’environ 2,85 m en 0,28 s d’impulsion (contre 1,83 m
en 0,32 s), vitesse maximale 16 m/s. Lecture dans le jeu à 1,2× ; clés Blender
intactes. Manœuvre totale : 0,44 s. Les autres directions restent inchangées.
Test graphique : `test_faster_backstep.log`, zéro échec, collision arrière vérifiée.

Double S joue désormais `esquive_back`, issue de la session ouverte
`nael_low_poly_with_animations_015.blend` : images 1–12, 30 i/s, lecture dans le jeu à 1,2×,
sans boucle. Aucune pose, clé ni courbe de l’action Blender n’a été modifiée.
L’origine temporelle du clip exporté est ramenée à zéro, sans changer les intervalles.
Fondu d’entrée de 0,04 s ; retour au repos en 0,12 s après la fin du clip.
Le déplacement et les collisions restent assurés par le contrôleur d’esquive.
Les esquives latérales et la charge conservent leur comportement simple.
Les treize autres clips, le maillage et le squelette sont conservés.
Export, sauvegardes et validation : `3D MODELS/MAIN CHARACTER/back_dodge_20261015/`.

## Esquives simples et charge — 15 octobre 2026

Double pression sur A/D : esquive gauche/droite ; S : recul ; W : charge.
Fenêtre de double pression : 0,25 s. Aucune touche supplémentaire.
Clic gauche : attaque inchangée. Les directions suivent la caméra.

À la demande de l’utilisateur, aucune nouvelle animation : Naël conserve sa pose
normale durant le déplacement rapide, puis reprend sa locomotion. Les quatre
essais d’animation ont été retirés du fichier 014 ouvert et de l’export du jeu.
Le modèle `nael.glb` a été restauré octet pour octet depuis sa sauvegarde.
Les essais restent séparément dans `dodge_update_20261015/animation_attempts.blend`.

Déplacement : environ 1,83 m pour les esquives et 2,24 m pour la charge,
impulsion sur 0,32 s ; manœuvre totale de 0,5 / 0,55 s. Délai entre départs :
0,65 s. Esquive protégée entre 0,07 et 0,27 s ; charge vulnérable.
Charge : 15 dégâts, une fois par ennemi, recul de 9 m/s amorti sur 0,22 s.
Murs, hauteur et collisions respectés. Impossible dans les airs, en nageant,
au repos, dans les menus, pendant une attaque ou la visée de boule de feu.
Les menus, la perte de focus, les dégâts hors protection et la réapparition
annulent la manœuvre. Paramètres dans `scripts/nael_dodge.gd`.

Tests : `tests/test_nael_dodge.gd`, `test_claw_combat.gd`,
`test_left_claw_combo.gd`. Sauvegardes et journaux hors du projet Godot :
`3D MODELS/MAIN CHARACTER/dodge_update_20261015/`.

## Griffe gauche puissante et enchaînements — 9 octobre 2026

Source : `Nael_Left_Hook_from_Guard` de `nael_low_poly_with_animations_009.blend`,
avec la correction des jambes. Clip Godot ajouté : `Nael_Claw_Left` (0,8 s,
lecture à 1,6×, sans boucle). Les dix clips existants et les données du modèle
restent identiques. L'export adapte l'origine, l'orientation et la hauteur du
bassin au personnage au sol ; il conserve le déplacement horizontal et les
poses des membres. La session Blender et son action originale ne sont pas modifiées.

Le premier clic donne la griffe normale (25 dégâts). Pendant une attaque,
les clics peuvent réserver une seule attaque suivante, valable 0,65 s.
À partir du deuxième coup enchaîné, le gauche a 35 % de chances de sortir ;
il est garanti au quatrième coup. Il inflige 50 dégâts, puis remet le compteur
à zéro. Une pause de plus de 0,65 s après la fin d'un coup termine l'enchaînement.
Le saut, les menus pendant une attaque et la réapparition annulent la réserve.
Les boules de feu ne participent pas à l'enchaînement.

Fondu d'entrée du gauche : 0,12 s ; retour au repos : 0,18 s.
Impact à 0,32 s du clip (suivant la pose et la vitesse de lecture), traînée
de `LeftHand` entre 0,12 et 0,38 s. La portée et les règles d'obstacle restent
celles de la griffe normale. Le déplacement du clip est visuel ; il ne déplace
pas la capsule physique du joueur.

Sauvegardes, export reproductible et captures Godot :
`3D MODELS/MAIN CHARACTER/left_claw_update_20261009/`.
Tests : `test_left_claw_combo.gd`, `test_claw_combat.gd`, `test_claw_trail.gd`.
Rendu : `render_left_claw.gd`.

## Remplacement de l'animation de vol plané — 30 septembre 2026

Action source : `Nael_Glide_Loop`, directement depuis la session Blender 3D active (`nael_low_poly_with_animations_008.blend`).
Nom stable dans Godot : `Nael_Glide` (61 images à 30 i/s, environ 2,03 s, boucle continue).
L'action a remplacé chirurgicalement l'ancien clip statique dans `nael.glb` :
- Les 9 autres animations (`Nael_Idle_Breathe`, `Nael_Walk`, `Nael_Run`, `Nael_Jump`, `Nael_Jump_InPlace`, `Nael_FrontFlip`, `Nael_FrontFlip_InPlace`, `Nael_Fall`, `Nael_Claw`), le maillage, les textures, le squelette à 24 os et les matériaux restent strictement identiques.
- Mouvement dynamique des membres ajouté (oscillations naturelles des bras et des jambes pendant le vol au lieu de la pose statique précédente).
- Sauvegarde avant modification : `3D MODELS/MAIN CHARACTER/glide_update_20260930/nael_before_glide_update_20260930.glb`.
- Validations passées avec succès : `test_glide_replacement.gd`, `test_fall_replacement.gd`, `test_nael_animations.gd`, `test_claw_combat.gd`.

## Ajout du coup de griffe — 16 septembre 2026

Action source : `coup de griffe_001`, dans `nael_low_poly_with_animations_006.blend`.
Nom stable dans Godot : `Nael_Claw` (20 images à 30 i/s, environ 0,67 s).
L'action a été ajoutée seule au fichier `nael.glb` existant : les neuf animations
précédentes, les données du modèle, les textures et le squelette sont conservés.
Le chemin et l'UID Godot restent identiques ; aucune référence de personnage à refaire.
La session Blender ouverte et les fichiers `.blend` n'ont pas été modifiés.

Clic gauche, au sol : Naël se tourne dans la direction de la caméra et donne un
coup de griffe. Impact à 45 % du mouvement, 25 dégâts, portée de 1,8 m et cône de
120 degrés devant lui. Un obstacle bloque le coup. Pas d'attaques empilées ni
d'attaque depuis l'inventaire. Saut, ouverture de l'inventaire et réapparition
annulent le coup en cours. Après Échap, le premier clic reprend seulement la souris.

Bandit : 100 PV, affichés après une blessure ; disparition au quatrième coup réussi.
Ses attaques, sa poursuite et le retour au camp sont conservés. Il réapparaît au
rechargement du monde ; aucune sauvegarde permanente des ennemis éliminés.

Sauvegardes avant modification et scripts d'export/import :
`3D MODELS/MAIN CHARACTER/claw_update_20260916/`, hors du projet Godot.
Continuer les sauvegardes Blender numérotées est possible ; intégrer les futures
animations dans le même export stable, après contrôle des noms d'os et des actions.
Éviter de remplacer aveuglément toutes les animations par celles d'une ancienne version.

Validations : `test_claw_combat.gd`, `test_nael_animations.gd`,
`test_fall_replacement.gd`, `test_bandit.gd`, `test_harvest_and_heal.gd`.
Essai graphique réel avec clics et riposte au camp : `claw_camp_validation.tscn`.

## Historique de l'intégration initiale

Source : 3D MODELS/MAIN CHARACTER/nael_low_poly_with_animations_003.blend.
Export : nael.glb, textures incluses, 24 os, échelle 0,1 à l’export (personnage environ 1,7 m).
Les actions originales sont conservées dans Blender. Seules les sept actions préparées sont exportées.

## Animations
- Nael_Idle_Breathe_Loop : respiration de 4 s, bras détendus le long du corps, coudes légèrement fléchis, mouvement du torse, des épaules et des mains ; pieds fixes. Ancienne action conservée dans Blender sous Nael_Idle_Breathe_PreRelax_Backup.
- Nael_Walk_Loop : marche existante rééchantillonnée sur 36 images et corrigée au sol.
- Nael_Run_Loop : course existante rééchantillonnée sur 24 images et corrigée au sol.
- Nael_Jump : saut créé avec anticipation et réception, 60 images.
- Nael_FrontFlip : salto avant créé, rotation de 360 degrés, regroupement puis réception, 60 images.
- Nael_Jump_InPlace / Nael_FrontFlip_InPlace : phase aérienne sans trajectoire verticale, pour le contrôleur physique Godot.

Godot reconnaît et retire le suffixe _Loop : Nael_Walk, Nael_Run, Nael_Idle_Breathe.
Le contrôleur joue FrontFlip_InPlace sur Espace. La translation et la hauteur viennent de CharacterBody3D.
WASD : marche ; Maj : course ; Espace : salto ; R : retour au départ.

La cape utilise les pondérations du squelette existant ; aucune simulation de tissu n’a été ajoutée.
Export limité à 8 influences par sommet, normalisées par l’exporteur pour Godot.

Validation : tests/test_nael_animations.gd et tests/test_playground.gd.
