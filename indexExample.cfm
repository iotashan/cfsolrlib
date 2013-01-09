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
		thisDoc = sampleSolrInstance.addField(thisDoc,"description",getArt.description[i]);
		sampleSolrInstance.add(thisDoc);
	}
	
	// example for indexing content from a rich file
	myFile = expandPath("NRRcreditsbyartist.pdf");
	
	// To Parse File Content with Tika on the ColdFusion Side
	local.fileObject = application.tika.parseToString(createObject("java","java.io.File").init(myfile));
	
	thisFile = arrayNew(1);
	thisFile = sampleSolrInstance.addField(thisFile,"text",local.fileObject);
	thisFile = sampleSolrInstance.addField(thisFile,"id","file-1");
	thisFile = sampleSolrInstance.addField(thisFile,"title","File Title");
	sampleSolrInstance.add(thisFile);
	
	// To Stream File to Solr
	fmap = structNew();
	fmap["title"] = "title";
	fmap["content"] = "text";
	sampleSolrInstance.addFile("file-2",myFile,fmap,true,"attr_");
	
	sampleSolrInstance.commit(); // do a final commit of our changes
	sampleSolrInstance.optimize(); // since we're all done, optimize the index
	
	h = new http();
	h.setMethod("get");
	h.setURL("http://localhost:8983/solr/suggest?spellcheck.build=true");
	h.send();
</cfscript>

<html>
	<head>
		<title>CFSolrLib 3.0 | Indexing example</title>
	</head>
	<body>
		<h2>Indexing</h2>
		
		<p>Done. There's nothing to output, you'll want to look at the CF source.</p>
	</body>
</html>
