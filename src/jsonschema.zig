/// Zig API for the Zig JSON Schema library
const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const regex = @import("zig-regex");

// https://json-schema.org/draft/2020-12/json-schema-validation.html#name-type
const Types = struct {
    // This is a enum set as a number can be an int or float
    // and a int can be either a int or a float if the float can be represented as a int without rounding
    types: std.EnumSet(Type) = std.EnumSet(Type){},

    const Self = @This();
    const Type = enum {
        Object,
        Array,
        String,
        Number,
        Integer,
        Bool,
        Null,
    };

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

    pub fn compile(type_schema: std.json.Value) Schema.CompileError!Self {
        return switch (type_schema) {
            .String => |val| .{ .types = try Types.str_to_schema_enum(val) },
            .Array => |array| brk: {
                var comp_types_schema = std.EnumSet(Type){};
                for (array.items) |string| {
                    comp_types_schema.setUnion(try Types.str_to_schema_enum(string.String));
                }
                break :brk .{ .types = comp_types_schema };
            },
            else => error.InvalidType,
        };
    }

    pub fn validate(self: Self, data: std.json.Value) Schema.ValidateError!bool {
        return switch (data) {
            .Object => self.types.contains(.Object),
            .Array => self.types.contains(.Array),
            .String => self.types.contains(.String),
            .Integer => self.types.contains(.Integer) or self.types.contains(.Number),
            .Float => |val| self.types.contains(.Number) or (self.types.contains(.Integer) and (@floor(val) == val and @ceil(val) == val)),
            .NumberString => error.TODONumberString,
            .Bool => self.types.contains(.Bool),
            .Null => self.types.contains(.Null),
        };
    }
};

// https://json-schema.org/draft/2020-12/json-schema-validation.html#name-maxlength
// https://json-schema.org/draft/2020-12/json-schema-validation.html#name-minlength
// https://json-schema.org/draft/2020-12/json-schema-validation.html#name-maxitems
// https://json-schema.org/draft/2020-12/json-schema-validation.html#name-minitems
const MinMax = struct {
    min: i64 = 0,
    max: ?i64 = null,
    type_of: TypeOf,

    const Self = @This();
    const TypeOf = enum {
        Items,
        Length,
    };

    pub fn compile(min_items_schema: ?std.json.Value, max_items_schema: ?std.json.Value, type_of: TypeOf) Schema.CompileError!Self {
        var range = MinMax{ .type_of = type_of };
        if (min_items_schema) |min_items| {
            switch (min_items) {
                .Integer => |ival| range.min = ival,
                .Float => |fval| {
                    if (@floor(fval) == fval and @ceil(fval) == fval) {
                        range.min = @floatToInt(i64, fval);
                    } else {
                        return error.InvalidFloatToInt;
                    }
                },
                .NumberString => return error.TODONumberString,
                else => return error.InvalidMinMaxItemsType,
            }
        }
        if (max_items_schema) |max_items| {
            switch (max_items) {
                .Integer => |ival| range.max = ival,
                .Float => |fval| {
                    if (@floor(fval) == fval and @ceil(fval) == fval) {
                        range.max = @floatToInt(i64, fval);
                    } else {
                        return error.InvalidFloatToInt;
                    }
                },
                .NumberString => return error.TODONumberString,
                else => return error.InvalidMinMaxItemsType,
            }
        }
        return range;
    }

    pub fn validate(self: Self, data: std.json.Value) Schema.ValidateError!bool {
        switch (data) {
            .Array => |array| {
                if (self.type_of == .Items) {
                    var is_valid = array.items.len >= self.min;
                    if (self.max) |max| {
                        is_valid = is_valid and array.items.len <= max;
                    }
                    return is_valid;
                }
                return true;
            },
            .String => |string| {
                const uni_len = try std.unicode.utf8CountCodepoints(string);
                if (self.type_of == .Length) {
                    var is_valid = uni_len >= self.min;
                    if (self.max) |max| {
                        is_valid = is_valid and uni_len <= max;
                    }
                    return is_valid;
                }
                return true;
            },
            else => return true,
        }
    }
};

