# Maelor — figurant herboriste

Source : `3D MODELS/Maelor/Maelor_lowpoly_optimise_003.blend`, session ouverte,
export des seuls Maelor_LowPoly, Baton_LowPoly et Maelor_armature.
Le fichier Blender et sa pose courante ont été préservés.
Le cycle `cycle_marche_001` est nommé `Animation` par l'export ACTIVE_ACTIONS.

La scène `res://scenes/herbalist.tscn` est intégrée au monde principal.
Capsule de rayon 0,32 m, hauteur 1,75 m, couche 3 (valeur 4), masque monde/joueur.
Elle ne possède aucun collider issu du mesh et n'appartient pas aux ennemis.

Ronde ouverte de 173,41 m entre la cour de sa maison et les abords de la caverne,
avec demi-tour à chaque extrémité (environ 6 min 48 s pour un aller-retour).
La traversée utilise le passage peu profond au sud, vers z = 32, loin des roches.
Au début, il part près de la clairière de Naël et se dirige vers sa maison.
Le personnage marche, cède le passage et rebrousse chemin après un blocage durable.
Un « ! » doré, orienté vers la caméra et animé verticalement, indique la première
conversation disponible. Il disparaît pendant le dialogue et après acceptation
de la quête. Il respecte l'occlusion du décor et la distance d'affichage du PNJ.
Il n'a pas d'animation de cueillette : le cycle existant est conservé.
La route est stockée dans maelor_route.tres, sans recherche de chemin en jeu.
Pour modifier la tournée après changement du terrain, ajuster les points d'intérêt
dans tests/bake_herbalist_route.gd, rebâtir puis lancer tests/test_herbalist.gd.

À plus de 56 m du joueur, rendu, animation et capsule sont désactivés ; la tournée
continue virtuellement à 2 Hz. Réactivation à moins de 48 m, avec hystérésis.
Les vérifications de distance sont espacées de 0,5 s et décalées entre instances.
Meshes et matériaux sont partagés, avec les LOD générés par l'importeur Godot.
Une foule visible reste à profiler sur le matériel cible : la capsule seule ne
supprime pas le coût du skinning, des ombres et des textures.

Validation : maison, caverne, puis maison, absence de blocage/chute, présence
d'une seule capsule, passage du joueur, poursuite à distance et réveil du PNJ.
Rapport : tests/herbalist_report.json. Aperçu : tests/herbalist_preview.png.
