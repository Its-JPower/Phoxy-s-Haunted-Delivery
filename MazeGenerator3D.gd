extends Node3D
class_name MazeGenerator3D

# Maze configuration
@export var maze_size: int = 10
@export var cell_size: float = 4.0
@export var wall_height: float = 3.0
@export var wall_thickness: float = 1.0  # How thick walls are (1.0 = full cell size)
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

# Direction vectors
const DIRECTIONS = [
	Vector2i(0, 1),   # North
	Vector2i(1, 0),   # East
	Vector2i(0, -1),  # South
	Vector2i(-1, 0)   # West
]

var maze_grid: Array[Array]
var secret_rooms: Array[Vector2i] = []

func _ready():
	generate_maze()

func generate_maze():
	# Clear existing maze
	clear_maze()
	
	# Initialize grid
	initialize_grid()
	
	# Generate maze using recursive backtracking
	recursive_backtrack(Vector2i(1, 1))
	
	# Add multiple exits
	create_exits()
	
	# Add secret rooms
	add_secret_rooms()
	
	# Build 3D mesh
	build_3d_maze()

func initialize_grid():
	maze_grid = []
	# Create grid with walls (odd positions will be paths)
	for y in range(maze_size * 2 + 1):
		var row: Array[int] = []
		for x in range(maze_size * 2 + 1):
			row.append(CellType.WALL)
		maze_grid.append(row)

func recursive_backtrack(start_pos: Vector2i):
	var stack: Array[Vector2i] = []
	var current = start_pos
	var visited = {}
	
	# Mark starting position as path
	maze_grid[current.y][current.x] = CellType.PATH
	visited[current] = true
	
	while true:
		var neighbors = get_unvisited_neighbors(current, visited)
		
		if neighbors.size() > 0:
			# Choose random neighbor
			var next_cell = neighbors[randi() % neighbors.size()]
			stack.push_back(current)
			
			# Remove wall between current and next cell
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
		var side = randi() % 4  # 0=top, 1=right, 2=bottom, 3=left
		var exit_pos: Vector2i
		
		match side:
			0:  # Top
				exit_pos = Vector2i(randi_range(1, maze_size * 2 - 1), 0)
			1:  # Right
				exit_pos = Vector2i(maze_size * 2, randi_range(1, maze_size * 2 - 1))
			2:  # Bottom
				exit_pos = Vector2i(randi_range(1, maze_size * 2 - 1), maze_size * 2)
			3:  # Left
				exit_pos = Vector2i(0, randi_range(1, maze_size * 2 - 1))
		
		# Check if there's a path cell adjacent to this exit
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
			if randf() < secret_room_chance:
				if can_place_secret_room(Vector2i(x, y)):
					create_secret_room(Vector2i(x, y))

func can_place_secret_room(pos: Vector2i) -> bool:
	# Check if the area is all walls (we'll replace them with secret room)
	for dy in range(secret_room_size * 2 + 1):
		for dx in range(secret_room_size * 2 + 1):
			var check_pos = pos + Vector2i(dx, dy)
			if not is_in_bounds(check_pos):
				return false
			if maze_grid[check_pos.y][check_pos.x] != CellType.WALL:
				return false
	
	# Check if there's at least one adjacent path cell for access
	var perimeter_positions = []
	for dy in range(-1, secret_room_size * 2 + 2):
		for dx in range(-1, secret_room_size * 2 + 2):
			if dy == -1 or dy == secret_room_size * 2 + 1 or dx == -1 or dx == secret_room_size * 2 + 1:
				var check_pos = pos + Vector2i(dx, dy)
				if is_in_bounds(check_pos):
					perimeter_positions.append(check_pos)
	
	for peri_pos in perimeter_positions:
		if maze_grid[peri_pos.y][peri_pos.x] == CellType.PATH:
			return true
	
	return false

