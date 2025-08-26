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

const DIRECTIONS = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]

var maze_grid: Array[Array]
var secret_rooms: Array[Vector2i] = []
var _navigation_region: NavigationRegion3D

func _ready():
	generate_maze()

func generate_maze():
	clear_maze()
	initialize_grid()
	recursive_backtrack(Vector2i(1, 1))
	create_exits()
	add_secret_rooms()
	build_3d_maze()
	
	# Debug: Print maze state before navigation
	print("Maze generated. Grid size: ", maze_grid.size())
	print("Sample cells: ", maze_grid[1][1], ", ", maze_grid[3][3])
	
	# Build navigation with proper timing
	await build_navigation_mesh_simple()
	
	print("Maze generation complete!")

func initialize_grid():
	maze_grid = []
	var grid_size = maze_size * 2 + 1
	for y in range(grid_size):
		var row: Array[int] = []
		row.resize(grid_size)
		row.fill(CellType.WALL)
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
		
		if is_valid_exit(exit_pos):
			maze_grid[exit_pos.y][exit_pos.x] = CellType.EXIT
			exits_created += 1

func is_valid_exit(exit_pos: Vector2i) -> bool:
	if not is_in_bounds(exit_pos) or maze_grid[exit_pos.y][exit_pos.x] != CellType.WALL:
		return false
	
	for direction in DIRECTIONS:
		var adj_pos = exit_pos + direction
		if is_in_bounds(adj_pos) and maze_grid[adj_pos.y][adj_pos.x] == CellType.PATH:
			return true
	return false

func add_secret_rooms():
	var grid_size = maze_size * 2 + 1
	for y in range(1, grid_size - secret_room_size, 2):
		for x in range(1, grid_size - secret_room_size, 2):
			if randf() < secret_room_chance and can_place_secret_room(Vector2i(x, y)):
				create_secret_room(Vector2i(x, y))

func can_place_secret_room(pos: Vector2i) -> bool:
	# Check if area is all walls
	var room_size = secret_room_size * 2 + 1
	for dy in range(room_size):
		for dx in range(room_size):
			var check_pos = pos + Vector2i(dx, dy)
			if not is_in_bounds(check_pos) or maze_grid[check_pos.y][check_pos.x] != CellType.WALL:
				return false
	
	# Check for adjacent path cells
	for dy in range(-1, room_size + 1):
		for dx in range(-1, room_size + 1):
			if dy == -1 or dy == room_size or dx == -1 or dx == room_size:
				var check_pos = pos + Vector2i(dx, dy)
				if is_in_bounds(check_pos) and maze_grid[check_pos.y][check_pos.x] == CellType.PATH:
					return true
	return false

func create_secret_room(pos: Vector2i):
	var room_size = secret_room_size * 2 + 1
	
	# Create room
	for dy in range(room_size):
		for dx in range(room_size):
			var room_pos = pos + Vector2i(dx, dy)
			if is_in_bounds(room_pos):
				maze_grid[room_pos.y][room_pos.x] = CellType.SECRET_ROOM
	
	# Add entrance
	var entrance_candidates = []
	for dy in range(room_size):
		for dx in range(room_size):
			if dy == 0 or dy == room_size - 1 or dx == 0 or dx == room_size - 1:
				var entrance_pos = pos + Vector2i(dx, dy)
				if has_adjacent_path(entrance_pos):
					entrance_candidates.append(entrance_pos)
	
	if entrance_candidates.size() > 0:
		var entrance = entrance_candidates[randi() % entrance_candidates.size()]
		maze_grid[entrance.y][entrance.x] = CellType.PATH
		secret_rooms.append(pos)

func has_adjacent_path(pos: Vector2i) -> bool:
	for direction in DIRECTIONS:
		var adj_pos = pos + direction
		if is_in_bounds(adj_pos) and maze_grid[adj_pos.y][adj_pos.x] == CellType.PATH:
			return true
	return false

func is_in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < maze_size * 2 + 1 and pos.y >= 0 and pos.y < maze_size * 2 + 1

func build_3d_maze():
	var mesh_instance = MeshInstance3D.new()
	var array_mesh = ArrayMesh.new()
	
	build_combined_mesh(array_mesh)
	
	mesh_instance.mesh = array_mesh
	add_child(mesh_instance)
	build_collision_shapes()

