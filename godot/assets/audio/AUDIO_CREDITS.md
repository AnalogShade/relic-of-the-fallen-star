# AUDIO CREDITS & INVENTAIRE SFX

Projet : Relic of the Fallen Star  
Mise à jour : 2026-09-20  
Moteur IA : **Stable Audio 3 (`small-sfx`)** déployé localement sur NVIDIA RTX 2060 (6 Go VRAM)  
Statut : 100% Domaine Public / Sans redevance / Utilisation commerciale libre  

---

## 1. Bruits de pas (Footsteps) — 3 Surfaces Dynamiques

### A. Pelouse & Clairières (`res://assets/audio/sfx/footsteps/grass/`)
- `step_grass_01.wav`, `step_grass_02.wav`, `step_grass_03.wav`
- **Génération :** Stable Audio 3 *small-sfx* (Prompt : *"crisp footstep on grass turf, nature recording, dry one-shot, isolated sound effect, 48khz"*).
- **Caractéristiques :** Impact feutré et amorti par la terre, froissement doux de brins d'herbe souples.
- **Format :** WAV PCM 16-bit, 48000 Hz, Mono, normalisé (-2 dBFS peak).

### B. Sentier & Gravier (`res://assets/audio/sfx/footsteps/gravel/`)
- `step_gravel_01.wav`, `step_gravel_02.wav`, `step_gravel_03.wav`
- **Génération :** Stable Audio 3 *small-sfx* (Prompt : *"crisp footstep on loose gravel and pebbles, dry crunch one-shot, isolated sound effect, 48khz"*).
- **Caractéristiques :** Assise pierreuse ferme avec micro-impacts stochastiques de cailloux et crissement de gravier.
- **Format :** WAV PCM 16-bit, 48000 Hz, Mono, normalisé (-2 dBFS peak).

### C. Sous-bois forestier / Brindilles & feuilles sèches (`res://assets/audio/sfx/footsteps/twigs/`)
- `step_twigs_01.wav`, `step_twigs_02.wav`, `step_twigs_03.wav`
- **Caractéristiques :** Impulsions nettes de fracture de brindilles (résonances bois 1.2–4.2 kHz) couplées au tassement d'aiguilles de pin.
- **Format :** WAV PCM 16-bit, 48000 Hz, Mono, sec.

---

## 2. Mouvements & Déplacements (`res://assets/audio/sfx/movement/`)

1. **`jump.wav`**
   - **Génération :** Stable Audio 3 *small-sfx* (Prompt : *"character jumping sound effect, quick clothing whoosh and athletic leap, isolated foley, 48khz"*).
   - Impulsion athlétique rapide : déplacement d'air et léger froissement textile au décollage (0.24s).
2. **`land_grass.wav`**
   - **Génération :** Stable Audio 3 *small-sfx* (Prompt : *"feet landing on lush grass turf, soft cushioned thud, isolated sound effect, 48khz"*).
   - Réception amortie dans l'herbe avec compression douce.
3. **`land_gravel.wav`**
   - **Génération :** Stable Audio 3 *small-sfx* (Prompt : *"heavy feet landing on gravel and loose dirt, crunch impact, isolated foley sound effect, 48khz"*).
   - Réception ferme avec dispersion de petits cailloux.
4. **`land_twigs.wav`**
   - Réception lourde au sol avec craquement d'impact de branches et tassement de terre forestière.

---

## 3. Combat Joueur & Ennemis (`res://assets/audio/sfx/combat/`)

### A. Attaque du Joueur (Griffes)
- **`claw_swipe_01.wav`, `claw_swipe_02.wav`, `claw_swipe_03.wav`**
  - **Génération :** Stable Audio 3 *small-sfx* (Prompt : *"TrackType: SFX, single sharp beast claw slash through the air, razor sharp talon swipe swoosh, crisp aggressive melee whoosh, 48khz isolated sound effect"*).
  - **Remplacement :** Remplace l'ancien son de boxeur cartoon (`mixkit-cartoon-punch-2149.wav` supprimé) ainsi que les premiers découpages trop abrupts.
  - **Calage & Acoustique :** Fente d'air vive et tranchante (0.55s) avec montée fluide et apex d'impact calé à la milliseconde près (`0.151s`, correspondant à l'apex de swing de l'animation Nael à vitesse x2), suivi d'une décroissance naturelle (decay de 0.4s sans coupure artificielle).
  - **Intégration :** Joué aléatoirement dans `player.gd` à volume rehaussé (-1.5 dB) avec micro-pitch aléatoire (0.97 - 1.03).

### B. Attaques des Ennemis (Sons Cohérents par Archétype)
1. **Bandits (`bandit_attack_01.wav`, `bandit_attack_02.wav`)**
   - **Génération :** Stable Audio 3 *small-sfx* (Prompt : *"aggressive martial melee punch swoosh, swift fist swing through air, visceral whoosh, isolated sound effect, 48khz"*).
   - **Intégration :** Joué en 3D spatiale (`AudioStreamPlayer3D`, portée 18m) dans `bandit.gd` au déclenchement du coup de poing.
2. **Golems (`golem_attack_01.wav`, `golem_attack_02.wav`)**
   - **Génération :** Stable Audio 3 *small-sfx* (Prompt : *"giant stone golem heavy swing, deep rumbling rock whoosh, low frequency earthy slam, isolated sound effect, 48khz"*).
   - **Intégration :** Joué en 3D spatiale (`AudioStreamPlayer3D`, portée 25m) dans `golem.gd` lors de l'attaque lourde.
3. **Araignées géantes (`spider_attack_01.wav`, `spider_attack_02.wav`)**
   - **Génération :** Stable Audio 3 *small-sfx* (Prompt : *"creepy giant insect mandible snap, chitinous claw strike, venomous spider attack hiss and snap, isolated sound effect, 48khz"*).
   - **Intégration :** Joué en 3D spatiale (`AudioStreamPlayer3D`, portée 22m) dans `araignee.gd` lors du bond d'attaque.

---

## 4. Ambiance Environnementale (`res://assets/audio/ambience/`)

1. **`wind_trees_loop.wav`**
   - **Caractéristiques :** Boucle de 30.0s en stéréo décorrélée. Brise continue et houle naturelle dans les cimes forestières.
   - **Diffusion :** En tâche de fond continue dans `open_world.gd` via `WindAmbiencePlayer` (-16 dB).

---

## 5. Pipeline & Outils de Génération

- **Dépôt :** `C:\Users\Utilisateur\Documents\Dev\stable-audio-3`
- **Modèle :** `small-sfx` (conditionneur texte `t5gemma-b-b-ul2`)
- **Mode d'inférence :** PyTorch 2.7.1 + CUDA 12.6 en précision FP32 (`model_half=False`) pour éliminer tout bug de saturation/bruit blanc sur architecture NVIDIA Turing (RTX 2060 6 Go).
- **Scripts autonomes :**
  - Génération par lot : `python generate_relic_sfx_pack.py`
  - Générateur à la demande : `generate_sfx.bat "<prompt>" <nom_fichier>`
