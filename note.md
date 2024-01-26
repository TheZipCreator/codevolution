Don't know why I decided to not include my original notes in the git repo. Anyway...

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
