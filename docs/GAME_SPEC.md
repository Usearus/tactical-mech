# 2D Mecha Tactical Card Game

## Game Design & Godot Architecture Specification

## 1. Project Overview

Build a 2D, landscape-oriented tactical mecha game for Android and PC using Godot 4.x.

The game combines:

* A strategic overworld
* Tactical turn-based mecha combat
* Card-driven combat abilities
* Mecha customization
* Equipment-driven deck construction
* Unique mech abilities
* Story / command-base management
* Positioning and encounters on the overworld
* Short cinematic attack cut-ins for powerful attacks

The game should feel like a combination of:

* A classic 2D tactical mecha game
* A card-based combat system
* A lightweight strategy/overworld game
* Anime/mecha-style special attack presentation

The game should be approachable and relatively fast-paced rather than a traditional long-form strategy RPG.

The core design principle is:

> **Your mech build creates your deck, and your mech itself gives that deck its identity.**

Equipment determines much of what a mech can do, while the chassis/mech provides a small number of unique abilities that make each mech feel distinct.

---

# 2. Platform

Primary target:

* Android
* Landscape orientation

Secondary target:

* PC

The game should be designed for touch input from the beginning, even if development initially occurs on PC.

Controls should work with:

* Mouse
* Touch

Avoid designing core interactions that require a keyboard.

The UI should be resolution-independent and use Godot anchors/containers appropriately.

Do not hard-code the game to a specific resolution.

The visual style can be inspired by GBA-era 2D games, but the game should not literally be constrained to GBA resolution.

---

# 3. Core Game Loop

The overall game loop is:

```text
COMMAND / BASE
      ↓
Prepare squad
      ↓
Select mission
      ↓
OVERWORLD
      ↓
Move mechs
      ↓
Explore / position / encounter enemies
      ↓
BATTLE
      ↓
Tactical combat
      ↓
Battle resolution
      ↓
Return to OVERWORLD or COMMAND
      ↓
Continue story / upgrade mechs
```

The command/base layer exists primarily as a place for:

* Story
* Mission briefing
* Mech management
* Equipment management
* Deck management
* Repairs
* Upgrades
* Squad management
* Deployment

The initial prototype does not need a sophisticated base simulation.

A simple command screen with buttons such as:

```text
HANGAR
STORY / BRIEFING
DEPLOY
```

is sufficient.

---

# 4. Command / Base

The Command screen is the player's preparation hub.

Possible structure:

```text
COMMAND
├── HANGAR
├── STORY
├── BRIEFING
└── DEPLOY
```

## HANGAR

The hangar allows the player to inspect and customize mechs.

A mech can have:

* Chassis
* Core / torso
* Arms
* Legs
* Right-hand weapon
* Left-hand weapon
* Shoulder equipment
* Booster
* Backpack
* Pilot
* Unique mech abilities
* Equipment-derived cards

The fixed chassis components are primarily identity/stat-related.

The modular equipment creates cards.

## STORY / BRIEFING

This can eventually contain:

* Dialogue
* Mission briefings
* Character conversations
* Intel
* Story progression
* Mission objectives

For the prototype, this can simply be placeholder UI.

## DEPLOY

The player:

1. Selects squad
2. Selects mission
3. Enters overworld

---

# 5. Squad

The player controls approximately three mechs.

The exact squad size should remain configurable rather than hard-coded into the combat engine.

Example:

```text
Player Squad
├── Raven
├── Bulldog
└── Lancer
```

Each mech is an independent game entity with:

* Persistent stats
* Equipment
* Deck
* Unique cards
* Position
* Current HP
* Status effects
* Upgrade state

The same mech data should be usable in:

* Hangar
* Overworld
* Battle
* UI
* Save/load systems

---

# 6. Overworld

The overworld is a strategic grid.

It should generally be presented horizontally/landscape.

Example:

```text
┌───┬───┬───┬───┬───┬───┬───┬───┐
│   │   │   │   │   │   │   │   │
├───┼───┼───┼───┼───┼───┼───┼───┤
│   │ 🤖│   │   │ 👾│   │   │   │
├───┼───┼───┼───┼───┼───┼───┼───┤
│   │   │   │   │   │   │   │   │
└───┴───┴───┴───┴───┴───┴───┴───┘
```

