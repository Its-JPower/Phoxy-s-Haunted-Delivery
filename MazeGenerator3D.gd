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
	
	# Bake navigation mesh after everything is built
	bake_navigation_mesh()

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
	# Build floor first (surface 0)
	build_floor_surface(array_mesh)
	
	# Build walls second (surface 1) 
	build_walls_surface(array_mesh)

func build_floor_surface(array_mesh: ArrayMesh):
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()
	
	# Create one large floor quad for the entire maze
	var maze_world_size = maze_grid.size() * cell_size
	var floor_half_size = maze_world_size * 0.5
	var floor_center = Vector3(floor_half_size - cell_size * 0.5, 0, floor_half_size - cell_size * 0.5)
	
	# Add one large floor quad
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
	
	# Create floor surface
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	# Apply floor material
	if floor_material:
		array_mesh.surface_set_material(0, floor_material)

func build_walls_surface(array_mesh: ArrayMesh):
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()
	
	var vertex_count = 0
	
	# Add walls
	for y in range(maze_grid.size()):
		for x in range(maze_grid[y].size()):
			var cell_type = maze_grid[y][x]
			var world_pos = Vector3(x * cell_size, 0, y * cell_size)
			
			# Add walls for wall cells
			if cell_type == CellType.WALL:
				add_wall_cube(vertices, normals, uvs, indices, world_pos, vertex_count)
				vertex_count += 24  # 6 faces * 4 vertices

	# Create walls surface
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	# Apply wall material
	if wall_material:
		array_mesh.surface_set_material(1, wall_material)

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

# Advanced enemy spawning utilities
func get_dead_end_positions() -> Array[Vector2i]:
	var dead_ends: Array[Vector2i] = []
	
	# Find cells that are paths but only have one neighbor
	for y in range(1, maze_grid.size() - 1, 2):
		for x in range(1, maze_grid[y].size() - 1, 2):
			if maze_grid[y][x] == CellType.PATH:
				var neighbor_count = 0
				
				# Check all 4 directions for path connections
				for direction in DIRECTIONS:
					var neighbor_pos = Vector2i(x, y) + direction
					if is_in_bounds(neighbor_pos) and maze_grid[neighbor_pos.y][neighbor_pos.x] == CellType.PATH:
						neighbor_count += 1
				
				# Dead end = only 1 connection
				if neighbor_count == 1:
					dead_ends.append(Vector2i(x, y))
	
	return dead_ends

func get_intersection_positions() -> Array[Vector2i]:
	var intersections: Array[Vector2i] = []
	
	# Find cells that are paths with 3+ neighbors
	for y in range(1, maze_grid.size() - 1, 2):
		for x in range(1, maze_grid[y].size() - 1, 2):
			if maze_grid[y][x] == CellType.PATH:
				var neighbor_count = 0
				
				# Check all 4 directions for path connections
				for direction in DIRECTIONS:
					var neighbor_pos = Vector2i(x, y) + direction
					if is_in_bounds(neighbor_pos) and maze_grid[neighbor_pos.y][neighbor_pos.x] == CellType.PATH:
						neighbor_count += 1
				
				# Intersection = 3+ connections
				if neighbor_count >= 3:
					intersections.append(Vector2i(x, y))
	
	return intersections

func get_positions_near_exits(radius: int = 3) -> Array[Vector2i]:
	var near_exit_positions: Array[Vector2i] = []
	var exit_positions: Array[Vector2i] = []
	
	# Find all exits first
	for y in range(maze_grid.size()):
		for x in range(maze_grid[y].size()):
			if maze_grid[y][x] == CellType.EXIT:
				exit_positions.append(Vector2i(x, y))
	
	# Find path positions near exits
	for y in range(1, maze_grid.size() - 1, 2):
		for x in range(1, maze_grid[y].size() - 1, 2):
			if maze_grid[y][x] == CellType.PATH:
				var current_pos = Vector2i(x, y)
				
				# Check if within radius of any exit
				for exit_pos in exit_positions:
					if current_pos.distance_to(exit_pos) <= radius:
						near_exit_positions.append(current_pos)
						break
	
	return near_exit_positions

