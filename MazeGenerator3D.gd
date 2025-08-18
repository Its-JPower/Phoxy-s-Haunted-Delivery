extends Node3D
class_name MazeGenerator3D

# Maze configuration
@export var maze_size: int = 10
@export var cell_size: float = 4.0
@export var wall_height: float = 3.0
@export var wall_thickness: float = 1.0
@export var num_exits: int = 2
@export var secret_room_chance: float = 0.1
@export var secret_room_size: int = 2

# Materials
@export var wall_material: Material
@export var floor_material: Material
@export var secret_floor_material: Material

# Cell types
enum CellType {
	WALL,
	PATH,
	EXIT,
	SECRET_ROOM
}

const DIRECTIONS = [
	Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)
]

var maze_grid: Array[Array]
var secret_rooms: Array[Vector2i] = []

func _ready():
	generate_maze()

func generate_maze():
	clear_maze()
	initialize_grid()
	recursive_backtrack(Vector2i(1, 1))
	create_exits()
	add_secret_rooms()
	build_3d_maze()
	bake_navigation_mesh()

func initialize_grid():
	maze_grid = []
	for y in range(maze_size * 2 + 1):
		var row: Array[int] = []
		for x in range(maze_size * 2 + 1):
			row.append(CellType.WALL)
		maze_grid.append(row)

func recursive_backtrack(start_pos: Vector2i):
	var stack: Array[Vector2i] = []
	var current = start_pos
	var visited = {}
	
	maze_grid[current.y][current.x] = CellType.PATH
	visited[current] = true
	
	while true:
		var neighbors = get_unvisited_neighbors(current, visited)
		
		if neighbors.size() > 0:
			var next_cell = neighbors[randi() % neighbors.size()]
			stack.push_back(current)
			
			var wall_pos = current + (next_cell - current) / 2
			maze_grid[wall_pos.y][wall_pos.x] = CellType.PATH
			maze_grid[next_cell.y][next_cell.x] = CellType.PATH
			
			visited[next_cell] = true
			current = next_cell
		elif stack.size() > 0:
			current = stack.pop_back()
		else:
			break

func get_unvisited_neighbors(pos: Vector2i, visited: Dictionary) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	for direction in DIRECTIONS:
		var neighbor = pos + direction * 2
		if is_valid_cell(neighbor) and not visited.has(neighbor):
			neighbors.append(neighbor)
	return neighbors

func is_valid_cell(pos: Vector2i) -> bool:
	return pos.x >= 1 and pos.x < maze_size * 2 and pos.y >= 1 and pos.y < maze_size * 2 and pos.x % 2 == 1 and pos.y % 2 == 1

func create_exits():
	var exits_created = 0
	var attempts = 0
	var max_attempts = num_exits * 10
	
	while exits_created < num_exits and attempts < max_attempts:
		attempts += 1
		var side = randi() % 4
		var exit_pos: Vector2i
		
		match side:
			0: exit_pos = Vector2i(randi_range(1, maze_size * 2 - 1), 0)
			1: exit_pos = Vector2i(maze_size * 2, randi_range(1, maze_size * 2 - 1))
			2: exit_pos = Vector2i(randi_range(1, maze_size * 2 - 1), maze_size * 2)
			3: exit_pos = Vector2i(0, randi_range(1, maze_size * 2 - 1))
		
		var adjacent_path = false
		for direction in DIRECTIONS:
			var adj_pos = exit_pos + direction
			if is_in_bounds(adj_pos) and maze_grid[adj_pos.y][adj_pos.x] == CellType.PATH:
				adjacent_path = true
				break
		
		if adjacent_path and maze_grid[exit_pos.y][exit_pos.x] == CellType.WALL:
			maze_grid[exit_pos.y][exit_pos.x] = CellType.EXIT
			exits_created += 1

func add_secret_rooms():
	var grid_size = maze_size * 2 + 1
	for y in range(1, grid_size - secret_room_size, 2):
		for x in range(1, grid_size - secret_room_size, 2):
			if randf() < secret_room_chance and can_place_secret_room(Vector2i(x, y)):
				create_secret_room(Vector2i(x, y))

func can_place_secret_room(pos: Vector2i) -> bool:
	# Check if area is all walls
	for dy in range(secret_room_size * 2 + 1):
		for dx in range(secret_room_size * 2 + 1):
			var check_pos = pos + Vector2i(dx, dy)
			if not is_in_bounds(check_pos) or maze_grid[check_pos.y][check_pos.x] != CellType.WALL:
				return false
	
	# Check for adjacent path cells
	for dy in range(-1, secret_room_size * 2 + 2):
		for dx in range(-1, secret_room_size * 2 + 2):
			if dy == -1 or dy == secret_room_size * 2 + 1 or dx == -1 or dx == secret_room_size * 2 + 1:
				var check_pos = pos + Vector2i(dx, dy)
				if is_in_bounds(check_pos) and maze_grid[check_pos.y][check_pos.x] == CellType.PATH:
					return true
	return false

