#set page("us-letter")

#align(center)[
	#text(size: 16pt)[
		= CODEVOLUTION
		Can Genetic Algorithms Write Code?
	]

	[name omitted]
]

#let inline-num(n) = {
	numbering("(i)", n);
}

#set raw(syntaxes: "codevolution.yml")

#set heading(numbering: "1.")

#columns(2)[
= Abstract
In this paper, I showcase an algorithm written for generating code in a custom Assembly-like programming language. This algorithm is given a specific goal, which consists of a generated input and an expected output (measured by a fitness function). It is then able to, via a genetic algorithm, iteratively improve randomly generated code into code that can achieve the set goal.

*Keywords:* Genetic Programming, Genetic Algorithm, Assembly

= Introduction
Genetic algorithms are search and optimization algorithms inspired by the principles of Natural Selection.@genetic-algorithm They consist of a number of individuals, comprising a population. Each of these individuals has some sort of _genome_, which determines how they act, and over time the algorithm fine tunes that genome to achieve certain results. The algorithm used in this paper consists of three main steps: #inline-num(1) the evaluation of individuals based on how well they perform at the given task (the _fitness function_), #inline-num(2) the elimination of the worst-performing individuals (_selection_), and #inline-num(3) the random altering of those individuals (_mutation_). One of these cycles is called a _generation_. The hope is that, over time, as more generations are run and as more possibilities are explored, the individuals will get better at their specified task. For this specific experiment, a few different tasks were used in different trials; each of these tasks entail performing an algorithm of some kind. For example, in one trial individuals were expected to output as many of the number `1` as possible, while in another trial individuals were expected to directly copy their input to their output.

= Model
Each individual (hereby referred to as a _program_) consists of a series of instructions (their genome). This instruction-based approach differs from more common grammar-based approaches, such as the one seen in @grammar-based-gp. At the start of the trial, one thousand programs are generated at random, with lengths between five and ten (inclusive).  Every program in the population is run for exactly one thousand cycles (each cycle corresponding to a single instruction being run) before being forcibly terminated, however they may halt on their own before that point. Programs are given an input and an output, and are expected to produce a certain output given a certain input. Once all programs in a generation are run, they are scored by the fitness function, which compares each program's output to the expected output, in a manner dependent on the task. The lowest-ranking half of programs are then discarded, and the remaining programs are cloned into their place, with mutations applied.
== Architecture
Each program has two buffers available to it: the input buffer, and the output buffer. Both are composed of bytes, and programs may read from the input buffer, and write to the output buffer (the input buffer can be thought of as a queue, while the output buffer can be thought of as a stack).

Programs have ten registers. The first register is the instruction pointer (abbreviated as `ip`), which describes which instruction the program is currently on. If `ip` becomes less than zero, it is reset to zero, and if it becomes more than the total length of the program, the program immediately halts.
]
#pagebreak()
#box(height: 98pt, columns(2)[
 The next register is the location in the input buffer (called the input buffer position or `ibp`); when an `in` command is executed, the byte at `ibp` is read into the specified register. Then `ibp` is advanced to the next byte in the input buffer. The previous two registers are 64-bit. The following eight registers (called _data registers_) are general-use and may be modified during runtime; they are 8-bit. They are named `r0` through `r7`.
