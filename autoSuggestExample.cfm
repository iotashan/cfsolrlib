<script src="js/jquery-1.7.2.js"></script>
<script src="js/jqueryui/jqueryui-1.8.22.js"></script>
<link rel="stylesheet" href="css/jqueryui/jqueryui-1.8.22.css" type="text/css" />
<script type="text/javascript">
$(function() {
    $("#keyword").autocomplete({
        source: "components/cfsolrlib.cfc?method=getAutoSuggestResults&returnformat=json"
    });
});
</script>

<html>
	<head>
		<title>CFSolrLib 3.0 | Auto-Suggest example</title>
	</head>
	<body>
    
		Keyword: <input id="keyword" />
        
    </body>
</html>