func build_combined_mesh(array_mesh: ArrayMesh):
	# Build floor
	var floor_arrays = create_floor_mesh()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, floor_arrays)
	if floor_material:
		array_mesh.surface_set_material(0, floor_material)
	
	# Build walls
	var wall_arrays = create_walls_mesh()
	if wall_arrays[Mesh.ARRAY_VERTEX].size() > 0:
		array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, wall_arrays)
		if wall_material:
			array_mesh.surface_set_material(1, wall_material)

func create_floor_mesh() -> Array:
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()
	
	var maze_world_size = maze_grid.size() * cell_size
	var half_size = maze_world_size * 0.5
	var center = Vector3(half_size - cell_size * 0.5, 0, half_size - cell_size * 0.5)
	
	vertices.append_array([
		Vector3(center.x - half_size, 0, center.z - half_size),
		Vector3(center.x + half_size, 0, center.z - half_size),
		Vector3(center.x + half_size, 0, center.z + half_size),
		Vector3(center.x - half_size, 0, center.z + half_size)
	])
	
	normals.append_array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	
	var uv_scale = maze_grid.size()
	uvs.append_array([Vector2(0, 0), Vector2(uv_scale, 0), Vector2(uv_scale, uv_scale), Vector2(0, uv_scale)])
	indices.append_array([0, 1, 2, 0, 2, 3])
	
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	
	return arrays

func create_walls_mesh() -> Array:
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
	
	return arrays

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

func build_collision_shapes():
	var static_body = StaticBody3D.new()
	static_body.name = "MazeCollision"
	
	# Single compound collision for all walls
	var wall_positions = []
	for y in range(maze_grid.size()):
		for x in range(maze_grid[y].size()):
			if maze_grid[y][x] == CellType.WALL:
				wall_positions.append(Vector3(x * cell_size, wall_height * 0.5, y * cell_size))
	
	# Batch create wall collisions
	for pos in wall_positions:
		var collision_shape = CollisionShape3D.new()
		var box_shape = BoxShape3D.new()
		box_shape.size = Vector3(cell_size, wall_height, cell_size)
		collision_shape.shape = box_shape
		collision_shape.position = pos
		static_body.add_child(collision_shape)
	
	# Floor collision
	var floor_collision = CollisionShape3D.new()
	var floor_shape = BoxShape3D.new()
	var maze_world_size = maze_grid.size() * cell_size
	var floor_thickness = 2.0
	
	floor_shape.size = Vector3(maze_world_size + cell_size, floor_thickness, maze_world_size + cell_size)
	floor_collision.shape = floor_shape
	floor_collision.position = Vector3(
		maze_world_size * 0.5 - cell_size * 0.5, 
		-floor_thickness * 0.5,
		maze_world_size * 0.5 - cell_size * 0.5
	)
	static_body.add_child(floor_collision)
	
	add_child(static_body)

func clear_maze():
	for child in get_children():
		child.queue_free()

# NAVIGATION SYSTEM - Simplified and optimized
func is_walkable_cell_type(cell_type: int) -> bool:
	return cell_type == CellType.PATH or cell_type == CellType.EXIT or cell_type == CellType.SECRET_ROOM

func create_navigation_quad(grid_pos: Vector2i, vertices: PackedVector3Array, polygons: Array):
	var world_pos = Vector3(grid_pos.x * cell_size, 0.1, grid_pos.y * cell_size)
	var quad_size = cell_size * 0.9  # Slightly smaller for safety
	var half_size = quad_size * 0.5
	
	var start_idx = vertices.size()
	vertices.append_array([
		world_pos + Vector3(-half_size, 0, -half_size),
		world_pos + Vector3(half_size, 0, -half_size),
		world_pos + Vector3(half_size, 0, half_size),
		world_pos + Vector3(-half_size, 0, half_size)
	])
	
	polygons.append(PackedInt32Array([start_idx + 0, start_idx + 1, start_idx + 2]))
	polygons.append(PackedInt32Array([start_idx + 0, start_idx + 2, start_idx + 3]))

# SPAWN AND UTILITY FUNCTIONS - Optimized
func get_player_spawn_position() -> Vector3:
	var spawn_grid_pos = Vector2i(1, 1)  # Guaranteed path cell
	if is_in_bounds(spawn_grid_pos) and maze_grid[spawn_grid_pos.y][spawn_grid_pos.x] == CellType.PATH:
		return grid_to_world(spawn_grid_pos) + Vector3(0, 3.0, 0)
	else:
		# Fallback to first path cell
		return grid_to_world(find_first_path_cell()) + Vector3(0, 3.0, 0)

