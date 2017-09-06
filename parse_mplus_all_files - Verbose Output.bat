@echo off
SETLOCAL EnableDelayedExpansion
REM ** Usage **
REM Loop over all .out files in current directory or given path.
REM Requires a compiled version of the parser by default.

REM You may drag-and-drop a directory to loop over .out files in that directory.
REM You may drag-and-drop a single file to parse that single file.
REM ************

REM Change this to change the name of the resulting CSV file.
REM Enter your desired filename within the quotes, after the =
REM Ex: SET "OUTPUT_FILENAME=my_filename.csv"
REM Default is blank, thus using the parser's default.
SET "OUTPUT_FILENAME=parse_mplus.csv"

REM Location of the parser executable. Defaults to current directory.
SET "PARSE_MPLUS=%~dp0\parse_mplus.exe"

REM Additional parameters to parse_mplus
SET "PARAMETERS=-v"

SET "CONSOLE_OUTPUT_FILENAME=parse_mplus_output.txt"

REM ** Start **

IF NOT EXIST "%PARSE_MPLUS%" (
	echo [%~nx0] ERROR: I can't seem to find [%PARSE_MPLUS%]
	echo [%~nx0] Aborting
	GOTO :done
)

REM If batch file itself is given a parameter (file or directory)
IF NOT "%~1"=="" (
	IF EXIST "%~1" (
		IF EXIST "%~1\" (
			REM It's a directory
			echo [%~nx0] Looking for .out files in [%~1]
			pushd "%~1"
		) ELSE (
			IF NOT "%OUTPUT_FILENAME%"=="" (
				"%PARSE_MPLUS%" "-o=%~dp1%OUTPUT_FILENAME%" %PARAMETERS% "%~1" > "%~dp1%CONSOLE_OUTPUT_FILENAME%" 2>&1
				echo [%~nx0] Outputted to [%CONSOLE_OUTPUT_FILENAME%] and [%OUTPUT_FILENAME%]
			) ELSE (
				"%PARSE_MPLUS%" %PARAMETERS% "%~1"
			)
			GOTO :done
		)
	) ELSE (
		[%~nx0] ERROR: [%~1] does not seem to exist
		GOTO :done
	)
)

REM Collect all *.out files in current directory into one string
SET _files=
FOR %%G IN (*.out) DO (
	IF [!_files!]==[] (
		SET _files="%%~fG"
	) ELSE (
		SET _files=!_files! "%%~fG"
	)
)
IF NOT [!_files!]==[] (
	IF NOT "%OUTPUT_FILENAME%"=="" (
		"%PARSE_MPLUS%" "-o=%OUTPUT_FILENAME%" %PARAMETERS% !_files! > "%CONSOLE_OUTPUT_FILENAME%" 2>&1
	) ELSE (
		"%PARSE_MPLUS%" %PARAMETERS% !_files! > "%CONSOLE_OUTPUT_FILENAME%" 2>&1
	)
	echo [%~nx0] Outputted to [%CONSOLE_OUTPUT_FILENAME%] and [%OUTPUT_FILENAME%]
) ELSE (
	echo [%~nx0] ERROR: Can't find any .out files to parse
)

:done
popd
pause