The exact overworld size should be configurable.

A prototype might use approximately a 10×10 map.

Each mech has an overworld grid coordinate:

```text
Vector2i(x, y)
```

Every turn, each player mech can move once.

The overworld is important strategically because **where units are positioned when combat begins influences the tactical battle**.

The overworld should therefore not simply be a menu between battles.

---

# 7. Overworld Encounters

A battle begins when opposing mechs encounter each other according to the overworld rules.

The system must determine:

* Which units are involved
* Who initiated the encounter
* The direction of approach
* Relative positions of participating units
* Initial tactical battle positions

The unit that directly initiates an encounter is considered the attacker for purposes of determining the initial battle anchor.

However:

> **Attacker does NOT automatically mean "left side of battlefield."**

The battlefield is a shared 5×10 grid.

The attacker enters at a designated anchor position based on the direction from which the encounter occurred.

---

# 8. Tactical Battle Grid

The tactical battle battlefield is a:

**5 rows × 10 columns grid**

for a total of 50 cells.

Coordinate convention:

```text
Rows:    A B C D E
Columns: 1 2 3 4 5 6 7 8 9 10
```

Example:

```text
      1   2   3   4   5   6   7   8   9   10

A    [ ] [ ] [ ] [ ] [ ] [ ] [ ] [ ] [ ] [ ]
B    [ ] [ ] [ ] [ ] [ ] [ ] [ ] [ ] [ ] [ ]
C    [ ] [ ] [ ] [ ] [ ] [ ] [ ] [ ] [ ] [ ]
D    [ ] [ ] [ ] [ ] [ ] [ ] [ ] [ ] [ ] [ ]
E    [ ] [ ] [ ] [ ] [ ] [ ] [ ] [ ] [ ] [ ]
```

The grid should be represented internally as a generic rectangular grid.

Do NOT hard-code assumptions that the battle grid will always be 5×10.

Recommended structure:

```text
BattleGrid
├── width
├── height
└── cells[]
```

The initial default should be:

```text
width = 10
height = 5
```

This allows future special battlefields without rewriting the combat engine.

---

# 9. Battle Orientation and Attacker Anchor

The attacker has an entry point determined by the direction of the encounter.

For example, if the attacker approaches from the left:

```text
B3
```

is the attacker's starting position.

If the attacker approaches from the right:

```text
B4
```

can be used as the corresponding starting anchor after the battlefield orientation is established.

The exact coordinate mapping should be implemented through a battle deployment system rather than scattered throughout combat code.

Conceptually:

```text
Encounter Direction
        ↓
Battle Deployment
        ↓
Determine attacker anchor
        ↓
Place remaining units relative to encounter
        ↓
Start Battle
```

The attacker anchor is therefore a **deployment rule**, not a permanent "attacker side."

---

# 10. Translating Overworld Positions Into Battle Positions

The most important relationship between the strategic and tactical layers is:

> **The tactical battlefield is a zoomed-in interpretation of the encounter.**

When combat begins, the game should use the relative positions of participating units on the overworld to determine their starting positions on the 5×10 battlefield.

For example:

```text
Overworld encounter:

Player A
Player B
      Enemy A
      Enemy B
```

could become:

```text
Battle:

[ ][ ][A][ ][ ][ ][ ][ ][ ][ ]
[ ][ ][B][ ][ ][E][ ][ ][ ][ ]
[ ][ ][ ][ ][ ][ ][E][ ][ ][ ]
[ ][ ][ ][ ][ ][ ][ ][ ][ ][ ]
[ ][ ][ ][ ][ ][ ][ ][ ][ ][ ]
```

The exact transformation algorithm can evolve during prototyping.

The architecture should therefore isolate this functionality in something like:

```text
BattleDeployment
```

or:

```text
EncounterDeploymentResolver
```

Do not place overworld-to-battle coordinate conversion directly inside `BattleManager`.

---

# 11. Battle Participants

Only units involved in the encounter participate in the battle.

