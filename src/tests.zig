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

    const schema = jsonschema.Schema{ .Bool = true };

    try expectError(jsonschema.Schema.CompileError.TODOTopLevel, jsonschema.validate(std.testing.allocator, schema_tree.root, data_tree.root));
    try expectError(jsonschema.Schema.CompileError.TODOTopLevel, jsonschema.Schema.compile(std.testing.allocator, schema_tree.root));
    try expectError(jsonschema.Schema.ValidateError.TODOTopLevel, jsonschema.Schema.validate(schema, data_tree.root));
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
