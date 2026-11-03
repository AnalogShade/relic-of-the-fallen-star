from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

source = Path(__file__).resolve().parent
out = source.parents[2] / 'screenshots' / 'Nova_variantes_20261030'
out.mkdir(parents=True, exist_ok=True)
font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 23)
small = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 18)
variants = [('original', 'A · Effet actuel'), ('soft', 'B · Halo diffus / Fresnel adouci'), ('motion', 'C · Halo diffus + traînée')]
sheet = Image.new('RGB', (1920, 724), '#13232e')
draw = ImageDraw.Draw(sheet)
for row, moment in enumerate([42, 62]):
    y = row * 362
    for col, (key, label) in enumerate(variants):
        x = col * 640
        draw.text((x + 15, y + 9), label, fill='#b6f9e9', font=font)
        draw.text((x + 15, y + 40), f'{moment / 100:.2f} s après le déclenchement', fill='white', font=small)
        pic = Image.open(source / f'{key}_{moment}.png').convert('RGB')
        pic = pic.crop((140, 200, 1140, 680)).resize((640, 295), Image.Resampling.LANCZOS)
        sheet.paste(pic, (x, y + 67))
sheet.save(out / 'comparaison.png')
frames = []
for n in range(30):
    canvas = Image.new('RGB', (1536, 288), '#13232e')
    for col, (key, _) in enumerate(variants):
        pic = Image.open(source / f'{key}_frame_{n:02d}.png').convert('RGB')
        canvas.paste(pic.resize((512, 288), Image.Resampling.LANCZOS), (col * 512, 0))
    frames.append(canvas)
frames[0].save(out / 'comparaison_animee.gif', save_all=True, append_images=frames[1:], duration=[65] * 29 + [650], loop=0, optimize=False)
for key, _ in variants:
    Image.open(source / f'{key}_42.png').save(out / f'{key}.png')
print(out)
