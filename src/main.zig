const std = @import("std");
const Io = std.Io;
const Dir = std.Io.Dir;

const zig_http_server = @import("zig_http_server");

// Doing https://www.boot.dev/courses/learn-http-protocol-golang but in zig
pub fn main(init: std.process.Init) !void {
    // This is appropriate for anything that lives as long as the process.
    // const arena: std.mem.Allocator = init.arena.allocator();
    const io = init.io;

    // Stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    // var stdout_buffer: [1024]u8 = undefined;
    // var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    // const stdout_writer = &stdout_file_writer.interface;
    // try stdout_writer.print("I hope I get the job!\n", .{});
    // try stdout_writer.flush(); // Don't forget to flush!

    const current_dir = Dir.cwd();
    const file = try std.Io.Dir.openFile(current_dir, io, "messages.txt", .{});
    defer file.close(io);

    var file_read_buffer: [1024]u8 = undefined;
    var f_reader = file.reader(io, &file_read_buffer);

    const alloc = init.gpa;
    while (try nextLine(&f_reader.interface, alloc)) |line| {
        defer alloc.free(line);
        std.debug.print("read: {s}\n", .{line});
    }
}

fn nextLine(reader: *Io.Reader, alloc: std.mem.Allocator) !?[]u8 {
    var bytes: std.Io.Writer.Allocating = .init(alloc);
    errdefer bytes.deinit();
    const read_result = reader.streamDelimiter(&bytes.writer, '\n');
    if (read_result == error.EndOfStream) {
        return null;
    }
    _ = try reader.takeByte();
    const line = try bytes.toOwnedSlice();
    return line;
}
