# Réglage renforcé et lissage final

Configuration livrée : Compatibility, occlusion native d'intensité 4,05
(3 × le premier réglage 1,35), rayon 1,4. Puis une passe indépendante de
lissage gaussien 5×5, rayon 0,65 pixel et mélange 20 %, appliquée à l'image
3D complète, eau incluse. L'interface reste nette, sur des couches supérieures.
Ce filtre adoucit aussi légèrement les petits détails des textures et les
contours ; il ne modifie ni la palette ni l'exposition.

Fichiers : `scripts/ambient_occlusion.gd`, `shaders/soft_image_filter.gdshader`,
les deux scènes de forêt. Aucun passage permanent à Forward+. Les shaders
de la rivière et du lac sont restaurés identiques aux sauvegardes initiales.

Le SSAO simplifié de Compatibility ne permet que rayon et intensité ;
les options de flou/nettété natives ne sont pas effectives dans ce moteur.
La passe additionnelle est donc un shader de lissage séparé, plutôt que
l'option FXAA intégrée (non prise en charge par Compatibility dans Godot 4.6).

Validation : captures du monde principal, de la cabane et de la grotte,
AO/lissage actifs au démarrage, pas d'erreur de script ou de shader. Les
rapports et journaux `final_*` décrivent le résultat livré ; les journaux
`forward_*` et `smooth_*` sont des essais intermédiaires non conservés.
Les captures finales `_on.png` sont comparées aux captures `_off.png`.

Dans la vue extérieure figée testée : médiane 7,871 ms sans AO/lissage,
8,418 ms avec les deux, soit +0,547 ms à 1920×1080 sur RTX 2060.
Ce n'est pas une mesure garantie pour toutes les situations du jeu.
Les messages de textures non libérées à la fermeture sont également présents
avant cette modification (voir les précédents journaux de capture).