func get_corridor_positions() -> Array[Vector2i]:
	var corridors: Array[Vector2i] = []
	
	# Find cells that are paths with exactly 2 neighbors (corridor pieces)
	for y in range(1, maze_grid.size() - 1, 2):
		for x in range(1, maze_grid[y].size() - 1, 2):
			if maze_grid[y][x] == CellType.PATH:
				var neighbor_count = 0
				
				# Check all 4 directions for path connections
				for direction in DIRECTIONS:
					var neighbor_pos = Vector2i(x, y) + direction
					if is_in_bounds(neighbor_pos) and maze_grid[neighbor_pos.y][neighbor_pos.x] == CellType.PATH:
						neighbor_count += 1
				
				# Corridor = exactly 2 connections
				if neighbor_count == 2:
					corridors.append(Vector2i(x, y))
	
	return corridors

# Get positions far from player spawn
func get_positions_far_from_spawn(min_distance: float = 10.0) -> Array[Vector2i]:
	var spawn_grid_pos = Vector2i(1, 1)  # Default spawn position
	var far_positions: Array[Vector2i] = []
	
	for y in range(1, maze_grid.size() - 1, 2):
		for x in range(1, maze_grid[y].size() - 1, 2):
			if maze_grid[y][x] == CellType.PATH:
				var current_pos = Vector2i(x, y)
				var distance = current_pos.distance_to(spawn_grid_pos)
				
				if distance >= min_distance:
					far_positions.append(current_pos)
	
	return far_positions

# Helper function to check if position is near an exit
func is_near_exit(pos: Vector2i, radius: int) -> bool:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var check_pos = pos + Vector2i(dx, dy)
			if is_in_bounds(check_pos) and maze_grid[check_pos.y][check_pos.x] == CellType.EXIT:
				return true
	return false

# Simplified manual navigation mesh creation
# Replace the create_simple_navigation_mesh function with this improved version

func create_simple_navigation_mesh(nav_region: NavigationRegion3D):
	print("Creating improved navigation mesh manually...")
	
	var nav_mesh = nav_region.navigation_mesh
	nav_mesh.clear()
	
	# Find all connected walkable areas
	var walkable_cells = []
	for y in range(maze_grid.size()):
		for x in range(maze_grid[y].size()):
			var cell_type = maze_grid[y][x]
			if cell_type == CellType.PATH or cell_type == CellType.EXIT or cell_type == CellType.SECRET_ROOM:
				walkable_cells.append(Vector2i(x, y))
	
	if walkable_cells.is_empty():
		print("No walkable cells found!")
		return
	
	# Create larger connected navigation polygons instead of individual tiles
	var processed_cells = {}
	var vertices = PackedVector3Array()
	var polygons = []
	
	for cell in walkable_cells:
		if processed_cells.has(cell):
			continue
			
		# Find rectangular regions of connected walkable cells
		var region = find_rectangular_region(cell, walkable_cells, processed_cells)
		if region.size() > 0:
			create_navigation_polygon_for_region(region, vertices, polygons)
	
	# Apply the navigation mesh
	nav_mesh.set_vertices(vertices)
	for polygon in polygons:
		nav_mesh.add_polygon(polygon)
	
	print("Improved navigation mesh created:")
	print("- Vertices: ", vertices.size())
	print("- Polygons: ", polygons.size())

func find_rectangular_region(start_cell: Vector2i, walkable_cells: Array, processed_cells: Dictionary) -> Array[Vector2i]:
	var region = []
	var cells_to_check = [start_cell]
	var region_cells = {}
	
	# Simple flood fill to find connected walkable area
	while not cells_to_check.is_empty():
		var current_cell = cells_to_check.pop_back()
		
		if processed_cells.has(current_cell) or region_cells.has(current_cell):
			continue
			
		if not walkable_cells.has(current_cell):
			continue
			
		region_cells[current_cell] = true
		region.append(current_cell)
		processed_cells[current_cell] = true
		
		# Add neighboring cells
		for direction in DIRECTIONS:
			var neighbor = current_cell + direction
			if not processed_cells.has(neighbor) and not region_cells.has(neighbor):
				cells_to_check.append(neighbor)
	
	return region