== Instruction Set
Below is a table of the instructions that programs were given. `reg` represents a data register, and `imm` represents an immediate value.
])
#columns(1)[
#table(
	columns: (50%, 50%),
	[*Instruction*], [*Action*],
	[`mov <reg>, <reg | imm>`], [Moves a value into a register.],
	[`in <reg>`], [Stores the value at `ibp` in the input buffer to a specified register, and then advances `ibp`.],
	[`out <reg | imm>`], [Outputs a value.],
	[`jmp <off>`], [Sets `ip` to `ip+<off>`, where `<off>` is a signed 64-bit integer. When displaying programs, the offsets are abstracted into labels to aide readability, so a jump might be displayed as `jmp A` (jump to label A), or possibly `halt` if it jumps past the end of the program.],
	[`op <add | sub | mul | div>, <reg>, <reg | imm>`], [Performs the specified operation with the destination register and the value, and stores it in the destination register. When displaying programs, the `op` is omitted, and this is displayed as just the operation.]
)
]
#columns(2)[
== Mutation
A percentage of programs will have their offspring be mutated. This rate is named the _mutation rate_. When a program is mutated, one of the following mutations occur:
- An instruction is modified. (for example, the operation in an `op` instruction being changed, or an `out` now outputting from a register instead of from an immediate. Note that this does not change the opcode of the instruction, only the operations.)
- An instruction is replaced with a completely random instruction.
- Two instructions are swapped with eachother.
- An instruction is inserted at a random location. Jump targets are modified such that they point to the same instruction they did previously.
- An instruction is removed. Jump targets are altered as previously described.
== Fitness Function Design <ffd-section>
The performance for any genetic algorithm is highly dependent on the design of the fitness function. In @fitness-function-design, the authors lay out a few basic principles for the design of a fitness function. Namely, for this experiment: #inline-num(1) try to convert _phenotypic_ requirements (in our case, the requirements of what the program outputs) to _genotypic_ requirements (in our case, requirements on what the program's code should look like), and #inline-num(2) transform decision requirements (e.g. requirements that look like a yes/no question) into optimization requirements (e.g. ones where you can "grade" based on intermediate levels of satisfaction). Of these, #inline-num(2) was done most in the design of the fitness functions used for this experiment, as just a pure yes/no question does not allow gradual improvement, and that is necessary for a genetic algorithm.
= Results
== Tasks <tasks>
For many of the tasks given, the algorithm did well in creating a program to perform it, but some tasks were problematic. This reflects the difficulty of designing adequate fitness functions for tasks, as it can be difficult to express a problem in a way that is conducive to genetic algorithms. Below is a list of every task attempted:
=== Print 1
The goal of this task was to output as many `1`s as possible. Fitness was defined as how many `1`s are left in the output buffer after the program is terminated. The algorithm did very well, achieving a median of 500 after 20 generations (as seen in @print1-fitness).
#figure(
	image("print1-fitness.svg"),
	caption: [Median fitness of 100 trials for goal `print1` after 20 generations.]
) <print1-fitness>
The optimal score was initially presumed to be 500, since that would be the score gotten by an `out 1` immediately followed by a jump back to the start. However, this was not the case, as a program could output twice before (or more) before jumping back to the start, garnering a higher fitness (see @fitness-over-500), in effect unrolling a loop.
#figure(
	```cv
A out 1
  out 1
  jmp A
  in r7
	```,
	caption: [Program with fitness of over 500 (667).]
) <fitness-over-500>
=== Cat
The goal of this task is to copy the input to the output (thereby mimicking the UNIX `cat` utility, hence the name). Initially, fitness was measured by negative Levenshtein distance from the input to the output (negative, since higher fitness is better). Levenshtein distance, also known as edit distance, is the amount of edits (insertions, deletions, or subsitutions) that it takes to go from one string to another.@levenshtein-distance This was not particularly lenient, but it worked well enough. At the start of a given trial, there will usually be one or two programs that output a byte from their input by pure chance (and in some trials an entire working program was generated by chance), so this specific challenge wasn't particularly hard for the algorithm to do. Later, the fitness function was changed to just simply add up all the differences, negated, between the input and the output. This allowed for variable length output (unlike before where it was expected that the program should output the _exact same_ amount of output as there is input, disallowing some valid solutions, such as an "unrolled loop" solution as seen in the previous section). However, there was an issue with this fitness function #sym.dash.em the maximal score was zero, and outputting nothing gave that score. So, many programs just simply outputted nothing, as it was much simpler than the alternative. This is an example of what is called _specification gaming_, "a particular failure mode in specification that can occur after an objective function has been specified by a human designer. It refers to a phenomenon where machine learning algorithms 'game' whatever specification they were given, finding ways to achieve the specified objective with techniques that are totally disconnected from what the operator wanted. This behavior can look like cheats or workarounds." @specification-gaming Luckily, in this case, the solution was simple enough #sym.dash.em an extra point in the fitness function was given for every byte outputted. This encouraged the algorithm to generate programs that actually output something, and not nothing. This produced better results, since a program was now required to output something to stay competitive.
=== Hello World
_Hello, World_ is a classic example in programming, typically used as an introductory program for beginners, or to demonstrate a new programming language's syntax. As such, it makes sense to have it as a goal for a code-generating algorithm. The goal is to print the string `Hello, World!` to the output, and fitness was initially measured by negative Levenshtein distance. Programs were able to make incremental improvements, but it was rather slow. This is because, when using pure Levenshtein distance, the ASCII differences between characters are not taken into account, but these differences matter in our case since mutations can directly add or subtract from instruction operands. This means that paths that could allow faster evolution are not encouraged as much as they should be. A change was made to the Levenshtein distance function to accomodate for character differences, the results of which are seen in @hello-world-fitness.

