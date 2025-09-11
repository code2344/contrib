# Games Plugin for KOReader

A comprehensive gaming plugin that brings classic games directly to your KOReader environment.

## Features

### Included Games
- **Tetris**: Classic block-stacking puzzle game with multiple piece types and line clearing
- **Snake**: Navigate the snake to eat food and grow while avoiding walls and yourself
- **Pong**: Classic paddle game with AI opponent
- **Minesweeper**: Logic puzzle game with hidden mines and numbered clues
- **Doom-Style Game**: A Doom-inspired raycasting game with basic WAD file support

### On-Screen Controls
All games feature intuitive on-screen controls optimized for touchscreen devices:
- Directional buttons for movement
- Game-specific action buttons
- Pause/Resume functionality
- Exit option

### Doom-Style Game Features
The plugin includes a simplified Doom-inspired game with basic WAD file support:
- **Note**: This is NOT the original Doom game, but a simplified recreation
- Basic WAD file parsing for level geometry (VERTEXES, LINEDEFS, SIDEDEFS, SECTORS, THINGS)
- Simple raycasting 3D renderer optimized for e-ink displays
- Basic entity system with enemies, items, and weapons
- Simplified game mechanics: health, armor, ammo, and scoring
- Basic enemy behavior (not original Doom AI)
- Limited weapon types: Fist, Shotgun, Chaingun, Rocket Launcher
- Basic collision detection and movement

## Installation

1. Download the games.koplugin folder
2. Copy it to your KOReader plugins directory (typically `koreader/plugins/`)
3. Restart KOReader
4. Access games from the "More tools" menu

## Usage

### Launching Games
1. Open KOReader menu
2. Navigate to "More tools" → "Games"
3. Select your desired game from the list
4. Use on-screen controls to play

### Playing the Doom-Style Game
1. Select "Doom-Style Game" from the games menu
2. Choose a WAD file using the file picker (DOOM.WAD, DOOM2.WAD, etc.)
3. **Important**: This loads only the level geometry from WAD files
4. **Note**: This is a simplified recreation, not the original Doom game
5. Use the movement and combat controls:
   - ↑/↓: Move forward/backward
   - ◄/►: Turn left/right
   - ←/→: Strafe left/right
   - Fire: Attack with current weapon
   - Use: Activate doors, switches, and pickups
   - Weapon: Switch between available weapons
   - Pause: Pause game (press again when dead to restart)

#### Doom-Style Game Features
- **Simplified Combat**: Fight against basic enemies with simple AI behavior
- **Basic Weapons**: Fist, Shotgun, Chaingun, Rocket Launcher with simplified mechanics
- **Health & Armor**: Basic health and armor system
- **Level Geometry**: Loads level layout from WAD files for exploration
- **Simple Scoring**: Basic point system for defeating enemies
- **Collision Detection**: Basic movement and collision system
- **Item Collection**: Simple pickup system for weapons, ammo, and health

**Important Limitations**:
- This is NOT the original Doom game engine
- Simplified AI and game mechanics
- Basic graphics optimized for e-ink displays
- Limited compared to authentic Doom experience

### Game Controls

#### Tetris
- ←/→: Move piece left/right
- ↻: Rotate piece
- ↓: Drop piece quickly
- Pause: Pause game

#### Snake
- ↑/↓/←/→: Change direction
- Pause: Pause game

#### Pong
- ↑/↓: Move paddle up/down
- Stop: Stop paddle movement
- Pause: Pause game

#### Minesweeper
- ↑/↓/←/→: Move selection
- Reveal: Reveal selected cell
- Flag: Flag/unflag selected cell
- Pause: Pause game

## Technical Details

### Architecture
- Modular design with base game class
- Individual game modules for each game type
- Canvas-based rendering system
- Event-driven input handling

### Performance
- Optimized for e-ink displays
- Adjustable frame rates per game
- Efficient rendering using KOReader's widget system

### Compatibility
- Works on all KOReader-supported devices
- Touch and keyboard input support
- Responsive UI scaling

## Adding Custom Games

The plugin architecture supports adding new games:

1. Create a new game module extending `BaseGame`
2. Implement required methods:
   - `initGame()`: Initialize game state
   - `addGameControls()`: Add control buttons
   - `updateGame()`: Update game logic
   - `renderGame()`: Render graphics
3. Add to main menu in `main.lua`

## Troubleshooting

### Common Issues
- **Game won't start**: Check that all required files are present and paths are correct
- **Controls not responding**: Ensure KOReader is up to date and touch interface is working
- **Doom WAD not loading**: Verify WAD file is valid, accessible, and is an official IWAD/PWAD
- **Doom crashes or freezes**: Large levels may require more memory; try simpler WAD files first
- **Poor Doom performance**: Complex levels may run slowly on older devices; this is normal

### Doom-Specific Troubleshooting
- **"Loading WAD file..." stuck**: WAD file may be corrupted or incompatible
- **No enemies/items appear**: WAD file may be missing THINGS data
- **Level geometry missing**: WAD file may have corrupted level data
- **Controls feel sluggish**: Adjust movement speed in game settings if available

### Performance Issues
- Lower frame rates on older devices is normal
- Close other applications for better performance
- Ensure sufficient free memory

## Requirements

- KOReader v2023.01 or later
- For Doom: Valid IWAD file (DOOM.WAD, DOOM2.WAD, PLUTONIA.WAD, TNT.WAD) or compatible PWAD
- Minimum 100MB free space for full installation with WAD files
- Sufficient memory for complex level geometry (typically 64MB+ recommended for Doom)

## License

This plugin is distributed under the same license as KOReader.

## Credits

Based on KOReader plugin architecture and classic game implementations.
WAD file format support based on Doom engine specifications.