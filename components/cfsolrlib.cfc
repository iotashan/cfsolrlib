<cfscript>
	// solr defaults
	THIS.host = "localhost";
	THIS.port = 8983;
	THIS.path = "/solr";
	THIS.solrURL = "http://#THIS.host#:#THIS.port##THIS.path#";
	THIS.queueSize = 100;
	THIS.threadCount = 5;
	
	// java defaults
	THIS.javaLoaderInstance = "";
</cfscript>


<cffunction name="init" access="public" output="false" returntype="CFSolrLib">
	<cfargument name="javaloaderInstance" required="true" hint="An instance of JavaLoader." />
	<cfargument name="host" required="true" type="string" default="localhost" hint="Solr Server host" />
	<cfargument name="port" required="false" type="numeric" default="8983" hint="Port Solr server is running on" />
	<cfargument name="path" required="false" type="string" default="/solr" hint="Path to solr instance">
	<cfargument name="queueSize" required="false" type="numeric" default="100" hint="The buffer size before the documents are sent to the server">
	<cfargument name="threadCount" required="false" type="numeric" default="5" hint="The number of background threads used to empty the queue">
	<cfargument name="binaryEnabled" required="false" type="boolean" default="true" hint="Should we use the faster binary data transfer format?">
	
	<cfset var BinaryRequestWriter = "" />
	
	<cfset THIS.javaLoaderInstance = ARGUMENTS.javaloaderInstance />
	<cfset THIS.host = ARGUMENTS.host />
	<cfset THIS.port = ARGUMENTS.port />
	<cfset THIS.path = ARGUMENTS.path />
	<cfset THIS.solrURL = "http://#THIS.host#:#THIS.port##THIS.path#" />
	<cfset THIS.queueSize = ARGUMENTS.queueSize />
	<cfset THIS.threadCount = ARGUMENTS.threadCount />
	
	<cfscript>
	// create an update server instance
	THIS.solrUpdateServer = THIS.javaLoaderInstance.create("org.apache.solr.client.solrj.impl.StreamingUpdateSolrServer").init(THIS.solrURL,THIS.queueSize,THIS.threadCount);
	
	// create a query server instance
	THIS.solrQueryServer = THIS.javaLoaderInstance.create("org.apache.solr.client.solrj.impl.CommonsHttpSolrServer").init(THIS.solrURL);
	
	// enable binary
	if (ARGUMENTS.binaryEnabled) {
		BinaryRequestWriter = THIS.javaLoaderInstance.create("org.apache.solr.client.solrj.impl.BinaryRequestWriter");
		THIS.solrUpdateServer.setRequestWriter(BinaryRequestWriter.init()); // comment this out if you didn't enable binary
		THIS.solrQueryServer.setRequestWriter(BinaryRequestWriter.init()); // comment this out if you didn't enable binary
	}
	</cfscript>

	<cfreturn this/>
</cffunction>