#figure(
	image("hw-fitness.svg"),
	caption: [Median fitness of the `hello-world` goal each generation (averaged over 10 trials with 200 generations each).]
) <hello-world-fitness>

As the chart demonstrates, the change to the Levenshtein distance function drastically improved the rate of fitness gain. In general, it is best to try to make gradual improvements as easy as possible, as it typically leads to good results.

#figure(
	```cv
  out 72
  out 101
  out 108
  mov r4, r0
  out 108
  sub r7, 173
  out 111
  mul r4, 217
  out 44
  mov r5, 121
  in r6
  out 32
  out 87
  jmp A
A out 111
  out 114
  out 108
  out 100
  out 33
	```,
	caption: [A hello world program generated by the algorithm.]
) <hello-world>

=== Increasing
The goal of this task was to produce sequences of increasing numbers. Fitness was measured by how many differences between sequential outputs were positive. The desired outcome was that the algorithm would learn to use the operation instruction to repeatedly add to a number, thereby generating an increasing sequence with minimal effort. However, instead, the algorithm generated a "lazier" program; it created hard-coded increasing sequences, followed by a jump back to the top to get the highest fitness possible  (see @hardcoded-increasing). This shows that the algorithm tends towards less "intelligent", but simpler, programs.

#figure(
	```cv
A out 208
  out 221
  out 254
	; note: registers are initialized to zero, so the following instruction outputs zero.
  out r2
  out 10
  out 53
  out 60
  out 81
  jmp A
	```,
	caption: [A hard-coded increasing sequence.]
) <hardcoded-increasing>

=== Add Eight
The goal of this task is similar to `cat`, except every output should be the input, plus eight, and it was scored similarly. The reason that the task was specifically "add eight" and not "increment" was that by having the number not be _directly next to_ the input, it gave programs more leniency; for example, if it was just "increment", then the program that adds two to its input and the program that just directly outputs its input would give the same fitness, when the former is much closer to what we want. With a higher number, such as eight, there's now fifteen different options that give higher fitness than doing nothing to the input (adding the seven numbers before eight, adding eight itself, and adding the seven numbers after eight). As discussed previously, this extra leniency is almost always a good thing. At first, the algorithm exploited a bug in the codebase to gain fitness infinitely, which was quickly fixed #sym.dash.em this being another instance of specification gaming. Once that was resolved, it managed the task well.

Something of note is that one program, instead of adding eight to the input, subtracted 247 from it (see @sub-247), which under arithmetic mod 256 (which is used since the general purpose registers are eight-bit), is the same operation as adding eight. This demonstrates that genetic algorithms sometimes give unexpected results.

#figure(
	```cv
A in r7
	sub r7, 247
	out r7
	jmp A
	```,
	caption: [A program that subtracted 247 instead of adding eight]
) <sub-247>