func get_possible_spawn_positions() -> Array[Vector3]:
	var spawn_positions: Array[Vector3] = []
	
	for y in range(1, maze_grid.size(), 2):
		for x in range(1, maze_grid[y].size(), 2):
			if maze_grid[y][x] == CellType.PATH:
				spawn_positions.append(grid_to_world(Vector2i(x, y)) + Vector3(0, 3.0, 0))
	
	return spawn_positions

func find_first_path_cell() -> Vector2i:
	for y in range(maze_grid.size()):
		for x in range(maze_grid[y].size()):
			if maze_grid[y][x] == CellType.PATH:
				return Vector2i(x, y)
	return Vector2i(1, 1)  # Fallback

func grid_to_world(grid_pos: Vector2i) -> Vector3:
	return Vector3(grid_pos.x * cell_size, 0, grid_pos.y * cell_size)

func world_to_grid(world_pos: Vector3) -> Vector2i:
	return Vector2i(int(world_pos.x / cell_size), int(world_pos.z / cell_size))

# NAVIGATION UTILITIES
func get_navigation_region() -> NavigationRegion3D:
	return _navigation_region

func setup_navigation_agent(agent: NavigationAgent3D):
	agent.radius = 0.5
	agent.height = 2.0
	agent.path_desired_distance = 0.3
	agent.target_desired_distance = 1.0
	agent.avoidance_enabled = false  # Disable for maze navigation

# GETTERS
func get_secret_room_positions() -> Array[Vector2i]:
	return secret_rooms

func get_maze_data() -> Array[Array]:
	return maze_grid

func get_maze_size() -> int:
	return maze_size

# Add these improvements to your existing MazeGenerator3D class

# In the create_navigation_mesh() function, replace it with this improved version:
func create_navigation_mesh():
	var nav_mesh = _navigation_region.navigation_mesh
	nav_mesh.clear()
	
	# Improved navigation mesh properties for better maze navigation
	nav_mesh.agent_radius = 0.3  # Smaller radius for tighter corridors
	nav_mesh.agent_height = 2.0
	nav_mesh.agent_max_climb = 0.3
	nav_mesh.agent_max_slope = 45.0
	nav_mesh.cell_size = 0.1  # Higher resolution
	nav_mesh.cell_height = 0.05
	nav_mesh.region_min_size = 2.0  # Smaller minimum regions
	nav_mesh.region_merge_size = 10.0
	nav_mesh.edge_max_length = 3.0  # Shorter edges for better corridor navigation
	nav_mesh.edge_max_error = 0.5
	nav_mesh.vertices_per_polygon = 6
	nav_mesh.detail_sample_distance = 1.0
	nav_mesh.detail_sample_max_error = 0.5
	
	var vertices = PackedVector3Array()
	var polygons = []
	
	# Create navigation areas for all walkable cells with better coverage
	for y in range(maze_grid.size()):
		for x in range(maze_grid[y].size()):
			var cell_type = maze_grid[y][x]
			if is_walkable_cell_type(cell_type):
				create_enhanced_navigation_quad(Vector2i(x, y), vertices, polygons)
	
	nav_mesh.set_vertices(vertices)
	for polygon in polygons:
		nav_mesh.add_polygon(polygon)
	
	_navigation_region.enabled = true
	print("Navigation mesh created with ", vertices.size(), " vertices and ", polygons.size(), " polygons")

# Also add this helper function to better configure navigation agents:
func setup_navigation_agent_for_maze(agent: NavigationAgent3D):
	"""Optimized navigation agent setup specifically for maze navigation"""
	agent.radius = 0.3
	agent.height = 2.0
	agent.path_desired_distance = 0.2
	agent.target_desired_distance = 0.8
	agent.path_max_distance = 100.0  # Allow long paths through complex mazes
	agent.avoidance_enabled = true
	agent.neighbor_distance = 1.5
	agent.max_neighbors = 2
	agent.time_horizon = 1.0
	agent.max_speed = 4.0

# Replace the entire navigation system in your MazeGenerator3D.gd with this:

func create_walkable_navigation_mesh(nav_mesh: NavigationMesh):
	print("Creating walkable navigation mesh...")
	
	var vertices = PackedVector3Array()
	var polygons = []
	
	# Find all walkable areas and create navigation surfaces
	var walkable_cells = get_all_walkable_cells()
	print("Found ", walkable_cells.size(), " walkable cells")
	
	if walkable_cells.is_empty():
		print("ERROR: No walkable cells found!")
		return
	
	# Create navigation quads for each walkable cell
	for cell_pos in walkable_cells:
		create_navigation_cell(cell_pos, vertices, polygons)
	
	# Set the mesh data
	nav_mesh.set_vertices(vertices)
	for polygon in polygons:
		nav_mesh.add_polygon(polygon)
	
	print("Navigation mesh created with ", vertices.size(), " vertices and ", polygons.size(), " polygons")

func get_all_walkable_cells() -> Array[Vector2i]:
	var walkable_cells: Array[Vector2i] = []
	
	for y in range(maze_grid.size()):
		for x in range(maze_grid[y].size()):
			var cell_type = maze_grid[y][x]
			if is_walkable_cell_type(cell_type):
				walkable_cells.append(Vector2i(x, y))
	
	return walkable_cells

func create_navigation_cell(grid_pos: Vector2i, vertices: PackedVector3Array, polygons: Array):
	# Convert grid position to world position
	var world_pos = grid_to_world(grid_pos)
	world_pos.y = 0.1  # Slightly above the floor
	
	# Create a quad for this cell
	var cell_half_size = cell_size * 0.4  # Smaller to avoid walls
	
	var start_vertex_index = vertices.size()
	
	# Add the four corners of the navigation quad
	vertices.append(world_pos + Vector3(-cell_half_size, 0, -cell_half_size))  # Bottom-left
	vertices.append(world_pos + Vector3(cell_half_size, 0, -cell_half_size))   # Bottom-right
	vertices.append(world_pos + Vector3(cell_half_size, 0, cell_half_size))    # Top-right
	vertices.append(world_pos + Vector3(-cell_half_size, 0, cell_half_size))   # Top-left
	
	# Create two triangles to form the quad
	# Triangle 1: bottom-left, bottom-right, top-right
	polygons.append(PackedInt32Array([
		start_vertex_index + 0,
		start_vertex_index + 1, 
		start_vertex_index + 2
	]))
	
	# Triangle 2: bottom-left, top-right, top-left
	polygons.append(PackedInt32Array([
		start_vertex_index + 0,
		start_vertex_index + 2,
		start_vertex_index + 3
	]))

# Alternative method using Godot's built-in navigation mesh generation
func build_navigation_mesh_automatic():
	print("Building navigation mesh using automatic generation...")
	
	# Wait for scene to be ready
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Remove existing navigation region
	if _navigation_region:
		_navigation_region.queue_free()
		_navigation_region = null
	
	# Create NavigationRegion3D
	_navigation_region = NavigationRegion3D.new()
	_navigation_region.name = "NavigationRegion3D"
	add_child(_navigation_region)
	
	# Create a simple floor mesh for navigation baking
	var floor_mesh = create_navigation_floor_mesh()
	
	# Create MeshInstance3D for the floor
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "NavigationFloor"
	mesh_instance.mesh = floor_mesh
	_navigation_region.add_child(mesh_instance)
	
	# Create navigation mesh and configure it
	var nav_mesh = NavigationMesh.new()
	nav_mesh.agent_radius = 0.4
	nav_mesh.agent_height = 2.0
	nav_mesh.agent_max_climb = 0.5
	nav_mesh.agent_max_slope = 45.0
	nav_mesh.cell_size = 0.3
	nav_mesh.cell_height = 0.1
	nav_mesh.region_min_size = 2.0
	nav_mesh.region_merge_size = 10.0
	
	_navigation_region.navigation_mesh = nav_mesh
	
	# Enable navigation region
	_navigation_region.enabled = true
	
	# Wait for navigation to process
	await get_tree().process_frame
	await get_tree().physics_frame
	
	print("Automatic navigation mesh generation complete!")
	
	# Verify
	if nav_mesh.get_vertices().size() > 0:
		print("SUCCESS: Navigation mesh has ", nav_mesh.get_vertices().size(), " vertices")
	else:
		print("ERROR: Automatic navigation mesh generation failed!")

