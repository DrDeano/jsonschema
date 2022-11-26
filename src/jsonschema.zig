/// Zig API for the Zig JSON Schema library
const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const Type = enum {
    Object,
    Array,
    String,
    Number,
    Integer,
    Bool,
    Null,
};

const Types = struct {
    // This is a enum set as a number can be an int or float
    // and a int can be either a int or a float if the float can be represented as a int without rounding
    types: std.EnumSet(Type) = std.EnumSet(Type){},

    const Self = @This();

    fn str_to_schema_enum(str: []const u8) Schema.CompileError!std.EnumSet(Type) {
        var set = std.EnumSet(Type){};
        if (std.mem.eql(u8, str, "integer")) {
            set.insert(.Integer);
        } else if (std.mem.eql(u8, str, "number")) {
            set.insert(.Number);
        } else if (std.mem.eql(u8, str, "string")) {
            set.insert(.String);
        } else if (std.mem.eql(u8, str, "object")) {
            set.insert(.Object);
        } else if (std.mem.eql(u8, str, "array")) {
            set.insert(.Array);
        } else if (std.mem.eql(u8, str, "boolean")) {
            set.insert(.Bool);
        } else if (std.mem.eql(u8, str, "null")) {
            set.insert(.Null);
        } else {
            return error.InvalidType;
        }
        return set;
    }

    pub fn compile(schema: std.json.Value) Schema.CompileError!Self {
        switch (schema) {
            .String => |val| return .{ .types = try Types.str_to_schema_enum(val) },
            .Array => |array| {
                var comp_types_schema = std.EnumSet(Type){};
                for (array.items) |string| {
                    comp_types_schema.setUnion(try Types.str_to_schema_enum(string.String));
                }
                return .{ .types = comp_types_schema };
            },
            else => return error.InvalidType,
        }
    }

    pub fn validate(self: Self, data: std.json.Value) Schema.ValidateError!bool {
        return switch (data) {
            .Object => self.types.contains(.Object),
            .Array => self.types.contains(.Array),
            .String => self.types.contains(.String),
            .Integer => self.types.contains(.Integer) or self.types.contains(.Number),
            .Float => |val| self.types.contains(.Number) or (self.types.contains(.Integer) and (@floor(val) == val and @ceil(val) == val)),
            .NumberString => error.TODOTopLevel,
            .Bool => self.types.contains(.Bool),
            .Null => self.types.contains(.Null),
        };
    }
};

/// The root compiled schema object
pub const Schema = union(enum) {
    Schemas: []Schema,
    Bool: bool,
    Types: Types,

    const Self = @This();

    /// Error relating to the compilation of the schema
    pub const CompileError = error{
        /// TODO top level compiler
        TODOTopLevel,
        InvalidType,
    } || Allocator.Error;

    /// Error relating to the validation of JSON data against the schema
    pub const ValidateError = error{
        /// TODO top level compiler
        TODOTopLevel,
    };

    ///
    /// Compile the provided JSON schema into a more refined form for faster validation.
    ///
    /// Arguments:
    ///     IN allocator: Allocator - An allocator.
    ///     IN schema: std.json.Value - The JSON data representing a schema to be compiled.
    ///
    /// Return: Schema
    ///     A schema object that can be used to validate against data. See Schema.validate().
    ///
    /// Error: CompileError
    ///     TODOTopLevel - TODO top level validator
    ///
    pub fn compile(allocator: Allocator, schema: std.json.Value) CompileError!Self {
        return switch (schema) {
            .Bool => |b| return Schema{ .Bool = b },
            .Object => |object| brk: {
                var schema_list = std.ArrayList(Schema).init(allocator);
                errdefer schema_list.deinit();

                if (object.get("type")) |type_schema| {
                    const sub_schema = Schema{ .Types = try Types.compile(type_schema) };
                    try schema_list.append(sub_schema);
                }

                break :brk Schema{ .Schemas = schema_list.toOwnedSlice() };
            },
            else => CompileError.TODOTopLevel,
        };
    }

    pub fn deinit(self: Self, allocator: Allocator) void {
        switch (self) {
            .Schemas => |schemas| allocator.free(schemas),
            else => {},
        }
    }

    ///
    /// Validate JSON data against a compiled schema.
    ///
    /// Arguments:
    ///     IN self: Self - The compiled schema.
    ///     IN data: std.json.Value - The JSON data to validate.
    ///
    /// Return: bool
    ///     Whether the JSON data matches the schema.
    ///
    /// Error: ValidateError
    ///     TODOTopLevel - TODO top level compiler
    ///
    pub fn validate(self: Self, data: std.json.Value) ValidateError!bool {
        return switch (self) {
            .Bool => |b| b,
            .Types => |types| types.validate(data),
            .Schemas => |schemas| {
                for (schemas) |schema| {
                    if (!try schema.validate(data)) {
                        return false;
                    }
                }
                return true;
            },
        };
    }
};

///
/// Compile then validate the data against the provided schema.
/// This will first compile the provided JSON schema then validate against the data.
///
/// Arguments:
///     IN allocator: Allocator - An allocator.
///     IN schema: std.json.Value - The JSON data representing a schema to be compiled.
///     IN data: std.json.Value - The JSON data to test against the schema.
///
/// Return: bool
///     True if the data matched the schema.
///
/// Error: CompileError || ValidateError
///     TODOTopLevel - TODO top level validator
///
pub fn validate(allocator: Allocator, schema: std.json.Value, data: std.json.Value) (Schema.CompileError || Schema.ValidateError)!bool {
    const js_cmp = try Schema.compile(allocator, schema);
    defer js_cmp.deinit(allocator);
    return js_cmp.validate(data);
}