func create_navigation_polygon_for_region(region: Array[Vector2i], vertices: PackedVector3Array, polygons: Array):
	if region.is_empty():
		return
	
	# Find bounds of the region
	var min_x = region[0].x
	var max_x = region[0].x
	var min_y = region[0].y
	var max_y = region[0].y
	
	for cell in region:
		min_x = min(min_x, cell.x)
		max_x = max(max_x, cell.x)
		min_y = min(min_y, cell.y)
		max_y = max(max_y, cell.y)
	
	# Create a single large polygon for the entire connected region
	# Use full cell_size to ensure no gaps
	var world_min = Vector3(min_x * cell_size - cell_size * 0.5, 0.1, min_y * cell_size - cell_size * 0.5)
	var world_max = Vector3(max_x * cell_size + cell_size * 0.5, 0.1, max_y * cell_size + cell_size * 0.5)
	
	var start_idx = vertices.size()
	
	# Add vertices for the bounding rectangle (slightly overlap to prevent gaps)
	var overlap = 0.1  # Small overlap to ensure connection
	vertices.append(Vector3(world_min.x - overlap, 0.1, world_min.z - overlap))  # Bottom-left
	vertices.append(Vector3(world_max.x + overlap, 0.1, world_min.z - overlap))  # Bottom-right
	vertices.append(Vector3(world_max.x + overlap, 0.1, world_max.z + overlap))  # Top-right
	vertices.append(Vector3(world_min.x - overlap, 0.1, world_max.z + overlap))  # Top-left
	
	# Create two triangles for the rectangle
	var poly1 = PackedInt32Array([start_idx, start_idx + 1, start_idx + 2])
	var poly2 = PackedInt32Array([start_idx, start_idx + 2, start_idx + 3])
	
	polygons.append(poly1)
	polygons.append(poly2)

# Alternative approach: Create one massive navigation polygon for all walkable areas
func create_unified_navigation_mesh(nav_region: NavigationRegion3D):
	print("Creating unified navigation mesh...")
	
	var nav_mesh = nav_region.navigation_mesh
	nav_mesh.clear()
	
	var vertices = PackedVector3Array()
	var polygons = []
	
	# Find all walkable cells
	var walkable_cells = []
	for y in range(maze_grid.size()):
		for x in range(maze_grid[y].size()):
			var cell_type = maze_grid[y][x]
			if cell_type == CellType.PATH or cell_type == CellType.EXIT or cell_type == CellType.SECRET_ROOM:
				walkable_cells.append(Vector2i(x, y))
	
	# Create individual quads for each walkable cell with slight overlap
	for cell in walkable_cells:
		var world_pos = Vector3(cell.x * cell_size, 0.1, cell.y * cell_size)
		var half_size = cell_size * 0.51  # Slightly larger than 0.5 to ensure overlap
		
		var start_idx = vertices.size()
		vertices.append(world_pos + Vector3(-half_size, 0, -half_size))
		vertices.append(world_pos + Vector3(half_size, 0, -half_size))
		vertices.append(world_pos + Vector3(half_size, 0, half_size))
		vertices.append(world_pos + Vector3(-half_size, 0, half_size))
		
		# Create two triangles for the quad
		var poly1 = PackedInt32Array([start_idx, start_idx + 1, start_idx + 2])
		var poly2 = PackedInt32Array([start_idx, start_idx + 2, start_idx + 3])
		
		polygons.append(poly1)
		polygons.append(poly2)
	
	nav_mesh.set_vertices(vertices)
	for polygon in polygons:
		nav_mesh.add_polygon(polygon)
	
	print("Unified navigation mesh created:")
	print("- Vertices: ", vertices.size())
	print("- Polygons: ", polygons.size())

