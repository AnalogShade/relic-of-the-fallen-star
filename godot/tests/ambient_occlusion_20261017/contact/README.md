# Occlusion de contact — réglage actuel

17 octobre 2026. Rayon 0,45 au lieu de 1,4 ; intensité 2,7, soit deux fois
l'intensité de départ (1,35). L'effet est limité aux distances plus courtes.
Le flou global est désactivé : aucun CanvasLayer de lissage n'est instancié.
Le shader de flou est conservé comme fichier inactif pour référence.

Les deux scènes de forêt et le singleton `ambient_occlusion.gd` utilisent les
mêmes valeurs. Le singleton applique aussi ces valeurs aux intérieurs.
Rendu Compatibility conservé ; aucun changement de palette ou de shaders d'eau.

Le rayon règle la distance prise en compte par le SSAO ; l'intensité règle
l'assombrissement. Le SSAO de Compatibility reste une approximation à partir
de l'image : réduire son rayon ne constitue pas une classification géométrique
parfaite des coins et des angles.

Validation : lancement du monde principal, captures avec/sans AO dans ce dossier.
Les captures de cabane peuvent correspondre à l'essai intermédiaire rayon 0,35 /
intensité 4,05. Les anciens dossiers `strong/` décrivent les étapes précédentes.
