<cfset sampleSolrInstance = createObject("component","components.cfsolrlib").init(APPLICATION.javaloader,"localhost","8983","/solr") />

<cfquery name="getArt" datasource="cfartgallery">
SELECT artID, artname, description
FROM art
</cfquery>

<cfscript>
	// example for indexing content from a database
	for (i=1;i LTE getArt.recordcount;i=i+1) {
		thisDoc = arrayNew(1);
		
		thisDoc = sampleSolrInstance.addField(thisDoc,"id",getArt.artID[i]);
		thisDoc = sampleSolrInstance.addField(thisDoc,"title",getArt.artname[i]);
		thisDoc = sampleSolrInstance.addField(thisDoc,"text",getArt.description[i]);
		sampleSolrInstance.add(thisDoc);
	}
	
	// example for indexing content from a rich file
	myFile = expandPath("NRRcreditsbyartist.pdf");
	fmap = structNew();
	fmap["title"] = "title";
	fmap["content"] = "text";
	sampleSolrInstance.addFile("file-1",myFile,fmap,true,"attr_");
	
	sampleSolrInstance.commit(); // do a final commit of our changes
	sampleSolrInstance.optimize(); // since we're all done, optimize the index
</cfscript>

<html>
	<head>
		<title>CFSolrLib 2.0 | Indexing example</title>
	</head>
	<body>
		<h2>Indexing</h2>
		
		<p>Done. There's nothing to output, you'll want to look at the CF source.</p>
	</body>
</html>
