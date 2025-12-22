module game::world;
import engine::math;
import engine::math::noise;
import engine::gfx;
import engine::core;
import std::io;
import std::thread;


const uint CHUNK_WIDTH = 16;
const uint CHUNK_HEIGHT = 256;
const uint CHUNK_VOLUME = CHUNK_WIDTH
	* CHUNK_WIDTH
	* CHUNK_HEIGHT;


const uint REGION_SIZE = 12;
const int REGION_RADIUS = (int)(REGION_SIZE / 2);
const int RENDER_RADIUS = REGION_RADIUS;
const int MESH_JOB_CAP = 32;
const int MESH_RESULT_CAP = 32;

enum BlockType: const int {
	AIR = -1,
	GRASS,
	DIRT,
	STONE
}

struct Block {
	BlockType type;
}

struct Chunk {
	Block[CHUNK_VOLUME] blocks;
	Mesh mesh;
	bool dirty;
	bool mesh_queued;
	bool mesh_building;
	uint generation;
	Vec2i pos;
}

struct World {
	Chunk*[REGION_SIZE * REGION_SIZE] chunks;
	Vec2i origin;
	Vec2i last_player_chunk;
	bool initialized;
}

struct BlockTexture {
	union {
		struct {
			uint front;
			uint back;
			uint left;
			uint right;
			uint top;
			uint bottom;
		}
		uint[6] inner;
	}
}

const BlockTexture[] TEXTURE_ATLAS @private = {
	{ // GRASS BLOCK
		2, 2, 2, 2, 1, 0
	},
	{ // DIRT BLOCK
		0, 0, 0, 0, 0, 0
	},
	{ // STONE BLOCK
		3, 3, 3, 3, 3, 3
	}

};

macro int coords_to_arr(p) => ((p.z * CHUNK_WIDTH * CHUNK_HEIGHT) + (p.y * CHUNK_WIDTH) + p.x);
macro int boundary_index(y, z) => ((z * CHUNK_HEIGHT) + y);

struct NeighborChunks {
	Chunk* pos_x;
	Chunk* neg_x;
	Chunk* pos_z;
	Chunk* neg_z;
}

struct MeshJob {
	Chunk* chunk;
	Vec2i chunk_pos;
	uint generation;
	Block[CHUNK_VOLUME] blocks;
	BlockType[CHUNK_HEIGHT * CHUNK_WIDTH] pos_x;
	BlockType[CHUNK_HEIGHT * CHUNK_WIDTH] neg_x;
	BlockType[CHUNK_HEIGHT * CHUNK_WIDTH] pos_z;
	BlockType[CHUNK_HEIGHT * CHUNK_WIDTH] neg_z;
	bool has_pos_x;
	bool has_neg_x;
	bool has_pos_z;
	bool has_neg_z;
}

struct MeshResult {
	Chunk* chunk;
	uint generation;
	float[] vertices;
	uint[] indices;
}

struct MeshQueue {
	thread::Thread worker;
	thread::Mutex mutex;
	thread::ConditionVariable cond;
	bool running;
	bool stop_requested;
	MeshJob*[MESH_JOB_CAP] pending;
	int pending_count;
	MeshResult[MESH_RESULT_CAP] completed;
	int completed_count;
}

MeshQueue g_mesh_queue;

<*
 Converts a linear block index into chunk-local coordinates.
*>
fn Vec3i arr_to_coords(int i) {
	int z = i / (CHUNK_WIDTH * CHUNK_HEIGHT);
	i -= (z * CHUNK_WIDTH * CHUNK_HEIGHT);
	int y = i / CHUNK_WIDTH;
	int x = i % CHUNK_WIDTH;
	return {x, y, z};

}

<*
 Returns the block type for a local position.
 This is the hook for procedural generation later.