func create_navigation_floor_mesh() -> ArrayMesh:
	var array_mesh = ArrayMesh.new()
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()
	
	# Create floor quads only for walkable cells
	var walkable_cells = get_all_walkable_cells()
	var vertex_count = 0
	
	for cell_pos in walkable_cells:
		var world_pos = grid_to_world(cell_pos)
		var half_size = cell_size * 0.4
		
		# Add four vertices for this cell
		vertices.append(world_pos + Vector3(-half_size, 0, -half_size))
		vertices.append(world_pos + Vector3(half_size, 0, -half_size))
		vertices.append(world_pos + Vector3(half_size, 0, half_size))
		vertices.append(world_pos + Vector3(-half_size, 0, half_size))
		
		# Add normals
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
		
		# Add UVs
		uvs.append(Vector2(0, 0))
		uvs.append(Vector2(1, 0))
		uvs.append(Vector2(1, 1))
		uvs.append(Vector2(0, 1))
		
		# Add indices for two triangles
		indices.append(vertex_count + 0)
		indices.append(vertex_count + 1)
		indices.append(vertex_count + 2)
		
		indices.append(vertex_count + 0)
		indices.append(vertex_count + 2)
		indices.append(vertex_count + 3)
		
		vertex_count += 4
	
	# Create the mesh
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	return array_mesh

# Add this debug function to test navigation
func debug_navigation_mesh():
	print("=== NAVIGATION DEBUG ===")
	if _navigation_region:
		print("Navigation region exists: ", _navigation_region.enabled)
		if _navigation_region.navigation_mesh:
			var nav_mesh = _navigation_region.navigation_mesh
			print("Navigation mesh vertices: ", nav_mesh.get_vertices().size())
			print("Navigation mesh polygons: ", nav_mesh.get_polygon_count())
			
			# Test if navigation server knows about our mesh
			var nav_map = _navigation_region.get_navigation_map()
			print("Navigation map valid: ", nav_map.is_valid())
			
			if nav_map.is_valid():
				# Test a known walkable position
				var test_pos = grid_to_world(Vector2i(1, 1)) + Vector3(0, 1, 0)
				var closest_point = NavigationServer3D.map_get_closest_point(nav_map, test_pos)
				print("Test position: ", test_pos)
				print("Closest nav point: ", closest_point)
				print("Distance to nav mesh: ", test_pos.distance_to(closest_point))
		else:
			print("ERROR: No navigation mesh!")
	else:
		print("ERROR: No navigation region!")
	print("========================")

# Add this to your MazeGenerator3D class to fix navigation mesh generation

func create_enhanced_navigation_quad(grid_pos: Vector2i, vertices: PackedVector3Array, polygons: Array):
	"""Create larger, overlapping navigation quads for better corridor coverage"""
	var world_pos = Vector3(grid_pos.x * cell_size, 0.05, grid_pos.y * cell_size)
	
	# Use larger quads that overlap slightly to ensure connectivity
	var quad_size = cell_size * 0.95  # Much larger coverage
	var half_size = quad_size * 0.5
	
	var start_idx = vertices.size()
	vertices.append_array([
		world_pos + Vector3(-half_size, 0, -half_size),
		world_pos + Vector3(half_size, 0, -half_size),
		world_pos + Vector3(half_size, 0, half_size),
		world_pos + Vector3(-half_size, 0, half_size)
	])
	
	# Create triangles for the quad
	polygons.append(PackedInt32Array([start_idx + 0, start_idx + 1, start_idx + 2]))
	polygons.append(PackedInt32Array([start_idx + 0, start_idx + 2, start_idx + 3]))

func create_corridor_navigation_mesh(nav_mesh: NavigationMesh):
	"""Create connected navigation areas for maze corridors"""
	print("Creating corridor-based navigation mesh...")
	
	var vertices = PackedVector3Array()
	var polygons = []
	
	# Get all walkable cells
	var walkable_cells = get_all_walkable_cells()
	print("Processing ", walkable_cells.size(), " walkable cells")
	
	# Group connected cells into corridors
	var corridor_groups = group_cells_into_corridors(walkable_cells)
	print("Found ", corridor_groups.size(), " corridor groups")
	
	# Create navigation mesh for each corridor group
	for group in corridor_groups:
		create_corridor_mesh(group, vertices, polygons)
	
	# Set the mesh data
	nav_mesh.set_vertices(vertices)
	for polygon in polygons:
		nav_mesh.add_polygon(polygon)
	
	print("Corridor navigation mesh created with ", vertices.size(), " vertices and ", polygons.size(), " polygons")

