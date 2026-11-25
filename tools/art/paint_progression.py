"""Draw the reusable corruption frames, glyphs, energy cels and new gear icons."""

from pathlib import Path
import math

from PIL import Image, ImageDraw


OUT = Path(__file__).resolve().parents[2] / "assets/upgrade/props"
INK = "#3c294b"
VIOLET = "#9a69ae"
GLINT = "#ead0ed"
IRON = "#78778d"
BRASS = "#bc9668"


def tile(size=24):
    image = Image.new("RGBA", (size, size))
    return image, ImageDraw.Draw(image)


def make_card():
    image, art = tile(28)
    art.rectangle((1, 1, 26, 26), fill="#201829", outline="#594368")
    art.rectangle((3, 3, 24, 24), outline="#32243e")
    for x, y, dx, dy in [(1, 1, 1, 1), (26, 1, -1, 1), (1, 26, 1, -1), (26, 26, -1, -1)]:
        art.line([(x, y + 6*dy), (x, y + 2*dy), (x + 2*dx, y), (x + 6*dx, y)], fill=VIOLET)
        art.rectangle((min(x, x+2*dx), min(y, y+2*dy), max(x, x+2*dx), max(y, y+2*dy)), outline=GLINT)
    return image


def glyph(index, color=VIOLET):
    image, art = tile()
    if index == 0:
        art.polygon([(5, 17), (17, 4), (21, 3), (20, 8), (9, 20)], fill=color, outline=INK)
        art.line([(8, 17), (18, 6)], fill=GLINT)
        art.line([(5, 14), (11, 20)], fill=BRASS, width=2)
        art.line([(4, 21), (7, 18)], fill=BRASS, width=2)
    elif index == 1:
        art.polygon([(14, 2), (3, 15), (10, 14), (7, 22), (21, 9), (14, 10)], fill=color, outline=INK)
        art.line([(13, 6), (7, 13), (13, 12)], fill=GLINT)
    elif index == 2:
        art.polygon([(4, 5), (12, 2), (20, 5), (19, 15), (12, 22), (5, 15)], fill=color, outline=INK)
        art.line([(7, 7), (12, 5), (17, 7)], fill=GLINT, width=2)
        art.line([(12, 7), (12, 17)], fill=IRON, width=2)
    elif index == 3:
        art.polygon([(12, 2), (17, 9), (20, 15), (18, 20), (12, 22), (6, 20), (4, 15), (8, 8)],
                    fill=color, outline=INK)
        art.line([(12, 6), (8, 12), (7, 16)], fill=GLINT, width=2)
    elif index == 4:
        art.polygon([(9, 3), (15, 4), (14, 12), (20, 16), (20, 20), (7, 20), (4, 17), (7, 12)], fill=color, outline=INK)
        art.line([(8, 7), (13, 8)], fill=GLINT, width=2)
        art.line([(7, 18), (17, 18)], fill=BRASS, width=2)
    elif index == 5:
        art.ellipse((3, 3, 20, 20), fill=color, outline=INK, width=2)
        art.ellipse((6, 6, 17, 17), fill="#211b2b")
        art.line([(12, 7), (12, 12), (15, 14)], fill=GLINT, width=2)
    else:
        art.rounded_rectangle((3, 9, 14, 20), radius=3, outline=color, width=3)
        art.rounded_rectangle((10, 3, 21, 14), radius=3, outline=color, width=3)
        art.line([(9, 15), (15, 9)], fill=GLINT, width=2)
    return image


def energy():
    atlas = Image.new("RGBA", (8*24, 48))
    for i in range(8):
        image, art = tile()
        length = 3 + i
        art.polygon([(10, 20), (6, 13), (11, 3), (12, 12-length), (16, 10), (14, 19)],
                    fill=(165, 97, 202, 164), outline=VIOLET)
        art.line([(10, 19), (10, 13), (13, 6)], fill=GLINT, width=2)
        atlas.paste(image, (i*24, 0))
    for i in range(6):
        image, art = tile()
        for ray in range(7):
            angle = ray*math.tau/7
            x = round(12 + math.cos(angle)*(2+i*1.6))
            y = round(12 + math.sin(angle)*(2+i*1.6))
            art.rectangle((x, y, x+1, y+1), fill=(225, 170, 242, 255-i*30))
        atlas.paste(image, (i*24, 24))
    return atlas


def gear():
    atlas = Image.new("RGBA", (6*24, 48))
    molds = [0, 0, 1, 1, 6, 6, 5, 3, 2, 2, 4, 4]
    colors = ["#91a4b3", "#a8a09e", "#8eb9a1", "#785f9a", "#ab8358", "#9099ab",
              "#b38d5f", "#94628b", "#747989", "#a59283", "#88745e", "#85889b"]
    for i, mold in enumerate(molds):
        image = glyph(mold, colors[i])
        art = ImageDraw.Draw(image)
        if i == 1:
            art.line([(9, 14), (20, 4)], fill="#d0c4b4", width=3)
        elif i in (2, 3):
            art.line([(4, 21), (16, 7)], fill="#8f644a", width=2)
            art.ellipse((13, 3, 20, 10), fill=colors[i], outline=BRASS)
        elif i in (4, 5):
            art.line([(4, 18), (16, 18)], fill=BRASS, width=2)
        atlas.paste(image, ((i % 6)*24, (i // 6)*24))
    return atlas


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    make_card().save(OUT / "boon_card.png")
    icons = Image.new("RGBA", (7*24, 24))
    for index in range(7):
        icons.paste(glyph(index), (index*24, 0))
    icons.save(OUT / "boon_icons.png")
    energy().save(OUT / "boon_energy.png")
    gear().save(OUT / "gear_growth.png")
