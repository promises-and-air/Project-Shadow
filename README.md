# Fantasy First-Person Roguelike

First-person roguelike set in a fantasy world featuring a demonic left hand and advanced movement system.

## 🎮 About

This is my first serious project in Godot 4, inspired by Titanfall/Apex movement mechanics and Hades gameplay.

**Development started:** October 2, 2025

## ✨ Implemented Features

### Movement System
- ✅ **Bunny hopping** with momentum preservation
- ✅ **Air strafe** mechanics (Source Engine style)
- ✅ **Wall running** with side detection
- ✅ **Wall jump** with proper physics
- ✅ **Slide** with dual-curve drag system
- ✅ **Dash** with momentum preservation
- ✅ **Mantle** system with crouch boost combo
- ✅ **Double jump**

### Additional Mechanics
- ✅ **Grappling hook** with spring physics
- ✅ **Jump pads** for vertical boost

### Systems
- ✅ **State Machine** for player state management
- ✅ **Viewmodel system** with procedural animations:
  - Head bob
  - Landing impact
  - Free fall effects
  - Jump kick
  - Weapon sway
  - State-aware animations (slide/dash/mantle)
- ✅ **ProceduralCurve** system for smooth animations

### Camera
- ✅ First-person camera with viewmodel
- ✅ Player camera with procedural effects

## 🛠️ Tech Stack

- **Engine:** Godot 4.x
- **Language:** GDScript
- **Architecture:** State Machine pattern
- **Physics:** CharacterBody3D
- **3D Modeling & Animation:** Blender

## 📚 What I Learned

During 12 days of development (Oct 2-14):
- Working with Godot 4
- Advanced FPS movement physics
- State Machine pattern implementation
- Procedural viewmodel animation
- Signal-based architecture
- Git and version control workflow
- Blender to Godot animation pipeline
- Mixing baked (Blender) and procedural (Godot) animations

## 🎯 Roadmap

### Near Future
- [ ] Basic combat system (6-7 weapon types)
- [ ] Combo system (4-6 hits)
- [ ] Demonic hand mechanics
- [ ] First test level
- [ ] Weapon animations in Blender

### Long-term
- [ ] Procedural level generation
- [ ] Progression system
- [ ] Roguelike elements
- [ ] Enemies and AI
- [ ] Audio and visual effects
- [ ] Advanced character animations

## 🏗️ Project Structure
Scripts/
├── PlayerMovement.gd # Main player controller
├── playerCamera.gd # Camera with effects
├── viewmodel_camera.gd # Viewmodel animations
├── GrappleHook.gd # Grapple system
├── ProceduralCurve.gd # Animation utility
└── States/ # State Machine
├── State.gd # Base class
├── StateMachine.gd # FSM controller
├── GroundState.gd
├── AirState.gd
├── SlideState.gd
├── DashState.gd
└── MantleState.gd


## 🎨 Animation Pipeline

The project uses a hybrid animation approach:

- **Procedural animations** (coded in GDScript): Head bob, sway, landing effects
- **Baked animations** (created in Blender): Weapon attacks, reloads, character movements
- **Mixed animations**: Combining Blender keyframe animations with procedural effects for dynamic, responsive gameplay

## 📝 Development History

**October 2, 2025** - Project Start
- Used Godot's default movement template
- Didn't know how to add hands and camera

**October 3-7** - Core Systems
- Figured out first-person controller
- Added viewmodel camera
- Implemented basic movement
- Started learning Blender for animations

**October 8-12** - Advanced Mechanics
- Implemented State Machine
- Added wall run, mantle, dash
- Integrated grappling hook
- Created procedural animation system
- Set up Blender to Godot animation workflow

**October 13-14** - Polish and Refactoring
- Full codebase code review
- Bug fixes
- GitHub setup
- Project documentation

## 📊 Stats

- **Development time:** 12 days
- **Lines of code:** ~2000+ (GDScript)
- **Files:** 15+ scripts
- **Commits:** Documentation in progress

## 🎓 Inspiration

- **Titanfall 2** - movement system
- **Apex Legends** - wall run and momentum
- **Hades** - roguelike gameplay


*Project is in active development*