Example:

If three player mechs are occupying the encounter area and one enemy is present:

```text
Player:
Raven
Bulldog
Lancer

Enemy:
Scout
```

the battle is:

```text
3v1
```

If only two player mechs are involved:

```text
2v1
```

If multiple enemy mechs are involved:

```text
3v3
```

etc.

The combat engine should not assume fixed team sizes.

---

# 12. Tactical Movement

Units occupy individual cells.

Movement is grid-based.

A unit can move between valid cells according to its movement allowance and card/equipment effects.

Movement should eventually account for:

* Occupied cells
* Terrain
* Obstacles
* Movement range
* Special movement abilities
* Knockback
* Charge
* Dash
* Jump/boost abilities

Do not implement all of these initially.

The first prototype only needs basic movement.

---

# 13. Terrain

The 5×10 battlefield should eventually support terrain.

Potential terrain types:

* Normal ground
* Cover
* Buildings
* Ruins
* Obstacles
* Elevated terrain
* Hazard tiles
* Destructible cover

Terrain should be represented as data rather than hard-coded visual behavior.

Example:

```text
BattleCell
├── terrain_type
├── occupant
├── cover
├── elevation
└── effects
```

This will allow cards to interact with the battlefield.

Examples:

```text
Missile Barrage
→ Area damage
→ Can destroy cover

Railgun
→ High damage
→ Can pierce cover

Dash
→ Increased movement

Breach
→ Destroy adjacent cover
→ Damage nearby units
```

---

# 14. Turn Structure

The exact action economy can evolve, but the intended structure is turn-based.

A simplified initial model:

```text
START TURN
    ↓
Draw cards
    ↓
Player action phase
    ↓
Enemy action phase
    ↓
END TURN
```

The original design concept is that each turn provides an opportunity to perform a meaningful attack/battle action.

Cards are central to this action phase.

The system should remain flexible enough to eventually support:

* Movement
* Card attacks
* Defensive cards
* Utility cards
* Multiple actions
* Free movement
* Special abilities

Do not prematurely lock the game into a complex action-point system.

---

# 15. Card System

Cards are the primary combat actions.

A mech's deck is generated from its equipment and unique identity.

Core design principle:

> **Your build is your deck.**

Equipment determines the cards available to the mech.

---

# 16. Equipment Slots

Current planned equipment slots:

### Fixed / chassis components

* Core / torso
* Arms
* Legs

These primarily define the physical mech and its base capabilities.

### Modular equipment

* Right-hand weapon
* Left-hand weapon
* Shoulder equipment
* Booster
* Backpack

Potentially:

* Pilot

The modular equipment contributes cards to the mech's deck.

---

# 17. Equipment → Cards

Example:

```text
Assault Rifle Mk I
    ↓
Burst Fire card
```

Upgrade:

```text
Assault Rifle Mk II
    ↓
Improved Burst Fire
```

Upgrade:

```text
Assault Rifle Mk III
    ↓
Advanced Burst Fire
```

Other examples:

```text
Shield
    ↓
Guard

Missile Pod
    ↓
Missile Barrage

Mobility Booster
    ↓
Dash

Ammo Pack
    ↓
Reload
```

Equipment upgrades should therefore affect both:

* Physical mech configuration
* Combat deck

This creates a direct connection between customization and gameplay.

---

# 18. Suggested Equipment Roles

These are guidelines, not rigid rules.

### Right / Left Hand

Typically direct combat.

Examples:

* Assault rifle
* Machine gun
* Shotgun
* Sword
* Heavy weapon
* Shield

### Shoulder

Typically:

* Long-range
* Area attacks
* Heavy weapons

Examples:

* Missile launcher
* Railgun
* Mortar
* Artillery

### Booster

Typically:

* Movement
* Mobility
* Charges
* Evasion

Examples:

* Dash
* Jump
* Charge
* Afterburner

### Backpack

Typically:

* Utility
* Ammunition
* Support
* Repair
* Drones

Examples:

* Reload
* Repair
* Drone deployment
* Ammo supply

---

# 19. Mech-Specific Cards

Each mech should have approximately two cards that are unique to its chassis.

