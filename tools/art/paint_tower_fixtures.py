"""Paint native-size structures, split altar layers, and the ending panorama."""

import argparse
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw

from paint_architecture import BRASS, GRANITE, INK, OUT, ROOT, chipped, shift


def masonry(size, seed, base):
    """Draw joined rough ashlar with a lower dark face and oblique wear."""
    width, height = size
    image = Image.new("RGBA", size, INK)
    draw = ImageDraw.Draw(image)
    rng = random.Random(seed)
    body = [shift(base, delta) for delta in (-30, -16, -2, 9, 17)]
    draw.rectangle((1, 1, width - 2, height - 2), fill=body[0])
    cap = height - min(8, height // 5)
    for row, y in enumerate(range(1, cap, 8)):
        x = -8 if row % 2 else 0
        while x < width - 1:
            block_width = rng.randint(10, 20)
            left, right = max(1, x), min(width - 2, x + block_width - 1)
            amount = rng.choice((-6, -4, 0, 3, 5))
            chipped(draw, left, y, right - left, min(7, cap - y),
                    [shift(shade, amount) for shade in body], rng)
            x += block_width
    draw.line((1, 1, width - 2, 1), fill=body[3])
    draw.line((1, 2, 1, cap - 2), fill=body[2])
    draw.line((2, cap, width - 3, cap), fill=body[3])
    draw.rectangle((2, cap + 1, width - 3, height - 3), fill=body[1])
    for x in range(10, width - 4, 16):
        draw.line([(x, cap + 1), (x - 1, height - 3)], fill=body[0])
    return image


def wear(draw, points, upper, lower):
    draw.line(points, fill=upper, width=2)
    draw.line([(x, y + 1) for x, y in points], fill=lower)


def slot(draw, rect):
    left, top, right, bottom = rect
    draw.rectangle(rect, fill=INK)
    draw.line((left - 1, top - 1, right + 1, top - 1), fill=GRANITE[3])
    draw.line((left, bottom + 1, right, bottom + 1), fill=GRANITE[4])


def cover_fixtures():
    image = masonry((46, 42), 81, "686567")
    draw = ImageDraw.Draw(image)
    slot(draw, (17, 5, 32, 32))
    draw.polygon([(18, 10), (30, 8), (29, 28), (24, 32), (19, 27)], fill=BRASS[1])
    draw.line([(20, 28), (20, 12), (27, 11)], fill=BRASS[4], width=2)
    draw.ellipse((21, 15, 27, 21), fill=INK, outline=BRASS[3], width=2)
    deliver = {"fixture_01": image}

    image = masonry((30, 132), 82, "646366")
    draw = ImageDraw.Draw(image)
    draw.polygon([(4, 3), (23, 3), (25, 9), (21, 16), (25, 21), (23, 31),
                  (29, 33), (29, 120), (19, 119), (16, 127), (3, 127)], outline=GRANITE[3])
    wear(draw, [(23, 4), (20, 12), (24, 17), (18, 22), (16, 31), (8, 34)], INK, GRANITE[4])
    wear(draw, [(2, 76), (9, 75), (13, 82), (22, 84), (26, 86)], INK, GRANITE[4])
    draw.line([(5, 102), (4, 117), (7, 124)], fill="#4c5550", width=2)
    deliver["fixture_02"] = image

    image = masonry((210, 32), 83, "65666d")
    draw = ImageDraw.Draw(image)
    for x in (18, 112):
        slot(draw, (x, 5, x + 80, 22))
        draw.rectangle((x + 2, 6, x + 78, 20), fill="#272b34")
        for bar in range(x + 5, x + 79, 8):
            draw.line((bar, 6, bar, 20), fill="#65636a", width=2)
            draw.point((bar, 7), fill="#99908c")
        draw.line((x + 2, 18, x + 77, 18), fill="#4f4a4e", width=2)
    for x in (9, 103, 201):
        draw.ellipse((x - 2, 10, x + 3, 15), fill=INK, outline=BRASS[2])
        draw.point((x, 11), fill=BRASS[4])
    for x, y in ((11, 16), (14, 19), (18, 21), (23, 22), (28, 20), (32, 17)):
        draw.ellipse((x - 3, y - 2, x + 3, y + 2), fill="#242836", outline=BRASS[2])
        draw.point((x - 1, y - 2), fill=BRASS[3])
    deliver["fixture_03"] = image

    image = masonry((32, 134), 84, "6a6060")
    draw = ImageDraw.Draw(image)
    for y in (17, 56, 95):
        draw.polygon([(5, y), (24, y + 6), (22, y + 19), (5, y + 24)], fill="#4c454a")
        draw.line([(5, y), (24, y + 6)], fill=GRANITE[4], width=2)
        draw.rectangle((8, y + 5, 13, y + 20), fill=INK)
        draw.line((24, y + 9, 22, y + 17), fill=GRANITE[3])
    draw.line((27, 7, 27, 123), fill=BRASS[2], width=2)
    deliver["fixture_04"] = image

    for name, width, winch in [("fixture_05", 153, True), ("fixture_05_guard", 148, False)]:
        image = masonry((width, 32), 85 + width, "6c6261")
        draw = ImageDraw.Draw(image)
        slot(draw, (14, 7, width - 15, 23))
        draw.rectangle((18, 9, width - 19, 21), fill="#504747")
        draw.line((19, 12, width - 20, 12), fill=BRASS[1], width=2)
        draw.line((19, 19, width - 20, 19), fill=BRASS[2])
        for x in range(21, width - 20, 14):
            draw.line((x, 10, x, 21), fill=INK)
            draw.point((x + 3, 11), fill=GRANITE[4])
        for x in (4, width - 14):
            chipped(draw, x, 4, 8, 23, GRANITE, random.Random(x + 30))
        if winch:
            x = width // 2
            draw.rectangle((x - 19, 5, x + 18, 24), fill="#363136", outline=GRANITE[0])
            draw.ellipse((x - 10, 5, x + 10, 24), fill=BRASS[1], outline=INK, width=2)
            draw.arc((x - 9, 6, x + 9, 23), 172, 340, fill=BRASS[4], width=2)
            draw.ellipse((x - 5, 10, x + 5, 20), fill=INK, outline=BRASS[3])
            draw.line([(x, 15), (x + 13, 7), (x + 17, 7)], fill=BRASS[3], width=2)
        deliver[name] = image

    image = masonry((139, 33), 86, "635d64")
    draw = ImageDraw.Draw(image)
    for x in (16, 116):
        draw.line((x, 4, x, 25), fill="#362e36", width=4)
        draw.line((x - 1, 4, x - 1, 24), fill="#797070")
        draw.point((x + 2, 10), fill=BRASS[3])
    wear(draw, [(75, 1), (70, 7), (76, 13), (75, 21), (82, 29)], "#31263b", "#635269")
    draw.line([(74, 20), (65, 24), (42, 25), (39, 30)], fill="#4d4053", width=2)
    for x in range(33, 113, 6):
        draw.point((x, 23 if x % 10 else 25), fill="#6b596d")
    deliver["fixture_06"] = image

    image = masonry((121, 31), 87, "6e6268")
    draw = ImageDraw.Draw(image)
    draw.polygon([(4, 5), (29, 4), (49, 10), (48, 25), (7, 26)], fill="#5f565d", outline=INK)
    draw.line([(5, 7), (30, 5), (46, 12)], fill="#89807f", width=2)
    draw.polygon([(76, 9), (115, 3), (118, 24), (79, 26), (71, 19)], fill="#635961", outline=INK)
    draw.line([(77, 10), (113, 4)], fill="#89807f", width=2)
    for x in (48, 64):
        draw.polygon([(x, 7), (x + 5, 8), (x + 2, 25), (x - 2, 26)], fill="#554950", outline=INK)
        draw.point((x + 1, 10), fill=BRASS[3])
        draw.point((x - 1, 22), fill=BRASS[3])
    wear(draw, [(60, 2), (59, 11), (63, 14), (54, 21), (57, 30)], "#33273a", "#665165")
    deliver["fixture_07"] = image

    image = masonry((33, 147), 89, "615c68")
    draw = ImageDraw.Draw(image)
    for x in (9, 23):
        slot(draw, (x - 2, 4, x + 3, 137))
        draw.line((x, 5, x, 136), fill="#514954", width=2)
        for y in range(13, 134, 21):
            draw.line((x - 1, y, x + 2, y), fill=BRASS[3])
    for y in (6, 69, 134):
        draw.rectangle((4, y, 28, y + 4), fill=BRASS[1], outline=INK)
        draw.line((5, y + 1, 27, y + 1), fill=BRASS[3])
    deliver["fixture_09"] = image

    image = masonry((50, 48), 90, "64596b")
    draw = ImageDraw.Draw(image)
    draw.rectangle((8, 8, 41, 39), fill="#554c58", outline=INK, width=2)
    draw.line([(9, 38), (9, 9), (39, 9)], fill="#817883", width=2)
    for x in (11, 36):
        draw.line((x, 12, x, 35), fill=BRASS[2], width=3)
    wear(draw, [(25, 8), (22, 17), (26, 24), (22, 36), (19, 43)], "#332737", "#68576e")
    deliver["fixture_10_pillar"] = image
    return deliver


def inlays():
    layers = {}
    image = Image.new("RGBA", (82, 44))
    draw = ImageDraw.Draw(image)
    draw.polygon([(4, 6), (76, 6), (79, 30), (73, 38), (6, 38), (1, 30)], fill="#454650", outline="#30313a")
    for y in (11, 19, 27):
        draw.line((5, y, 75, y), fill="#605e65")
        draw.line((6, y + 1, 76, y + 1), fill="#33353e")
    for x in (14, 40, 67):
        slot(draw, (x - 3, 24, x + 3, 32))
    layers["threshold_01"] = image

    image = Image.new("RGBA", (24, 118))
    draw = ImageDraw.Draw(image)
    draw.polygon([(4, 2), (19, 2), (21, 109), (18, 116), (5, 116), (3, 108)], fill="#42474e", outline="#2c313a")
    draw.line((9, 4, 9, 113), fill="#2b3037", width=5)
    draw.line((6, 5, 6, 113), fill="#5d6063")
    draw.line((13, 9, 13, 108), fill="#3e4f52")
    for y in range(11, 113, 17):
        draw.line((6, y, 17, y), fill="#52535a")
    layers["drain_02"] = image

    image = Image.new("RGBA", (154, 81))
    draw = ImageDraw.Draw(image)
    for box in ((1, 1, 152, 78), (12, 7, 142, 73), (19, 14, 135, 66)):
        draw.arc(box, 17, 151, fill="#504754", width=2)
        draw.arc(box, 185, 341, fill="#655959", width=2)
    draw.polygon([(77, 21), (113, 40), (77, 58), (41, 40)], outline="#6c5a5b", width=2)
    draw.line([(5, 30), (21, 31), (25, 37), (36, 40), (40, 47)], fill="#302930", width=2)
    draw.line([(102, 63), (113, 54), (121, 54), (128, 43), (145, 38)], fill="#302930", width=2)
    for x in (32, 123):
        draw.line((x, 34, x, 46), fill="#775f59", width=2)
        draw.line((x - 4, 40, x + 4, 40), fill="#775f59")
    layers["fixture_08"] = image

    image = Image.new("RGBA", (150, 89))
    draw = ImageDraw.Draw(image)
    draw.ellipse((4, 2, 145, 85), outline="#302934", width=3)
    draw.arc((6, 4, 143, 83), 191, 343, fill="#746365", width=3)
    draw.arc((15, 12, 134, 78), 13, 153, fill="#67585b", width=2)
    draw.arc((15, 12, 134, 78), 182, 355, fill="#8b7770", width=2)
    crown = [(46, 32), (63, 42), (75, 25), (88, 42), (103, 30), (96, 61), (54, 61)]
    draw.polygon(crown, fill="#5d4c52", outline="#332a36", width=2)
    draw.line(crown[:5], fill="#8f7870", width=2)
    draw.line((56, 57, 94, 57), fill="#736063", width=2)
    wear(draw, [(103, 6), (100, 19), (84, 29), (82, 42), (70, 50), (61, 70), (46, 84)], "#322a36", "#675365")
    layers["fixture_10"] = image
    return layers


def altar():
    # Preserve the existing basin painting. Detach its saturated red strokes so light
    # follows the presence of the bead without changing the material of the stone.
    stone = Image.open(ROOT / "assets/edition/props.png").convert("RGBA")
    stone = stone.crop((765, 73, 1046, 337)).resize((90, 85), Image.Resampling.LANCZOS)
    runes = Image.new("RGBA", stone.size)
    base, glow = stone.load(), runes.load()
    for y in range(stone.height):
        for x in range(stone.width):
            red, green, blue, alpha = base[x, y]
            if alpha > 0 and red > 83 and red - green > 36 and red > 1.48 * blue:
                amount = min(224, (red - max(green, blue)) * 2)
                glow[x, y] = (222, 54 + green // 8, 80 + blue // 8, min(alpha, amount))
                base[x, y] = (62 + red // 9, 43 + green // 4, 52 + blue // 4, alpha)
    return {"altar_stone": stone, "altar_runes": runes}


def crystal():
    base = masonry((70, 33), 891, "625969")
    draw = ImageDraw.Draw(base)
    draw.ellipse((14, 2, 56, 27), fill=INK, outline="#8a7970", width=2)
    draw.ellipse((20, 5, 52, 23), fill="#352943", outline=BRASS[1], width=2)
    for x in (6, 54):
        chipped(draw, x, 6, 10, 19, GRANITE, random.Random(x))
        draw.line((x + 2, 14, x + 9, 14), fill=BRASS[3], width=2)
    mineral = Image.new("RGBA", (61, 76))
    draw = ImageDraw.Draw(mineral)
    draw.polygon([(9, 66), (4, 56), (7, 40), (19, 30), (23, 54), (27, 67)], fill="#523858", outline=INK, width=2)
    draw.polygon([(35, 65), (38, 46), (52, 35), (57, 52), (54, 65), (49, 70)], fill="#66446d", outline=INK, width=2)
    draw.polygon([(18, 65), (13, 48), (21, 14), (36, 3), (48, 21), (45, 56), (35, 72)], fill="#5f4178", outline=INK, width=2)
    draw.polygon([(21, 15), (36, 4), (31, 29), (17, 50)], fill="#8e64a7")
    draw.polygon([(36, 4), (47, 21), (41, 43), (31, 29)], fill="#b287bc")
    draw.polygon([(31, 29), (41, 43), (34, 69), (19, 64), (16, 49)], fill="#563968")
    draw.polygon([(41, 43), (47, 21), (44, 54), (35, 69)], fill="#382944")
    draw.line([(18, 45), (21, 25), (25, 15), (35, 5)], fill="#c9a7cd", width=2)
    draw.line([(31, 30), (36, 37), (28, 46), (29, 53), (20, 62)], fill="#ad80b5", width=2)
    draw.line([(38, 47), (35, 57), (35, 63)], fill="#917099")
    draw.line([(9, 52), (10, 45), (17, 35)], fill="#9e739e", width=2)
    draw.line([(49, 42), (51, 37), (55, 50)], fill="#bc8dbb", width=2)
    glow = Image.new("RGBA", mineral.size)
    draw = ImageDraw.Draw(glow)
    draw.line([(33, 9), (25, 20), (23, 33)], fill=(216, 153, 241, 136), width=2)
    draw.line([(31, 33), (32, 38), (27, 47), (29, 53), (22, 60)], fill=(217, 121, 255, 179), width=2)
    draw.line([(40, 30), (39, 36), (37, 39)], fill=(206, 152, 230, 113))
    draw.point((49, 45), fill=(243, 166, 255, 173))
    return {"summit_crystal_base": base, "summit_crystal": mineral, "summit_crystal_glow": glow}


def skyline():
    size = (640, 360)
    image = Image.new("RGBA", size)
    draw = ImageDraw.Draw(image)
    rng = random.Random(86717)
    # Layer distant ridges from cold fog to the exposed nearer escarpment.
    for index, (mid, height, color) in enumerate([(249, 52, "#7b7686"), (280, 68, "#5d5c70"),
                                                  (304, 77, "#46465a"), (341, 59, "#2e3241")]):
        peaks = []
        for x in range(-16, 664, 8):
            side = (abs(x - 330) / 330) ** 1.3
            lift = (math.sin(x / (31 + 4 * index)) + math.sin(x / 13 + index) * 0.26) * 9
            peaks.append((x, round(mid - height * side + lift + rng.randrange(-3, 4))))
        draw.polygon(peaks + [(663, 360), (-16, 360)], fill=color)
        draw.line(peaks, fill=shift(color, 10))
        for x, y in peaks[::3]:
            if rng.random() < 0.76:
                draw.line([(x, y + 3), (x + 9, y + 6), (x + 18, y + 12)], fill=shift(color, 5))

    tower = [(264, 317), (276, 281), (279, 203), (286, 184), (284, 165), (291, 148),
             (291, 83), (279, 83), (279, 69), (291, 69), (292, 59), (303, 58), (307, 41),
             (314, 25), (329, 13), (345, 28), (352, 52), (355, 69), (368, 69), (368, 82),
             (359, 85), (361, 146), (368, 157), (367, 180), (374, 205), (376, 276), (394, 309),
             (402, 346), (259, 346)]
    draw.polygon(tower, fill="#242633", outline="#1c202c", width=2)
    draw.polygon([(280, 278), (284, 208), (295, 181), (293, 164), (297, 132), (296, 90),
                  (308, 86), (312, 273), (302, 317), (277, 322)], fill="#383944")
    draw.polygon([(312, 68), (315, 43), (328, 22), (324, 62), (332, 70)], fill="#45434d")
    draw.polygon([(333, 22), (343, 36), (350, 69), (342, 69)], fill="#302f3c")
    draw.line([(294, 63), (306, 63), (313, 42), (329, 19)], fill="#68606a", width=2)
    for y in (77, 85, 112, 137, 154, 177, 208, 239, 269, 288):
        left = 295 if y < 150 else 284
        right = 358 if y < 180 else 372
        draw.line((left, y, right, y), fill="#50505b", width=2)
        draw.line((left, y + 2, right, y + 2), fill="#212533")
    for i in range(8):
        x, y = 315 if i % 2 else 336, 94 + 24 * i
        draw.polygon([(x, y + 11), (x, y + 3), (x + 3, y), (x + 6, y + 3), (x + 6, y + 11)], fill="#181e2a")
        draw.line((x + 1, y + 11, x + 1, y + 6), fill="#595363")
    draw.line([(353, 102), (354, 160), (351, 179), (357, 225), (359, 278)], fill="#171e2a", width=3)
    draw.polygon([(0, 345), (167, 330), (223, 344), (264, 322), (294, 319), (323, 326), (343, 316),
                  (375, 323), (405, 322), (460, 344), (542, 330), (639, 330), (639, 359), (0, 359)], fill="#222a36")
    for x in [17, 57, 104, 148, 194, 228, 426, 471, 482, 517, 560, 606, 623]:
        height = rng.randint(15, 41)
        ground = rng.randrange(341, 359)
        for half in range(3, 11, 3):
            top = ground - height + half
            draw.polygon([(x, top - 4), (x - half, top + 13), (x + half - 1, top + 10)], fill="#19232c")
        draw.rectangle((x - 1, ground - height + 8, x + 1, ground), fill="#19232c")

    clouds = Image.new("RGBA", size)
    draw = ImageDraw.Draw(clouds)
    for band, (height, tint) in enumerate([(53, (104, 101, 128, 118)), (102, (127, 122, 146, 100)),
                                            (162, (124, 115, 138, 70)), (218, (168, 149, 158, 74))]):
        for x in range(-40, 630, 116):
            width = rng.randrange(100, 214)
            y = height + rng.randrange(-12, 13)
            draw.polygon([(x, y + 6), (x + 30, y), (x + width // 2, y - 7 - band),
                          (x + width - 26, y - 1), (x + width, y + 5),
                          (x + width - 31, y + 10), (x + 34, y + 12)], fill=tint)
            draw.line((x + 37, y + 12, x + width - 29, y + 10), fill=(*shift(tint, 13), tint[3] // 2))
    return {"summit_skyline": image, "summit_clouds": clouds}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=OUT)
    args = parser.parse_args()
    images = cover_fixtures() | inlays() | altar() | crystal() | skyline()
    args.output.mkdir(parents=True, exist_ok=True)
    for name, image in images.items():
        image.save(args.output / f"{name}.png", optimize=True)


if __name__ == "__main__":
    main()
