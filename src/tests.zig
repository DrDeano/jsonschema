const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectError = std.testing.expectError;
const jsonschema = @import("jsonschema.zig");

test "basic" {
    var schema_parser = std.json.Parser.init(std.testing.allocator, false);
    defer schema_parser.deinit();

    var schema_tree = try schema_parser.parse("{}");
    defer schema_tree.deinit();

    var data_parser = std.json.Parser.init(std.testing.allocator, false);
    defer data_parser.deinit();

    var data_tree = try data_parser.parse("{}");
    defer data_tree.deinit();

    const t_schema = jsonschema.Schema{ .Bool = true };
    const f_schema = jsonschema.Schema{ .Bool = false };

    try expectError(jsonschema.Schema.CompileError.TODOTopLevel, jsonschema.validate(std.testing.allocator, schema_tree.root, data_tree.root));
    try expectError(jsonschema.Schema.CompileError.TODOTopLevel, jsonschema.Schema.compile(std.testing.allocator, schema_tree.root));
    try expect(!try jsonschema.Schema.validate(f_schema, data_tree.root));
    try expect(try jsonschema.Schema.validate(t_schema, data_tree.root));
}

test "c API" {
    const zjs_type = opaque {};
    const zjs_compile = @extern(*const fn (schema: ?[*:0]const u8) ?*zjs_type, .{ .name = "zjs_compile", .linkage = .Strong });
    const zjs_validate = @extern(*const fn (zjs: ?*zjs_type, data: ?[*:0]const u8) bool, .{ .name = "zjs_validate", .linkage = .Strong });
    const zjs_compile_and_validate = @extern(*const fn (schema: ?[*:0]const u8, data: ?[*:0]const u8) bool, .{ .name = "zjs_compile_and_validate", .linkage = .Strong });
    const zjs_deinit = @extern(*const fn (zjs: ?*zjs_type) void, .{ .name = "zjs_deinit", .linkage = .Strong });

    try expectEqual(zjs_compile(null), null);
    try expectEqual(zjs_compile("{}"), null);
    try expectEqual(zjs_compile("8tyol8fcu"), null);

    try expect(!zjs_validate(null, null));
    try expect(!zjs_validate(null, "{}"));

    try expect(!zjs_compile_and_validate(null, null));
    try expect(!zjs_compile_and_validate(null, "{}"));
    try expect(!zjs_compile_and_validate("{}", null));
    try expect(!zjs_compile_and_validate("{}", "{}"));

    zjs_deinit(null);
}

test "JSON Schema Test Suite" {
    const test_files_dir = "JSON-Schema-Test-Suite/tests/draft7/";
    const test_files = .{
        test_files_dir ++ "boolean_schema.json",
    };

    inline for (test_files) |test_file| {
        var test_parser = std.json.Parser.init(std.testing.allocator, false);
        defer test_parser.deinit();

        const type_tests = try std.fs.cwd().openFile(test_file, .{});
        defer type_tests.close();

        const test_data_file = try type_tests.readToEndAlloc(std.testing.allocator, 14000);
        defer std.testing.allocator.free(test_data_file);

        var test_tree = try test_parser.parse(test_data_file);
        defer test_tree.deinit();
        defer test_parser.reset();

        for (test_tree.root.Array.items) |entry| {
            const test_obj = entry.Object;
            const schema = test_obj.get("schema").?;
            const tests = test_obj.get("tests").?;
            for (tests.Array.items) |sub_entry| {
                const sub_test_obj = sub_entry.Object;
                const test_data = sub_test_obj.get("data").?;
                const is_valid = sub_test_obj.get("valid").?.Bool;
                var compiled_schema = jsonschema.Schema.compile(std.testing.allocator, schema) catch |e| {
                    var schema_buff: [1024]u8 = undefined;
                    var schema_stream = std.io.fixedBufferStream(&schema_buff);

                    try schema.jsonStringify(.{}, schema_stream.writer());
                    std.log.err("TODO: {s}", .{schema_stream.getWritten()});
                    return e;
                };

                var i: usize = 0;
                while (i < 1) : (i += 1) {
                    const validated = try compiled_schema.validate(test_data);
                    std.testing.expectEqual(is_valid, validated) catch |e| {
                        var schema_buff: [1024]u8 = undefined;
                        var schema_stream = std.io.fixedBufferStream(&schema_buff);

                        var data_buff: [1024]u8 = undefined;
                        var data_stream = std.io.fixedBufferStream(&data_buff);

                        try schema.jsonStringify(.{}, schema_stream.writer());
                        try test_data.jsonStringify(.{}, data_stream.writer());
                        std.log.err("TODO: S:\n{s}\nD:\n{s}", .{ schema_stream.getWritten(), data_stream.getWritten() });
                        return e;
                    };
                }
            }
        }
    }
}