<cffunction name="search" access="public" output="false" hint="Search for documents in the Solr index">
	<cfargument name="q" type="string" required="true" hint="Your query string" />
	<cfargument name="start" type="numeric" required="false" default="0" hint="Offset for results, starting with 0" />
	<cfargument name="rows" type="numeric" required="false" default="20" hint="Number of rows you want returned" />
	<cfargument name="params" type="struct" required="false" default="#structNew()#" hint="A struct of data to add as params. The struct key will be used as the param name, and the value as the param's value. If you need to pass in multiple values, make the value an array of values." />
	<cfset var thisQuery = THIS.javaLoaderInstance.create("org.apache.solr.client.solrj.SolrQuery").init(ARGUMENTS.q).setStart(ARGUMENTS.start).setRows(ARGUMENTS.rows) />
	<cfset var thisParam = "" />
	<cfset var response = "" />
	<cfset var ret = structNew() />
	<cfset var thisKey = "" />
	<cfset var tempArray = [] />
	<cfset var suggestions = "" />
	<cfset var thisSuggestion = "" />
	<cfset var iSuggestion = "" />
	
	<cfloop list="#structKeyList(ARGUMENTS.params)#" index="thisKey">
		<cfif isArray(ARGUMENTS.params[thisKey])>
			<cfset thisQuery.setParam(thisKey,javaCast("string[]",ARGUMENTS.params[thisKey])) />
		<cfelseif isBoolean(ARGUMENTS.params[thisKey]) AND NOT isNumeric(ARGUMENTS.params[thisKey])>
			<cfset thisQuery.setParam(thisKey,ARGUMENTS.params[thisKey]) />
		<cfelse>
			<cfset tempArray = arrayNew(1) />
			<cfset arrayAppend(tempArray,ARGUMENTS.params[thisKey]) />
			<cfset thisQuery.setParam(thisKey,javaCast("string[]",tempArray)) />
		</cfif>
	</cfloop>
	
	<!--- we do this instead of making the user call java functions, to work around a CF bug --->
	<cfset response = THIS.solrQueryServer.query(thisQuery) />
	<cfset ret.highlighting = response.getHighlighting() />
	<cfset ret.results = response.getResults() / >
	<cfset ret.totalResults = response.getResults().getNumFound() / >
	<cfif NOT isNull(response.getSpellCheckResponse())>
		<cfset suggestions = response.getSpellCheckResponse().getSuggestions() />
		<cfset ret.collatedSuggestion = response.getSpellCheckResponse().getCollatedResult() />
		<cfset ret.spellCheck = arrayNew(1) />
		<cfloop array="#suggestions#" index="iSuggestion">
			<cfset thisSuggestion = structNew() />
			<cfset thisSuggestion.token = iSuggestion.getToken() />
			<cfset thisSuggestion.startOffset = iSuggestion.getStartOffset() />
			<cfset thisSuggestion.endOffset = iSuggestion.getEndOffset() />
			<cfset thisSuggestion.suggestions = arrayNew(1) />
			<cfloop array="#iSuggestion.getSuggestions()#" index="iSuggestion">
				<cfset arrayAppend(thisSuggestion.suggestions,iSuggestion) />
			</cfloop>
			<cfset arrayAppend(ret.spellCheck,thisSuggestion) />
		</cfloop>
	</cfif>
	
	<cfreturn duplicate(ret) /> <!--- duplicate clears out the case-sensitive structure --->
</cffunction>

<cffunction name="queryParam" access="public" output="false" returnType="array" hint="Creates a name/value pair and appends it to the array. This is a helper method for adding to your index.">
	<cfargument name="paramArray" required="true" type="array" hint="An array to add your document field to." />
	<cfargument name="name" required="true" type="string" hint="Name of your field." />
	<cfargument name="value" required="true" type="any" hint="Value of your field." />
	
	<cfset var thisField = structNew() />
	<cfset thisField.name = ARGUMENTS.name />
	<cfset thisField.value = ARGUMENTS.value />
	
	<cfset arrayAppend(ARGUMENTS.paramArray,thisField) />
	
	<cfreturn ARGUMENTS.paramArray />
</cffunction>

<cffunction name="add" access="public" output="false" hint="Add a document to the Solr index">
	<cfargument name="doc" type="array" required="true" hint="An array of field objects, with name, value, and an optional boost attribute. {name:""Some Name"",value:""Some Value""[,boost:5]}" />
	<cfargument name="docBoost" type="numeric" required="false" hint="Value of boost for this document." />
	
	<cfset var thisDoc = THIS.javaLoaderInstance.create("org.apache.solr.common.SolrInputDocument").init() />
	<cfset var thisParam = "" />
	<cfif isDefined("ARGUMENTS.docBoost")>
		<cfset thisDoc.setDocumentBoost(javaCast("float",ARGUMENTS.docBoost)) />
	</cfif>
	
	<cfloop array="#ARGUMENTS.doc#" index="thisParam">
		<cfif isDefined("thisParam.boost")>
			<cfset thisDoc.addField(thisParam.name,thisParam.value,thisParam.boost) />
		<cfelse>
			<cfset thisDoc.addField(thisParam.name,thisParam.value) />
		</cfif>
	</cfloop>
	
	<cfreturn THIS.solrUpdateServer.add(thisDoc) />
</cffunction>

<cffunction name="addField" access="public" output="false" returnType="array" hint="Creates a field object and appends it to the array. This is a helper method for adding to your index.">
	<cfargument name="documentArray" required="true" type="array" hint="An array to add your document field to." />
	<cfargument name="name" required="true" type="string" hint="Name of your field." />
	<cfargument name="value" required="true" hint="Value of your field." />
	<cfargument name="boost" required="false" type="numeric" hint="An array to add your document field to." />
	
	<cfset var thisField = structNew() />
	<cfset thisField.name = ARGUMENTS.name />
	<cfset thisField.value = ARGUMENTS.value />
	<cfif isDefined("ARGUMENTS.boost")>
		<cfset thisField.boost = ARGUMENTS.boost />
	</cfif>
	
	<cfset arrayAppend(ARGUMENTS.documentArray,thisField) />
	
	<cfreturn ARGUMENTS.documentArray />