*>
fn BlockType block_type_at(Vec3i local_pos, Vec2i chunk_pos) {
	//int surface = CHUNK_HEIGHT - 20 /*+ local_pos.x*/ + (chunk_pos.x + chunk_pos.y) * 0;
	int x = local_pos.x + chunk_pos.x * CHUNK_WIDTH;
	int y = local_pos.z + chunk_pos.y * CHUNK_WIDTH;

	float zoom = 0.01f;
	int surface = (int)(200 + noise::simplex2((float)x * zoom, (float)y * zoom) * 20);
	if(local_pos.y <= surface - 2) return STONE;
	if(local_pos.y > surface - 2 && local_pos.y < surface) return DIRT;
	if(local_pos.y == surface) return GRASS;
	return AIR;
}

<*
 Fills the chunk with blocks for the given world chunk position.
*>
fn void generate_chunk_blocks(Chunk* chunk, Vec2i pos) {
	chunk.pos = pos;
	chunk.generation += 1;
	chunk.mesh_queued = false;
	chunk.mesh_building = false;
	chunk.dirty = true;
	chunk.mesh.count = 0;
	for(int x = 0; x < CHUNK_WIDTH; x++) {
		for(int y = 0; y < CHUNK_HEIGHT; y++) {
			for(int z = 0; z < CHUNK_WIDTH; z++) {
				Vec3i local_pos = {x, y, z};
				int idx = coords_to_arr(local_pos);
				chunk.blocks[idx] = { block_type_at(local_pos, pos) };
			}
		}
	}
}

<*
 Allocates and initializes a chunk at the given position.
*>
fn Chunk* generate_chunk(Vec2i pos) {
	// Zero-init mesh so GL handles start at 0; uninitialised handles cause UB in Mesh.make.
	Chunk* chunk = mem::new(Chunk, { .mesh = {}, .dirty = true });
	generate_chunk_blocks(chunk, pos);
	return chunk;
}

<*
 Builds or rebuilds the chunk mesh from current block data.
*>
fn Chunk* find_chunk(World *world, Vec2i pos) {
	for(usz i = 0; i < world.chunks.len; i++) {
		Chunk* chunk = world.chunks[i];
		if(chunk == null) continue;
		if(chunk.pos == pos) return chunk;
	}
	return null;
}

<*
 Captures neighbor chunk pointers for boundary sampling.
*>
fn NeighborChunks gather_neighbors(World *world, Vec2i pos) {
	return {
		.pos_x = find_chunk(world, {pos.x + 1, pos.y}),
		.neg_x = find_chunk(world, {pos.x - 1, pos.y}),
		.pos_z = find_chunk(world, {pos.x, pos.y + 1}),
		.neg_z = find_chunk(world, {pos.x, pos.y - 1})
	};
}

fn void snapshot_chunk_job(MeshJob* job, World *world, Chunk* chunk) {
	*job = {};
	job.chunk = chunk;
	job.chunk_pos = chunk.pos;
	job.generation = chunk.generation;
	job.blocks = chunk.blocks;

	NeighborChunks neighbors = gather_neighbors(world, chunk.pos);
	if(neighbors.pos_x != null) {
		job.has_pos_x = true;
		for(int y = 0; y < (int)CHUNK_HEIGHT; y++) {
			for(int z = 0; z < (int)CHUNK_WIDTH; z++) {
				job.pos_x[boundary_index(y, z)] =
					neighbors.pos_x.blocks[coords_to_arr((Vec3i){0, y, z})].type;
			}
		}
	}
	if(neighbors.neg_x != null) {
		job.has_neg_x = true;
		for(int y = 0; y < (int)CHUNK_HEIGHT; y++) {
			for(int z = 0; z < (int)CHUNK_WIDTH; z++) {
				job.neg_x[boundary_index(y, z)] =
					neighbors.neg_x.blocks[coords_to_arr((Vec3i){(int)CHUNK_WIDTH - 1, y, z})].type;
			}
		}
	}
	if(neighbors.pos_z != null) {
		job.has_pos_z = true;
		for(int y = 0; y < (int)CHUNK_HEIGHT; y++) {
			for(int x = 0; x < (int)CHUNK_WIDTH; x++) {
				job.pos_z[boundary_index(y, x)] =
					neighbors.pos_z.blocks[coords_to_arr((Vec3i){x, y, 0})].type;
			}
		}
	}
	if(neighbors.neg_z != null) {
		job.has_neg_z = true;
		for(int y = 0; y < (int)CHUNK_HEIGHT; y++) {
			for(int x = 0; x < (int)CHUNK_WIDTH; x++) {
				job.neg_z[boundary_index(y, x)] =
					neighbors.neg_z.blocks[coords_to_arr((Vec3i){x, y, (int)CHUNK_WIDTH - 1})].type;
			}
		}
	}
}

