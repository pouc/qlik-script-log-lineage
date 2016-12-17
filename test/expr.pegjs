
/*
 * Expressions
 */

expressions
	= head:expression tail:(sep? ',' sep? expression?)*
	{
		return tail.reduce(function(result, element) {
			return result.concat([element[3]])
		}, [ head ]);
    }
	
expression
	= expr:conditionORExpression
	{
		return expr;
	}
	
// OR has a lower priority so rule evaluation is 1st in order
	
conditionORExpression
	= head:conditionANDExpression tail:(sep? conditionOROperator sep? conditionANDExpression)*
	{
		if (tail.length == 0) {
			return head;
		} else {
			var retVal = tail.reduce(function(result, element) {
				return { type: 'EXPR', op: element[1], left: result, right: element[3]}
			}, head)
			retVal.txt = () => computeText(arguments);
			return retVal;
		}
    }

conditionOROperator		= op: ( 'OR'i / 'XOR'i ) & ( sep / '(' ) 			{ return op; }

// AND has a higher priority so rule evaluation is 2nd in order

conditionANDExpression
	= head:conditionNOTExpression tail:(sep? conditionANDOperator sep? conditionNOTExpression)*
	{
		if (tail.length == 0) {
			return head;
		} else {
			var retVal = tail.reduce(function(result, element) {
				return { type: 'EXPR', op: element[1], left: result, right: element[3]}
			}, head)
			retVal.txt = () => computeText(arguments);
			return retVal;
		}
    }
	
conditionANDOperator	= op:'AND'i & ( sep / '(' ) 						{ return op; }

// NOT has a higher priority so rule evaluation is last in order
	
conditionNOTExpression
	= tail:(conditionNOTOperator sep? comparisonExpression)+
	{
		var retVal = tail.reduce(function(result, element) {
			return { type: 'EXPR', op: element[0], left: element[2], right: false}
		}, [])
		retVal.txt = () => computeText(arguments);
		return retVal;
    }
	/ comparisonExpression

conditionNOTOperator		= op:'NOT'i & ( sep / '(' )						{ return op; }

comparisonExpression
	= left:calculationExpression sep? op:comparisonOperator sep? right:calculationExpression {
		return { type: 'EXPR', op: op, left: left, right: right, txt: () => computeText(arguments) }
    }
	/ left:calculationExpression { return left; }

comparisonOperator	= '=' / '<>' / '>=' / '<=' / '>' / '<' / 'LIKE'i & sep

calculationExpression
	= calculationStringExpression
	
calculationStringExpression
	= head:calculationAddExpression tail:(sep? calculationStringOperator sep? calculationAddExpression)*
	{
		if (tail.length == 0) {
			return head;
		} else {
			var retVal = tail.reduce(function(result, element) {
				return { type: 'EXPR', op: element[1], left: result, right: element[3]}
			}, head);
			retVal.txt = () => computeText(arguments);
			return retVal;
		}
    }
	
calculationStringOperator = '&'
	
calculationAddExpression
	= head:calculationFactExpression tail:(sep? calculationAddOperator sep? calculationFactExpression)*
	{
		if (tail.length == 0) {
			return head;
		} else {
			var retVal = tail.reduce(function(result, element) {
				return { type: 'EXPR', op: element[1], left: result, right: element[3]}
			}, head);
			retVal.txt = () => computeText(arguments);
			return retVal;
		}
    }
	
calculationAddOperator = '+' / '-'
	
calculationFactExpression
	= head:termExpression tail:(sep? calculationFactOperator sep? termExpression)*
	{
		if (tail.length == 0) {
			return head;
		} else {
			var retVal = tail.reduce(function(result, element) {
				return { type: 'EXPR', op: element[1], left: result, right: element[3]}
			}, head);
			retVal.txt = () => computeText(arguments);
			return retVal;
		}
    }

calculationFactOperator = '*'  / '/'
  
