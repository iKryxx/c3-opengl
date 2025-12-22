module game::world;
import engine::math;
import engine::gfx;
import engine::core;
import std::io;


const uint CHUNK_WIDTH = 16;
const uint CHUNK_HEIGHT = 256;
const uint CHUNK_VOLUME = CHUNK_WIDTH
	* CHUNK_WIDTH
	* CHUNK_HEIGHT;


const uint REGION_SIZE = 6;
const int REGION_RADIUS = (int)(REGION_SIZE / 2);
const int RENDER_RADIUS = REGION_RADIUS;

enum BlockType: const int {
	AIR = -1,
	GRASS,
	DIRT
}

struct Block {
	BlockType type;
}

struct Chunk {
	Block[CHUNK_VOLUME] blocks;
	Mesh mesh;
	bool dirty;
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
	}
};

macro int coords_to_arr(p) => ((p.z * CHUNK_WIDTH * CHUNK_HEIGHT) + (p.y * CHUNK_WIDTH) + p.x);

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
	int surface = CHUNK_HEIGHT - 20 + (chunk_pos.x + chunk_pos.y) * 0;
	if(local_pos.y < surface) return DIRT;
	if(local_pos.y == surface) return GRASS;
	return AIR;
}

<*
 Fills the chunk with blocks for the given world chunk position.
*>
fn void generate_chunk_blocks(Chunk* chunk, Vec2i pos) {
	chunk.pos = pos;
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
 Returns the block type for a neighbor, including across chunk boundaries.
*>
fn BlockType neighbor_block(World *world, Chunk* chunk, Vec3i local_pos, int dir) {
	Vec3i n_local = local_pos;
	Vec2i n_chunk_pos = chunk.pos;

	switch(dir) {
		case 0: { // +Z
			if(local_pos.z < (int)CHUNK_WIDTH - 1) {
				n_local.z += 1;
				return chunk.blocks[coords_to_arr(n_local)].type;
			}
			n_chunk_pos.y += 1;
			n_local.z = 0;
			break;
		}
		case 1: { // -Z
			if(local_pos.z > 0) {
				n_local.z -= 1;
				return chunk.blocks[coords_to_arr(n_local)].type;
			}
			n_chunk_pos.y -= 1;
			n_local.z = (int)CHUNK_WIDTH - 1;
			break;
		}
		case 2: { // -X
			if(local_pos.x > 0) {
				n_local.x -= 1;
				return chunk.blocks[coords_to_arr(n_local)].type;
			}
			n_chunk_pos.x -= 1;
			n_local.x = (int)CHUNK_WIDTH - 1;
			break;
		}
		case 3: { // +X
			if(local_pos.x < (int)CHUNK_WIDTH - 1) {
				n_local.x += 1;
				return chunk.blocks[coords_to_arr(n_local)].type;
			}
			n_chunk_pos.x += 1;
			n_local.x = 0;
			break;
		}
		case 4: { // +Y
			if(local_pos.y < (int)CHUNK_HEIGHT - 1) {
				n_local.y += 1;
				return chunk.blocks[coords_to_arr(n_local)].type;
			}
			return AIR;
		}
		case 5: { // -Y
			if(local_pos.y > 0) {
				n_local.y -= 1;
				return chunk.blocks[coords_to_arr(n_local)].type;
			}
			return AIR;
		}
		default: core::error("Unreachable Code reached inside neighbor_block");
	}

	Chunk* neighbor_chunk = find_chunk(world, n_chunk_pos);
	if(neighbor_chunk == null) return AIR;
	return neighbor_chunk.blocks[coords_to_arr(n_local)].type;
}

fn void Chunk.generate_chunk_mesh(&self, World *world) {
	Listf chunk_vertices;
	Listui chunk_indices;

	chunk_vertices.tinit();
	chunk_indices.tinit();

	for(int i = 0; i < self.blocks.len; i++) {
		Block block = self.blocks[i];
		Vec3i pos = arr_to_coords(i);
		if(block.type == AIR) continue;

		for (int d = 0; d < 6; d++) {
			BlockType neighbor = neighbor_block(world, self, pos, d);

			// Only draw exposed faces.
			if(neighbor != AIR) {
				continue;
			}

			// Copy face template so we do not mutate the shared const vertex data.
			float[gfx::CUBE_FLOAT_STRIDE * 4] new_slice = gfx::get_cube_face_vert(d);
			uint[6] new_slice_idx = gfx::get_cube_face_idx(d);
			usz base_vert = chunk_vertices.len() / gfx::CUBE_FLOAT_STRIDE;
			uint face_vertex_base = (uint)(d * 4);

			// offset vertex and set texture
			for(int p = 0; p < 4; p++) {
				new_slice[p * gfx::CUBE_FLOAT_STRIDE + 0] += (float)(pos.x + self.pos.x * CHUNK_WIDTH);
				new_slice[p * gfx::CUBE_FLOAT_STRIDE + 1] += (float)pos.y;
				new_slice[p * gfx::CUBE_FLOAT_STRIDE + 2] += (float)(pos.z + self.pos.y * CHUNK_WIDTH);

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

	float[] verts_arr = chunk_vertices.to_tarray();
	uint[] idx_arr = chunk_indices.to_tarray();

	self.mesh.make(verts_arr, idx_arr, gfx::CUBE_FLOAT_STRIDE);

	chunk_indices.free();
	chunk_vertices.free();
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

fn void init_world_chunk_window(World *world, Vec2i origin) {
	for(int x = 0; x < (int)REGION_SIZE; x++) {
		for(int y = 0; y < (int)REGION_SIZE; y++) {
			Vec2i pos = {origin.x + x, origin.y + y};
			world.chunks[(usz)(x * (int)REGION_SIZE + y)] = generate_chunk(pos);
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
		}
	}

	world.chunks = new_chunks;
	world.origin = new_origin;
	world.initialized = true;
}