func create_secret_room(pos: Vector2i):
	# Create room
	for dy in range(secret_room_size * 2 + 1):
		for dx in range(secret_room_size * 2 + 1):
			var room_pos = pos + Vector2i(dx, dy)
			if is_in_bounds(room_pos):
				maze_grid[room_pos.y][room_pos.x] = CellType.SECRET_ROOM
	
	# Add entrance
	var entrance_candidates = []
	for dy in range(secret_room_size * 2 + 1):
		for dx in range(secret_room_size * 2 + 1):
			if dy == 0 or dy == secret_room_size * 2 or dx == 0 or dx == secret_room_size * 2:
				var entrance_pos = pos + Vector2i(dx, dy)
				for direction in DIRECTIONS:
					var adj_pos = entrance_pos + direction
					if is_in_bounds(adj_pos) and maze_grid[adj_pos.y][adj_pos.x] == CellType.PATH:
						entrance_candidates.append(entrance_pos)
						break
	
	if entrance_candidates.size() > 0:
		var entrance = entrance_candidates[randi() % entrance_candidates.size()]
		maze_grid[entrance.y][entrance.x] = CellType.PATH
		secret_rooms.append(pos)

func is_in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < maze_size * 2 + 1 and pos.y >= 0 and pos.y < maze_size * 2 + 1

func build_3d_maze():
	var mesh_instance = MeshInstance3D.new()
	var array_mesh = ArrayMesh.new()
	
	build_floor_surface(array_mesh)
	build_walls_surface(array_mesh)
	
	mesh_instance.mesh = array_mesh
	add_child(mesh_instance)
	build_collision_shapes()

func build_floor_surface(array_mesh: ArrayMesh):
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()
	
	var maze_world_size = maze_grid.size() * cell_size
	var floor_half_size = maze_world_size * 0.5
	var floor_center = Vector3(floor_half_size - cell_size * 0.5, 0, floor_half_size - cell_size * 0.5)
	
	vertices.append(Vector3(floor_center.x - floor_half_size, 0, floor_center.z - floor_half_size))
	vertices.append(Vector3(floor_center.x + floor_half_size, 0, floor_center.z - floor_half_size))
	vertices.append(Vector3(floor_center.x + floor_half_size, 0, floor_center.z + floor_half_size))
	vertices.append(Vector3(floor_center.x - floor_half_size, 0, floor_center.z + floor_half_size))
	
	for i in range(4):
		normals.append(Vector3.UP)
	
	var uv_scale = maze_grid.size()
	uvs.append_array([Vector2(0, 0), Vector2(uv_scale, 0), Vector2(uv_scale, uv_scale), Vector2(0, uv_scale)])
	indices.append_array([0, 1, 2, 0, 2, 3])
	
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if floor_material:
		array_mesh.surface_set_material(0, floor_material)

func build_walls_surface(array_mesh: ArrayMesh):
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()
	var vertex_count = 0
	
	for y in range(maze_grid.size()):
		for x in range(maze_grid[y].size()):
			if maze_grid[y][x] == CellType.WALL:
				var world_pos = Vector3(x * cell_size, 0, y * cell_size)
				add_wall_cube(vertices, normals, uvs, indices, world_pos, vertex_count)
				vertex_count += 24

	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if wall_material:
		array_mesh.surface_set_material(1, wall_material)

func add_wall_cube(vertices: PackedVector3Array, normals: PackedVector3Array,
				  uvs: PackedVector2Array, indices: PackedInt32Array,
				  pos: Vector3, vertex_offset: int):
	
	var half_size = cell_size * 0.5
	var height = wall_height
	
	var cube_vertices = [
		# Bottom face
		Vector3(pos.x - half_size, 0, pos.z - half_size),
		Vector3(pos.x + half_size, 0, pos.z - half_size),
		Vector3(pos.x + half_size, 0, pos.z + half_size),
		Vector3(pos.x - half_size, 0, pos.z + half_size),
		# Top face
		Vector3(pos.x - half_size, height, pos.z - half_size),
		Vector3(pos.x + half_size, height, pos.z - half_size),
		Vector3(pos.x + half_size, height, pos.z + half_size),
		Vector3(pos.x - half_size, height, pos.z + half_size),
	]
	
	var faces = [
		[[3, 2, 1, 0], Vector3.DOWN],
		[[4, 5, 6, 7], Vector3.UP],
		[[0, 1, 5, 4], Vector3.FORWARD],
		[[2, 3, 7, 6], Vector3.BACK],
		[[3, 0, 4, 7], Vector3.LEFT],
		[[1, 2, 6, 5], Vector3.RIGHT]
	]
	
	var face_vertex_offset = vertex_offset
	
	for face_data in faces:
		var face_indices = face_data[0]
		var normal = face_data[1]
		
		for i in range(4):
			vertices.append(cube_vertices[face_indices[i]])
			normals.append(normal)
			uvs.append(Vector2(i % 2, i / 2))
		
		indices.append_array([
			face_vertex_offset + 0, face_vertex_offset + 1, face_vertex_offset + 2,
			face_vertex_offset + 0, face_vertex_offset + 2, face_vertex_offset + 3
		])
		face_vertex_offset += 4

func clear_maze():
	for child in get_children():
		child.queue_free()

# NAVIGATION MESH SYSTEM
func bake_navigation_mesh():
	print("Baking navigation mesh...")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	var nav_region = get_or_create_navigation_region()
	var nav_mesh = nav_region.navigation_mesh
	nav_mesh.clear()
	
	# FORCE manual creation to avoid auto-baking over entire floor
	print("Skipping auto-baking, creating manual mesh only...")
	create_manual_navigation_mesh(nav_region)
	
	# Force enable the navigation region
	nav_region.enabled = true

