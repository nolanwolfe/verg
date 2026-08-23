# App icon appearances

Three 1024×1024 PNGs, no alpha, no rounded corners — iOS masks them.

| File                   | Appearance | What it is                                          |
|------------------------|------------|-----------------------------------------------------|
| `appstore.png`         | Light/any  | The default, and the one the App Store shows.        |
| `appstore-dark.png`    | Dark       | Shown on a dark home screen.                         |
| `appstore-tinted.png`  | Tinted     | Greyscale. iOS applies the user's colour.            |

**Tinted is the one worth drawing by hand.** iOS derives it by desaturating
and re-tinting, which flattens a dark square with a small bright flame into a
muddy block — the flame is exactly the detail that gets lost. Supply a
greyscale image built for it: the candle light against dark, using luminance
alone to carry the shape, no colour anywhere.

Until `appstore-dark.png` and `appstore-tinted.png` exist, Xcode will warn
about the missing files and fall back to `appstore.png`.
