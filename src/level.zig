const std = @import("std");
const rand = std.rand;

pub fn posEq(a: [2]usize, b: [2]usize) bool {
    return a[0] == b[0] and a[1] == b[1];
}

pub const Tile = enum {
    upstair,
    downstair,
    wall,
    blank,
};

pub const Level = struct {
    pub const width: usize = 30;
    pub const height: usize = 15;

    fn genPos(rng: *rand.Random) [2]usize {
        const x = rng.uintLessThan(usize, width - 2);
        const y = rng.uintLessThan(usize, height - 2);
        return [_]usize{ x + 1, y + 1 };
    }

    upstair: [2]usize,
    downstair: [2]usize,
    tiles: [height][width]Tile,

    pub fn get(self: *const Level, pos: [2]usize) ?Tile {
        const x = pos[0];
        const y = pos[1];
        if (x < width and y < height) {
            return self.tiles[y][x];
        } else {
            return null;
        }
    }

    pub fn new(rng: *rand.Random) Level {
        const upstair = genPos(rng);
        var downstair: [2]usize = undefined;
        while (true) {
            downstair = genPos(rng);
            if (!posEq(upstair, downstair)) {
                break;
            }
        }

        var tiles: [height][width]Tile = undefined;
        var y: usize = 0;
        while (y < height) : (y += 1) {
            var x: usize = 0;
            while (x < width) : (x += 1) {
                const pos = [_]usize{ x, y };
                if (x == 0 or y == 0 or x + 1 == width or y + 1 == height) {
                    tiles[y][x] = .wall;
                } else if (posEq(pos, upstair)) {
                    tiles[y][x] = .upstair;
                } else if (posEq(pos, downstair)) {
                    tiles[y][x] = .downstair;
                } else if (rng.uintLessThan(u8, 5) == 0) {
                    tiles[y][x] = .wall;
                } else {
                    tiles[y][x] = .blank;
                }
            }
        }

        return .{
            .upstair = upstair,
            .downstair = downstair,
            .tiles = tiles,
        };
    }
};