func create_secret_room(pos: Vector2i):
	# Create the secret room
	for dy in range(secret_room_size * 2 + 1):
		for dx in range(secret_room_size * 2 + 1):
			var room_pos = pos + Vector2i(dx, dy)
			if is_in_bounds(room_pos):
				maze_grid[room_pos.y][room_pos.x] = CellType.SECRET_ROOM
	
	# Add secret entrance
	var entrance_candidates = []
	for dy in range(secret_room_size * 2 + 1):
		for dx in range(secret_room_size * 2 + 1):
			if dy == 0 or dy == secret_room_size * 2 or dx == 0 or dx == secret_room_size * 2:
				var entrance_pos = pos + Vector2i(dx, dy)
				
				# Check if this position has an adjacent path
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
	
	# Build walls and floor
	build_walls_and_floor(array_mesh)
	
	mesh_instance.mesh = array_mesh
	add_child(mesh_instance)
	
	# Add proper collision using individual box colliders for walls
	build_collision_shapes()

func build_walls_and_floor(array_mesh: ArrayMesh):
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()
	
	var vertex_count = 0
	
	# First pass: Build a continuous floor across the entire maze area
	var maze_world_size = maze_grid.size() * cell_size
	var floor_half_size = maze_world_size * 0.5
	var floor_center = Vector3(floor_half_size - cell_size * 0.5, 0, floor_half_size - cell_size * 0.5)
	
	# Add one large floor quad for the entire maze
	vertices.append(Vector3(floor_center.x - floor_half_size, 0, floor_center.z - floor_half_size))
	vertices.append(Vector3(floor_center.x + floor_half_size, 0, floor_center.z - floor_half_size))
	vertices.append(Vector3(floor_center.x + floor_half_size, 0, floor_center.z + floor_half_size))
	vertices.append(Vector3(floor_center.x - floor_half_size, 0, floor_center.z + floor_half_size))
	
	for i in range(4):
		normals.append(Vector3.UP)
	
	var uv_scale = maze_grid.size()  # Scale UVs based on maze size
	uvs.append(Vector2(0, 0))
	uvs.append(Vector2(uv_scale, 0))
	uvs.append(Vector2(uv_scale, uv_scale))
	uvs.append(Vector2(0, uv_scale))
	
	# Floor indices
	indices.append(0)
	indices.append(1)
	indices.append(2)
	indices.append(0)
	indices.append(2)
	indices.append(3)
	
	vertex_count = 4
	
	# Second pass: Add walls
	for y in range(maze_grid.size()):
		for x in range(maze_grid[y].size()):
			var cell_type = maze_grid[y][x]
			var world_pos = Vector3(x * cell_size, 0, y * cell_size)
			
			# Add walls for wall cells
			if cell_type == CellType.WALL:
				add_wall_cube(vertices, normals, uvs, indices, world_pos, vertex_count)
				vertex_count += 24  # 6 faces * 4 vertices

	# Create mesh surface
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	# Apply materials
	if wall_material:
		array_mesh.surface_set_material(0, wall_material)

func add_floor_quad(vertices: PackedVector3Array, normals: PackedVector3Array, 
				   uvs: PackedVector2Array, indices: PackedInt32Array, 
				   pos: Vector3, vertex_offset: int):
	
	var half_size = cell_size * 0.5
	
	# Floor vertices (Y = 0) - always full cell size for seamless floors
	vertices.append(Vector3(pos.x - half_size, 0, pos.z - half_size))
	vertices.append(Vector3(pos.x + half_size, 0, pos.z - half_size))
	vertices.append(Vector3(pos.x + half_size, 0, pos.z + half_size))
	vertices.append(Vector3(pos.x - half_size, 0, pos.z + half_size))
	
	# Normals (pointing up)
	for i in range(4):
		normals.append(Vector3.UP)
	
	# UVs
	uvs.append(Vector2(0, 0))
	uvs.append(Vector2(1, 0))
	uvs.append(Vector2(1, 1))
	uvs.append(Vector2(0, 1))
	
	# Indices (two triangles)
	indices.append(vertex_offset + 0)
	indices.append(vertex_offset + 1)
	indices.append(vertex_offset + 2)
	
	indices.append(vertex_offset + 0)
	indices.append(vertex_offset + 2)
	indices.append(vertex_offset + 3)

