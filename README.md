# Summary
parse_mplus is a cross-platform command-line parsing Lua script for Mplus output (.out files). Mplus is a statistical program made in Fortran that outputs in a custom style based off of Fortan, making it arguably both hard to read and parse. This program parses various sections of the Mplus output and provides two output formats:

- CSV table, importable into your spreadsheet program of choice (or another programming language)
- Fully commented R plotting script

And currently supports outputting tables in these sections:

- LCP: FINAL CLASS COUNTS AND PROPORTIONS FOR THE LATENT CLASSES BASED ON THE ESTIMATED MODEL
- CP: RESULTS IN PROBABILITY SCALE
- CI: CONFIDENCE INTERVALS IN PROBABILITY SCALE
- R3STEP: TESTS OF CATEGORICAL LATENT VARIABLE MULTINOMIAL LOGISTIC REGRESSIONS USING THE 3-STEP PROCEDURE
- BCH: EQUALITY TESTS OF MEANS ACROSS CLASSES USING THE BCH PROCEDURE WITH N DEGREE(S) OF FREEDOM FOR THE OVERALL TEST
- LCM: Various sections and values for Latent Class Model Selection, one row per file

The R plotting script defaults to outputting CI values, but other values are included in the code if you wish to change what's plotted.

The program can work on a single .out file or multiple .out files with different numbers of classes (preferably with the same variables).

You do not need to know or understand Lua to use parse_mplus. Windows users even have an executable they can use, under `releases`.

## Command-line arguments
Simply either call the `parse_mplus.lua` script or type in `parse_mplus.exe` on the Windows command line to get a list of all possible arguments.

## Configuration
Configuration can be done by one of two ways:

- Command-line arguments to the parse_mplus.lua script or parse_mplus.exe program. This is how you change the type of output generated, for instance.
- Configuration via the `parse_mplus.conf` file. Here you may change which columns are included in the output, what the default category is in CP and CI parsing, and remap variable categories for triumvirate variable analysis (IE, category 1 of ABC becomes DEF, category 2 of ABC becomes GHI, category 3 of ABC becomes JKL), as well as other options. See the `parse_mplus.conf` file for usage and examples.

## Windows Users
For the convenience of Windows users I have both made a compiled executable using `srlua` and handy drag-and-drop batch files that can be used instead of using the command-line. Just drag & drop either a single .out file or a folder containing multiple .out files onto the batch file. The executable `parse_mplus.exe` must be in the same directory as the batch file. Using the batch file means that any output from the program is placed where the .out files are located, instead of in the program's directory.

The batch files themselves also have configurable options.

## Example




