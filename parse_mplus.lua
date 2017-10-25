--[[
parse_mplus.lua

Lua script parser for Mplus output (parse_mplus)
Author: Matthew Carras
Email: matthew.carras+parsemplus AT gmail.com
Date Created: 6-29-2017
License: MIT

This script will parse a given Mplus output text file for specific keywords 
and values and generate a CSV file from it (called parse_mplus.csv). It has
a companion batch file for Windows called parse_mplus_allfiles.bat to parse 
all .out files in the current or given directory. It can also generate R
script per parsed .out file.

This source can be run directly using luaXX.exe where "XX" is the version
number of Lua. Example: lua53.exe parse_mplus.lua "filename.out"

We're going to output it in CSV notation per RFC 4180 (IETF):

First line: field_name,field_name,field_name,field_name,... CRLF
Additional lines: record row,record row,record row,record row,... CRLF

So each line after the field names are rows.

Make sure you import this CSV as an ISO-standard format such as ISO-8859-1.

Source: https://tools.ietf.org/html/rfc4180#section-2

Usage: See # Argument Definition & Parsing

## License ##
Copyright (c) 2017 Matthew Carras

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
--]]

PM_VERSION = '0.1'

-- ################################################################
-- # Static Defaults for command-line configuration
-- #
-- # All of these variables are configurable from command-line parameters.
-- #
-- # These are NOT held in "optable"

PM_flag_verbosity = 1 -- Default is not to display "DEBUG: " and other superfluous messages

-- FINAL CLASS COUNTS AND PROPORTIONS FOR THE LATENT CLASSES BASED ON THE ESTIMATED MODEL
PM_flag_get_lcp = true 

-- These flags can be mutually exclusive
PM_mux_flags = {
	["get_lcm"] = true, -- Latent Class Model Selection (multiple sections)
	["get_cp"] = true, -- RESULTS IN PROBABILITY SCALE
	["get_ci"] = true, -- CONFIDENCE INTERVALS IN PROBABILITY SCALE
	["get_r3step"] = true, -- TESTS OF CATEGORICAL LATENT VARIABLE MULTINOMIAL LOGISTIC REGRESSIONS USING THE 3-STEP PROCEDURE
	["get_bch"] = true -- EQUALITY TESTS OF MEANS ACROSS CLASSES USING THE BCH PROCEDURE WITH N DEGREE(S) OF FREEDOM FOR THE OVERALL TEST
}

-- type of output, default is CSV, other option is R or "NONE"
local flag_output_type = "CSV" -- nil also works here, defaulting to CSV

-- # End Command-line config defaults
-- ################################################################

-- ################################################################
-- # Load Local Libraries / Includes
require "./localization/localization" -- all output localization
require "./includes/patterns" -- all patterns (a few in localization)

local patterns_by_section_hash = patterns_by_section_hash
local strloc = strings_localized

if not strloc then
	print( "** ERROR loading ./localization/localization" )
	return -1
end
if not patterns_by_section_hash then
	print( "** ERROR loading ./includes/patterns" )
	return -1
end

-- ################################################################
-- # Non-Configurable Defaults
-- local locale = 'default' -- currently only option (besides en-US)

-- Parameter to check for not outputting to any file, IE -o=NONE or -type=NONE
local key_no_output = "NONE"

-- Order of CSV columns (mostly same as Mplus output)
local cptable_columns_order = { 
	"estimate",
	"s.e.",
	"est./s.e.",
	"two-tailed p-value"
}
local citable_columns_order = { 
	"lower ci bound 0.5%",
	"lower ci bound 2.5%",
	"lower ci bound 5%",
	"estimate",
	"upper ci bound 5%",
	"upper ci bound 2.5%",
	"upper ci bound 0.5%"
}
-- TODO: DEBUG: FULLY IMPLEMENT BCH ORDER
-- local bchtable_column1_order = { 
	-- "chi-sq",
	-- "two-tailed p-value"
-- }
-- local bchtable_column2_order = { 
	-- "mean",
	-- "s.e."
-- }
local r3steptable_columns_order = { 
	"estimate",
	"s.e.",
	"est./s.e.",
	"two-tailed p-value"
}
local lcmtable_columns_order = {
	"# of free parameters",
	"sample-size adjusted bic",
	"entropy",
	"lmr p value",
	"overall bp chi-sq",
	"avg. bp",
	"h0 value"
}

-- Definitions of columns from ALL tables
-- TODO: DEBUG: FULLY IMPLEMENT CUSTOM TABLES
local customtable_cols = { 
	["# of classes"] = {
		["table"] = nil, -- no specific table (use root)
		["key"] = "numofclasses"
	},
	["# of dep var"] = {
		["table"] = nil,
		["key"] = "numofdepvar"
	}
}
do 
   -- Go through each table's columns and add them to customtable_cols
   -- Note: r3steptable and bchtable can have weird relationships so 
   -- we're excluding those
	local _,col
	for _,col in ipairs(cptable_columns_order) do
		customtable_cols[ 'cp' .. col ] = {
			["table"] = "cptable",
			["key"] = col
		}
	end
	for _,col in ipairs(citable_columns_order) do
		customtable_cols[ 'ci' .. col ] = {
			["table"] = "citable",
			["key"] = col
		}
	end
	for _,col in ipairs(lcmtable_columns_order) do
		customtable_cols[ col ] = {
			["table"] = nil, -- LCM values have no specific table
			["key"] = col
		}
	end
end -- do
		
-- Abbreviations for column names in CSV
-- Localized in strings_localized (they should NOT be localized here)
local csv_column_abbrs = { 
	["# of free parameters"] = "# of param",
	["sample-size adjusted bic"] = "bic",
	["lmr p value"] = "lmr p",
	["overall bp chi-sq"] = "bp",
	["h0 value"] = "h0", -- logliklihood?
	["lower ci bound 0.5%"] = "lb 0.5%",
	["lower ci bound 2.5%"] = "lb 2.5%",
	["lower ci bound 5%"] = "lb 5%",
	["estimate"] = "est.",
	["upper ci bound 5%"] = "ub 5%",
	["upper ci bound 2.5%"] = "ub 2.5%",
	["upper ci bound 0.5%"] = "ub 0.5%",
	["two-tailed p-value"] = "p-value"
}

-- # End Non-Configurable Defaults
-- ################################################################

-- ################################################################
-- # Get this file name
-- #
-- # And set relative defaults

-- Get name of this file
local path, thisfile, thisfileext = string.match(arg[0],"(.*[\\/])([^\\/]+)(%.%w%w%w)")
if not thisfile then
	thisfile, thisfileext = string.match(arg[0],"([^\\/]+)(%.%w%w%w)")
end
if not thisfile then thisfile = 'parse_mplus' end -- should never be needed

-- Set default, can be changed with -o=filename option
-- This is the outputted CSV filename.
local outputfilename = thisfile .. ".csv"

-- Set default, can be changed with -c=filename option
-- This is the configuration filename.
local conffilename = thisfile .. ".conf"

-- Set default, can be changed with -r=filename option
-- This is the filename for the R template script used in the R output.
local rtemplatefilename = thisfile .. '_template.R'

-- # End Get this file name
-- ################################################################

-- ################################################################
-- ## Generic Functions

-- Calculate the binomal coefficient of n choose k
-- Used currently to calculate the Average BP
-- Source: http://rosettacode.org/wiki/Evaluate_binomial_coefficients#Lua
local function BinomialCoeff( n, k )
    if k > n then return nil end
    if k > n/2 then k = n - k end       --   (n k) = (n n-k)
 
    numer, denom = 1, 1
    for i = 1, k do
        numer = numer * ( n - i + 1 )
        denom = denom * i
    end
    return numer / denom
end

-- Quick function to get the length of any table (not just indexed)
local function tableLength(t)
	local length = 0
	local _
	if not t then return nil end
	for _ in pairs(t) do
		length = length + 1
	end
	return length
end -- tableLength(t)

-- Quick function to return if a table is empty or not
local function isTableEmpty(t)
	local _
	if t then
		for _ in pairs(t) do
			return false
		end
	end
	return true
end -- isTableEmpty(t)

-- ## End Generic Functions
-- ################################################################

-- ################################################################
-- ## Function: Read Configuration File
-- ## Also optable definition

--[[ Syntax
	Commments: Line starts with # or ;
	Boolean: OPTIONNAME = true or false (or T or F)
	Single value: OPTIONAME = value
	Multiple values: OPTIONNAME = value1,value2,value3,value4
	Option with one suboption (unused): OPTIONNAME suboption = value
	Option with two suboptions: OPTIONNAME suboption1,suboption2 = value
	Option names cannot have spaces.
	Values and suboptions can have spaces.
	Values cannot have commas or equal signs.
	Spaces are otherwise trimmed.
--]]

