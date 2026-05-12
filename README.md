# Gravity Maze

## Project Description

Gravity Maze is a mobile game developed with Flutter in which the player controls a ball through a maze and tries to reach the goal while avoiding obstacles.

The game can be controlled using:
- device tilt (sensors)
- swipe gestures (in advanced levels)

The maze is procedurally generated and is always solvable thanks to a DFS (Depth-First Search) algorithm.

The project is structured using the MVC (Model–View–Controller) pattern to separate logic, data, and UI.

---

## Main Features

- Ball control using sensors (tilt) or gestures (flip mode)
- Random maze generation (always solvable)
- Star system (★☆☆ → ★★★) for each level
- Local progress saving using SharedPreferences
- Levels with:
  - timer
  - obstacles (holes)
  - square rotating board
- HUD displaying:
  - score
  - time
  - game state (win/lose)
- Double tap actions:
  - restart level
  - go to next level

---

## Project Structure (MVC)

### Model: GameModel
Manages the game state:
- maze layout
- ball position
- stars
- holes
- score

### Controller: GameController
Handles:
- sensor and gesture input
- ball physics
- timer system
- game logic
- saving stars (SharedPreferences)

### View: MazeView
Responsible for rendering:
- maze
- ball
- stars
- HUD and game messages

---

## Physics and Collision System

Ball physics is handled by:

**BallPhysics**

Key features:
- acceleration based on device sensors
- damping (friction)
- velocity limit
- wall collision detection
- separate X and Y axis movement
- controlled bounce effect

---

## Level System

Defined in:

**LevelData**

Each level may include:
- timer
- holes (instant death)
- square board layout
- different control modes (tilt / flip)

---

## Star System 

Each level contains 3 stars.

Each collected star = +10 points.

Final rating:
- ★☆☆ = 1 star
- ★★☆ = 2 stars
- ★★★ = 3 stars

Best results are saved locally.

---

## Data Persistence (SharedPreferences)

Stars are saved using keys such as:

level_1_stars → 3  
level_2_stars → 2  

Features:
- no permissions required
- persistent local storage
- simple key-value system

Implemented in `GameController` and read in `LevelSelectView`.

---

## Screens

### LevelSelectView
- level selection
- display saved stars

### MazeView
- main gameplay screen
- HUD with game information and status

---

## Maze Generation Algorithm

The maze is generated using DFS (Depth-First Search).

Steps:
1. Start from (0,0)
2. Mark cell as visited
3. Shuffle directions randomly
4. Visit unvisited neighbors
5. Remove walls between cells
6. Repeat recursively
7. Backtracking ensures full exploration

Guarantees:
- always a valid maze
- at least one path from start to goal

---

## Technologies Used

- Flutter
- Dart
- sensors_plus (accelerometer input)
- shared_preferences (local storage)

---

## Possible Future Improvements

- Level unlocking system
- Cloud save support
- Sound effects
- More advanced animations
- Improved UI design

---

## Run Project

```bash
flutter pub get
flutter run
