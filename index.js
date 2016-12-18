var fs = require('fs');
var path = require('path');
var promise = require('q');

var parser = require('qlik-script-log-parser');
var util = require('util');


var NoValue = [ 'NoValue' ];

function tryFilter(arr, cond) {
	var retVal = arr.filter(cond);
	return (retVal.length == 1) ? arr[0] : false;
}

module.exports = {
	
	getAnalyzer: function() {
		
		return parser.getParser().then(parser => {
			
			return {
				
				analyze: file => analyzeFile(parser, file)
				
			}
			
		})
		
	}
	
}

function analyzeFile(parser, file) {
					
	var parsedFile = parser.parse(file);
	
	if (parsedFile.parsed) {
		
		var outFiles = {};
		
		var tables = [];
	
		var blocksToKeep = [ 'LOAD', 'CONNECT', 'FINISHED', 'FAILED', 'DROP', 'RENAME', 'DIRECT' ]
		var blocks = parsedFile.result.filter(block => blocksToKeep.indexOf(block.blockType) !== -1);
		
		var prevConnect = NoValue;
		var prevLoad = NoValue;
		
		blocks.forEach((block, index) => {
			if(block.blockType == 'CONNECT' && !block.block.disconnect) prevConnect = block;
			if(block.blockType == 'CONNECT' && block.block.disconnect) prevConnect = NoValue;
			
			if(block.blockType == 'LOAD') {
				block.prevLoad = prevLoad;
				block.prevConnect = prevConnect;
				prevLoad = block;
			}
			
		});
		
		// Libraries
		
		var connectBlocks = blocks
			.filter(block => block.blockType == 'CONNECT')
			.map(block => { return { libName: 'CONNECT', libRow: block.rowNumber, blocks: [ block ] }});
		
		var connectFromBlocks = blocks
			.filter(block => block.blockType == 'LOAD')
			.filter(block => block.block.source && block.block.source.loadBlockType == 'FROM')
			.map(block => { return { from: block.block.source.data.from, block: block }})
			.map(block => { return { from: block.from.match('^lib://([^/]*)/.+$')[1], block: block.block }})
			.reduce((result, value) => {
				if(filter = tryFilter(result, block => block.from == value.from)) {
					filter.blocks.push(value.block);
				} else {
					result.push({ from: value.from, blocks: [ value.block ] }) ;
				}
				
				return result;
			}, [])
			.map(block => { return { libName: block.from, blocks: block.blocks }});
		
		var libraries = connectBlocks.concat(connectFromBlocks);
		libraries.forEach((item, index) => item.keyLib = index)
		
		// Fields
		
		function findTableName(block) {
			
			if(block.block.prefixes && block.block.prefixes.concat && block.block.prefixes.concat.concat) {
				if(block.block.prefixes.concat.name) {
					return block.block.prefixes.concat.name.value;
				} else if (block.prevLoad) {
					return findTableName(block.prevLoad);
				}
			}
			
			if(block.block.prefixes && block.block.prefixes.table) {
				return block.block.prefixes.table.value;
			}

			if(block.block.precedings) {
				if (block.block.precedings[0].prefixes && block.block.precedings[0].prefixes.table) {
					return block.block.precedings[0].prefixes.table.value;
				}
			}
			
			if(block.block.source && block.block.source.loadBlockType == 'FROM') {
				if(block.block.source.data && block.block.source.data.params) {
					var fParams = block.block.source.data.params.filter(param => param.table);
					if (fParams.length == 1) return fParams[0].value;
				}
				
				if(block.block.source.data && block.block.source.data.from) {
					if (block.block.source.data.from.match(/^lib:\/\//)) {
						var s1 = block.block.source.data.from.split('/');
						var s2 = s1[s1.length - 1].split('\\');
						var csvName = s2[s2.length - 1];
						return csvName.split('.').slice(0, -1).join('.');
					}
				}
			}
			
			if(block.block.source && block.block.source.loadBlockType == 'RESIDENT') {
				if(block.block.source.data && block.block.source.data.from) {
					return block.block.source.data.table;
				}
			}
			
			return NoValue;
			
		}
		
		function findConcat(block) {
			if(block.block.prefixes && !block.block.prefixes.concat) {
				return { concat: true };
			} else if(block.block.prefixes && block.block.prefixes.concat && !block.block.prefixes.concat.concat) {
				return { concat: false };
			} else if(block.block.prefixes && block.block.prefixes.concat && block.block.prefixes.concat.concat) {
				return { concat: true };
			}
			
			if(block.block.precedings) {
				if (block.block.precedings[0].prefixes && block.block.precedings[0].prefixes.concat) {
					return block.block.precedings[0].prefixes.concat;
				}
			}
			
			var fields = findFields(block);
			
			var concatTable = tables.find(table => {
				return table.fields.length == fields.length && table.fields.every(field => {
					return typeof fields.find(previousField => previousField.fieldName == field.fieldName) !== 'undefined';
				})
			})
			
			if (typeof concatTable !== 'undefined') return { concat: true, name: concatTable.name }
			
			return { concat: false };
		}
		
		function fieldFindSourceFields(field) {
			
			switch (field.type) {
				
				case 'EXPR':
					var retVal = [];
					if(field.left) retVal = retVal.concat(fieldFindSourceFields(field.left));
					if(field.right) retVal = retVal.concat(fieldFindSourceFields(field.right));
					return retVal;
					
				case 'VAR':
					return [ field.value ];
					
				case 'FCALL':
					var retVal = [];
					if (field.params) {
						field.params.forEach(param => {
							retVal = retVal.concat(fieldFindSourceFields(param));
						});
					}
					return retVal;
					
				default:
					return [];
				
			}
			
		}
		
		function fieldsFindSourceFields(fields) {
			var retVal = [];
			fields.forEach(field => {
				return fieldFindSourceFields(field.source.expression).forEach(foundField => {
					retVal.push({
						field: field,
						foundField: foundField
					});
				});
			})
			return retVal;
		}
		
		function findFields(block) {
			
			if(block.block.summary && block.block.summary.sum.length == 1) {
				
				return block.block.summary.sum[0].sum1.map(field => {
					
					var fieldCandidates = [ NoValue ];
					
					if(block.block.load) {

						fieldCandidates = block.block.load.fields.filter(sourceField => {
							return sourceField.field == field;
						}).map(sourceField => sourceField.expr);
						
						if(fieldCandidates.length == 0) fieldCandidates = block.block.load.fields.filter(sourceField => sourceField == '*').map(sourceField => { return { type: 'VAR', value: '*', txt: () => '*' }});
						if(fieldCandidates.length == 0) fieldCandidates = [ NoValue ]
					}

					return {
						field: field,
						expression: (fieldCandidates[0] != NoValue) ? fieldCandidates[0] : { type: 'VAR', value: '*', txt: () => '*' }
					};
				});
			}
			
			return NoValue;
		}
		
		var loadBlocks = blocks
			.filter(block => block.blockType == 'LOAD' || block.blockType == 'DROP' || block.blockType == 'RENAME')
			.map(block => {
				
				var retVal = { block: block };
				
				if(block.blockType == 'LOAD') {
				
					var props = {
						tableName: findTableName(block),
						concat: findConcat(block),
						fields: findFields(block),
						source: block.block.source
					};
					
					Object.keys(props).forEach(key => retVal[key] = props[key]);
				
				}
				
				return retVal;
			});
			
		var incompleteStatements = loadBlocks.filter(statement => {
			return statement.block.blockType == 'LOAD' && (
				statement.tableName == NoValue ||
				statement.concat == NoValue ||
				statement.fields == NoValue ||
				statement.source == NoValue
			);
		});
		
		if (incompleteStatements.length > 0) {
			
			return {
				analyzed: false,
				message: 'not implemented yet: missing analysis',
				incompleteStatements: incompleteStatements
			}
			
		}

		
		
		function addField(tables, fields, tableName, fieldName, expression, rowNumber, statement) {
			
			var tablesFilter = tables.filter(table => table.tableName == tableName);
			
			if (tablesFilter.length == 0) {
				
				var newField = {
					tableName: tableName,
					fieldName: fieldName
				};
				
				fields.push(newField);
				
				var newSource = {
					expression: expression,
					rowNumber: rowNumber,
					statement: statement
				}
					
				var newTable = {
					tableName: tableName,
					fields: [{
						field: newField,
						sources: [newSource]
					}]
				}
				
				tables.push(newTable);
				
				return { table: newTable, field: newField, source: newSource };
				
			} else if (tablesFilter.length == 1) {
				
				var table = tablesFilter[0];
				var fieldsFilter = table.fields.filter(field => field.field.tableName == tableName && field.field.fieldName == fieldName);
				
				if (fieldsFilter.length == 0) {
					
					var newField = {
						tableName: tableName,
						fieldName: fieldName
					};
					
					fields.push(newField);
					
					var newSource = {
						expression: expression,
						rowNumber: rowNumber,
						statement: statement
					}
					
					table.fields.push({
						field: newField,
						sources: [newSource]
					})
					
					return { table: table, field: newField, source: newSource };
					
				} else if (fieldsFilter.length == 1) {
					
					var field = fieldsFilter[0];
					
					var newSource = {
						expression: expression,
						rowNumber: rowNumber,
						statement: statement
					}
					
					field.sources.push(newSource);
					
					return { table: table, field: field.field, source: newSource };
					
				}
				
			}
		}
		
		var fields = [];
		var statements = [];
		var links = [];
		
		for(var sIdx = 0; sIdx < loadBlocks.length; sIdx++) {
			
			var loadBlock = loadBlocks[sIdx];
			
			if (loadBlock.block.blockType == 'LOAD') {
				
				var newStatement = {};

				var tablesFilter = tables.filter(table => table.tableName == loadBlock.tableName);
				if(!loadBlock.concat.concat && tablesFilter.length > 0) {
					
					var tableSuffix = 1;
					do {
						var tablesFilterSuffix = tables.filter(table => table.tableName == loadBlock.tableName + '-' + tableSuffix);
						if (tablesFilterSuffix.length == 0) break;
						tableSuffix++;
					} while(true);
					
					loadBlock.tableName = loadBlock.tableName + '-' + tableSuffix;
					
				}

				var flds = loadBlock.fields.map(field => {
					return addField(tables, fields, loadBlock.tableName, field.field, field.expression, loadBlock.block.rowNumber, newStatement);
				});
				
				links = links.concat(flds);
				
				if (loadBlock.source.loadBlockType == 'RESIDENT') {
					var sourceFlds = fieldsFindSourceFields(flds);
					
					var sourceTablesFilter = tables.filter(table => table.tableName == loadBlock.source.data.table);
					
					if(sourceTablesFilter.length !== 1) {
						
						return {
							analyzed: false,
							message: 'impossible to find source resident table',
							table: loadBlock.source.data.table
						}
						
					}
					
					var sourceFields = sourceFlds.map(sourceFld => {
						var fieldCandidates;
						if(sourceFld.foundField == '*') {
							fieldCandidates = sourceTablesFilter[0].fields.filter(srcFldCandidate => sourceFld.field.field.fieldName == srcFldCandidate.field.fieldName);
						} else {
							fieldCandidates = sourceTablesFilter[0].fields.filter(srcFldCandidate => sourceFld.foundField == srcFldCandidate.field.fieldName);
						}

						return {
							field: sourceFld.field,
							sourceField: (fieldCandidates.length == 1) ? fieldCandidates[0] : false
						};
					})
					
					
					
					sourceFields.forEach(sourceField => {
						if (sourceField.sourceField.sources) {
							sourceField.sourceField.sources.forEach(source => {
								links.push(addField(
									tables,
									fields,
									sourceField.field.table.tableName,
									sourceField.field.field.fieldName,
									source.expression,
									source.rowNumber,
									source.statement
								));
							})
						}
					});

					
				}

				var lib = tryFilter(libraries, lib => lib.blocks.indexOf(loadBlock.block) != -1);

				newStatement.lib 						= lib ? lib : false, 
				newStatement.statementType				= loadBlock.block.blockType,
				newStatement.statement					= loadBlock.block.txt(),
				newStatement.statementSourceType		= loadBlock.source.loadBlockType,
				newStatement.statementSource			= loadBlock.source.data.from,
				newStatement.statementSourceLib			= loadBlock.source.data.lib,
				newStatement.statementSourceTable		= loadBlock.source.data.table,
				newStatement.statementSourceParameters	= loadBlock.source.data.params,
				newStatement.statementTable				= loadBlock.tableName
				
				statements.push(newStatement);

				// console.log('--------------------------')
				// console.log(util.inspect(flds, { showHidden: false, depth: 8, colors: true, maxArrayLength: null }));
				
				
			
			} else if (loadBlock.block.blockType == 'DROP') {
				
			} else if (loadBlock.block.blockType == 'RENAME') {
				
			}


		}
		
		fields.forEach((item, index) => item.keyField = index)
		statements.forEach((item, index) => item.keyStatement = index)
		
		//console.log(util.inspect(links, { showHidden: false, depth: 8, colors: true, maxArrayLength: null }));

		return {
			analyzed: true,
			libraries: libraries,
			fields: fields,
			statements: statements,
			links: links
		}
		
	}
	
}