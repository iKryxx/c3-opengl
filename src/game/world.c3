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

fn Vec3i arr_to_coords(int i) {
	int z = i / (CHUNK_WIDTH * CHUNK_HEIGHT);
	i -= (z * CHUNK_WIDTH * CHUNK_HEIGHT);
	int y = i / CHUNK_WIDTH;
	int x = i % CHUNK_WIDTH;
	return {x, y, z};

}

fn void generate_chunk_blocks(Chunk* chunk, Vec2i pos) {
	chunk.pos = pos;
	for(int x = 0; x < CHUNK_WIDTH; x++) {
		for(int y = 0; y < CHUNK_HEIGHT; y++) {
			for(int z = 0; z < CHUNK_WIDTH; z++) {
				BlockType 			    b = AIR;
				if(y < CHUNK_HEIGHT - 20) 	  { b = DIRT; }
				else if (y <  CHUNK_HEIGHT - 19)  { b = GRASS; }

				int idx = coords_to_arr((Vec3i){x, y, z});
				chunk.blocks[idx] = { b };
			}
		}
	}
}

fn Chunk* generate_chunk(Vec2i pos) {
	// Zero-init mesh so GL handles start at 0; uninitialised handles cause UB in Mesh.make.
	Chunk* chunk = mem::new(Chunk, { .mesh = {}, .dirty = true });
	generate_chunk_blocks(chunk, pos);
	return chunk;
}

fn void Chunk.generate_chunk_mesh(&self) {
	Listf chunk_vertices;
	Listui chunk_indices;

	chunk_vertices.tinit();
	chunk_indices.tinit();

	for(int i = 0; i < self.blocks.len; i++) {
		Block block = self.blocks[i];
		Vec3i pos = arr_to_coords(i);
		if(block.type == AIR) continue;

		for (int d = 0; d < 6; d++) {
			Block neighbor = {.type = AIR};
			int n_idx = -1;
			switch(d) {
				case 0: { // +Z
					if(pos.z == CHUNK_WIDTH - 1) break;
					n_idx = coords_to_arr(pos + (Vec3i){0, 0, 1});
					break;
				}
				case 1: { // -Z
					if(pos.z == 0) break;
					n_idx = coords_to_arr(pos + (Vec3i){0, 0, -1});
					break;
				}
				case 2: { // -X
					if(pos.x == 0) break;
					n_idx = coords_to_arr(pos + (Vec3i){-1, 0, 0});
					break;
				}
				case 3: { // +X
					if(pos.x == CHUNK_WIDTH - 1) break;
					n_idx = coords_to_arr(pos + (Vec3i){1, 0, 0});
					break;
				}
				case 4: { // +Y
					if(pos.y == CHUNK_HEIGHT - 1) break;
					n_idx = coords_to_arr(pos + (Vec3i){0, 1, 0});
					break;
				}
				case 5: { // -Y
					if(pos.y == 0) break;
					n_idx = coords_to_arr(pos + (Vec3i){0, -1, 0});
					break;
				}
				default: core::error("Unreachable Code reached inside generate_chunk_mesh(self)");
			}

			if(n_idx >= 0) {
				neighbor = self.blocks[n_idx];
			}

			// Only draw exposed faces.
			if(neighbor.type != AIR) {
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

fn void unload_chunk(World *world) {
	for(usz i = 0; i < world.chunks.len; i++) {
		Chunk* chunk = world.chunks[i];
		if(chunk == null) continue;
		chunk.mesh.destroy();
		mem::free(chunk);
		world.chunks[i] = null;
	}
}

fn int chunk_coord_from_world(float pos) {
	float scaled = pos / (float)CHUNK_WIDTH;
	int coord = (int)scaled;
	if(pos < 0 && (float)coord * (float)CHUNK_WIDTH > pos) {
		coord -= 1;
	}
	return coord;
}

fn Vec2i world_pos_to_chunk(Vec3f pos) {
	return {
		chunk_coord_from_world(pos.x),
		chunk_coord_from_world(pos.z)
	};
}

<*
 Keeps a fixed-size window of chunks centered on the player. Reuses in-range chunks
 and recycles out-of-range ones to avoid allocations when shifting the region.
*>
fn void update_world(World *world, Vec3f player_pos) {
	Vec2i player_chunk = world_pos_to_chunk(player_pos);
	if(world.initialized && player_chunk == world.last_player_chunk) {
		return;
	}

	world.last_player_chunk = player_chunk;

	Vec2i new_origin = {
		player_chunk.x - REGION_RADIUS,
		player_chunk.y - REGION_RADIUS
	};

	Chunk*[REGION_SIZE * REGION_SIZE] new_chunks = {};
	Chunk*[REGION_SIZE * REGION_SIZE] recycled = {};
	int recycled_count = 0;

	for(usz i = 0; i < world.chunks.len; i++) {
		Chunk* chunk = world.chunks[i];
		if(chunk == null) continue;

		int rel_x = chunk.pos.x - new_origin.x;
		int rel_y = chunk.pos.y - new_origin.y;
		if(rel_x >= 0 && rel_x < (int)REGION_SIZE &&
		   rel_y >= 0 && rel_y < (int)REGION_SIZE) {
			usz idx = (usz)(rel_x * (int)REGION_SIZE + rel_y);
			new_chunks[idx] = chunk;
		} else {
			recycled[recycled_count] = chunk;
			recycled_count++;
		}
	}

	for(int x = 0; x < (int)REGION_SIZE; x++) {
		for(int y = 0; y < (int)REGION_SIZE; y++) {
			usz idx = (usz)(x * (int)REGION_SIZE + y);
			if(new_chunks[idx] != null) continue;

			Vec2i target = {new_origin.x + x, new_origin.y + y};
			Chunk* chunk = null;
			if(recycled_count > 0) {
				recycled_count--;
				chunk = recycled[recycled_count];
				generate_chunk_blocks(chunk, target);
				chunk.dirty = true;
			} else {
				chunk = generate_chunk(target);
			}

			new_chunks[idx] = chunk;
		}
	}

	world.chunks = new_chunks;
	world.origin = new_origin;
	world.initialized = true;
}
