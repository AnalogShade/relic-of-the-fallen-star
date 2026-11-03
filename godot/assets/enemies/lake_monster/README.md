# Dévoreur du lac — prototype jouable

**Version active : Crystalmaw V003.** Voir `README_V003.md` pour l'intégration actuelle : nouveau modèle texturé, quatre animations, marche lente et retour au lac. La V3 est désormais utilisée dans le monde principal.

Essai actuel : F9 active/désactive le feu, F8 recommence en conservant ce choix. La gueule naturelle est vulnérable sans sphère orange. Le monstre a 320 PV : quatre boules de feu dans la gueule, aucun dégât sur le corps. Le tir ennemi possède un halo et une traînée cyan/violette. Ces réglages remplacent les valeurs historiques ci-dessous.

Les sections suivantes conservent le compte rendu historique du prototype V002.

Intégré au monde principal le 20 octobre 2026, à la demande de l'utilisateur. Modèle de travail remplaçable : `lake_monster_prototype.glb`, exporté de Blender V002 via MCP. Le studio, le plan d'eau de présentation et le projectile Blender sont exclus. Export optimisé en un maillage, 17 surfaces de matériaux, environ 5 400 triangles, squelette de 14 os et trois animations : `Lake_Idle`, `Lake_Emerge`, `Lake_Spit`.

## Essai immédiat

Lancer `3D MODELS/monstre lac/Voir le monstre du lac.cmd` : point de départ près de la rive, monstre encore caché. Avancer vers l'eau pour déclencher le surgissement. F8 remet l'essai à zéro. F9 ajoute volontairement le pouvoir de feu **uniquement dans cette session de test**; clic droit maintenu pour viser, relâché pour lancer. R esquive. Le point de départ normal et les règles d'acquisition de la relique du jeu principal sont conservés.

Le monde principal crée le boss dans `open_world.gd`, uniquement à l'exécution. Position : (7, 5.5, -213). Modèle à 85 % de l'échelle Blender, moitié inférieure sous l'eau. Distance de déclenchement : 27 m depuis le centre du lac. Au-delà de 48 m, le monstre replonge, supprime ses projectiles et récupère ses PV; une nouvelle approche relance l'affrontement.

## Comportement

- Surgissement animé d'environ 4 s avec deux gerbes d'eau et des ondes, puis veille de 1,4 s.
- Attaque de 4,5 s : préparation visible, orientation et cible verrouillées à 1,65 s, projectile à 2,33 s, puis recul et récupération. La cible est figée avant le départ pour laisser une possibilité d'esquive.
- Projectile de 13 m/s, durée maximale de 5 s, collision balayée contre joueur et décor, dégâts de 60 PV. Deux coups tuent Naël avec ses 100 PV actuels; son esquive et son invulnérabilité après impact restent respectées.
- Boss : 800 PV. Griffes et armes ordinaires sans effet. Seule une boule de feu qui atteint la zone de la gueule pendant la fenêtre 0,95–3 s de l'attaque inflige des dégâts, avec multiplicateur x2 : 80 par boule de feu actuelle, soit 10 impacts réussis.
- Contact à moins de 6,5 m : 60 dégâts avec délai de 1,5 s, pour décourager de traverser le corps au lieu de jouer depuis les berges.
- Défaite : immersion, collisions désactivées, suppression des tirs et drapeau `story/lake_monster_defeated` dans `Inventory.collected`, conservé par le système de sauvegarde existant. Aucune récompense définitive inventée.

Les éclaboussures dérivent de `water_splash.gd`, le même effet que les pas de Naël. Version amplifiée séparée : gouttelettes en couronne, ondes, durée plus longue et vérification de la surface réelle de l'eau. Les pas du joueur sont inchangés. Aucun nouvel audio n'est généré.

## Fichiers et validation

- `scripts/lake_monster.gd` : états, animation, visée, dégâts, disparition et persistance.
- `scripts/lake_monster_projectile.gd` : projectile et collision continue.
- `scripts/lake_monster_splash.gd` : variation de l'effet d'eau existant.
- `tests/test_lake_monster.gd` : approche, import, éclaboussures, types de dégâts, vraie boule de feu, collision du tir ennemi, retraite et persistance.
- `tests/capture_lake_monster.gd` : captures dans le monde réel, monstre caché, surgissement, surface et tir.
- `tests/lake_monster_preview.gd` et `tests/lake_monster_preview_controls.gd` : entrée de test et raccourcis temporaires.

Le MCP Godot était indisponible; import, parsing, tests et vues du jeu sont exécutés avec Godot 4.6.1 local. Rapports dans `diagnostics/lake_monster_*.log`, captures dans `godot/tests/lake_monster_*.png`.

Validation : **20 contrôles réussis**, dont une boule de feu en vol contre la hitbox réelle, un projectile ennemi contre Naël et l'absence du boss après recréation avec son drapeau de victoire. Les captures confirment l'échelle, la moitié immergée, la charge, les gouttelettes et le projectile. Les lancements de test signalent encore des ressources en cours d'utilisation à la fermeture de Godot, également observées pendant la capture du monde sans monstre; aucun échec de script n'est relevé pendant ces scénarios. Le nettoyage général de fermeture du projet n'est pas modifié.

Il s'agit d'un prototype : IA stationnaire, corps protégé par un collider simplifié et hitbox de gueule suivant l'os de tête. Le modèle peut être remplacé en gardant les trois clips ou en ajustant leur association et la position de la gueule. La mise en scène, la cadence et la difficulté restent à régler avec les essais du joueur.
