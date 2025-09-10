# Compatibility Notes

## KOReader Version Requirements
- KOReader v2023.01 or later recommended
- Tested widget compatibility with standard KOReader UI components

## Device Compatibility
- All KOReader-supported devices
- Optimized for e-ink displays with conservative color usage
- Touch and keyboard input support

## Performance Considerations
- Games use configurable frame rates (Tetris: 0.5s, Snake: 0.2s, Pong: 0.03s, etc.)
- Optimized rendering using KOReader's Blitbuffer system
- Memory efficient game state management

## Known Limitations
- Doom engine is simplified demonstration version
- For full Doom experience, a complete engine port would be required
- Colors are limited to standard KOReader palette for e-ink compatibility

## Installation Notes
1. Copy entire games.koplugin folder to KOReader plugins directory
2. Restart KOReader
3. Access via More Tools menu
4. For Doom: Ensure WAD files are accessible in device storage

## Future Enhancements
- Additional game types
- Enhanced Doom engine implementation
- Multiplayer support
- Save/load game states
- Achievement system