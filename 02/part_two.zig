const std = @import("std");

// Zig you nasty pita I want my argv from C...
pub fn getInputFromArgs(args: [][:0]u8) []u8 {
    var file:[]u8 = undefined;
    var next:bool = false;
    file = args[0][0..];
    file[0] = 0x00;

    for(args) |arg| {
        if (next) {
            file = arg[0..];
            break;
        }

        if (std.mem.eql(u8, arg, "--data")) {
            next = true;
        }
    }
    std.log.debug("{s}\n", .{file});

    return file;
}

const MAX_RED = 12;
const MAX_GREEN = 13;
const MAX_BLUE = 14;

pub fn main() !void {

    // Get allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    // Parse args into string array (error union needs 'try')
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const data: []u8 = getInputFromArgs(args);

    if (data[0] == 0x00) {
        std.log.warn("Failed to find file, use --data <filename>\n", .{});
        return;
    }

    var file = try std.fs.cwd().openFile(data, .{});
    defer file.close();
    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();
    var buf: [1024]u8 = undefined;

    var total:u64 = 0;

    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        // var line = try allocLowerString(std.mem.Allocator, tmp) // assume it's all lower case
        var it = std.mem.tokenizeSequence(u8, line, ":");
        var tmp:[]const u8 = it.next() orelse continue;
        tmp = tmp[5..];//skip 'game ' - get just the ID
        const game_id = try std.fmt.parseUnsigned(u8, tmp, 10);

        tmp = it.next() orelse continue; // the rest of the line
        it = std.mem.tokenizeSequence(u8, tmp, ";");
        std.log.debug("Line: {s}\n", .{line});

        var local_max_red:u32 = 0;
        var local_max_blue:u32 = 0;
        var local_max_green:u32 = 0;

        while(it.next()) |game| {
            var eit = std.mem.tokenizeSequence(u8, game, ",");
            std.log.debug("\tGame ({d}); {s}\n", .{game_id, game});
            while(eit.next()) |die| {

                var dit = std.mem.tokenizeSequence(u8, die, " ");
                const tcount:[]const u8 = dit.next() orelse continue;
                const count = try std.fmt.parseUnsigned(u8, tcount, 10);
                const color:[]const u8 = dit.next() orelse continue;

                if (std.mem.count(u8, color, "red") > 0 and local_max_red < count) {
                    local_max_red = count;
                }

                if (std.mem.count(u8, color, "blue") > 0 and local_max_blue < count) {
                    local_max_blue = count;
                }

                if (std.mem.count(u8, color, "green") > 0 and local_max_green < count) {
                    local_max_green = count;
                }

                std.log.debug("\t\tPart: {d} {s}\n", .{count, color});
            }

            std.log.debug("\tMAX: {d} {d} {d}\n", .{local_max_red, local_max_blue, local_max_green});
        }

        total = total + (local_max_red * local_max_blue * local_max_green);

        std.log.debug("_______________________\n", .{});
        std.log.debug("Result |{d} {d}|\n", .{game_id, total});
    }

    const stdout = std.io.getStdOut().writer();
    try stdout.print("Total: {d}\n", .{total});
}