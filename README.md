# 🚤 Speedboats for Luanti, Minetest, Mineclonia & VoxeLibre

[![Luanti](https://img.shields.io/badge/Luanti-5.x+-00d2ff.svg)](https://www.luanti.org/)
[![Mineclonia](https://img.shields.io/badge/Mineclonia-Compatible-green.svg)](https://mineclonia.net/)
[![VoxeLibre](https://img.shields.io/badge/VoxeLibre-Supported-blue.svg)](https://git.minetest.land/VoxeLibre/VoxeLibre)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](licence.md)
[![Kenney: CC0](https://img.shields.io/badge/Assets-Kenney%20CC0-lightgrey.svg)](https://kenney.nl/)

> **Unleash full throttle on the open ocean!**  
> Say goodbye to sluggish wooden rowboats. **Speedboats** brings high-performance motorized watercraft, **7-step autonomous cruise control**, realistic **open-cockpit player seating**, and thrilling **maritime hazards** to your blocky seas.

---

## ⚡ Highlights & Key Features

* 🏎️ **2x Faster Navigation (Speed 7)**  
  Leave traditional boats in your wake! Reach exhilarating top speeds of **7.0 m/s**—twice as fast as standard watercraft.

* 🕹️ **7-Step Cruise Control Throttle ("Autopilot")**  
  No more holding down `[W]` until your finger cramps! Tap `[W]` to gear up (Steps 1 through 7) and `[S]` to downshift. Once set, your speedboat maintains its cruising speed automatically until you downshift back to Step 0 or reach shore.

* 💺 **Adaptive Cockpit Seating (Open vs. Roofed)**  
  * **Open-Top Boats** (`fan`, `speed_d`, `speed_e`, `speed_f`, `speed_h`, `speed_j`): The pilot sits neatly in the driver's seat at normal human scale with proper sitting animation.
  * **Enclosed Roof Boats** (`speed_a`, `speed_b`, `speed_c`, `speed_g`, `speed_i`): The pilot sits inside the covered cabin and the exterior avatar is hidden so it doesn't clip through the roof or glass.
  * In both modes, the driver retains a natural first-person windshield camera view.

* 🧊 **Titanic Iceberg Collision & Sinking Mechanic**  
  Watch where you steer! Hitting ice at speed triggers an instant hull breach. Hear the glass-shattering crunch, watch bubbles rush to the surface, and see the bow tilt downward as your vessel takes on water and sinks to the ocean floor.

* 🔥 **Lava Hazard & Thermal Incineration**  
  Magma and speedboats don't mix! Falling into lava engulfs the hull in flame and smoke particles, immediately ejecting the driver and melting the boat.

* ⛏️ **Heavy-Duty Pickaxe Dismantling**  
  No more accidental boat breaks from stray sword swings or punches! These reinforced hulls **can only be dismantled using a pickaxe**.

* 🛥️ **Complete Fleet of 11 Single Speedboats**  
  A diverse collection of 11 single boat types, from the swamp-ready Fan Airboat to high-speed racers (Alpha through Juliet).

* 🔄 **Shapeless Cycle Crafting**  
  Want to switch boats? Simply place any speedboat into any crafting slot to cycle into the next model in the fleet!

---

## 🕹️ Controls & Navigation

| Key | Action | Description |
|---|---|---|
| **`[W]` (Forward)** | **Gear Up (1 → 7)** | Increases your throttle step by +1 up to maximum Speed 7 (7.0 m/s). |
| **`[S]` (Backward)** | **Gear Down (7 → 0)** | Decreases your throttle step. At Step 0, hold `[S]` in water for reverse maneuvering. |
| **`[A]` (Left)** | **Port Turn** | Smoothly steers the boat to the left. |
| **`[D]` (Right)** | **Starboard Turn** | Smoothly steers the boat to the right. |
| **`[Shift]` (Sneak)** | **Exit / Dismount** | Safely dismounts the driver, restores standing animation, and halts the boat. |
| **Right-Click** | **Enter / Exit** | Mounts an empty speedboat or exits when already seated. |
| **Pickaxe Punch** | **Dismantle** | Breaks down the boat and returns it to your inventory. |

---

## 📟 Cockpit Heads-Up Display (HUD)

Whenever you board a speedboat, a real-time digital dashboard appears right above your hotbar:

```text
🚤 CRUISING [ ■■■■□□□ ] Step 4/7 (4.0 m/s) | [W] Gear Up  [S] Gear Down
⚡ MAX SPEED [ ■■■■■■■ ] Step 7/7 (7.0 m/s) | Cruise Active
🚨 MAYDAY! BOAT SINKING! HULL BREACH! 🚨
```

---

## 🛥️ The Speedboats Fleet

| Model | Item ID | Description |
|---|---|---|
| **Fan Speedboat** | `speedboats:fan` | Propeller-powered swamp airboat with high agility. |
| **Speedboat Alpha** | `speedboats:speed_a` | Classic marine cruiser with dual-tone hull and windshield. |
| **Speedboat Bravo** | `speedboats:speed_b` | Sport interceptor with streamlined racing geometry. |
| **Speedboat Charlie** | `speedboats:speed_c` | Aqua racer optimized for fast open-water sprinting. |
| **Speedboat Delta** | `speedboats:speed_d` | Offshore predator with extended deep-V hull. |
| **Speedboat Echo** | `speedboats:speed_e` | Compact hydro jet with rear thruster design. |
| **Speedboat Foxtrot** | `speedboats:speed_f` | Vortex runner with broad-beam rough-water stability. |
| **Speedboat Golf** | `speedboats:speed_g` | Arrowhead sprint built for straight-line velocity. |
| **Speedboat Hotel** | `speedboats:speed_h` | Coastal patrol vessel with reinforced hull walls. |
| **Speedboat India** | `speedboats:speed_i` | Stealth phantom with low drag coefficient. |
| **Speedboat Juliet** | `speedboats:speed_j` | Thunderbolt deluxe performance edition. |

---

## 🔨 Crafting Recipes

### Mineclonia & VoxeLibre
```text
[Iron Ingot]   [          ]   [Iron Ingot]
[Wood Plank]   [ Redstone ]   [Wood Plank]   ==>  Speedboat Alpha
[Wood Plank]   [Wood Plank]   [Wood Plank]

[          ]   [Iron Ingot]   [          ]
[Iron Ingot]   [ Redstone ]   [Iron Ingot]   ==>  Fan Speedboat
[Wood Plank]   [Wood Plank]   [Wood Plank]
```

### Minetest Game (Default)
```text
[Steel Ingot]  [          ]   [Steel Ingot]
[Wood Plank]   [Copper Ingot] [Wood Plank]   ==>  Speedboat Alpha
[Wood Plank]   [Wood Plank]   [Wood Plank]

[          ]   [Steel Ingot]  [          ]
[Steel Ingot]  [Copper Ingot] [Steel Ingot]  ==>  Fan Speedboat
[Wood Plank]   [Wood Plank]   [Wood Plank]
```

### Fleet Cycling
Place **any** speedboat alone in the crafting grid to cycle into the next speedboat in the fleet!

---

## 🌐 Compatibility

* **Luanti** (formerly Minetest) 5.0.0 through 5.10.0+
* **Mineclonia**
* **VoxeLibre** (formerly MineClone 2)
* **Minetest Game**

Zero external hard dependencies required!

---

## 📜 Credits & License

* **Code:** © 2026 **ronrob-lu** — Licensed under the [MIT License](licence.md).
* **3D Models & Textures:** Created by **Kenney** ([kenney.nl](https://www.kenney.nl/)) — Dedicated to the public domain under [Creative Commons Zero (CC0 1.0)](https://creativecommons.org/publicdomain/zero/1.0/).
