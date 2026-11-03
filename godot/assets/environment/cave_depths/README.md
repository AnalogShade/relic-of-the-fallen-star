# Intégration — Descente des échos

Accès : forêt → grotte existante (`cave_room.tscn`) → ouverture au fond → confirmation → `cave_depths.tscn`.

L'ancien intérieur conserve sa voûte, son sol et ses accessoires. Son mur du fond est masqué dans l'instance et remplacé par une ouverture. Le GLB original n'est pas modifié. Le coffre et l'Éclat du Premier Écho sont désormais placés dans la sixième salle, à la fin de la descente. Leurs identifiants de collecte restent inchangés : un objet déjà pris ne réapparaît pas.

Le retour près du portique de départ restaure la même salle d'entrée. Celle-ci permet toujours de ressortir dans la forêt, dont l'instance et la position du joueur sont conservées. Annuler une invitation n'en ouvre pas immédiatement une nouvelle ; F permet de la redemander, ou il suffit de s'éloigner puis de revenir.

## Collisions

- Dalles convexes simples pour les six paliers, avec retrait du raccord descendant.
- Cinq prismes inclinés pour les rampes, avec petit recouvrement aux raccords.
- Cylindres pour les grandes formations rocheuses ; les petits gravats sont décoratifs.
- 119 boîtes invisibles suivant le contour extérieur unifié, sans couper les passages entre les salles.
- Les barrières utilisent le masque 4 déjà pris en compte par le personnage ; la caméra les ignore. Elles montent bien au-dessus de la hauteur de saut.
- 196 formes au total, capsule du joueur et coffre inclus ; aucun collider concave issu du maillage détaillé.

Les flaques sont peu profondes et restent traversables. Le modèle est importé en 50 maillages et 62 surfaces de matériaux, avec LOD d'import Godot. Les petites lumières locales n'ont pas d'ombres et s'estompent à distance. Aucun système d'ennemis ou de navigation n'est ajouté à cette étape.

## Contrôles

`res://tests/cave_depths_validation.tscn` (également accessible par l'ancien point d'entrée `cave_validation.tscn`) vérifie 30 points : dialogue accepter/annuler, sol et mouvement réel sur les cinq rampes, 465 sondages de sol, périmètre à trois hauteurs, saut/sprint au bord, coffre, inventaire plein, absence de duplication, revisite et aller-retour complet depuis la forêt.

Résultats : `res://tests/cave_depths_report.json`. Les captures `res://tests/depths_*.png` montrent le dialogue, l'arrivée et le coffre. Les originaux des scripts modifiés sont conservés hors de Godot dans `environments/grotte1_interieur/integration_backup`.