-- Contains configurable options and their defaults
-- Configure with the .conf configuration file
-- Note: Hash keys must be lowercase
local optable = {
	["csv_class_num_header"] = true, -- Show number of classes in CSV output
	["csv_section_header"] = true, -- Show section header in CSV output
	["csv_table_seperator"] = false, -- Separates tables on CSV output (given string to use for seperator)
	["cptable_default_category"] = 2, -- Default category if variable not defined using "remap varname,cat = newname"
	["citable_default_category"] = 2, -- " 			"

	["lcmtable_output_columns"] = { 
		["# of free parameters"] = true,
		["sample-size adjusted bic"] = true,
		["entropy"] = true,
		["lmr p value"] = true,
		["overall bp chi-sq"] = true,
		["avg. bp"] = true,
		["h0 value"] = true,
		["approx p-value"] = false
	},
	
	-- default: S.E.
	["cptable_output_columns"] = { 
		["estimate"] = false,
		["s.e."] = true,
		["est./s.e."] = false,
		["two-tailed p-Value"] = false
	},
	-- default: Lower CI Bound 2.5%, Estimate, Upper CI Bound 2.5%
	["citable_output_columns"] = { 
		["lower ci bound 0.5%"] = false,
		["lower ci bound 2.5%"] = true,
		["lower ci bound 5%"] = false,
		["estimate"] = true,
		["upper ci bound 5%"] = false,
		["upper ci bound 2.5%"] = true,
		["upper ci bound 0.5%"] = false
	},
	-- default: Mean, S.E., overall, overall_chi_sq, overall_p_value
	["bchtable_output_columns"] = { 
		["mean"] = true,
		["s.e."] = true,
		["overall"] = true,
		["overall_chi_sq"] = true,
		["overall_p_value"] = true,
		["classx_vs_classy"] = false,
		["classx_vs_classy_chi_sq"] = false,
		["classx_vs_classy_p_value"] = false
	},
	-- default: Estimate, S.E., Two-Tailed P-Value, #byrefclass
	["r3step_output_columns"] = {
		["estimate"] = true,
		["s.e."] = true,
		["est./s.e."] = false,
		["two-tailed p-value"] = true,
		["#byrefclass"] = true -- output one table per reference class / parameterization
	},
	-- Order of variables outputted in CSV table and R plot
	["category_output_order"] = {},
	-- remap categories of a variable to individual variable names
	-- Note: must start with "remap"
	["remap_categories"] = {}
}

-- lookup table for remapped variable names<->categories of that variable
local remap_variable_categories_lookup = {}

local function parseConfigFile( suppressWarning )
	-- If table is in here then it's an indexed table
	-- Note: For now, all suboptions are always indexed tables
	local optable_indexed_tables = {
		["category_output_order"] = true
	}

	-- prefixes and their associated table values
	local optable_option_prefixes = {
		["remap"] = { 
			["optkey"] = "remap_categories",
			["suboptions"] = 2 -- number of required suboptions
		}
	}
	
	if PM_flag_verbosity > 0 then print( "Reading config file: " .. conffilename ) end
	local f = io.open( conffilename, "r" )
	if f then
		-- Inspired by https://rosettacode.org/wiki/Read_a_configuration_file#Lua
		local line = f:read( "*line" )
		while line do -- loop over lines
			line = line:match( "%s*(.+)%s*" ) -- trim whitespace
			-- ignore lines starting with # or ; (comments)
			if line and line:sub( 1, 1 ) ~= '#' and line:sub( 1, 1 ) ~= ';' then
				-- options (and prefixes) must not have any spaces
				local option = line:match( "^([^%s=]+)[^=]*=" )
				local value  = line:match( "=%s*(%S.*)" )
				
				if option then
					-- options are always evaluated in lowercase
					option = string.lower(option)
					
					-- Check if option fits a defined prefix
					-- Ex: remap FOO,1 = BAR1
					local suboption1,suboption2 = nil,nil
					if optable_option_prefixes[ option ] then
						-- See if there are more than one suboptions
						-- Currently used for "remap"
						-- In above ex, 1 would be suboption2
						if optable_option_prefixes[ option ]["suboptions"] > 1 then
							suboption1,suboption2 = line:match( "^%S+%s+([^,]*[^,%s])%s*,%s*([^=,]*[^=,%s])%s*=" )
						else
							suboption1 = line:match( "^%S+%s+([^=]*[^=%s])%s*=" )
						end
						if not suboption1 then
							if PM_flag_verbosity > 0 then print( string.format("WARNING: Invalid or missing suboptions for option [%s] in [%s]", option, conffilename ) ) end
							option = nil -- make next sanity check fail
						else -- we have one or more suboptions
							-- Currently, suboptions are all caps
							suboption1 = string.upper(suboption1)
							suboption2 = string.upper(suboption2)
							
							-- set option var to correct key
							option = optable_option_prefixes[ option ]["optkey"]
						end -- if not suboption
					end -- if option has a prefix

					-- Check if option doesn't exist
					-- All valid options must have a default or set to false, never nil or uninitialized
					if not option or not (optable[option] or optable[option] == false) then
						if PM_flag_verbosity > 0 then print( string.format("WARNING: Invalid option [%s] in [%s]", option, conffilename ) ) end
					
					-- single value
					elseif not value then
						if PM_flag_verbosity > 0 then print( string.format("WARNING: Missing value for option [%s] in [%s]", option, conffilename ) ) end
					
					-- single value
					elseif not value:find( ',' ) then
						-- Validate values
						if type(optable[option]) == "number" then
							value = tonumber(value)
							if value == nil and PM_flag_verbosity > 0 then print( string.format("WARNING: Invalid string value [%s] for option [%s] (number expected)", value, option) ) end
						else
							-- check if boolean
							local v = value:lower()
							if v == 'true' or v == 'false' or v == 't' or v == 'f' then
								if type(optable[option]) ~= "boolean" and PM_flag_verbosity > 0 then 
									print( string.format("WARNING: Invalid boolean value [%s] for option [%s] (option does not accept boolean)", value, option) )
								else
									value = ( v == 'true' or v == 't' )
								end
							end -- if value is "true" or "false"
						end
						
						-- Assign single value
						if type(optable[option]) == "table" then
							if suboption1 then
								if suboption2 then
									-- init table, if needed
									if not optable[option][suboption1] then optable[option][suboption1] = {} end
									-- use numbered indexes whenever possible
									optable[option][suboption1][tonumber(suboption2) or suboption2] = value
								else -- only 1 suboption
									-- currently, no options use only 1 suboption
									if PM_flag_verbosity > 0 then print( string.format("WARNING: Invalid suboption format for [%s] in [%s]", option, conffilename) ) end
								end
							-- no suboption; check if option is an indexed table
							elseif optable_indexed_tables[option] then
								-- if so, reset table and set value in 1st index
								optable[option] = {
									[1] = value
								}
							else -- not an indexed table
								-- reset hash table with ONLY this value enabled
								optable[option] = {
									[ value:lower() ] = true
								}
							end
						else -- option is not a table
							optable[option] = value
						end
							
						if PM_flag_verbosity > 1 then 
							if suboption1 and suboption2 then
								print( string.format("Set Option [%s][%s][%s] = [%s]", option, suboption1, suboption2, value) )
							else
								print( string.format("Set Option [%s] = [%s]", option, value) )
							end
						end
						
					-- multiple values separated by commas
					elseif suboption1 or suboption2 then
						-- currently there are no suboptions with lists
						if PM_flag_verbosity > 0 then print( string.format("WARNING: Invalid suboption format for [%s] list in [%s]", option, conffilename) ) end
					else
						value = value .. ',' -- append , for parsing
						-- Whether this option is an indexed table or not
						local is_indexed = optable_indexed_tables[option]
						local t = {} -- new table
						-- iterate through comma-deliminated list
						local entry
						for entry in value:gmatch( "%s*([^,]*[^,%s])%s*," ) do
							if is_indexed then
								table.insert(t, entry)
							else -- if hash, lowercase then check if valid entry
								entry = string.lower(entry)
								if not ( optable[option][entry] or optable[option][entry] == false ) then
									if PM_flag_verbosity > 0 then print( string.format("WARNING: Invalid entry for [%s] list in [%s]", option, conffilename) ) end
								else
									t[ entry ] = true
								end
							end
							if PM_flag_verbosity > 1 then print( string.format("Option [%s] add entry [%s]", option, entry) ) end
						end -- for entry
						-- if we have a new, valid list then use it
						if not isTableEmpty(t) then
							optable[option] = t
						end
					end -- if valid option or single or multiple value
				end -- if option
			end -- if valid line
		
			-- Read the next line (if it exists, otherwise 'line' is nil)
			line = f:read( "*line" )
		end -- while line
		f:close() -- done with file
		
		-- This is a reverse lookup table, mainly for use with optable[ "category_output_order" ].
		-- Note that remaps are done on OUTPUT and have nothing to do with parsing.
		local remap_variable_categories = optable["remap_categories"]
		if remap_variable_categories then
			for k,t in pairs(remap_variable_categories) do
				-- t is a table
				for i,remap in pairs(t) do
					if type(remap) == "string" then
						remap_variable_categories_lookup[remap] = { ["origvar"] = k, ["cat"] = i }
					end
				end
			end
		end -- if remap_variable_categories

	elseif not suppressWarning and PM_flag_verbosity > 0 then
		print( string.format("WARNING: Cannot open config file [%s], skipping", conffilename) )
	end -- if file opens for reading OK
end -- parseConfigFile()

-- Check and load configuration from default file location, suppressing warnings if not found
parseConfigFile( true )

-- # End Configuration File Parsing
-- ################################################################


-- ################################################################
-- # Argument Definitions & Parsing

