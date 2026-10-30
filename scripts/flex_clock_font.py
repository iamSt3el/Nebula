import sys

from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

FAMILY = "Google Sans Flex Clock"
AXES = {"wght": 1000, "wdth": 106, "ROND": 0, "opsz": 144, "slnt": 0}


def main(src, dst):
    font = instancer.instantiateVariableFont(TTFont(src), AXES, overlap=instancer.OverlapMode.REMOVE)
    name = font["name"]
    for rec in list(name.names):
        if rec.nameID in (16, 17, 21, 22, 25):
            name.removeNames(nameID=rec.nameID)
    name.setName(FAMILY, 1, 3, 1, 0x409)
    name.setName("Regular", 2, 3, 1, 0x409)
    name.setName(FAMILY + " Regular", 3, 3, 1, 0x409)
    name.setName(FAMILY, 4, 3, 1, 0x409)
    name.setName(FAMILY.replace(" ", "") + "-Regular", 6, 3, 1, 0x409)
    for table in ("STAT",):
        if table in font:
            del font[table]
    font["OS/2"].usWeightClass = 900
    font["OS/2"].fsSelection = (font["OS/2"].fsSelection & ~0b1100001) | 0b1000000
    font["head"].macStyle = 0
    font.save(dst)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