func get_or_create_navigation_region() -> NavigationRegion3D:
	var nav_region = find_child("NavigationRegion3D", false, false) as NavigationRegion3D
	if not nav_region:
		nav_region = NavigationRegion3D.new()
		nav_region.name = "NavigationRegion3D"
		nav_region.navigation_mesh = NavigationMesh.new()
		add_child(nav_region)
	return nav_region

func create_manual_navigation_mesh(nav_region: NavigationRegion3D):
	print("Creating robust manual navigation mesh...")
	var nav_mesh = nav_region.navigation_mesh
	nav_mesh.clear()
	
	var vertices = PackedVector3Array()
	var polygons = []
	
	# Create navigation using corridor mapping instead of individual cells
	create_corridor_based_navigation(vertices, polygons)
	
	if vertices.size() == 0:
		print("ERROR: No navigation areas created! Creating emergency navigation...")
		create_emergency_navigation(vertices, polygons)
	
	nav_mesh.set_vertices(vertices)
	for polygon in polygons:
		nav_mesh.add_polygon(polygon)
	
	print("Robust navigation mesh created:")
	print("- Vertices: ", vertices.size())
	print("- Polygons: ", polygons.size())
	
	# Force update
	nav_region.navigation_mesh = nav_mesh
	nav_region.enabled = false
	await get_tree().process_frame
	nav_region.enabled = true
	await get_tree().process_frame
	
	await get_tree().create_timer(0.5).timeout
	validate_navigation_mesh(nav_mesh)

func is_walkable_cell(grid_pos: Vector2i) -> bool:
	"""Check if a grid position contains a walkable cell"""
	if not is_in_bounds(grid_pos):
		return false
	
	var cell_type = maze_grid[grid_pos.y][grid_pos.x]
	return cell_type == CellType.PATH or cell_type == CellType.EXIT or cell_type == CellType.SECRET_ROOM

func find_connected_walkable_regions() -> Array:
	"""Find connected regions of walkable cells using flood fill"""
	var processed_cells = {}
	var regions = []
	
	for y in range(maze_grid.size()):
		for x in range(maze_grid[y].size()):
			var cell_pos = Vector2i(x, y)
			var cell_type = maze_grid[y][x]
			
			if (cell_type == CellType.PATH or cell_type == CellType.EXIT or cell_type == CellType.SECRET_ROOM) and not processed_cells.has(cell_pos):
				var region = flood_fill_walkable_region(cell_pos, processed_cells)
				if region.size() > 0:
					regions.append(region)
	
	return regions

func flood_fill_walkable_region(start_pos: Vector2i, processed_cells: Dictionary) -> Array:
	"""Flood fill to find all connected walkable cells"""
	var region = []
	var cells_to_check = [start_pos]
	var region_cells = {}
	
	while not cells_to_check.is_empty():
		var current = cells_to_check.pop_back()
		
		if processed_cells.has(current) or region_cells.has(current):
			continue
		
		if not is_in_bounds(current):
			continue
		
		var cell_type = maze_grid[current.y][current.x]
		if not (cell_type == CellType.PATH or cell_type == CellType.EXIT or cell_type == CellType.SECRET_ROOM):
			continue
		
		region_cells[current] = true
		region.append(current)
		processed_cells[current] = true
		
		# Add all 4 adjacent cells (not diagonal to avoid leaking through corners)
		var neighbors = [
			current + Vector2i(0, 1),   # North
			current + Vector2i(1, 0),   # East
			current + Vector2i(0, -1),  # South
			current + Vector2i(-1, 0)   # West
		]
		
		for neighbor in neighbors:
			if not processed_cells.has(neighbor) and not region_cells.has(neighbor):
				cells_to_check.append(neighbor)
	
	return region

func create_navigation_bridges_for_region(region: Array, vertices: PackedVector3Array, polygons: Array):
	"""Create bridge navigation areas between adjacent cells in a region"""
	
	var bridge_count = 0
	
	for cell_pos in region:
		var cell_type = maze_grid[cell_pos.y][cell_pos.x]
		
		if cell_type == CellType.PATH or cell_type == CellType.EXIT or cell_type == CellType.SECRET_ROOM:
			# Check adjacent cells and create bridges
			var directions = [
				Vector2i(1, 0),   # Right
				Vector2i(0, 1),   # Down
			]
			
			for direction in directions:
				var neighbor_pos = cell_pos + direction
				
				# Check if neighbor is also in the region and walkable
				if region.has(neighbor_pos):
					var neighbor_type = maze_grid[neighbor_pos.y][neighbor_pos.x]
					if neighbor_type == CellType.PATH or neighbor_type == CellType.EXIT or neighbor_type == CellType.SECRET_ROOM:
						# Create a bridge between these cells
						create_bridge_between_cells(cell_pos, neighbor_pos, vertices, polygons)
						bridge_count += 1
	
	print("  Created ", bridge_count, " navigation bridges")

