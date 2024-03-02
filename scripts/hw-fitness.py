#!/usr/bin/python3

import numpy as np;
import subprocess;
import json;
import seaborn as sns;
import math;
import matplotlib.pyplot as plt;
import pandas as pd;

numGenerations = 200;
numTrials = 50;

unadjustedFitness = np.empty((numGenerations, numTrials));
adjustedFitness = np.empty((numGenerations, numTrials));

def filename(adjusted, g, t):
    return ("adjusted" if adjusted else "unadjusted")+"-"+str(g)+"-"+str(t);

stdin = "optmem true\ngoal hello-world\n";
for i in range(numTrials):
    stdin += "new\n"
    for j in range(numGenerations):
        stdin += "
