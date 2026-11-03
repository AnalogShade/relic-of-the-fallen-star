# Inventaire, récolte et pêche — Forêt des lueurs 7

Version de base jouable dans `scenes/world/open_world.tscn` (F5).

- **I** : ouvrir ou fermer le sac. **Échap** le ferme aussi.
- **F** : interaction la plus proche, affichée à l’écran (porte, récolte, outil ou pêche).
- Les quatre colonies de la forêt originale donnent chacune six champignons et disparaissent après récolte.
- La canne se trouve sur le mur du fond de la cabane, au-dessus de la petite table, entre le fauteuil et le foyer.
- Dans le sac, cliquer sur la canne dans **Équipement** pour l’équiper ; cliquer à nouveau pour la ranger.
- Canne équipée, approcher la berge du ruisseau original. **F** lance la ligne ; attendre « Ça mord ! », puis appuyer sur **F** dans les deux secondes pour recevoir une truite.
- Marcher, ouvrir l’inventaire ou ranger la canne interrompt la pêche. **F** pendant l’attente annule aussi. Un sac plein relâche le poisson.

Le sac comprend 24 cases de ressources (99 unités par pile) et 6 cases d’équipement. L’inventaire, les récoltes et la canne équipée sont conservés entre la forêt et la cabane pendant la partie. **Arrêter puis relancer le jeu réinitialise cette version** : pas encore de sauvegarde sur disque.

La canne est attachée à la main animée. La posture de pêche, l’animation de lancer et les poissons 3D nageant dans l’eau restent à créer. Le système actuel utilise un flotteur, une ligne et une fenêtre de capture. La pêche concerne le ruisseau de la forêt originale.

## Fichiers

- `scripts/inventory.gd` : état partagé, empilement, équipement et sélection unique des interactions.
- `scripts/inventory_ui.gd` : grille, icônes, descriptions et messages.
- `scripts/collectible.gd` : objet cueillable avec identifiant stable, quantité et contrôle de visibilité.
- `scripts/harvest_world.gd` : remplace uniquement les surfaces de champignons du décor par quatre colonies indépendantes.
- `scripts/held_equipment.gd` : canne attachée à la main de Naël.
- `scripts/stream_fishing.gd` : pêche sur le véritable maillage du ruisseau.
- `assets/items/` : modèles exportés depuis Blender.
- `tests/inventory_validation.tscn` : tests du parcours récolte → cabane → équipement → pêche, avec captures et rapport JSON.

Le travail Blender est enregistré dans `environments/foret_des_lueurs/Foret_des_lueurs7.blend`, collection « 15 • Récolte et équipement ». L’objet original des champignons est conservé masqué. Le script `inventory_assets.py` documente la création initiale ; son garde-fou interdit de recréer accidentellement les mêmes objets.

Les scripts existants modifiés et les réglages initiaux sont copiés dans `backups/inventory_before/` (ignoré par Godot).

## Prochains objets possibles

- **Baies sauvages** : nourriture et recettes simples.
- **Herbes aromatiques** : cuisine ou potions.
- **Brindilles et résine** : fabrication et entretien du feu.
- **Vers de terre** : appâts pour la pêche.
- **Fragments d’étoile** : ressource rare liée au thème du jeu.

Pour ajouter une ressource : définir son nom, son icône et sa description dans `Inventory.ITEMS`, puis placer un `collectible.gd` avec un `pickup_id` unique et son modèle enfant. Les autres outils nécessitent leur propre comportement d’équipement et d’utilisation.
