# Eau intégrée au jeu : ruisseau et lac

Le nouveau rendu est actif dans la scène principale : ruisseau de la forêt, prolongements nord et sud, source et exutoire de l'oasis. Le réservoir de l'oasis utilise `lake_water.gdshader`, une variante plus calme avec la même palette et transparence. Les douves du château utilisent également la variante calme du lac. L'océan garde son matériau. Aucun maillage importé, collision, terrain, fichier Blender ou système de pêche n'est modifié. `water.gdshader` et `oasis_water.gdshader` restent intacts.

L'objet décoratif Blender `Ripples` est masqué par les scripts d'environnement : ses traits blancs fixes ne sont plus nécessaires avec les reflets animés. Le GLB original reste intact. Cette suppression visuelle reste active même si les anciens matériaux d'eau sont restaurés.

Ouvrir `preview.tscn` dans Godot et lancer cette scène (F6). La touche **B** compare les matériaux sous le même angle. Le nouveau matériau est aussi actif dans le jeu après un redémarrage de la scène.

Pour restaurer l'ancien rendu : passer `const ENABLED := true` à `false` dans `scripts/stream_water.gd`, puis relancer la scène. Ou exécuter `restore_original.ps1` dans ce dossier. Pour réactiver, remettre `true`.

Copies de sécurité : `environment.gd.original`, `open_world.gd.original` et `oasis_water.gdshader.original`. La restauration par le commutateur désactive les nouveaux matériaux du ruisseau et du lac ensemble et conserve les éventuelles modifications ultérieures du jeu.

La direction du courant est dérivée des berges du maillage existant, par sections suivant son axe Z. Le shader est prévu pour le rendu Compatibility de ce projet. Il ajoute des rides animées, une transparence et une teinte selon la profondeur, et un peu d'écume visuelle près des berges. Il ne simule pas physiquement les fluides, le contournement individuel des rochers ou les éclaboussures du personnage. Pas de réfraction pour cette première version.

`before.png`, `after.png` et `after_motion.png` sont des captures du même point de vue. `capture.gd` permet de les régénérer avec Godot en mode graphique.

`lake_before.png` et `lake_integrated.png` montrent le lac dans la scène principale. `check_integrated_water.gd` vérifie les affectations des matériaux et capture ces vues.
