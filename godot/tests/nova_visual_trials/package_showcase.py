from pathlib import Path
from shutil import copy2
from PIL import Image

source = Path(__file__).resolve().parent
out = source.parents[2] / 'screenshots' / 'Nova_couches_verticales_20261030'
out.mkdir(parents=True, exist_ok=True)
for name in ['showcase_clean.png', 'showcase_controls.png', 'layered_42.png', 'layered_62.png']:
    copy2(source / name, out / name)
frames = [Image.open(source / f'showcase_frame_{n:02d}.png').convert('RGB').resize((960, 540), Image.Resampling.LANCZOS) for n in range(34)]
for name, delay in [('showcase_animation.gif', 33), ('showcase_ralenti.gif', 65)]:
    frames[0].save(out / name, save_all=True, append_images=frames[1:], duration=[delay] * 33 + [650], loop=0, optimize=False)
print(out)