func create_bridge_between_cells(cell1: Vector2i, cell2: Vector2i, vertices: PackedVector3Array, polygons: Array):
	"""Create a bridge navigation area between two adjacent cells"""
	
	var world_pos1 = Vector3(cell1.x * cell_size, 0.05, cell1.y * cell_size)
	var world_pos2 = Vector3(cell2.x * cell_size, 0.05, cell2.y * cell_size)
	
	# Create a bridge quad that spans between the two cell centers
	var center = (world_pos1 + world_pos2) * 0.5
	var direction = (world_pos2 - world_pos1).normalized()
	var perpendicular = Vector3(-direction.z, 0, direction.x)
	
	# Bridge dimensions
	var length_half = cell_size * 0.6  # Length of bridge
	var width_half = cell_size * 0.3   # Width of bridge
	
	var start_idx = vertices.size()
	vertices.append_array([
		center + (-direction * length_half) + (-perpendicular * width_half),
		center + (-direction * length_half) + (perpendicular * width_half),
		center + (direction * length_half) + (perpendicular * width_half),
		center + (direction * length_half) + (-perpendicular * width_half)
	])
	
	polygons.append(PackedInt32Array([start_idx + 0, start_idx + 1, start_idx + 2]))
	polygons.append(PackedInt32Array([start_idx + 0, start_idx + 2, start_idx + 3]))

func validate_navigation_mesh(nav_mesh: NavigationMesh) -> bool:
	"""Validate navigation mesh and print detailed info"""
	var vertices = nav_mesh.get_vertices()
	if vertices.size() == 0:
		print("ERROR: Navigation mesh has no vertices!")
		return false
	
	# Check bounds
	var min_pos = vertices[0]
	var max_pos = vertices[0]
	for vertex in vertices:
		min_pos.x = min(min_pos.x, vertex.x)
		min_pos.z = min(min_pos.z, vertex.z)
		max_pos.x = max(max_pos.x, vertex.x)
		max_pos.z = max(max_pos.z, vertex.z)
	
	print("Navigation mesh bounds: ", min_pos, " to ", max_pos)
	print("Navigation mesh size: ", max_pos - min_pos)
	
	# Test a few known positions
	var test_positions = [
		grid_to_world(Vector2i(1, 1)),
		grid_to_world(Vector2i(3, 3)),
		grid_to_world(Vector2i(5, 5))
	]
	
	var nav_region = get_navigation_region()
	if nav_region:
		var nav_map = nav_region.get_navigation_map()
		if nav_map.is_valid():
			print("Testing navigation mesh at key positions:")
			for i in range(test_positions.size()):
				var pos = test_positions[i]
				var closest = NavigationServer3D.map_get_closest_point(nav_map, pos)
				var distance = pos.distance_to(closest)
				print("  Test ", i, ": ", pos, " -> ", closest, " (dist: ", distance, ")")
			return true
		else:
			print("Navigation map is not valid!")
			return false
	else:
		print("No navigation region found!")
		return false

func create_emergency_navigation(vertices: PackedVector3Array, polygons: Array):
	print("Creating emergency navigation mesh at multiple locations...")
	
	# Create multiple emergency navigation areas
	var emergency_positions = [
		Vector2i(1, 1),  # Start position
		Vector2i(3, 3),  # Nearby
		Vector2i(5, 5),  # Further away
	]
	
	for grid_pos in emergency_positions:
		if is_in_bounds(grid_pos):
			var spawn_world = grid_to_world(grid_pos)
			var safe_size = cell_size * 0.8
			var half_size = safe_size * 0.5
			
			var start_idx = vertices.size()
			vertices.append_array([
				spawn_world + Vector3(-half_size, 0.05, -half_size),
				spawn_world + Vector3(half_size, 0.05, -half_size),
				spawn_world + Vector3(half_size, 0.05, half_size),
				spawn_world + Vector3(-half_size, 0.05, half_size)
			])
			
			polygons.append(PackedInt32Array([start_idx + 0, start_idx + 1, start_idx + 2]))
			polygons.append(PackedInt32Array([start_idx + 0, start_idx + 2, start_idx + 3]))
	
	print("Emergency navigation created with ", vertices.size(), " vertices at ", emergency_positions.size(), " locations")

func build_collision_shapes():
	var static_body = StaticBody3D.new()
	static_body.name = "MazeCollision"
	static_body.collision_layer = 1
	static_body.collision_mask = 0
	
	var wall_count = 0
	for y in range(maze_grid.size()):
		for x in range(maze_grid[y].size()):
			if maze_grid[y][x] == CellType.WALL:
				var collision_shape = CollisionShape3D.new()
				var box_shape = BoxShape3D.new()
				box_shape.size = Vector3(cell_size, wall_height, cell_size)
				collision_shape.shape = box_shape
				collision_shape.position = Vector3(x * cell_size, wall_height * 0.5, y * cell_size)
				static_body.add_child(collision_shape)
				wall_count += 1
	
	# FIXED: Floor collision positioned so top surface is at Y = 0
	var floor_collision = CollisionShape3D.new()
	var floor_shape = BoxShape3D.new()
	var maze_world_size = maze_grid.size() * cell_size
	
	# Floor thickness and positioning
	var floor_thickness = 2.0
	floor_shape.size = Vector3(maze_world_size + cell_size, floor_thickness, maze_world_size + cell_size)
	floor_collision.shape = floor_shape
	# Position floor so the TOP surface is at Y = 0
	floor_collision.position = Vector3(
		maze_world_size * 0.5 - cell_size * 0.5, 
		-floor_thickness * 0.5,  # Half the thickness below Y = 0
		maze_world_size * 0.5 - cell_size * 0.5
	)
	floor_collision.name = "FloorCollision"
	static_body.add_child(floor_collision)
	
	add_child(static_body)
	print("Collision created: ", wall_count, " walls + floor")
	print("Floor size: ", floor_shape.size, " at position: ", floor_collision.position)
	print("Floor top surface should be at Y = 0")

