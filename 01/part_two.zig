const std = @import("std");

// override defaults?
// pub const std_options = struct {
//     // Set this to .info, .debug, .warn, or .err.
//     pub const log_level = .info;
// };

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

pub fn checkLine(line: []u8, hm: anytype) u8 {
    var num:u8 = 0xFF;
    var idx:u16 = 0;

    for (line) |character| {
        if (num == 0xFF) {
            if (std.ascii.isDigit(character)) {
                num = character;
                break;
            }


            var it = hm.iterator();
            while (it.next()) |entry| {
                const e = entry.key_ptr.*;

                if (e.len > line.len - idx - 1) {
                    continue;
                }

                std.log.debug("{s} {d} > {d} {s}\n", .{e, e.len, line.len - idx - 1, line[idx..idx+e.len]});
                
                if (std.ascii.eqlIgnoreCase(e, line[idx..idx+e.len])) {
                    num = entry.value_ptr.*;
                    std.log.debug("--------- {s} {d}\n", .{entry.key_ptr.*, num});
                    break;
                }
            }
        } else {
            break;
        }
        idx += 1;
    }

    return num;
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

    var WHYAOCWHY = std.StringHashMap(u8).init(allocator);
    var WHYAOCWHYR = std.StringHashMap(u8).init(allocator);
    defer WHYAOCWHY.deinit();
    defer WHYAOCWHYR.deinit();
    // left
    try WHYAOCWHY.put("zero", '0');
    try WHYAOCWHY.put("one", '1');
    try WHYAOCWHY.put("two", '2');
    try WHYAOCWHY.put("three", '3');
    try WHYAOCWHY.put("four", '4');
    try WHYAOCWHY.put("five", '5');
    try WHYAOCWHY.put("six", '6');
    try WHYAOCWHY.put("seven", '7');
    try WHYAOCWHY.put("eight", '8');
    try WHYAOCWHY.put("nine", '9');

    // left or right reverse
    try WHYAOCWHYR.put("orez", '0');
    try WHYAOCWHYR.put("eno", '1');
    try WHYAOCWHYR.put("owt", '2');
    try WHYAOCWHYR.put("eerht", '3');
    try WHYAOCWHYR.put("ruof", '4');
    try WHYAOCWHYR.put("evif", '5');
    try WHYAOCWHYR.put("xis", '6');
    try WHYAOCWHYR.put("neves", '7');
    try WHYAOCWHYR.put("thgie", '8');
    try WHYAOCWHYR.put("enin", '9');


    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        // var line = try allocLowerString(std.mem.Allocator, tmp) // assume it's all lower case
        std.log.debug("{s}\n", .{line});

        var num = [_]u8 { 0xFF, 0xFF };

        num[0] = checkLine(line, &WHYAOCWHY);
        std.mem.reverse(u8, line);
        num[1] = checkLine(line, &WHYAOCWHYR);
        std.log.debug("({s}) L: {d} R: {d}  LEN: {d}\n", .{line, num[0], num[1], num.len});

        const line_total = try std.fmt.parseUnsigned(u8, &num, 10);
        total += line_total;

        std.log.debug(">>>>\n\tL: {c}\n\tR: {c} {d}\n", .{num[0], num[1], line_total});
    }

    const stdout = std.io.getStdOut().writer();
    try stdout.print("Total: {d}\n", .{total});
}