--[[
local key_nobch = 'nobch'
local key_nolcm = 'nolcm'
local key_
--]]

local argparameters = {
	{ -- Set Output filename
		["key"] = '-o="FILENAME"',
		["desc"] = "-o=filename Give a custom output filename for the resulting file (default: " .. outputfilename .. ")" ..
		"\n\t            You may use -o=" .. key_no_output .." to not generate a file at all.",
		["pattern"] = "^%-o=(.+)",
		["dofunc"] = function ( m ) -- anonymous function
						if m then
							outputfilename = m
							print( "Output set to: " .. outputfilename )
							return true
						end
					 end -- function
	},
	{ -- Set Output type (CSV or R)
		["key"] = '-type=[CSV or R]',
		["desc"] = "-type=[CSV or R] Change the output type between CSV and R Script (default: " .. string.upper(flag_output_type) .. ")" ..
		"\n\t            You may use -type=" .. key_no_output .." to not generate a file at all.",
		["pattern"] = "^%-type=(.+)",
		["dofunc"] = function ( m ) -- anonymous function
						if m then
							flag_output_type = string.upper(m)
							print( "Output type set to: " .. flag_output_type )
							return true
						end
					 end -- function
	},
	{ -- Use different configuration file
		["key"] = '-c="FILENAME"',
		["desc"] = "-c=filename Load a different configuration file (default: " .. conffilename .. ")",
		["pattern"] = "^%-c=(.+)",
		["dofunc"] = function ( m ) -- anonymous function
						if m then
							conffilename = m
							print( "Configuration file set to: " .. conffilename )
							parseConfigFile( false )
							return true
						end
					 end -- function
	},
	{ -- Set R template script filename
		["key"] = '-r="FILENAME"',
		["desc"] = "-r=filename Give a custom filename for the R template script (default: " .. rtemplatefilename .. ")",
		["pattern"] = "^%-r=(.+)",
		["dofunc"] = function ( m ) -- anonymous function
						if m then
							rtemplatefilename = m
							print( "R template script filename set to: " .. rtemplatefilename )
							return true
						end
					 end -- function
	},
	{ -- Set verbosity = 0
		["key"] = '-s',
		["desc"] = "-s\t\t Be quieter",
		["pattern"] = "^%-s$",
		["dofunc"] = function ( m )
						if m then
							PM_flag_verbosity = 0
							print( "Being mostly silent" )
							return true
						end
					 end -- function
	},
	{ -- Set verbosity = 2 (includes DEBUG messages)
		["key"] = '-v',
		["desc"] = "-v\t\t Be even more verbose, also showing DEBUG messages",
		["pattern"] = "^%-v$",
		["dofunc"] = function ( m )
						if m then
							PM_flag_verbosity = 2
							print( "Being more verbose" )
							return true
						end
					 end -- function
	},
	{ -- Do NOT parse for LCP values
		["key"] = '-nolcp',
		["desc"] = "-nolcp\t\t Do NOT parse for LCP (Latent Class Prevalence) values",
		["pattern"] = "^%-nolcp$",
		["dofunc"] = function ( m )
						if m then
							PM_flag_get_lcp = false
							print( "NOTE: NOT parsing LCP values per user request" )
							return true
						end
					 end -- function
	},
	{ -- Do NOT parse for LCM values
		["key"] = '-nolcm',
		["desc"] = "-nolcm\t\t Do NOT parse for LCM (Latent Class Model Selection) values",
		["pattern"] = "^%-nolcm$",
		["dofunc"] = function ( m )
						if m then
							PM_mux_flags["get_lcm"] = false
							if PM_flag_verbosity > 1 then
								print( "DEBUG: NOT parsing LCM values per user request" )
							end
							return true
						end
					 end -- function
	},
	{ -- Parse for ONLY BCH values
		["key"] = '-onlylcm',
		["desc"] = "-onlylcm\t Parse for ONLY LCM (Latent Class Model Selection) values",
		["pattern"] = "^%-onlylcm$",
		["dofunc"] = function ( m )
						if m then
							local flag
							for flag in pairs(PM_mux_flags) do
								if flag == "get_lcm" then
									PM_mux_flags[flag] = true
								else
									PM_mux_flags[flag] = false
								end
							end -- for PM_mux_flags
							print( "NOTE: Parsing ONLY LCM values per user request" )
							return true
						end
					 end -- function
	},
	{ -- Do NOT parse for BCH values
		["key"] = '-nobch',
		["desc"] = "-nobch\t\t Do NOT parse for BCH values",
		["pattern"] = "^%-nobch$",
		["dofunc"] = function ( m )
						if m then
							PM_mux_flags["get_bch"] = false
							if PM_flag_verbosity > 1 then
								print( "DEBUG: NOT parsing BCH values per user request" )
							end
							return true
						end
					 end -- function
	},
	{ -- Parse for ONLY BCH values
		["key"] = '-onlybch',
		["desc"] = "-onlybch\t Parse for ONLY BCH values",
		["pattern"] = "^%-onlybch$",
		["dofunc"] = function ( m )
						if m then
							local flag
							for flag in pairs(PM_mux_flags) do
								if flag == "get_bch" then
									PM_mux_flags[flag] = true
								else
									PM_mux_flags[flag] = false
								end
							end -- for PM_mux_flags
							print( "NOTE: Parsing ONLY BCH values per user request. May include LCP." )
							return true
						end
					 end -- function
	},
	{ -- Do NOT parse for R3STEP (formerly Aux Var Reg) values
		["key"] = '-nor3step',
		["desc"] = "-nor3step\t Do NOT parse for R3STEP (Auxiliary Variable Regression) values",
		["pattern"] = "^%-nor3step$",
		["dofunc"] = function ( m )
						if m then
							PM_mux_flags["get_r3step"] = false
							print( "NOTE: NOT parsing R3STEP (Auxiliary Variable Regression) values per user request" )
							return true
						end
					 end -- function
	},
	{ -- Parse for ONLY R3STEP (formerly Aux Var Reg) values
		["key"] = '-onlyr3step',
		["desc"] = "-onlyr3step\t Parse ONLY for R3STEP (Auxiliary Variable Regression) values",
		["pattern"] = "^%-onlyr3step$",
		["dofunc"] = function ( m )
						if m then
							local flag
							for flag in pairs(PM_mux_flags) do
								if flag == "get_r3step" then
									PM_mux_flags[flag] = true
								else
									PM_mux_flags[flag] = false
								end
							end -- for PM_mux_flags
							print( "NOTE: Parsing ONLY R3STEP (Auxiliary Variable Regression) values per user request. May include LCP." )
							return true
						end
					 end -- function
	},
	{ -- Do NOT parse for CP values
		["key"] = '-nocp',
		["desc"] = "-nocp\t\t Do NOT parse for CP values",
		["pattern"] = "^%-nocp$",
		["dofunc"] = function ( m )
						if m then
							PM_mux_flags["get_cp"] = false
							print( "NOTE: NOT parsing CP values per user request" )
							return true
						end
					 end -- function
	},
	{ -- Parse for ONLY CP values
		["key"] = '-onlycp',
		["desc"] = "-onlycp\t\t Parse ONLY for CP values",
		["pattern"] = "^%-onlycp$",
		["dofunc"] = function ( m )
						if m then
							local flag
							for flag in pairs(PM_mux_flags) do
								if flag == "get_cp" then
									PM_mux_flags[flag] = true
								else
									PM_mux_flags[flag] = false
								end
							end -- for PM_mux_flags
							print( "NOTE: Parsing ONLY CP values per user request. May include LCP." )
							return true
						end
					 end -- function
	},
	{ -- Do NOT parse for CI values
		["key"] = '-noci',
		["desc"] = "-noci\t\t Do NOT parse for CI values",
		["pattern"] = "^%-noci$",
		["dofunc"] = function ( m )
						if m then
							PM_mux_flags["get_ci"] = false
							print( "NOTE: NOT parsing CI values per user request" )
							return true
						end
					 end -- function
	},
	{ -- Parse for ONLY CI values
		["key"] = '-onlyci',
		["desc"] = "-onlyci\t\t Parse ONLY for CI values",
		["pattern"] = "^%-onlyci$",
		["dofunc"] = function ( m )
						if m then
							local flag
							for flag in pairs(PM_mux_flags) do
								if flag == "get_ci" then
									PM_mux_flags[flag] = true
								else
									PM_mux_flags[flag] = false
								end
							end -- for PM_mux_flags
							print( "NOTE: Parsing ONLY CI values per user request. May include LCP." )
							return true
						end
					 end -- function
	}
} -- argparameters{}				

-- Parse argument parameters given to script/program
local function parseArgument( str )
	local _,parameter
	if str then
		-- Check all parameters for matches
		for _,parameter in pairs(argparameters) do
			if parameter["dofunc"]( string.match(str, parameter["pattern"]) ) then
				return true
			end
		end -- for _,parameter
	end -- if str
	
	return false
end -- parseArgument()