fn BlockType neighbor_block_from_job(MeshJob* job, Vec3i local_pos, int dir) {
	switch(dir) {
		case 0: { // +Z
			if(local_pos.z < (int)CHUNK_WIDTH - 1) {
				return job.blocks[coords_to_arr(local_pos + (Vec3i){0, 0, 1})].type;
			}
			if(!job.has_pos_z) return AIR;
			return job.pos_z[boundary_index(local_pos.y, local_pos.x)];
		}
		case 1: { // -Z
			if(local_pos.z > 0) {
				return job.blocks[coords_to_arr(local_pos + (Vec3i){0, 0, -1})].type;
			}
			if(!job.has_neg_z) return AIR;
			return job.neg_z[boundary_index(local_pos.y, local_pos.x)];
		}
		case 2: { // -X
			if(local_pos.x > 0) {
				return job.blocks[coords_to_arr(local_pos + (Vec3i){-1, 0, 0})].type;
			}
			if(!job.has_neg_x) return AIR;
			return job.neg_x[boundary_index(local_pos.y, local_pos.z)];
		}
		case 3: { // +X
			if(local_pos.x < (int)CHUNK_WIDTH - 1) {
				return job.blocks[coords_to_arr(local_pos + (Vec3i){1, 0, 0})].type;
			}
			if(!job.has_pos_x) return AIR;
			return job.pos_x[boundary_index(local_pos.y, local_pos.z)];
		}
		case 4: { // +Y
			if(local_pos.y < (int)CHUNK_HEIGHT - 1) {
				return job.blocks[coords_to_arr(local_pos + (Vec3i){0, 1, 0})].type;
			}
			return AIR;
		}
		case 5: { // -Y
			if(local_pos.y > 0) {
				return job.blocks[coords_to_arr(local_pos + (Vec3i){0, -1, 0})].type;
			}
			return AIR;
		}
		default: core::error("Unreachable Code reached inside neighbor_block_from_job");
	}
	core::error("Unreachable Code reached inside neighbour_block_from_job");
	return AIR;
}

fn MeshResult build_mesh_result(MeshJob* job) {
	Listf chunk_vertices;
	Listui chunk_indices;

	chunk_vertices.init(mem, 1024);
	chunk_indices.init(mem, 1024);

	for(int i = 0; i < job.blocks.len; i++) {
		Block block = job.blocks[i];
		Vec3i pos = arr_to_coords(i);
		if(block.type == AIR) continue;

		for (int d = 0; d < 6; d++) {
			BlockType neighbor = neighbor_block_from_job(job, pos, d);

			// Only draw exposed faces.
			if(neighbor != AIR) continue;

			// Copy face template so we do not mutate the shared const vertex data.
			float[gfx::CUBE_FLOAT_STRIDE * 4] new_slice = gfx::get_cube_face_vert(d);
			uint[6] new_slice_idx = gfx::get_cube_face_idx(d);
			usz base_vert = chunk_vertices.len() / gfx::CUBE_FLOAT_STRIDE;
			uint face_vertex_base = (uint)(d * 4);

			// offset vertex and set texture
			for(int p = 0; p < 4; p++) {
				new_slice[p * gfx::CUBE_FLOAT_STRIDE + 0] += (float)(pos.x + job.chunk_pos.x * (int)CHUNK_WIDTH);
				new_slice[p * gfx::CUBE_FLOAT_STRIDE + 1] += (float)pos.y;
				new_slice[p * gfx::CUBE_FLOAT_STRIDE + 2] += (float)(pos.z + job.chunk_pos.y * (int)CHUNK_WIDTH);

				new_slice[p * gfx::CUBE_FLOAT_STRIDE + 8] = TEXTURE_ATLAS[(int)block.type].inner[d];
			}

			// edit update indices
			for(int o = 0; o < new_slice_idx.len; o++) {
				new_slice_idx[o] = (new_slice_idx[o] - face_vertex_base) + (uint)base_vert;
			}

			chunk_vertices.push_all(&new_slice);
			chunk_indices.push_all(&new_slice_idx);
		}
	}

	float[] verts_arr = chunk_vertices.to_array(mem);
	uint[] idx_arr = chunk_indices.to_array(mem);

	chunk_indices.free();
	chunk_vertices.free();

	return {
		.chunk = job.chunk,
		.generation = job.generation,
		.vertices = verts_arr,
		.indices = idx_arr
	};
}

