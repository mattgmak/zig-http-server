const std = @import("std");
const Io = std.Io;

const zig_http_server = @import("zig_http_server");

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

    const destination_ip: Io.net.IpAddress = try .parseIp4("127.0.0.1", 42069);
    const bind_ip: Io.net.IpAddress = try .parseIp4("127.0.0.1", 0);
    const socket = try bind_ip.bind(io, .{
        .mode = .dgram,
        .protocol = .udp,
    });
    defer socket.close(io);

    var stdin_buffer: [1024]u8 = undefined;
    var stdin_file_reader: Io.File.Reader = .init(.stdin(), io, &stdin_buffer);
    const stdin_reader = &stdin_file_reader.interface;

    while (true) {
        try stdout_writer.print(">", .{});
        try stdout_writer.flush();
        if (try nextLine(stdin_reader, init.gpa)) |line| {
            try socket.send(io, &destination_ip, line);
            init.gpa.free(line);
        } else break;
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