func group_cells_into_corridors(walkable_cells: Array[Vector2i]) -> Array:
	"""Group connected walkable cells into corridor segments"""
	var groups = []
	var processed = {}
	
	for cell in walkable_cells:
		if not processed.has(cell):
			var group = get_connected_cells(cell, walkable_cells, processed)
			if group.size() > 0:
				groups.append(group)
	
	return groups

func get_connected_cells(start_cell: Vector2i, all_cells: Array[Vector2i], processed: Dictionary) -> Array[Vector2i]:
	"""Get all cells connected to start_cell"""
	var group: Array[Vector2i] = []
	var queue: Array[Vector2i] = [start_cell]
	
	while not queue.is_empty():
		var current = queue.pop_front()
		
		if processed.has(current):
			continue
		
		processed[current] = true
		group.append(current)
		
		# Check adjacent cells
		for direction in DIRECTIONS:
			var adjacent = current + direction
			if adjacent in all_cells and not processed.has(adjacent):
				queue.append(adjacent)
	
	return group

func create_corridor_mesh(corridor_cells: Array[Vector2i], vertices: PackedVector3Array, polygons: Array):
	"""Create a single mesh for an entire corridor"""
	if corridor_cells.is_empty():
		return
	
	# Find the bounding box of the corridor
	var min_x = corridor_cells[0].x
	var max_x = corridor_cells[0].x
	var min_y = corridor_cells[0].y
	var max_y = corridor_cells[0].y
	
	for cell in corridor_cells:
		min_x = min(min_x, cell.x)
		max_x = max(max_x, cell.x)
		min_y = min(min_y, cell.y)
		max_y = max(max_y, cell.y)
	
	# Create a large navigation area covering the entire corridor
	var world_min = Vector3(min_x * cell_size - cell_size * 0.4, 0.05, min_y * cell_size - cell_size * 0.4)
	var world_max = Vector3(max_x * cell_size + cell_size * 0.4, 0.05, max_y * cell_size + cell_size * 0.4)
	
	var start_idx = vertices.size()
	
	# Create a large quad covering the entire corridor
	vertices.append_array([
		Vector3(world_min.x, 0.05, world_min.z),  # Bottom-left
		Vector3(world_max.x, 0.05, world_min.z),  # Bottom-right
		Vector3(world_max.x, 0.05, world_max.z),  # Top-right
		Vector3(world_min.x, 0.05, world_max.z)   # Top-left
	])
	
	# Create triangles
	polygons.append(PackedInt32Array([start_idx + 0, start_idx + 1, start_idx + 2]))
	polygons.append(PackedInt32Array([start_idx + 0, start_idx + 2, start_idx + 3]))

# Replace your build_navigation_mesh function with this improved version:
func build_navigation_mesh():
	print("Building improved navigation mesh...")
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Remove existing navigation region
	if _navigation_region:
		_navigation_region.queue_free()
		_navigation_region = null
	
	# Create new navigation region
	_navigation_region = NavigationRegion3D.new()
	_navigation_region.name = "NavigationRegion3D"
	add_child(_navigation_region)
	
	# Create and configure navigation mesh
	var nav_mesh = NavigationMesh.new()
	_navigation_region.navigation_mesh = nav_mesh
	
	# Optimized settings for maze navigation
	nav_mesh.agent_radius = 0.3
	nav_mesh.agent_height = 2.0
	nav_mesh.agent_max_climb = 0.3
	nav_mesh.agent_max_slope = 45.0
	nav_mesh.cell_size = 0.2  # Smaller cells for better precision
	nav_mesh.cell_height = 0.05
	nav_mesh.region_min_size = 1.0  # Allow smaller regions
	nav_mesh.region_merge_size = 5.0
	nav_mesh.edge_max_length = 2.0  # Shorter edges
	nav_mesh.edge_max_error = 0.3
	nav_mesh.vertices_per_polygon = 6
	nav_mesh.detail_sample_distance = 1.0
	nav_mesh.detail_sample_max_error = 0.3
	
	print("Navigation mesh properties configured")
	
	# Use the improved corridor-based navigation mesh generation
	create_corridor_navigation_mesh(nav_mesh)
	
	# Enable the navigation region
	_navigation_region.enabled = true
	
	# Wait for navigation server to process
	await get_tree().process_frame
	await get_tree().physics_frame
	
	print("Improved navigation mesh generation complete!")
	
	# Verify the mesh was created
	if nav_mesh.get_vertices().size() > 0:
		print("SUCCESS: Navigation mesh has ", nav_mesh.get_vertices().size(), " vertices")
		print("Polygons: ", nav_mesh.get_polygon_count())
		debug_navigation_coverage()
	else:
		print("ERROR: Navigation mesh has no vertices!")

