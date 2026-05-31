# acceMaze

**Android Project — Accelerometer-Controlled Maze Game**  

---

## Overview

**acceMaze** is a mobile maze game where the player guides a steel ball from the top-left corner to the goal in the bottom-right corner of a procedurally generated maze. Along the way, stars can be collected while avoiding obstacles such as holes, special surfaces, and portals.

The game features local user authentication with separate profiles, 10 levels of increasing difficulty, two control modes, and a context-aware audio system.

### Control Modes

| Mode | Description |
|------|-------------|
| **Tilt** | Physically tilt the device — the accelerometer converts the tilt angle into force applied to the ball |
| **Flip** | Horizontal swipe to rotate the board 90° — gravity direction changes accordingly |

---

## Architecture (MVC)

```
lib/
├── model/
│   ├── game_model.dart        ← maze and ball state
│   └── level_data.dart        ← definition of all 10 levels
├── controller/
│   ├── game_controller.dart   ← game logic, input, timer
│   └── ball_physics.dart      ← physics engine
├── service/
│   ├── auth_service.dart      ← authentication and user profiles
│   └── audio_service.dart     ← music and sound effects
└── view/
    ├── auth_view.dart             ← login and registration
    ├── level_select_view.dart     ← level grid and user profile
    ├── maze_view.dart             ← gameplay screen
    └── audio_settings_dialog.dart ← audio settings
```

---

## Core Components

### GameModel
Holds the entire state of the current game session:
- **Maze grid** — `rows × cols` matrix of cells with 4 open-wall flags (N, E, S, W), generated via recursive DFS with backtracking (always connected and solvable)
- **Ball state** — position, velocity, radius (20% of the minimum cell dimension)
- **Game objects** — collectible stars (max 3), holes, portals
- **Special surfaces** — `(col, row) → SurfaceType` map for ice and mud
- **Game state** — `score`, `isDead`, `isWin`, `isTimeOver`, `timeLeft`, `levelIndex`

### GameController
Runs the game loop at **60 fps** (tick every 16 ms) via `Timer.periodic`.

**Input:**
- *Tilt* — accelerometer via `accelerometerEventStream()` with an exponential moving average low-pass filter (α = 0.15) to smooth sensor noise
- *Flip* — `onPanEnd` triggers a 90° board rotation animation with `easeInOutCubic` curve (duration: 0.35 s)

**UI Callbacks:**

| Callback | Event |
|----------|-------|
| `onStarCollected` | Ball collects a star |
| `onHoleDeath` | Ball falls into a hole |
| `onPortalEnter` | Ball passes through a portal |
| `onSurfaceChanged(type)` | Ball moves onto a new surface type |
| `onBoardRotate(dir)` | Board rotation starts (flip mode) |

### BallPhysics
- Acceleration derived from the accelerometer (tilt) or from a fixed gravity vector rotated mathematically (flip)
- Collision detection via `Rect.fromCircle` overlapping wall rectangles
- On collision: bounce along the affected axis with coefficient 0.05

### AuthService
Fully local management via `SharedPreferences`:
- **User database** — profiles serialized as JSON under the key `users_db`
- **Password hashing** — SHA-256 via the `crypto` package (plaintext passwords are never stored)
- **Session** — current username stored under `current_user`
- **Data isolation** — star keys are prefixed with the username → different users on the same device do not share progress
- **Guest mode** — data saved during the session, cleared on logout

---

## Game Mechanics

### Maze Generation
Each game start regenerates the maze using recursive DFS with a random seed, guaranteeing infinite variety. Stars and holes are placed randomly, excluding the start and goal cells and any cells adjacent to portals (safe zone = 6 × ball radius).

### Stars and Score
Each level contains 3 collectible stars. Each star is worth 10 points. The final score converts to a star rating (`score / 10`, max 3).

### Special Surfaces

| Surface | Friction | Effect |
|---------|----------|--------|
| Normal (wood) | 5.0 | Standard behaviour |
| Ice | 0.6 | Slippery, hard to control |
| Mud | 22.0 | Movement heavily slowed |

### Portals
Bidirectional pairs (A ↔ B): a ball entering A teleports to B, and vice versa.

### Holes
Circular traps that instantly end the game. Collision radius = 0.95 × `ballRadius`. Present in 7 out of 10 levels.

### Timer
6 out of 10 levels have a countdown. When time runs out the game ends. The timer bar turns red below 10 seconds.

---

## Level Structure

| Level | Grid | Control | Timer | Holes | Surfaces | Portals |
|-------|------|---------|-------|-------|----------|---------|
| 1 – Tutorial | 5×7 | Tilt | — | No | — | — |
| 2 | 5×7 | Tilt | — | Yes | Ice | — |
| 3 | 5×7 | Tilt | 40 s | Yes | Ice | — |
| 4 | 5×7 | Tilt | 45 s | No | Mud | 2 |
| 5 | 5×5 | Flip | — | Yes | — | — |
| 6 | 5×5 | Flip | 40 s | No | Mud | 2 |
| 7 | 5×5 | Flip | — | Yes | Ice | — |
| 8 | 5×5 | Flip | 35 s | Yes | Ice | 2 |
| 9 | 5×7 | Tilt | 45 s | Yes | Ice + Mud | 2 |
| 10 – Final | 5×5 | Flip | 40 s | Yes | Ice + Mud | 2 |

---

## Progression and Unlocking

- **Level 1** is always available
- Each subsequent level unlocks by earning **at least 1 star** in the previous level
- Best star results per level are saved per user and persist across sessions
- **Achievements** are awarded for completing a level with 3 stars (*"Level N: three stars!"*)
- **Rank title** updates based on total stars earned across all levels:

| Total Stars | Rank |
|-------------|------|
| 0 – 5 | Novice |
| 6 – 9 | Beginner |
| 10 – 14 | Explorer |
| 15+ | Maze Master |

---

## User Interface

### AuthView
Login and registration screen with optional guest access. Local validation: username ≥ 3 characters, email must contain `@`, password ≥ 6 characters. Password visibility toggle included.

### LevelSelectView
User profile panel (avatar with initial, username, rank title, total stars) and a 2-column level grid showing earned stars and mechanic icons (timer, holes, ice, mud, portals).

### MazeView
Rendered entirely via `CustomPainter`:
- Wood-textured background, maze board with drop shadow
- Walls, ice/mud cells, animated portals, steel ball with specular highlights
- Particle system (60 particles) for the victory effect
- **Bottom HUD** — current stars, active surface indicator, timer bar, status messages

---

## Audio System

Implemented with the `audioplayers` package. Background music (looped) and sound effects (stars, death, portal, surfaces, victory) run on separate players with independent audio contexts, allowing simultaneous playback without interruption. Music and SFX volume are individually adjustable and persisted in `SharedPreferences`.

---

## Technical Details

| Aspect | Solution |
|--------|----------|
| Framework | Flutter / Dart |
| Persistence | `shared_preferences` (JSON for profiles, primitive keys for stars) |
| Security | SHA-256 password hashing (`package:crypto`) |
| Sensors | `sensors_plus` — accelerometer |
| Audio | `audioplayers` |
| Physics | Custom engine, per-axis sweep, 60 fps |
| Animations | `AnimationController` + `CustomPainter` |
| Orientation | Locked portrait (`portraitUp` / `portraitDown`) |
| Map generation | Recursive DFS with backtracking |

---

## Getting Started

```bash
flutter pub get
flutter run
```

> A physical Android device is required for the accelerometer to work in Tilt mode.