# Build individual collision shapes for better collision detection
func build_collision_shapes():
	var static_body = StaticBody3D.new()
	static_body.name = "MazeCollision"
	
	for y in range(maze_grid.size()):
		for x in range(maze_grid[y].size()):
			var cell_type = maze_grid[y][x]
			
			# Add collision only for walls
			if cell_type == CellType.WALL:
				var collision_shape = CollisionShape3D.new()
				var box_shape = BoxShape3D.new()
				
				# Set box size - use full cell size for collision to prevent gaps
				box_shape.size = Vector3(cell_size, wall_height, cell_size)
				
				collision_shape.shape = box_shape
				collision_shape.position = Vector3(x * cell_size, wall_height * 0.5, y * cell_size)
				
				static_body.add_child(collision_shape)
	
	# Add floor collision as one large plane
	var floor_collision = CollisionShape3D.new()
	var floor_shape = BoxShape3D.new()
	var maze_world_size = maze_grid.size() * cell_size
	floor_shape.size = Vector3(maze_world_size, 0.1, maze_world_size)
	floor_collision.shape = floor_shape
	floor_collision.position = Vector3(maze_world_size * 0.5 - cell_size * 0.5, -0.05, maze_world_size * 0.5 - cell_size * 0.5)
	static_body.add_child(floor_collision)
	
	add_child(static_body)

func add_wall_cube(vertices: PackedVector3Array, normals: PackedVector3Array,
				  uvs: PackedVector2Array, indices: PackedInt32Array,
				  pos: Vector3, vertex_offset: int):
	
	# For wall connectivity, use full cell size but adjust visual thickness
	var visual_half_size = (cell_size * wall_thickness) * 0.5
	var collision_half_size = cell_size * 0.5  # Full size for connectivity
	
	# Use collision size to ensure walls connect, but this creates solid blocks
	# For better visual appearance with thin walls, we'll use full cell size
	var half_size = collision_half_size  # This ensures walls connect properly
	var height = wall_height
	
	# Define cube vertices
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
	
	# Define face data with CORRECTED winding order: [vertex indices, normal, uv coordinates]
	var faces = [
		# Bottom (Y-) - Fixed winding
		[[3, 2, 1, 0], Vector3.DOWN, [[0,0], [1,0], [1,1], [0,1]]],
		# Top (Y+) - Fixed winding  
		[[4, 5, 6, 7], Vector3.UP, [[0,0], [1,0], [1,1], [0,1]]],
		# Front (Z-) - Fixed winding
		[[0, 1, 5, 4], Vector3.FORWARD, [[0,0], [1,0], [1,1], [0,1]]],
		# Back (Z+) - Fixed winding
		[[2, 3, 7, 6], Vector3.BACK, [[0,0], [1,0], [1,1], [0,1]]],
		# Left (X-) - Fixed winding
		[[3, 0, 4, 7], Vector3.LEFT, [[0,0], [1,0], [1,1], [0,1]]],
		# Right (X+) - Fixed winding
		[[1, 2, 6, 5], Vector3.RIGHT, [[0,0], [1,0], [1,1], [0,1]]]
	]
	
	var face_vertex_offset = vertex_offset
	
	for face_data in faces:
		var face_indices = face_data[0]
		var normal = face_data[1]
		var face_uvs = face_data[2]
		
		# Add vertices for this face
		for i in range(4):
			vertices.append(cube_vertices[face_indices[i]])
			normals.append(normal)
			uvs.append(Vector2(face_uvs[i][0], face_uvs[i][1]))
		
		# Add indices for two triangles (counter-clockwise winding)
		indices.append(face_vertex_offset + 0)
		indices.append(face_vertex_offset + 1)
		indices.append(face_vertex_offset + 2)
		
		indices.append(face_vertex_offset + 0)
		indices.append(face_vertex_offset + 2)
		indices.append(face_vertex_offset + 3)
		
		face_vertex_offset += 4