# SPAWN POSITION UTILITIES
func get_player_spawn_position() -> Vector3:
	# FIXED: Use the guaranteed path cell at (1,1) where maze generation starts
	var spawn_grid_pos = Vector2i(1, 1)
	
	# Double-check this is a path cell
	if is_in_bounds(spawn_grid_pos) and maze_grid[spawn_grid_pos.y][spawn_grid_pos.x] == CellType.PATH:
		var spawn_pos = grid_to_world(spawn_grid_pos) + Vector3(0, 3.0, 0)
		print("Player spawn position calculated: ", spawn_pos, " (grid: ", spawn_grid_pos, ")")
		return spawn_pos
	else:
		print("ERROR: Default spawn grid position is not a path!")
		# Find first available path
		var first_path = find_first_path_cell()
		var spawn_pos = grid_to_world(first_path) + Vector3(0, 3.0, 0)
		print("Using first path cell: ", spawn_pos, " (grid: ", first_path, ")")
		return spawn_pos

func get_possible_spawn_positions() -> Array[Vector3]:
	var spawn_positions: Array[Vector3] = []
	print("Searching for possible spawn positions in maze...")
	
	for y in range(1, maze_grid.size() - 1, 2):
		for x in range(1, maze_grid[y].size() - 1, 2):
			if maze_grid[y][x] == CellType.PATH:
				if not is_near_exit(Vector2i(x, y), 3):
					# Spawn above floor so entities fall and land properly
					var world_pos = grid_to_world(Vector2i(x, y)) + Vector3(0, 3.0, 0)
					spawn_positions.append(world_pos)
	
	print("Found ", spawn_positions.size(), " possible spawn positions")
	return spawn_positions


func get_positions_far_from_spawn(min_distance: float = 10.0) -> Array[Vector2i]:
	var spawn_grid_pos = Vector2i(1, 1)
	var far_positions: Array[Vector2i] = []
	print("Searching for positions far from spawn (min distance: ", min_distance, ")...")
	
	for y in range(1, maze_grid.size() - 1, 2):
		for x in range(1, maze_grid[y].size() - 1, 2):
			if maze_grid[y][x] == CellType.PATH:
				var current_pos = Vector2i(x, y)
				var distance = current_pos.distance_to(spawn_grid_pos)
				if distance >= min_distance:
					far_positions.append(current_pos)
	
	print("Found ", far_positions.size(), " positions far from spawn")
	return far_positions

func find_first_path_cell() -> Vector2i:
	"""Find the first path cell in the maze as emergency fallback"""
	print("Searching for first path cell...")
	
	for y in range(maze_grid.size()):
		for x in range(maze_grid[y].size()):
			if maze_grid[y][x] == CellType.PATH:
				print("Found first path cell at: ", Vector2i(x, y))
				return Vector2i(x, y)
	
	print("ERROR: No path cells found in maze!")
	return Vector2i(1, 1)  # Fallback

func is_near_exit(pos: Vector2i, radius: int) -> bool:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var check_pos = pos + Vector2i(dx, dy)
			if is_in_bounds(check_pos) and maze_grid[check_pos.y][check_pos.x] == CellType.EXIT:
				return true
	return false

func get_guaranteed_safe_spawn_position() -> Vector3:
	await get_tree().physics_frame
	
	# FIXED: Ensure we spawn in the actual path cell at (1,1)
	# The maze generation starts at grid position (1,1) which is guaranteed to be a path
	var spawn_grid_pos = Vector2i(1, 1)
	
	# Verify this is actually a path cell
	if maze_grid[spawn_grid_pos.y][spawn_grid_pos.x] != CellType.PATH:
		print("ERROR: Spawn position is not a path! Cell type: ", maze_grid[spawn_grid_pos.y][spawn_grid_pos.x])
		# Find the first available path cell
		spawn_grid_pos = find_first_path_cell()
	
	var base_spawn = grid_to_world(spawn_grid_pos) + Vector3(0, 3.0, 0)
	print("Base spawn position: ", base_spawn, " (grid: ", spawn_grid_pos, ")")
	
	# Verify the grid position is valid
	print("Grid cell type at spawn: ", maze_grid[spawn_grid_pos.y][spawn_grid_pos.x])
	
	var nav_region = get_navigation_region()
	if not nav_region or not nav_region.navigation_mesh:
		print("No navigation available, using base spawn")
		return base_spawn
	
	var nav_map = nav_region.get_navigation_map()
	if not nav_map.is_valid():
		print("Navigation map not valid, using base spawn")
		return base_spawn
	
	# Test navigation at floor level but spawn above
	var nav_test_pos = Vector3(base_spawn.x, 0.1, base_spawn.z)
	var safe_spawn = NavigationServer3D.map_get_closest_point(nav_map, nav_test_pos)
	safe_spawn.y = 3.0  # Always spawn above floor
	
	print("Navigation test position: ", nav_test_pos)
	print("Closest nav point: ", safe_spawn)
	
	# Check if the navigation point is reasonably close to our intended spawn
	var horizontal_distance = Vector2(base_spawn.x, base_spawn.z).distance_to(Vector2(safe_spawn.x, safe_spawn.z))
	print("Horizontal distance to nav point: ", horizontal_distance)
	
	if horizontal_distance < 1.0:  # Close enough to navigation mesh
		return safe_spawn
	else:
		print("Navigation point too far, using base spawn")
		return base_spawn