// https://json-schema.org/draft/2020-12/json-schema-validation.html#name-maximum
// https://json-schema.org/draft/2020-12/json-schema-validation.html#name-minimum
// https://json-schema.org/draft/2020-12/json-schema-validation.html#name-exclusivemaximum
// https://json-schema.org/draft/2020-12/json-schema-validation.html#name-exclusiveminimum
const MinimumMaximum = struct {
    min: union(enum) { Int: i64, Float: f64 } = .{ .Int = 0 },
    max: ?union(enum) { Int: i64, Float: f64 } = null,
    is_exclusive: bool,

    const Self = @This();

    fn toInt(self: Self) Self {
        var range = MinimumMaximum{ .is_exclusive = self.is_exclusive };

        range.min = .{ .Int = switch (self.min) {
            .Int => |val| val,
            .Float => |val| @floatToInt(i64, val),
        } };

        if (self.max) |max| {
            range.max = .{ .Int = switch (max) {
                .Int => |val| val,
                .Float => |val| @floatToInt(i64, val),
            } };
        }

        return range;
    }

    fn toFloat(self: Self) Self {
        var range = MinimumMaximum{ .is_exclusive = self.is_exclusive };

        range.min = .{ .Float = switch (self.min) {
            .Int => |val| @intToFloat(f64, val),
            .Float => |val| val,
        } };

        if (self.max) |max| {
            range.max = .{ .Float = switch (max) {
                .Int => |val| @intToFloat(f64, val),
                .Float => |val| val,
            } };
        }

        return range;
    }

    pub fn compile(minimum_schema: ?std.json.Value, maximum_schema: ?std.json.Value, is_exclusive: bool) Schema.CompileError!Self {
        var range = MinimumMaximum{ .is_exclusive = is_exclusive };
        if (minimum_schema) |minimum| {
            switch (minimum) {
                .Integer => |ival| range.min = .{ .Int = ival },
                .Float => |fval| range.min = .{ .Float = fval },
                .NumberString => return error.TODONumberString,
                else => return error.InvalidMinimumMaximumType,
            }
        }
        if (maximum_schema) |maximum| {
            switch (maximum) {
                .Integer => |ival| range.max = .{ .Int = ival },
                .Float => |fval| range.max = .{ .Float = fval },
                .NumberString => return error.TODONumberString,
                else => return error.InvalidMinimumMaximumType,
            }
        }
        return range;
    }

    fn validate_inclusive(self: Self, data: std.json.Value) Schema.ValidateError!bool {
        switch (data) {
            .Integer => |val| {
                const int_val = self.toInt();
                var is_valid = val >= int_val.min.Int;
                if (int_val.max) |max| {
                    is_valid = is_valid and val <= max.Int;
                }
                return is_valid;
            },
            .Float => |val| {
                const float_val = self.toFloat();
                var is_valid = val >= float_val.min.Float;
                if (float_val.max) |max| {
                    is_valid = is_valid and val <= max.Float;
                }
                return is_valid;
            },
            .NumberString => return error.TODONumberString,
            else => return true,
        }
    }

    fn validate_exclusive(self: Self, data: std.json.Value) Schema.ValidateError!bool {
        switch (data) {
            .Integer => |val| {
                const int_val = self.toInt();
                var is_valid = val > int_val.min.Int;
                if (int_val.max) |max| {
                    is_valid = is_valid and val < max.Int;
                }
                return is_valid;
            },
            .Float => |val| {
                const float_val = self.toFloat();
                var is_valid = val > float_val.min.Float;
                if (float_val.max) |max| {
                    is_valid = is_valid and val < max.Float;
                }
                return is_valid;
            },
            .NumberString => return error.TODONumberString,
            else => return true,
        }
    }

    pub fn validate(self: Self, data: std.json.Value) Schema.ValidateError!bool {
        if (self.is_exclusive) {
            return self.validate_exclusive(data);
        }
        return self.validate_inclusive(data);
    }
};

const PatternProperties = struct {
    pattern: []const u8,
    required: bool,
};