# Updated bake_navigation_mesh function with better fallback
# Replace your bake_navigation_mesh function with this fixed version
# Updated navigation mesh settings that work better with agents
func bake_navigation_mesh():
	print("Starting navigation mesh baking...")
	
	# Wait for all geometry and collision to be properly setup
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	var nav_region = find_child("NavigationRegion3D", false, false) as NavigationRegion3D
	
	if not nav_region:
		print("Creating NavigationRegion3D...")
		nav_region = NavigationRegion3D.new()
		nav_region.name = "NavigationRegion3D"
		add_child(nav_region)
		await get_tree().process_frame
	
	if not nav_region.navigation_mesh:
		nav_region.navigation_mesh = NavigationMesh.new()
	
	var nav_mesh = nav_region.navigation_mesh
	nav_mesh.clear()
	
	# CRITICAL: Navigation mesh settings that prevent wall collision
	nav_mesh.cell_size = 0.2
	nav_mesh.cell_height = 0.2
	nav_mesh.agent_height = 2.0
	nav_mesh.agent_radius = 0.6  # INCREASED - creates more distance from walls
	nav_mesh.agent_max_climb = 0.5
	nav_mesh.agent_max_slope = 45.0
	nav_mesh.region_min_size = 1.0  # Increased for more stable regions
	nav_mesh.region_merge_size = 2.0
	nav_mesh.edge_max_length = 8.0
	nav_mesh.edge_max_error = 1.0
	nav_mesh.vertices_per_polygon = 6
	
	# Geometry parsing settings
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	nav_mesh.geometry_collision_mask = 1
	
	print("Baking navigation mesh with agent radius:", nav_mesh.agent_radius)
	nav_region.bake_navigation_mesh()
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	if nav_mesh.get_vertices().size() > 0:
		print("SUCCESS: Navigation mesh baked!")
		print("- Vertices: ", nav_mesh.get_vertices().size())
		print("- Polygons: ", nav_mesh.get_polygon_count())
		print("- Agent radius: ", nav_mesh.agent_radius)
	else:
		print("Auto-baking failed. Creating manual mesh...")
		create_safe_manual_navigation_mesh(nav_region)

# Improved manual navigation mesh with proper wall clearance
func create_safe_manual_navigation_mesh(nav_region: NavigationRegion3D):
	print("Creating safe manual navigation mesh...")
	
	var nav_mesh = nav_region.navigation_mesh
	nav_mesh.clear()
	
	var vertices = PackedVector3Array()
	var polygons = []
	
	# Find walkable cells with safety margin
	var agent_radius = 0.6  # Match the navigation mesh agent radius
	var safety_margin = agent_radius + 0.2  # Extra safety
	
	for y in range(maze_grid.size()):
		for x in range(maze_grid[y].size()):
			var cell_type = maze_grid[y][x]
			
			if cell_type == CellType.PATH or cell_type == CellType.EXIT or cell_type == CellType.SECRET_ROOM:
				# Check if this cell has enough clearance from walls
				if has_safe_clearance(Vector2i(x, y), safety_margin):
					create_safe_navigation_quad(Vector2i(x, y), vertices, polygons, agent_radius)
	
	if vertices.size() == 0:
		print("WARNING: No safe navigation areas found! Creating basic fallback...")
		create_fallback_navigation(vertices, polygons)
	
	nav_mesh.set_vertices(vertices)
	for polygon in polygons:
		nav_mesh.add_polygon(polygon)
	
	print("Safe manual navigation mesh created:")
	print("- Vertices: ", vertices.size())
	print("- Polygons: ", polygons.size())
	print("- Safety margin: ", safety_margin)

func has_safe_clearance(grid_pos: Vector2i, margin_distance: float) -> bool:
	var world_pos = Vector3(grid_pos.x * cell_size, 0, grid_pos.y * cell_size)
	var margin_cells = int(ceil(margin_distance / cell_size))
	
	# Check all cells within the margin distance
	for dy in range(-margin_cells, margin_cells + 1):
		for dx in range(-margin_cells, margin_cells + 1):
			var check_pos = grid_pos + Vector2i(dx, dy)
			
			if is_in_bounds(check_pos):
				var cell_type = maze_grid[check_pos.y][check_pos.x]
				if cell_type == CellType.WALL:
					var check_world_pos = Vector3(check_pos.x * cell_size, 0, check_pos.y * cell_size)
					var distance = world_pos.distance_to(check_world_pos)
					if distance < margin_distance:
						return false
	
	return true

