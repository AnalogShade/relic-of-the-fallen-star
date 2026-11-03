# Rochers de Blender

Bibliothèque de 31 modèles provenant de `environments/DIVERS ROCHES/DIVERS ROCHES_002.blend` : 15 pierres nues et 16 pierres moussues. Les copies exportées ont une origine au sol, deux matériaux partagés et des textures limitées à 2K (1K pour les cartes de données).

Le monde utilise `scripts/rock_replacements.gd`, appelé par `open_world.gd` après le dégagement des sentiers. Les emplacements et collisions sont précalculés dans `scenes/world/rocks_blender_replacements.tscn` : 630 pierres, 29 variantes utilisées et 182 lots MultiMesh. Les collisions sont regroupées par région. Chaque pierre possède une forme convexe simplifiée à 26 points ; aucune collision triangulée n'est construite pour les nouvelles pierres.

`replacement_sources.json` identifie les groupes importés à masquer ou à remplacer partiellement. Les grands blocs conservés utilisent les ressources du dossier `retained/`. Les GLB originaux restent inchangés. Les murs du sanctuaire, les bâtiments, la caverne, les formations monumentales et les modèles spéciaux déjà texturés ne font pas partie de ce remplacement.

Pour reconstruire, utiliser les scripts dans `diagnostics/rock_replacement_20261024/` à la racine du projet :

1. Exécuter `export_rocks.py` dans Blender avec le fichier source ouvert.
2. Laisser Godot importer `roches_bibliotheque.glb`.
3. Exécuter `bake.gd` avec Godot en mode fenêtré (un moteur de rendu actif est nécessaire pour enregistrer les buffers MultiMesh).
4. Exécuter `validate.gd`, `validate_paths.gd` et `tests/test_stream_bank_movement.gd`.

Le rapport de placement, les correspondances de sources et les images de vérification se trouvent dans le même dossier de diagnostics.
