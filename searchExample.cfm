<cfparam name="URL.q" default="Oil">
<cfset sampleSolrInstance = createObject("component","components.cfsolrlib").init(APPLICATION.javaloader,"localhost","8983","/solr") />
<cfif structKeyExists(url,"enableHighlighting")>
	<cfset local.params = structNew()>
    <cfset local.params["hl"] = "on">
    <cfset local.params["hl.fl"] = "title">
    <cfset local.params["hl.fragListBuilder"] = "simple">
    <cfset local.params["hl.fragsize"] = 20>
	<cfset local.params["hl.snippets"] = 10>
    <cfset local.params["hl.useFastVectorHighlighter"] = true>
	<cfset local.params["hl.fragmentsBuilder"] = "colored">
	<cfset local.params["hl.boundaryScanner"] = "default">
	<cfset local.params["hl.usePhraseHighlighter"] = true>
    <cfset searchResponse = sampleSolrInstance.search(URL.q,0,100,local.params) />
<cfelse>
    <cfset searchResponse = sampleSolrInstance.search(URL.q,0,100) />
</cfif>

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
            Enable Highlighting: <input name="enableHighlighting" type="checkbox" /><br />
			<input type="submit" value="Search" /><br />
			Other Search Examples: <a href="searchExample.cfm?q=*:*">*:*</a> | <a href="searchExample.cfm?q=Charcoal">Charcoal</a> | <a href="searchExample.cfm?q=Media">Media</a>
		</form>
		<p>
				<cfloop array="#searchResponse.results#" index="currentResult">
					<strong>ID:</strong> #currentResult.id# <strong>TITLE:</strong> #currentResult.title#<br/>
                    <cfif structKeyExists(url,"enableHighlighting")>
                    	<strong>HIGHLIGHTING:</strong> <cfif structKeyExists(currentResult,"highlightingResult")>#currentResult.highlightingResult[1]#</cfif><br/>
                    </cfif>
				</cfloop>
		</p>
	</body>
</html>
</cfoutput>
