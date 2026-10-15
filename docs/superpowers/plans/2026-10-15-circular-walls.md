# Circular walls implementation

Approved conversational design: smooth circular wall tool matching Circle floors, with the same Door tool following circular walls. Execute inline in the existing feature branch, preserving the reviewable PR.

1. Add failing integration coverage for circular enclosure and same-tool door placement.
2. Add shared circle sampling/path geometry, compact circle records, anchored curved doors, codec v2 and atomic commands. Preserve v1 and orthogonal APIs.
3. Extend arrangement, physical queries, region boundary incidence/lineage and overlays to sampled sloping edges.
4. Register Circular Wall handler; extend existing door projection/preview/rendering and occupancy paths.
5. Verify regressions plus circular/seam/intersection/restore cases, independent review, document limits and update PR.

Implementation status: steps 1–4 integrated. Initial circular-tool test failed before implementation. Sixteen suites pass on the initial integrated implementation. Review reproduced open-door residual walls and region/portal sampling precision failures; regression coverage now includes translated coordinates and all eight compass door positions. Circular barrier apertures use source arclength intervals. Portal and boundary adjacency are read from arrangement edges and region rings, without side-offset guesses. Final full-suite verification and focused re-review complete: all 16 suites, import, startup and whitespace checks pass; reviewer confirms original probes fixed with no Important findings remaining. Graphical/Godot 4.7 acceptance remains unverified.