This is important because interchangeable equipment should not make every mech feel identical.

Concept:

```text
Equipment
    ↓
Determines playstyle

Mech chassis
    ↓
Determines identity
```

Example:

### Raven

High mobility.

Unique cards:

```text
Afterburner
Ghost Step
```

### Bulldog

Heavy assault.

Unique cards:

```text
Brace
Breach
```

### Lancer

Close-range/melee.

Unique cards:

```text
Charge
Counterstrike
```

These names/examples are placeholders and can change.

Unique cards may also upgrade alongside the mech.

---

# 20. Optional Pilot Cards

The architecture should leave room for pilot-specific cards.

For example:

```text
Pilot
    ↓
1 unique pilot card
```

This is not required for the first prototype.

Do not implement pilots as a mandatory gameplay system until the core card/mech system works.

---

# 21. Deck Construction

A mech's deck should be generated from:

```text
Mech
+
Equipment
+
Unique Mech Cards
+
Optional Pilot
=
Deck
```

For example:

```text
Raven

Right Hand:
Assault Rifle
→ Burst Fire
→ Suppressive Fire

Left Hand:
Shield
→ Guard

Shoulder:
Missile Pod
→ Missile Barrage

Booster:
High Mobility Booster
→ Dash

Backpack:
Ammo Pack
→ Reload

Mech:
Raven
→ Afterburner
→ Ghost Step

Pilot:
Optional
→ Pilot Ability
```

The exact number of cards is not finalized.

A reasonable initial prototype might have approximately 8–11 cards.

The game should not depend on this exact number.

---

# 22. Card Data Architecture

Cards should be data-driven.

Use a `CardData` resource/class rather than putting individual card behavior inside UI scenes.

Conceptual structure:

```text
CardData
├── id
├── name
├── description
├── card_type
├── damage
├── range
├── movement
├── target_type
├── effects
├── animation
└── cut_in
```

Possible card types:

```text
Attack
Defense
Movement
Utility
Support
Special
```

The exact type system can evolve.

---

# 23. Combat Resolution

Combat calculations should be separated from presentation.

Use a dedicated:

```text
CombatResolver
```

Its responsibility is determining what actually happens.

Examples:

```text
calculate_damage()
apply_damage()
move_unit()
apply_status()
destroy_cover()
apply_knockback()
check_unit_destroyed()
```

`BattleManager` should coordinate the battle.

`CombatResolver` should resolve the rules.

The UI should not calculate damage.

---

# 24. Battle Manager

`BattleManager` controls the current tactical encounter.

Responsibilities:

* Initialize battle
* Load participants
* Create battlefield
* Handle turns
* Handle card selection
* Request combat resolution
* Advance phases
* Trigger animations
* Check victory/defeat
* End battle
* Return results to overworld

Conceptual structure:

```text
BattleManager
├── battle_grid
├── player_units
├── enemy_units
├── current_turn
├── current_phase
├── card_system
├── combat_resolver
├── enemy_ai
└── attack_cutin_manager
```

---

# 25. Attack Cut-In System

Special attacks should have a more cinematic presentation.

Normal cards should be fast.

Example:

```text
Burst Fire
→ small weapon animation
→ damage
```

Special cards can trigger:

```text
Card selected
      ↓
Battle temporarily pauses
      ↓
Large mech illustration / animation appears
      ↓
Mech performs attack
      ↓
VFX / impact
      ↓
Return to battlefield
      ↓
Combat resolution
```

This should be reserved for cards that deserve emphasis.

Potential examples:

* Missile Barrage
* Full-Charge Railgun
* Mech-specific ultimate
* Powerful melee attack
* Pilot special ability

---

# 26. Attack Cut-In Architecture

Use a dedicated:

```text
AttackCutInManager
```

A card can contain information such as:

```text
cut_in = "missile_barrage"
```

The manager then loads/plays the appropriate presentation.

Potential scene:

```text
AttackCutIn.tscn
├── AnimationPlayer
├── Sprite2D / AnimatedSprite2D
├── VFX
├── Camera
└── Audio
```

The cut-in system must be independent from combat calculations.