func debug_navigation_coverage():
	"""Debug function to check navigation coverage"""
	if not _navigation_region or not _navigation_region.navigation_mesh:
		return
		
	var nav_map = _navigation_region.get_navigation_map()
	if not nav_map.is_valid():
		print("Navigation map not valid for coverage test")
		return
	
	# Test a few key positions
	var test_positions = [
		grid_to_world(Vector2i(1, 1)),  # Start position
		grid_to_world(Vector2i(3, 3)),  # Interior position
		grid_to_world(Vector2i(maze_size * 2 - 1, maze_size * 2 - 1))  # End position
	]
	
	print("Testing navigation coverage:")
	for i in range(test_positions.size()):
		var pos = test_positions[i]
		var closest = NavigationServer3D.map_get_closest_point(nav_map, pos)
		var distance = pos.distance_to(closest)
		print("Test ", i + 1, ": ", pos, " -> ", closest, " (distance: ", distance, ")")

# Add this to your MazeGenerator3D class to debug navigation mesh generation

func debug_navigation_generation():
	"""Call this function to see what's happening with navigation mesh generation"""
	print("=== NAVIGATION MESH DEBUG ===")
	
	# Check if we have a navigation region
	if not _navigation_region:
		print("ERROR: No _navigation_region exists!")
		return
	else:
		print("Navigation region exists: ", _navigation_region.name)
		print("Navigation region enabled: ", _navigation_region.enabled)
	
	# Check navigation mesh
	var nav_mesh = _navigation_region.navigation_mesh
	if not nav_mesh:
		print("ERROR: No navigation mesh assigned to region!")
		return
	else:
		print("Navigation mesh exists")
		print("Vertices: ", nav_mesh.get_vertices().size())
		print("Polygons: ", nav_mesh.get_polygon_count())
	
	# Check walkable cells
	var walkable_cells = get_all_walkable_cells()
	print("Walkable cells found: ", walkable_cells.size())
	if walkable_cells.size() > 0:
		print("First few walkable cells: ", walkable_cells.slice(0, min(5, walkable_cells.size())))
	
	# Check navigation map
	var nav_map = _navigation_region.get_navigation_map()
	print("Navigation map valid: ", nav_map.is_valid())
	
	if nav_map.is_valid():
		# Test a specific position
		var test_pos = grid_to_world(Vector2i(1, 1)) + Vector3(0, 1, 0)
		var closest_point = NavigationServer3D.map_get_closest_point(nav_map, test_pos)
		print("Test position: ", test_pos)
		print("Closest nav point: ", closest_point)
		print("Distance: ", test_pos.distance_to(closest_point))
	
	print("=============================")

