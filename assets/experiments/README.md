# 3D Cat Model — Proof of Concept

> Experiment: turning the copilot-cat 2D SVG sprites into a 3D model
> rendered with Qt Quick 3D.

## What Is This?

A proof-of-concept that generates a low-poly 3D chibi cat mesh matching the
existing Catppuccin color palette, and a Qt Quick 3D viewer to display it
with lighting, rotation, and camera controls. This explores whether the
copilot-cat desktop pet could be rendered in 3D instead of using 2D SVG
sprite sheets.

## Quick Start

### 1. Generate the 3D Model

```bash
cd assets/experiments
pip install numpy          # only dependency (trimesh not required)
python cat_3d_concept.py
```

This creates:
- `cat_model.obj` — Wavefront OBJ mesh (~3000-4000 faces)
- `cat_model.mtl` — Material library with Catppuccin palette colors

### 2. View the Model

```powershell
# Requires Qt 6.x with QtQuick3D module installed
$env:PATH = "C:\Qt\6.8.3\msvc2022_64\bin;" + $env:PATH
qml cat_3d_viewer.qml
```

Controls:
- **Drag** to rotate the model (with auto-rotate off)
- **Scroll** to zoom in/out
- **Auto-rotate checkbox** toggles continuous rotation

### 3. Alternative Viewers

The `.obj` file is a standard Wavefront OBJ — you can also open it in:
- Blender (free, full-featured)
- Windows 3D Viewer
- VS Code with the "3D Viewer" extension
- Any 3D modeling software

## Architecture

```
cat_3d_concept.py     # Mesh generator (pure Python + numpy)
  └─> cat_model.obj   # Output mesh (vertices, faces, materials)
  └─> cat_model.mtl   # Material definitions (Catppuccin colors)

cat_3d_viewer.qml     # Qt Quick 3D viewer
  └─ reads cat_model.obj
  └─ PerspectiveCamera + DirectionalLight + orbit animation
```

### Cat Anatomy (3D Parts)

| Part | Primitive | Material |
|------|-----------|----------|
| Head | Ellipsoid (1.8 × 1.7 × 1.6) | body `#7f849c` |
| Body | Ellipsoid (2.0 × 1.3 × 1.4) | body `#7f849c` |
| Belly | Front-facing ellipsoid | belly `#bac2de` |
| Chest | Small ellipsoid | chest `#cdd6f4` |
| Ears | Cones with inner cone | body + ear_inner `#cdd6f4` |
| Eyes | Spheres (heterochromia) | blue `#89b4fa` / amber `#fab387` |
| Nose | Small sphere | nose `#f38ba8` |
| Legs | Cylinders (4×) | body `#7f849c` |
| Paws | Spheres + toe beans | paw `#f5c2e7` |
| Tail | Bezier tube (tapered) | body `#7f849c` |
| Heart | 2 spheres + cone | pink `#f5c2e7` |

## Integration Into Main App

To replace the current SVG sprite system with 3D rendering:

### Required Changes

1. **Add QtQuick3D dependency** to `CMakeLists.txt`:
   ```cmake
   find_package(Qt6 REQUIRED COMPONENTS Quick Quick3D)
   target_link_libraries(copilot-cat PRIVATE Qt6::Quick3D)
   ```

2. **Replace SVG Image elements** in `Main.qml` / `Debug.qml` with a
   `View3D` viewport containing the cat `Model`.

3. **Animation system**: Replace sprite-frame switching with skeletal
   animation or programmatic transforms on the 3D model's joints.

4. **Asset bundling**: Include `.obj` in Qt resources (`qrc`) or convert
   to Qt Quick 3D's native `.mesh` format using `balsam` tool.

5. **Transparency**: The `View3D` can render with a transparent background
   to maintain the desktop-pet overlay aesthetic.

## Pros vs Cons

### 3D Approach ✨

**Pros:**
- Smooth rotation and viewing from any angle
- Single model replaces 12+ SVG sprite files
- Animation via transforms (walk = leg rotation) instead of separate frames
- Easy to add new poses/expressions without drawing new sprites
- Better lighting and depth effects
- Qt Quick 3D integrates natively with Qt Quick (same scene graph)

**Cons:**
- Higher GPU requirements (QtQuick3D needs OpenGL 3.3+ or Vulkan)
- More complex asset pipeline (modeling, rigging, UV mapping)
- Larger binary size (QtQuick3D module is ~20MB)
- Current SVGs are hand-crafted pixel-perfect; 3D loses that control
- QtQuick3D is newer/less mature than Qt Quick 2D
- Potential transparency/compositing issues on some window managers

### Current SVG Approach 🎨

**Pros:**
- Lightweight, works everywhere (even qmlscene)
- Pixel-perfect at any size
- Simple to understand and modify (Python generators)
- Tiny file sizes (~2KB per SVG)
- No GPU requirements beyond basic 2D

**Cons:**
- Need separate SVG for every pose/direction (12+ files)
- Adding new animations means drawing new frames
- No smooth transitions between poses
- Fixed viewpoint (always side/front view)

## Next Steps (If Pursuing 3D)

### Phase 1: Model Refinement
- [ ] Import into Blender, clean up topology
- [ ] Add proper UV mapping for texture details
- [ ] Optimize polygon count (target: 2000-3000 faces)
- [ ] Add mouth, whiskers as geometry (currently simplified)

### Phase 2: Rigging & Animation
- [ ] Add armature/skeleton (spine, legs, tail, head, ears)
- [ ] Create animation clips: idle, walk, sit, pounce, land
- [ ] Export as glTF 2.0 (Qt Quick 3D's preferred format)
- [ ] Implement `AnimationController` in QML

### Phase 3: Integration
- [ ] Replace `Image` sprite in Debug.qml with `View3D`
- [ ] Map existing animation state machine to 3D animations
- [ ] Handle transparency overlay on desktop
- [ ] Test performance on target platforms
- [ ] Add shader effects (outline, glow) to match 2D aesthetic

### Phase 4: Polish
- [ ] Custom cel-shading to maintain the 2D "flat" look in 3D
- [ ] Facial expressions via morph targets (blend shapes)
- [ ] Procedural ear/tail movement (physics-based secondary motion)
- [ ] Dynamic eye tracking (look at cursor)

## Dependencies

- **Python 3.7+** with `numpy` (for mesh generation)
- **Qt 6.x** with `QtQuick3D` module (for the viewer)
- No other dependencies required