The combat engine should not care how an attack looks.

---

# 27. Mech Visual Architecture

Mechs should ideally be constructed from modular visual components.

Potential components:

```text
Mech
├── Core / Torso
├── Head
├── Left Arm
├── Right Arm
├── Legs
├── Left Weapon
├── Right Weapon
├── Shoulder Equipment
├── Booster
└── Backpack
```

This allows equipment customization to visibly change the mech.

The exact visual implementation can evolve.

For the first prototype, simple placeholder sprites are completely acceptable.

---

# 28. Data vs Scenes

A major architectural principle:

> **Game data should not be tightly coupled to Godot scenes.**

For example:

Do not make the entire Raven mech exist only as a `Raven.tscn`.

Instead:

```text
MechData
```

describes the mech.

Then:

```text
BattleMech.tscn
```

visualizes the mech using that data.

Similarly:

```text
EquipmentData
```

describes equipment.

```text
CardData
```

describes cards.

Scenes should primarily handle:

* Visual representation
* Input
* Animation
* UI
* Node relationships

Data/resources should handle:

* Stats
* Configuration
* Equipment
* Card definitions
* Mech definitions
* Mission definitions

---

# 29. Recommended Godot Project Structure

Use this general structure:

```text
res://

scenes/
    main/
        Main.tscn

    command/
        Command.tscn
        Hangar.tscn
        Briefing.tscn

    overworld/
        Overworld.tscn
        OverworldGrid.tscn
        OverworldMech.tscn

    battle/
        Battle.tscn
        BattleGrid.tscn
        BattleMech.tscn
        BattleCard.tscn
        AttackCutIn.tscn

    ui/
        CardUI.tscn
        MechStatus.tscn
        TurnIndicator.tscn


scripts/
    game/
    command/
    overworld/
    battle/
    cards/
    mechs/
    equipment/
    enemies/
    ui/


data/
    mechs/
    equipment/
    cards/
    pilots/
    enemies/
    missions/


art/
    mechs/
    weapons/
    terrain/
    effects/
    pilots/
    ui/


audio/
    music/
    sfx/
```

The exact folder structure can change if there is a strong reason, but maintain clear separation between systems.

---

# 30. GameManager

Use a persistent `GameManager` autoload.

Responsibilities:

* Current game state
* Current mission
* Player squad
* Persistent mech state
* Transition between major game states
* Save/load coordination

Possible game states:

```text
COMMAND
OVERWORLD
BATTLE
```

Conceptual flow:

```text
GameManager
    ↓
COMMAND
    ↓
OVERWORLD
    ↓
BATTLE
    ↓
OVERWORLD
    ↓
COMMAND
```

Avoid putting combat logic inside `GameManager`.

It should coordinate high-level game state only.

---

# 31. OverworldManager

Responsible for strategic gameplay.

Responsibilities:

* Overworld grid
* Unit positions
* Player movement
* Enemy movement
* Turn progression
* Encounter detection
* Objectives
* Creating encounter data

Conceptual structure:

```text
OverworldManager
├── grid
├── player_mechs
├── enemies
├── objectives
├── current_turn
└── encounter_detector
```

---

# 32. EncounterData

When an encounter occurs, generate an object/data structure describing the battle.

Potential information:

```text
EncounterData
├── attacker
├── participants
├── encounter_location
├── encounter_direction
├── player_positions
└── enemy_positions
```

This data is passed into the battle system.

The battle system should not need to inspect the overworld directly.

This is important because it keeps the systems decoupled.

---

# 33. BattleDeployment

Create a dedicated system responsible for converting an encounter into battle starting positions.

Conceptual flow:

```text
EncounterData
      ↓
BattleDeployment
      ↓
Determine attacker anchor
      ↓
Translate relative positions
      ↓
Validate cells
      ↓
Create BattleState
      ↓
BattleManager
```

This system is where B3/B4 and future deployment rules should live.

---

# 34. BattleState

The tactical battle should have a data representation independent of the visual scene.

Potential structure:

```text
BattleState
├── grid
├── units
├── turn
├── phase
├── active_unit
├── winner
└── battle_status
```