# Simple navigation mesh generation that should definitely work
func create_simple_navigation_mesh():
	"""Create a basic navigation mesh that definitely works"""
	print("Creating simple navigation mesh...")
	
	# Remove existing navigation region
	if _navigation_region:
		_navigation_region.queue_free()
		await get_tree().process_frame
	
	# Create new navigation region
	_navigation_region = NavigationRegion3D.new()
	_navigation_region.name = "NavigationRegion3D"
	add_child(_navigation_region)
	
	# Create navigation mesh
	var nav_mesh = NavigationMesh.new()
	_navigation_region.navigation_mesh = nav_mesh
	
	# Simple, guaranteed-to-work settings
	nav_mesh.agent_radius = 0.5
	nav_mesh.agent_height = 2.0
	nav_mesh.cell_size = 0.5
	nav_mesh.cell_height = 0.2
	
	# Get walkable cells
	var walkable_cells = get_all_walkable_cells()
	print("Found ", walkable_cells.size(), " walkable cells")
	
	if walkable_cells.is_empty():
		print("ERROR: No walkable cells found!")
		return
	
	# Create vertices and polygons manually
	var vertices = PackedVector3Array()
	var polygons = []
	
	for cell in walkable_cells:
		var world_pos = grid_to_world(cell)
		world_pos.y = 0.1  # Slightly above floor
		
		var size = cell_size * 0.8  # Large enough to be useful
		var half = size * 0.5
		
		var start_idx = vertices.size()
		
		# Add 4 vertices for this cell
		vertices.append(world_pos + Vector3(-half, 0, -half))
		vertices.append(world_pos + Vector3(half, 0, -half))
		vertices.append(world_pos + Vector3(half, 0, half))
		vertices.append(world_pos + Vector3(-half, 0, half))
		
		# Add 2 triangles
		polygons.append(PackedInt32Array([start_idx, start_idx + 1, start_idx + 2]))
		polygons.append(PackedInt32Array([start_idx, start_idx + 2, start_idx + 3]))
	
	# Set mesh data
	nav_mesh.set_vertices(vertices)
	for polygon in polygons:
		nav_mesh.add_polygon(polygon)
	
	print("Simple navigation mesh created:")
	print("- Vertices: ", vertices.size())
	print("- Polygons: ", polygons.size())
	
	# Enable region
	_navigation_region.enabled = true
	
	# Wait for processing
	await get_tree().process_frame
	await get_tree().physics_frame
	
	# Verify it worked
	if nav_mesh.get_vertices().size() > 0:
		print("SUCCESS: Simple navigation mesh working!")
		debug_navigation_generation()
	else:
		print("FAILED: Simple navigation mesh has no vertices")

# Add this to your _ready() function or call it manually for testing
func test_navigation_generation():
	"""Test function to verify navigation generation works"""
	print("Testing navigation generation...")
	
	# Wait for maze to be fully generated
	await get_tree().create_timer(1.0).timeout
	
	# Try the simple navigation mesh
	await create_simple_navigation_mesh()
	
	# Debug the results
	debug_navigation_generation()

# Replace your existing build_navigation_mesh function with this simpler version:
func build_navigation_mesh_simple():
	print("Building simple navigation mesh...")
	
	# Wait for scene setup
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Clear existing
	if _navigation_region:
		_navigation_region.queue_free()
		_navigation_region = null
	
	await get_tree().process_frame
	
	# Create navigation region
	_navigation_region = NavigationRegion3D.new()
	_navigation_region.name = "NavigationRegion3D"
	add_child(_navigation_region)
	
	# Create and configure navigation mesh
	var nav_mesh = NavigationMesh.new()
	nav_mesh.agent_radius = 0.4
	nav_mesh.agent_height = 2.0
	nav_mesh.agent_max_climb = 0.5
	nav_mesh.cell_size = 0.3
	nav_mesh.cell_height = 0.1
	
	# Get all walkable positions
	var walkable_cells = get_all_walkable_cells()
	print("Processing ", walkable_cells.size(), " walkable cells for navigation")
	
	if walkable_cells.is_empty():
		print("ERROR: No walkable cells found!")
		return
	
	# Create simple navigation quads
	var vertices = PackedVector3Array()
	var polygons = []
	
	for cell_pos in walkable_cells:
		var world_pos = grid_to_world(cell_pos) + Vector3(0, 0.1, 0)
		var quad_size = cell_size * 0.8
		var half = quad_size * 0.5
		
		var vertex_start = vertices.size()
		
		vertices.append_array([
			world_pos + Vector3(-half, 0, -half),
			world_pos + Vector3(half, 0, -half),
			world_pos + Vector3(half, 0, half),
			world_pos + Vector3(-half, 0, half)
		])
		
		polygons.append(PackedInt32Array([vertex_start, vertex_start + 1, vertex_start + 2]))
		polygons.append(PackedInt32Array([vertex_start, vertex_start + 2, vertex_start + 3]))
	
	# Apply to navigation mesh
	nav_mesh.set_vertices(vertices)
	for polygon in polygons:
		nav_mesh.add_polygon(polygon)
	
	_navigation_region.navigation_mesh = nav_mesh
	_navigation_region.enabled = true
	
	# Wait for navigation server
	await get_tree().process_frame
	await get_tree().physics_frame
	
	print("Navigation mesh created with ", vertices.size(), " vertices, ", polygons.size(), " polygons")
	
	# Verify
	if nav_mesh.get_vertices().size() > 0:
		print("Navigation mesh generation successful!")
		var nav_map = _navigation_region.get_navigation_map()
		print("Navigation map valid: ", nav_map.is_valid())
	else:
		print("ERROR: Navigation mesh generation failed!")
