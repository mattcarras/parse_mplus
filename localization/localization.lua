-- ################################################################
-- # parse_mplus Localized Strings
-- #
-- #(Includes section headers and possibly some patterns)

-- Globals defined here: strings_localized

-- [ "Default (en-US) String" ] = "Localized String"
strings_localized = {
	-- Section Headers
	-- Keys are from Mplus output
	["INPUT INSTRUCTIONS"] = "INPUT INSTRUCTIONS",
	["SUMMARY OF ANALYSIS"] = "SUMMARY OF ANALYSIS",
	["BASED ON THE ESTIMATED MODEL"] = "BASED ON THE ESTIMATED MODEL",
	["FINAL CLASS COUNTS AND PROPORTIONS FOR THE LATENT CLASSES"] = "FINAL CLASS COUNTS AND PROPORTIONS FOR THE LATENT CLASSES",
	["RESULTS IN PROBABILITY SCALE"] = "RESULTS IN PROBABILITY SCALE",
	["CONFIDENCE INTERVALS IN PROBABILITY SCALE"] = "CONFIDENCE INTERVALS IN PROBABILITY SCALE",
	["TESTS OF CATEGORICAL LATENT VARIABLE MULTINOMIAL LOGISTIC REGRESSIONS USING"] = "TESTS OF CATEGORICAL LATENT VARIABLE MULTINOMIAL LOGISTIC REGRESSIONS USING",
	-- ["THE %d-STEP PROCEDURE"] = "THE %d-STEP PROCEDURE", -- %d is replaced by a number (not needed for R3STEP)
	["THE 3-STEP PROCEDURE"] = "THE 3-STEP PROCEDURE", -- R3STEP
	["EQUALITY TESTS OF MEANS ACROSS CLASSES USING THE BCH PROCEDURE"] = "EQUALITY TESTS OF MEANS ACROSS CLASSES USING THE BCH PROCEDURE",
	["WITH %d DEGREE(S) OF FREEDOM FOR THE OVERALL TEST"] = "WITH %d DEGREE(S) OF FREEDOM FOR THE OVERALL TEST", -- %d is replaced by a number (BCH)
	["CLASSIFICATION QUALITY"] = "CLASSIFICATION QUALITY",
	["MODEL FIT INFORMATION"] = "MODEL FIT INFORMATION",
	["TECHNICAL 10 OUTPUT"] = "TECHNICAL 10 OUTPUT",
	["TECHNICAL 11 OUTPUT"] = "TECHNICAL 11 OUTPUT",
	["TECHNICAL 14 OUTPUT"] = "TECHNICAL 14 OUTPUT",
	
	-- Strings used in output
	["n/a"] = "n/a",
	["Class"] = "Class", -- as in "Latent Class"
	
	-- Must be lower-case for these keys
	["chi-squared"] = "Chi-Squared", -- Chi-Squared or Chi^2
	["chi-sq"] = "Chi-Sq", -- Chi-Squared or Chi^2
	["p-value"] = "P-Value",
	["mean"] = "Mean",
	["s.e."] = "S.E.",
	["est."] = "Est.",
	["est./s.e."] = "Est./S.E.",
	["two-tailed p-value"] = "Two-Tailed P-Value",
	["lower ci bound 0.5%"] = "Lower CI Bound 0.5%",
	["lower ci bound 2.5%"] = "Lower CI Bound 2.5%",
	["lower ci bound 5%"] = "Lower CI Bound 5%",
	["estimate"] = "Estimate",
	["upper ci bound 5%"] = "Upper CI Bound 5%",
	["upper ci bound 2.5%"] = "Upper CI Bound 2.5%",
	["upper ci bound 0.5%"] = "Upper CI Bound 0.5%",
	["lb 0.5%"] = "LB 0.5%", -- Lower Bound 0.5%, abbreviated
	["lb 2.5%"] = "LB 2.5%", -- Lower Bound 2.5%, abbreviated
	["lb 5%"] = "LB 5%", -- Lower Bound 5%, abbreviated
	["ub 0.5%"] = "UB 0.5%", -- Upper Bound 0.5%, abbreviated
	["ub 2.5%"] = "UB 2.5%", -- Upper Bound 2.5%, abbreviated
	["ub 5%"] = "UB 5%", -- Upper Bound 5%, abbreviated
	["# of free parameters"] = "# of free parameters",
	["# of param"] = "# of param", -- # of free parameters, abbreviated
	["h0 value"] = "H0 Value",
	["h0"] = "H0", -- h0 value, abbreviated
	["sample-size adjusted bic"] = "Sample-Size Adjusted BIC",
	["bic"] = "BIC", -- Sample-Size Adjusted BIC, abbreviated
	["overall bp chi-sq"] = "Overall BP Chi-Sq",
	["bp"] = "BP", -- Overall BP Chi-Sq, abbreviated
	["avg. bp"] = "Avg. BP" ,-- Average BP using BinomialCoeff()
	["lmr p-value"] = "LMR P-Value",
	["lmr p"] = "LMR p", -- LMR P-Value, abbreviated
	["approx p-value"] = "Approx P-Value",
	["entropy"] = "Entropy",
	["# of classes"] = "# of classes",
	["# of dep var"] = "# of dep var",
		
	["Class %d vs Class %d"] = "Class %d vs Class %d", -- for BCH

	-- Used in CSV table for most upper-left column header
	["csv_class_num_header_format"] = "**%dC**", -- %d is replaced by total number of classes
	["*Ref Class %d*"] = "*Ref Class %d*", -- %d is replaced by ref class (for R3STEP)
	
	["Latent Class Model Selection"] = "Latent Class Model Selection",
	
	-- Used in R plotting code
	["Conditional probability"] = "Conditional probability", -- default y axis label
	["Latent class indicator"] = "Latent class indicator" -- default x axis label
}

-- Example of how to overwrite and extend this table:
--[[
if locale == 'de-DE' then
	strings_localized = setmetatable({
		["Class"] = "Klasse",
		...
	}, {__index=strings_localized})
end
--]]

