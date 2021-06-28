const std = @import("std");
const Rng = std.rand.DefaultPrng;

const level = @import("level.zig");
const Level = level.Level;
const LevelList = std.ArrayList(Level);

fn initRng() !Rng {
    const seed = std.crypto.random.int(u64);
    return Rng.init(seed);
}

pub const Command = union(enum) {
    quit,
    move: [2]i8,
    up,
    down,
};

pub const World = struct {
    rng: Rng,

    levels: LevelList,
    cur_idx: usize,
    player: [2]usize,

    pub fn init(alloc: *std.mem.Allocator) !World {
        var rng = try initRng();

        var levels = LevelList.init(alloc);
        const first_level = Level.new(&rng.random);
        try levels.append(first_level);

        return World{
            .rng = rng,
            .levels = levels,
            .cur_idx = 0,
            .player = first_level.upstair,
        };
    }

    pub fn deinit(self: World) void {
        self.levels.deinit();
    }

    pub fn curLevel(self: *const World) *const Level {
        return &self.levels.items[self.cur_idx];
    }

    pub fn getPlayer(self: *const World) [2]usize {
        return self.player;
    }

    pub fn handleCommand(self: *World, cmd: Command) !bool {
        switch (cmd) {
            .quit => return false,

            .move => |deltas| {
                const new_x = @intCast(isize, self.player[0]) + @intCast(isize, deltas[0]);
                const new_y = @intCast(isize, self.player[1]) + @intCast(isize, deltas[1]);
                const new = [_]usize{ @intCast(usize, new_x), @intCast(usize, new_y) };
                if (self.curLevel().get(new).? != .wall) {
                    self.player = new;
                }
                return true;
            },

            .up => {
                if (self.curLevel().get(self.player).? != .upstair) {
                    return true;
                }
                if (self.cur_idx == 0) {
                    return false; // escaped
                }
                self.cur_idx -= 1;
                self.player = self.curLevel().downstair;
                return true;
            },

            .down => {
                if (self.curLevel().get(self.player).? != .downstair) {
                    return true;
                }
                self.cur_idx += 1;
                while (self.cur_idx >= self.levels.items.len) {
                    try self.levels.append(Level.new(&self.rng.random));
                }
                self.player = self.curLevel().upstair;
                return true;
            },
        }
    }
};
