# Relic of the Fallen Star — projet Godot

Le projet utilise **Godot 4.6.1** et le moteur de rendu **Compatibility (OpenGL)**. Après avoir récupéré les ressources avec Git LFS, importe [project.godot](project.godot) et appuie sur **F5**. Les étapes d’installation et les [commandes principales](../README.md#commandes-principales) figurent dans le README à la racine.

## Lancement et sauvegardes

**F5** ouvre le menu principal. **Nouvelle partie** démarre dans le monde jouable. **Charger une partie** reprend une sauvegarde existante. Une nouvelle partie réinitialise la progression en cours et conserve les sauvegardes déjà enregistrées.

En jeu, **Échap → Sauvegarder la partie** permet de nommer et d’enregistrer une sauvegarde sur disque. Le jeu les stocke dans `user://saves`, le dossier de sauvegarde propre au projet sur chaque machine. Le menu **Options → Commandes / Raccourcis clavier** présente les commandes de déplacement, de combat et de magie.

## Organisation

| Emplacement | Rôle |
| --- | --- |
| [scenes/main_menu.tscn](scenes/main_menu.tscn) | Scène de démarrage et menu principal |
| [scenes/world/open_world.tscn](scenes/world/open_world.tscn) | Monde jouable, dont la Forêt des lueurs |
| [scenes/interiors/](scenes/interiors/) | Intérieurs de la cabane et de la grotte |
| [scenes/player.tscn](scenes/player.tscn) et [scripts/player.gd](scripts/player.gd) | Personnage de Nael, déplacements, caméra et commandes de combat |
| [scripts/](scripts/) | Systèmes de jeu, dont l’inventaire, la progression, les quêtes et les sauvegardes |
| [assets/](assets/) et [shaders/](shaders/) | Modèles, textures, sons, interface et effets de rendu |
| [addons/godot_mcp/](addons/godot_mcp/) | Extension de développement fournie avec sa licence. Le jeu se lance sans serveur MCP |
| [tests/](tests/) | Scripts de vérification et scènes de test |

[scenes/forest_test.tscn](scenes/forest_test.tscn) correspond au prototype historique de la forêt. Le parcours de jeu actuel passe par le menu principal et `open_world.tscn`.

## Vérification locale

Depuis la racine du dépôt, remplace `godot` par le chemin de ton exécutable Godot 4.6.1 s’il est absent du `PATH`.

```sh
godot --headless --path godot --editor --import
godot --headless --path godot --script res://tests/test_save_system.gd
```

La première commande importe les ressources. Le test de sauvegarde crée une partie temporaire, vérifie la restauration de l’inventaire, de la progression et de l’état du joueur, puis supprime la sauvegarde de test.
