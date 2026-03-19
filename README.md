# TweaksLoader

Standalone tweak dylib for the **Corunna** exploit chain (iOS 13.0 – 17.2.1).  
No substrate, no ellekit — pure ObjC runtime hooking injected into SpringBoard.

---

## Preview

<table>
  <tr>
    <td><img src="media/IMG_2827.PNG" width="200"/></td>
    <td><img src="media/IMG_2828.PNG" width="200"/></td>
    <td><img src="media/IMG_2829.PNG" width="200"/></td>
    <td><img src="media/IMG_2830.PNG" width="200"/></td>
  </tr>
  <tr>
    <td><img src="media/IMG_2831.PNG" width="200"/></td>
    <td><img src="media/IMG_2832.PNG" width="200"/></td>
    <td><img src="media/IMG_2833.PNG" width="200"/></td>
    <td><img src="media/IMG_2834.PNG" width="200"/></td>
  </tr>
  <tr>
    <td><img src="media/IMG_2835.PNG" width="200"/></td>
    <td><img src="media/IMG_2836.PNG" width="200"/></td>
    <td><img src="media/IMG_2837.PNG" width="200"/></td>
    <td><img src="media/IMG_2838.PNG" width="200"/></td>
  </tr>
  <tr>
    <td><img src="media/IMG_2839.PNG" width="200"/></td>
  </tr>
</table>

---

## Features

### Floating Dock
iPad-style floating dock on iPhone.

### Page Animations
8 home screen page-swipe animation styles — Cube, Wave, Tilt 3D, Fade, Spiral, Float, Smooth, None.

### Icon Roundness
Adjustable icon corner radius via slider.

### Custom Battery Styles
5 styles — Default, Vertical, Face, Kawaii, Heart, Bolt.

### Banner Glass
Liquid glass effect on notification banners.

### Lockscreen Customizer
Custom clock font, size, alignment, split mode, and date label.

### Control Center
Apple device info button and mini file browser injected into the CC overlay.

### Mini File Browser
Navigate the filesystem from SpringBoard. Read, edit, and save files — binary plists decoded to XML automatically. Long-press the floating button to open.

### Mini Terminal
SpringBoard-based terminal with native ObjC commands — no posix_spawn.  
`ls` `cd` `cat` `find` `grep` `echo` `ps` `env` `stat` `uname` `df` `head` `tail` `mkdir` `touch` `rm` `date` `whoami` `id` `neofetch` `clear` `pwd`  
Floating, draggable window. Save log to disk. Enable via the Settings panel toggle.

### MobileGestalt Editor
Write directly to `com.apple.MobileGestalt.plist` from SpringBoard.

| Tweak | Key |
|---|---|
| Dynamic Island (14 Pro / 14 Pro Max / 15 Pro Max / 16 Pro / 16 Pro Max) | `ArtworkDeviceSubType` |
| iPhone X Gestures | `ArtworkDeviceSubType` |
| Boot Chime | `QHxt+hGLaBPbQJbXiUJX3w` |
| 80% Charge Limit | `37NVydb//GP/GrhuTN+exg` |
| Tap to Wake | `yZf3GTRMGTuwSV/lD7Cagw` |
| Action Button | `cT44WE1EohiwRzhsZ8xEsw` |
| Always On Display | `2OOJf1VhaM7NxfRok3HbWQ` |
| Apple Pencil Support | `yhHcB0iH0d1XzPO/CFd3ow` |
| Apple Internal (Metal HUD) | `EqrsVvjcYDdxHBiQmGhAWw` |
| Disable Wallpaper Parallax | `UIParallaxCapability` |
| Collision SOS | `HCzWusHQwZDea6nNhaKndw` |
| Camera Button (iPhone 16) | `CwvKxM2cEogD3p+HYgaW0Q` |
| Stage Manager | `qeaj75wk3HF4DwQ8qbIi7g` |
| iPadOS Full (CacheExtra + CacheData auto-patch) | multiple |
| Apple Intelligence | `A62OafQ85EJAiiqKn4agtg` |

Includes backup, restore, and respring.

---

## Installation

Drop `TweaksLoader.dylib` into your Corunna dylib folder and inject into SpringBoard.

Requires **Corunna** or compatible exploit chain.  
iOS 13.0 – 17.2.1 | arm64

---

## Credits

Based on and inspired by:

- https://github.com/zeroxjf/Coruna-Tweaks-Collection — **zeroxjf**
- **FloatingDockXVI** — @EthanWhited  
- **Cylinder Remade** — @ryannair05  
- **FiveIconDock** — lunaynx  

### MobileGestalt Tweaks
- https://github.com/leminlimez — **Nuget**
- https://github.com/khanhduytran0 — **SparseBox**

### Additional
- **Claude** — collaboration & assistance

---

## Notes

- Source is not included for now. Binary only. Source release coming soon.
- MobileGestalt tweaks require a respring to apply.
- Stage Manager and iPadOS mode are marked risky — use with caution.