-- Check arguments and print usage
if not arg[1] then
	print('\nParse one or more given Mplus output text files for specific keywords within sections,' )
	print('generating CSV tables or R script output.' )
	print('Author: Matthew Carras')
	print('Version: ' .. PM_VERSION)
	print('\nUsage:' .. ((thisfileext == ".lua" and ' lua ') or ' ') .. thisfile .. 
		 thisfileext .. '[-o="filename"] "file1.out" "file2.out" "file3.out" ...'
	)
	print('') -- empty line
	local _,parameter
	for _,parameter in pairs(argparameters) do
		 print( '\t' .. parameter["desc"] )
	end -- for argparameters
	return -- end execution
end

-- # End Argument Definition & Parsing
-- ################################################################


-- ################################################################
-- # BEGIN Main Logic & Parsing

-- NOTE: Argument checking is done earlier, before configuration parsing

-- Print all section headers, if set to max verbosity
if PM_flag_verbosity > 1 then
	print( "DEBUG: ALL SECTION HEADERS")
	for k in pairs(patterns_by_section_hash) do
		print( k )
	end
end

-- Initialize resultstable
local resultstable = {}

-- Init/declare variables used for looping
local n = 1
local i, s, f, m, m2, t, k, v, p, _
--local m2_matched
local total_num_of_classes = 0

while arg[n] do
	-- First look to see if this is a parameter and not a file (function returns true if so)
	if not parseArgument( arg[n] ) then
		-- Assume this argument is a file, so try to open it
		local file = arg[n]
		local f = io.input(file)
		if f then -- file's OK
			local previous_line = nil -- for multi-line section headers, etc.
			local cursection = nil -- current section we are parsing, IE "RESULTS IN PROBABILITY SCALE"
			local section_vars -- used with calling the parsing functions
			
			-- Initialize the resuls table for this file
			resultstable[n] = { 
				["filename"] = file
			}
			
			local line = f:read("*line")
			while line do -- loop over lines
				
				-- Check line first for new section header
				local m = string.match(line, pattern_section_header)
				if m then
					if PM_flag_verbosity > 1 then print( string.format("DEBUG: POSSIBLE SECTION [%s]", m) ) end
					-- is it a known pattern? check localization table then patterns_by_section_hash (get nil if not)
					cursection = strloc[m]
					if cursection and patterns_by_section_hash[ cursection ] then
						-- Check if multi-line header
						if patterns_by_section_hash[ cursection ]["prev"] and previous_line ~= strloc[ patterns_by_section_hash[ cursection ]["prev"] ] then
							cursection = nil -- Previous line was NOT the right line
						-- elseif patterns_by_section_hash[ cursection ]["section"] then
							-- cursection = patterns_by_section_hash[ cursection ]
						end
					end -- if cursection
					if cursection then
						-- reset section_vars
						section_vars = { ["cursection"] = cursection }
						if PM_flag_verbosity > 1 then print(string.format("DEBUG: CURRENT SECTION IS [%s]", cursection)) end
					end -- if cursection
				elseif cursection then 	-- If we are currently in a section
					
					-- Call parsing function for this section, if it exists
					if patterns_by_section_hash[ cursection ].parsefunc then
						-- function( line, rt, section_vars )
						local result_rt, result_section_vars = patterns_by_section_hash[ cursection ]:parsefunc( line, resultstable[n], section_vars )
						if result_rt ~= nil and result_section_vars ~= nil then
							resultstable[n] = result_rt
							section_vars = result_section_vars
						end -- if parsed
					end -- if parsing function exists
				end -- if cursection
				
				-- Read the next line (if it exists, otherwise 'line' is nil)
				previous_line = line -- used for multi-line section headers
				line = f:read("*line")
			end -- while line
			f:close() -- done with this file
			
			-- ** Print results to console **
			if PM_flag_verbosity > 0 then
				if PM_flag_verbosity > 1 then print('') end
				
				-- Fancy way of just calling print once, where .. is string concat
				print("************************************************" ..
				"\nFile: [" .. file .. "]" ..
				"\n************************************************")
				
				if resultstable[n]["numofclasses"] ~= nil then
					print("Number of Classes: " .. resultstable[n]["numofclasses"])
				else
					print("WARNING: Could not parse number of classes")
				end
				if resultstable[n]["numofdepvar"] ~= nil then
					print("Number of dependent variables: " .. resultstable[n]["numofdepvar"])
				else
					print("WARNING: Could not parse number of dependent variables")
				end
				print('') -- empty line
				if resultstable[n]["lcptable"] and not isTableEmpty(resultstable[n]["lcptable"]) then
					print( "SUCCESSFULLY PARSED: " .. strloc["FINAL CLASS COUNTS AND PROPORTIONS FOR THE LATENT CLASSES"] .. ' ' .. strloc["BASED ON THE ESTIMATED MODEL"])
				end
				if resultstable[n]["r3steptable"] and not isTableEmpty(resultstable[n]["r3steptable"]) then
					print( "SUCCESSFULLY PARSED: " .. patterns_by_section_hash[ "THE 3-STEP PROCEDURE" ]:getheaderstr( resultstable[n] ) )
				end
				if resultstable[n]["bchtable"] and not isTableEmpty(resultstable[n]["bchtable"]) then
					print( "SUCCESSFULLY PARSED: " .. patterns_by_section_hash[ "EQUALITY TESTS OF MEANS ACROSS CLASSES USING THE BCH PROCEDURE WITH N DEGREE(S) OF FREEDOM FOR THE OVERALL TEST" ]:getheaderstr( resultstable[n] ) )
				end
				if resultstable[n]["cptable"] and not isTableEmpty(resultstable[n]["cptable"]) then
					print( "SUCCESSFULLY PARSED: " .. strloc[ "RESULTS IN PROBABILITY SCALE" ] )
				end
				if resultstable[n]["citable"] and not isTableEmpty(resultstable[n]["citable"]) then
					print( "SUCCESSFULLY PARSED: " .. strloc[ "CONFIDENCE INTERVALS IN PROBABILITY SCALE" ] )
				end
				if resultstable[n]["# of free parameters"] ~= nil and resultstable[n]["h0 value"] ~= nil and resultstable[n]["sample-size adjusted bic"] ~= nil then
					print( "SUCCESSFULLY PARSED: " .. strloc[ "MODEL FIT INFORMATION" ] )
				end
				if resultstable[n]["entropy"] ~= nil then
					print( "SUCCESSFULLY PARSED: " .. strloc[ "CLASSIFICATION QUALITY" ] )
				end
				if resultstable[n]["overall bp chi-sq"] ~= nil then
					print( "SUCCESSFULLY PARSED: " .. strloc[ "TECHNICAL 10 OUTPUT" ] )
				end
				if resultstable[n]["lmr p-value"] ~= nil then
					print( "SUCCESSFULLY PARSED: " .. strloc[ "TECHNICAL 11 OUTPUT" ] )
				end
				if resultstable[n]["approx p-value"] ~= nil then
					print( "SUCCESSFULLY PARSED: " .. strloc[ "TECHNICAL 14 OUTPUT" ] )
				end
				print("************************************************")
			end -- if PM_flag_verbosity > 0
		else -- could not open the file for some reason
			print(string.format("** ERROR: Could not open file for parsing [%s]", file))
			return -2
		end -- end if io.input succeeds
	end -- if argument
	
	-- Next argument
	n = n + 1
end -- while arg[n]

-- ################################################################
-- 			Output

-- ################################################################
-- # Output R script for plotting

