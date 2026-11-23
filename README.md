# Spire VR — Phase 1 prototype

A VR action RPG prototype for Meta Quest, made with **Godot 4**.
You stand on a floating island and fight enemies with a sword.
**The faster you swing, the more damage you do.**

## What's in this version
- A sword in your right hand. Damage depends on swing speed, the blade glows when you swing hard, and the controller vibrates on hits.
- Enemies that use the same model in different colours (Crimson, Verdant, Azure, Violet and Amber Husks). They walk at you, glow as they wind up, and then lunge.
- Hitting an enemy while it winds up staggers it and cancels the attack.
- Floating damage numbers, enemy HP bars and name tags. Enemies topple and shatter when they die.
- Your HP is shown above your left hand, and there's a kill counter.
- Enemies knocked off the island also count as kills.

## Controls
| | VR (Quest) | No headset (PC test mode) |
|---|---|---|
| Move | Left thumbstick | W A S D |
| Turn | Right thumbstick (snap turn) | Mouse |
| Attack | Swing your right hand | Left click |
| Free the mouse | — | Esc |

## How to open it (beginner steps)
1. **Get the files.** On GitHub, switch to the `claude/kind-bell-rkkxsw` branch, click the green **Code** button, then **Download ZIP**. Unzip it somewhere.
2. **Open Godot 4** (version 4.3 or newer; 4.5 recommended).
3. In the Project Manager, click **Import**, browse to the unzipped folder, and select `project.godot`. Then click **Import & Edit**.
   - The first time, Godot spends a few seconds importing the character model. That's normal.
4. **Test on your PC without a headset:** press **F5** (or the ▶ Play button in the top right). With no headset connected, it starts in mouse & keyboard mode.

## Playing it on your Quest
### Option A: Quest Link (easiest, needs a Windows PC)
1. Install the **Meta Quest Link** app on your PC.
2. In the Link app, go to **Settings → General** and set **OpenXR Runtime** to Meta Quest Link.
3. Connect your Quest with a USB-C cable (or use Air Link) and enable Link inside the headset.
4. Press **F5** in Godot. The game runs in your headset.

### Option B: Standalone (installed on the Quest, no PC needed)
This needs more setup: Android build tools, the "Godot OpenXR Vendors" plugin, and Developer Mode on the Quest. Get Option A working first, then ask and we'll set this up step by step.

## Tuning numbers (no code needed)
Click a node in Godot's scene tree and change values in the **Inspector** on the right:
- `scenes/sword.tscn` → **Sword**: `Min Hit Speed`, `Damage Per Speed`, `Max Damage`
- `scenes/enemy.tscn` → **Enemy**: `Max Hp`, `Move Speed`, `Attack Damage`, `Windup Time`
- `scenes/main.tscn` → **Main**: `Max Enemies`, `Spawn Delay`
- `scenes/player.tscn` → **Player**: `Move Speed`, `Snap Turn Degrees`, `Max Hp`

If the sword sits at a weird angle in your hand, open `scenes/player.tscn`, select **RightHand → Sword**, and change its **Rotation** in the Inspector. Try X = -30 first.

## Project layout
```
assets/models/   character model (+ CREDITS.md)
scenes/          main.tscn (the arena), player.tscn, sword.tscn, enemy.tscn
scripts/         the GDScript code for each of those
PLAN.md          the overall roadmap
```

## Credits
The character model is "Proportional Low Poly Man" by Robin Butler, licensed CC-BY-4.0. See `assets/models/CREDITS.md`.
