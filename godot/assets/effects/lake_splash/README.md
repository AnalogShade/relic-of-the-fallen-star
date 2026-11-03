# Éclaboussures du monstre du lac

`splash_fan_rgba.png` : image RGBA 1254 × 1254, véritable transparence, générée avec l'outil ImageGen intégré le 20 octobre 2026. Aucune retouche de l'image après génération; copie de l'original conservé dans le dossier generated_images de Codex.

Utilisation : `scripts/lake_monster_splash.gd`, douze plans pour une grande gerbe et quatre pour une petite, regroupés dans un MultiMesh. Le shader `shaders/lake_splash_billboard.gdshader` oriente les plans vers la caméra, varie leur taille, leur délai et leur orientation horizontale, puis les fait disparaître. Un anneau accompagne le contact sur l'eau. Les matériaux passent après l'eau transparente tout en conservant le test de profondeur contre les objets solides. Aucun calcul de collision ni simulation de gouttes 3D dans cet effet. Durée : 2,3 s / 1,15 s.

Les effets sont utilisés pour le surgissement, les mouvements, le retour sous l'eau et les impacts des projectiles dans l'eau. Le modèle du projectile lui-même reste inchangé.

## Prompt exact transmis à ImageGen

Create ONE production-ready game VFX sprite texture for an upright water splash billboard, square RGBA with REAL alpha transparency, no background. A single broad dramatic water splash fan erupting upward from a narrow low central base, curved branching white foamy spray fingers, many fine scattered droplets around the upper and side silhouette. Stylized semi-realistic hand-painted fantasy game effect, pale icy cyan water with white highlights, soft partly transparent translucent liquid interiors, crisp foam edges with gentle alpha falloff; irregular organic shape, moderate airy coverage with transparent gaps. Front view, flat 2D sprite, no perspective ground, no lake, no horizon, no shadow, no container, no text, no borders, no glow cloud. Splash spans 85% of frame, leave transparent padding at all edges; base at bottom center. Designed to read clearly on small camera-facing quads against turquoise lake water. Single isolated splash only, not a sprite sheet. Preserve genuine transparent alpha.