fn void free_mesh_result(MeshResult* result) {
	if(result.vertices.ptr != null) mem::free(result.vertices.ptr);
	if(result.indices.ptr != null) mem::free(result.indices.ptr);
	*result = {};
}

fn void apply_mesh_result(MeshResult* result) {
	if(result.chunk == null) {
		free_mesh_result(result);
		return;
	}
	result.chunk.mesh.make(result.vertices, result.indices, gfx::CUBE_FLOAT_STRIDE);
	free_mesh_result(result);
}

fn int mesh_worker_main(void* arg) {
	MeshQueue* queue = (MeshQueue*)arg;
	for(;;) {
		queue.mutex.lock()!!;
		while(queue.pending_count == 0 && !queue.stop_requested) {
			queue.cond.wait(&queue.mutex)!!;
		}
		if(queue.stop_requested) {
			queue.mutex.unlock()!!;
			break;
		}

		queue.pending_count -= 1;
		MeshJob* job = queue.pending[queue.pending_count];
		job.chunk.mesh_queued = false;
		job.chunk.mesh_building = true;
		queue.mutex.unlock()!!;

		MeshResult result = build_mesh_result(job);
		mem::free(job);

		queue.mutex.lock()!!;
		if(queue.completed_count < MESH_RESULT_CAP) {
			queue.completed[queue.completed_count] = result;
			queue.completed_count += 1;
		} else {
			free_mesh_result(&result);
			if(result.chunk != null) {
				result.chunk.mesh_building = false;
			}
		}
		queue.mutex.unlock()!!;
	}
	return 0;
}

<*
 Starts the background mesh worker if it is not already running.
*>
fn void start_mesh_worker() {
	if(g_mesh_queue.running) return;
	g_mesh_queue.mutex.init()!!;
	g_mesh_queue.cond.init()!!;
	g_mesh_queue.running = true;
	g_mesh_queue.stop_requested = false;
	g_mesh_queue.pending_count = 0;
	g_mesh_queue.completed_count = 0;
	g_mesh_queue.worker.create(&mesh_worker_main, &g_mesh_queue)!!;
}

<*
 Stops the background mesh worker and clears pending work.
*>
fn void shutdown_mesh_worker() {
	if(!g_mesh_queue.running) return;
	g_mesh_queue.mutex.lock()!!;
	g_mesh_queue.stop_requested = true;
	g_mesh_queue.cond.signal()!!;
	g_mesh_queue.mutex.unlock()!!;

	g_mesh_queue.worker.join()!!;
	g_mesh_queue.mutex.lock()!!;
	for(int i = 0; i < g_mesh_queue.pending_count; i++) {
		mem::free(g_mesh_queue.pending[i]);
	}
	g_mesh_queue.pending_count = 0;
	for(int i = 0; i < g_mesh_queue.completed_count; i++) {
		free_mesh_result(&g_mesh_queue.completed[i]);
	}
	g_mesh_queue.completed_count = 0;
	g_mesh_queue.mutex.unlock()!!;
	g_mesh_queue.cond.destroy()!!;
	g_mesh_queue.mutex.destroy()!!;
	g_mesh_queue.running = false;
}