func create_safe_navigation_quad(grid_pos: Vector2i, vertices: PackedVector3Array, polygons: Array, agent_radius: float):
	var world_pos = Vector3(grid_pos.x * cell_size, 0.05, grid_pos.y * cell_size)
	
	# Make navigation area smaller to stay away from walls
	var safe_size = cell_size - (agent_radius * 2.0) - 0.2  # Extra safety margin
	var half_size = safe_size * 0.5
	
	# Only create quad if it's large enough to be useful
	if safe_size > 0.5:
		var start_idx = vertices.size()
		
		vertices.append(world_pos + Vector3(-half_size, 0, -half_size))
		vertices.append(world_pos + Vector3(half_size, 0, -half_size))
		vertices.append(world_pos + Vector3(half_size, 0, half_size))
		vertices.append(world_pos + Vector3(-half_size, 0, half_size))
		
		var poly1 = PackedInt32Array([start_idx + 0, start_idx + 1, start_idx + 2])
		var poly2 = PackedInt32Array([start_idx + 0, start_idx + 2, start_idx + 3])
		
		polygons.append(poly1)
		polygons.append(poly2)

func create_fallback_navigation(vertices: PackedVector3Array, polygons: Array):
	print("Creating basic fallback navigation at spawn...")
	
	# Create a small safe area at the spawn position
	var spawn_world = grid_to_world(Vector2i(1, 1))
	var safe_size = cell_size * 0.8
	var half_size = safe_size * 0.5
	
	var start_idx = vertices.size()
	vertices.append(spawn_world + Vector3(-half_size, 0.05, -half_size))
	vertices.append(spawn_world + Vector3(half_size, 0.05, -half_size))
	vertices.append(spawn_world + Vector3(half_size, 0.05, half_size))
	vertices.append(spawn_world + Vector3(-half_size, 0.05, half_size))
	
	var poly1 = PackedInt32Array([start_idx + 0, start_idx + 1, start_idx + 2])
	var poly2 = PackedInt32Array([start_idx + 0, start_idx + 2, start_idx + 3])
	
	polygons.append(poly1)
	polygons.append(poly2)

# AGENT SETUP FUNCTIONS - Use these for your NavigationAgent3D
func setup_navigation_agent(agent: NavigationAgent3D):
	"""Call this function to properly configure your NavigationAgent3D"""
	
	# CRITICAL: Agent settings must match navigation mesh
	agent.radius = 0.6  # Same as navigation mesh agent_radius
	agent.height = 2.0  # Same as navigation mesh agent_height
	agent.path_desired_distance = 0.8  # Stop before reaching exact target
	agent.target_desired_distance = 1.0  # How close to get to target
	agent.path_max_distance = 3.0  # Maximum distance for path correction
	agent.avoidance_enabled = true
	agent.neighbor_distance = 3.0
	agent.max_neighbors = 5
	agent.time_horizon = 1.5
	agent.max_speed = 3.0
	
	print("Navigation agent configured:")
	print("- Radius: ", agent.radius)
	print("- Height: ", agent.height)
	print("- Desired distance: ", agent.path_desired_distance)

func get_safe_navigation_position(world_pos: Vector3) -> Vector3:
	"""Get a safe navigation position that's not too close to walls"""
	
	var nav_region = get_navigation_region()
	if not nav_region or not nav_region.navigation_mesh:
		return world_pos
	
	# Use NavigationServer3D to find the closest safe point
	var nav_map = nav_region.get_navigation_map()
	var safe_pos = NavigationServer3D.map_get_closest_point(nav_map, world_pos)
	
	# If the safe position is too far, use original
	if world_pos.distance_to(safe_pos) > cell_size * 2:
		return world_pos
	
	return safe_pos

func is_position_safe_for_navigation(world_pos: Vector3) -> bool:
	"""Check if a world position is safe for navigation"""
	
	var nav_region = get_navigation_region()
	if not nav_region or not nav_region.navigation_mesh:
		return false
	
	var nav_map = nav_region.get_navigation_map()
	var closest_point = NavigationServer3D.map_get_closest_point(nav_map, world_pos)
	
	# Position is safe if it's very close to a valid navigation point
	return world_pos.distance_to(closest_point) < 0.5