The visual `Battle.tscn` displays the current `BattleState`.

This makes it easier to save, test, debug, and eventually support different presentation systems.

---

# 35. Enemy AI

Enemy AI should be a separate system.

Initial AI can be extremely simple.

Example:

```text
Enemy turn
    ↓
Find nearest player
    ↓
Move toward player
    ↓
If attack available
    ↓
Attack
```

Later it can become more sophisticated:

* Protect objective
* Maintain distance
* Focus weakest mech
* Defend another unit
* Use area attacks
* Retreat
* Flank
* Use terrain
* React to player cards

Do not build sophisticated AI initially.

---

# 36. Save Data

The architecture should eventually support persistent game state.

Potential persistent data:

```text
PlayerProgress
├── current_story_state
├── unlocked_mechs
├── mech_states
├── equipment
├── equipment_upgrades
├── pilots
├── missions
└── currency/resources
```

Do not over-engineer saving during the first prototype.

However, avoid architectural decisions that make persistent state impossible later.

---

# 37. Input

Input should be abstracted so mouse and touch can share the same game actions.

Core interactions:

```text
Select unit
Select cell
Move
Select card
Select target
Confirm action
Cancel
Open menu
```

Do not write separate gameplay logic for Android and PC.

Instead:

```text
Touch / Mouse
      ↓
Input system
      ↓
Game action
```

---

# 38. UI

The UI should be designed for landscape.

Battle UI might eventually look like:

```text
┌───────────────────────────────────────────────┐
│ ENEMY HP                         TURN 03       │
│                                               │
│             5 × 10 BATTLEFIELD               │
│                                               │
│                                               │
├───────────────────────────────────────────────┤
│ [CARD] [CARD] [CARD] [CARD] [CARD]            │
│                                               │
│ HP ████████     ENERGY / RESOURCES             │
└───────────────────────────────────────────────┘
```

The exact UI is not finalized.

Prioritize readability and touch targets over visual complexity.

---

# 39. Visual Style

The game is intended to be 2D.

The visual direction is currently inspired by:

* GBA-era games
* Anime/mecha
* Tactical RPGs
* Pixel art or stylized 2D illustration

The final art direction has not been locked.

AI-generated assets may be used for:

* Mech concepts
* Weapons
* Parts
* Pilots
* Terrain
* Backgrounds
* UI icons
* Attack cut-ins
* Effects

Consistency is more important than individual asset quality.

Mechs should ideally use a standardized visual specification so AI-generated assets can be refined into a consistent game style.

---

# 40. Development Philosophy

Do not attempt to build the entire game at once.

Build a playable vertical slice.

The first prototype should use ugly placeholder graphics.

The first goal is to prove:

```text
COMMAND
   ↓
DEPLOY
   ↓
OVERWORLD
   ↓
MOVE
   ↓
ENCOUNTER
   ↓
BATTLE
   ↓
5×10 GRID
   ↓
MOVE
   ↓
PLAY CARD
   ↓
DAMAGE ENEMY
   ↓
WIN
   ↓
RETURN TO OVERWORLD
```

If this loop works, the core architecture is proven.

---

# 41. Recommended Development Phases

## Phase 1 — Core Game Flow

Build:

* GameManager
* Command placeholder
* Overworld
* Grid movement
* Player mech
* Enemy mech
* Encounter detection
* Battle transition
* Battle return

Use simple colored squares.

---

## Phase 2 — Tactical Battle

Build:

* 5×10 battle grid
* Battle units
* Movement
* Turn system
* Basic attack
* HP
* Death
* Win/loss

Still use placeholders.

---

## Phase 3 — Card System

Build:

* Deck
* Draw pile
* Hand
* Card selection
* Card targeting
* Card resolution
* Discard
* Basic card effects

Start with approximately five cards.

---

## Phase 4 — Equipment

Build:

```text
Equipment
    ↓
Cards
    ↓
Deck
```

Add:

* Hand weapons
* Shoulder weapon
* Booster
* Backpack
* Equipment upgrades

---

## Phase 5 — Mech Identity

Add:

* Mech-specific cards
* Chassis stats
* Mech upgrades
* Different movement/defense characteristics

---

## Phase 6 — Encounter Deployment

Implement:

* Encounter direction
* Attacker anchor
* Relative overworld positions
* Battle deployment
* Different starting formations

This is where the overworld and tactical layer become deeply connected.

---

## Phase 7 — Terrain

Add:

* Cover
* Obstacles
* Destructible terrain
* Hazards
* Elevation if useful

---

## Phase 8 — Enemy AI

Start simple.

Then add tactical behavior as needed.

---

## Phase 9 — Command / Story

Add:

* Hangar
* Equipment UI
* Deck UI
* Story
* Mission selection
* Upgrades
* Repairs

---

## Phase 10 — Presentation

Add:

* Final mech art
* Animations
* VFX
* Sound
* Music
* Attack cut-ins
* Camera movement
* Screen shake
* UI polish

Special attack cut-ins should be added after the combat system works.

---

# 42. Important Architectural Rules

Follow these rules throughout development.

### Rule 1 — Keep systems modular

Do not create one enormous script containing:

* Overworld
* Battle
* Cards
* UI
* Mechs
* AI

Each system should have a clear responsibility.

### Rule 2 — Keep data separate from presentation

Mech stats should not live inside sprite scenes.

Card rules should not live inside card UI.

Combat calculations should not live inside animations.

### Rule 3 — Avoid hard-coded game assumptions

Do not assume:

* Exactly three player mechs
* Exactly three enemies
* Exactly one enemy
* A fixed battle size
* A fixed number of cards
* A fixed number of equipment slots

The current design may use those values, but the architecture should be configurable.

### Rule 4 — Prefer data-driven content

Adding a new mech should ideally mean creating a new `MechData` resource rather than modifying core combat code.

Adding a new card should ideally mean creating a new `CardData` resource and defining its effects.

Adding equipment should similarly be data-driven.

### Rule 5 — Build the smallest working version first

Do not add:

* Complex animations
* Advanced AI
* Elaborate story systems
* Large inventories
* Multiplayer
* Online services

until the core game loop is playable.

---

# 43. First Prototype Target

The first playable build should contain:

### Command

One screen:

```text
[ DEPLOY ]
```

### Overworld

Approximately:

```text
10 × 10
```

with:

* 3 player mechs
* 2–3 enemies
* Basic terrain
* Turn progression

### Encounter

Move a player mech onto an enemy.

Create an `EncounterData`.

Determine:

* Attacker
* Direction
* Participants
* Relative positions

### Battle

Create:

```text
5 × 10 grid
```

Place participating units.

Allow:

* Select mech
* Move
* Select card
* Attack
* Damage
* Destroy enemy

### End

Return to overworld.

That is the first milestone.

---

# 44. Long-Term Vision

The eventual game should feel like one interconnected system:

```text
                    COMMAND
                       │
              ┌────────┴────────┐
              │                 │
           MECHS             STORY
              │
        EQUIPMENT / CARDS
              │
              ▼
          OVERWORLD
              │
      ┌───────┴────────┐
      │                │
   POSITION         ENCOUNTER
      │                │
      └───────┬────────┘
              ▼
        BATTLE DEPLOYMENT
              │
              ▼
         5 × 10 BATTLE
              │
       ┌──────┼──────┐
       │      │      │
    MOVEMENT CARDS TERRAIN
       │      │      │
       └──────┼──────┘
              ▼
        COMBAT RESOLUTION
              │
              ▼
        ATTACK CUT-INS
              │
              ▼
        BATTLE OUTCOME
              │
              ▼
           OVERWORLD
              │
              ▼
           COMMAND
```

The goal is for every layer to reinforce the others.

**The overworld determines the encounter.**

**The encounter determines the battlefield setup.**

**The mech's equipment determines its cards.**

**The mech's chassis determines its identity.**

**The cards determine what the player can do.**

**The battlefield and terrain determine how those cards are used.**

**Special cards create the big cinematic moments.**

This should result in a game where customization, positioning, deck construction, and tactical combat all feel like parts of the same system rather than disconnected features.