== Mutation Rate and Population Size
Preliminary experiments used a mutation rate below 100% (to avoid issues where optimal programs would get destroyed too early), but experimentally a rate of 100% proved optimal. The reasons for this are hypothesized to be that #inline-num(1) the higher mutation rate helps explore the possibility space in less time, and #inline-num(2) there exists some sort of _soft mutation rate_; this is the amount of mutations that actually have an effect on the performance of the program #sym.dash.em some programs have a number of "garbage" instructions in them (instructions that don't do anything, see the previously shown @hello-world, which has a few garbage instructions), so the effects of a high mutation rate (especially a rate of 100%, which would presumably have bad effects since beneficial mutations could be instantly mutated away) appears to be limited. However, a low mutation rate appears to be generally worse, since it just seems to delay the evolution of programs.

Population size does have a significant effect though, in general higher population sizes increase the rate at which the algorithm improves. This makes intuitive sense; the more individuals, the faster the possibility space can be explored. However, higher population sizes also result in more computational cost, so for all trials in @tasks, a size of 1000 was used; this choice was mostly arbitrary, but it appeared to be a size that wasn't too big nor too small.

#figure(
	image("size-mut.svg"),
	caption: [A heatmap of the average fitness for the `print1` task after 50 generations, over 5 trials, with mutation rate and population size as independent variables.]
) <size-mut>

== Optimizing Program Size
As previously mentioned, there is a problem of programs having many "garbage" instructions that clutter up the program. In some cases these can slow down the program, leading to the instructions being optimized out naturally, but in most cases these are innert #sym.dash.em having no effect on fitness. However, these extraneous instructions are still somewhat undesirable. To counter this, a term was added to the fitness function to disincentivize longer programs (which is a _genotypic_ requirement, as introduced in @ffd-section) to mixed results. For one, the term must be insignificant enough that it doesn't hinder progress (a program that does the task better but is longer should still have higher fitness than one that's shorter but worse at the task) but significant enough that when the space is competitive, it favors shorter programs. Having every instruction subtract a tenth of a point (or more accurately, multiplying the fitness by ten and then subtracting one point for each instruction used) seemed to work well. However, for some tasks, this meant that the empty program, while having a lower fitness than a program which does the task correctly, would take less effort to get to than a correct program, and therefore be reached quicker; at which point the algorithm would reach a local maximum and be unable to improve.

= Discussion
== Limitations <limitations>
There are a few limitations in the approach presented in this paper #sym.dash.em primarily, the algorithm can not do very complex tasks. The selection shown here is mostly simple tasks that would take any half-decent programmer a few minutes at most, and the programs that they would produce would be of a much higher quality. Assigning any task with sufficient complexity will result in the failure of the algorithm to produce a program that satisfies the constraints. Conditional instructions were not included in the instruction set since the algorithm (in its current form) would most likely not be able to utilize them correctly.

Another limitation is that genetic algorithms like this one tend to require a lot of computation time, since it has to simulate a whole population every single generation. Also, most mutations done will tend not to be beneficial, meaning some of that time is wasted too.
== Continuing From Here
There are a few possible improvements. For one, there may be different types of instruction sets that would be more amenable to these sorts of algorithms. It would definitely be worth it to change it up and see the results. Changing what kinds of mutations can occur could likewise result in improvements.

It may also be possible to devise a new kind of algorithm #sym.dash.em one which searches the entire set of adjacent (e.g. one mutation away) programs and picks the most optimal one, without having to go through the cycle of a genetic algorithm. This could possibly fix the second problem presented in the previous section, requiring less computational resources and being generally faster.

= Conclusion
Overall, the experiment was a success. The point of this experiment was to gauge whether a genetic algorithm would work in an assembly-like programming language, and from these results, it appears to. However, it is worth noting that there are significant limitations with my approach, and this is by no means fit for application in any real-world context.

On the whole, more work is needed.
#colbreak()
#bibliography("paper.bib")
Source code for the algorithm used in this paper is available at #link("https://github.com/thezipcreator/codevolution") under the GNU General Public License Version 3.0.
]
