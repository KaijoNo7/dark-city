# Technical documentation

This section covers the nuts and bolts: how the project is configured, how input and physics are
set up, the developer tools that generate content, and how to test and ship the game.

| Document | Read it when you want to… |
|---|---|
| [01 — Project settings](01-project-settings.md) | understand the resolution, scaling, pixel snapping, renderer and other `project.godot` settings |
| [02 — Input & physics](02-input-and-physics.md) | add a control, rebind a key, or understand collision layers and masks |
| [03 — Tools & asset pipeline](03-tools-and-pipeline.md) | regenerate the sprite animations, the tileset, or the level from code |
| [04 — Testing, debugging & export](04-testing-debugging-export.md) | run the automated playtest bot, debug a problem, or export a build |
| [05 — Settings, save games & controllers](05-settings-saves-controllers.md) | know every option, the save file format, how gamepads are detected and how rebinding works |

## Requirements at a glance

| Requirement | Detail |
|---|---|
| Godot | 4.7 (standard build; the .NET build is not needed, there is no C#) |
| GPU | Vulkan-capable (Forward+ renderer). On Windows the project asks for Direct3D 12 (`rendering_device/driver.windows="d3d12"`). |
| OS | Anything Godot 4.7 runs on: Linux, Windows, macOS |
| Extra software | None to play or build. Only to *regenerate audio*: Python 3 + numpy and ffmpeg (see [03](03-tools-and-pipeline.md#audio-tools)). |
