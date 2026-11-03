> Effet retiré à la demande de l’utilisateur. Aucun autoload AO ou filtre de lissage actif ; paramètres SSAO retirés des scènes. Historique des essais uniquement.

> Réglage actuel : `contact/README.md` (rayon court, sans flou global).

> Mise à jour : réglage renforcé avec passe de lissage indépendante dans `strong/README.md`. Les paramètres et mesures ci-dessous décrivent la première version.

# Occlusion ambiante globale — 17 octobre 2026

SSAO actif au démarrage, pour tous les personnages et décors opaques éclairés
par l'environnement. Les particules lumineuses et matériaux volontairement
non éclairés conservent leur rendu.

Moteur conservé : Compatibility, Godot 4.6.1, RTX 2060. Le test visuel confirme
que le SSAO fonctionne dans cette version avec ce moteur ; Forward+ n'est
pas nécessaire pour cette modification.

- `res://scripts/ambient_occlusion.gd`, autoload `AmbientOcclusion` : configure
  les WorldEnvironment ajoutés au jeu, y compris ceux construits à l'entrée
  dans la cabane et les grottes. Aucun traitement de rendu par image en script.
- `forest_test.tscn` et `experiments/arbres_20261014/playable_forest.tscn` :
  mêmes valeurs enregistrées pour le monde principal et l'aperçu dans l'éditeur.
- Rayon 1,1 m ; intensité 1,35 ; puissance 1,25 ; détail 0,35 ; influence sur
  la lumière directe 0,12 ; netteté 0,95. Conserver ces valeurs synchronisées
  entre les deux ressources de scène et le script pour les futurs réglages.
- Éclairage, brouillard, eau, modèle du personnage et physique conservés.

## Vérifications

Le script `capture.gd` lance la scène réelle, vérifie que son environnement
est actif avant tout ajustement de test, fige la simulation, puis capture
la même caméra avec et sans effet. Validation du monde principal avec les
arbres intégrés, de la cabane, de la grotte et des profondeurs : les quatre
rapports indiquent `initially_enabled: true`. Captures `_off.png` / `_on.png`.
Aucune erreur de script ou de compilation de shader observée pendant ces tests.

Sur la vue extérieure à 1920×1080, sans VSync, une exécution isolée donne
7,681 ms sans effet et 7,824 ms avec effet (médiane sur 60 images, écart
0,143 ms). Cette mesure concerne une vue figée et cette machine ; elle ne
constitue pas une garantie de débit dans tout le monde. Les autres mesures
sont aussi dans les rapports JSON.

Le monde signale deux textures OpenGL non libérées et des instances restantes
à la fermeture du processus de capture ; ces messages sont déjà présents dans
les captures antérieures à l'activation globale. Ils ne sont pas des erreurs
de shader SSAO. Une grotte signale aussi des ressources restantes à la fermeture.

Lancer une nouvelle partie pour charger l'autoload. Les sauvegardes des trois
fichiers modifiés sont dans `before/`, exclu de l'import via `.gdignore`.

Commande : Godot `--path godot --script
res://tests/ambient_occlusion_20261017/capture.gd --resolution 1280x720
--windowed --disable-vsync`. Le réglage plein écran du projet produit une
capture 1920×1080 sur la machine testée. Pour les intérieurs, ajouter
`-- --scene=res://scenes/interiors/cabin_room.tscn` (ou cave_room/cave_depths).