# Enhanced spawn position that ensures navigation safety
func get_safe_spawn_position() -> Vector3:
	"""Get a spawn position that's guaranteed to be safe for navigation"""
	
	# Start with the basic spawn position
	var base_spawn = get_player_spawn_position()
	
	# Try to find a safe navigation position near the spawn
	var safe_spawn = get_safe_navigation_position(base_spawn)
	
	# If safe position is too far, create a manual safe zone
	if base_spawn.distance_to(safe_spawn) > cell_size:
		print("WARNING: Spawn position not safe for navigation, using fallback")
		return grid_to_world(Vector2i(1, 1)) + Vector3(0, 1, 0)
	
	return safe_spawn

# Debug function to visualize navigation mesh
func debug_navigation_mesh():
	"""Call this to see navigation mesh info"""
	
	var nav_region = get_navigation_region()
	if not nav_region or not nav_region.navigation_mesh:
		print("No navigation mesh found!")
		return
	
	var nav_mesh = nav_region.navigation_mesh
	print("=== NAVIGATION MESH DEBUG ===")
	print("Agent radius: ", nav_mesh.agent_radius)
	print("Agent height: ", nav_mesh.agent_height)
	print("Cell size: ", nav_mesh.cell_size)
	print("Vertices: ", nav_mesh.get_vertices().size())
	print("Polygons: ", nav_mesh.get_polygon_count())
	
	if nav_mesh.get_vertices().size() > 0:
		var vertices = nav_mesh.get_vertices()
		var min_pos = vertices[0]
		var max_pos = vertices[0]
		
		for vertex in vertices:
			min_pos.x = min(min_pos.x, vertex.x)
			min_pos.z = min(min_pos.z, vertex.z)
			max_pos.x = max(max_pos.x, vertex.x)
			max_pos.z = max(max_pos.z, vertex.z)
		
		print("Navigation bounds: ", min_pos, " to ", max_pos)
		print("Navigation area size: ", max_pos - min_pos)
# Debug function to check collision setup
func check_collision_setup():
	print("=== COLLISION DEBUG ===")
	var collision_bodies = find_children("", "StaticBody3D", true, false)
	print("Found ", collision_bodies.size(), " StaticBody3D nodes")
	
	for body in collision_bodies:
		print("- Body: ", body.name, " Layer: ", body.collision_layer, " Mask: ", body.collision_mask)
		var shapes = body.find_children("", "CollisionShape3D", true, false)
		print("  - Collision shapes: ", shapes.size())
		for shape in shapes:
			print("    - Shape: ", shape.shape, " at ", shape.global_position)

# Improved manual navigation mesh creation
func create_manual_navigation_mesh(nav_region: NavigationRegion3D):
	print("Creating manual navigation mesh...")
	
	var nav_mesh = nav_region.navigation_mesh
	nav_mesh.clear()
	
	var vertices = PackedVector3Array()
	var polygons = []
	
	# Find all walkable cells
	var walkable_cells = []
	for y in range(maze_grid.size()):
		for x in range(maze_grid[y].size()):
			var cell_type = maze_grid[y][x]
			if cell_type == CellType.PATH or cell_type == CellType.EXIT or cell_type == CellType.SECRET_ROOM:
				walkable_cells.append(Vector2i(x, y))
	
	print("Found ", walkable_cells.size(), " walkable cells")
	
	if walkable_cells.is_empty():
		print("ERROR: No walkable cells found!")
		return
	
	# Create overlapping navigation polygons for each walkable cell
	for cell in walkable_cells:
		var world_pos = Vector3(cell.x * cell_size, 0.05, cell.y * cell_size)  # Slightly above floor
		var half_size = cell_size * 0.52  # Slight overlap to prevent gaps
		
		var start_idx = vertices.size()
		
		# Add 4 vertices for this cell (counter-clockwise)
		vertices.append(world_pos + Vector3(-half_size, 0, -half_size))  # 0: Bottom-left
		vertices.append(world_pos + Vector3(half_size, 0, -half_size))   # 1: Bottom-right  
		vertices.append(world_pos + Vector3(half_size, 0, half_size))    # 2: Top-right
		vertices.append(world_pos + Vector3(-half_size, 0, half_size))   # 3: Top-left
		
		# Create two triangles with correct winding (counter-clockwise)
		var poly1 = PackedInt32Array([start_idx + 0, start_idx + 1, start_idx + 2])  # First triangle
		var poly2 = PackedInt32Array([start_idx + 0, start_idx + 2, start_idx + 3])  # Second triangle
		
		polygons.append(poly1)
		polygons.append(poly2)
	
	# Apply the manual mesh
	nav_mesh.set_vertices(vertices)
	for polygon in polygons:
		nav_mesh.add_polygon(polygon)
	
	print("Manual navigation mesh created:")
	print("- Vertices: ", vertices.size())
	print("- Polygons: ", polygons.size())
	
	# Force the navigation region to update
	nav_region.navigation_mesh = nav_mesh
	nav_region.enabled = false
	await get_tree().process_frame
	nav_region.enabled = true

