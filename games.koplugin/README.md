# Games Plugin for KOReader

A comprehensive gaming plugin that brings classic games directly to your KOReader environment, including authentic original Doom gameplay.

## Features

### Included Games
- **Tetris**: Classic block-stacking puzzle game with multiple piece types and line clearing
- **Snake**: Navigate the snake to eat food and grow while avoiding walls and yourself
- **Pong**: Classic paddle game with AI opponent
- **Minesweeper**: Logic puzzle game with hidden mines and numbered clues
- **Original Doom**: Authentic Doom gameplay using real Doom ports and original WAD files

### On-Screen Controls
All games feature intuitive on-screen controls optimized for touchscreen devices:
- Directional buttons for movement
- Game-specific action buttons
- Pause/Resume functionality
- Exit option

### Original Doom Features
The plugin integrates with real Doom ports to provide authentic original Doom gameplay:
- **Authentic Experience**: Uses real Doom engine ports (chocolate-doom, prboom-plus, crispy-doom, etc.)
- **Original WAD Support**: Load and play original DOOM.WAD, DOOM2.WAD, or compatible WAD files
- **Full Game Features**: Complete original Doom experience with all weapons, enemies, levels, and mechanics
- **Touch Controls**: Custom on-screen controls integrated with KOReader for Doom input
- **Process Management**: Launches Doom as a separate window while providing control interface

#### Supported Doom Ports
The plugin automatically detects and uses available Doom ports in order of preference:
1. **chocolate-doom** (most authentic to original)
2. **prboom-plus** (enhanced features)
3. **crispy-doom** (quality of life improvements)
4. **gzdoom** (modern features)
5. **zdoom** (advanced port)
6. **freedoom** (free alternative)

## Installation

1. Download the games.koplugin folder
2. Copy it to your KOReader plugins directory (typically `koreader/plugins/`)
3. **For Doom**: Install a compatible Doom port using your system package manager:
   - Ubuntu/Debian: `sudo apt install chocolate-doom` or `sudo apt install prboom-plus`
   - Fedora: `sudo dnf install chocolate-doom` or `sudo dnf install prboom-plus`
   - Arch: `sudo pacman -S chocolate-doom` or `sudo pacman -S prboom-plus`
4. Restart KOReader
5. Access games from the "More tools" menu

## Usage

### Launching Games
1. Open KOReader menu
2. Navigate to "More tools" → "Games"
3. Select your desired game from the list
4. Use on-screen controls to play

### Playing Original Doom
1. Select "Original Doom" from the games menu
2. Choose a WAD file using the file picker (DOOM.WAD, DOOM2.WAD, etc.)
3. **Note**: This launches the actual original Doom game using authentic Doom ports
4. The game opens in a separate window with full original gameplay
5. Use the KOReader control interface to control the game:
   - **Movement**: Forward, Back, Turn Left/Right, Strafe Left/Right
   - **Actions**: Fire, Use, Run
   - **Weapons**: Direct weapon selection (Fist, Pistol, Shotgun, etc.)
   - **Map**: Toggle automap
   - **Pause**: Game pause functionality

#### Getting WAD Files
You need original WAD files to play Doom:
- **DOOM.WAD**: Original Doom (shareware version available free)
- **DOOM2.WAD**: Doom II (commercial)
- **FREEDOOM1.WAD/FREEDOOM2.WAD**: Free alternatives (available from freedoom.github.io)
- **PLUTONIA.WAD/TNT.WAD**: Final Doom episodes

Place WAD files in a directory accessible to KOReader (e.g., `/sdcard/doom/` or `/mnt/onboard/games/`).

#### Doom Controls Mapping
The on-screen controls map to standard Doom keys:
- **Forward/Back**: Up/Down arrow keys
- **Turn Left/Right**: Left/Right arrow keys  
- **Strafe Left/Right**: Comma/Period keys
- **Fire**: Ctrl key
- **Use**: Spacebar
- **Run**: Shift key
- **Weapons 1-7**: Number keys 1-7
- **Map**: Tab key
- **Pause**: Escape key

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
- Canvas-based rendering system for simple games
- Process management system for Doom integration
- Event-driven input handling

### Doom Integration
- **Process Management**: Launches Doom as separate process
- **Input Forwarding**: Uses xdotool to send keyboard input to Doom window
- **Window Management**: Handles Doom window focus and control
- **Configuration**: Creates temporary Doom config files for optimal e-reader settings

### Performance
- Optimized for e-ink displays
- Adjustable frame rates per game
- Efficient rendering using KOReader's widget system
- Doom runs natively with full performance

### Compatibility
- Works on all KOReader-supported Linux devices
- Touch and keyboard input support
- Responsive UI scaling
- **Doom Requirements**: Linux system with X11 for window management

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

### Doom-Specific Troubleshooting
- **"No Doom port found"**: Install a compatible Doom port using your package manager
- **WAD file not loading**: Verify WAD file is valid and accessible
- **Doom window doesn't respond to controls**: Ensure xdotool is installed (`sudo apt install xdotool`)
- **Doom starts but no control**: Check that the Doom window has focus
- **Performance issues**: Doom runs at native speed; any issues are system-related

### Installation Issues
- **Missing dependencies**: Install required packages:
  ```bash
  # Ubuntu/Debian
  sudo apt install chocolate-doom xdotool
  
  # Fedora
  sudo dnf install chocolate-doom xdotool
  
  # Arch
  sudo pacman -S chocolate-doom xdotool
  ```

### Performance Issues
- Simple games: Lower frame rates on older devices is normal
- Doom: Runs at full native performance
- Close other applications for better performance
- Ensure sufficient free memory

## Requirements

- KOReader v2023.01 or later running on Linux
- **For Doom**: 
  - Compatible Doom port installed (chocolate-doom, prboom-plus, etc.)
  - xdotool for input handling (`sudo apt install xdotool`)
  - Valid IWAD file (DOOM.WAD, DOOM2.WAD, FREEDOOM1.WAD, etc.)
  - X11 display server (standard on most Linux systems)
- Minimum 100MB free space for installation with WAD files

## License

This plugin is distributed under the same license as KOReader.

## Credits

Based on KOReader plugin architecture and classic game implementations.
Doom integration uses authentic Doom engine ports for original gameplay experience.