class_name SimUnits
extends RefCounted
## Fixed-point convention of the deterministic simulation.
##
## Every position, velocity and distance in the sim is an `int` in sub-units:
## 1 meter = PER_METER sub-units (1000 = millimeter precision). Velocities are
## sub-units per tick (60 ticks per second). Timers are counted in ticks.
## Floats never enter sim state, so the state hash is identical on every CPU
## (Apple Silicon Mac, x86 Windows, Linux CI).
##
## The float helpers below exist for the VIEW only (turning sim state into
## 3D positions). Never call them from code that writes sim state.

## Sub-units per meter. # proposal, tune
const PER_METER: int = 1000

## Simulation ticks per second. Must match physics/common/physics_ticks_per_second.
const TICKS_PER_SECOND: int = 60


## Converts whole meters to sub-units (for authoring constants).
static func from_meters(meters: int) -> int:
	return meters * PER_METER


## View only: sub-units to meters as a float.
static func to_meters(sub_units: int) -> float:
	return float(sub_units) / float(PER_METER)


## View only: a point on the gameplay plane (x right, y up) to a 3D position.
## `depth` is the view's z (the sim is 2D; depth is a display choice).
static func to_vector3(x: int, y: int, depth: float = 0.0) -> Vector3:
	return Vector3(to_meters(x), to_meters(y), depth)
