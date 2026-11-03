# Forêt des lueurs — prototype Godot

## Écran d’accueil

Le lancement (F5) ouvre désormais `scenes/main_menu.tscn` : paysage 3D avec caméra lente, titre médiéval, étoile et parchemin orné. Souris, flèches et Entrée permettent de choisir **Nouvelle partie**, **Charger une partie**, **Options** ou **Quitter**. Les options audio et les commandes réutilisent le menu existant. Une nouvelle partie réinitialise la progression de la session et conserve les sauvegardes sur disque.

Le décor d’accueil utilise une copie visuelle du monde, débarrassée de ses acteurs, scripts de jeu, collisions et interfaces. Les polices Cinzel sont fournies avec leurs licences OFL dans `assets/ui/title/`.

Validation : `godot --headless --path godot --script res://tests/test_main_menu.gd` depuis la racine du dépôt. Sans `--headless`, ce test enregistre également trois aperçus PNG dans `godot/tests/`.

Projet créé avec **Godot 4.6.1**, moteur de rendu Compatibility (OpenGL), testé sur la RTX 2060 de ce poste.

## Ouvrir et jouer

Dans le gestionnaire de projets Godot : **Importer** → sélectionner `project.godot` dans ce dossier → ouvrir le projet. Appuyer sur **F5** pour lancer la scène principale. Aucune extension externe ni installation Blender n'est nécessaire pour jouer.

| Contrôle | Action |
|---|---|
| W, A, S, D | Déplacement par rapport à l'orientation de la caméra |
| Espace | Saut |
| Souris | Orbite de caméra à la troisième personne |
| Molette | Distance de caméra |
| Maj | Course |
| Échap | Libérer la souris |
| Clic gauche | Reprendre la caméra |
| R | Revenir au départ |

Les touches utilisent leur position physique WASD. Le cube revient automatiquement au départ s'il tombe hors du décor ou dépasse les limites de la zone de test. La rivière est peu profonde : on marche sur son lit ; la nage n'est pas implémentée.

## Organisation

- `scenes/forest_test.tscn` : scène principale, décor importé, ciel, lumières et interface.
- `scenes/player.tscn` : cube, collision et caméra avec SpringArm3D.
- `scripts/player.gd` : déplacement, saut avec petite tolérance de bord et de saisie, caméra, réapparition.
- `assets/environment/forest.glb` : export glTF 2.0 du décor Blender.
- `shaders/` : sol procédural et eau animée propres à Godot.
- `addons/godot_mcp/` : extension MCP déjà disponible sur ce poste, copiée avec sa licence pour permettre de poursuivre le travail. Le serveur n'est pas nécessaire au jeu.
- `tests/test_playground.gd` : vérification du contrôleur et des collisions.

## Conservation de l'original

Le fichier `../environments/foret_des_lueurs/Foret_des_lueurs.blend` est intact. Son SHA-256 avant conversion est `3B307F857377911E65E4D40DDD3C8FE45F744809B20DC42E5AAAB926CDDBC730`.

La copie adaptée est `../environments/foret_des_lueurs/export/Foret_des_lueurs_game.blend`. Elle simplifie les matériaux pour glTF, retire les volumes et couronnes masqués ainsi que la subdivision du terrain, applique les petits biseaux des pierres, et regroupe les objets statiques en dix maillages. Les suffixes `-col` produisent les collisions du terrain, du bois, des roches et du sanctuaire à l'importation Godot.

Le sol, les reflets de l'eau, la brume et la lumière sont adaptés dans Godot : le résultat n'est pas une reproduction exacte du rendu Cycles. La scène reste un prototype, sans optimisation LOD ou système de nage.

## Réexporter

Pour repartir du décor source, recopier l'original vers `Foret_des_lueurs_game.blend`, puis exécuter Blender en arrière-plan **sur cette copie** avec le script `../environments/foret_des_lueurs/export/export_godot.py`. Le script réécrit la copie et `assets/environment/forest.glb`. Ne pas exécuter ce script dans le fichier original. Godot réimporte le GLB ; le personnage et la scène de jeu restent séparés.

## Vérification

Depuis ce dossier, avec l'exécutable Godot 4.6 :

```text
godot --headless --editor --import
godot --headless --fixed-fps 60 --script res://tests/test_playground.gd
godot --fixed-fps 60 --script res://tests/test_playground.gd
```

La dernière commande teste aussi la souris et enregistre une capture dans `tests/godot_playground.png`, puis ferme sa fenêtre automatiquement.

Références : [import GLB](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html) et [caméra SpringArm3D](https://docs.godotengine.org/en/stable/tutorials/3d/spring_arm.html).