termExpression
	= op:"(" sp1:sep? expr:expression sp2:sep? cp:")"		{ return { type: 'NONE', value: expr, 	txt: () => computeText(arguments) }; }
	/ expr:number											{ return { type: 'NUM', value: expr, 	txt: () => computeText(arguments) }; }	
	/ expr:singleQuoteString								{ return expr; }
	/ expr:functionCall										{ return expr; }
	/ expr:('TRUE'i / 'FALSE'i)								{ return { type: 'BOOL', value: expr, 	txt: () => computeText(arguments) }; }
	/ expr:resource											{ return { type: 'VAR', value: expr.value, 	txt: () => computeText(arguments) }; }
	/ expr:('$' [0-9])										{ return { type: 'PARAM', value: expr, 	txt: () => computeText(arguments) }; }

functionCall		= 	name:functionName sep? '(' sep? 'DISTINCT'i? sep? params:functionParameters? sep? ')'
						{ return { type: "FCALL", function: name, params: params }; }

fp					= & (sep? '(')

functionName					 	
/* Aggregation					*/	= func:(
									  'FirstSortedValue'i fp	/ 'Min'i fp					/ 'Max'i fp					/ 'Mode'i fp				/ 'Only'i fp
									/ 'Sum'i fp					/ 'Count'i fp				/ 'MissingCount'i fp		/ 'NullCount'i fp			/ 'NumericCount'i fp
									/ 'TextCount'i fp			/ 'IRR'i fp					/ 'XIRR'i fp				/ 'NPV'i fp					/ 'XNPV'i fp
									/ 'Avg'i fp					/ 'Correl'i fp				/ 'Fractile'i fp			/ 'Kurtosis'i fp			/ 'LINEST_B'i fp
									/ 'LINEST_df'i fp			/ 'LINEST_f'i fp			/ 'LINEST_m'i fp			/ 'LINEST_r2'i fp			/ 'LINEST_seb'i fp
									/ 'LINEST_sem'i fp			/ 'LINEST_sey'i fp			/ 'LINEST_ssreg'i fp		/ 'Linest_ssresid'i fp		/ 'Median'i fp
									/ 'Skew'i fp				/ 'Stdev'i fp				/ 'Sterr'i fp				/ 'STEYX'i fp				/ 'Chi2Test_chi2'i fp
									/ 'Chi2Test_df'i fp			/ 'Chi2Test_p'i fp			/ 'ttest_conf'i fp			/ 'ttest_df'i fp			/ 'ttest_dif'i fp
									/ 'ttest_lower'i fp			/ 'ttest_sig'i fp			/ 'ttest_sterr'i fp			/ 'ttest_t'i fp				/ 'ttest_upper'i fp
									/ 'ztest_conf'i fp			/ 'ztest_dif'i fp			/ 'ztest_sig'i fp			/ 'ztest_sterr'i fp			/ 'ztest_z'i fp
									/ 'ztest_lower'i fp			/ 'ztest_upper'i fp			/ 'Concat'i fp				/ 'FirstValue'i fp			/ 'LastValue'i fp
									/ 'MaxString'i fp			/ 'MinString'i fp
									
/* Color						*/	/ 'ARGB'i fp				/ 'HSL'i fp					/ 'RGB'i fp					/ 'Color'i fp				/ 'Colormix1'i fp
									/ 'Colormix2'i fp			/ 'SysColor'i fp			/ 'ColorMapHue'i fp			/ 'ColorMapJet'i fp
									
/* Conditional					*/	/ 'alt'i fp					/ 'class'i fp				/ 'if'i fp					/ 'match'i fp				/ 'mixmatch'i fp
									/ 'pick'i fp				/ 'wildmatch'i fp
									
/* Counter						*/	/ 'autonumberhash128'i fp	/ 'autonumberhash256'i fp	/ 'autonumber'i fp			/ 'IterNo'i fp				/ 'RecNo'i fp
									/ 'RowNo'i fp
									
/* Date and time				*/	/ 'Date'i fp				/ 'weekyear'i fp			/ 'weekday'i fp				/ 'now'i fp					/ 'today'i fp
									/ 'LocalTime'i fp			/ 'makedate'i fp			/ 'makeweekdate'i fp		/ 'maketime'i fp			/ 'AddMonths'i fp
									/ 'AddYears'i fp			/ 'yeartodate'i fp			/ 'timezone'i fp			/ 'GMT'i fp					/ 'UTC'i fp
									/ 'daylightsaving'i fp		/ 'converttolocaltime'i fp	/ 'setdateyear'i fp			/ 'setdateyearmonth'i fp	/ 'inyeartodate'i fp
									/ 'inyear'i fp				/ 'inquarter'i fp			/ 'inquartertodate'i fp		/ 'inmonth'i fp				/ 'inmonthtodate'i fp
									/ 'inmonths'i fp			/ 'inmonthstodate'i fp		/ 'inweek'i fp				/ 'inweektodate'i fp		/ 'inlunarweek'i fp
									/ 'inlunarweektodate'i fp	/ 'inday'i fp				/ 'indaytotime'i fp			/ 'yearstart'i fp			/ 'yearend'i fp
									/ 'yearname'i fp			/ 'quarterstart'i fp		/ 'quarterend'i fp			/ 'quartername'i fp			/ 'monthstart'i fp
									/ 'monthend'i fp			/ 'monthname'i fp			/ 'monthsstart'i fp			/ 'monthsend'i fp			/ 'monthsname'i fp
									/ 'weekstart'i fp			/ 'weekend'i fp				/ 'weekname'i fp			/ 'lunarweekstart'i fp		/ 'lunarweekend'i fp
									/ 'lunarweekname'i fp		/ 'daystart'i fp			/ 'dayend'i fp				/ 'dayname'i fp				/ 'age'i fp
									/ 'networkdays'i fp			/ 'firstworkdate'i fp		/ 'lastworkdate'i fp		/ 'daynumberofyear'i fp		/ 'daynumberofquarter'i fp
									/ 'second'i fp				/ 'minute'i fp				/ 'hour'i fp				/ 'day'i fp					/ 'week'i fp
									/ 'month'i fp				/ 'year'i fp
									
/* Exponential and logarithmic	*/	/ 'exp'i fp					/ 'log'i fp					/ 'log10'i fp				/ 'pow'i fp					/ 'sqr'i fp
									/ 'sqrt'i fp
									
/* File							*/	/ 'Attribute'i fp			/ 'ConnectString'i fp		/ 'FileBaseName'i fp		/ 'FileDir'i fp				/ 'FileExtension'i fp
									/ 'FileName'i fp			/ 'FilePath'i fp			/ 'FileSize'i fp			/ 'FileTime'i fp			/ 'GetFolderPath'i fp
									/ 'QvdCreateTime'i fp		/ 'QvdFieldName'i fp		/ 'QvdNoOfFields'i fp		/ 'QvdNoOfRecords'i fp		/ 'QvdTableName'i fp

/* Financial					*/	/ 'FV'i fp					/ 'nPer'i fp				/ 'Pmt'i fp					/ 'PV'i fp					/ 'Rate'i fp

/* Formatting					*/	/ 'ApplyCodepage'i fp		/ 'Dual'i fp				/ 'Num'i fp					/ 'Timestamp'i fp			/ 'Time'i fp
									/ 'Interval'i fp			/ 'Money'i fp
									
/* General numeric				*/	/ 'bitcount'i fp			/ 'div'i fp					/ 'fabs'i fp				/ 'fact'i fp				/ 'frac'i fp
									/ 'sign'i fp				/ 'combin'i fp				/ 'permut'i fp				/ 'fmod'i fp				/ 'mod'i fp
									/ 'even'i fp				/ 'odd'i fp					/ 'ceil'i fp				/ 'floor'i fp				/ 'round'i fp
									
/* Geospatial					*/	/ 'GeoAggrGeometry'i fp		/ 'GeoBoundingBox'i fp		/ 'GeoCountVertex'i fp		/ 'GeoInvProjectGeometry'i fp
									/ 'GeoProjectGeometry'i fp	/ 'GeoReduceGeometry'i fp	/ 'GeoGetBoundingBox'i fp	/ 'GeoGetPolygonCenter'i fp
									/ 'GeoMakePoint'i fp		/ 'GeoProject'i fp
									
/* Interpretation				*/	/ 'Date#'i fp				/ 'Interval#'i fp			/ 'Num#'i fp				/ 'Time#'i fp				/ 'Timestamp#'i fp
									/ 'Money#'i fp				/ 'Text'i fp
									
/* Inter-record					*/	/ 'Exists'i fp				/ 'LookUp'i fp				/ 'Peek'i fp				/ 'Previous'i fp			/ 'FieldValue'i fp

/* Logical						*/	/ 'IsNum'i fp				/ 'IsText'i fp

/* Mapping						*/	/ 'ApplyMap'i fp			/ 'MapSubstring'i fp

/* Mathematical					*/	/ 'e'i fp					/ 'false'i fp				/ 'pi'i fp					/ 'rand'i fp				/ 'true'i fp

/* NULL							*/	/ 'isnull'i fp				/ 'null'i fp

/* Range						*/	/ 'RangeMax'i fp			/ 'RangeMaxString'i fp		/ 'RangeMin'i fp			/ 'RangeMinString'i fp		/ 'RangeMode'i fp
									/ 'RangeOnly'i fp			/ 'RangeSum'i fp			/ 'RangeCount'i fp			/ 'RangeMissingCount'i fp	/ 'RangeNullCount'i fp
									/ 'RangeNumericCount'i fp	/ 'RangeTextCount'i fp		/ 'RangeAvg'i fp			/ 'RangeCorrel'i fp			/ 'RangeFractile'i fp
									/ 'RangeKurtosis'i fp		/ 'RangeSkew'i fp			/ 'RangeStdev'i fp			/ 'RangeIRR'i fp			/ 'RangeNPV'i fp
									/ 'RangeXIRR'i fp			/ 'RangeXNPV'i fp
									
/* Ranking in charts			*/	/ 'Rank'i fp				/ 'HRank'i fp

/* Statistical distribution		*/	/ 'CHIDIST'i fp				/ 'CHIINV'i fp				/ 'NORMDIST'i fp			/ 'NORMINV'i fp				/ 'TDIST'i fp
									/ 'TINV'i fp				/ 'FDIST'i fp				/ 'FINV'i fp
									
/* String						*/	/ 'Capitalize'i fp			/ 'Chr'i fp					/ 'Evaluate'i fp			/ 'FindOneOf'i fp			/ 'Hash128'i fp
									/ 'Hash160'i fp				/ 'Hash256'i fp				/ 'Index'i fp				/ 'KeepChar'i fp			/ 'Left'i fp
									/ 'Len'i fp					/ 'Lower'i fp				/ 'LTrim'i fp				/ 'Mid'i fp					/ 'Ord'i fp
									/ 'PurgeChar'i fp			/ 'Repeat'i fp				/ 'Replace'i fp				/ 'Right'i fp				/ 'RTrim'i fp
									/ 'SubField'i fp			/ 'SubStringCount'i fp		/ 'TextBetween'i fp			/ 'Trim'i fp				/ 'Upper'i fp
									
/* System						*/	/ 'Author'i fp				/ 'ClientPlatform'i fp		/ 'ComputerName'i fp		/ 'DocumentName'i fp		/ 'DocumentPath'i fp
									/ 'DocumentTitle'i fp		/ 'GetCollationLocale'i fp	/ 'GetObjectField'i fp		/ 'GetRegistryString'i fp	/ 'IsPartialReload'i fp
									/ 'OSUser'i fp				/ 'ProductVersion'i fp		/ 'ReloadTime'i fp			/ 'StateName'i fp
									
/* Table						*/	/ 'FieldName'i fp			/ 'FieldNumber'i fp			/ 'NoOfFields'i fp			/ 'NoOfRows'i fp			/ 'NoOfTables'i fp
									/ 'TableName'i fp			/ 'TableNumber'i fp
									
/* Trigonometric and hyperbolic	*/	/ 'cos'i fp					/ 'acos'i fp				/ 'sin'i fp					/ 'asin'i fp				/ 'tan'i fp
									/ 'atan'i fp				/ 'atan2'i fp				/ 'cosh'i fp				/ 'sinh'i fp				/ 'tanh'i fp
								) { return func[0]; }

