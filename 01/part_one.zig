const std = @import("std");

pub const std_options = struct {
    // Set this to .info, .debug, .warn, or .err.
    pub const log_level = .info;
};

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
    var total: u64 = 0;

    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        std.log.debug("{s}\n", .{line});

        var num = [_]u8 {0xA, 0xA };

        for (line) |character| {
            if (num[0] == 0xA) {
                if (std.ascii.isDigit(character)) {
                    num[0] = character;
                }
            } else {
                break;
            }
        }

        // `i = i -% 1` is wrapping subtraction - reverse line and find the right 'left'
        var i: u64 = line.len - 1;
        var character: u8 = 0xAA;
        while (i < line.len) : (i -%= 1) {
            character = line[i];

            if (num[1] == 0xA) {
                if (std.ascii.isDigit(character)) {
                    num[1] = character;
                }
            }
        }
        const line_total = try std.fmt.parseInt(u8, &num, 10);
        total += line_total;

        std.log.debug(">>>>\n\tL: {c}\n\tR: {c} {d}\n", .{num[0], num[1], line_total});
    }

    const stdout = std.io.getStdOut().writer();
    try stdout.print("Total: {d}\n", .{total});
}