# NAVIGATION UTILITIES
func get_navigation_region() -> NavigationRegion3D:
	return find_child("NavigationRegion3D", false, false) as NavigationRegion3D

func is_position_on_navigation_mesh(world_pos: Vector3) -> bool:
	var nav_region = get_navigation_region()
	if not nav_region:
		print("No navigation region found!")
		return false
	if not nav_region.navigation_mesh:
		print("No navigation mesh found!")
		return false
	
	var nav_map = nav_region.get_navigation_map()
	if not nav_map.is_valid():
		print("Navigation map is not valid!")
		return false
	
	var closest_point = NavigationServer3D.map_get_closest_point(nav_map, world_pos)
	var distance = world_pos.distance_to(closest_point)
	var is_on_mesh = distance < 0.3
	
	print("Position ", world_pos, " -> closest nav point: ", closest_point, " (distance: ", distance, ") -> on mesh: ", is_on_mesh)
	return is_on_mesh

func get_safe_navigation_position_for_agent(world_pos: Vector3) -> Vector3:
	var nav_region = get_navigation_region()
	if not nav_region or not nav_region.navigation_mesh:
		return world_pos
	var nav_map = nav_region.get_navigation_map()
	if not nav_map.is_valid():
		return world_pos
	var safe_pos = NavigationServer3D.map_get_closest_point(nav_map, world_pos)
	return safe_pos if world_pos.distance_to(safe_pos) < cell_size * 1.5 else world_pos

func setup_navigation_agent_for_maze(agent: NavigationAgent3D):
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	# OPTIMIZED: Agent settings for better corner navigation
	agent.radius = 0.3  # Smaller radius for better corner navigation
	agent.height = 2.0
	agent.path_desired_distance = 0.2  # Get very close to waypoints
	agent.target_desired_distance = 0.8  # Stop closer to target
	agent.path_max_distance = 100.0  # Allow very long path corrections
	agent.avoidance_enabled = true
	agent.neighbor_distance = 2.0
	agent.max_neighbors = 3
	agent.time_horizon = 1.0
	agent.max_speed = 8.0  # Slightly slower for better navigation
	
	# IMPORTANT: Set debug enabled to see pathfinding
	agent.debug_enabled = true
	agent.debug_use_custom = true
	agent.debug_path_custom_color = Color.RED
	
	print("Navigation agent configured for corner navigation:")
	print("- Radius: ", agent.radius)
	print("- Path desired distance: ", agent.path_desired_distance)
	print("- Target desired distance: ", agent.target_desired_distance)
	print("- Max path distance: ", agent.path_max_distance)

# UTILITY FUNCTIONS
func grid_to_world(grid_pos: Vector2i) -> Vector3:
	return Vector3(grid_pos.x * cell_size, 0, grid_pos.y * cell_size)

func world_to_grid(world_pos: Vector3) -> Vector2i:
	return Vector2i(int(world_pos.x / cell_size), int(world_pos.z / cell_size))

func get_secret_room_positions() -> Array[Vector2i]:
	return secret_rooms

func get_maze_data() -> Array[Array]:
	return maze_grid

# DEBUG FUNCTIONS
func debug_navigation_setup():
	print("=== NAVIGATION DEBUG ===")
	var nav_region = get_navigation_region()
	if not nav_region or not nav_region.navigation_mesh:
		print("ERROR: No navigation mesh!")
		return
	
	var nav_mesh = nav_region.navigation_mesh
	var nav_map = nav_region.get_navigation_map()
	print("Vertices: ", nav_mesh.get_vertices().size())
	print("Polygons: ", nav_mesh.get_polygon_count())
	print("Agent radius: ", nav_mesh.agent_radius)
	print("Map valid: ", nav_map.is_valid())
	
	if nav_mesh.get_vertices().size() > 0:
		var vertices = nav_mesh.get_vertices()
		var min_pos = vertices[0]
		var max_pos = vertices[0]
		for vertex in vertices:
			min_pos.x = min(min_pos.x, vertex.x)
			min_pos.z = min(min_pos.z, vertex.z)
			max_pos.x = max(max_pos.x, vertex.x)
			max_pos.z = max(max_pos.z, vertex.z)
		print("Bounds: ", min_pos, " to ", max_pos)

func debug_spawn_area():
	"""Debug the area around the spawn position"""
	print("=== SPAWN AREA DEBUG ===")
	
	var spawn_grid = Vector2i(1, 1)
	print("Spawn grid position: ", spawn_grid)
	print("Maze grid size: ", maze_grid.size(), "x", maze_grid[0].size() if maze_grid.size() > 0 else 0)
	
	# Check 3x3 area around spawn
	for dy in range(-1, 2):
		var row_str = ""
		for dx in range(-1, 2):
			var check_pos = spawn_grid + Vector2i(dx, dy)
			if is_in_bounds(check_pos):
				var cell_type = maze_grid[check_pos.y][check_pos.x]
				match cell_type:
					CellType.WALL:
						row_str += "W "
					CellType.PATH:
						row_str += "P "
					CellType.EXIT:
						row_str += "E "
					CellType.SECRET_ROOM:
						row_str += "S "
					_:
						row_str += "? "
			else:
				row_str += "X "
		print("Row ", dy + 1, ": ", row_str)
	
	# Check world positions
	var spawn_world = grid_to_world(spawn_grid)
	print("Spawn world position (floor level): ", spawn_world)
	print("Spawn world position (player level): ", spawn_world + Vector3(0, 3.0, 0))
	
	print("========================")

