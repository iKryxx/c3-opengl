module game::world;
import engine::math;
import engine::gfx;
import engine::core;
import std::io;


const uint CHUNK_WIDTH = 16;
const uint CHUNK_HEIGHT = 16;
const uint CHUNK_VOLUME = CHUNK_WIDTH
			  * CHUNK_WIDTH
			  * CHUNK_HEIGHT;


const uint REGION_SIZE = 12;

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
}

struct World {
    Chunk*[REGION_SIZE * REGION_SIZE] chunks;
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


fn Chunk* generate_chunk(Vec2i pos) {
    // Zero-init mesh so GL handles start at 0; uninitialised handles cause UB in Mesh.make.
    Chunk* chunk = mem::new(Chunk, { .mesh = {}, .dirty = true });

    for(int x = 0; x < CHUNK_WIDTH; x++) {
	for(int y = 0; y < CHUNK_HEIGHT; y++) {
	    for(int z = 0; z < CHUNK_WIDTH; z++) {
		int idx = coords_to_arr((Vec3i){x, y, z});
		
		if (y == CHUNK_HEIGHT - 1){
		    chunk.blocks[idx] =
		    {GRASS};

		} else {
		    chunk.blocks[idx] =
		    {DIRT};
		}
	    }
	}
    }

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
		new_slice[p * gfx::CUBE_FLOAT_STRIDE + 0] += (float)pos.x;
		new_slice[p * gfx::CUBE_FLOAT_STRIDE + 1] += (float)pos.y;
		new_slice[p * gfx::CUBE_FLOAT_STRIDE + 2] += (float)pos.z;

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
    Chunk *curr = generate_chunk({0, 0});
    
    world.chunks[0] = curr;
    return world;
}

fn void unload_chunk(World *world) {
    mem::free(world.chunks[0]);
    world.chunks[0] = null;
}