const AllPattern = struct {
    pattern: union(enum) {
        All: PatternProperties,
        Regex: regex.Regex,
    },
    matches: Schema,
};

// https://json-schema.org/draft/2020-12/json-schema-core.html#name-properties
// https://json-schema.org/draft/2020-12/json-schema-core.html#name-patternproperties
// https://json-schema.org/draft/2020-12/json-schema-core.html#name-additionalproperties
// https://json-schema.org/draft/2020-12/json-schema-validation.html#name-required
const PatternMatch = struct {
    pattern: std.ArrayList(AllPattern),
    // Would prefer ?Schema but complier doesn't yes support self dependency:
    // https://github.com/ziglang/zig/issues/2746
    // For now this is a pointer and will need to be freed
    not_matches: ?*Schema,
    required_count: i64,

    const Self = @This();

    pub fn compile(allocator: Allocator, properties: ?std.json.Value, pattern_properties: ?std.json.Value, additional_properties: ?std.json.Value, required: ?std.json.Value) Schema.CompileError!Self {
        var patterns = std.ArrayList(AllPattern).init(allocator);
        errdefer {
            for (patterns.items) |*elem| {
                switch (elem.pattern) {
                    .Regex => |*r| r.deinit(),
                    else => {},
                }
                elem.matches.deinit(allocator);
            }
            patterns.deinit();
        }

        var required_count: i64 = 0;
        if (required) |req| {
            for (req.Array.items) |elem| {
                try patterns.append(.{
                    .pattern = .{ .All = .{ .pattern = elem.String, .required = true } },
                    .matches = Schema{ .Bool = true },
                });
            }
            required_count = @intCast(i64, req.Array.items.len);
        }

        if (properties) |prop| {
            var prop_it = prop.Object.iterator();
            while (prop_it.next()) |elem| {
                for (patterns.items) |*elem2| {
                    if (std.mem.eql(u8, elem.key_ptr.*, elem2.pattern.All.pattern)) {
                        elem2.matches = try Schema.compile(allocator, elem.value_ptr.*);
                        errdefer elem2.matches.deinit(allocator);
                    }
                } else {
                    const match = try Schema.compile(allocator, elem.value_ptr.*);
                    errdefer match.deinit(allocator);
                    try patterns.append(.{
                        .pattern = .{ .All = .{ .pattern = elem.key_ptr.*, .required = false } },
                        .matches = match,
                    });
                }
            }
        }

        if (pattern_properties) |prop| {
            var prop_it = prop.Object.iterator();
            while (prop_it.next()) |elem| {
                const match = try Schema.compile(allocator, elem.value_ptr.*);
                errdefer match.deinit(allocator);
                var reg = try regex.Regex.compile(allocator, elem.key_ptr.*);
                errdefer reg.deinit();
                try patterns.append(.{
                    .pattern = .{ .Regex = reg },
                    .matches = match,
                });
            }
        }

        var not_matches: ?*Schema = null;
        if (additional_properties) |add_prop| {
            not_matches = try allocator.create(Schema);
            errdefer allocator.destroy(not_matches.?);
            not_matches.?.* = try Schema.compile(allocator, add_prop);
        }

        return .{
            .pattern = patterns,
            .not_matches = not_matches,
            .required_count = required_count,
        };
    }

    pub fn validate(self: Self, data: std.json.Value) Schema.ValidateError!bool {
        switch (data) {
            .Object => |obj| {
                var required_matches: usize = 0;
                var obj_it = obj.iterator();
                while (obj_it.next()) |obj_val| {
                    var failed_match = false;
                    var has_match = false;
                    for (self.pattern.items) |*pattern| {
                        switch (pattern.pattern) {
                            .All => |pat| {
                                if (std.mem.eql(u8, pat.pattern, obj_val.key_ptr.*)) {
                                    has_match = true;
                                    if (pat.required) {
                                        required_matches += 1;
                                    }
                                    if (!try pattern.matches.validate(obj_val.value_ptr.*)) {
                                        failed_match = true;
                                        break;
                                    }
                                }
                            },
                            .Regex => |*re| {
                                if (try re.partialMatch(obj_val.key_ptr.*)) {
                                    has_match = true;
                                    if (!try pattern.matches.validate(obj_val.value_ptr.*)) {
                                        failed_match = true;
                                        break;
                                    }
                                }
                            },
                        }
                    }
                    if (!has_match or failed_match) {
                        if (self.not_matches) |not_matches| {
                            if (!try not_matches.validate(obj_val.value_ptr.*)) {
                                return false;
                            }
                        }
                        // Move this above the first if (test speed)
                        if (failed_match) {
                            return false;
                        }
                    }
                }
                return self.required_count <= required_matches;
            },
            else => return true,
        }
    }
};