functionParameters
	= expressions

/*
 * Misc.
 */

sep
	= chars:(sp1:spaces? nl:newline spaces? pf:rowPrefix sp2:spaces? { return (sp1 ? sp1 : '') + nl + (pf.sp ? pf.sp : '') + (sp2 ? sp2 : ''); } )+
		{ return chars.join(''); }
	/ chars:spaces
		{ return chars; }
 
tableName			= name:resource spaces? ':'																	{ return name;}

resources
	= head:resource tail:(sep? ',' sep? resource)*
	{
		return [head].concat(tail.map(res => res[3]));
	}

resource			= name:(
						lib:'lib://' res:[^ \t\r\n()]+		{ return { value: lib + res.join(''), 					txt: () => computeText(arguments) }; }
						/ name:('@'? alphanum)				{ return { value: (name[0] ? name[0] : '') + name[1], 	txt: () => computeText(arguments) }; }
						/ name:braceQuoteString				
						/ name:doubleQuoteString
						/ name:singleQuoteString
						/ name:diagonalQuoteString
					)
					{ return name;}
					
variableName		= name:alphanum
variableValue 		= expression

rowPrefix			= pf:rowPrefixWoRn space scriptRowNumber:scriptRowNumber space sp:spaces?					{ return { datetime: pf.datetime, rowNumber: parseInt(scriptRowNumber), sp: (sp ? sp : false), txt: () => '' }; }
rowPrefix6Spaces	= pf:rowPrefixWoRn sixSpaces																{ return { datetime: pf.datetime }; }

