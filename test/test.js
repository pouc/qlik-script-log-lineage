var analyzer = require('../index');
var util = require('util');
var json2csv = require('json2csv');

var path = require('path');
var fs = require('fs');

analyzer.getAnalyzer().then(analyzer => {
	
	var analyzed = analyzer.analyze(`
2016-11-15 02:12:03      ReloadCodebase                Classic
2016-11-15 02:12:04      Reload Executed By            UserDirectory=INTERNAL; UserId=sa_scheduler
2016-11-15 02:12:04      Process Executing             Qlik Sense Server
2016-11-15 02:12:04      Process ID                    4940
2016-11-15 02:12:04 0048 set c_lightblue 			= 'RGB(188,181,201)' & (c + 1 + (3 + 4) *
2016-11-15 02:12:04 0048 2)
  2016-11-15 02:12:04 0074 CommandList:	
  2016-11-15 02:12:04 0075   LOAD 
  2016-11-15 02:12:04 0076       Command, 
  2016-11-15 02:12:04 0077       CommandType
  2016-11-15 02:12:04 0078   Inline [
  2016-11-15 02:12:04 0079     Command, CommandType
  2016-11-15 02:12:04 0080     Add license, Allocation
  2016-11-15 02:12:04 0081     Add user access, Usage
  2016-11-15 02:12:04 0082     Delete user access, Allocation
  2016-11-15 02:12:04 0083     License maintenance, Usage
  2016-11-15 02:12:04 0084     License user access, Usage
  2016-11-15 02:12:04 0085     License user access request, Usage
  2016-11-15 02:12:04 0086     Request access type, Usage
  2016-11-15 02:12:04 0087     Update license, Allocation
  2016-11-15 02:12:04 0088     Update user access, Allocation
  2016-11-15 02:12:04 0089     ]
  2016-11-15 02:12:04      	2 fields found: Command, CommandType, 
  2016-11-15 02:12:04      9 lines fetched
	`);
	
	console.log(util.inspect(analyzed, { showHidden: false, depth: null, colors: true, maxArrayLength: null }));
	
	if(analyzed.analyzed) {
		
		console.log('###### libraries.csv');
		
		var libraries = json2csv({
			data: analyzed.libraries,
			fields: [ 'keyLib', 'libName', 'libRow' ],
			defaultValue: 'false'
		});
		
		fs.writeFile(path.join(__dirname, 'libraries.csv'), libraries, function(err) {
			if (err) throw err;
			console.log('libraries file saved');
		});
		
		console.log('###### statements.csv');
		
		var statements = json2csv({
			data: analyzed.statements,
			fields: [
				'keyStatement', 'lib.keyLib', 'statementType', 'statement',
				'statementSourceType', 'statementSource', 'statementSourceLib',
				'statementSourceTable', 'statementSourceParameters', 'statementTable'
			],
			fieldNames: [
				'keyStatement', 'keyLib', 'statementType', 'statement',
				'statementSourceType', 'statementSource', 'statementSourceLib',
				'statementSourceTable', 'statementSourceParameters', 'statementTable'
			],
			defaultValue: 'false'
		});
		
		fs.writeFile(path.join(__dirname, 'statements.csv'), statements, function(err) {
			if (err) throw err;
			console.log('statements file saved');
		});
		
		console.log('###### fields.csv');
		
		var fields = json2csv({
			data: analyzed.fields,
			fields: [ 'keyField', 'tableName', 'fieldName' ],
			defaultValue: 'false'
		});
		
		fs.writeFile(path.join(__dirname, 'fields.csv'), fields, function(err) {
			if (err) throw err;
			console.log('fields file saved');
		});
		
		var links = [];
		analyzed.statements.forEach(statement => {
			statement.fields.forEach(field => {
				links.push({
					keyField: field.field.keyField,
					keyStatement: statement.keyStatement,
					rowNumber: field.rowNumber,
					expression: field.expression
				})
			})
		});
		
		console.log('###### linksFieldStatement.csv');
		
		var linksFieldStatement = json2csv({
			data: links,
			fields: [ 'keyField', 'keyStatement', 'rowNumber', 'expression' ],
			defaultValue: 'false'
		});
		
		fs.writeFile(path.join(__dirname, 'linksFieldStatement.csv'), linksFieldStatement, function(err) {
			if (err) throw err;
			console.log('linksFieldStatement file saved');
		});
	
	}
	

}).fail(err => console.log(err))