// https://json-schema.org/draft/2020-12/json-schema-validation.html#name-multipleof
const MultipleOf = struct {
    multiple: union(enum) { Int: i64, Float: f64 },

    const Self = @This();

    pub fn compile(multiple_of_schema: std.json.Value) Schema.CompileError!Self {
        switch (multiple_of_schema) {
            .Integer => |ival| {
                if (ival <= 0) {
                    return error.MultipleOfLessThanZero;
                }
                return .{ .multiple = .{ .Int = ival } };
            },
            .Float => |fval| {
                if (fval <= 0) {
                    return error.MultipleOfLessThanZero;
                }
                return .{ .multiple = .{ .Float = fval } };
            },
            .NumberString => return error.TODONumberString,
            else => return error.InvalidMultipleOfType,
        }
    }

    pub fn validate(self: Self, data: std.json.Value) Schema.ValidateError!bool {
        switch (data) {
            .Integer => |ival| {
                switch (self.multiple) {
                    .Int => |m_ival| {
                        _ = std.math.divExact(i64, ival, m_ival) catch |e| switch (e) {
                            error.UnexpectedRemainder => return false,
                            else => return e,
                        };
                        return true;
                    },
                    .Float => |m_fval| {
                        const fval = @intToFloat(f64, ival);
                        _ = std.math.divExact(f64, fval, m_fval) catch |e| switch (e) {
                            error.UnexpectedRemainder => {
                                const test_result = @divTrunc(fval, m_fval) * m_fval;
                                return std.math.approxEqAbs(f64, test_result, fval, std.math.floatEps(f64));
                            },
                            else => return e,
                        };
                        return true;
                    },
                }
            },
            .Float => |fval| {
                switch (self.multiple) {
                    .Int => |m_ival| {
                        const m_fval = @intToFloat(f64, m_ival);
                        _ = std.math.divExact(f64, fval, m_fval) catch |e| switch (e) {
                            error.UnexpectedRemainder => return false,
                            else => return e,
                        };
                        return true;
                    },
                    .Float => |m_fval| {
                        _ = std.math.divExact(f64, fval, m_fval) catch |e| switch (e) {
                            error.UnexpectedRemainder => {
                                const test_result = @divTrunc(fval, m_fval) * m_fval;
                                return std.math.approxEqAbs(f64, test_result, fval, std.math.floatEps(f64));
                            },
                            else => return e,
                        };
                        return true;
                    },
                }
            },
            .NumberString => return error.TODONumberString,
            else => return true,
        }
    }
};