if string.upper(flag_output_type) == "R" then
	if PM_flag_verbosity > 0 then print('') end
	if PM_flag_verbosity > 1 then print("DEBUG: Making R script files\n") end
	
	-- Pre-parse to check and see if we actually have results
	local _,rt,k,t
	local haveresults = false
	for _,rt in pairs(resultstable) do
		for k,t in pairs(rt) do
			if type(t) == "table" and not isTableEmpty(t) then
				haveresults = true
			end
		end -- for k,t
	end -- for _,rt
	if not haveresults then
		print('No results parsed to make into R script. Aborting.')
		return -3 -- exit with error, though this may be by user request
	end -- if not haveresults
				
	-- CONFIDENCE INTERVALS IN PROBABILITY SCALE
	-- Print CI Results
	-- resultstable[n]["citable"][varname][class #][category #][1-7]
	for _,rt in pairs(resultstable) do
		-- Get actual filename, minus preceeding path involved and minus extension
		local filename,fileext = string.match(rt["filename"],".*[\\/]([^\\/]+)(%..*)")
		local filename_outfile,filename_only
		if not filename then
			filename = string.match(rt["filename"],".*[\\/]([^\\/]+)")
			if not filename then
				filename,fileext = string.match(rt["filename"],"([^\\/]+)(%..*)")
				if not filename then
					filename = rt["filename"]
				end
			end
		end -- if filename
		filename_outfile = filename .. fileext
		filename_only = filename
		filename = filename .. '.R'
		
		-- open file for output
		local f = io.output( filename )
		if not f then
			print( string.format("** ERROR: Could not open R output script file [%s]", filename ) )
			return -4
		end
		f:write('# Plot R script automatically generated by [' .. thisfile .. ']' .. "\n")
		f:write("\n")
		f:write( "# Mplus Output File: " .. filename_outfile .. "\n")
		f:write("\n")
		
		f:write('# NOTE: You will see some commented out code, which just gives you extra options and additional variables not used by the default logic.' .. "\n")
		f:write("\n")
		
		f:write("\n")
		f:write('# Filename without extension for outputting images' .. "\n")
		f:write( 'output_filename<-"' .. filename_only .. '"' .. "\n")
		f:write("\n")
		
		-- LCP Values
		if rt["lcptable"] then
			-- Write Section header as R comment
			f:write( '# ' .. strloc["FINAL CLASS COUNTS AND PROPORTIONS FOR THE LATENT CLASSES"] .. ' ' .. strloc["BASED ON THE ESTIMATED MODEL"] .. "\n")
			local lcp = nil
			local lcpprecision = patterns_by_section_hash["BASED ON THE ESTIMATED MODEL"]["precision"]
			local _,v
			for _,v in ipairs(rt["lcptable"]) do
				-- convert to string
				if lcp == nil then
					lcp = v
				else
					lcp = lcp .. ',' .. v
				end
			end
			if lcp then
				f:write( 'lcp<-c(' .. lcp .. ')'  .. "\n")
			else
				f:write("# ERROR PARSING LCP VALUES" .. "\n")
			end
			f:write("\n")
		end -- if rt["lcptable"]
		
		-- Number of classes for this file
		local nclass = rt["numofclasses"]
		
		f:write('# Class names for legend or title' .. "\n")
		local classnames
		for i = 1,nclass do
			if not classnames then
				classnames = '"' .. strloc["Class"] .. ' ' .. i .. '"'
			else
				classnames = classnames .. ',"' .. strloc["Class"] .. ' ' .. i .. '"'
			end
		end -- for 1,nclass
		f:write(string.format("classnames<-c(%s)",classnames) .. "\n")
		f:write("\n")
			
		f:write("# Number of classes" .. "\n" )
		f:write('nclass<-' .. nclass .. "\n")
		f:write("\n")
		
		f:write('# LEGEND TEXT - edit legend.text to edit the text of the legend' .. "\n")
		f:write('# There should be values for each class #' .. "\n")
		f:write('# This is generated automatically by using paste() on each vector member, but can be edited manually here' .. "\n")
		f:write('# Ex result: Class 1 (5.2%), Class 2 (3.2%), ...' .. "\n")
		if rt["lcptable"] then
			local lcpprecision = patterns_by_section_hash["BASED ON THE ESTIMATED MODEL"]["precision"] or 1
			f:write('# sapply() -- apply function "round()" with precision argument to each member of vector "lcp"' .. "\n")
			f:write('legend.text<-paste(classnames, "  (", sapply(lcp*100,round,' .. lcpprecision .. '), "%)", sep="")' .. "\n")
		else
			f:write('#legend.text<-paste(classnames, " ", sep="")' .. "\n")
			f:write('legend.text<-classnames' .. "\n")
		end
		f:write("\n")
		
		if rt["cptable"] or rt["citable"] then
			local nvar
			local varlist = rt["citable"]["#vars_in_orig_order"]
			if not isTableEmpty( optable[ "category_output_order" ] ) then
				f:write( "# Re-ordering variables based on given category_output_order\n" .. "\n")
				varlist = optable[ "category_output_order" ]
			end
			if not isTableEmpty( varlist ) then
				nvar = #varlist
			
				f:write("# Number of variables" .. "\n")
				f:write("# NOTE: nvar here does not apply to BCH or R3STEP variables\n")
				f:write('nvar<-' .. nvar .. "\n")
				f:write("\n")
				
				local i,var,variables
				for i,var in pairs(varlist) do 
					-- save list of variables formatted as strings
					-- format is quoted to be used in other languages
					if not variables then 
						variables = '"' .. var .. '"'
					else
						variables = variables .. ',"' .. var .. '"'
					end
				end -- for varlist
				f:write("# Labels for X axis (variable names)\n")
				if variables then
					f:write( "varlab<-c(" .. variables .. ')' .. "\n")
				else
					f:write( "# ** WARNING: No variables parsed!" .. "\n")
				end
				f:write("\n")
				
				if rt["citable"] then
					-- Write Section header as R comment
					f:write('# ' .. strloc[ "CONFIDENCE INTERVALS IN PROBABILITY SCALE" ]  .. "\n")
					f:write("\n")
						
					-- Comment out (in R code) matrixes we aren't using
					local output_matrixes = {
						{
							["name"] = "ciestimates",
							["flag"] = "estimate"
						},
						{
							["name"] = "cilower2p5",
							["flag"] = "lower ci bound 2.5%"
						},
						{
							["name"] = "ciupper2p5",
							["flag"] = "upper ci bound 2.5%"
						},
						{
							["name"] = "cilower0p5",
							["flag"] = "lower ci bound 0.5%"
						},
						{
							["name"] = "ciupper0p5",
							["flag"] = "upper ci bound 0.5%"
						},
						{
							["name"] = "cilower5p0",
							["flag"] = "lower ci bound 5%"
						},
						{
							["name"] = "ciupper5p0",
							["flag"] = "upper ci bound 5%"
						}
					} -- output_matrixes{}
					
					f:write("# CI Matrixes\n")
					f:write("# Construct matixes with all data of nvar x nclass\n")
					f:write("# Ex: a_matrix[1,1] would be the value for variable 1, class 1\n")
					f:write("# Also set rownames (varlab) and colnames (classnames) for easy index and output\n")
					local class
					local allvalues = {} -- allvalues strings, nvar x nclass, hashed by output_matrixes
					for class = 1,nclass do
						local i,var
						for i,var in pairs(varlist) do 
							local cat,catvalue
							-- Check to see if we need to remap this variable
							-- remap_variable_categories_lookup[remap] = { ["origvar"] = k, ["cat"] = i }
							if remap_variable_categories_lookup[var] then
								cat = remap_variable_categories_lookup[var]["cat"]
								var = remap_variable_categories_lookup[var]["origvar"]
							-- Check to see if we're doing anything else special with this variable
							elseif optable["remap_categories"][var] then
								-- Shouldn't get here
								f:write( '# ERROR in variable remap lookup for [' .. var .. ']\n' )
							else
								cat = optable[ "citable_default_category" ]
							end
							
							catvalue = rt["citable"][var][class][cat]
							local _,t
							for _,t in ipairs(output_matrixes) do
								local v = catvalue[ t["flag"] ]
								if not allvalues[ t["name"] ] then
									allvalues[ t["name"] ] = v
								else
									allvalues[ t["name"] ] = allvalues[ t["name"] ] .. ',' .. v
								end
							end -- for output_matrixes
						end -- for varlist
					end -- for nclass
					
					local _,v
					for _,v in ipairs(output_matrixes) do
						local matrix_line = string.format("%s_matrix<-matrix(nrow=nvar,ncol=nclass,dimnames=list(varlab,classnames),data=c(%s))\n", v["name"], allvalues[ v["name"] ] )
						if optable[ "citable_output_columns" ][ v["flag"] ] then
							f:write( matrix_line )
						else
							-- write it, but comment it out by default
							f:write( '#' .. matrix_line )
						end
					end -- for output_matrixes
					f:write('\n')
				end -- if rt["citable"] then
				
				if rt["cptable"] then
					-- Write Section header as R comment
					f:write('# ' .. strloc[ "RESULTS IN PROBABILITY SCALE" ]  .. "\n")
					f:write("\n")
						
					-- Comment out (in R code) matrixes we aren't using
					local output_matrixes = {
						{
							["name"] = "cpestimates",
							["flag"] = "estimate"
						},
						{
							["name"] = "cpse",
							["flag"] = "s.e."
						},
						{
							["name"] = "cpestse",
							["flag"] = "est./s.e."
						},
						{
							["name"] = "cppvalue",
							["flag"] = "two-tailed p-value"
						}
					} -- output_matrixes{}
					
					f:write("# CP Matrixes\n")
					f:write("# Construct matixes with all data of nvar x nclass\n")
					f:write("# Ex: a_matrix[1,1] would be the value for variable 1, class 1\n")
					f:write("# Also set rownames (varlab) and colnames (classnames) for easy index and output\n")
					local class
					local allvalues = {} -- allvalues strings, nvar x nclass, hashed by output_matrixes
					for class = 1,nclass do
						local i,var
						for i,var in pairs(varlist) do 
							local cat,catvalue
							-- Check to see if we need to remap this variable
							-- remap_variable_categories_lookup[remap] = { ["origvar"] = k, ["cat"] = i }
							if remap_variable_categories_lookup[var] then
								cat = remap_variable_categories_lookup[var]["cat"]
								var = remap_variable_categories_lookup[var]["origvar"]
							-- Check to see if we're doing anything else special with this variable
							elseif optable["remap_categories"][var] then
								-- Shouldn't get here
								f:write( '# ERROR in variable remap lookup for [' .. var .. ']\n' )
							else
								cat = optable[ "cptable_default_category" ]
							end
							
							catvalue = rt["cptable"][var][class][cat]
							local _,t
							for _,t in ipairs(output_matrixes) do
								local v = catvalue[ t["flag"] ]
								if not allvalues[ t["name"] ] then
									allvalues[ t["name"] ] = v
								else
									allvalues[ t["name"] ] = allvalues[ t["name"] ] .. ',' .. v
								end
							end -- for output_matrixes
						end -- for varlist
					end -- for nclass
					
					local _,v
					for _,v in ipairs(output_matrixes) do
						local matrix_line = string.format("%s_matrix<-matrix(nrow=nvar,ncol=nclass,dimnames=list(varlab,classnames),data=c(%s))\n", v["name"], allvalues[ v["name"] ] )
						if optable[ "cptable_output_columns" ][ v["flag"] ] then
							f:write( matrix_line )
						else
							-- write it, but comment it out by default
							f:write( '#' .. matrix_line )
						end
					end -- for output_matrixes
					f:write('\n')
				end -- if rt["cptable"]
			end -- if not isTableEmpty(varlist)
		end -- if rt["cptable"] or rt["citable"]
		
		if rt["bchtable"] then
			-- Write Section header as R comment
			f:write( '# ' .. patterns_by_section_hash[ "EQUALITY TESTS OF MEANS ACROSS CLASSES USING THE BCH PROCEDURE WITH N DEGREE(S) OF FREEDOM FOR THE OVERALL TEST" ]:getheaderstr( rt ) .. "\n")
			
			-- local optable[ "bchtable_output_columns" ] = { 
				-- ["Mean"] = true,
				-- ["S.E."] = true,
				-- ["overall"] = true,
				-- ["overall_chi_sq"] = true,
				-- ["overall_p_value"] = true,
				-- ["classx_vs_classy"] = false,
				-- ["classx_vs_classy_chi_sq"] = false,
				-- ["classx_vs_classy_p_value"] = false
			-- }
			
			-- Comment out (in R code) matrixes we aren't using
			local output_matrixes = {
				{
					["name"] = "bchmean",
					["flag"] = "mean",
					["parentkey"] = "classes",
					["key"] = "mean"
				},
				{
					["name"] = "bchse",
					["flag"] = "s.e.",
					["parentkey"] = "classes",
					["key"] = "s.e."
				}
			} -- output_matrixes{}
			-- Overall values (not per class)
			local output_vectors = {
				{
					["name"] = "bchoverall_chi_sq",
					["flag"] = "overall_chi_sq",
					["parentkey"] = "overall",
					["key"] = "chi-sq"
				},
				{
					["name"] = "bchoverall_p_value",
					["flag"] = "overall_p_value",
					["parentkey"] = "overall",
					["key"] = "p-value"
				}
			} -- output_vectors{}
			
			local varlist = rt["bchtable"]["#vars_in_orig_order"]
			
			if not isTableEmpty(varlist) then
				f:write("\n")
				f:write('bch_nvar<-' .. #varlist .. "\n")
			
				local i,var,variables
				for i,var in pairs(varlist) do 
					-- save list of variables formatted as strings
					-- format is quoted to be used in other languages
					if not variables then 
						variables = '"' .. var .. '"'
					else
						variables = variables .. ',"' .. var .. '"'
					end
				end -- for varlist
				f:write("\n")
				f:write("# BCH variable names\n")
				if variables then
					f:write( "bch_varlab<-c(" .. variables .. ')' .. "\n")
				else
					f:write( "# ** WARNING: No variables parsed!" .. "\n")
				end
				f:write("\n")
			
				f:write("# BCH Matrixes and Vectors\n")
				f:write("# Construct matixes with all data of nvar x nclass\n")
				f:write("# Ex: a_matrix[1,1] would be the value for variable 1, class 1\n")
				f:write("# Also set rownames (varlab) and colnames (classnames) for easy index and output\n")
				f:write("# Vectors are used where values are not per class (IE, Overall)\n")

				-- First, write out matrixes
				local class
				local allvalues = {} -- allvalues strings, nvar x nclass, hashed by output_matrixes
				for class = 1,nclass do
					local i,var
					for i,var in pairs(varlist) do 
						-- resultstable[n]["bchtable"][varname]["classes"][class #] OR resultstable[n]["bchtable"][varname]["overall"]
						local _,t
						for _,t in ipairs(output_matrixes) do
							local value = nil
							if t["parentkey"] == "classes" then
								value = rt["bchtable"][var]["classes"][class]
							end
							if value ~= nil then
								local v = value[ t["key"] ]
								if not values[ t["name"] ] then
									allvalues[ t["name"] ] = v
								else
									allvalues[ t["name"] ] = allvalues[ t["name"] ] .. ',' .. v
								end
							end -- if value
						end -- for output_matrixes
					end -- for varlist
				end -- for nclass
				
				local _,v
				for _,v in ipairs(output_matrixes) do
					local matrix_line = string.format("%s_matrix<-matrix(nrow=bch_nvar,ncol=nclass,dimnames=list(bch_varlab,classnames),data=c(%s))\n", v["name"], allvalues[ v["name"] ] )
					if optable[ "bchtable_output_columns" ][ v["flag"] ] then
						f:write( matrix_line )
					else
						-- write it, but comment it out by default
						f:write( '#' .. matrix_line )
					end
				end -- for output_matrixes
				
				-- Next, write out vectors (Overall, etc.)
				local vector_values = {}
				for i,var in pairs(varlist) do 
					-- Assign values from current variable to R vector
					-- Overall values
					for _,t in ipairs(output_vectors) do
						local v = nil
						if t["parentkey"] then
							v = rt["bchtable"][var][ t["parentkey"] ][ t["key"] ]
						end
						if v ~= nil then
							if not vector_values[ t["name"] ] then
								vector_values[ t["name"] ] = v
							else
								vector_values[ t["name"] ] = vector_values[ t["name"] ] .. ',' .. v
							end
						end
					end -- for output_vectors
				end -- for varlist
				
				-- Finally, assign the vector values
				if not isTableEmpty(vector_values) then
					f:write('\n')
					f:write("# The BCH overall values are vectors indexed by variable\n")
					f:write("# a_vector[1] would be the value for the 1st variable according to order in varlab (bch_varlab)\n")
					for _,v in ipairs(output_vectors) do
						local vector_line = string.format("%s_vector<-c(%s)\n", v["name"], vector_values[ v["name"] ])
						if optable[ "bchtable_output_columns" ][ v["flag"] ] then
							f:write( vector_line )
						else -- write it, but comment it out
							f:write( '#' .. vector_line )
						end
					end -- for output_vectors
				end -- if not isTableEmpty(vector_values)
			end -- if not isTableEmpty(varlist)
			f:write('\n')
		end -- if rt["bchtable"]

		if rt["r3steptable"] then
			-- Write Section header as R comment
			f:write( '# ' .. patterns_by_section_hash[ "THE 3-STEP PROCEDURE" ]:getheaderstr( rt ) .. "\n" )
			f:write("\n")
			f:write("# ** NOT IMPLEMENTED **" .. "\n")
			
			-- local optable[ "r3step_output_columns" ] = { 
				-- ["Estimate"] = true,
				-- ["S.E."] = true,
				-- ["Est./S.E."] = false,
				-- ["Two-Tailed P-Value"] = true,
				-- ["#byrefclass"] = true -- output one table per reference class / parameterization
			-- }	
		end
		
		-- ** Rest of plotting code			
		f:write('# SETUP PLOT PARAMETERS' .. "\n")
		
		-- Code required for parse_mplus_template.R 
		-- Needs: colors, ylabel, and xlabel defined
		do 
			local line = "colors<-c(1"
			local c
			for i = 2,nclass do
				c = i
				if i > 4 then -- skip light cyan
					c = c + 1
				end
				line = line .. ',' .. c
			end
			line = line .. ')'
			f:write('# Line colors, skipping light cyan if nclass > 4' .. "\n")
			f:write(line .. "\n")
			f:write('# All black line colors, for testing what it may look like in B&W publication (commented out by default)' .. "\n")
			f:write('#colors<-rep(1,nclass)' .. "\n")
			f:write("\n")
		end -- do
		
		f:write( '# Default x and y axis labels for CI matrixes' .. "\n" )
		f:write( string.format('xlabel<-"%s"' .. "\n", strloc["Latent class indicator"]) )
		f:write( string.format('ylabel<-"%s"' .. "\n", strloc["Conditional probability"]) )
		f:write("\n")
			
		-- Read in parse_mplus_template.R to string, then output to file
		local infile = io.input( rtemplatefilename )
		if infile then -- io success
			-- read in file to string
			local instr = infile:read("*a")
			if instr then
				f:write( instr ) -- write template script to our output file
			else
				f:write( string.format("# WARNING: R template script [%s] appears to be blank\n", rtemplatefilename ) )
			end
			infile:close()
		else
			print( string.format("** WARNING: Could not open R template script [%s]", rtemplatefilename ) )
			f:write( string.format("# WARNING: Could not open R template script [%s]\n", rtemplatefilename ) )
			-- Non fatal error (do not exit prematurely)
		end
			
		f:write('# Done auto-generated script' .. "\n")
		f:close()
		print( string.format("R script written to [%s]", filename) )
	end -- for resultstable

-- # End Output R Script
-- ################################################################

-- ################################################################
-- # Output CSV tables

else -- flag_output_type
	if PM_flag_verbosity > 0 then print('') end
	if PM_flag_verbosity > 1 then print("DEBUG: Making CSV file\n") end

	-- If -o=NONE given then don't output a CSV file
	if string.upper(outputfilename) == key_no_output then
		print('Not making file per user request')
		return -- exit
	end

	-- Pre-parse to check and see if we actually have results
	local _,rt,k,t
	local haveresults = false
	for _,rt in pairs(resultstable) do
		for k,t in pairs(rt) do
			-- Skip these three results as they won't be written to CSV by themselves
			if type(t) == "table" and not isTableEmpty(t) then
				haveresults = true
			end
		end -- for k,t
	end -- for _,rt
	if not haveresults then
		print('No results parsed to make into CSV table. Aborting.')
		return -5 -- exit with error, though this may be by user request
	end -- if not haveresults

	-- open CSV file for output
	local f = io.output( outputfilename )
	if not f then
		print(string.format("** ERROR: Could not open CSV output file [%s]", outputfilename))
		return -6
	end
	
	-- ## Locally Defined Functions ##
	
	-- Function for making a single Class + LCP string
	-- Used separately with just R3STEP (formerly Aux Var Reg) for now
	-- line - Current string we're adding to
	-- class - class #
	-- lcptable - table with LCP values per class
	function makeClassColumnString( line, class, lcptable )
		if not line then line = '' end
		-- Add final count table to output (if avail), ex: Class 1, 5.1%
		if lcptable and lcptable[class] then
			local lcpprecision = patterns_by_section_hash["BASED ON THE ESTIMATED MODEL"]["precision"]
			local lcp = string.format('%.' .. lcpprecision .. 'f%%', lcptable[class] * 100)
			line = line .. ',"' .. strloc["Class"] .. ' ' .. class .. ', ' .. lcp .. '"'
		else
			line = line .. ',' .. strloc["Class"] .. ' ' .. class
		end
		return line
	end -- function makeClassHeaderLineString( line, class, lcptable )
	
	-- Function for making a header string with Classes including LCP
	-- Make header such as "Class 1, 5.6%", etc. for each class
	-- rt - results table
	-- blankcols - Number of blank columns after Class #
	local function makeClassHeaderString( rt, blankcols )
		if not rt then return nil end -- sanity check
		local line
		if optable[ "csv_class_num_header" ] then
			-- Add the # of classes to header
			line = string.format(strloc["csv_class_num_header_format"], rt["numofclasses"])
		else
			line = ''
		end
		-- Add Classes (and LCP, if parsed) to header
		local class
		for class = 1,rt["numofclasses"] do
			if blankcols and class > 1 then
				local i
				for i = 1,blankcols do
					line = line .. ','
				end
			end -- if blankcols and class > 1
			line = makeClassColumnString(line, class, rt["lcptable"])
		end -- for rt["numofclasses"]
		return line
	end -- function makeClassHeaderString( rt )
	
	-- Split string to fit into multiple columns
	local function splitStringIntoMultiCol( str )
		return '"' .. str:gsub(' ', '","') .. '"'
	end -- function splitStringIntoMultiCol( str )
	
	-- Returns a list of keys IF entries resolve to 'true', in order given
	local function makeCSVCols( t, order )
		local colstrs = nil
		local numcols = nil
		local _,k

		-- sanity check
		if not t or not order then 
			print( "ERROR" )
			return 
		end
		
		for _,k in ipairs(order) do
			if t[k] then -- also checks if value is true
				local colstr = strloc[ csv_column_abbrs[ k ] or k ]
				if not colstrs then 
					colstrs = colstr
					numcols = 1
				else
					colstrs = colstrs .. ',' .. colstr
					numcols = numcols + 1
				end
			end
		end

		return colstrs,numcols
	end -- makeCSVCols()

	-- Write Categorical section (CP, CI, etc.) values to given file handle
	--function writeCategorySection(f,rt,outputtable,ordertable,)
	--end
	
	local _,rt
	local tables_written = 0
	
	-- Do LCM (Latent Class Model Selection) table, which is formatted a bit differently as
	-- each is just a single value per file (instead of per class per file)
	if PM_mux_flags["get_lcm"] then
		local line
		local header_string = strloc[ "Latent Class Model Selection" ]
		
		local colstr,numcols = makeCSVCols( optable["lcmtable_output_columns"], lcmtable_columns_order )
		
		print( "Writing table for " .. header_string .. " using [" .. colstr .. "]" )
		
		-- Start with header of what type of table this is, columns of 6 characters each
		if optable[ "csv_section_header" ] then
			line = splitStringIntoMultiCol( header_string )
			f:write( line .. '\n')
		end
		
		-- Start with # of classes for column names
		line = strloc[ "# of classes" ] .. ',' .. colstr
		f:write( line .. "\n")
				
		-- Write out values for Latent Class Model Selection
		local v
		for _,rt in pairs(resultstable) do
			if rt["numofclasses"] then
				-- Write values, starting with # of classes
				line = rt["numofclasses"]
				for _,col in ipairs(lcmtable_columns_order) do
					if optable[ "lcmtable_output_columns" ][ col ] then
						-- Avg. BP must be calculated
						if col == 'avg. bp' and rt[ 'overall bp chi-sq' ] ~= nil and rt[ 'numofdepvar' ] then
							-- Avg. BP = BPvalue/"num of dep var" choose 2
							v = rt[ 'overall bp chi-sq' ] / BinomialCoeff( rt[ 'numofdepvar' ], 2 )
						-- n/a or not parsed
						elseif rt[ col ] == nil then
							v = strloc[ "n/a" ]
						else
							v = rt[ col ]
						end
						line = line .. ',' .. v
					end
				end -- for lcmtable_columns_order
				f:write( line .. "\n")
			end -- if rt["numofclasses"]
		end
		f:write('\n') -- empty line to separate tables
		tables_written = tables_written + 1
	end -- if get_lcm (Latent Class Model Selection)
			
	-- loop over each table from each file (may be in any order)
	for _,rt in pairs(resultstable) do
		local line
		if rt["numofclasses"] then
			-- Write BCH Table results, if parsed
			if rt["bchtable"] then
				local section_header_string = patterns_by_section_hash[ "EQUALITY TESTS OF MEANS ACROSS CLASSES USING THE BCH PROCEDURE WITH N DEGREE(S) OF FREEDOM FOR THE OVERALL TEST" ]:getheaderstr( rt )
				
				-- TODO: DEBUG: Implement customizing BCH table
				
				-- local colstr,numcols = 
				
				line = 'Writing Table for ' .. section_header_string .. ' using [ '
				line = line .. strloc["mean"] .. ',' .. strloc["s.e."]
				line = line .. ' ]'
				print( line ) 
				
				-- Start with header of what type of table this is, columns of 6 characters each
				if optable[ "csv_section_header" ] then
					line = splitStringIntoMultiCol( section_header_string )
					f:write( line .. '\n')
				end
				
				-- Make header such as "Class 1, 5.6%", etc. for each class
				line = makeClassHeaderString( rt, 1 ) -- call previous declared function
				-- Add extra blank column if Class > 1
				if rt["numofclasses"] > 1 then
					line = line .. ','
				end
				-- Add Chi-Sq and P-Value to headers
				line = line .. ',' .. strloc["chi-sq"] .. ',' .. strloc["p-value"]
				f:write(line .. '\n') -- write the 1st line of field names
				
				-- Write 2nd line of field names (Mean, S.E.)
				line = '' -- First column is blank
				for i = 1,rt["numofclasses"] do
					line = line .. ',' .. strloc["mean"] .. ',' .. strloc["s.e."]
				end -- for rt["numofclasses"]
				f:write(line.. '\n') -- write the 2nd line of field names
				
				-- Output results of BCH parsing
				-- resultstable[n]["bchtable"][varname]["classes"][class] OR resultstable[n]["bchtable"][varname]["overall"]
				local _,var,t,class,values
				for _,var in ipairs(rt["bchtable"]["#vars_in_orig_order"]) do 
					local t = rt["bchtable"][var] -- t is a table
					line = var -- Start with the variable (key) name
					if not isTableEmpty(t) then -- DEBUG: skip empty tables
						-- Print out results per classes
						for class,values in ipairs(t["classes"]) do
							line = line .. ',' .. values["mean"] .. ',' .. values["s.e."]
						end -- for class
						-- Print out overall results (Chi-Sq & P-Value)
						line = line .. ',' .. t["overall"]["chi-sq"] .. ',' .. t["overall"]["p-value"]
						
						f:write(line .. '\n') -- write line of values
					end -- if not isTableEmpty(t)
				end -- for var,t
				if optable[ "csv_table_seperator" ] then
					f:write( optable[ "csv_table_seperator" ] .. '\n' )
				end
				f:write('\n') -- empty line to separate tables
				tables_written = tables_written + 1
			end -- if rt["bchtable"]
			
			-- Write R3STEP (formerly Aux Var Reg) Table results, if parsed
			if rt["r3steptable"] then
				local section_header_string = patterns_by_section_hash[ "THE 3-STEP PROCEDURE" ]:getheaderstr( resultstable[n] )
				
				local colstr,numcols = makeCSVCols( optable["r3step_output_columns"], r3steptable_columns_order )
				
				line = 'Writing Table for ' .. section_header_string .. ' using [ ' .. colstr .. ' ]'
				if optable["r3step_output_columns"]["#byrefclass"] then
					line = line .. ' for each reference class'
				end
				print( line )
			
				-- Start with header of what type of table this is, columns of 6 characters each
				if optable[ "csv_section_header" ] then
					line = splitStringIntoMultiCol( section_header_string )
					f:write( line .. '\n')
				end
				
				local _,var,vars,refclass,class,values,i,v
				if not optable["r3step_output_columns"]["#byrefclass"] then 
					print("** NOT IMPLEMENTED **")
					-- TODO: DEBUG: Not implemented yet
				else
					-- Loop over by reference class parameterization
					for refclass,vars in ipairs(rt["r3steptable"]["#byrefclass"]) do
						line = string.format( strloc["*Ref Class %d*"], refclass )
						-- Write the header(s) first
						-- Add Classes (and LCP, if parsed) to header
						local count = 0
						for class = 1,rt["numofclasses"] do
							-- Skip reference class, as it will not be in output
							if class ~= refclass then
								-- add empty columns if count > 0 to separate classes
								if count > 0 then
									line = line .. ',,'
								end
								-- Add final count table to output (if avail), ex: Class 1, 5.1%
								line = makeClassColumnString( line, class, rt["lcptable"] )
								count = count + 1
							end -- if class ~= refclass
						end -- for rt["numofclasses"]
						f:write(line .. '\n') -- write the 1st line of field names
						
						-- Write 2nd line of field names (Est., S.E., P-Value by default)
						-- But only if there are more than 2 columns
						if numcols > 1 then
							line = '' -- First column is blank (variable names)
							for class = 1,rt["numofclasses"] do
								if class ~= refclass then
									line = line .. ',' .. colstr
								end
							end -- for rt["numofclasses"]
							f:write(line.. '\n') -- write the 2nd line of field names
						end
					
						-- Loop in original variable order
						for _,var in ipairs(rt["r3steptable"]["#vars_in_orig_order"]) do 
							line = var
							-- Print out results per reference class
							for class,values in pairs(vars[var]) do
								for _,col in ipairs(r3steptable_columns_order) do
									v = values[ col ]
									if v ~= nil and optable[ "r3step_output_columns" ][ col ] then
										line = line .. ',' .. v
									end
								end -- for col
							end -- for class,values
							f:write(line .. '\n') -- write line of values
						end -- for rt["r3steptable"]["#vars_in_orig_order"]
						if optable[ "csv_table_seperator" ] then
							f:write( optable[ "csv_table_seperator" ] .. '\n' )
						end
						f:write('\n') -- empty line to separate tables
						tables_written = tables_written + 1
					end -- for rt["r3steptable"]["#byrefclass"]
				end -- if by reference class
			end -- if rt["r3steptable"]
			
			-- Write CP Table results, if parsed
			if rt["cptable"] then
				local section_header_string = strloc[ "RESULTS IN PROBABILITY SCALE" ]
				
				local colstr,numcols = makeCSVCols( optable["cptable_output_columns"], cptable_columns_order )
				
				line = 'Writing Table for ' .. section_header_string .. ' using [ ' .. colstr .. ' ]'
				print( line ) 
				
				-- Start with header of what type of table this is, columns of 6 characters each
				if optable[ "csv_section_header" ] then
					line = splitStringIntoMultiCol( section_header_string )
					f:write( line .. '\n')
				end
				
				-- Make header such as "Class 1, 5.6%", etc. for each class
				f:write( makeClassHeaderString( rt ) .. '\n' ) -- write 1st line of field names
				
				-- Write 2nd line of field names
				-- But only if there are more than 2 columns
				-- (Default is only S.E. so this shouldn't be written)
				if numcols and numcols > 1 then
					line = '' -- First column is blank (variable names)
					for class = 1,rt["numofclasses"] do
						line = line .. ',' .. colstr
					end -- for rt["numofclasses"]
					f:write(line.. '\n') -- write the 2nd line of field names
				end
						
				-- Set variable list based on whether we have a set order or original order
				local varlist = rt["cptable"]["#vars_in_orig_order"]
				if not isTableEmpty( optable[ "category_output_order" ] ) then
					print( "Re-ordering variables based on given category_output_order" )
					varlist = optable[ "category_output_order" ]
				end
				
				-- Loop through variable list
				local i,var,variables,cat,class,v,catvalues,col
				for i,var in pairs(varlist) do 
					line = var -- start line with variable name
					
					-- Check to see if we need to remap this variable
					-- remap_variable_categories_lookup[remap] = { ["origvar"] = k, ["cat"] = i }
					if remap_variable_categories_lookup[var] then
						cat = remap_variable_categories_lookup[var]["cat"]
						var = remap_variable_categories_lookup[var]["origvar"]
					-- Check to see if we're doing anything else special with this variable
					elseif optable["remap_categories"][var] then
						-- Shouldn't get here
						print( '** Error in variable remap lookup for ' .. var )
					else
						cat = optable[ "cptable_default_category" ]
					end
				
					for class = 1,rt["numofclasses"] do
						-- resultstable[n]["cptable"][varname][class #][category #][value name]
						-- Varname, S.E. by default
						catvalues = rt["cptable"][var][class][cat]
						for _,col in ipairs( cptable_columns_order ) do
							v = catvalues[ col ]
							if v ~= nil and optable[ "cptable_output_columns" ][ col ] then
								line = line .. ',' .. v
							end
						end -- for col
					end
					f:write(line .. '\n') -- Write line of values
				end -- for varlist
				if optable[ "csv_table_seperator" ] then
					f:write( optable[ "csv_table_seperator" ] .. '\n' )
				end
				f:write('\n') -- empty line to separate tables
				tables_written = tables_written + 1
			end -- if rt["cptable"]
			
			-- Write CI Table results, if parsed
			if rt["citable"] then
				local section_header_string = strloc[ "CONFIDENCE INTERVALS IN PROBABILITY SCALE" ]
				
				local colstr,numcols = makeCSVCols( optable["citable_output_columns"], citable_columns_order )
				line = 'Writing Table for ' .. section_header_string .. ' using [ ' .. colstr .. ' ]'
				print( line ) 
				
				-- Start with header of what type of table this is, columns of 6 characters each
				if optable[ "csv_section_header" ] then
					line = splitStringIntoMultiCol( section_header_string )
					f:write( line .. '\n')
				end
				
				-- Write the headers first
				if optable[ "csv_class_num_header" ] then
					-- Add the # of classes to header
					line = string.format(strloc["csv_class_num_header_format"], rt["numofclasses"])
				else
					line = ''
				end
				-- Add Classes (and LCP, if parsed) to header
				-- Make header such as "Class 1, 5.6%", etc. for each class
				local count = 0
				for class = 1,rt["numofclasses"] do
					-- add empty columns if count > 0 to separate classes
					if count > 0 then
						line = line .. ',,'
					end
					-- Add final count table to output (if avail), ex: Class 1, 5.1%
					line = makeClassColumnString( line, class, rt["lcptable"] )
					count = count + 1
				end -- for rt["numofclasses"]
				f:write(line.. '\n') -- write the 1st line of field names
				
				-- Write 2nd line of field names (LB 2.5%, Est., UB 2.5% by default)
				-- But only if there are more than 2 columns
				if numcols > 1 then
					line = '' -- First column is blank (variable names)
					for class = 1,rt["numofclasses"] do
						line = line .. ',' .. colstr
					end -- for rt["numofclasses"]
					f:write(line.. '\n') -- write the 2nd line of field names
				end
				
				-- Set variable list based on whether we have a set order or original order
				local varlist = rt["citable"]["#vars_in_orig_order"]
				if not isTableEmpty( optable[ "category_output_order" ] ) then
					print( "Re-ordering variables based on given category_output_order" )
					varlist = optable[ "category_output_order" ]
				end
				
				-- Loop through variable list
				local i,var,variables,cat,class,v,catvalues,col
				for i,var in pairs(varlist) do 
					line = var -- start line with variable name
					
					-- Check to see if we need to remap this variable
					-- remap_variable_categories_lookup[remap] = { ["origvar"] = k, ["cat"] = i }
					if remap_variable_categories_lookup[var] then
						cat = remap_variable_categories_lookup[var]["cat"]
						var = remap_variable_categories_lookup[var]["origvar"]
					-- Check to see if we're doing anything else special with this variable
					elseif optable["remap_categories"][var] then
						-- Shouldn't get here
						print( '** Error in variable remap lookup for ' .. var )
					else
						cat = optable[ "citable_default_category" ]
					end
				
					for class = 1,rt["numofclasses"] do
						-- resultstable[n]["citable"][varname][class #][category #][value name]
						catvalues = rt["citable"][var][class][cat]
						-- Varname, LB 2.5%, Est., UB 2.5% by default
						for _,col in ipairs(citable_columns_order) do
							v = catvalues[ col ]
							if v ~= nil and optable[ "citable_output_columns" ][ col ] then
								line = line .. ',' .. v
							end
						end -- for col
					end
					f:write(line .. '\n') -- Write line of values
				end -- for varlist
				if optable[ "csv_table_seperator" ] then
					f:write( optable[ "csv_table_seperator" ] .. '\n' )
				end
				f:write('\n') -- empty line to separate tables
				tables_written = tables_written + 1
			end -- if rt["citable"]
		end -- if rt["numofclasses"]
	end -- end for loop
			
	f:close()
	print("Tables written: " .. tables_written)
	print("Output CSV file: [" .. outputfilename .. "]")
end -- if output type is CSV or R

-- # End Output
-- ################################################################

-- End file