# psdf
pascal simpe df script
---
A simple script to show "df -h" output on linux using progress bars.

The bars and labels are drawn with a truecolor (24-bit) gradient that shades
from white to purple and back. Virtual/temporary filesystems (tmpfs, proc,
snap squashfs, ...) are filtered out and each mount point is shown only once.

## Usage

```
./psdf.sh            # gradient for a dark terminal background
./psdf.sh --invert   # shade from black instead of white, for bright backgrounds
./psdf.sh --help     # show options
```

The invert mode can also be enabled with `PSDF_INVERT=1`.

![output preview](https://raw.githubusercontent.com/pascalbrax/psdf/master/psdfcolors.PNG)