</cffunction>

<cffunction name="addFile" access="public" output="false" hint="Creates a field object for appending to an array. This is a helper method for adding to your index.">
	<cfargument name="id" required="true" hint="The unique ID of the document" />
	<cfargument name="file" required="true" type="string" hint="path to the document to be added" />
	<cfargument name="fmap" required="false" type="struct" hint="The mappings of document metadata fields to index fields." />
	<cfargument name="saveMetadata" required="false" type="boolean" default="true" hint="Store non-mapped metadata in dynamic fields" />
	<cfargument name="metadataPrefix" required="false" type="string" default="attr_" hint="Metadata dynamic field prefix" />
	<cfargument name="literalData" required="false" type="struct" hint="A struct of data to add as literal fields. The struct key will be used as the field name, and the value as the field's value. NOTE: You cannot have a literal field with the same name as a metadata field.  Solr will throw an error if you attempt to override metadata with a literal field" />
	<cfargument name="boost" required="false" type="struct" hint="A struct of boost values.  The struct key will be the field name to boost, and its value is the numeric boost value" />
	<cfargument name="idFieldName" required="false" type="string" default="id" hint="The name of the unique id field in the Solr schema" />
	<cfset var docRequest = THIS.javaLoaderInstance.create("org.apache.solr.client.solrj.request.ContentStreamUpdateRequest").init("/update/extract") />
	<cfset var thisKey = "" />
	<cfset docRequest.addFile(createObject("java","java.io.File").init(ARGUMENTS.file)) />
	<cfset docRequest.setParam("literal.#arguments.idFieldName#",ARGUMENTS.id) />
	<cfif ARGUMENTS.saveMetadata>
		<cfset docRequest.setParam("uprefix",metadataPrefix) />
	</cfif>
	<cfif isDefined("ARGUMENTS.fmap")>
		<cfloop list="#structKeyList(ARGUMENTS.fmap)#" index="thisKey">
			<cfset docRequest.setParam("fmap.#thisKey#",ARGUMENTS.fmap[thisKey]) />
		</cfloop>
	</cfif>
	<cfif isDefined("ARGUMENTS.boost")>
		<cfloop list="#structKeyList(ARGUMENTS.boost)#" index="thisKey">
			<cfset docRequest.setParam("boost.#thisKey#",ARGUMENTS.boost[thisKey]) />
		</cfloop>
	</cfif>
	<cfif isDefined("ARGUMENTS.literalData")>
		<cfloop list="#structKeyList(ARGUMENTS.literalData)#" index="thisKey">
			<cfset docRequest.setParam("literal.#thisKey#",ARGUMENTS.literalData[thisKey]) />
		</cfloop>
	</cfif>
	
	<cfreturn THIS.solrUpdateServer.request(docRequest) />
</cffunction>

<cffunction name="deleteByID" access="public" output="false" hint="Delete a document from the index by ID">
	<cfargument name="id" type="string" required="true" hint="ID of object to delete.">
	<cfargument name="idFieldName" type="string" required="false" default="id" hint="The solr unique id field name" />
	
	<cfset THIS.solrUpdateServer.deleteByQuery(ARGUMENTS.idFieldName & ":" & ARGUMENTS.id) />
</cffunction>

<cffunction name="deleteByQuery" access="public" output="false" hint="Delete a document from the index by Query">
	<cfargument name="q" type="string" required="true" hint="Query string to delete objects with.">
	
	<cfset THIS.solrUpdateServer.deleteByQuery(ARGUMENTS.q) />
</cffunction>

<cffunction name="resetIndex" access="public" output="false" hint="Clear out the index.">
	<cfset THIS.deleteByQuery("*:*") />
	<cfset THIS.commit() />
	<cfset THIS.optimize() />
</cffunction>

<cffunction name="rollback" access="public" output="false" hint="Roll back all pending changes to the index">
	<cfset THIS.solrUpdateServer.rollback() />
</cffunction>

<cffunction name="commit" access="public" output="false" hint="Commit all pending changes to the index">
	<cfset THIS.solrUpdateServer.commit() />
</cffunction>

<cffunction name="optimize" access="public" output="false" hint="Commit all pending changes to the index">
	<cfset THIS.solrUpdateServer.optimize() />
</cffunction>
