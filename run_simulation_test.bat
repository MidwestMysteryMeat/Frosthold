@echo off
REM FROSTHOLD Simulation Test Runner
REM Usage: run_simulation_test.bat [scenario]
REM Scenarios: quick, survival, endurance, combat, building, persistence, full

set SCENARIO=%1
if "%SCENARIO%"=="" set SCENARIO=survival

echo Running FROSTHOLD simulation test: %SCENARIO%
echo.

REM Set globals for simulation mode
set SIMULATION_TEST=true
set SIMULATION_SCENARIO=%SCENARIO%

REM Run with Love2D (adjust path if needed)
love . --console %*

echo.
echo Test complete. Check the save directory for results JSON.
