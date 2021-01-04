const std = @import("std");
const Writer = std.fs.File.Writer;
const Alloc = std.heap.ArenaAllocator;

const c = @cImport(@cInclude("termios.h"));
const stdin_fd: u8 = 0;

const level_mod = @import("level.zig");
const Level = level_mod.Level;
const posEq = level_mod.posEq;

const RenderError = error{
    NoSettings,
    NoRaw,
};

var old_term_settings: c.struct_termios = undefined;

pub fn set_raw_term() !void {
    if (c.tcgetattr(stdin_fd, &old_term_settings) < 0) {
        return error.NoSettings;
    }

    var raw = old_term_settings;
    c.cfmakeraw(&raw);

    if (c.tcsetattr(stdin_fd, c.TCSANOW, &raw) < 0) {
        return error.NoRaw;
    }
}

pub fn restore_term() void {
    _ = c.tcsetattr(stdin_fd, c.TCSANOW, &old_term_settings);
}

const csi = "\x1b[";

pub fn altScreen(out: Writer) void {
    out.writeAll(csi ++ "?1049h") catch {};
}

pub fn mainScreen(out: Writer) void {
    out.writeAll(csi ++ "?1049l") catch {};
}

pub fn goTo(out: Writer, x: usize, y: usize) void {
    out.print(csi ++ "{};{}H", .{ y + 1, x + 1 }) catch {};
}

pub fn clear(out: Writer) void {
    out.writeAll(csi ++ "J") catch {};
}

pub const Screen = struct {
    chars: ?[Level.height][Level.width]u8,
    cursor: [2]usize,

    pub fn init() Screen {
        return .{
            .chars = null,
            .cursor = [_]usize{ 0, 0 },
        };
    }

    fn nearWall(level: *const Level, pos: [2]usize, dx: i8, dy: i8) bool {
        const real_x = @intCast(isize, pos[0]) + @intCast(isize, dx);
        const real_y = @intCast(isize, pos[1]) + @intCast(isize, dy);

        if (real_x < 0 or real_y < 0) {
            return false;
        } else {
            const real_pos = [_]usize{
                @intCast(usize, real_x),
                @intCast(usize, real_y),
            };
            if (level.get(real_pos)) |tile| {
                return tile == .wall;
            } else {
                return false;
            }
        }
    }

    fn calcChar(level: *const Level, player: [2]usize, pos: [2]usize) u8 {
        if (posEq(player, pos)) {
            return '@';
        } else {
            const tile = level.get(pos).?;
            switch (tile) {
                .upstair => return '<',
                .downstair => return '>',
                .blank => return ' ',

                .wall => {
                    const wall_w = nearWall(level, pos, -1, 0);
                    const wall_e = nearWall(level, pos, 1, 0);
                    const wall_n = nearWall(level, pos, 0, -1);
                    const wall_s = nearWall(level, pos, 0, 1);

                    const hori = wall_w or wall_e;
                    const vert = wall_n or wall_s;

                    if (vert and !hori) {
                        return '|';
                    } else {
                        return '-';
                    }
                },
            }
        }
    }

    pub fn redraw(self: *Screen, level: *const Level, player: [2]usize, out: Writer) void {
        const first_time_drawing = self.chars == null;
        if (first_time_drawing) {
            var chars: [Level.height][Level.width]u8 = undefined;
            for (chars) |*row| {
                for (row) |*char| {
                    char.* = 0;
                }
            }
            self.chars = chars;
        }

        var cur_x = self.cursor[0];
        var cur_y = self.cursor[1];

        var y: usize = 0;
        while (y < Level.height) : (y += 1) {
            var dirty_line = false;

            // replace each character in this row with the new one
            var x: usize = 0;
            while (x < Level.width) : (x += 1) {
                const pos = [_]usize{ x, y };
                const new_char = calcChar(level, player, pos);
                const old_char = self.chars.?[y][x];
                if (new_char != old_char) {
                    dirty_line = true;
                }
                self.chars.?[y][x] = new_char;
            }

            // if there were any differences in this row, redraw it
            if (dirty_line) {
                if (cur_y + 1 == y) {
                    out.writeAll("\r\n") catch {};
                } else {
                    goTo(out, 0, y);
                }
                out.writeAll(&self.chars.?[y]) catch {};
                cur_x = Level.width;
                cur_y = y;
            }
        }

        goTo(out, player[0], player[1]);
        self.cursor = player;
    }
};
