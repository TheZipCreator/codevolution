It seems that mutation rate is best when it's put at 100%. This is because I think there's sort of a "soft mutation rate"; i.e. the percentage of mutations that don't do anything. They don't do anything since around half of each program appears to be garbage (as in, instructions that don't do anything or affect the result), and mutating that does nothing to the fitness of the program.

Generation size also doesn't seem to have a large effect on fitness over time, but that needs more testing.

Programs seem to do well with `print1`, but on most trials they cap out at 500 (with programs that are mostly just loops of `out 1` followed by a jump back), which I thought was an optimal score, until in one trial one program went to 667. Looking at it, it outputted *twice* before jumping back. I haven't been able to replicate this again.

In one trial, there was a program like so (generation #31):
```asm
  in r2
A out 1
  mov r1, r7
  out 1
  jmp A
  ...
```
which got a score of 500. Note how that's despite there being two `out`s. This is different from the usual program that shows up around this generation, which usually has just one `out`. Within 2 generations, the extraneous `mov` was removed, achieving a fitness of 666.

Compared to `print1`, the program struggles a bit more at `hello-world`. I think it might be better if I somehow added some leniency to the Levenshtein Distance (e.g. subsitutions of characters that have closer ascii values to other characters cost less), so I'll probably try that.

It takes hundreds of generations to get good results, but the upside is that running generations doesn't take much time with this goal. I believe that's because most of the programs are linear in nature and end rather quickly, unlike other goals where loops improve fitness.

I notice that with this goal, programs tend to have a bunch of useless garbage in them. I believe that's because there's no incentive to really have less instructions; the amount of cycles used to print "Hello, World!" isn't particularly important, as long as it gets printed.

My hope with the `increasing` is that it'd use the `add` instruction to generate a sequence of increasing integers, but alas, no. It instead just hardcoded sequences of increasing integers.

The program does astonishingly well at `cat`. Within just 10 or so generations it manages to get fitness all the way to `-2`.

I noticed that in one trial, there was one program like so:
```asm
  out r0
A in r2
  out r2
  in r3
  mov r6, 32
  out r3
  jmp A
  ...
```
which catted twice. Due to the way I'm scoring this (levenshtein distance from an input), I think this scores lower than just doing it once (since at some point it's just printing zeroes, which do not exist in the original input).

It really struggles at `double`. It can't seem to realize it needs to multiply the input by two. I think I'm gonna modify the levenshtein distance to take into account the ASCII distance between characters

The way I implemented Levenshtein distance with ASCII differences was broken, and I fixed it. This vastly improved performance on goal `hello-world` since they could now improve much more gradually than before.

Added `add8`, where the goal is to add 8 to the input.
Also, I'm going to try making it so that instead of expecting a fixed length for the output, it instead bases it on the length of the input. My hypothesis is that it will just learn to output nothing.

It did, but the solution was simple enough. Simply add the count of bytes outputted to the total fitness. Also funny bug, when implementing this first it exploited an overflow bug that allowed it to get fitness for basically free. Normally Zig prevents overflow, but I was compiling in `ReleaseFast` mode, so it didn't report it.

Okay, so it still fails at `add8`. I'm gonna try increasing the base cost per byte and see if that works. I tried increasing it to 8, but that was too small it seems, so I'm going to try 10.

One of them had a sequence of instructions that contained a subtraction by 247, which is the exact same as adding 8, since arithmetic here is mod 256. That's slightly interesting.

One of them actually learned how to add 8, sort of. But its code is a fucking mess:
```
  mov r6, r4
B in r4
  out r4
  jmp A
  in r7
C mov r3, 36
  out r1
  jmp B
  in r1
  out r2
D jmp C
A add r4, r5
  in r1
  sub r1, 248
  jmp D
```
This basically alternates between outputting the input (as in `cat`) and then outputting the input minus 248 (which is the same as adding 8, as said previously). It gets a much higher fitness than its competitors but it still isn't optimal quite yet. (eventually it just started skipping over the part where it outputs 1 every other loop cycle, so it became almost optimal)

I added a term to the fitness function to discourage longer programs. It multiplies the previous fitness by 10 (giving it a weight) and removes 1 per every instruction used. This seems to work. Although it takes a bit to remove instructions.

I added a bias to removing instructions (now 50% of the time it removes an instruction, and the other 50% of the time it does any of the other things)