# Also update your build_collision_shapes function to ensure proper setup
func build_collision_shapes():
	var static_body = StaticBody3D.new()
	static_body.name = "MazeCollision"
	
	# IMPORTANT: Set collision layers for navigation
	static_body.collision_layer = 1  # Layer 1 = "Walls"
	static_body.collision_mask = 0   # Walls don't need to detect anything
	
	var wall_count = 0
	
	for y in range(maze_grid.size()):
		for x in range(maze_grid[y].size()):
			var cell_type = maze_grid[y][x]
			
			# Add collision only for walls
			if cell_type == CellType.WALL:
				var collision_shape = CollisionShape3D.new()
				var box_shape = BoxShape3D.new()
				
				# Set box size - use full cell size for collision
				box_shape.size = Vector3(cell_size, wall_height, cell_size)
				
				collision_shape.shape = box_shape
				collision_shape.position = Vector3(x * cell_size, wall_height * 0.5, y * cell_size)
				collision_shape.name = "WallCollision_" + str(x) + "_" + str(y)
				
				static_body.add_child(collision_shape)
				wall_count += 1
	
	# Add floor collision (important for navigation mesh generation)
	var floor_collision = CollisionShape3D.new()
	var floor_shape = BoxShape3D.new()
	var maze_world_size = maze_grid.size() * cell_size
	floor_shape.size = Vector3(maze_world_size, 0.1, maze_world_size)
	floor_collision.shape = floor_shape
	floor_collision.position = Vector3(maze_world_size * 0.5 - cell_size * 0.5, -0.05, maze_world_size * 0.5 - cell_size * 0.5)
	floor_collision.name = "FloorCollision"
	static_body.add_child(floor_collision)
	
	add_child(static_body)
	
	print("Maze collision created:")
	print("- Wall collisions: ", wall_count)
	print("- Collision layer: ", static_body.collision_layer)
	print("- Static body ready for navigation")
	
	# Ensure the static body is properly registered
	static_body.set_owner(self)

# Add this function to manually trigger navigation baking for testing
func force_rebake_navigation():
	print("Force rebaking navigation...")
	var nav_region = get_navigation_region()
	if nav_region and nav_region.navigation_mesh:
		nav_region.navigation_mesh.clear()
		await get_tree().process_frame
		nav_region.bake_navigation_mesh()
		await get_tree().process_frame
		
		if nav_region.navigation_mesh.get_vertices().size() > 0:
			print("Force rebake SUCCESS!")
		else:
			print("Force rebake FAILED - using manual mesh")
			create_manual_navigation_mesh(nav_region)

func get_navigation_region() -> NavigationRegion3D:
	return find_child("NavigationRegion3D", false, false) as NavigationRegion3D

# Utility function to get world position from grid coordinates
func grid_to_world(grid_pos: Vector2i) -> Vector3:
	return Vector3(grid_pos.x * cell_size, 0, grid_pos.y * cell_size)

# Utility function to get grid coordinates from world position
func world_to_grid(world_pos: Vector3) -> Vector2i:
	return Vector2i(int(world_pos.x / cell_size), int(world_pos.z / cell_size))
