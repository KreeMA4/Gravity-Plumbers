class_name Layers
extends RefCounted
## Physics collision layers (bit values). Keep every script using these names.
const WORLD: int = 1        ## static level geometry
const PROPS: int = 2        ## dynamic props and tools
const PLUMBERS: int = 4     ## plumber body parts
const GOO: int = 8          ## sludge blobs
const TRIGGERS: int = 16    ## Area3D triggers (leaks, tanks, kill volumes)

const MASK_SOLID: int = WORLD | PROPS | PLUMBERS | GOO
