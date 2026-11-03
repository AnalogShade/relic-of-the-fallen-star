# Vegetation — première intégration

Source : `environments/plantes et roche assets pack/plantes et roche assets pack_002.blend`.
Les 15 GLB sont exportés individuellement à l'échelle de la scène Blender, origine au sol.

La scène `res://scenes/world/vegetation_first_pass.tscn` est instanciée dans `open_world.tscn`.
Elle contient les catégories HerbesCourtes, HerbesHautes, Fougeres, FeuillesLarges,
ArbresPlaines, ArbresMontagne (réservée) et TouffesRocheuses.

- 2 916 plantes : les 12 variantes en îlots dans les plaines occidentales,
  principalement x = -234 à -100, z = 20 à 111 ; densité décroissante vers la plage.
- 24 arbres : deux modèles, rotation aléatoire et échelle uniforme de 0,72 à 1,12.
- 6 touffes rocheuses : sur les abords de la grotte, hors du passage d'entrée.
- Collisions : une CapsuleShape3D par nouveau tronc, aucune collision de feuillage.
- Petites plantes : 223 MultiMesh par variante et cellule de 24 m, un matériau
  à couleurs de sommets par maillage, affichage jusqu'à 110 m, sans ombres portées.
- Les sols sont sondés physiquement ; les chemins du shader, le château,
  les obstacles physiques et les fortes pentes sont exclus des placements.

## Reproduire et vérifier

Depuis la racine du projet Godot, après import des GLB :

```text
godot --windowed --script res://tests/bake_vegetation.gd
godot --windowed res://tests/vegetation_preview.tscn
```

Le bake utilise la graine 15092026 et remplace uniquement la scène d'ajouts.
Un moteur de rendu actif est nécessaire pour enregistrer les buffers MultiMesh.
Le test vérifie les collisions primitives, le contact au sol et les buffers
d'instances, puis produit trois captures et `tests/vegetation_validation.json`.
Les placements détaillés sont enregistrés dans `tests/vegetation_placement.json`.