rowPrefixWoRn		= spaces? datetime:datetime																	{ return { datetime: datetime}; }	
	
/*
 * Date & Time
 */
	
datetime			= date:date spaces time:time { return {date: date, time: time}; } 
date				= date:(digit digit digit digit '-' digit digit '-' digit digit) { return date.join(''); }
time				= time:(digit digit ':' digit digit ':' digit digit) { return time.join(''); }
	
scriptRowNumber		= scriptRowNumber:(digit digit digit digit) { return scriptRowNumber.join(''); }

/*
 * Spaces
 */

spacesNL			= spacesNL:(space / newline)+			{ return spacesNL.join(''); }
spaces				= spaces:space+							{ return spaces.join(''); }
sixSpaces			= spaces:(space space space space space space)
															{ return spaces.join(''); }

space				= chars:(' ' / '\t')					{ return chars; }

newline				= chars:('\r'? '\n') 					{ return chars.join(''); }

/*
 * Numbers
 */
number				= decimal / integer
decimal				= digits:('-'? digit+ '.' digit+ ) { return parseFloat((digits[0] ? digits[0] : '+') + digits[1].join("") + '.' + digits[3].join("")); }
integer				= digits:('-'? digit+) { return parseInt((digits[0] ? digits[0] : '+') + digits[1].join("")); }
digit				= [0-9]

