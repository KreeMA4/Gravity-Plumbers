class_name LevelBatcher
extends RefCounted
## Performance: merge all the little static meshes of a level (walls, trims,
## pipes, flanges, rocks...) into ONE mesh per material. A room built from
## 40 boxes becomes a handful of draw calls. Collision shapes are untouched;
## only MeshInstance3D nodes that are direct children of a StaticBody3D or of
## a room root (window frames, edge trims, lamps) are merged. Interactive
## objects (LevelObjects: leaks, valves, switches, tanks...), rigid bodies,
## fields and areas are skipped entirely.

static func batch_static(world: Node3D) -> int:
	var groups: Dictionary = {}       ## key -> [material, Array of [mesh, xform]]
	var to_free: Array = []
	_collect(world, world, groups, to_free)
	var merged: int = 0
	for key: Variant in groups.keys():
		var g: Array = groups[key] as Array
		var items: Array = g[1] as Array
		if items.size() < 2:
			continue
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for it: Variant in items:
			var pair: Array = it as Array
			var mesh: Mesh = pair[0] as Mesh
			for s: int in mesh.get_surface_count():
				st.append_from(mesh, s, pair[1] as Transform3D)
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "Batched_%d" % merged
		mi.mesh = st.commit()
		mi.material_override = g[0] as Material
		mi.cast_shadow = g[2] as GeometryInstance3D.ShadowCastingSetting
		world.add_child(mi)
		for it2: Variant in items:
			var src: MeshInstance3D = (it2 as Array)[2] as MeshInstance3D
			if is_instance_valid(src):
				to_free.append(src)
		merged += 1
	for n: Variant in to_free:
		var node: Node = n as Node
		if is_instance_valid(node) and node.get_parent() != null:
			node.get_parent().remove_child(node)
			node.queue_free()
	return merged


static func _collect(world: Node3D, n: Node, groups: Dictionary, to_free: Array) -> void:
	for c: Node in n.get_children():
		if c is LevelObject or c is RigidBody3D or c is GravityField or c is Area3D:
			continue   # interactive / moving things keep their own meshes
		var static_parent: bool = n is StaticBody3D or (n is Node3D and str(n.name).begins_with("Room_"))
		if c is MeshInstance3D and static_parent:
			var mi: MeshInstance3D = c as MeshInstance3D
			if mi.mesh != null and mi.material_override != null and mi.visible:
				var mat: Material = mi.material_override
				# Group by material and by whether the mesh has UVs (primitives do, tubes don't).
				# (Mesh has no surface_get_format() in GDScript; check the arrays instead.)
				var arrays: Array = mi.mesh.surface_get_arrays(0)
				var has_uv: bool = arrays.size() > Mesh.ARRAY_TEX_UV and arrays[Mesh.ARRAY_TEX_UV] != null
				var key: String = "%d_%s_%d" % [mat.get_instance_id(), str(has_uv), int(mi.cast_shadow)]
				if not groups.has(key):
					groups[key] = [mat, [], mi.cast_shadow]
				var rel: Transform3D = world.global_transform.affine_inverse() * mi.global_transform
				((groups[key] as Array)[1] as Array).append([mi.mesh, rel, mi])
				continue
		_collect(world, c, groups, to_free)