// https://json-schema.org/draft/2020-12/json-schema-core.html#name-allof
// https://json-schema.org/draft/2020-12/json-schema-core.html#name-anyof
// https://json-schema.org/draft/2020-12/json-schema-core.html#name-oneof
const AllAnyOneOf = struct {
    schemas: []Schema,
    type_of: TypeOf,

    const Self = @This();
    const TypeOf = enum {
        All,
        Any,
        One,
    };

    pub fn compile(allocator: Allocator, type_of_schema: std.json.Value, type_of: TypeOf) Schema.CompileError!Self {
        switch (type_of_schema) {
            .Array => |array| {
                if (array.items.len == 0) {
                    return error.AllAnyOneOfEmptyArray;
                }
                var schemas = std.ArrayList(Schema).init(allocator);
                errdefer {
                    for (schemas.items) |sub_schema| {
                        sub_schema.deinit(allocator);
                    }
                    schemas.deinit();
                }
                for (array.items) |sub_schema| {
                    const comp_sub_schema = try Schema.compile(allocator, sub_schema);
                    errdefer comp_sub_schema.deinit(allocator);
                    try schemas.append(comp_sub_schema);
                }
                return .{ .schemas = schemas.toOwnedSlice(), .type_of = type_of };
            },
            else => return error.InvalidAllOfType,
        }
    }

    pub fn validate(self: Self, data: std.json.Value) Schema.ValidateError!bool {
        switch (self.type_of) {
            .All => {
                for (self.schemas) |sub_schema| {
                    if (!try sub_schema.validate(data)) {
                        return false;
                    }
                }
                return true;
            },
            .Any => {
                for (self.schemas) |sub_schema| {
                    if (try sub_schema.validate(data)) {
                        return true;
                    }
                }
                return false;
            },
            .One => {
                var has_valid = false;
                for (self.schemas) |sub_schema| {
                    const is_valid = try sub_schema.validate(data);
                    if (has_valid and is_valid) {
                        return false;
                    }
                    if (!has_valid) {
                        has_valid = is_valid;
                    }
                }
                return has_valid;
            },
        }
    }
};

// https://json-schema.org/draft/2020-12/json-schema-core.html#name-not
const Not = struct {
    // Would prefer Schema but complier doesn't yes support self dependency:
    // https://github.com/ziglang/zig/issues/2746
    // For now this is a pointer and will need to be freed
    schema: *Schema,

    const Self = @This();

    pub fn compile(allocator: Allocator, not_schema: std.json.Value) Schema.CompileError!Self {
        const sub_schema = try allocator.create(Schema);
        errdefer allocator.destroy(sub_schema);
        sub_schema.* = try Schema.compile(allocator, not_schema);
        return .{ .schema = sub_schema };
    }

    pub fn validate(self: Self, data: std.json.Value) Schema.ValidateError!bool {
        return !try self.schema.validate(data);
    }
};

// https://json-schema.org/draft/2020-12/json-schema-validation.html#name-enum
// https://json-schema.org/draft/2020-12/json-schema-validation.html#name-const
const EnumConst = struct {
    data: std.json.Array,

    const Self = @This();

    pub fn compile(allocator: Allocator, enum_schema: std.json.Value) Schema.CompileError!Self {
        switch (enum_schema) {
            .Array => |data| {
                var copy_data = std.json.Array.init(allocator);
                errdefer copy_data.deinit();
                try copy_data.appendSlice(data.items);
                return .{ .data = copy_data };
            },
            else => return error.EnumConstInvalidType,
        }
    }

    fn eql(enum_s: std.json.Value, data: std.json.Value) Schema.ValidateError!bool {
        switch (enum_s) {
            .Object => {
                if (std.meta.activeTag(enum_s) != std.meta.activeTag(data)) {
                    return false;
                }
                if (enum_s.Object.count() != data.Object.count()) {
                    return false;
                }
                var it = enum_s.Object.iterator();
                while (it.next()) |elem| {
                    if (data.Object.get(elem.key_ptr.*)) |val| {
                        if (!try eql(val, elem.value_ptr.*)) {
                            return false;
                        }
                    } else {
                        return false;
                    }
                }
                return true;
            },
            .Array => {
                if (std.meta.activeTag(enum_s) != std.meta.activeTag(data)) {
                    return false;
                }
                if (enum_s.Array.items.len != data.Array.items.len) {
                    return false;
                }
                for (enum_s.Array.items) |e| {
                    for (data.Array.items) |d| {
                        if (try eql(e, d)) {
                            break;
                        }
                    } else {
                        return false;
                    }
                }
                return true;
            },
            .String => {
                if (std.meta.activeTag(enum_s) != std.meta.activeTag(data)) {
                    return false;
                }
                return std.mem.eql(u8, enum_s.String, data.String);
            },
            .Integer => {
                if (std.meta.activeTag(data) != .Integer and std.meta.activeTag(data) != .Float) {
                    return false;
                }
                if (std.meta.activeTag(data) == .Float) {
                    if (@trunc(data.Float) == data.Float) {
                        return enum_s.Integer == @floatToInt(i64, data.Float);
                    }
                    return false;
                }
                return enum_s.Integer == data.Integer;
            },
            .Float => {
                if (std.meta.activeTag(data) != .Integer and std.meta.activeTag(data) != .Float) {
                    return false;
                }
                if (std.meta.activeTag(data) == .Integer) {
                    if (@trunc(enum_s.Float) == enum_s.Float) {
                        return @floatToInt(i64, enum_s.Float) == data.Integer;
                    }
                    return false;
                }
                return enum_s.Float == data.Float;
            },
            .NumberString => return error.TODONumberString,
            .Bool => {
                if (std.meta.activeTag(enum_s) != std.meta.activeTag(data)) {
                    return false;
                }
                return enum_s.Bool == data.Bool;
            },
            // Null has no payload and the tag type is check at top
            .Null => return std.meta.activeTag(enum_s) == std.meta.activeTag(data),
        }
    }

    pub fn validate(self: Self, data: std.json.Value) Schema.ValidateError!bool {
        for (self.data.items) |elem| {
            if (try eql(elem, data)) {
                return true;
            }
        }
        return false;
    }
};

