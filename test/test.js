var fs = require('fs');
var path = require('path');
var util = require('util');
var promise = require('q');

var analyzer = require('../index');
var json2csv = require('json2csv');

var readdir = promise.denodeify(fs.readdir);
var readFile = promise.denodeify(fs.readFile);

var logFilesDirectoryName = 'log files';

var logFilesFilter = [
	
];

var logFilesForce = [
	// 'dd45cfae-fc4d-4077-9aa0-ac6ea2a52be7.2016_09_12_15_34_19.318C35741417B5EFA5F4.log'
	'5e5e779e-dde6-404d-b682-d6b6710d07dd.2016_11_08_18_05_29.0FEAC4EC4F26D589738A.log'
];

var logFilesDirectoryFullPaths = [
	path.join(__dirname, logFilesDirectoryName, 'test'),
	path.join(__dirname, logFilesDirectoryName, 'script')
];

analyzer.getAnalyzer().then(analyzer => {
	
	return promise.all(logFilesDirectoryFullPaths.map(logFilesDirectoryFullPath => readdir(logFilesDirectoryFullPath).then(files => {
		
		return files.map(file => {
			
			if(fs.lstatSync(path.join(logFilesDirectoryFullPath, file)).isFile()) {
				
				return {
					fileName: file,
					fullName: path.join(logFilesDirectoryFullPath, file)
				};
				
			}
			
			return false;
			
		})
		.filter(i => i && logFilesFilter.indexOf(i.fileName) == -1)
		.filter(i => i && (logFilesForce.length == 0 || logFilesForce.indexOf(i.fileName) !== -1));
		
	}))).then(files => {
		
		return promise.all([
	
			analyzer,
			
			[].concat.apply([], files)
		
		]);
		
	}) 
	
}).then(reply => {
	
	var analyzer = reply[0];
	var files = reply[1];

	var step = promise([]);
	files.forEach(file => {

		step = step.then(function(arr) {
			
			return promise().then(() => {
				
				return readFile(file.fullName, 'utf-8').then(fileContent => {
					
					return {
						fullName : file.fullName,
						fileName: file.fileName,
						fileContent: fileContent
					}
					
				});
				
			}).then(file => {
				
				var analyzed = analyzer.analyze(file.fileContent);
				
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
					
					var links2 = analyzed.links.map(link => {
						console.log(link)
						return {
							keyField: link.field.keyField,
							keyStatement: link.source.statement.keyStatement,
							rowNumber: link.source.rowNumber,
							expression: link.source.expression.txt()
						}
					});
					
					console.log('###### linksFieldStatement.csv');
					
					var linksFieldStatement = json2csv({
						data: links2,
						fields: [ 'keyField', 'keyStatement', 'rowNumber', 'expression' ],
						defaultValue: 'false'
					});
					
					fs.writeFile(path.join(__dirname, 'linksFieldStatement.csv'), linksFieldStatement, function(err) {
						if (err) throw err;
						console.log('linksFieldStatement file saved');
					});
				
				} else {
					
					console.log(util.inspect(analyzed, { showHidden: false, depth: 8, colors: true, maxArrayLength: null }));
					// console.log(analyzed)
					
				}
				
				
			})
			
		});
		
	});
	
	return step;
	
}).fail(err => console.log(err))
				
	
	
	
	
	
	
	
	
	
	
	
/*
	
	
	
	var analyzer = reply[0];
	console.log(reply[1])
	
	return;
	
	
	

}).fail(err => console.log(err))

//*/