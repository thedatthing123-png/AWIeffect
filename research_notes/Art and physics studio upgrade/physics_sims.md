# Physics Studio for a Mobile Video Editor: Blender Feature Reference and Real-Time 2D Techniques (iOS / Metal)

Note on sourcing: docs.blender.org returned HTTP 403 to the fetch tool, so the Blender facts below were read from the Blender manual bundled with the Blender MCP server (the same RST source as docs.blender.org). Their URLs are the matching docs.blender.org pages. Default values marked "(Blender default, from training knowledge)" were not checked against a live page in this session, so they should be confirmed in-app before they ship.

## 1. Blender physics systems: features and key parameters (the reference spec)

### Takeaway
Blender splits physics into Rigid Body (Bullet), Soft Body (springs plus a goal), Cloth (mass-spring with tension, compression, shear and bending stiffness, plus pressure), Fluid (Mantaflow FLIP liquid with viscosity and surface tension), Particles (Newtonian, plus SPH "Fluid" particles), Force Fields and Collision. A phone "physics studio" can copy this vocabulary one-for-one: users already know these slider names from YouTube tutorials.

### Cited Findings
**Rigid body**
- Bounciness (restitution) runs from 0 to 1, rigid to perfectly elastic. The collision margin ("Sensitivity") trades stability for exactness: some shapes embed the margin, others show a visible gap — [Blender Manual: Rigid Body Collisions](https://docs.blender.org/manual/en/latest/physics/rigid_body/properties/collisions.html)
- Shapes include Box, Sphere, Capsule, Cylinder, Cone, Convex Hull and Mesh. Friction default is 0.5, bounciness 0, margin 0.04 (Blender default, from training knowledge). Constraint types include Fixed, Point, Hinge, Slider, Piston, Generic, Generic Spring and Motor — [Blender Manual: Rigid Body Constraints](https://docs.blender.org/manual/en/latest/physics/rigid_body/constraints/index.html)

**Soft body**
- A Goal is "a shape that a soft body object tries to conform to". It pins vertices to their animated position, weighted per vertex by a vertex group and scaled by Goal Strength — [Blender Manual: Soft Body Exterior Forces](https://docs.blender.org/manual/en/latest/physics/soft_body/forces/exterior.html)
- Goal Stiffness sets spring strength to the goal, from a weak, flexible attachment to a stiff one. Goal Damping is friction, so higher values mean "little jiggle" and motion that settles quickly — [Blender Manual: Soft Body Goal](https://docs.blender.org/manual/en/latest/physics/soft_body/settings/goal.html)
- Two things prevent collapse. Edge Stiffness adds diagonal springs: without it a quad cube collapses completely while a triangulated cube only deforms temporarily. Bending Stiffness adds angular resistance — [Blender Manual: Soft Body Interior Forces](https://docs.blender.org/manual/en/latest/physics/soft_body/forces/interior.html)
- Edges panel: Pull (spring stiffness when stretched), Push (when compressed), Damp, Plasticity (permanent deformation), Bending, and Length (rest-length scale). Pull, Push, Damp, Goal Stiffness and Goal Damping all default to about 0.5 (Blender default, from training knowledge) — [Blender Manual: Soft Body Edges](https://docs.blender.org/manual/en/latest/physics/soft_body/settings/edges.html)
- Collision Damping runs 0 to 1: at 0.0 the soft body bounces as much as it can, at 1.0 it does not bounce at all. The Thickness Outer and Inner values pad each face to prevent intersections — [Blender Manual: Collision](https://docs.blender.org/manual/en/latest/physics/collision.html)

**Cloth**
- Stiffness settings are Tension (resists stretching), Compression, Shear and Bending, plus Structural for the linear bending model. Each has a vertex-group weight with Max values (Max Shearing, Max Bending) — [Blender Manual: Cloth Physical Properties](https://docs.blender.org/manual/en/latest/physics/cloth/settings/physical_properties.html); [Property Weights](https://docs.blender.org/manual/en/latest/physics/cloth/settings/property_weights.html)
- Defaults and presets (Blender default, from training knowledge): Quality 5 steps per frame, Vertex Mass 0.3 kg, Air Viscosity 1, Tension and Compression 15, Shear 5, Bending 0.5. Presets as tension / bending: Cotton 15 / 0.5, Silk 5 / 0.05, Denim 40 / 10, Leather 80 / 150, Rubber 15 / 25. The Shape panel adds Pin Group plus Pin Stiffness, and Internal Springs / Pressure add Pressure, a target volume and a Pressure Scale for inflated pillows and balloons — [Blender Manual: Cloth Shape](https://docs.blender.org/manual/en/latest/physics/cloth/settings/shape.html)

**Fluid (Mantaflow)**
- Liquid "Diffusion" is set mainly by Viscosity and Surface Tension, and presets cover water, oil and honey — [Blender Manual: Liquid Diffusion](https://docs.blender.org/manual/en/latest/physics/fluid/type/domain/liquid/diffusion.html)
- A separate High Viscosity Solver simulates honey and molasses. Its Strength is the viscosity, and the manual shows 0.2 against 0.4 on a rotating inflow. Even at 0 it still applies some viscosity — [same page](https://docs.blender.org/manual/en/latest/physics/fluid/type/domain/liquid/diffusion.html)
- Mantaflow liquid is FLIP based: particles carry velocity and a grid handles pressure — [Blender Manual: Fluid](https://docs.blender.org/manual/en/latest/physics/fluid/index.html)

**Particles and force fields**
- Particle "Fluid" physics uses SPH, with pressure, surface tension, viscosity and springs. The manual describes it as covering "liquids to slime, goo to sand" — [Blender Manual: Particle Fluid Physics](https://docs.blender.org/manual/en/latest/physics/particles/emitter/physics/fluid.html)
- Force field types (Blender manual, from training knowledge): Force (radial), Wind, Vortex, Magnetic, Harmonic, Charge, Lennard-Jones, Texture, Curve Guide, Boid, Turbulence, Drag, Fluid Flow. Shared settings are Strength, Flow, Noise, Seed, Shape (Point, Line, Plane, Surface), and Falloff (Sphere, Tube, Cone) with power, min and max distance — [Blender Manual: Force Fields](https://docs.blender.org/manual/en/latest/physics/forces/force_fields/index.html)

### Inferences
- Suggested app presets in Blender terms. These are design suggestions, not sourced values.
  - Jelly: Pull and Push 0.9, Damp 0.1–0.2, Goal 0.3–0.5, Bending 0.1.
  - Rubber: Pull 0.95, Damp 0.3, Bounciness 0.8.
  - Slime: Pull 0.3, Plasticity 0.5, Damp 0.6, Collision Damping 0.9.
  - Paper: cloth Tension 80, Bending 5–20, Air 1–2.
  - Silk: cloth Tension 5, Bending 0.05, Air 2.
  - Water: SPH/PBF viscosity about 0, surface tension low.
  - Honey: high-viscosity XSPH factor about 0.3–0.5, slow pour.

### Gaps
- Exact Mantaflow preset values for water, oil and honey (base and exponent) could not be verified, because the live manual was blocked and the bundled text does not list them.
- Cloth preset numbers come from training knowledge of Blender's preset scripts and were not re-fetched.

## 2. Real-time algorithms feasible on iPhone (Metal compute)

### Takeaway
Use one XPBD particle-and-constraint core for ropes, cloth, soft bodies and jelly (via shape matching) and rigid-ish bodies, at 5–20 substeps of a single iteration each. Add PBF on the same particles for liquid, and a small 2D MLS-MPM (88-line Taichi style) for slime, snow and viscoplastic goo. A 2D grid FLIP (Ten Minute Physics #18) is an alternative for water. All of these stay in the 5k–60k particle range on a phone GPU.

### Cited Findings
- Ten Minute Physics (Matthias Müller) has ready reference implementations: #09 XPBD basics, #10 "Simple and unbreakable" soft bodies, #11 spatial hashing for overlaps, #12 "100x speedup for soft body simulations", #14 cloth, #15 self-collisions, #17 a 200-line Eulerian fluid, #18 a FLIP water simulator, #20 height-field water, #25 joints — [Ten Minute Physics](https://matthias-research.github.io/pages/tenMinutePhysics/index.html)
- XPBD adds a compliance term α̃ = α/Δt², which makes stiffness independent of iteration count and timestep. Small Steps (many substeps, 1 iteration each) beats many iterations at the same cost — [Macklin, Müller, Chentanez 2016, XPBD](https://matthias-research.github.io/pages/publications/XPBD.pdf); [Small Steps in Physics Simulation](https://mmacklin.com/smallsteps.pdf) (from training knowledge, not fetched)
- PBF solves a density constraint with λᵢ = −Cᵢ / (Σ|∇Cᵢ|² + ε), where ε is a user-set constant relaxation. The constraint's vanishing gradient at the kernel edge destabilizes separating particles, so ε is needed. A tensile-instability artificial pressure s_corr fights clustering and mimics surface tension — [Macklin & Müller 2013 slides](https://cgweb.informatik.uni-freiburg.de/intern/seminar/positionBasedFluids_2014_SIGGRAPH.pdf); [TAMU reimplementation](https://people.engr.tamu.edu/sueda/courses/CSCE450/2022F/projects/Brandon_Nguyen/index.html)
- Typical PBF values (paper, from training knowledge, exact ε not confirmed by search): s_corr = −k(W(r)/W(Δq))ⁿ with k = 0.1, n = 4, |Δq| = 0.1–0.3h. XPBD-style XSPH viscosity c = 0.01 for water, and much higher for honey. Vorticity confinement is optional. 2–4 solver iterations — [PBF paper record](https://history.siggraph.org/?p=108378)
- Adaptive PBF cuts cost for real-time use — [Adaptive Position-Based Fluids (arXiv 1608.04721)](https://arxiv.org/pdf/1608.04721)
- MLS-MPM 88-line reference:
  - Per step: grid reset, then P2G (quadratic B-spline weights, fixed-corotated stress, APIC affine term), then grid update (divide by mass, gravity, sticky walls, separating floor), then G2P (gather v and C, advect, F ← (I+dt·C)F).
  - Plasticity: SVD of F, clamp singular values to [1−2.5e-2, 1+7.5e-3], Jp clamped to [0.6, 20].
  - Parameters: n = 80 grid, dt = 1e-4 (10 substeps per 1e-3 frame), 3,000 particles, E = 1e4, ν = 0.2, hardening 10, gravity −200.
  - Higher quality: n = 320, dt = 1e-5, E = 2e4.
  - [taichi_mpm mls-mpm88-explained.cpp](https://github.com/yuanming-hu/taichi_mpm/blob/master/mls-mpm88-explained.cpp); paper: [Hu et al. 2018, MLS-MPM](https://yzhu.io/publication/mpmmls2018siggraph/paper.pdf) (paper link from training knowledge)
- In the same code family (from training knowledge of taichi `mpm99.py`, not fetched), material switching is simple:
  - Fluid: μ = 0, J reset.
  - Jelly: hardening 0.3, no plasticity.
  - Snow: clamped SVD as above.
  - Slime / viscoplastic: Drucker-Prager or a von Mises yield.
  - [taichi mpm99 example](https://github.com/taichi-dev/taichi/blob/master/python/taichi/examples/simulation/mpm99.py)

### Inferences
**Budget on A14+ iPhone GPUs.** These are estimates, not measured.
- PBF with a hash grid: 10k–30k particles at 60 fps.
- XPBD cloth: a 64×64 grid with 10 substeps is trivial.
- 2D MLS-MPM: 20k–50k particles on a 128² grid at 20–40 substeps per frame.
- Offline "bake" mode can push about 5x higher than these, because preview does not have to be real time.

**Stability rules**
- Clamp the per-substep velocity to less than 1 cell (or particle radius) per substep, a CFL-like limit.
- Use XPBD compliance instead of raw stiffness.
- Damp velocities by (1−k·dt).
- Use a fixed timestep with an accumulator, so the result is deterministic and bakes match previews.

**Metal parallelism**
- Jacobi or graph-colored constraint solves, since Gauss-Seidel does not parallelize.
- Atomic float adds for P2G: Metal supports `atomic<float>` add on device memory.
- Counting-sort spatial hash, as in Ten Minute Physics #11.

**Jelly via shape matching (Müller 2005)**
- Find the goal rotation R by polar decomposition of A_pq.
- Pull each particle toward R(x⁰−c⁰)+c with stiffness α ∈ [0, 1]. This is the direct analogue of Blender's Goal.
- α of 0.1–0.3 gives wobbly jelly; 0.8 or more gives rubber.

### Gaps
- No measured iPhone benchmarks for PBF or MPM were found. The budgets above are extrapolations.
- The exact ε in the PBF paper was not confirmed (the paper suggests a value around 100–600 in its units, but this was not verified).

## 3. Rendering fluid and slime in 2D, and deforming a layer image by a soft-body mesh

### Takeaway
Render liquids and slime as metaballs:
1. Splat each particle as a radial-falloff sprite into a half-resolution R16F buffer, adding the values together.
2. Optionally blur the buffer, which is separable and cheap.
3. Threshold it with smoothstep for an antialiased edge.
4. Compute a normal from the field gradient, then shade: specular, a Fresnel rim, refraction (offset the background by the normal), and an inner tint and thickness.

For layer soft bodies, render the original image texture-mapped onto the deformed triangle mesh.

### Cited Findings
- The 2D metaball trick: draw one sprite per ball into an offscreen buffer so overlaps add up, then keep pixels above a threshold with a full-screen shader. A commenter in the same thread argues additive alpha can be "just as good and much faster" than a true isosurface. Per-pixel CPU evaluation scales poorly — [gamedev.net thread](https://gamedev.net/forums/topic/484576-efficient-2d-metaballs/4177661/); [gamedev.net original](https://gamedev.net/forums/topic/484576/)
- Screen-space fluid rendering (van der Laan / NVIDIA): render particle point sprites, smooth depth with a bilateral Gaussian whose width is computed in screen space, then shade. Large blobs can still look "viscous", which is a plus for slime — [NVIDIA GDC 2010 Direct3D Effects](https://developer.download.nvidia.com/presentations/2010/gdc/Direct3D_Effects.pdf); [Burkus/Kárpáti paper](https://dspace.zcu.cz/bitstream/11025/45029/1/J29.pdf)

### Inferences
**Shading recipe**
- Normal: n = normalize(−∂f/∂x, −∂f/∂y, k), with k about 0.5–2 to control the bulge.
- Highlight: Blinn specular, power 40–120 for glossy slime and 200 or more for water.
- Fresnel rim: (1−n.z)^3.
- Refraction: sample the background layer at uv + n.xy·0.02–0.05.
- Thickness absorption: color = mix(bg, tint, 1−exp(−f·density)).

**Look presets**
- Water: low threshold blur, clear tint, strong refraction.
- Slime: green tint, sharp specular, subsurface fake via a blurred field, slight translucency.
- Honey: amber, low refraction, high absorption.

**Layer to soft body**
1. Alpha-threshold the layer's image (or rasterize its text or shape).
2. Trace the contour with marching squares and simplify it with Douglas-Peucker to about 30–150 points.
3. Triangulate with constrained Delaunay plus interior Steiner points, or simply use a regular grid clipped to the mask.
4. Give each vertex its original UV.
5. Simulate with XPBD distance plus area constraints, or shape matching.
6. Draw the triangles textured with the original layer, so text and image stay crisp.

**Baking**
- Store per-frame vertex positions (mesh: N×2 floats per frame) or particle positions (Float16) in the project as a cache keyed to the timeline frame.
- Playback reads the cache; editing the parameters invalidates it.
- Optionally convert rigid-body results to keyframes (position plus rotation per frame, then curve-simplify) so users can tweak them in the graph editor.
- A fixed dt with seeded randomness makes the bake reproducible.

### Gaps
- No canonical Metal sample for 2D metaball fluid was found. Apple's Metal sample code was not reviewed in this session.
- Sebastian Lague's fluid videos and NVIDIA Flex docs were not fetched, because the tool budget ran out.