// https://json-schema.org/draft/2020-12/json-schema-validation.html#name-pattern
const Pattern = struct {
    reg_pattern: *regex.Regex,

    const Self = @This();

    pub fn compile(allocator: Allocator, pattern_schema: std.json.Value) Schema.CompileError!Self {
        switch (pattern_schema) {
            .String => |str| {
                var reg = try allocator.create(regex.Regex);
                reg.* = try regex.Regex.compile(allocator, str);
                errdefer reg.deinit();
                return .{ .reg_pattern = reg };
            },
            else => return error.InvalidPatternType,
        }
    }

    pub fn validate(self: Self, data: std.json.Value) Schema.ValidateError!bool {
        switch (data) {
            .String => |str| return try self.reg_pattern.partialMatch(str),
            else => return true,
        }
    }
};

/// The root compiled schema object
pub const Schema = union(enum) {
    Schemas: []Schema,
    Bool: bool,
    Types: Types,
    MinMaxItems: MinMax,
    MinimumMaximum: MinimumMaximum,
    PatternMatch: PatternMatch,
    MultipleOf: MultipleOf,
    AllOf: AllAnyOneOf,
    AnyOf: AllAnyOneOf,
    OneOf: AllAnyOneOf,
    MinMaxLength: MinMax,
    MinimumMaximumExclusive: MinimumMaximum,
    Not: Not,
    EnumConst: EnumConst,
    Pattern: Pattern,

    const Self = @This();

    const TODOError = error{
        /// TODO top level compiler
        TODOTopLevel,
        TODONumberString,
    };

    /// Error relating to the compilation of the schema
    pub const CompileError = error{
        InvalidType,
        InvalidMinMaxItemsType,
        InvalidFloatToInt,
        InvalidMinimumMaximumType,
        InvalidMultipleOfType,
        MultipleOfLessThanZero,
        AllAnyOneOfEmptyArray,
        InvalidAllOfType,
        EnumConstInvalidType,
        InvalidPatternType,
        NonExhaustiveSchemaValidators,
    } ||
        TODOError ||
        Allocator.Error ||
        @typeInfo(@typeInfo(@TypeOf(regex.Regex.compile)).Fn.return_type.?).ErrorUnion.error_set;

    /// Error relating to the validation of JSON data against the schema
    pub const ValidateError =
        TODOError ||
        @typeInfo(@typeInfo(@TypeOf(regex.Regex.partialMatch)).Fn.return_type.?).ErrorUnion.error_set ||
        @typeInfo(@TypeOf(std.math.divExact(i64, 1, 1))).ErrorUnion.error_set ||
        @typeInfo(@typeInfo(@TypeOf(std.unicode.utf8CountCodepoints)).Fn.return_type.?).ErrorUnion.error_set;

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
            // https://json-schema.org/draft/2020-12/json-schema-core.html#name-boolean-json-schemas
            .Bool => |b| .{ .Bool = b },
            .Object => |object| brk: {
                var schema_used: usize = 0;
                var schema_list = std.ArrayList(Schema).init(allocator);
                errdefer {
                    for (schema_list.items) |sub_schema| {
                        sub_schema.deinit(allocator);
                    }
                    schema_list.deinit();
                }

                if (object.get("type")) |type_schema| {
                    const sub_schema = Schema{ .Types = try Types.compile(type_schema) };
                    errdefer sub_schema.deinit(allocator);
                    try schema_list.append(sub_schema);
                    schema_used += 1;
                }

                const min_items_schema = object.get("minItems");
                const max_items_schema = object.get("maxItems");
                if (min_items_schema != null or max_items_schema != null) {
                    const sub_schema = Schema{ .MinMaxItems = try MinMax.compile(min_items_schema, max_items_schema, .Items) };
                    errdefer sub_schema.deinit(allocator);
                    try schema_list.append(sub_schema);
                    if (min_items_schema) |_| {
                        schema_used += 1;
                    }
                    if (max_items_schema) |_| {
                        schema_used += 1;
                    }
                }

                const minimum_schema = object.get("minimum");
                const maximum_schema = object.get("maximum");
                if (minimum_schema != null or maximum_schema != null) {
                    const sub_schema = Schema{ .MinimumMaximum = try MinimumMaximum.compile(minimum_schema, maximum_schema, false) };
                    errdefer sub_schema.deinit(allocator);
                    try schema_list.append(sub_schema);
                    if (minimum_schema) |_| {
                        schema_used += 1;
                    }
                    if (maximum_schema) |_| {
                        schema_used += 1;
                    }
                }

                const minimum_exclusive_schema = object.get("exclusiveMinimum");
                const maximum_exclusive_schema = object.get("exclusiveMaximum");
                if (minimum_exclusive_schema != null or maximum_exclusive_schema != null) {
                    const sub_schema = Schema{ .MinimumMaximumExclusive = try MinimumMaximum.compile(minimum_exclusive_schema, maximum_exclusive_schema, true) };
                    errdefer sub_schema.deinit(allocator);
                    try schema_list.append(sub_schema);
                    if (minimum_exclusive_schema) |_| {
                        schema_used += 1;
                    }
                    if (maximum_exclusive_schema) |_| {
                        schema_used += 1;
                    }
                }

                const properties = object.get("properties");
                const pattern_properties = object.get("patternProperties");
                const additional_properties = object.get("additionalProperties");
                const required = object.get("required");
                if (properties != null or pattern_properties != null or pattern_properties != null or additional_properties != null or required != null) {
                    const sub_schema = Schema{ .PatternMatch = try PatternMatch.compile(allocator, properties, pattern_properties, additional_properties, required) };
                    errdefer sub_schema.deinit(allocator);
                    try schema_list.append(sub_schema);
                    if (properties) |_| {
                        schema_used += 1;
                    }
                    if (pattern_properties) |_| {
                        schema_used += 1;
                    }
                    if (additional_properties) |_| {
                        schema_used += 1;
                    }
                    if (required) |_| {
                        schema_used += 1;
                    }
                }

                if (object.get("multipleOf")) |multiple_of_schema| {
                    const sub_schema = Schema{ .MultipleOf = try MultipleOf.compile(multiple_of_schema) };
                    errdefer sub_schema.deinit(allocator);
                    try schema_list.append(sub_schema);
                    schema_used += 1;
                }

                if (object.get("allOf")) |all_of_schema| {
                    const sub_schema = Schema{ .AllOf = try AllAnyOneOf.compile(allocator, all_of_schema, .All) };
                    errdefer sub_schema.deinit(allocator);
                    try schema_list.append(sub_schema);
                    schema_used += 1;
                }

                if (object.get("anyOf")) |any_of_schema| {
                    const sub_schema = Schema{ .AnyOf = try AllAnyOneOf.compile(allocator, any_of_schema, .Any) };
                    errdefer sub_schema.deinit(allocator);
                    try schema_list.append(sub_schema);
                    schema_used += 1;
                }

                if (object.get("oneOf")) |one_of_schema| {
                    const sub_schema = Schema{ .OneOf = try AllAnyOneOf.compile(allocator, one_of_schema, .One) };
                    errdefer sub_schema.deinit(allocator);
                    try schema_list.append(sub_schema);
                    schema_used += 1;
                }

                const min_length_schema = object.get("minLength");
                const max_length_schema = object.get("maxLength");
                if (min_length_schema != null or max_length_schema != null) {
                    const sub_schema = Schema{ .MinMaxLength = try MinMax.compile(min_length_schema, max_length_schema, .Length) };
                    errdefer sub_schema.deinit(allocator);
                    try schema_list.append(sub_schema);
                    if (min_length_schema) |_| {
                        schema_used += 1;
                    }
                    if (max_length_schema) |_| {
                        schema_used += 1;
                    }
                }

                if (object.get("not")) |not_schema| {
                    const sub_schema = Schema{ .Not = try Not.compile(allocator, not_schema) };
                    errdefer sub_schema.deinit(allocator);
                    try schema_list.append(sub_schema);
                    schema_used += 1;
                }

                if (object.get("enum")) |enum_schema| {
                    const sub_schema = Schema{ .EnumConst = try EnumConst.compile(allocator, enum_schema) };
                    errdefer sub_schema.deinit(allocator);
                    try schema_list.append(sub_schema);
                    schema_used += 1;
                }

                if (object.get("const")) |const_schema| {
                    // Const is a enum with one element.
                    var enum_schema = std.json.Array.init(allocator);
                    defer enum_schema.deinit();
                    try enum_schema.append(const_schema);

                    const sub_schema = Schema{ .EnumConst = try EnumConst.compile(allocator, .{ .Array = enum_schema }) };
                    errdefer sub_schema.deinit(allocator);
                    try schema_list.append(sub_schema);
                    schema_used += 1;
                }

                if (object.get("pattern")) |pattern_schema| {
                    const sub_schema = Schema{ .Pattern = try Pattern.compile(allocator, pattern_schema) };
                    errdefer sub_schema.deinit(allocator);
                    try schema_list.append(sub_schema);
                    schema_used += 1;
                }

                if (object.count() != schema_used) {
                    return error.NonExhaustiveSchemaValidators;
                }

                break :brk .{ .Schemas = schema_list.toOwnedSlice() };
            },
            else => CompileError.TODOTopLevel,
        };
    }

    ///
    /// Deinitialise the compiled schema.
    ///
    /// Arguments:
    ///     IN self: Self - The compiled schema.
    ///     IN allocator: Allocator - The allocator used in Schema.compile()
    ///
    pub fn deinit(self: Self, allocator: Allocator) void {
        switch (self) {
            .Schemas => |schemas| {
                for (schemas) |elem| {
                    elem.deinit(allocator);
                }
                allocator.free(schemas);
            },
            .PatternMatch => |pattern_match| {
                for (pattern_match.pattern.items) |*pattern| {
                    switch (pattern.pattern) {
                        .Regex => |*reg| reg.deinit(),
                        else => {},
                    }
                    pattern.matches.deinit(allocator);
                }
                pattern_match.pattern.deinit();
                if (pattern_match.not_matches) |not_matches| {
                    not_matches.*.deinit(allocator);
                    allocator.destroy(not_matches);
                }
            },
            .AllOf, .AnyOf, .OneOf => |all_of| {
                for (all_of.schemas) |schemas| {
                    schemas.deinit(allocator);
                }
                allocator.free(all_of.schemas);
            },
            .Not => |not| {
                not.schema.deinit(allocator);
                allocator.destroy(not.schema);
            },
            .EnumConst => |enum_const_schema| {
                enum_const_schema.data.deinit();
            },
            .Pattern => |pattern| {
                pattern.reg_pattern.deinit();
                allocator.destroy(pattern.reg_pattern);
            },
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
            .Schemas => |schemas| {
                for (schemas) |schema| {
                    if (!try schema.validate(data)) {
                        return false;
                    }
                }
                return true;
            },
            inline else => |sch| sch.validate(data),
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