fn bool enqueue_chunk_mesh(World *world, Chunk* chunk) {
	if(chunk == null) return false;
	if(!chunk.dirty) return false;
	if(chunk.mesh_queued || chunk.mesh_building) return false;

	MeshJob* job = mem::new(MeshJob);
	snapshot_chunk_job(job, world, chunk);

	g_mesh_queue.mutex.lock()!!;
	if(g_mesh_queue.pending_count >= MESH_JOB_CAP) {
		g_mesh_queue.mutex.unlock()!!;
		mem::free(job);
		return false;
	}
	g_mesh_queue.pending[g_mesh_queue.pending_count] = job;
	g_mesh_queue.pending_count += 1;
	chunk.mesh_queued = true;
	g_mesh_queue.cond.signal()!!;
	g_mesh_queue.mutex.unlock()!!;
	return true;
}

<*
 Enqueues a limited number of dirty, visible chunks for mesh generation.
*>
fn int queue_visible_chunk_meshes(World *world, Vec3f camera_pos, int budget) {
	if(budget <= 0) return 0;
	int queued = 0;
	for(int i = 0; i < world.chunks.len; i++) {
		if(queued >= budget) break;
		Chunk* chunk = world.chunks[i];
		if(chunk == null) continue;
		if(!chunk_in_render_range(chunk, camera_pos)) continue;
		if(enqueue_chunk_mesh(world, chunk)) queued += 1;
	}
	return queued;
}

<*
 Applies a limited number of completed mesh builds on the main thread.
*>
fn int apply_completed_meshes(int budget) {
	if(budget <= 0) return 0;
	int applied = 0;
	for(int i = 0; i < budget; i++) {
		g_mesh_queue.mutex.lock()!!;
		if(g_mesh_queue.completed_count == 0) {
			g_mesh_queue.mutex.unlock()!!;
			break;
		}
		g_mesh_queue.completed_count -= 1;
		MeshResult result = g_mesh_queue.completed[g_mesh_queue.completed_count];
		g_mesh_queue.mutex.unlock()!!;

		if(result.chunk == null || result.chunk.generation != result.generation) {
			if(result.chunk != null) result.chunk.mesh_building = false;
			free_mesh_result(&result);
			continue;
		}

		result.chunk.mesh_building = false;
		result.chunk.dirty = false;
		apply_mesh_result(&result);
		applied += 1;
	}
	return applied;
}

fn World generate_world() {
	World world = {};
	world.initialized = false;
	return world;
}

<*
 Frees all chunk CPU and GPU resources.
*>
fn void unload_chunk(World *world) {
	for(usz i = 0; i < world.chunks.len; i++) {
		Chunk* chunk = world.chunks[i];
		if(chunk == null) continue;
		chunk.mesh.destroy();
		mem::free(chunk);
		world.chunks[i] = null;
	}
}

<*
 Converts a world-space coordinate into a chunk coordinate.
*>
fn int chunk_coord_from_world(float pos) {
	float scaled = pos / (float)CHUNK_WIDTH;
	int coord = (int)scaled;
	if(pos < 0 && (float)coord * (float)CHUNK_WIDTH > pos) {
		coord -= 1;
	}
	return coord;
}

<*
 Maps a 3D world position to a 2D chunk coordinate (x/z plane).
*>
fn Vec2i world_pos_to_chunk(Vec3f pos) {
	return {
		chunk_coord_from_world(pos.x),
		chunk_coord_from_world(pos.z)
	};
}

<*
 Computes the chunk center in world space (x/z plane).
*>
fn Vec2f chunk_world_center(Vec2i chunk_pos) {
	float half = (float)CHUNK_WIDTH * 0.5f;
	return {
		(float)(chunk_pos.x * (int)CHUNK_WIDTH) + half,
		(float)(chunk_pos.y * (int)CHUNK_WIDTH) + half
	};
}

<*
 Returns true if a chunk is inside the render radius around the camera.
*>
fn bool chunk_in_render_range(Chunk* chunk, Vec3f camera_pos) {
	Vec2f center = chunk_world_center(chunk.pos);
	float dx = center.x - camera_pos.x;
	float dz = center.y - camera_pos.z;
	float radius = (float)((RENDER_RADIUS + 1) * (int)CHUNK_WIDTH);
	return (dx * dx + dz * dz) <= (radius * radius);
}

