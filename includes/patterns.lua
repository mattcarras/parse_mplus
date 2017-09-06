-- ################################################################
-- # parse_mplus Pattern Definitions
-- #
-- #(See "Localized Strings" for localized patterns)

-- Globals defined here: patterns_by_section_hash

require "../localization/localization"
local strloc = strings_localized -- global from localization.lua
local flag_verbosity = flag_verbosity -- global from main file (parse_mplus.lua)

-- Returns a keyset for table t
-- Used at bottom
local function keySet(t)
	local keyset={}
	local k

	for k in pairs(t) do
		table.insert(keyset, k)
	end

	return keyset
end -- keySet()
	
-- These are generic patterns used by multiple sections in Mplus output
-- Keys are NOT from Mplus output
local generic_patterns = {
	-- CP and CI
	["CATEGORICAL_SECTIONS"] = {
		["patterns"] = {
			["class"] = "Latent Class (%d+)", -- current latent class #
			["varname"] = "%s+(%u+)$" -- variable names always all uppercase
		}
	}
} -- generic_patterns{}

-- Header text separating sections and the patterns used within them
-- Keys are localized in strings_localized
-- Multi-line headers have a ["prev"] to include the localized previous line.
-- Section headers with ["strformat"] will be duplicated to include patterns up to n=10, Ex: "THE %d-STEP PROCEDURE" becomes "THE 1-STEP PROCEDURE", "THE 2-STEP PROCEDURE" ... "THE 10-STEP PROCEDURE"
patterns_by_section_hash = {
	-- INPUT INSTRUCTIONS
	-- Values: # of Classes
	[ "INPUT INSTRUCTIONS" ] = { 
		["patterns"] = {
			["numofclasses"] = "[cC]lasses[%s=]+[^(]*%((%d+)%)[%s;]*"
		}
	},
	-- SUMMARY OF ANALYSIS
	-- Values: # of dependent variables
	[ "SUMMARY OF ANALYSIS" ] = { 
		["patterns"] = {
			["numofdepvar"] = "Number of dependent variables%s+([%d-.]+)"
		}
	},
	-- FINAL CLASS COUNTS AND PROPORTIONS FOR THE LATENT CLASSES
	-- BASED ON THE ESTIMATED MODEL
	-- Values: LCP (Latent Class Prevalence)
	-- Note: multi-line section header
	[ "BASED ON THE ESTIMATED MODEL" ] = {
		["prev"] = "FINAL CLASS COUNTS AND PROPORTIONS FOR THE LATENT CLASSES", -- 1st (previous) line
		["patterns"] = {
			-- Example: Class #	 N					LCP Value (%)
			-- 			1        397.48405          0.05054
			["lcpvalues"] = "(%d+)%s+[%d.-]+%s+([%d.-]+)"
		},
		["precision"] = 1 -- precision of LCP value
	},
	-- RESULTS IN PROBABILITY SCALE
	-- Values: CP (Class Probability)
	[ "RESULTS IN PROBABILITY SCALE" ] = {
		["patterns"] = {
			-- NOTE: Patterns for class and varname are found in generic_patterns{}
			
			-- Latent class values for each category (we only need the 1st value)
			--	   Category #      	  Estimate   S.E.  		Est./S.E.  Two-Tailed P-Value
			-- Ex: Category 1         0.490      0.049      9.951      0.000
			-- local pattern_probscale_category = "Category (%d+)%s+([%d.-]+)"
			["catvalues"] = "Category%s+(%d+)%s+([%d.-]+)%s+([%d.-]+)%s+([%d.-]+)%s+([%d.-]+)"
		}
	},
	-- CONFIDENCE INTERVALS IN PROBABILITY SCALE
	-- Values: CI
	[ "CONFIDENCE INTERVALS IN PROBABILITY SCALE" ] = {
		["patterns"] = {
		-- NOTE: Patterns for class and varname are found in generic_patterns{}
		
		-- Latent class values for each category. Example with notation:
		-- 					Lower .5%   Lower 2.5%  Lower 5%    Estimate    Upper 5%    Upper 2.5%  Upper .5%
		--								Lower CI*				Data Point*				Upper Bound*
		-- Category 1       0.363       0.394       0.409       0.490       0.571       0.587       0.617
		-- Note: For R script output we are using Estimate as main Data Point, then Upper Bound and Lower Bound. We just need these three lines for each variable in the plot, default just 2nd category.
			["catvalues"] = "Category%s+(%d+)%s+([%d.-]+)%s+([%d.-]+)%s+([%d.-]+)%s+([%d.-]+)%s+([%d.-]+)%s+([%d.-]+)%s+([%d.-]+)"
		}
	},
	-- TESTS OF CATEGORICAL LATENT VARIABLE MULTINOMIAL LOGISTIC REGRESSIONS USING
	-- THE 3-STEP PROCEDURE
	-- Values: R3STEP (formely Aux Var Reg)
	-- Note: multi-line section header, 2nd line should always be "THE 3-STEP PROCEDURE"
	-- ["TESTS OF CATEGORICAL LATENT VARIABLE MULTINOMIAL LOGISTIC REGRESSIONS USING THE N-STEP PROCEDURE"] = {
	[ "THE 3-STEP PROCEDURE" ] = {
		["prev"] = "TESTS OF CATEGORICAL LATENT VARIABLE MULTINOMIAL LOGISTIC REGRESSIONS USING",
		-- ["strformat"] = "THE %d-STEP PROCEDURE", -- (not needed for R3STEP)
		["patterns"] = {
			["class"] = "%s+C#(%d+)%s+ON", -- latent class #
			["parameterization"] = "Parameterization using Reference Class (%d+)", -- if using parameterization
			--  Example:         Varname       	  Estimate    S.E.  	Est./S.E.   Two-Tailed P-Value
			--  				 AGE              -0.100      0.075     -1.331      0.183
			-- Note: Estimate also known as "beta"
			["values"] = "%s+(%u+)%s+([%d.-]+)%s+([%d.-]+)%s+([%d.-]+)%s+([%d.-]+)",
			-- Intercepts values
			["intercepts"] = "%s+Intercepts",
			["intercepts_values"] = "%s+C#(%d+)%s+([%d.-]+)%s+([%d.-]+)%s+([%d.-]+)%s+([%d.-]+)",
		}
	},
	-- EQUALITY TESTS OF MEANS ACROSS CLASSES USING THE BCH PROCEDURE
	-- WITH N DEGREE(S) OF FREEDOM FOR THE OVERALL TEST
	-- Values: BCH
	-- Note: multi-line section header, 2nd line has a varying number
	["EQUALITY TESTS OF MEANS ACROSS CLASSES USING THE BCH PROCEDURE WITH N DEGREE(S) OF FREEDOM FOR THE OVERALL TEST"] = { 
		["prev"] = "EQUALITY TESTS OF MEANS ACROSS CLASSES USING THE BCH PROCEDURE",
		["strformat"] = "WITH %d DEGREE(S) OF FREEDOM FOR THE OVERALL TEST", -- create 10 versions of this header
		["patterns"] = {
			-- Unfortunately BCH varnames are top level! Probably an oversight by MPLUS devs. But afaik all section headers contain spaces while variable names cannot.
			["varname"] = "^(%u+)$",
			-- NOTE: Above 3 classes will result in two columns
			-- Example:       C#              Mean        S.E.         C#              Mean        S.E.
			--   		Class 1               15.745      0.046  Class 2               15.708      0.029
			["mean_se_values_2col"] = "%s+Class%s+(%d+)%s+([%d.-]+)%s+([%d.-]+)%s+Class%s+(%d+)%s+([%d.-]+)%s+([%d.-]+)",
			-- Example: 			 		  Chi-Square  P-Value 	  CX     CY		  	Chi-Square P-Value
			--			Overall test          20.327      0.000  Class 1 vs. 2          0.769      0.380
			["chi_p_overall_values_2col"] = "%s+Overall test%s+([%d.-]+)%s+([%d.-]+)%s+Class (%d+) vs%. (%d+)%s+([%d.-]+)%s+([%d.-]+)",
			-- Example:		 CX     CY		   Chi-Square P-Value	  CX     CY		    Chi-Square P-Value
			--			Class 1 vs. 3          0.593      0.441  Class 1 vs. 4          4.782      0.029
			["chi_p_classx_vs_classy_values_2col"] = "%s+Class (%d+) vs%. (%d+)%s+([%d.-]+)%s+([%d.-]+)%s+Class (%d+) vs%. (%d+)%s+([%d.-]+)%s+([%d.-]+)",
			-- NOTE: 3 or below will result in one column
			-- Example:		  C#		  	  Mean		  S.E.
			-- 			Class 1               15.691      0.025
			["mean_se_values"] = "%s+Class%s+(%d+)%s+([%d.-]+)%s+([%d.-]+)",
			-- Example: 			 		  Chi-Square  P-Value
			-- 			Overall test          23.072      0.000
			["chi_p_overall_values"] = "%s+Overall test%s+([%d.-]+)%s+([%d.-]+)",
			-- Example:		 CX     CY		  Chi-Square  P-Value
			-- 			Class 1 vs. 2         23.014      0.000
			["chi_p_classx_vs_classy_values"] = "%s+Class (%d+) vs%. (%d+)%s+([%d.-]+)%s+([%d.-]+)"
		}
	},
	-- CLASSIFICATION QUALITY
	-- Values: Entropy (BLRT?) (for Latent Class Model Selection)
	-- Latent Class Model Selection: "This table provides information about model fit and class structure that can be used to decide which model to choose for analysis--such as number of free parameters, BIC, etc."
	[ "CLASSIFICATION QUALITY" ] = {
		["patterns"] = {
			["entropy"] = "Entropy%s+([%d-.]+)"
		}
	},
	-- MODEL FIT INFORMATION
	-- Note: This is a section, not a subsection
	-- Values: # of free parameters, BIC, H0 Value (LL), etc. (BLRT?) (for Latent Class Model Selection)
	[ "MODEL FIT INFORMATION" ] = { 
		["patterns"] = {
			["# of free parameters"] = "Number of Free Parameters%s+([%d-.]+)",
			["h0 value"] = "H0 Value%s+([%d-.]+)",
			["sample-size adjusted bic"] = "Sample%-Size Adjusted BIC%s+([%d-.]+)"
		}
	},
	-- TECHNICAL 10 OUTPUT
	-- Values: BP (for Avg BP, using BinomialCoeff( n, k ) function) (for Latent Class Model Selection)
	[ "TECHNICAL 10 OUTPUT" ] = {
		["patterns"] = {
			-- Found under BIVARIATE MODEL FIT INFORMATION in TECH 10
			["overall bp chi-sq"] = "Overall Bivariate Pearson Chi%-Square%s+([%d-.]+)"
		}
	},
	-- TECHNICAL 11 OUTPUT
	-- Values: LMR, P-Value (for Latent Class Model Selection)
	[ "TECHNICAL 11 OUTPUT" ] = {
		["patterns"] = {
			["LMR subheader"] = "LO%-MENDELL%-RUBIN ADJUSTED LRT TEST",
			["lmr p-value"] = "P%-Value%s+([%d-.]+)"
		}
	},
	-- TECHNICAL 14 OUTPUT
	-- Values: Approximate P Value (BLRT?) (for Latent Class Model Selection)
	[ "TECHNICAL 14 OUTPUT" ] = {
		["patterns"] = {
			["approx p-value"] = "Approximate P%-Value%s+([%d-.]+)"
		}
	}
} -- patterns_by_section_hash{}
local patterns_by_section_hash = patterns_by_section_hash

-- Section headers will always be uppercase with no preceeding spaces, may contain numbers and a few symbols
pattern_section_header = "^(%u+%s+[%u%s%d-()]+)$"

-- Table which maps table names to hashes of patterns_by_section_hash
--[[
local tablename_to_pattern_hash = {
	["lcptable"] = patterns_by_section_hash[ "BASED ON THE ESTIMATED MODEL" ],
	["cptable"] = patterns_by_section_hash[ "RESULTS IN PROBABILITY SCALE" ],
	["citable"] = patterns_by_section_hash[ "CONFIDENCE INTERVALS IN PROBABILITY SCALE" ],
	["r3steptable"] = patterns_by_section_hash[ "THE 3-STEP PROCEDURE" ],
	["bchtable"] = patterns_by_section_hash[ "EQUALITY TESTS OF MEANS ACROSS CLASSES USING THE BCH PROCEDURE WITH N DEGREE(S) OF FREEDOM FOR THE OVERALL TEST" ]
}
--]]

-- ################################################################
-- # Pattern Parsing Functions

-- Little function useful for sections with patterns that only have 1 value
-- NOTE that the value is saved in rt with the same key that the pattern uses
function getFromSingleCapturePatterns( section_table, line, rt, section_vars )
	local patterns = section_table["patterns"]
	local k,pat
	for k,pat in pairs(patterns) do
		if not rt[ k ] then
			local m = string.match(line, pat)
			m = tonumber(m)
			if m ~= nil then
				rt[ k ] = m
				if flag_verbosity > 1 then print(string.format("DEBUG: PARSE VALUE: %s = %f", k, m)) end
					
				return rt, section_vars
			end -- if match
		end -- if not rt[ k ]
	end -- for pairs(patterns)
end -- getFromSingleCapturePatterns()

-- Set certain sections to use the generic getFromSingleCapturePatterns() function
patterns_by_section_hash["INPUT INSTRUCTIONS"].parsefunc = getFromSingleCapturePatterns
patterns_by_section_hash["SUMMARY OF ANALYSIS"].parsefunc = getFromSingleCapturePatterns
patterns_by_section_hash["CLASSIFICATION QUALITY"].parsefunc = getFromSingleCapturePatterns
patterns_by_section_hash["MODEL FIT INFORMATION"].parsefunc = getFromSingleCapturePatterns
patterns_by_section_hash["TECHNICAL 10 OUTPUT"].parsefunc = getFromSingleCapturePatterns
patterns_by_section_hash["TECHNICAL 14 OUTPUT"].parsefunc = getFromSingleCapturePatterns

-- GENERIC section member parsing function
-- SYNTATIC SUGAR FUNCTION (self passed)
local sectiont = generic_patterns["CATEGORICAL_SECTIONS"]
function sectiont:parsefunc( line, rt, section_vars )
	local patterns = self["patterns"]
	local curclass = section_vars["curclass"]
	
	-- These sections are split up by latent class, then variable, then category #
	-- Look first for "Latent Class #"
	local m = string.match(line, patterns["class"])
	m = tonumber(m)
	if m then
		section_vars["curclass"] = m -- Set class iterator (current latent class #)
		section_vars["curvar"] = nil -- reset current variable
		if flag_verbosity > 1 then print("DEBUG: CURRENT LATENT CLASS: " .. section_vars["curclass"]) end
		
		return rt, section_vars
	elseif curclass then -- only look for variables when inside a latent class section
		-- Look for variable names
		local m = string.match(line, patterns["varname"])
		if m then
			section_vars["curvar"] = m -- set current variable
			if flag_verbosity > 1 then print("DEBUG: CURRENT LATENT CLASS VARIABLE: " .. section_vars["curvar"]) end
			
			return rt, section_vars
		end -- if patterns["varname"] matches
	end -- if curclass
end -- generic_patterns["CATEGORICAL_SECTIONS"]:parsefunc()

-- Section member parsing function
-- SYNTATIC SUGAR FUNCTION (self passed)
sectiont = patterns_by_section_hash["BASED ON THE ESTIMATED MODEL"]
function sectiont:parsefunc( line, rt, section_vars )
	local patterns = self["patterns"]
	
	-- Check to see if we should be parsing this section
	if flag_get_lcp == false then return end
	
	-- Look for LCP values
	local m,m2 = string.match(line, patterns["lcpvalues"])
	 m = tonumber(m)  -- class #
	m2 = tonumber(m2) -- lcp value
	if m ~= nil and m2 ~= nil then
		-- Initialize table if needed
		if not rt["lcptable"] then rt["lcptable"] = {} end
		rt["lcptable"][m] = m2
		if flag_verbosity > 1 then print(string.format("DEBUG: PARSE LCP VALUES: %d, %f", m, m2)) end
		
		return rt, section_vars
	end -- if patterns["lcpvalues"] matches
end -- patterns_by_section_hash["INPUT INSTRUCTIONS"]:parsefunc()

-- Section member parsing function
-- SYNTATIC SUGAR FUNCTION (self passed)
sectiont = patterns_by_section_hash["RESULTS IN PROBABILITY SCALE"]
function sectiont:parsefunc( line, rt, section_vars )
	local patterns = self["patterns"]
	local curclass = section_vars["curclass"]
	local curvar = section_vars["curvar"]
	
	-- Check to see if we should be parsing this section
	if mux_flags["get_cp"] == false then return end

	-- First parse for class or varname
	local result_rt, result_section_vars = generic_patterns["CATEGORICAL_SECTIONS"]:parsefunc( line, rt, section_vars )
	if result_rt ~= nil and result_section_vars ~= nil then
		-- successful parse, so return
		return rt, section_vars
	-- If we are working with a variable then look for category values
	elseif curclass and curvar then
		local m, m2, m3, m4, m5 = string.match(line, patterns["catvalues"])
		 --	   Category #      	  Estimate   S.E.  		Est./S.E.  Two-Tailed P-Value
		 m = tonumber(m)  -- Category #
		m2 = tonumber(m2) -- Estimate
		m3 = tonumber(m3) -- S.E. **
		m4 = tonumber(m4) -- Est./S.E.
		m5 = tonumber(m5) -- Two-Tailed P-Value
		if m ~= nil and m2 ~= nil and m3 ~= nil and m4 ~= nil and m5 ~= nil then
			if flag_verbosity > 1 then print( string.format("DEBUG: PARSE CP CATEGORY VALUES: %d,%f* %f %f %f", m, m2, m3, m4, m5)) end
			-- Initialize tables if needed
			if not rt["cptable"] then rt["cptable"] = { ["#vars_in_orig_order"] = {} } end
			if not rt["cptable"][curvar] then 
				table.insert(rt["cptable"]["#vars_in_orig_order"], curvar) -- save original variable order
				rt["cptable"][curvar] = {} 
			end
			if not rt["cptable"][curvar][curclass] then rt["cptable"][curvar][curclass] = {} end
			-- Save result in results table
			rt["cptable"][curvar][curclass][m] = {
				["estimate"] = m2,
				["s.e."] = m3,
				["est./s.e."] = m4,
				["two-tailed p-value"] = m5
			}
			
			return rt, section_vars
		end -- if patterns["catvalues"] matches
	end -- if curclass and curvar
end -- patterns_by_section_hash["RESULTS IN PROBABILITY SCALE"]:parsefunc()

-- Section member parsing function
-- SYNTATIC SUGAR FUNCTION (self passed)
sectiont = patterns_by_section_hash["CONFIDENCE INTERVALS IN PROBABILITY SCALE"]
function sectiont:parsefunc( line, rt, section_vars )
	local patterns = self["patterns"]
	local curclass = section_vars["curclass"]
	local curvar = section_vars["curvar"]
	
	-- Check to see if we should be parsing this section
	if mux_flags["get_ci"] == false then return end

	-- First parse for class or varname
	local result_rt, result_section_vars = generic_patterns["CATEGORICAL_SECTIONS"]:parsefunc( line, rt, section_vars )
	if result_rt ~= nil and result_section_vars ~= nil then
		-- successful parse, so return
		return rt, section_vars
	-- If we are working with a variable then look for category values
	elseif curclass and curvar then
		local m, m2, m3, m4, m5, m6, m7, m8 = string.match(line, patterns["catvalues"])
		m = tonumber(m) -- category #
		m2 = tonumber(m2) -- Lower CI Bound 0.5%
		m3 = tonumber(m3) -- Lower CI Bound 2.5% **
		m4 = tonumber(m4) -- Lower CI Bound 5% 
		m5 = tonumber(m5) -- Estimate **
		m6 = tonumber(m6) -- Upper CI Bound 5%
		m7 = tonumber(m7) -- Upper CI Bound 2.5% **
		m8 = tonumber(m8) -- Upper CI Bound 0.5%
		if m ~= nil and m2 ~= nil and m3 ~= nil and m4 ~= nil and m5 ~= nil and m6 ~= nil and m7 ~= nil and m8 ~= nil then
			if flag_verbosity > 1 then print( string.format("DEBUG: PARSE CI CATEGORY VALUES: %d,%f %f* %f %f* %f %f* %f", m, m2, m3, m4, m5, m6, m7, m8)) end
			-- Initialize tables if needed
			if not rt["citable"] then rt["citable"] = { ["#vars_in_orig_order"] = {} } end
			if not rt["citable"][curvar] then 
				table.insert(rt["citable"]["#vars_in_orig_order"], curvar) -- save original variable order
				rt["citable"][curvar] = {} 
			end
			if not rt["citable"][curvar][curclass] then rt["citable"][curvar][curclass] = {} end
			-- Save result in results table
			rt["citable"][curvar][curclass][m] = {
				["lower ci bound 0.5%"] = m2,
				["lower ci bound 2.5%"] = m3,
				["lower ci bound 5%"] = m4,
				["estimate"] = m5,
				["upper ci bound 5%"] = m6,
				["upper ci bound 2.5%"] = m7,
				["upper ci bound 0.5%"] = m8
			}
			
			return rt, section_vars
		end -- if patterns["catvalues"] matches
	end -- if curclass and curvar
end -- patterns_by_section_hash["CONFIDENCE INTERVALS IN PROBABILITY SCALE"]:parsefunc()

-- Section member parsing function
-- SYNTATIC SUGAR FUNCTION (self passed)
sectiont = patterns_by_section_hash[ "THE 3-STEP PROCEDURE" ] -- R3STEP
function sectiont:parsefunc( line, rt, section_vars )
	local patterns = self["patterns"]
	local curpar = section_vars["curpar"]
	local curclass = section_vars["curclass"]
	
	-- Check to see if we should be parsing this section
	if mux_flags["get_r3step"] == false then return end

	local m = string.match(line, patterns["parameterization"])
	m = tonumber(m)
	if m then
		section_vars["curpar"] = m -- set current class parameterization
		section_vars["curclass"] = nil -- reset class iterator
		if flag_verbosity > 1 then print("DEBUG: CURRENT R3STEP PARAMETERIZATION: " .. section_vars["curpar"]) end
		
		return rt, section_vars
	else -- next check for class
		local m = string.match(line, patterns["class"])
		m = tonumber(m)
		if m then
			section_vars["curclass"] = m -- Set class iterator (current latent class #)
			if flag_verbosity > 1 then print("DEBUG: CURRENT R3STEP CLASS: " .. section_vars["curclass"]) end
			
			return rt, section_vars
		elseif curclass then -- only look for values when inside a latent class section
			-- Varname       	  Estimate    S.E.  	Est./S.E.   Two-Tailed P-Value
			local m, m2, m3, m4, m5 = string.match(line, patterns["values"])
			m2 = tonumber(m2) -- Estimate/Beta*
			m3 = tonumber(m3) -- S.E.*
			m4 = tonumber(m4) -- Est./S.E.
			m5 = tonumber(m5) -- Two-Tailed P-Value*
			if m ~= nil and m2 ~= nil and m3 ~= nil and m4 ~= nil and m5 ~= nil then
				local var = m
				if flag_verbosity > 1 then print( string.format("DEBUG: PARSE R3STEP (formely Aux Var Reg) VALUES: %s=Est %f* S.E. %f* E/SE %f P %f*", var, m2, m3, m4, m5)) end
				local par = curpar
				if not par then -- no parameterization
					-- assume Reference Class = Total Num Of Classes
					par = rt["numofclasses"]
				end
				-- Initialize table if needed
				if not rt["r3steptable"] then rt["r3steptable"] = { ["#n"] = self["n"], ["#vars_in_orig_order"] = {} } end
				-- Initialize then make sure we save original variable order
				if not rt["r3steptable"][var] then
					rt["r3steptable"][var] = {}
					table.insert(rt["r3steptable"]["#vars_in_orig_order"], var)
				end
				if not rt["r3steptable"][var][par] then rt["r3steptable"][var][par] = {} end
				-- Save result in results table
				rt["r3steptable"][var][par][curclass] = {
					["estimate"] = m2,
					["s.e."] = m3,
					["est./s.e."] = m4,
					["two-tailed p-value"] = m5
				}
				-- Also save it referencing class # instead of by variable
				if not rt["r3steptable"]["#byrefclass"] then rt["r3steptable"]["#byrefclass"] = {} end
				if not rt["r3steptable"]["#byrefclass"][par] then rt["r3steptable"]["#byrefclass"][par] = {} end
				if not rt["r3steptable"]["#byrefclass"][par][var] then rt["r3steptable"]["#byrefclass"][par][var] = {} end
				rt["r3steptable"]["#byrefclass"][par][var][curclass] = rt["r3steptable"][var][par][curclass]
				
				return rt, section_vars
			end -- if pattern_r3step_values matches
		end -- if pattern_r3step_class matches
	end -- if pattern_r3step_parameterization matches
end -- patterns_by_section_hash["THE 3-STEP PROCEDURE"]:parsefunc()

-- Section member parsing function
-- SYNTATIC SUGAR FUNCTION (self passed)
sectiont = patterns_by_section_hash["EQUALITY TESTS OF MEANS ACROSS CLASSES USING THE BCH PROCEDURE WITH N DEGREE(S) OF FREEDOM FOR THE OVERALL TEST"]
function sectiont:parsefunc( line, rt, section_vars )
	local patterns = self["patterns"]
	local curvar = section_vars["curvar"]
	
	-- Check to see if we should be parsing this section
	if mux_flags["get_bch"] == false then return end

	-- split first by varname, with NO spaces before it
	local m = string.match(line, patterns["varname"])
	if m then
		curvar = m
		section_vars["curvar"] = curvar
		if flag_verbosity > 1 then print("DEBUG: CURRENT BCH VARNAME: " .. curvar) end
		-- Initialize tables if needed
		if not rt["bchtable"] then rt["bchtable"] = { ["#n"] = self["n"], ["#vars_in_orig_order"] = {} } end
		-- Initialize and make sure we save original variable order
		if not rt["bchtable"][curvar] then
			rt["bchtable"][curvar] = {}
			table.insert(rt["bchtable"]["#vars_in_orig_order"], curvar)
		end
		
		return rt, section_vars
	elseif curvar then -- only look for values when inside a variable section
		local cols = 0 -- how many columns of data we have
		-- First check if we are dealing with multi-column
		local m,m2,m3,m4,m5,m6 = string.match(line, patterns["mean_se_values_2col"])
		 m = tonumber(m)  -- Class #*
		m2 = tonumber(m2) -- Mean*
		m3 = tonumber(m3) -- S.E.*
		m4 = tonumber(m4) -- Class #* (2nd Column)
		m5 = tonumber(m5) -- Mean* (2nd Column)
		m6 = tonumber(m6) -- S.E.* (2nd Column)
		if m ~= nil and m2 ~= nil and m3 ~= nil and m4 ~= nil and m5 ~= nil and m6 ~= nil then
			-- we have two columns of data
			cols = 2
		else -- try single column
			-- Class #		  	Mean		  S.E.
			m, m2, m3 = string.match(line, patterns["mean_se_values"])
			 m = tonumber(m)  -- Class #*
			m2 = tonumber(m2) -- Mean*
			m3 = tonumber(m3) -- S.E.*
			if m ~= nil and m2 ~= nil and m3 ~= nil then
				-- one column of data
				cols = 1
			end
		end -- if pattern matches for two or one columns
		if cols > 0 then
			if flag_verbosity > 1 then 
				print( string.format("DEBUG: PARSE BCH VALUES: %d, Mean %f* S.E. %f*", m, m2, m3))
				if cols > 1 then
					print( string.format("DEBUG: PARSE BCH VALUES 2nd Column: %d, Mean %f* S.E. %f*", m4, m5, m6))
				end
			end -- if flag_verbosity > 1
			-- Initialize table, if needed
			if not rt["bchtable"][curvar]["classes"] then rt["bchtable"][curvar]["classes"] = {} end
			-- Save result in results table
			rt["bchtable"][curvar]["classes"][m] = {
				["mean"] = m2,
				["s.e."] = m3
			}
			-- if we have 2nd column of data
			if cols > 1 then
				rt["bchtable"][curvar]["classes"][m4] = {
					["mean"] = m5,
					["s.e."] = m6
				}
			end -- if cols > 1
			
			return rt, section_vars
		else -- Look for "Overall test"
			local cols = 0 -- how many columns of data we have
			-- First, try two column
			local m,m2,m3,m4,m5,m6 = string.match(line, patterns["chi_p_overall_values_2col"])
			 m = tonumber(m)  -- Chi-Squared (Overall)*
			m2 = tonumber(m2) -- P-Value (Overall)*
			m3 = tonumber(m3) -- Class #X (2nd Column)
			m4 = tonumber(m4) -- Class #Y (2nd Column)
			m5 = tonumber(m5) -- Chi-Squared (2nd Column)
			m6 = tonumber(m6) -- P-Value (2nd Column)
			if m ~= nil and m2 ~= nil and m3 ~= nil and m4 ~= nil and m5 ~= nil and m6 ~= nil then
				-- we have two columns of data
				cols = 2
			else -- try single column
				-- Chi-Square  P-Value
				m, m2 = string.match(line, patterns["chi_p_overall_values"])
				 m = tonumber(m)  -- Chi-Squared (Overall)*
				m2 = tonumber(m2) -- P-Value (Overall)*
				if m ~= nil and m2 ~= nil then
					-- one column of data
					cols = 1
				end
			end -- if pattern matches for two or one columns
			if cols > 0 then
				if flag_verbosity > 1 then 
					print( string.format("DEBUG: PARSE BCH VALUES: Overall Test is Chi-Sq %f* P %f*", m, m2))
					if cols > 1 then
						print( string.format("DEBUG: PARSE BCH VALUES 2nd Column: Class %d vs. %d Chi-Sq %f* P %f*", m3, m4, m5, m6))
					end -- if cols > 1
				end -- if flag_verbosity > 1
				-- Save result in results table
				rt["bchtable"][curvar]["overall"] = {
					["chi-sq"] = m,
					["p-value"] = m2
				}
				-- if we have 2nd column of data
				if cols > 1 then
					if not rt["bchtable"][curvar]["classx_vs_y"] then
						rt["bchtable"][curvar]["classx_vs_y"] = {}
					end
					-- Insert result in results table
					local t = {
							["classx"] = m3,
							["classy"] = m4,
							["chi-sq"] = m5,
							["p-value"] = m6
					}
					table.insert(rt["bchtable"][curvar]["classx_vs_y"], t)
				end -- if cols > 1
				
				return rt, section_vars
			else -- Finally, look for Class X vs. Y
				local cols = 0 -- how many columns of data we have
				-- First look for two column format
				local m, m2,m3,m4,m5,m6,m7,m8 = string.match(line, patterns["chi_p_classx_vs_classy_values_2col"])
				 m = tonumber(m)  -- Class #X
				m2 = tonumber(m2) -- Class #Y
				m3 = tonumber(m3) -- Chi-Squared
				m4 = tonumber(m4) -- P-Value
				m5 = tonumber(m5) -- Class #X (2nd column)
				m6 = tonumber(m6) -- Class #Y (2nd column)
				m7 = tonumber(m7) -- Chi-Squared (2nd column)
				m8 = tonumber(m8) -- P-Value (2nd column)
				if m ~= nil and m2 ~= nil and m3 ~= nil and m4 ~= nil and m5 ~= nil and m6 ~= nil and m7 ~= nil and m8 ~= nil then
					cols = 2
				else -- single column format
					m, m2,m3,m4 = string.match(line, patterns["chi_p_classx_vs_classy_values"])
					 m = tonumber(m)  -- Class #X
					m2 = tonumber(m2) -- Class #Y
					m3 = tonumber(m3) -- Chi-Squared
					m4 = tonumber(m4) -- P-Value
					if m ~= nil and m2 ~= nil and m3 ~= nil and m4 ~= nil then
						-- one column of data
						cols = 1
					end
				end -- if pattern matches for two or one columns
				if cols > 0 then
					if flag_verbosity > 1 then 
						print( string.format("DEBUG: PARSE BCH VALUES: Class %d vs. %d Chi-Sq %f* P %f*", m, m2, m3, m4)) 
						if cols > 1 then
							print( string.format("DEBUG: PARSE BCH VALUES 2nd Column: Class %d vs. %d Chi-Sq %f* P %f*", m5, m6, m7, m8))
						end -- if cols > 1
					end -- if flag_verbosity > 1
					if not rt["bchtable"][curvar]["classx_vs_y"] then
						rt["bchtable"][curvar]["classx_vs_y"] = {}
					end
					-- Insert result in results table
					local t = {
							["classx"] = m,
							["classy"] = m2,
							["chi-sq"] = m3,
							["p-value"] = m4
					}
					table.insert(rt["bchtable"][curvar]["classx_vs_y"], t)
					-- if we have 2nd column of data
					if cols > 1 then
						t = {
								["classx"] = m5,
								["classy"] = m6,
								["chi-sq"] = m7,
								["p-value"] = m8
						}
						table.insert(rt["bchtable"][curvar]["classx_vs_y"], t)
					end -- if cols > 1
					
					return rt, section_vars
				end -- if cols > 0
			end -- looking for "Class X vs Y"
		end -- looking for "Overall Test" (and possibly "Class X vs Y"
	end -- if curvar
end --  patterns_by_section_hash["EQUALITY TESTS OF MEANS ACROSS CLASSES USING THE BCH PROCEDURE WITH N DEGREE(S) OF FREEDOM FOR THE OVERALL TEST"]:parsefunc()

-- Section member parsing function
-- SYNTATIC SUGAR FUNCTION (self passed)
sectiont = patterns_by_section_hash["TECHNICAL 11 OUTPUT"]
function sectiont:parsefunc( line, rt, section_vars )
	local patterns = self["patterns"]
	
	-- First look for LMR subheader
	if string.match(line, patterns["LMR subheader"]) then
		section_vars["LMR subheader found"] = true
		
		return rt, section_vars
	elseif section_vars["LMR subheader found"] then
		-- We've found the LMR subheader, so check for the desired P-Value
		if not rt[ "LMR P Value" ] then
			local m = string.match(line, patterns["lmr p-value"])
			m = tonumber(m)
			if m ~= nil then
				rt[ "lmr p-value" ] = m
				
				return rt, section_vars
			end -- if patterns["P-Value"] matches
		end -- if not rt[ "LMR P Value" ]
	end -- if we found or are in LMR subsection
end -- patterns_by_section_hash["TECHNICAL 11 OUTPUT"]:parsefunc()

-- Section header output functions
-- SYNTATIC SUGAR FUNCTION (self passed)
sectiont = patterns_by_section_hash["THE 3-STEP PROCEDURE"]
function sectiont:getheaderstr( rt )
	if not rt or not rt["r3steptable"] then return '**HEADER STRING ERROR**' end

	return strloc[ self["prev"] ] .. ' ' .. strloc[ "THE 3-STEP PROCEDURE" ]
end

-- SYNTATIC SUGAR FUNCTION (self passed)
sectiont = patterns_by_section_hash["EQUALITY TESTS OF MEANS ACROSS CLASSES USING THE BCH PROCEDURE WITH N DEGREE(S) OF FREEDOM FOR THE OVERALL TEST"]
function sectiont:getheaderstr( rt )
	if not rt or not rt["bchtable"] then return '**HEADER STRING ERROR**' end
	
	return strloc[ self["prev"] ] .. ' ' .. strloc[ string.format( self["strformat"], rt["bchtable"]["#n"] ) ]
end

sectiont = nil

	
-- Add patterns for multi-line patterns_by_section_hash up to n=10
-- We must grab the original keys as we're editing patterns_by_section_hash while iterating
local keys = keySet(patterns_by_section_hash)
local _,k
for _,k in pairs(keys) do
	local strformat = patterns_by_section_hash[ k ][ "strformat" ]
	if strformat then
		for n=1,10 do
			-- Example: "THE N-STEP PROCEDURE" becomes "THE 1-STEP PROCEDURE", etc.
			local header = string.format(strformat, n)
			patterns_by_section_hash[ header ] = setmetatable({
				["section"] = k,
				["strformat"] = false,
				["n"] = n
			},{__index=patterns_by_section_hash[ k ]})
			-- Also add it to localization table
			strloc[ string.format(strloc[ strformat ], n) ] = header
		end -- for n
	end -- if
end -- for k,v

-- # End Pattern Definitions & Functions
-- ################################################################