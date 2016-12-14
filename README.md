# qlik-script-log-lineage

Provides lineage information on what happened during a Qlik Sense reload with the reload script as an input.

# Usage

```shell
npm install qlik-script-log-lineage --save
```

then

```javascript
var analyzer = require(' qlik-script-log-lineage');

analyzer.getAnalyzer().then(analyzer => {
  var analyzed = analyzer.analyze(fileContent);
  return analyzed;
}).then(analyzed => {
  console.log(analyzed);
})
```
