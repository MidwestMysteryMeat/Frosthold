# FROSTHOLD — PC System Requirements

## Minimum
- **OS:** Windows 7 / macOS 10.9 / Ubuntu 18.04
- **CPU:** Any dual-core, 1.5 GHz+
- **RAM:** 2 GB
- **GPU:** OpenGL 2.1 compatible (any integrated GPU from ~2010+)
- **Storage:** 100 MB
- **Resolution:** 960x540

## Recommended
- **OS:** Windows 10/11 / macOS 12+ / Ubuntu 22.04
- **CPU:** Any quad-core, 2.5 GHz+
- **RAM:** 4 GB
- **GPU:** OpenGL 3.3 compatible (any dedicated or modern integrated GPU)
- **Storage:** 200 MB
- **Resolution:** 1280x720 or higher

## Technical Notes
- **Engine:** Love2D 11.4 / LuaJIT
- **Sim tick rate:** 20Hz fixed timestep, rendering decoupled
- **Performance profile:** CPU-bound (tile simulation, pathfinding, ECS), not GPU-bound
- **Scaling factors:** Larger colonies (20+ colonists), deep z-levels, and big maps benefit from faster single-thread CPU performance
- **Network:** None required (singleplayer)