func clear_maze():
	# Remove all children (previous maze geometry)
	for child in get_children():
		child.queue_free()

func get_secret_room_positions() -> Array[Vector2i]:
	return secret_rooms

func get_maze_data() -> Array[Array]:
	return maze_grid

# Get a safe spawn position for the player
func get_player_spawn_position() -> Vector3:
	# Option 1: Always spawn at the starting position (guaranteed safe)
	var start_grid_pos = Vector2i(1, 1)  # This is where maze generation starts
	return grid_to_world(start_grid_pos) + Vector3(0, 1, 0)  # Add Y offset for player height

# Get multiple possible spawn positions
func get_possible_spawn_positions() -> Array[Vector3]:
	var spawn_positions: Array[Vector3] = []
	
	# Find all path cells that could be good spawn points
	for y in range(1, maze_grid.size() - 1, 2):  # Only check odd positions (path cells)
		for x in range(1, maze_grid[y].size() - 1, 2):
			if maze_grid[y][x] == CellType.PATH:
				# Check if it's not too close to exits (optional)
				if not is_near_exit(Vector2i(x, y), 3):
					var world_pos = grid_to_world(Vector2i(x, y)) + Vector3(0, 1, 0)
					spawn_positions.append(world_pos)
	
	return spawn_positions

# Get a random spawn position (excluding near exits)
func get_random_spawn_position() -> Vector3:
	var possible_positions = get_possible_spawn_positions()
	if possible_positions.size() > 0:
		return possible_positions[randi() % possible_positions.size()]
	else:
		# Fallback to guaranteed safe position
		return get_player_spawn_position()

# Get spawn position farthest from all exits
func get_spawn_position_far_from_exits() -> Vector3:
	var exit_positions: Array[Vector2i] = []
	
	# Find all exit positions
	for y in range(maze_grid.size()):
		for x in range(maze_grid[y].size()):
			if maze_grid[y][x] == CellType.EXIT:
				exit_positions.append(Vector2i(x, y))
	
	var best_position = Vector2i(1, 1)  # Default safe position
	var max_min_distance = 0.0
	
	# Find path cell with maximum distance to nearest exit
	for y in range(1, maze_grid.size() - 1, 2):
		for x in range(1, maze_grid[y].size() - 1, 2):
			if maze_grid[y][x] == CellType.PATH:
				var current_pos = Vector2i(x, y)
				var min_distance_to_exit = INF
				
				# Find distance to nearest exit
				for exit_pos in exit_positions:
					var distance = current_pos.distance_to(exit_pos)
					min_distance_to_exit = min(min_distance_to_exit, distance)
				
				# Update best position if this is farther from exits
				if min_distance_to_exit > max_min_distance:
					max_min_distance = min_distance_to_exit
					best_position = current_pos
	
	return grid_to_world(best_position) + Vector3(0, 1, 0)

# Helper function to check if position is near an exit
func is_near_exit(pos: Vector2i, radius: int) -> bool:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var check_pos = pos + Vector2i(dx, dy)
			if is_in_bounds(check_pos) and maze_grid[check_pos.y][check_pos.x] == CellType.EXIT:
				return true
	return false

# Utility function to get world position from grid coordinates
func grid_to_world(grid_pos: Vector2i) -> Vector3:
	return Vector3(grid_pos.x * cell_size, 0, grid_pos.y * cell_size)

# Utility function to get grid coordinates from world position
func world_to_grid(world_pos: Vector3) -> Vector2i:
	return Vector2i(int(world_pos.x / cell_size), int(world_pos.z / cell_size))
