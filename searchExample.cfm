<cfparam name="URL.q" default="Oil">
<cfset sampleSolrInstance = createObject("component","components.cfsolrlib").init(APPLICATION.javaloader,"localhost","8983","/solr") />
<cfset searchResponse = sampleSolrInstance.search(URL.q,0,100) />

<cfoutput>
<html>
	<head>
		<title>CFSolrLib 2.0 | Search Example</title>
	</head>
	<body>
		<h2>Search Example</h2>
		<p>Here is a simple search example.</p>
		<form action="" method="GET">
			Search: <input name="q" value="#URL.q#" /><br />
			<input type="submit" value="Search" /><br/>
			Other Search Examples: <a href="searchExample.cfm?q=*:*">*:*</a> | <a href="searchExample.cfm?q=Charcoal">Charcoal</a> | <a href="searchExample.cfm?q=Media">Media</a>
		</form>
		
		<p>
				<cfloop array="#searchResponse.results#" index="currentResult">
					<strong>ID:</strong> #currentResult.id# <strong>TITLE:</strong> #currentResult.title#<br/>
				</cfloop>
		</p>
	</body>
</html>
</cfoutput>