func force_navigation_rebake():
	print("Force rebaking navigation...")
	var nav_region = get_navigation_region()
	if nav_region and nav_region.navigation_mesh:
		nav_region.navigation_mesh.clear()
		await get_tree().process_frame
		bake_navigation_mesh()

func create_expanded_navigation_coverage(center_pos: Vector3, vertices: PackedVector3Array, polygons: Array):
	"""Create additional overlapping navigation tiles around each walkable cell"""
	
	# Create 4 additional offset tiles around the main tile for maximum coverage
	var offset_positions = [
		center_pos + Vector3(cell_size * 0.3, 0, 0),           # East offset
		center_pos + Vector3(-cell_size * 0.3, 0, 0),          # West offset  
		center_pos + Vector3(0, 0, cell_size * 0.3),           # South offset
		center_pos + Vector3(0, 0, -cell_size * 0.3),          # North offset
	]
	
	for offset_pos in offset_positions:
		var tile_size = cell_size * 0.9  # Smaller overlapping tiles
		var half_size = tile_size * 0.5
		
		var start_idx = vertices.size()
		vertices.append_array([
			offset_pos + Vector3(-half_size, 0, -half_size),
			offset_pos + Vector3(half_size, 0, -half_size),
			offset_pos + Vector3(half_size, 0, half_size),
			offset_pos + Vector3(-half_size, 0, half_size)
		])
		
		polygons.append(PackedInt32Array([start_idx + 0, start_idx + 1, start_idx + 2]))
		polygons.append(PackedInt32Array([start_idx + 0, start_idx + 2, start_idx + 3]))

func create_sub_navigation_tiles(center_pos: Vector3, vertices: PackedVector3Array, polygons: Array):
	"""Create multiple sub-tiles around each main navigation tile"""
	
	# Create a 3x3 grid of overlapping sub-tiles centered on the main tile
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue  # Skip center (already created)
			
			var offset = Vector3(dx * cell_size * 0.4, 0, dy * cell_size * 0.4)
			var tile_pos = center_pos + offset
			var tile_size = cell_size * 0.8
			var half_size = tile_size * 0.5
			
			var start_idx = vertices.size()
			vertices.append_array([
				tile_pos + Vector3(-half_size, 0, -half_size),
				tile_pos + Vector3(half_size, 0, -half_size),
				tile_pos + Vector3(half_size, 0, half_size),
				tile_pos + Vector3(-half_size, 0, half_size)
			])
			
			polygons.append(PackedInt32Array([start_idx + 0, start_idx + 1, start_idx + 2]))
			polygons.append(PackedInt32Array([start_idx + 0, start_idx + 2, start_idx + 3]))

func create_enhanced_navigation_bridges_for_region(region: Array, vertices: PackedVector3Array, polygons: Array):
	"""Create WIDER and MORE bridge connections between adjacent cells"""
	
	var bridge_count = 0
	
	for cell_pos in region:
		var cell_type = maze_grid[cell_pos.y][cell_pos.x]
		
		if cell_type == CellType.PATH or cell_type == CellType.EXIT or cell_type == CellType.SECRET_ROOM:
			# Check all 4 directions and create wide bridges
			var directions = [
				Vector2i(1, 0),   # Right
				Vector2i(0, 1),   # Down
				Vector2i(-1, 0),  # Left  
				Vector2i(0, -1),  # Up
			]
			
			for direction in directions:
				var neighbor_pos = cell_pos + direction
				
				if region.has(neighbor_pos):
					var neighbor_type = maze_grid[neighbor_pos.y][neighbor_pos.x]
					if neighbor_type == CellType.PATH or neighbor_type == CellType.EXIT or neighbor_type == CellType.SECRET_ROOM:
						# Create WIDE bridge between these cells
						create_wide_bridge_between_cells(cell_pos, neighbor_pos, vertices, polygons)
						bridge_count += 1
	
	print("  Created ", bridge_count, " wide navigation bridges")

func create_wide_bridge_between_cells(cell1: Vector2i, cell2: Vector2i, vertices: PackedVector3Array, polygons: Array):
	"""Create a WIDE bridge navigation area between two adjacent cells"""
	
	var world_pos1 = Vector3(cell1.x * cell_size, 0.05, cell1.y * cell_size)
	var world_pos2 = Vector3(cell2.x * cell_size, 0.05, cell2.y * cell_size)
	
	var center = (world_pos1 + world_pos2) * 0.5
	var direction = (world_pos2 - world_pos1).normalized()
	var perpendicular = Vector3(-direction.z, 0, direction.x)
	
	# MUCH WIDER bridge dimensions
	var length_half = cell_size * 0.8  # Longer bridge
	var width_half = cell_size * 0.7   # Much wider bridge
	
	var start_idx = vertices.size()
	vertices.append_array([
		center + (-direction * length_half) + (-perpendicular * width_half),
		center + (-direction * length_half) + (perpendicular * width_half),
		center + (direction * length_half) + (perpendicular * width_half),
		center + (direction * length_half) + (-perpendicular * width_half)
	])
	
	polygons.append(PackedInt32Array([start_idx + 0, start_idx + 1, start_idx + 2]))
	polygons.append(PackedInt32Array([start_idx + 0, start_idx + 2, start_idx + 3]))

