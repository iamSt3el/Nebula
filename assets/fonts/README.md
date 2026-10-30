# Fonts

`NebulaSymbolsDark.ttf` is a static instance of Google's
[Material Symbols Rounded](https://github.com/google/material-design-icons) variable font
(FILL 0, GRAD −25, opsz 24, wght 400), renamed to the family "Nebula Symbols Dark".
The shell uses it for icons on dark themes.
`NebulaSymbolsFilled.ttf` is Google's static `MaterialSymbolsRounded_Filled-Regular.ttf` (FILL 1, wght 400), used for
icons that set `fill: 1`. Licensed under the Apache License 2.0,
see `LICENSE-MaterialSymbols`.

Regenerate with fontTools:

```python
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer
f = instancer.instantiateVariableFont(
    TTFont("MaterialSymbolsRounded[FILL,GRAD,opsz,wght].ttf"),
    {"FILL": 0, "GRAD": -25, "opsz": 24, "wght": 400})
# then set name IDs 1/16 to "Nebula Symbols Dark", 4 to "Nebula Symbols Dark Regular",
# 6 to "NebulaSymbolsDark-Regular", drop STAT, and save.
```
