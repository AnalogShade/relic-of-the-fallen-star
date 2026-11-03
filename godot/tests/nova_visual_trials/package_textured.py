from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import sys

source = Path(__file__).resolve().parent
out = source.parents[2] / 'screenshots' / (sys.argv[1] if len(sys.argv) > 1 else 'Nova_texture_alpha_20261030')
out.mkdir(parents=True, exist_ok=True)
font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 24)
variants = [('reference', 'A · Originale'), ('textured', 'B · Une couche + rotation'), ('layered', 'C · Trois étages + aura')]
sheet = Image.new('RGB', (1920, 720), '#13232e')
draw = ImageDraw.Draw(sheet)
for row, moment in enumerate([42, 62]):
    for col, (key, label) in enumerate(variants):
        x, y = col * 640, row * 360
        draw.text((x + 15, y + 10), f'{label}   ({moment / 100:.2f} s)', fill='#b6f9e9', font=font)
        pic = Image.open(source / f'{key}_{moment}.png').convert('RGB')
        pic = pic.crop((120, 210, 1160, 690)).resize((640, 310), Image.Resampling.LANCZOS)
        sheet.paste(pic, (x, y + 50))
sheet.save(out / 'comparaison.png')
frames = []
for n in range(33):
    # Full-size final effect, with only the test UI cropped away.
    pic = Image.open(source / f'layered_frame_{n:02d}.png').convert('RGB')
    frame = Image.new('RGB', (1040, 540), '#13232e')
    ImageDraw.Draw(frame).text((15, 8), 'NOVA · Texture alpha, trois couches, rotation et aura', font=font, fill='#b6f9e9')
    frame.paste(pic.crop((120, 180, 1160, 680)), (0, 40))
    frames.append(frame)
for name, duration in [('nova_animee.gif', 33), ('nova_ralentie.gif', 65)]:
    frames[0].save(out / name, save_all=True, append_images=frames[1:], duration=[duration] * 32 + [600], loop=0, optimize=False)
Image.open(source / 'layered_42.png').save(out / 'nova_finale.png')
for moment in [22, 42, 62]:
    p = source / f'world_{moment}.png'
    if p.exists(): Image.open(p).save(out / f'nova_dans_le_jeu_{moment}.png')
print(out)