func create_corridor_based_navigation(vertices: PackedVector3Array, polygons: Array):
	"""Create navigation mesh with LARGE overlapping tiles - SIMPLE VERSION"""
	
	print("Creating large overlapping navigation tiles...")
	
	var created_areas = 0
	
	for y in range(maze_grid.size()):
		for x in range(maze_grid[y].size()):
			var cell_type = maze_grid[y][x]
			
			if cell_type == CellType.PATH or cell_type == CellType.EXIT or cell_type == CellType.SECRET_ROOM:
				var world_pos = Vector3(x * cell_size, 0.05, y * cell_size)
				
				# MUCH LARGER navigation areas with significant overlap
				var nav_size = cell_size * 1.5  # 50% larger than cell size
				var half_size = nav_size * 0.5
				
				var start_idx = vertices.size()
				
				vertices.append_array([
					world_pos + Vector3(-half_size, 0, -half_size),
					world_pos + Vector3(half_size, 0, -half_size),
					world_pos + Vector3(half_size, 0, half_size),
					world_pos + Vector3(-half_size, 0, half_size)
				])
				
				polygons.append(PackedInt32Array([start_idx + 0, start_idx + 1, start_idx + 2]))
				polygons.append(PackedInt32Array([start_idx + 0, start_idx + 2, start_idx + 3]))
				created_areas += 1
	
	print("Created ", created_areas, " large overlapping navigation areas")

func create_corner_navigation_helpers(grid_pos: Vector2i, world_pos: Vector3, vertices: PackedVector3Array, polygons: Array):
	"""Create LARGER corner helpers - SIMPLE VERSION"""
	
	var has_north = is_walkable_cell(grid_pos + Vector2i(0, -1))
	var has_south = is_walkable_cell(grid_pos + Vector2i(0, 1))
	var has_east = is_walkable_cell(grid_pos + Vector2i(1, 0))
	var has_west = is_walkable_cell(grid_pos + Vector2i(-1, 0))
	
	# Create larger corner helpers
	var corner_positions = []
	
	if has_north and has_east:  # Northeast corner
		corner_positions.append(world_pos + Vector3(cell_size * 0.4, 0, -cell_size * 0.4))
	if has_north and has_west:  # Northwest corner
		corner_positions.append(world_pos + Vector3(-cell_size * 0.4, 0, -cell_size * 0.4))
	if has_south and has_east:  # Southeast corner
		corner_positions.append(world_pos + Vector3(cell_size * 0.4, 0, cell_size * 0.4))
	if has_south and has_west:  # Southwest corner
		corner_positions.append(world_pos + Vector3(-cell_size * 0.4, 0, cell_size * 0.4))
	
	# Create MUCH LARGER navigation quads at corner positions
	for corner_pos in corner_positions:
		var corner_size = cell_size * 1.0  # Large corners
		var half_size = corner_size * 0.5
		
		var start_idx = vertices.size()
		vertices.append_array([
			corner_pos + Vector3(-half_size, 0, -half_size),
			corner_pos + Vector3(half_size, 0, -half_size),
			corner_pos + Vector3(half_size, 0, half_size),
			corner_pos + Vector3(-half_size, 0, half_size)
		])
		
		polygons.append(PackedInt32Array([start_idx + 0, start_idx + 1, start_idx + 2]))
		polygons.append(PackedInt32Array([start_idx + 0, start_idx + 2, start_idx + 3]))

func create_seamless_region_navigation(region: Array, vertices: PackedVector3Array, polygons: Array):
	"""Create seamless navigation with LARGE overlap - SIMPLE VERSION"""
	if region.is_empty():
		return
	
	print("Creating seamless navigation for region with ", region.size(), " cells:")
	
	var navigation_created = false
	
	for cell_pos in region:
		var cell_type = maze_grid[cell_pos.y][cell_pos.x]
		
		if cell_type == CellType.PATH or cell_type == CellType.EXIT or cell_type == CellType.SECRET_ROOM:
			var world_pos = Vector3(cell_pos.x * cell_size, 0.05, cell_pos.y * cell_size)
			
			# LARGE overlapping navigation quads
			var base_size = cell_size * 1.4  # 40% larger than cell
			var half_size = base_size * 0.5
			
			var start_idx = vertices.size()
			
			vertices.append_array([
				world_pos + Vector3(-half_size, 0, -half_size),
				world_pos + Vector3(half_size, 0, -half_size),
				world_pos + Vector3(half_size, 0, half_size),
				world_pos + Vector3(-half_size, 0, half_size)
			])
			
			polygons.append(PackedInt32Array([start_idx + 0, start_idx + 1, start_idx + 2]))
			polygons.append(PackedInt32Array([start_idx + 0, start_idx + 2, start_idx + 3]))
			navigation_created = true
	
	# Create bridge connections
	create_navigation_bridges_for_region(region, vertices, polygons)
	
	if not navigation_created:
		print("  No navigation created for this region")
	else:
		print("  Navigation region completed with large overlapping tiles")