fn bool chunk_in_region(Vec2i pos, Vec2i origin) {
	int rel_x = pos.x - origin.x;
	int rel_y = pos.y - origin.y;
	return rel_x >= 0 && rel_x < (int)REGION_SIZE &&
		rel_y >= 0 && rel_y < (int)REGION_SIZE;
}

fn usz region_index(Vec2i pos, Vec2i origin) {
	int rel_x = pos.x - origin.x;
	int rel_y = pos.y - origin.y;
	return (usz)(rel_x * (int)REGION_SIZE + rel_y);
}

fn Chunk* take_recycled_chunk(Chunk*[REGION_SIZE * REGION_SIZE] recycled, int *count, Vec2i pos) {
	if(*count <= 0) return null;
	*count -= 1;
	Chunk* chunk = recycled[*count];
	generate_chunk_blocks(chunk, pos);
	chunk.dirty = true;
	return chunk;
}

fn void mark_chunk_dirty(Chunk* chunk) {
	if(chunk == null) return;
	chunk.dirty = true;
}

fn void mark_chunk_and_neighbors_dirty(World *world, Vec2i pos) {
	mark_chunk_dirty(find_chunk(world, pos));
	mark_chunk_dirty(find_chunk(world, {pos.x + 1, pos.y}));
	mark_chunk_dirty(find_chunk(world, {pos.x - 1, pos.y}));
	mark_chunk_dirty(find_chunk(world, {pos.x, pos.y + 1}));
	mark_chunk_dirty(find_chunk(world, {pos.x, pos.y - 1}));
}

fn void init_world_chunk_window(World *world, Vec2i origin) {
	for(int x = 0; x < (int)REGION_SIZE; x++) {
		for(int y = 0; y < (int)REGION_SIZE; y++) {
			Vec2i pos = {origin.x + x, origin.y + y};
			world.chunks[(usz)(x * (int)REGION_SIZE + y)] = generate_chunk(pos);
			mark_chunk_and_neighbors_dirty(world, pos);
		}
	}
}

<*
 Keeps a fixed-size window of chunks centered on the player. Reuses in-range chunks
 and recycles out-of-range ones to avoid allocations when shifting the region.
*>
fn void update_world(World *world, Vec3f player_pos) {
	Vec2i player_chunk = world_pos_to_chunk(player_pos);
	if(world.initialized && player_chunk == world.last_player_chunk) return;

	world.last_player_chunk = player_chunk;

	Vec2i new_origin = {
		player_chunk.x - REGION_RADIUS,
		player_chunk.y - REGION_RADIUS
	};

	if(!world.initialized) {
		init_world_chunk_window(world, new_origin);
		world.origin = new_origin;
		world.initialized = true;
		return;
	}

	Chunk*[REGION_SIZE * REGION_SIZE] new_chunks = {};
	Chunk*[REGION_SIZE * REGION_SIZE] recycled = {};
	int recycled_count = 0;

	for(usz i = 0; i < world.chunks.len; i++) {
		Chunk* chunk = world.chunks[i];
		if(chunk == null) continue;
		if(chunk_in_region(chunk.pos, new_origin)) {
			new_chunks[region_index(chunk.pos, new_origin)] = chunk;
			continue;
		}
		recycled[recycled_count] = chunk;
		recycled_count++;
	}

	for(int x = 0; x < (int)REGION_SIZE; x++) {
		for(int y = 0; y < (int)REGION_SIZE; y++) {
			usz idx = (usz)(x * (int)REGION_SIZE + y);
			if(new_chunks[idx] != null) continue;

			Vec2i target = {new_origin.x + x, new_origin.y + y};
			Chunk* chunk = take_recycled_chunk(recycled, &recycled_count, target);
			if(chunk == null) chunk = generate_chunk(target);

			new_chunks[idx] = chunk;
			mark_chunk_and_neighbors_dirty(world, target);
		}
	}

	world.chunks = new_chunks;
	world.origin = new_origin;
	world.initialized = true;
}
