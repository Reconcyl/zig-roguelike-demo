const std = @import("std");
const File = std.fs.File;

const world_mod = @import("world.zig");
const World = world_mod.World;
const Command = world_mod.Command;

const render = @import("render.zig");

fn getChar(stdin: File) !?u8 {
    var buffer: [1]u8 = undefined;
    const bytes = try stdin.read(&buffer);
    return if (bytes == 1) buffer[0] else null;
}

fn parseCmd(char: u8) ?Command {
    return switch (char) {
        'y' => .{ .move = [_]i8{ -1, -1 } },
        'u' => .{ .move = [_]i8{ 1, -1 } },
        'h' => .{ .move = [_]i8{ -1, 0 } },
        'j' => .{ .move = [_]i8{ 0, 1 } },
        'k' => .{ .move = [_]i8{ 0, -1 } },
        'l' => .{ .move = [_]i8{ 1, 0 } },
        'b' => .{ .move = [_]i8{ -1, 1 } },
        'n' => .{ .move = [_]i8{ 1, 1 } },
        '<' => .up,
        '>' => .down,
        'q', 0x3, 0x4 => .quit, // q, ^C, ^D
        else => null,
    };
}

fn getCmd(stdin: File) !?Command {
    while (true) {
        const char = (try getChar(stdin)) orelse return null;
        return (parseCmd(char) orelse continue);
    }
}

pub fn main() !void {
    try render.set_raw_term();
    defer render.restore_term();

    const stdin = std.io.getStdIn();

    const stdout = std.io.getStdOut().writer();

    render.altScreen(stdout);
    errdefer render.mainScreen(stdout);
    render.goTo(stdout, 0, 0);
    render.clear(stdout);

    var world = try World.init();
    var screen = render.Screen.init();

    while (true) {
        screen.redraw(world.curLevel(), world.player, stdout);
        var cmd = (try getCmd(stdin)) orelse break;

        if (!try world.handleCommand(cmd)) break;
    }

    render.mainScreen(stdout);
    stdout.writeAll("You left the dungeon.\r\n") catch {};
}