/*
 * Strings
 */

alphanum			= chars:[a-zA-Z0-9\xC0-\xFF_\.%\?#°º$§]+	{ return chars.join(''); }
endofrow			= chars:[^\r\n]*							{ return chars.join(''); }
spEndofrow			= spaces? ( newline / EOF )
EOF					= !.

strings
	= head:string tail:(sep? ',' sep? string)*
	{
		return tail.reduce(function(result, element) {
			return result.concat([element[3]])
		}, [ head ]);
    }
	
string				= doubleQuoteString / singleQuoteString / diagonalQuoteStrings


/*
 * Double quoted strings
 */

doubleQuoteStrings
	= head:doubleQuoteString tail:(sep? ',' sep doubleQuoteString)*
	{
		return tail.reduce(function(result, element) {
			return result.concat([element[3]])
		}, [ head ]);
    }
	
doubleQuoteString = doubleQuote chars:doubleQuotechar* doubleQuote { return chars.join(''); }

doubleQuotechar
  = doubleQuoteUeChar
  / doubleQuoteEscape
	sequence:(
		doubleQuote { return '"'; }
	)
    { return sequence; }

doubleQuoteEscape	= '"'
doubleQuote			= '"'
doubleQuoteUeChar	= '\t' / [^\0-\x1F"]

/*
 * Single quoted strings
 */

singleQuoteStrings
	= head:singleQuoteString tail:(sep? ',' sep? singleQuoteString)*
	{
		return tail.reduce(function(result, element) {
			return result.concat([element[3]])
		}, [ head ]);
    }
	
singleQuoteString
	= oq:singleQuote chars:singleQuotechar* cq:singleQuote
	{
		return { type: 'STR', value: chars.map(char => char.char).join(''), txt: () => computeText(arguments) };
	}

singleQuotechar
 	= char:singleQuoteUeChar
	{ return { char: char, txt: () => computeText(arguments) }}
	
	/ esc:singleQuote sequence:(singleQuote)
    { return { char: sequence, txt: () => computeText(arguments) }; }
	
    / sep:sep char:(singleQuotechar / & singleQuote)
    { return { char: sep + char, txt: () => computeText(arguments) }; }
    
singleQuote			= "'"
singleQuoteUeChar	= '\t' / [^\0-\x1F']

/*
 * Diagonal quoted strings
 */

diagonalQuoteStrings
	= head:diagonalQuoteString tail:(sep? ',' sep? diagonalQuoteString)*
	{
		return tail.reduce(function(result, element) {
			return result.concat([element[3]])
		}, [ head ]);
    }
	
diagonalQuoteString
	= oq:diagonalQuote chars:diagonalQuotechar* cq:diagonalQuote
	{
		return { type: 'STR', value: chars.map(char => char.char).join(''), txt: () => computeText(arguments) };
	}

diagonalQuotechar
 	= char:diagonalQuoteUeChar
	{ return { char: char, txt: () => computeText(arguments) }}
	
	/ esc:diagonalQuote sequence:(diagonalQuote)
    { return { char: sequence, txt: () => computeText(arguments) }; }
	
    / sep:sep char:(diagonalQuotechar / & diagonalQuote)
    { return { char: sep + char, txt: () => computeText(arguments) }; }
    
diagonalQuote		= "`"
diagonalQuoteUeChar	= '\t' / [^\0-\x1F`]

/*
 * Braced quoted strings
 */
 
braceQuoteString
	= oq:openBrace chars:braceQuotechar* cq:closeBrace
	{
		return { type: 'STR', value: chars.map(char => char.char).join(''), txt: () => computeText(arguments) };
	}

braceQuotechar
 	= char:braceQuoteUeChar
	{ return { char: char, txt: () => computeText(arguments) }}
	
	/ esc:braceQuoteEscape sequence:(closeBrace)
    { return { char: sequence, txt: () => computeText(arguments) }; }
	
    / sep:sep char:(braceQuotechar / & closeBrace)
    { return { char: sep + char, txt: () => computeText(arguments) }; }

braceQuoteEscape	= '\\'
openBrace			= '['
closeBrace			= ']'
braceQuoteUeChar	= '\t' / [^\0-\x1F\]]