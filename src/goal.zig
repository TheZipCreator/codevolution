//! Contains goals for the programs to accomplish

const std = @import("std");
const Random = std.rand.Random;
const Allocator = std.mem.Allocator;

const Program = @import("program.zig").Program;

const Generation = @import("generation.zig").Generation;

const color = @import("color.zig").color;

/// A goal
pub const Goal = struct {
	name: []const u8,
	desc: []const u8,
	input: ?*const fn(Allocator, Random) anyerror![]const u8 = null, // returned slice is owned by the caller and must be freed
	fitness: *const fn(Program) i64,
	outputAsString: bool = false, // whether output is a string (for ease of use)
	includeLengthInFitness: bool = true, // whether to include length as part of fitness calculation

	pub fn write(self: Goal, writer: anytype) !void {
		try writer.print(color.green++"{s}\n"++color.default, .{self.name});
		try writer.print("{s}\n", .{self.desc});
	}
};

/// Levenshtein distance
fn stringDist(comptime baseCost: comptime_int, s: []const u8, t: []const u8) usize {
	// mostly stolen from https://en.wikipedia.org/wiki/Levenshtein_distance and ziggified
	var v0 = comptime init: {
		var ret: [Generation.numCycles]usize = undefined;
		for(0..Generation.numCycles) |i|
			ret[i] = baseCost*i;
		break :init ret;
	};
	var v1 = [_]usize { 0 } ** Generation.numCycles;
	for(0..s.len) |i| {
		v1[0] = baseCost*(i+1);
		for(0..t.len) |j| {
			const deletionCost = v0[j+1]+baseCost;
			const insertionCost = v1[j]+baseCost;
			const subsitutionCost = v0[j]+@abs(@as(i16, @intCast(s[i]))-@as(i16, @intCast(t[j])));
			// const deletionCost = v0[j+1]+1;
			// const insertionCost = v1[j]+1;
			// const subsitutionCost = if(s[i] == t[j]) v0[j] else v0[j]+1;
			v1[j+1] = @min(deletionCost, @min(insertionCost, subsitutionCost));
		}
		// swap v0 with v1
		for(&v0, &v1) |*a, *b|
			std.mem.swap(usize, a, b);
	}
	return v0[t.len];
}

fn print1(p: Program) i64 {
	var ret: i64 = 0;
	for(p.output.items) |b| {
		if(b == 1)
			ret += 1;
	}
	return ret;
}

fn helloWorld(p: Program) i64 {
	return -@as(i64, @intCast(stringDist(16, "Hello, World!", p.output.items)));
}

fn increasing(p: Program) i64 {
	if(p.output.items.len == 0)
		return 0;
	var ret: i64 = 0;
	var last: u8 = p.output.items[0];
	for(p.output.items) |b| {
		ret += if(b > last) 1 else -1;
		last = b;
	}
	return ret;
}


fn randomInput(ally: Allocator, rng: Random) ![]const u8 {
	const str = try ally.alloc(u8, Generation.numCycles); // numCycles is the most possible output
	for(str) |*c|
		c.* = rng.int(u8);
	return str;
}

inline fn outDist(a: u8, b: u8) i64 {
	return @intCast(@abs(@as(i64, @intCast(a))-@as(i64, @intCast(b))));
}

fn catFitness(p: Program) i64 {
	var ret: i64 = @intCast(p.output.items.len);
	for(p.output.items, 0..) |o, i|
		ret -= outDist(o, p.input[i]);
	return ret;
}

fn octupleFitness(p: Program) i64 {
	const fitMult = 100;
	var ret: i64 = @intCast(p.output.items.len*fitMult);
	for(p.output.items, 0..) |out, i| {
		ret += fitMult;
		// use "multiplicative" distance (e.g. dist = 2 when output = input*2)
		const in = p.input[i]*%8;
		const mult: f64 = 
			if(in == 0 and out == 0)
				0
			else if((in == 0 and out != 0) or (out == 0 and in != 0))
				8 // arbitrary high number
			else
				@abs(@as(f64, @floatFromInt(out))/(@as(f64, @floatFromInt(in)))-1);
		ret -= @intFromFloat(mult*fitMult);
		// std.debug.print("{} {} {d} -> {}\n", .{in, out, mult, ret});
	}
	return ret;
}

fn add8Fitness(p: Program) i64 {
	var ret: i64 = @intCast(p.output.items.len*10);
	for(p.output.items, 0..) |o, i|
		ret -= outDist(o, p.input[i]+%8);
	return ret;
}

/// Existing goals
pub const goals = .{
	.print1 = Goal {
		.name = "print1",
		.desc = "Print as many ones as possible. Fitness is how many ones are outputted.",
		.fitness = &print1
	},
	.helloWorld = Goal {
		.name = "hello-world",
		.desc = "Print the string 'Hello, World!'. Fitness is the negative levenshtein distance.",
		.fitness = &helloWorld,
		.outputAsString = true
	},
	.increasing = Goal { 
		.name = "increasing",
		.desc = "Have increasing strings of numbers, for as long as possible. Every successive increase is a +1 to fitness, and every successive decrease is a -1.",
		.fitness = &increasing 
	},
	.cat = Goal {
		.name = "cat",
		.desc = "Input should be the same as output. Fitness is measured by output length minus difference of input and output.",
		.input = &randomInput,
		.fitness = &catFitness
	},
	.add8 = Goal {
		.name = "add8",
		.desc = "Values in the output should be those in the input plus 8. Fitness is measured by output length minus difference of input+8 and output.",
		.input = &randomInput,
		.fitness = &add8Fitness
	},
	.octuple = Goal {
		.name = "octuple",
		.desc = "Values in the output should be eight times those in the input. Fitness is measured by output length minus difference of input*8 and output",
		.input = &randomInput,
		.fitness = &octupleFitness,
		.includeLengthInFitness = false
	},
	// .hex = Goal {
	// 	.name = "hex",
	// 	.desc = "Output should be the given string outputted in hex. 
	// }
};
