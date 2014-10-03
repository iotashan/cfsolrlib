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
	<cfargument name="username" required="false" type="string" hint="HTTP Basic Authentication Username" />
	<cfargument name="password" required="false" type="string" hint="HTTP Basic Authentication Password" />
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
	THIS.solrUpdateServer = THIS.javaLoaderInstance.create("org.apache.solr.client.solrj.impl.ConcurrentUpdateSolrServer").init(THIS.solrURL,THIS.queueSize,THIS.threadCount);
	
	// create a query server instance
	THIS.solrQueryServer = THIS.javaLoaderInstance.create("org.apache.solr.client.solrj.impl.HttpSolrServer").init(THIS.solrURL);
	
	if ( structKeyExists(arguments, "username") and structKeyExists(arguments, "password") ) {
		// set up basic authentication
		THIS.javaLoaderInstance.create("org.apache.solr.client.solrj.impl.HttpClientUtil")
			.setBasicAuth(
				THIS.solrQueryServer.getHttpClient(),
				arguments.username,
				arguments.password
			);		
	}
	
	// enable binary
	if (ARGUMENTS.binaryEnabled) {
		BinaryRequestWriter = THIS.javaLoaderInstance.create("org.apache.solr.client.solrj.impl.BinaryRequestWriter");
		THIS.solrUpdateServer.setRequestWriter(BinaryRequestWriter.init()); // comment this out if you didn't enable binary
		THIS.solrQueryServer.setRequestWriter(BinaryRequestWriter.init()); // comment this out if you didn't enable binary
	}
	</cfscript>

	<cfreturn this/>
</cffunction>

<cffunction name="checkForCore" access="public" output="false" hint="Multicore method. Checks for existance of a Solr core by name">
	<cfargument name="coreName" type="string" required="true" hint="Solr core name" />
    
    <cfscript>
		h = new http();
		h.setMethod("get");
		h.setURL("#THIS.solrURL#/#ARGUMENTS.coreName#/admin/ping");
		pingResponse = h.send().getPrefix().statusCode;
		coreCheckResponse = structNew();
		if (pingResponse eq "200 OK"){
			coreCheckResponse.success = true;
			coreCheckResponse.statusCode = pingResponse;
			return coreCheckResponse;
		}else{
			coreCheckResponse.success = false;
			coreCheckResponse.statusCode = pingResponse;
			return coreCheckResponse;
		}
	</cfscript>
</cffunction>

<cffunction name="createNewCore" access="public" output="false" hint="Multicore method. Creates new Solr core" returntype="struct">
	<cfargument name="coreName" type="string" required="true" hint="New Solr core name" />
    <cfargument name="instanceDir" type="string" required="true" hint="Location of folder containing config and schema files" />
    <cfargument name="dataDir" type="string" required="false" hint="Location to store core's index data" />
    <cfargument name="configName" type="string" required="false" hint="Name of config file" />
    <cfargument name="schemaName" type="string" required="false" hint="Name of schema file" />
    
    <cfscript>
		URLString = "#THIS.host#:#THIS.port#/solr/admin/cores?action=CREATE&name=#ARGUMENTS.coreName#&instanceDir=#instanceDir#";
		if (structKeyExists(ARGUMENTS, "dataDir")){
			URLString = "#URLString#&dataDir=#ARGUMENTS.dataDir#";
		}
		if (structKeyExists(ARGUMENTS, "configName")){
			URLString = "#URLString#&config=#ARGUMENTS.configName#";
		}
		if (structKeyExists(ARGUMENTS, "schemaName")){
			URLString = "#URLString#&schema=#ARGUMENTS.schemaName#";
		}
		newCoreRequest = new http();
		newCoreRequest.setMethod("get");
		newCoreRequest.setURL("#URLString#");
		response = newCoreRequest.send().getPrefix();
		coreCreationResponse = structNew();
		if (response.statusCode eq "200 OK"){
			coreCreationResponse.success = true;
			return coreCreationResponse;
		}else{
			coreCreationResponse.success = false;
			coreCreationResponse.message = response.ErrorDetail;
			return coreCreationResponse;
		}
	</cfscript>
</cffunction>

<cffunction name="search" access="public" output="false" hint="Search for documents in the Solr index">
	<cfargument name="q" type="string" required="true" hint="Your query string" />
	<cfargument name="start" type="numeric" required="false" default="0" hint="Offset for results, starting with 0" />
	<cfargument name="rows" type="numeric" required="false" default="20" hint="Number of rows you want returned" />
    <cfargument name="highlightingField" type="string" required="false" hint="Name of the field used for the highlighting result" />
	<cfargument name="params" type="struct" required="false" default="#structNew()#" hint="A struct of data to add as params. The struct key will be used as the param name, and the value as the param's value. If you need to pass in multiple values, make the value an array of values." />
	<cfargument name="facetFields" type="array" required="false" default="#arrayNew(1)#" hint="An array of fields to facet." />
	<cfargument name="facetMinCount" type="numeric" required="false" default="1" hint="Minimum number of results to return a facet." />
	<cfargument name="facetFilters" type="array" required="false" default="#arrayNew(1)#" hint="An array of facet filters." />
	<cfset var thisQuery = THIS.javaLoaderInstance.create("org.apache.solr.client.solrj.SolrQuery").init(ARGUMENTS.q).setStart(ARGUMENTS.start).setRows(ARGUMENTS.rows) />
	<cfset var thisParam = "" />
	<cfset var response = "" />
	<cfset var ret = structNew() />
	<cfset var thisKey = "" />
	<cfset var tempArray = [] />
	<cfset var suggestions = "" />
	<cfset var thisSuggestion = "" />
	<cfset var iSuggestion = "" />

	<cfif NOT arrayIsEmpty(ARGUMENTS.facetFields)>
		<cfset thisQuery.setFacet(true)>
		<cfset thisQuery.addFacetField(javaCast("string[]",facetFields))>
		<cfset thisQuery.setFacetMinCount(ARGUMENTS.facetMinCount)>
	</cfif>

	<cfif NOT arrayIsEmpty(ARGUMENTS.facetFilters)>
		<cfset thisQuery.addFilterQuery(javaCast("string[]",ARGUMENTS.facetFilters))>
	</cfif>
	
	<cfif structKeyExists(arguments.params, "group") and arguments.params.group is true >
	<!--- Grouped query results are in a completely different format from standard
		queries; however, adding the following params produces a standard format.
		* https://wiki.apache.org/solr/FieldCollapsing
		* http://lucene.472066.n3.nabble.com/SolrQuery-API-for-adding-group-filter-tp2921539p2923180.html
	 --->
		<cfset arguments.params["group.format"] = "simple" />
		<cfset arguments.params["group.main"] = true />
	</cfif>
	
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
    <cfset ret.results = response.getResults() / >
	<cfset ret.totalResults = response.getResults().getNumFound() / >
    <cfset ret.qTime = response.getQTime() />
	
	<!--- Spellchecker Response --->
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
    
	<!--- Highlighting Response --->
	<cfif NOT isNull(response.getHighlighting()) AND structKeyExists(ARGUMENTS,"highlightingField")>
    	<cfloop array="#ret.results#" index="currentResult">
        	<cfset currentResult.highlightingResult = response.getHighlighting().get("#currentResult.get('id')#").get("#ARGUMENTS.highlightingField#") />
        </cfloop>
    </cfif>

    <cfif NOT isNull(response.getFacetFields())>
		<cfset ret.facetFields = arrayNew(1)>
		<cfset ret.facetFields = response.getFacetFields()>
	</cfif>
    <cfreturn duplicate(ret) /> <!--- duplicate clears out the case-sensitive structure --->
</cffunction>

<cffunction name="getAutoSuggestResults" access="remote" returntype="any" output="false">
    <cfargument name="term" type="string" required="no">
        <cfif Len(trim(ARGUMENTS.term)) gt 0>
        	<!--- Remove any leading spaces in the search term --->
			<cfset ARGUMENTS.term = "#trim(ARGUMENTS.term)#">
			<cfscript>
                h = new http();
                h.setMethod("get");
                h.setURL("#THIS.solrURL#/suggest?q=#ARGUMENTS.term#");
                local.suggestResponse = h.send().getPrefix().Filecontent;
                if (isXML(local.suggestResponse)){
					local.XMLResponse = XMLParse(local.suggestResponse);
					local.wordList = "";
					if (ArrayLen(XMLResponse.response.lst) gt 1 AND structKeyExists(XMLResponse.response.lst[2].lst, "lst")){
						local.wordCount = ArrayLen(XMLResponse.response.lst[2].lst.lst);
						For (j=1;j LTE local.wordCount; j=j+1){
							if(j eq local.wordCount){
								local.resultCount = XMLResponse.response.lst[2].lst.lst[j].int[1].XmlText;
								local.resultList = arrayNew(1);
								For (i=1;i LTE local.resultCount; i=i+1){
									arrayAppend(local.resultList, local.wordList & XMLResponse.response.lst[2].lst.lst[j].arr.str[i].XmlText);
								}
							}else{
								local.wordList = local.wordList & XMLResponse.response.lst[2].lst.lst[j].XMLAttributes.name & " ";
							}
						}
						//sort results aphabetically
						if (ArrayLen(local.resultList)){
							ArraySort(local.resultList,"textnocase","asc");
						}
					}else{
						local.resultList = "";
					}
                }else{
                    local.resultList = "";
                }
            </cfscript>
        <cfelse>
        	<cfset local.resultList = "">
        </cfif>
        <cfreturn local.resultList />
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
		<cfset thisDoc.setDocumentBoost(ARGUMENTS.docBoost) />
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
    <cfset var thisKey = "" /><cfcomponent>

	<cffunction name="getMinisiteType" access="public" returntype="string">
		<cfargument name="type" required="false" default="program" /><!--- program; ccr; system --->
		<cfargument name="islabel" required="false" default="0" />
		
		<cfset var local=structNew() />
		<cfset local.myResult="" />	
		
		<cfswitch expression="#arguments.type#">
		
			<cfcase value="program">			
				<cfquery name="qry" datasource="onecpd_cms">
					SELECT program_id as id
						, program_description as name
					FROM rsc_tbl_program
					order by program_description
				</cfquery>				
			</cfcase>
			
			<cfcase value="ccr">	
				<cfquery name="qry" datasource="onecpd_cms">
					SELECT ccr_id as id
						, ccr_name as name
					FROM rsc_lku_ccr
					order by ccr_name
				</cfquery>			
			</cfcase>
			
			<cfcase value="system">
				<cfquery name="qry" datasource="onecpd_cms">
					SELECT system_id as id
						, system_name as name
					FROM rsc_lku_reporting_system
					order by system_name
				</cfquery>			
			</cfcase>
			
			<cfdefaultcase>
				<cfset qry = QueryNew( 'id,name', 'Integer,VarChar' ) />
			</cfdefaultcase>
			
		</cfswitch>
		
		<cfif islabel>		
			<cfset local.myResult = ValueList(qry.name, '^') />
		<cfelse>		
			<cfset local.myResult = ValueList(qry.id, '^') />
		</cfif>
		
		<cfreturn local.myResult>
	</cffunction>
	
	<cffunction name="getOrgTypeByShortName" access="public" returntype="string">
		<cfargument name="shortname" required="false" default="" />
		<cfset var local=structNew() />
		
		<cfquery name="qry" datasource="onecpd_cms">
			SELECT orgtype
			FROM c_torgtype
			WHERE shortname IN (<cfqueryparam value="#arguments.shortname#" cfsqltype="cf_sql_varchar" list="yes" />)
		</cfquery>
		
		<cfset local.orgtype = ValueList(qry.orgtype, ", ") />
		<cfreturn local.orgtype />
	</cffunction>
	<cffunction name="getHMISorgType" access="public" returntype="string">
		<cfargument name="shortname" required="false" default="" />
		<cfset var local=structNew() />
		
		<cfset local.orgtype = "" />
		
		<cfif ListFind(arguments.shortname, "hmis-lead")>
			<cfset local.orgtype = ListAppend(local.orgtype, "Lead Organization") />
		</cfif>
		<cfif ListFind(arguments.shortname, "hmis-vendor")>
			<cfset local.orgtype = ListAppend(local.orgtype, "Vendor", ", ") />
		</cfif>
		<cfif ListFind(arguments.shortname, "hmis-participating")>
			<cfset local.orgtype = ListAppend(local.orgtype, "Participating Organization") />
		</cfif>
		<cfif ListFind(arguments.shortname, "hmis-non-participating")>
			<cfset local.orgtype = ListAppend(local.orgtype, "Non-Participating Organization") />
		</cfif>
		
		<cfreturn local.orgtype />
	</cffunction>
	<cffunction name="getOrgsIDs" access="public" returntype="string">
		<cfargument name="typeid" required="false" default="1" />
		<cfset var local=structNew() />
		<cfset local.myResult="" />	
		<cfset local.typeid="" />
		
		<cfif NOT IsNumeric(arguments.typeid)>
			<cfset local.typeid = 1 />
		</cfif>
		<cfquery name="qry" datasource="onecpd_cms">
			SELECT orgid
			FROM c_torganizations
			WHERE active = 1
				AND FIND_IN_SET(<cfqueryparam value="#arguments.typeid#" cfsqltype="cf_sql_integer" />,orgtypes) 
			ORDER BY orgname
		</cfquery>
		
		<cfset local.myResult = ValueList(qry.orgid, '^') />
		
		<cfreturn local.myResult>
	</cffunction>
	<cffunction name="getOrgsLabels" access="public" returntype="string">
		<cfargument name="typeid" required="false" default="1" />
		<cfset var local=structNew() />
		<cfset local.myResult="" />	
		<cfset local.typeid="" />
		
		<cfif NOT IsNumeric(arguments.typeid)>
			<cfset local.typeid = 1 />
		</cfif>
		
		<cfquery name="qry" datasource="onecpd_cms">
			SELECT orgname
			FROM c_torganizations
			WHERE active = 1
				AND FIND_IN_SET(<cfqueryparam value="#arguments.typeid#" cfsqltype="cf_sql_integer" />,orgtypes) 
			ORDER BY orgname
		</cfquery>
		
		<cfset local.myResult = ValueList(qry.orgname, '^') />
		
		<cfreturn local.myResult>
	</cffunction>
	
	<cffunction name="getOrgQueryByID" access="public" returntype="query">
		<cfargument name="typeid" required="false" default="1" />
		<cfset var local=structNew() />
		<cfset local.typeid="" />
		
		<cfif NOT IsNumeric(arguments.typeid)>
			<cfset local.typeid = 1 />
		</cfif>
		
		<cfquery name="local.qry" datasource="onecpd_cms">
			SELECT o.orgid, o.orgname, t.orgtype
			FROM c_torganizations o
			JOIN c_torgtype t on FIND_IN_SET(t.orgTypeID, o.orgtypes)
			WHERE o.active = 1
				AND t.orgTypeID = <cfqueryparam value="#arguments.typeid#" cfsqltype="cf_sql_integer" />
			ORDER BY t.sort, o.orgname
		</cfquery>
				
		<cfreturn local.qry>
	</cffunction>
	
	<cffunction name="getOrgQueryByIDState" access="public" returntype="query">
		<cfargument name="typeid" required="false" default="1" />
		<cfargument name="state" required="false" default="" />
		<cfset var local=structNew() />
		<cfset local.typeid="" />
		
		<cfif NOT IsNumeric(arguments.typeid)>
			<cfset local.typeid = 1 />
		</cfif>
		
		<cfquery name="local.qry" datasource="onecpd_cms">
			SELECT o.orgid, o.orgname, t.orgtype
			FROM c_torganizations o
			JOIN c_torgtype t on FIND_IN_SET(t.orgTypeID, o.orgtypes)
			JOIN state s on s.abbrev = o.grantee_state
			WHERE o.active = 1
				AND t.orgTypeID = <cfqueryparam value="#arguments.typeid#" cfsqltype="cf_sql_integer" />
				AND UPPER(s.name) = <cfqueryparam value="#arguments.state#" cfsqltype="cf_sql_varchar" />
			ORDER BY t.sort, o.orgname
		</cfquery>
					
		<cfreturn local.qry>
	</cffunction>
		
	<cffunction name="getOrgQueryByCoCNo" access="public" returntype="query">
		<cfargument name="coc_no" required="false" default="" />
		<cfset var local=structNew() />
		
		<cfquery name="local.qry" datasource="onecpd_cms">
			SELECT o.orgid, o.orgname
			FROM c_torganizations o
			WHERE o.active = 1
				AND (1=0 <cfloop list="#arguments.coc_no#" index="i">
					OR FIND_IN_SET(<cfqueryparam value="#i#" cfsqltype="cf_sql_varchar" />, o.coc_no_coc)
				</cfloop>)
				AND FIND_IN_SET(5, o.orgtypes)
			ORDER BY o.orgname
		</cfquery>
							
		<cfreturn local.qry>
	</cffunction>
	
	<cffunction name="getCoCNo" access="public" returntype="query">
		<cfargument name="state" required="false" default="" />
		<cfset var local=structNew() />
		
		<cfquery name="local.qry" datasource="onecpd_cms">
			SELECT c.coc_no, c.coc_name
			FROM c_tcoc c
			JOIN state s on s.abbrev = c.state_id
			WHERE UPPER(s.name) = <cfqueryparam value="#arguments.state#" cfsqltype="cf_sql_varchar" />
			ORDER BY c.coc_no
		</cfquery>
				
		<cfreturn local.qry>
	</cffunction>
		
	<cffunction name="getHUD" access="public" returntype="query">
		
		<cfquery name="qry" datasource="onecpd_cms">
			SELECT o.orgid, o.orgname, t.orgtype
			FROM c_torganizations o
			JOIN c_torgtype t on FIND_IN_SET (t.orgTypeID, o.orgTypes)
			WHERE o.active = 1 
				AND (t.orgTypeID = 1 or t.orgTypeID = 2)
			ORDER BY t.sort, o.orgname
		</cfquery>
				
		<cfreturn qry>
	</cffunction>
	
	<cffunction name="getTAProviders" access="public" returntype="query">
		
		<cfquery name="qry" datasource="onecpd_cms">
			SELECT o.orgid, o.orgname, t.orgtype
			FROM c_torganizations o
			JOIN c_torgtype t on FIND_IN_SET (t.orgTypeID, o.orgTypes)
			WHERE o.active = 1 
				AND t.orgTypeID = 3
			ORDER BY t.sort, o.orgname
		</cfquery>
				
		<cfreturn qry>
	</cffunction>
	
	<cffunction name="getOrgNameByID" access="public" returntype="string">
		<cfargument name="orgid" required="true" />
		<cfset var myResult="">
		
		<cfquery name="qry" datasource="onecpd_cms">
			SELECT orgname
			FROM c_torganizations
			WHERE 
			<cfif ListLen(arguments.orgid) gte 2>
				orgid IN (<cfqueryparam value="#arguments.orgid#" cfsqltype="cf_sql_integer" list="true" />)
			<cfelse>
				orgid = <cfqueryparam value="#val(arguments.orgid)#" cfsqltype="cf_sql_integer" />
			</cfif>
			ORDER BY orgname
		</cfquery>
		
		<cfset myResult = ValueList(qry.orgname, ', ') />
		
		<cfreturn myResult>
	</cffunction>
	
	<cffunction name="getState" access="public" returntype="query">
	
		<cfquery name="qry" datasource="onecpd_cms">
			SELECT name, abbrev
			FROM state
			ORDER BY order_by
		</cfquery>
				
		<cfreturn qry>
	</cffunction>
	
	<cffunction name="getTimezone" access="public" returntype="query">
	
		<cfquery name="qry" datasource="onecpd_cms">
			SELECT name, value, zone
			FROM timezone
			ORDER BY sort_order
		</cfquery>
				
		<cfreturn qry>
	</cffunction>
	
	<cffunction name="getHUDUMAdmin" access="public" returntype="string">
		<cfargument name="orgid" required="true" />
		<cfset var myResult="">
		
		<cfquery name="qry" datasource="onecpd_cms">	
			SELECT DISTINCT u.email FROM tusers u
			JOIN tusersmemb m on m.userID = u.userID
			JOIN tusers g on g.userID = m.groupID
			JOIN tclassextenddatauseractivity o on o.baseID = u.userID
			JOIN tclassextendattributes a on a.attributeID = o.attributeID and a.name = 'orgid'
			JOIN c_torganizations taorg on taorg.orgid=o.attributeValue
			JOIN c_tusersmemb_subscribe mg on mg.groupID = g.userID 
										AND mg.userID = m.userID 
										AND mg.subscribe = 1
			WHERE g.GroupName like 'User Management / HUD%'
			AND taorg.orgID IN (<cfqueryparam value="#arguments.orgid#" cfsqltype="cf_sql_integer" list="true" />)
		</cfquery>
		
		<cfset myResult = ValueList(qry.email, ', ') />
		
		<cfreturn myResult>
	</cffunction>
	
	<cffunction name="getTAUMAdmin" access="public" returntype="string">
		<cfargument name="orgid" required="true" />
		<cfset var myResult="">
				
		<cfquery name="qry" datasource="onecpd_cms">
			SELECT DISTINCT u.email FROM `tusers` u
			JOIN tusersmemb m on m.userID = u.userID
			JOIN tusers g on g.userID = m.groupID
			JOIN tclassextenddatauseractivity o on o.baseID = u.userID
			JOIN c_torganizations taorg on (find_in_set(taorg.orgid, o.attributeValue))
			JOIN c_tusersmemb_subscribe mg on mg.groupID = m.groupID 
										AND mg.userID = m.userID 
										AND mg.subscribe = 1
			WHERE g.GroupName like 'User Management / TA%'
			AND taorg.orgID IN (<cfqueryparam value="#arguments.orgid#" cfsqltype="cf_sql_integer" list="true" />)
		</cfquery>
		
		<cfset myResult = ValueList(qry.email, ', ') />
		
		<cfreturn myResult>
	</cffunction>
	
	<cffunction name="getGroupNameByID" access="public" returntype="string">
		<cfargument name="groups" required="true" />
		<cfset var myResult="">
		
		<cfquery name="qry" datasource="onecpd_cms">
			SELECT groupname
			FROM tusers
			WHERE userid IN (<cfqueryparam value="#arguments.groups#" cfsqltype="cf_sql_varchar" list="true" />)
			ORDER BY groupname
		</cfquery>
		
		<cfset myResult = ValueList(qry.groupname) />
		
		<cfreturn myResult>
	</cffunction>
		
	<cffunction name="getAAQUserRole" access="public" returntype="string">
		<cfargument name="userID" required="true" />
		<cfset var myResult="">
		
		<cfquery name="qry" datasource="onecpd_cms">
			SELECT concat(
							IFNULL(fo.orgname, concat(pt.name, '/', IFNULL(p.acronym, p.name)))
						, ' - '
						, r.name)	 as role_name
			FROM aaq_tbl_user_role ur
			JOIN aaq_lku_role r on r.id = ur.role_id
			LEFT JOIN c_torganizations fo on fo.orgid = ur.fieldoffice_id
			LEFT JOIN aaq_lku_pool p on p.id = ur.pool_id
			LEFT JOIN aaq_lku_pool_type pt on pt.id = p.pool_type_id
			WHERE ur.user_id = <cfqueryparam value="#arguments.userID#" cfsqltype="cf_sql_varchar" />
			ORDER BY pt.order_by, p.order_by, p.name
		</cfquery>
		
		<cfset myResult = ValueList(qry.role_name) />
		
		<cfreturn myResult>
	</cffunction>
		
	<cffunction name="getNAAdministratingTA" access="public" returntype="string">
		<cfargument name="userID" required="true" />
		<cfset var myResult="">
		
		<cfquery name="qry" datasource="onecpd_cms">
			SELECT o.orgname 
			FROM tclassextenddatauseractivity ta 
			JOIN c_torganizations o on Find_In_Set(o.orgid, ta.attributeVAlue)
			WHERE attributeID = 7 
				AND ta.baseID = <cfqueryparam value="#arguments.userID#" cfsqltype="cf_sql_varchar" />
		</cfquery>
		
		<cfset myResult = ValueList(qry.orgname) />
		
		<cfreturn myResult>
	</cffunction>
	
	<cffunction name="updatePasswordLastUpdateByID" access="public" returntype="any" output="false">
		<cfargument name="userID" required="true" />
		<cfargument name="LastUpdateByID" required="true" />
						
		<cfquery name="updatePasswordLastUpdateByID" datasource="onecpd_cms" result="result">
			UPDATE c_tuserspwupdateinfo
			SET PasswordLastUpdateByID = <cfqueryparam value="#arguments.LastUpdateByID#" cfsqltype="cf_sql_varchar" />
			WHERE UserID = <cfqueryparam value="#arguments.userID#" cfsqltype="cf_sql_varchar" />
		</cfquery>
		
		<cfif result.RECORDCOUNT eq 0>
			<cfquery name="createPasswordLastUpdateByID" datasource="onecpd_cms" result="result">
				INSERT INTO c_tuserspwupdateinfo (UserID, PasswordLastUpdateByID) 
				VALUES (<cfqueryparam value="#arguments.userID#" cfsqltype="cf_sql_varchar" />
						, <cfqueryparam value="#arguments.LastUpdateByID#" cfsqltype="cf_sql_varchar" />)
			</cfquery>			
		</cfif>
		
	</cffunction>
	
	<cffunction name="getGroupSubscribe" access="public" returntype="query">
		<cfargument name="userID" required="true" />
		
		<cfquery name="qry" datasource="onecpd_cms">
			SELECT CONCAT('groupsubscribe_', REPLACE(s.GROUPID, "-", "")) AS groupsubscribe
				, s.SUBSCRIBE
			FROM c_tusersmemb_subscribe s
			WHERE s.USERID = <cfqueryparam value="#arguments.userID#" cfsqltype="cf_sql_varchar" />
		</cfquery>
				
		<cfreturn qry />
	</cffunction>

	
	<cffunction name="sendLoginByEmail" output="false" returntype="string"  access="public"  hint="used from custom login form - getRandomPassword function in userUtility.cfc has a bug.  This can be removed when the bug is fixed in the core.">
		<cfargument name="email" type="string">
		<cfargument name="siteid" type="string" required="yes" default="">
		<cfargument name="returnURL" type="string" required="yes" default="#listFirst(cgi.http_host,":")##cgi.SCRIPT_NAME#">
		<cfset var msg="No account currently exists with the email address '#arguments.email#'.">
		<cfset var struser=structnew()>
		<cfset var rsuser = ""/>
		<cfset var userBean = ""/>
	
		<cfif isValid("email", trim(arguments.email))>
					<cfset rsuser=application.serviceFactory.getBean("userUtility").getUserByEmail('#arguments.email#','#arguments.siteid#')>
					<cfif rsuser.recordcount>
						<cfloop query="rsuser">
							<cfset userBean=application.userManager.read(rsuser.userid)>

							<cfif userBean.getUsername() neq ''>

								<cfset userBean.setPassword(getRandomPassword(Length="7", CharSet="AlphaNumeric", Ucase="yes")) />
								<cfset userBean.save() />
						
								<cfset struser=userBean.getAllValues()>
									
								<cfset struser.fieldnames='Username,Password'>
								<cfset struser.from=application.settingsManager.getSite(arguments.siteid).getSite()>
								
								<cfset application.serviceFactory.getBean("userUtility").sendLogin(struser,'#arguments.email#','#struser.from#','#struser.from# Account Information','#arguments.siteid#','','')>
								<cfset msg="Your account information has been sent to you.">
							</cfif>
						</cfloop>
					</cfif>
		<cfelse>
					<cfset  msg="The email address '#arguments.email#' is not a valid format.">
		</cfif>
	<cfreturn msg>
	</cffunction>
	
	<cffunction name="getRandomPassword" access="public" returntype="string" output="false" hint="used from usermanagement plugin and custom login form - getRandomPassword function in userUtility.cfc has a bug.  This can be removed when the bug is fixed in the core.">		
		<cfargument name="Length" default="7" required="yes" type="numeric">
		<cfargument name="CharSet" default="Alpha" required="yes" type="string">
		<cfargument name="Ucase" default="no" required="yes" type="string">
		
		<cfset var alphaLcase = "abcdefghijklmnopqrstuvwxyz">
		<cfset var alphaUcase = UCase( alphaLcase )>
		<cfset var numeric =    "0123456789">
		<cfset var ThisPass="">
		<cfset var charlist=""/>
		<cfset var thisNum=0/>
		<cfset var thisChar=""/>
		<cfset var i=0/>
		
		<cfset var arrPassword = ArrayNew( 1 ) />
			
		<cfswitch expression="#arguments.CharSet#">
		
		 <cfcase value="alpha">
		  <cfset charlist = alphaLcase>
		   <cfif arguments.UCase IS "Yes">
			<cfset charList = listappend(charlist, alphaUcase, "")>
			<cfset arrPassword[ 1 ] = Mid( alphaLcase, RandRange( 1, Len( alphaLcase ) ), 1 ) />
			<cfset arrPassword[ 2 ] = Mid( alphaUcase, RandRange( 1, Len( alphaUcase ) ),	1 ) />
		   </cfif>
		 </cfcase>
		
		 <cfcase value="alphanumeric">
		  <cfset charlist = "#alphaLcase##numeric#">
		  <cfset arrPassword[ 1 ] = Mid( alphaLcase, RandRange( 1, Len( alphaLcase ) ), 1 ) />
		  <cfset arrPassword[ 2 ] = Mid( numeric, RandRange( 1, Len( numeric ) ), 1 ) />
		   <cfif arguments.UCase IS "Yes">
			<cfset charList = listappend(charlist, alphaUcase, "")>
			<cfset arrPassword[ 3 ] = Mid( alphaUcase, RandRange( 1, Len( alphaUcase ) ),	1 ) />
		   </cfif>  
		 </cfcase>
		 
		 <cfcase value="numeric">
		  <cfset charlist = numeric>
		 </cfcase>
		  
		 <cfdefaultcase><cfthrow detail="Valid values of the attribute <b>CharSet</b> are Alpha, AlphaNumeric, and Numeric"> </cfdefaultcase> 
		</cfswitch>
		 
		<cfloop index="intChar" from="#(ArrayLen( arrPassword ) + 1)#" to="#arguments.Length#" step="1">
			<cfset arrPassword[ intChar ] = Mid( charlist, RandRange( 1, Len( charlist ) ), 1 ) />
		</cfloop>
		
		<cfset CreateObject( "java", "java.util.Collections" ).Shuffle(	arrPassword	) />
		
		<cfset ThisPass = ArrayToList( arrPassword, "" ) />
		
		<cfreturn ThisPass />
	</cffunction>
	

	<cffunction name="getfeaturedNews" output="false" returntype="any">
			
			<cfquery name="qryFeaturedNews" datasource="onecpd_cms" cachedwithin="#application.qryCacheTime30#">
			SELECT 
				tc.TContent_ID
			   ,tc.Title
			   ,tc.Summary
			   ,tc.Body
			   ,tc.notes
			   ,tc.urltitle
			   ,tc.fileID
			   ,Date_Format(tc.ReleaseDate,'%M %d, %Y') as ReleaseDate
			   ,tf.fileName
			   ,tf.fileExt
			   ,(select attributeValue
				 from tclassextenddata  
			     inner join tclassextendattributes  on tclassextenddata.attributeID=tclassextendattributes.attributeID 
			     where tclassextenddata.baseID=tc.contentHistID and name='featuredsummary' and attributeValue is not null) as featuredsummary
     		  ,(select group_concat(DISTINCT CASE WHEN tcca1.notes!='' THEN tcca1.notes ELSE tcca1.name END,'^',tcca1.categoryID SEPARATOR '|') from tcontentcategoryassign tcca left join tcontentcategories tcca1 on tcca.categoryID=tcca1.categoryID where tcca1.isActive = 1 and tcca.contentHistID in (select contentHistID from tcontent where ContentID=tc.ContentID and Active=1 and Display = 1)) as categoryList 
			  ,(select group_concat(DISTINCT  tcca1.name) from tcontentcategoryassign tcca left join tcontentcategories tcca1 on tcca.categoryID=tcca1.categoryID where tcca1.isActive = 1 and tcca.contentHistID in (select contentHistID from tcontent where ContentID=tc.ContentID and Active=1 and Display = 1)) as categoryName 

			FROM
				      tcontent tc
			left join tfiles tf on tc.fileID = tf.fileID
			
			WHERE
				tc.subType='News'
				and tc.ReleaseDate <= now()
				and tc.Active=1
				and tc.Display=1
				and tc.isFeature=1
				
			ORDER BY tc.ReleaseDate	DESC
				
			LIMIT 0,6
			
		</cfquery>
		
		<cfreturn qryFeaturedNews />
		
	</cffunction>

	<cfscript>
	function ParagraphFormat2(str) {
	    //first make Windows style into Unix style
	    str = replace(str,chr(13)&chr(10),chr(10),"ALL");
	    //now make Macintosh style into Unix style
	    str = replace(str,chr(13),chr(10),"ALL");
	    //now fix tabs
	    str = replace(str,chr(9),"&nbsp;&nbsp;&nbsp;","ALL");
	    //now return the text formatted in HTML
	    return replace(str,chr(10),"<br />","ALL");
	}
	</cfscript>

	<cffunction name="getHomeBanner" output="false" returntype="any">
		<cfquery name="qryHomeBanner" datasource="onecpd_cms">
			SELECT 
				tc.TContent_ID
			   ,tc.Title
			   ,tc.Summary
			   ,tc.Body
			   ,tc.filename
			   ,concat('/onecpd/cache/file/', tf.fileID, '.', tf.fileExt) as img
			   ,e.attributeValue as readmorelink
			FROM tcontent tc
			LEFT OUTER JOIN tfiles tf on tc.fileID = tf.fileID AND tf.deleted = 0
			LEFT OUTER JOIN tclassextenddata e on e.baseID = tc.contentHistID
			WHERE
				tc.Type = 'Page'
				and tc.subType='Banner'
				and tc.Active=1
				and tc.Display=1
				and tc.Approved=1				
			ORDER BY tc.orderNo				
			LIMIT 4			
		</cfquery>
		
		<cfreturn qryHomeBanner />
		
	</cffunction>
	<cffunction name="getHomeNews" output="false" returntype="any">
		<cfquery name="qryHomeNews" datasource="onecpd_cms" cachedwithin="#CreateTimeSpan(0,0,30,0)#">
			SELECT DISTINCT
				tc.TContent_ID
			   ,tc.Title
			   ,tc.filename
			   ,Date_Format(tc.ReleaseDate,'%M %d, %Y') as ReleaseDate
			  ,group_concat(distinct tcc.notes separator ', ') as categorylist
			    
			FROM
				      tcontent tc
			left join tcontentcategoryassign tcca on tcca.contentID = tc.ContentID
			left join tcontentcategories tcc on tcca.categoryID = tcc.categoryID
			
			WHERE
				tc.Type = 'Page'
				and tc.subType='News'
				and Date_Format(tc.ReleaseDate,'%Y-%m-%d') <= Date_Format(now(),'%Y-%m-%d')
				and tc.Active=1
				and tc.Display=1
				and tc.Approved=1
			GROUP BY tc.TContent_ID
			ORDER BY tc.ReleaseDate desc	
			LIMIT 10
		</cfquery>
		
		<cfreturn qryHomeNews />
		
	</cffunction>
	
	<cffunction name="getCategoriesByHistID" returntype="query" access="public" output="false">
		<cfargument name="contentHistID" type="string" required="true">
		<cfset var rs = "">
		
		<cfquery name="rs" datasource="onecpd_cms">
			select tcontentcategoryassign.*, tcontentcategories.name, tcontentcategories.filename, tcontentcategories.notes
			from tcontentcategories inner join tcontentcategoryassign
			ON (tcontentcategories.categoryID=tcontentcategoryassign.categoryID)
			where tcontentcategoryassign.contentHistID= <cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.contentHistID#"/>
			Order By tcontentcategories.filename
		</cfquery> 
	
		<cfreturn rs />
	</cffunction>

	<!--- CSRF functions --->
	<!--- Generate a random token and put that token into the user session. --->
	<cffunction name="CSRFGenerateToken" returntype="any" output="yes">
		<cfargument name="tokenname" type="string" default="csrftoken">
		<cfargument name="inputs" type="string" default="#CreateUUID()#&#DateFormat(Now(),'yyyymmdd')#&#TimeFormat(Now(),'HHmmss')#">
		
		<!--- Hash the inputs --->
		<cfset local.hashedCSRFtoken=Hash(arguments.inputs,"SHA-512") />
		<cfif NOT structKeyExists(SESSION,'security')>
        	<cfset SESSION.security = structNew()>
			<cfif NOT structKeyExists(SESSION.security,'CSRFtokens')>
                <cfset SESSION.security.CSRFtokens = structNew()>
            </cfif>
        </cfif>    
        
		<cfset SESSION.security.CSRFtokens[local.hashedCSRFtoken]="#DateFormat(Now(),"yyyymmdd")##TimeFormat(Now(),"HHmmss")#">
		<!--- Generate the string to output the hidden form field --->
		<cfset local.str='<input type="hidden" name="#arguments.tokenname#" value="#local.hashedCSRFtoken#" />'>
		
		<cfreturn str>
	</cffunction>
	
	<!--- Validates the given token against the same stored in the session and delete it upon validation --->
	<cffunction name="CSRFVerifyToken" returntype="any" output="yes">
		<cfargument name="token" type="string" default="">
		<cfargument name="struct" type="string" default="SESSION.security">
		
		<!--- IF THE STRUCTKEY EXISTS, DELETE IT AND RETURN TRUE --->
		<cfif StructKeyExists(SESSION,"security")
			AND StructKeyExists(SESSION.security,"CSRFtokens")
			AND StructKeyExists(SESSION.security.CSRFtokens,"#token#")>
			<cfset temp=StructDelete(SESSION.security.CSRFtokens,"#token#")>
			<cfreturn true>
		<cfelse>
			<cfreturn false>
		</cfif>
		
	</cffunction>
	
	<cfscript>
	function getServerEnvironment() {
		serverEnvironment = "";
		
		// first figure out where we are
		if(findNoCase("local",CGI.SERVER_NAME) OR findNoCase("localhost",CGI.SERVER_NAME)) {
			serverEnvironment = "local";
		} else if (findNoCase("dev",CGI.SERVER_NAME)) {
			serverEnvironment = "dev";
		} else if (findNoCase("test",CGI.SERVER_NAME)) {
			serverEnvironment = "test";
		} else if (findNoCase("stage",CGI.SERVER_NAME)) {
			serverEnvironment = "stage";
		} else {
			serverEnvironment = "prod";
		};
		
		return serverEnvironment;
	};
	
	function onServers(regions) {
		// determine if I am on one of the regions I am looking for
		if(listFindNoCase(arguments.regions,getServerEnvironment()))
			return true;
		
		return false;
	};
	
	function getEmailSubjectAppend() {
		rtnStr = "";
		if(NOT onServers('prod'))
			rtnStr = " (#getServerEnvironment()# Server)";
			
		return rtnStr;
	};
	
	//function getUserOrgInformation(userID) {
//		rtnStruct = structNew();
//		rtnStruct.orgType = "";
//		rtnStruct.orgLongName = "";
//		rtnStruct.orgShortName = "";
//		// get the org type of the user
//		queryService = new query();
//		queryService.setDatasource("onecpd_cms"); 
// 		queryService.setName("getOrgInfo"); 
//		queryService.addParam(name="userID",value=userID,cfsqltype="cf_sql_varchar"); 
//		result = queryService.execute(sql="SELECT attributeValue FROM tclassextenddatauseractivity ua, tclassextendattributes a WHERE ua.siteID = 'onecpd' AND ua.baseID = :userID AND ua.attributeID = a.attributeID AND a.name = 'OrganizationAffiliation'"); 
//		theQry = result.getResult();
//		if(result.getPrefix().recordCount IS 0 OR theQry.attributeValue IS "" OR theQry.attributeValue IS "None") {
//			rtnStruct.orgType = "None";
//			rtnStruct.orgLongName = "No Organization";
//			rtnStruct.orgShortName = "No Organization";
//			return rtnStruct;
//		};
//		
//		rtnStruct.orgType = theQry.attributeValue;
//		// now get the attribute id of the org information
// 		queryService.clear(); 
//		queryService.addParam(name="orgType",value="#replace(rtnStruct.orgType,' ','','ALL')#",cfsqltype="cf_sql_varchar"); 
//		result = queryService.execute(sql="SELECT attributeID FROM tclassextendattributes WHERE siteID = 'onecpd' AND name = :orgType");
//		theQry = result.getResult();
//		orgTypeAttributeID = theQry.attributeID;
//		queryService.clear(); 
//		if(rtnStruct.orgType IS 'Other') {
//			queryService.addParam(name="userID",value=userID,cfsqltype="cf_sql_varchar");
//			queryService.addParam(name="attributeID",value=orgTypeAttributeID,cfsqltype="cf_sql_integer");
//			result = queryService.execute(sql="SELECT attributeValue FROM tclassextenddatauseractivity WHERE siteID = 'onecpd' AND baseID = :userID AND attributeID = :attributeID");
//			theQry = result.getResult();
//			rtnStruct.orgLongName = theQry.attributeValue;
//			rtnStruct.orgShortName = theQry.attributeValue;
//		} else {
//			queryService.addParam(name="userID",value=userID,cfsqltype="cf_sql_varchar");
//			queryService.addParam(name="attributeID",value=orgTypeAttributeID,cfsqltype="cf_sql_integer");
//			result = queryService.execute(sql="SELECT o.orgname, o.orgshortname FROM tclassextenddatauseractivity ua, c_torganizations o WHERE ua.siteID = 'onecpd' AND ua.baseID = :userID AND attributeID = :attributeID AND o.orgid = ua.attributeValue");
//			theQry = result.getResult();
//			rtnStruct.orgLongName = theQry.orgname;
//			if(theQry.orgshortname IS NOT "") {
//				rtnStruct.orgShortName = theQry.orgshortname;
//			} else {
//				rtnStruct.orgShortName = theQry.orgname;
//			};
//		};
//		return rtnStruct;
//	};
		
	function isSpider() {
		theUserAgent = LCase(CGI.http_user_agent);
	
		if(REFind( "bot/b",theUserAgent)
			OR Find( "crawl",theUserAgent) 
			OR REFind( "/brss",theUserAgent) 
			OR Find( "feed",theUserAgent) 
			OR Find( "news",theUserAgent) 
			OR Find( "syndication",theUserAgent) 
			OR FindNocase( "Slurp",theUserAgent) 
			OR FindNocase( "Googlebot",theUserAgent) 
			OR Find( "zyborg",theUserAgent) 
			OR Find( "emonitor",theUserAgent) 
			OR FindNocase( "ezooms",theUserAgent) 
			OR FindNocase( "baidu",theUserAgent) 
			OR FindNocase( "Yahoo",theUserAgent) 
			OR FindNocase( "bingbot",theUserAgent) 
			OR FindNocase( "jeeves",theUserAgent)) {
			
			return true;
		} else {
			
			return false;
		}
	}
	
	function hasIECCalculation(userID){
		
		queryService = new query();
		queryService.setDatasource("onecpd_cms"); 
 		queryService.setName("hasIECCalculation"); 
		queryService.addParam(name="userID",value=userID,cfsqltype="cf_sql_varchar"); 
		result = queryService.execute(sql="SELECT household_id FROM iec_tbl_household WHERE site_user_id = :userID"); 
		theQry = result.getResult();
		if(result.getPrefix().recordCount GT 0) {
			return true;
		} else {
			return false;			
		}
		
	}
	</cfscript>
	
	<cffunction name="getUserOrgInformation" access="public" output="false" returntype="struct">
		<cfargument name="userID" required="true">
		
		<cfset rtnStruct = StructNew() />
		<cfset rtnStruct.orgType = "None" />
		<cfset rtnStruct.orgLongName = "No Organization" />
		<cfset rtnStruct.orgShortName = "No Organization" />
		
		<cfquery name="getOrgInfo" datasource="onecpd_cms">
			SELECT  u.username
				, group_concat(ot.orgType separator ', ') as orgtypes
				, group_concat(ot.shortname separator ', ') as shortname
				, IFNULL(IFNULL(o.orgname, onua.attributeValue),ot.shortname)  AS orgname
				, IFNULL(o.orgshortname, IFNULL(IFNULL(o.orgname, onua.attributeValue),ot.shortname)) as orgshortname
			FROM tusers u
			JOIN tclassextenddatauseractivity otua ON otua.baseID = u.userID
			JOIN tclassextendattributes ota ON otua.attributeID = ota.attributeID AND ota.name = 'orgtype' 
			JOIN c_torgtype ot ON FIND_IN_SET(ot.shortname,otua.attributeValue)
			LEFT JOIN tclassextenddatauseractivity oua ON oua.baseID = u.userID
			JOIN tclassextendattributes oa ON oua.attributeID = oa.attributeID AND oa.name = 'orgid' 
			LEFT JOIN c_torganizations o on o.orgid = oua.attributeValue
			LEFT JOIN tclassextenddatauseractivity onua ON onua.baseID = u.userID
			JOIN tclassextendattributes ona ON onua.attributeID = ona.attributeID AND ona.name = 'organization_name' 
			WHERE u.userID = <cfqueryparam value="#arguments.userID#" cfsqltype="cf_sql_varchar" />
			GROUP BY u.userID
		</cfquery>
		
		<cfif getOrgInfo.recordCount>
			<cfset rtnStruct.orgType = getOrgInfo.orgtypes />
			<cfset rtnStruct.orgLongName = getOrgInfo.orgname />
			<cfset rtnStruct.orgShortName = getOrgInfo.orgshortname />
		</cfif>
			
		<cfreturn rtnStruct />	
	</cffunction>
	
	<!--- User Registration Related --->
	<cffunction name="getOrgOptions" access="remote" returntype="struct" returnformat="json" output="false">
		<cfargument name="state" required="true">
		 
		<!--- Define the local scope. --->
		<cfset var LOCAL = {} />
		
		<!--- Get a new API resposne. --->
		<cfset LOCAL.Response = {
					Success = true,
					Errors = [],
					CoCData = "",
					PHAData = "",
					HMISData = "",
					GranteeData = ""
					} />						 
		<cftry>
			<cfquery name="qryCoCNumber" datasource="onecpd_cms">
				SELECT c.coc_no, c.coc_name
				FROM c_tcoc c
				JOIN state s on s.abbrev = c.state_id
				WHERE s.name = <cfqueryparam value="#arguments.state#" cfsqltype="cf_sql_varchar" />
				ORDER BY c.coc_no
			</cfquery>
			
			<cfset LOCAL.CoCs = [] />
			<cfloop query="qryCoCNumber">
				<cfset LOCAL.CoC = {	
									optionValue = coc_no,
									optionDisplay = coc_no & " - " & coc_name
								} />
				<cfset ArrayAppend(
						LOCAL.CoCs,
						LOCAL.CoC
						) /> 
			</cfloop>
			<cfset LOCAL.Response.CoCData = LOCAL.CoCs />
					
			<cfquery name="qryHMIS" datasource="onecpd_cms">
				SELECT o.orgid, o.orgname
				FROM c_torganizations o
				JOIN state s on s.abbrev = o.grantee_state
				WHERE 
					o.active = 1
					AND s.name = <cfqueryparam value="#arguments.state#" cfsqltype="cf_sql_varchar" />
					AND FIND_IN_SET (7, o.orgtypes)
				ORDER BY o.orgname
			</cfquery>
			<cfset LOCAL.HMISs = [] />
			<cfloop query="qryHMIS">
				<cfset LOCAL.HMIS = {	
									optionValue = orgid,
									optionDisplay = orgname
								} />
				<cfset ArrayAppend(
						LOCAL.HMISs,
						LOCAL.HMIS
						) /> 
			</cfloop>
			<cfset LOCAL.Response.HMISData = LOCAL.HMISs />
					
			<cfquery name="qryPHA" datasource="onecpd_cms">
				SELECT o.orgid, o.orgname
				FROM c_torganizations o
				JOIN state s on s.abbrev = o.grantee_state
				WHERE 
					o.active = 1
					AND s.name = <cfqueryparam value="#arguments.state#" cfsqltype="cf_sql_varchar" />
					AND FIND_IN_SET (6, o.orgtypes)
				ORDER BY o.orgname
			</cfquery>
			<cfset LOCAL.PHAs = [] />
			<cfloop query="qryPHA">
				<cfset LOCAL.PHA = {	
									optionValue = orgid,
									optionDisplay = orgname
								} />
				<cfset ArrayAppend(
						LOCAL.PHAs,
						LOCAL.PHA
						) /> 
			</cfloop>
			<cfset LOCAL.Response.PHAData = LOCAL.PHAs />
			
			<cfquery name="qryGrantee" datasource="onecpd_cms">
				SELECT o.orgid, o.orgname
				FROM c_torganizations o
				JOIN state s on s.abbrev = o.grantee_state
				WHERE 
					o.active = 1
					AND s.name = <cfqueryparam value="#arguments.state#" cfsqltype="cf_sql_varchar" />
					AND FIND_IN_SET (4, o.orgtypes)
				ORDER BY o.orgname
			</cfquery>
			
			<cfset LOCAL.Grantees = [] />
			<cfloop query="qryGrantee">
				<cfset LOCAL.Grantee = {	
									optionValue = orgid,
									optionDisplay = orgname
								} />
				<cfset ArrayAppend(
						LOCAL.Grantees,
						LOCAL.Grantee
						) /> 
			</cfloop>
			<cfset LOCAL.Response.GranteeData = LOCAL.Grantees />
					
		<cfcatch type="any">
			<cfset LOCAL.Response = {
						Success = false,
						Errors = "An error occurred.",
						CoCData = "",
						PHAData = "",
						GranteeData = ""
						} />
		</cfcatch>
		</cftry>
		
		<!--- Return the response. --->
		<cfreturn LOCAL.Response />
		
	</cffunction>
	
	<cffunction name="getCoCOrgOptions" access="remote" returntype="struct" returnformat="json" output="false">
		<cfargument name="coc_no" required="true">
		 
		<!--- Define the local scope. --->
		<cfset var LOCAL = {} />
		
		<!--- Get a new API resposne. --->
		<cfset LOCAL.Response = {
					Success = true,
					Errors = [],
					Data = ""
					} />						 
		<cftry>
			<cfif ArrayLen(arguments.coc_no)> 
				<cfquery name="qryCoCOrg" datasource="onecpd_cms">
					SELECT o.orgid, o.orgname
					FROM c_torganizations o
					WHERE o.active = 1
						AND (1=0 <cfloop array="#arguments.coc_no#" index="i">
							OR FIND_IN_SET(<cfqueryparam value="#i#" cfsqltype="cf_sql_varchar" />, o.coc_no_coc)
						</cfloop>)
						AND FIND_IN_SET(5, o.orgtypes)
					ORDER BY o.orgname
				</cfquery>
				
				<cfset LOCAL.CoCs = [] />
				<cfloop query="qryCoCOrg">
					<cfset LOCAL.CoC = {	
										optionValue = orgid,
										optionDisplay = orgname
									} />
					<cfset ArrayAppend(
							LOCAL.CoCs,
							LOCAL.CoC
							) /> 
				</cfloop>
				<cfset LOCAL.Response.Data = LOCAL.CoCs />
			</cfif>	
		<cfcatch type="any">
			<cfset LOCAL.Response = {
						Success = false,
						Errors = "An error occurred.",
						Data = ""
						} />
		</cfcatch>
		</cftry>
		
		<!--- Return the response. --->
		<cfreturn LOCAL.Response />
		
	</cffunction>
	
	<cffunction name="completedUserProfile" returntype="boolean" access="public" output="false">
		
		<cfif LEN($.currentUser('orgtype')) 
			AND (LEN($.currentUser('organization_name')) OR ($.currentUser('orgtype') eq "individual"))
			AND LEN($.currentUser().getAddressesIterator().next().getState())
			AND LEN($.currentUser().getAddressesIterator().next().getHours())
			>
			<cfreturn true />
		<cfelse>
			<cfreturn false />
		</cfif>
		
	</cffunction>
	
	<cffunction name="completedLearnerProfile" returntype="boolean" access="public" output="false">
		
		<cfquery name="checkLearnerProfile" datasource="onecpd_cms">
			SELECT distinct user_id
			FROM lms_tbl_registration
			WHERE user_id = <cfqueryparam value="#$.currentUser('userid')#" cfsqltype="cf_sql_varchar" />
		</cfquery>
		
		<cfquery name="checkGroup" datasource="onecpd_cms">
			SELECT u.UserID FROM tusers u
			JOIN tusersmemb m on m.userid = u.userid
			JOIN tusers g on g.userid = m.groupid
			WHERE u.userid = <cfqueryparam value="#$.currentUser('userid')#" cfsqltype="cf_sql_varchar" />
				AND g.groupName = 'HUD Exchange Learn'
		</cfquery>
		
		<cfif checkLearnerProfile.recordCount AND checkGroup.recordCount>
			<cfreturn true />
		<cfelse>
			<cfreturn false />			
		</cfif>
	
	</cffunction>
	
	<cffunction name="checkUsername" access="remote" returntype="struct" returnformat="json" output="false">
		<cfargument name="newusername" required="true">
		<cfargument name="currentusername" required="true">
		
		<!--- Define the local scope. --->
		<cfset var LOCAL = {} />
		
		<!--- Get a new API resposne. --->
		<cfset LOCAL.Response = {
					Success = true,
					Data = ""
					} />						 
		<cftry>
			<cfif NOT REFIND("^[a-zA-Z0-9_@\.\-]*$", newusername)>
				<cfset LOCAL.Response = {
					Success = false,
					Data = "Only alphanumeric characters including dot, hyphen, underscore and @ can be used (no spaces)."
					} />	
			<cfelse>
				<cfquery name="qryCheckUserName" datasource="onecpd_cms">
					SELECT distinct userid
					FROM tusers
					WHERE username = <cfqueryparam value="#trim(arguments.newusername)#" cfsqltype="cf_sql_varchar" />
					<cfif len(trim(arguments.currentusername))>
						AND username <> <cfqueryparam value="#trim(arguments.currentusername)#" cfsqltype="cf_sql_varchar" /> 
					</cfif>
				</cfquery>
				
				<cfif qryCheckUserName.recordCount>
					<cfset LOCAL.Response = {
						Success = false,
						Data = "This username is already in use.  Please choose different user name."
						} />			
				<cfelse>
					<cfset LOCAL.Response = {
						Success = true,
						Data = "OK"
						} />
				</cfif>
			
			</cfif>
		<cfcatch type="any">
			<cfset LOCAL.Response = {
						Success = false,
						Data = "Unable to check availability"
						} />
		</cfcatch>
		</cftry>
		
		<!--- Return the response. --->
		<cfreturn LOCAL.Response />
		
	</cffunction>
	
	<cffunction name="checkEmail" access="remote" returntype="struct" returnformat="json" output="false">
		<cfargument name="email" required="true">
		<cfargument name="path_info" required="false" default="">
		<cfargument name="returnURL" required="false" default="">
		
		<!--- Define the local scope. --->
		<cfset var LOCAL = {} />
		
		<!--- Get a new API resposne. --->
		<cfset LOCAL.Response = {
					Success = true,
					HasAccount = false,
					Data = ""
					} />						 
		<cftry>
			<cfif isValid('email', trim(arguments.email))>
			
				<cfquery name="qryCheckEmail" datasource="onecpd_cms">
					SELECT username, email 
					FROM tusers
					WHERE email = <cfqueryparam value="#trim(arguments.email)#" cfsqltype="cf_sql_varchar" />
						AND inactive = 0
					ORDER BY username
				</cfquery>
				
				<cfif qryCheckEmail.recordCount>
					<cfset message = "" />
					<cfif qryCheckEmail.recordcount eq 1>
						<cfset message="You already have an existing account " />
					<cfelse>
						<cfset message="You already have existing accounts " />
					</cfif>
					<cfif FindNoCase("/incomecalculator/dashboard/", arguments.PATH_INFO)>
						<cfset component = "Income Calculator" />
					<cfelse>
						<cfset component = "HUD Exchange" />
					</cfif>
					
					<cfset loginlink = arguments.path_info />
					<cfif len(arguments.returnURL)>
						<cfset loginlink &= "?display=login&returnURL=" & urlencodedformat(arguments.returnURL) />
					</cfif>
					
					<cfset message &= "(#ValueList(qryCheckEmail.username, ', ')#) with the email address #trim(arguments.email)#.  You can either:<ul class='bullet'><li><a href='#loginlink#'>Log In</a> to an existing HUD Exchange account</li><li>Create a new #component# account with this email address</li></ul>">
					
					<cfset LOCAL.Response.HasAccount = true />	
					<cfset LOCAL.Response.Data = message />
				</cfif> 
			<cfelse>
				<cfset LOCAL.Response.Data = "Please enter valid email address." />	
			</cfif>			
		<cfcatch type="any">
			<cfset LOCAL.Response = {
						Success = false,
						HasAccount = false,
						Data = "Unable to check this time. #cfcatch.Message#"
						} />
		</cfcatch>
		</cftry>
		
		<!--- Return the response. --->
		<cfreturn LOCAL.Response />
		
	</cffunction>
	
	<cffunction name="getPrograms" output="false" returntype="query">	
		<cfargument name="userID" required="true" />	
		<cfquery name="getPrograms" datasource="onecpd_cms">
			SELECT
            	programs.program_category_id
                ,programs.program_category
                ,programs.short_name
                ,programs.short_name_display
                ,programs.type_id
				,subPrograms.program_category as sub_program_category
				,subPrograms.parent_category_id as sub_parent_category_id
				,subPrograms.program_category_id as sub_program_category_id
				,subPrograms.short_name as sub_short_name
				,programs.sort_order as psort_order
				,subPrograms.sort_order as ssort_order
		        ,r.experience_id
			FROM
            	lms_lku_programs programs 
                JOIN lms_lku_programs subPrograms ON programs.program_category_id = subPrograms.parent_category_id
				LEFT JOIN lms_tbl_registration r on r.program_category_id = subPrograms.program_category_id AND r.user_id = <cfqueryparam value="#arguments.userid#" cfsqltype="cf_sql_varchar" />
			where programs.type_id = 1
			UNION
			SELECT
            	programs.program_category_id
                ,programs.program_category
                ,programs.short_name
                ,programs.short_name_display
                ,programs.type_id
				,subPrograms.program_category as sub_program_category
				,subPrograms.parent_category_id as sub_parent_category_id
				,subPrograms.program_category_id as sub_program_category_id
				,subPrograms.short_name as sub_short_name
				,programs.sort_order as psort_order
				,subPrograms.sort_order as ssort_order
		        ,r.experience_id
			FROM
            	lms_lku_programs programs 
                LEFT JOIN lms_lku_programs subPrograms ON programs.program_category_id = subPrograms.parent_category_id
				LEFT JOIN lms_tbl_registration r on r.program_category_id = programs.program_category_id AND r.user_id = <cfqueryparam value="#arguments.userid#" cfsqltype="cf_sql_varchar" />
                where programs.type_id <> 1
				order by type_id, psort_order, ssort_order  asc
		</cfquery>
		
		<cfreturn getPrograms />
   
    </cffunction>
    
    <cffunction name="getExperience" output="false" returntype="query">
		<cfquery name="getExperience" datasource="onecpd_cms">
			SELECT
            	experience_id
                ,experience_years
			FROM
            	lms_lku_experience
		</cfquery>
		<cfreturn getExperience />
   </cffunction>
      
   <cffunction name="saveLearnerProfile" output="false" returntype="void">
		<cfargument name="event" required="true" />
		
		<!--- Step 2 --->
		<cfset user = event.getValue("userBean") />
		<cfset experience_values = "" />
		<cfset eventValues = event.getAllValues() />
		<cfif StructKeyExists(eventValues, "FIELDNAMES")>
			<cfloop list="#eventValues.FieldNames#" index="i">
				<cfif FindNoCase("ID_", i)>
					<!--- construct INSERT Values --->
					<cfset local.categoryID = replace(i, "ID_", "") />
					<cfset local.experienceID = eventValues["#i#"]>
				   <cfset experience_values = ListAppend(experience_values, "(#local.categoryID#, #local.experienceID#, '#user.getUserID()#', now())") />
				</cfif>
			</cfloop>
		</cfif>
	
		<cfif ListLEN(experience_values)>
			<cftransaction>
			<cfquery name="deleteOldRegistration" datasource="onecpd_cms">
				DELETE FROM lms_tbl_registration
				WHERE user_id  = <cfqueryparam value="#user.getUserID()#" cfsqltype="cf_sql_varchar" />
			</cfquery>
			
			<cfquery name="insertRegistration" datasource="onecpd_cms">
			INSERT INTO lms_tbl_registration
				(
				   program_category_id
				  ,experience_id
				  ,user_id
				  ,create_date
				)
			VALUES
				#replace(experience_values, "''", "'", "all")#
			</cfquery>
			</cftransaction>
	   </cfif>
	   
   </cffunction>
   
   <cffunction name="updateLMS" output="false" returntype="boolean">
		<cfargument name="userID" required="true" />
		<cfargument name="pw" type="string" default="" required="false" />
		<cfset request.traceUtil.logTick("reset") />
		
		<cftry>
		
		<cfset userBean=application.userManager.read(arguments.userID)>
		<cfset address=userBean.getAddressesIterator().next()>

		<cfset ArgStruct= StructNew()>
		<cfset ArgStruct.refreshWSDL = True>
		<cfset ArgStruct.username = application.lms.username>
		<cfset ArgStruct.password = application.lms.password>
		
		<cfset request.traceUtil.logTick("reset") />
		<cfset local.sumTotalMaestroUtils = getSumTotalMaestroUtils(
			wsUrl = application.lms.wsurl,
			args = ArgStruct
		) >
		<cfset request.traceUtil.logTick("getSumTotalMaestroUtils") />
		
		<cfset local.ws = local.sumTotalMaestroUtils.webService />
		<cfset local.javaLoader = local.sumTotalMaestroUtils.javaLoader />
		
		<cfset newuser = true />
		
		<cfset request.traceUtil.logTick("reset") />
		<cfif local.ws.UserExistsByUniqueId(arguments.userID) OR local.ws.UserExists(userBean.getUserName())>
			<cfset newuser = false />
		</cfif>
		<cfset request.traceUtil.logTick("<cfif local.ws.UserExistsByUniqueId(arguments.userID) OR local.ws.UserExists(userBean.getUserName())>") />
		
		<cfset CFCUAArray =  ArrayNew(1)>
		<cfset count = 1>
		
		<cfif newuser>
		<cfscript>
			// Create a new user object
			request.traceUtil.logTick("reset");
			user = local.ws.GenerateUserObject();
			request.traceUtil.logTick("local.ws.GenerateUserObject()");
					
			// the users status is part of the superclass. Its also a enum so we have to make a status object
			// if you just want to make users as active you dont have to do this because it will default
			UserStatus = local.javaLoader.create("com.geolearning.geonext.webservices.Status");
			user.setStatus(UserStatus.Active);
		
			//the start date is a java calendar instance
			StartDate = local.javaLoader.create("java.util.Calendar").getInstance();
			user.SetStartDate(StartDate);
						
			// Roles
			CFRoles = ArrayNew(1);
			CFRoles[1] = 'Learner';
			RolesArray = local.javaLoader.create("com.geolearning.geonext.webservices.ArrayOfString").init(CFRoles);
			user.setRoleNames(RolesArray);
			user.setDefaultRoleName('Learner');
			
		</cfscript>
		<cfelse>
		<cfscript>
			request.traceUtil.logTick("reset");
			if ( local.ws.UserExistsByUniqueId(arguments.userID) ) {
				request.traceUtil.logTick("local.ws.UserExistsByUniqueId(arguments.userID)");
				user = local.ws.LoadUserByUniqueId(arguments.userID);
				request.traceUtil.logTick("local.ws.LoadUserByUniqueId(arguments.userID)");
			} else {
				request.traceUtil.logTick("local.ws.UserExistsByUniqueId(arguments.userID)");
				user = local.ws.LoadUser(userBean.getUserName());
				request.traceUtil.logTick("local.ws.LoadUser(userBean.getUserName()");
			}
		</cfscript>
		</cfif>

		<!--- step 1 - user contact and login info --->
		<cfscript>
		
			user.SetUniqueID(arguments.userID);	
			user.SetUserName(userBean.getUserName());	
			
			if (LEN(arguments.pw)) {
				user.SetPassword(arguments.pw);
				user.SetDoChangePasswordNextLogin('False');
			}
			
			// First lets set all of the simple string values.
			// Then we will attack the complex types
			user.SetFirstName(userBean.getFName());
			user.SetLastName(userBean.getLName());
			user.SetEmail(userBean.getEmail());
			user.SetStreetAddress(address.getAddress1());
			user.SetCity(address.getCity());
			user.SetState(address.getState());
			user.SetCountry('United States');
			user.SetTelephone(userBean.getValue('mobilePhone'));
			user.SetTimeZone(address.getHours());
			
			// the postal code type is a enum. because CF doesn't have enums
			// we will new it out of the ws stubs. remember that if you ever want
			user.SetPostalCode(address.getZip());
			PostalCodeType = local.javaLoader.create("com.geolearning.geonext.webservices.PostalCodeType");
			user.setPostalCodeType(PostalCodeType.US);
				
			// and the custom user attributes. Remember that these would need to have already been created in the system.
			CUA = local.javaLoader.create("com.geolearning.geonext.webservices.CustomUserAttribute").init();
			CUA.setName("Org Type");
			CUA.setValue(userBean.getValue('orgtype'));
			CFCUAArray[count] = CUA;
			count++;
			
			CUA = local.javaLoader.create("com.geolearning.geonext.webservices.CustomUserAttribute").init();
			CUA.setName("Organization Name");
			CUA.setValue(userBean.getValue('organization_name'));
			CFCUAArray[count] = CUA;
			count++;
			
			CUA = local.javaLoader.create("com.geolearning.geonext.webservices.CustomUserAttribute").init();
			CUA.setName("CoC No");
			CUA.setValue(userBean.getValue('coc_no'));
			CFCUAArray[count] = CUA;
			count++;
			
			CUA = local.javaLoader.create("com.geolearning.geonext.webservices.CustomUserAttribute").init();
			CUA.setName("HMIS Type");
			CUA.setValue(userBean.getValue('hmis_type'));
			CFCUAArray[count] = CUA;
			count++;
			
			CUA = local.javaLoader.create("com.geolearning.geonext.webservices.CustomUserAttribute").init();
			CUA.setName("Affiliated Grantees");
			CUA.setValue(userBean.getValue('affiliated_grantees'));
			CFCUAArray[count] = CUA;
			count++;
			
			CUA = local.javaLoader.create("com.geolearning.geonext.webservices.CustomUserAttribute").init();
			CUA.setName("Field for Audience");
			CUA.setValue("DEFAULT THIS ONE");
			CFCUAArray[count] = CUA;
			count++;
			
			CUA = local.javaLoader.create("com.geolearning.geonext.webservices.CustomUserAttribute").init();
			CUA.setName("Field for Audience");
			CUA.setValue("DEFAULT THIS ONE");
			CFCSUAArray =  ArrayNew(1);
			CFCSUAArray[1] = CUA;
			CSUAArray = local.javaLoader.create("com.geolearning.geonext.webservices.ArrayOfCustomUserAttribute").init(CFCUAArray);
			user.setCustomSelectUserAttributes(CSUAArray);
			
		</cfscript>
		
		<!--- step 2 - learner profile info --->
		<cfquery name="getExperienceData" datasource="onecpd_cms">
			SELECT 
				group_concat(concat(p.short_name, '-', r.experience_id) separator ':') as value, 
				pp.lms_mapping_name 
			FROM lms_lku_programs p
			JOIN lms_tbl_registration r on p.program_category_id = r.program_category_id
			JOIN lms_lku_programs pp ON pp.program_category_id  = p.parent_category_id
			JOIN lms_lku_type t on t.type_id = p.type_id
			WHERE t.type_id = 1
				AND r.user_id = <cfqueryparam value="#userBean.getUserID()#" cfsqltype="cf_sql_varchar" />
			GROUP BY pp.program_category_id
					
			UNION
			
			SELECT 
				group_concat(concat(p.short_name, '-', r.experience_id) separator ':') as value,
				t.type_name AS lms_mapping_name
			FROM lms_lku_programs p
			JOIN lms_tbl_registration r on p.program_category_id = r.program_category_id
			LEFT JOIN lms_lku_type t on t.type_id = p.type_id
			WHERE (t.type_id = 2 or t.type_id = 3 or t.type_id = 4)
				AND r.user_id = <cfqueryparam value="#userBean.getUserID()#" cfsqltype="cf_sql_varchar" />
			GROUP BY t.type_id
		</cfquery>
		
		<cfif getExperienceData.recordCount>
			<cfloop query="getExperienceData">
				<cfset CUA = local.javaLoader.create("com.geolearning.geonext.webservices.CustomUserAttribute").init()>
				<cfset CUA.setName(lms_mapping_name)>
				<cfset CUA.setValue(javacast("string",toString(value)))>
				<cfset CFCUAArray[count] = CUA>
				<cfset count  = count + 1>
			</cfloop>
			<cfset CUAArray = local.javaLoader.create("com.geolearning.geonext.webservices.ArrayOfCustomUserAttribute").init(CFCUAArray)>
			<cfset user.setCustomUserAttributes(CUAArray)>
			<cfset hasLearnerProfile = true />
		
			<cfset request.traceUtil.logTick("reset") />
			<!---save into LMS  --->
			<cfif newuser>
				<cfset result = local.ws.CreateUser(user)>
				<cfset request.traceUtil.logTick("local.ws.CreateUser(user)") />
			<cfelse>
				<cfset result = local.ws.updateUser(user)>
				<cfset request.traceUtil.logTick("local.ws.updateUser(user)") />
			</cfif>

		</cfif>
		<cfif StructKeyExists(result, "ERRORS")>
			<cfset error = result.Errors.getString() />	
		</cfif>
		<cfif isDefined("error")>
			<cflog
				file="UpdateLMS_errors"
				type="Error"
				text="#serializeJSON(error)#." />	
			<cfif getServerEnvironment() neq "prod">
				<cfdump var="#error#"><cfabort />
			<cfelse>
				<!--- write log --->
			</cfif>
			<cfreturn false />
		<cfelse>
			<cfreturn true />
		</cfif>
		
		<cfcatch type="any">
			<cflog
				file="UpdateLMS_errors"
				type="Error"
				text="within CFCATCH block: #serializeJSON(cfcatch)#." />			
			<cfreturn false />
		</cfcatch>
		
		</cftry>	   							
   </cffunction>
   
   <cffunction name="updateLMSPassword" access="public" returntype="void">
		<cfargument name="username" type="string" required="yes" />
		<cfargument name="password" type="string" required="yes" />
		
		<cfset local.username = arguments.username />
		<cfset local.password = arguments.password />
		
		<cfset request.traceUtil.logTick("begin spawning updateLMSPassword thread") />
		<cfthread 
			name="updateLMSPassword" 
			action="run" 
			priority="NORMAL"
			username="#arguments.username#"
			password="#arguments.password#"
			>
	 		<cftry>
				<cfset local.ArgStruct= StructNew()>
				<cfset local.ArgStruct.refreshWSDL = True>
				<cfset local.ArgStruct.username = application.lms.username>
				<cfset local.ArgStruct.password = application.lms.password>
				
				<cfset local.sumTotalMaestroUtils = getSumTotalMaestroUtils(
					wsUrl = application.lms.wsurl,
					args = local.ArgStruct
				) >
		 
				<cfset local.ws = local.sumTotalMaestroUtils.webService />
				<cfset local.javaLoader = local.sumTotalMaestroUtils.javaLoader />
				
				<cfset request.traceUtil.logTick("reset") />
				<cfif local.ws.UserExists(username)>
					<cfset request.traceUtil.logTick("local.ws.UserExists(username)") />
					<cfset local.user = local.ws.LoadUser(username) />
					<cfset request.traceUtil.logTick("local.ws.LoadUser(username)") />
					<cfset local.user.SetPassword(password) />
					<cfset local.user.SetDoChangePasswordNextLogin('False') />
					<cfset result = local.ws.updateUser(local.user) />
					<cfset request.traceUtil.logTick("local.ws.updateUser(local.user)") />
					
					<cfset error = result.Errors.getString() />	
					<cfif isDefined("error")>
						<!---<cflog
							file="OneCPD_updateLMSPassword"
							type="error"
							text="#error[1]#."
						/>	--->
					</cfif>
				</cfif>
				<cfset request.traceUtil.logTick("after <cfif local.ws.UserExists(username)>") />
			<cfcatch type="any">	
						<cflog
							file="OneCPD_updateLMSPassword"
							type="error"
							text="#cfcatch#"
						/>
			</cfcatch>
			</cftry>							
		</cfthread>
		<cfset request.traceUtil.logTick("end spawning updateLMSPassword thread") />
	</cffunction>
		
		<cffunction name="getUserAccess" output="false" returntype="struct">
			<cfargument name="userID" required="true" />
			
			<cfset var resultStruct = {} />
			<cfset var qry = QueryNew("dummy") />
			<cfset var comp = {} />
			<cfset var roleName = "" />
			
			<cfquery name="qry" datasource="onecpd_cms">
				SELECT g.GroupName
				FROM tusers g
				JOIN tusersmemb m on m.groupID = g.userID
				WHERE m.userID = <cfqueryparam value="#arguments.userID#" cfsqltype="cf_sql_varchar" />
			</cfquery>
			
			<cfloop query="qry">
				<cfif ListLen(qry.GroupName, "/") EQ 3>
					<cfset roleName = trim(ListGetAt(qry.GroupName, 2, "/")) & " " & trim( ListGetAt(qry.GroupName, 3, "/") )/>
				<cfelseif NOT CompareNoCase(qry.GroupName, "Income Calculator")>
					<cfset roleName = "User" />
				<cfelseif NOT CompareNoCase(qry.GroupName, "Income Calculator / Admin")>
					<cfset roleName = "Income Calculator Admin" />
				<cfelseif NOT CompareNoCase(qry.GroupName, "HUD Exchange Learn")>
					<cfset roleName = "User" />
				<cfelse>
					<cfset roleName = qry.GroupName />
				</cfif>
				<cfset comp = application.userManager.readByGroupName(qry.GroupName, "onecpd") />
				<cfif NOT StructKeyExists(resultStruct, comp.getValue('shortname'))>
					<cfset resultStruct[comp.getValue('shortname')]= [] />
				</cfif>
				<cfset ArrayAppend(resultStruct[comp.getValue('shortname')], roleName) />
			</cfloop>
			
			<cfreturn resultStruct />
		</cffunction>
		
		<cffunction name="getOrgNamesFromIDs" output="false" returntype="string">
			<cfargument name="orgids" required="true" />
			
			<cfset var resultSting = "" />
			<cfset var qry = QueryNew("dummy") />
			
			<cfquery name="qry" datasource="onecpd_cms">
				SELECT orgname
				FROM c_torganizations
				WHERE Find_in_set(orgid, <cfqueryparam value="#arguments.orgids#" cfsqltype="cf_sql_varchar" />)
				order by orgname
			</cfquery>
			
			<cfloop query="qry">
				<cfset resultSting &= chr(13)&chr(10) & qry.orgname />
			</cfloop>
			
			<cfset resultSting = replace(resultSting, chr(13)&chr(10), "", "one") />
			
			<cfreturn resultSting />
		</cffunction>
		
		<cffunction name="getStateFromName" output="false" returntype="string">
			<cfargument name="statename" required="true" />
			
			<cfset var resultSting = "" />
			<cfset var qry = QueryNew("dummy") />
			
			<cfquery name="qry" datasource="onecpd_cms">
				SELECT abbrev
				FROM state
				WHERE name = <cfqueryparam value="#arguments.statename#" cfsqltype="cf_sql_varchar" />
			</cfquery>
			
			<cfset resultSting = qry.abbrev />
			
			<cfreturn resultSting />
		</cffunction>
		
	<cffunction name="updateUserProfile_LastLogin" output="false" returntype="void">
		<cfargument name="userID" required="true" />
		
		<cfquery name="local.qry" datasource="onecpd_cms">
			update um_mv_userprofile
			set lastlogin = now()
			where userID = <cfqueryparam value="#arguments.userID#" cfsqltype="cf_sql_varchar" />
		</cfquery>
	</cffunction>
	
	<cffunction name="updateUserProfile" output="false" returntype="void">
		<cfargument name="userID" required="true" />
	
		<cfset var userBean=application.userManager.read(arguments.userID) />
		<cfset var userAccess = getUserAccess(userBean.getUserID()) />
		<cfset var affiliated_grantees = getOrgNamesFromIDs(userBean.getValue('affiliated_grantees')) />
		<cfset var na_ta = getOrgNamesFromIDs(userBean.getValue('AdministratingTA_NA')) />
		<cfset var ta_mgmt_ta = getOrgNamesFromIDs(userBean.getValue('AdministratingTA')) />
		
		<cfset var hudrole = "" />
		<cfset var ta_mgmt_role = "" />
		
		<cfif FindNoCase("CPD Director", userBean.getValue('hudrole'))>
			<cfset hudrole = "CPD Director" />
		<cfelseif FindNoCase("CPD Representative", userBean.getValue('hudrole'))>
			<cfset hudrole = "CPD Representative" />
		</cfif>
		
		<cfif FindNoCase("GTM", userBean.getValue('hudrole'))>
			<cfset ta_mgmt_role &= "GTM"&chr(10) />
		</cfif>
		<cfif FindNoCase("GTR", userBean.getValue('hudrole'))>
			<cfset ta_mgmt_role &= "GTR"&chr(10) />
		</cfif>
		<cfif FindNoCase("Program Office Reviewer", userBean.getValue('hudrole'))>
			<cfset ta_mgmt_role &= "Program Office Reviewer"&chr(10) />
		</cfif>
		
			<cfquery name="local.qry" datasource="onecpd_cms">
				REPLACE INTO um_mv_userprofile (
					userid
					, username
					, fname
					, lname
					, email
					, inactive
					, lastlogin
					, phone
					, address
					, city
					, state
					, zip
					,`orgid`
					,`organization`
					,`orgtype`
					,`coc_no`
					,`hmis_type`
					,`affiliated_grantees_orgid`
					,`affiliated_grantees`
					,`hud_fo_type`
					,`system_admin`
					,`aaq`
					,`coc_checkup`
					,`event_space`
					,`grantees`
					,`iec`
					,`na`
					,`na_ta`
					,`lms`
					,`report_mgmt`
					,`resources`
					,`ta_mgmt`
					,`ta_mgmt_ta`
					,`training_event`
					,`um`
				) value (
					<cfqueryparam value="#userBean.getUserID()#" cfsqltype="cf_sql_varchar" />
					,<cfqueryparam value="#userBean.getUsername()#" cfsqltype="cf_sql_varchar" />
					,<cfqueryparam value="#userBean.getFname()#" cfsqltype="cf_sql_varchar" />
					,<cfqueryparam value="#userBean.getLname()#" cfsqltype="cf_sql_varchar" />
					,<cfqueryparam value="#userBean.getValue('email')#" cfsqltype="cf_sql_varchar" />
					,<cfqueryparam value="#userBean.getValue('inactive')#" cfsqltype="cf_sql_varchar" />
					,<cfqueryparam value="#DateFormat(userBean.getValue('lastLogin'), 'yyyy-mm-dd')# #TimeFormat(userBean.getValue('lastLogin'), 'hh:mm:ss')#" cfsqltype="cf_sql_varchar" null="#not len(userBean.getValue('lastLogin'))#" />
					,<cfqueryparam value="#userBean.getValue('mobilePhone')#" cfsqltype="cf_sql_varchar" />
					,<cfqueryparam value="#userBean.getAddressesIterator().next().getAddress1()#" cfsqltype="cf_sql_varchar" />
					,<cfqueryparam value="#userBean.getAddressesIterator().next().getCity()#" cfsqltype="cf_sql_varchar" />
					,<cfqueryparam value="#getStateFromName(userBean.getAddressesIterator().next().getState())#" cfsqltype="cf_sql_varchar" />
					,<cfqueryparam value="#userBean.getAddressesIterator().next().getZip()#" cfsqltype="cf_sql_varchar" />
					,<cfqueryparam value="#userBean.getValue('orgid')#" cfsqltype="cf_sql_varchar" />
					,<cfqueryparam value="#userBean.getValue('organization_name')#" cfsqltype="cf_sql_varchar" />
					,<cfqueryparam value="#userBean.getValue('orgtype')#" cfsqltype="cf_sql_varchar" />
					,<cfqueryparam value="#userBean.getValue('coc_no')#" cfsqltype="cf_sql_varchar" null="#not len(userBean.getValue('coc_no'))#" />
					,<cfqueryparam value="#userBean.getValue('hmis_type')#" cfsqltype="cf_sql_varchar" null="#not len(userBean.getValue('coc_no'))#" />
					,<cfqueryparam value="#userBean.getValue('affiliated_grantees')#" cfsqltype="cf_sql_varchar" null="#not len(userBean.getValue('affiliated_grantees'))#" />
					,<cfqueryparam value="#affiliated_grantees#" cfsqltype="cf_sql_varchar" null="#not len(affiliated_grantees)#" /> 
					,<cfif len(hudrole)>
						<cfqueryparam value="#hudrole#" cfsqltype="cf_sql_varchar" /> 
					<cfelse>
						NULL
					</cfif>
					,<cfif userBean.isInGroup('Admin')>
						1
					<cfelse>
						0
					</cfif>
					,<cfif StructKeyExists(userAccess, 'aaq')>
						<cfqueryparam value="#ArrayToList(userAccess.aaq, chr(10))#" cfsqltype="cf_sql_varchar" /> 
					<cfelse>
						NULL	
					</cfif>
					,<cfif StructKeyExists(userAccess, 'coc_checkup')>
						<cfqueryparam value="#ArrayToList(userAccess.coc_checkup, chr(10))#" cfsqltype="cf_sql_varchar" /> 
					<cfelse>
						NULL	
					</cfif>
					,<cfif StructKeyExists(userAccess, 'event_space')>
						<cfqueryparam value="#ArrayToList(userAccess.event_space, chr(10))#" cfsqltype="cf_sql_varchar" /> 
					<cfelse>
						NULL	
					</cfif>
					,<cfif StructKeyExists(userAccess, 'grantees')>
						<cfqueryparam value="#ArrayToList(userAccess.grantees, chr(10))#" cfsqltype="cf_sql_varchar" /> 
					<cfelse>
						NULL	
					</cfif>
					,<cfif StructKeyExists(userAccess, 'iec')>
						<cfqueryparam value="#ArrayToList(userAccess.iec, chr(10))#" cfsqltype="cf_sql_varchar" /> 
					<cfelse>
						NULL	
					</cfif>
					,<cfif StructKeyExists(userAccess, 'na')>
						<cfqueryparam value="#ArrayToList(userAccess.na, chr(10))#" cfsqltype="cf_sql_varchar" /> 
					<cfelse>
						NULL	
					</cfif>
					,<cfqueryparam value="#na_ta#" cfsqltype="cf_sql_varchar" null="#NOT LEN(na_ta)#" /> 
					,<cfif StructKeyExists(userAccess, 'lms')>
						<cfqueryparam value="#ArrayToList(userAccess.lms, chr(10))#" cfsqltype="cf_sql_varchar" /> 
					<cfelse>
						NULL	
					</cfif>
					,<cfif StructKeyExists(userAccess, 'report_mgmt')>
						<cfqueryparam value="#ArrayToList(userAccess.report_mgmt, chr(10))#" cfsqltype="cf_sql_varchar" /> 
					<cfelse>
						NULL	
					</cfif>
					,<cfif StructKeyExists(userAccess, 'resources')>
						<cfqueryparam value="#ArrayToList(userAccess.resources, chr(10))#" cfsqltype="cf_sql_varchar" /> 
					<cfelse>
						NULL	
					</cfif>
					,<cfif StructKeyExists(userAccess, 'ta_mgmt')>
						<cfqueryparam value="#ta_mgmt_role##ArrayToList(userAccess.ta_mgmt, chr(10))#" cfsqltype="cf_sql_varchar" /> 
					<cfelse>
						NULL	
					</cfif>
					,<cfqueryparam value="#ta_mgmt_ta#" cfsqltype="cf_sql_varchar" null="#NOT LEN(ta_mgmt_ta)#" /> 
					,<cfif StructKeyExists(userAccess, 'training_event')>
						<cfqueryparam value="#ArrayToList(userAccess.training_event, chr(10))#" cfsqltype="cf_sql_varchar" /> 
					<cfelse>
						NULL	
					</cfif>
					,<cfif StructKeyExists(userAccess, 'um')>
						<cfqueryparam value="#ArrayToList(userAccess.um, chr(10))#" cfsqltype="cf_sql_varchar" /> 
					<cfelse>
						NULL	
					</cfif>
				)
			</cfquery>

	</cffunction>
	
   <cffunction name="getLMSRoles" output="false" returntype="string">
		<cfargument name="userID" required="true" />
		
		<cfset rolesList = "" />

		<cfset userBean=application.userManager.read(arguments.userID)>
		
		<cfif userBean.isInGroup('HUD Exchange Learn')>
			<cftry>
			
			<cfset ArgStruct= StructNew()>
			<cfset ArgStruct.refreshWSDL = True>
			<cfset ArgStruct.username = application.lms.username>
			<cfset ArgStruct.password = application.lms.password>
	
			<cfset local.sumTotalMaestroUtils = getSumTotalMaestroUtils(
				wsUrl = application.lms.wsurl,
				args = ArgStruct
			) >
			
			<cfset local.ws = local.sumTotalMaestroUtils.webService />
			<cfset local.javaLoader = local.sumTotalMaestroUtils.javaLoader />
			<cfset request.traceUtil.logTick("before UserExistsByUniqueId/UserExists conditional") />
			<cfif local.ws.UserExistsByUniqueId(arguments.userID) OR local.ws.UserExists(userBean.getUserName())>
			<cfset request.traceUtil.logTick("just inside UserExistsByUniqueId/UserExists conditional") />
				<cfscript>
					if ( local.ws.UserExistsByUniqueId(arguments.userID) ) {
						request.traceUtil.logTick("just after local.ws.UserExistsByUniqueId(arguments.userID) conditional");
						user = local.ws.LoadUserByUniqueId(arguments.userID);
						request.traceUtil.logTick("just after local.ws.LoadUserByUniqueId(arguments.userID)");
					} else {
						user = local.ws.LoadUser(userBean.getUserName());
						request.traceUtil.logTick("just after local.ws.LoadUser(userBean.getUserName()");
					}
				</cfscript>
				<cfset arrayOfroles = user.getRoleNames().getString() />
				<cfif isdefined('arrayOfroles')>
					<cfloop array="#arrayOfroles#" index="r">
						<cfset rolesList = ListAppend(rolesList, r) />
					</cfloop>
				</cfif>
			</cfif>
			
			<cfcatch type="any">
			
			</cfcatch>
			</cftry>
		</cfif>
		<cfreturn rolesList />
   </cffunction>

	<cffunction name="HTMLStringFormat" access="public" output="No" >
		<cfargument name="string" type="string" required="Yes" >
		<cfset local.special = "&ndash;,&mdash;,&iexcl;,&iquest;,&quot;,&ldquo;,&rdquo;,&lsquo;,&rsquo;,&laquo;,&raquo;,&nbsp;,&amp;,&cent;,&copy;,&divide;,&gt;,&lt;,&micro;,&middot;,&para;,&plusmn;,&euro;,&pound;,&reg;,&sect;,&trade;,&yen;,&aacute;,&Aacute;,&agrave;,&Agrave;,&acirc;,&Acirc;,&aring;,&Aring;,&atilde;,&Atilde;,&auml;,&Auml;,&aelig;,&AElig;,&ccedil;,&Ccedil;,&eacute;,&Eacute;,&egrave;,&Egrave;,&ecirc;,&Ecirc;,&euml;,&Euml;,&iacute;,&Iacute;,&igrave;,&Igrave;,&icirc;,&Icirc;,&iuml;,&Iuml;,&ntilde;,&Ntilde;,&oacute;,&Oacute;,&ograve;,&Ograve;,&ocirc;,&Ocirc;,&oslash;,&Oslash;,&otilde;,&Otilde;,&ouml;,&Ouml;,&szlig;,&uacute;,&Uacute;,&ugrave;,&Ugrave;,&ucirc;,&Ucirc;,&uuml;,&Uuml;,&yuml;,&##32;,&##33;,&##34;,&##35;,&##36;,&##37;,&##38;,&##39;,&##40;,&##41;,&##42;,&##43;,&##44;,&##45;,&##46;,&##47;,&##48;,&##49;,&##50;,&##51;,&##52;,&##53;,&##54;,&##55;,&##56;,&##57;,&##58;,&##59;,&##60;,&##61;,&##62;,&##63;,&##64;,&##65;,&##66;,&##67;,&##68;,&##69;,&##70;,&##71;,&##72;,&##73;,&##74;,&##75;,&##76;,&##77;,&##78;,&##79;,&##80;,&##81;,&##82;,&##83;,&##84;,&##85;,&##86;,&##87;,&##88;,&##89;,&##90;,&##91;,&##92;,&##93;,&##94;,&##95;,&##96;,&##97;,&##98;,&##99;,&##100;,&##101;,&##102;,&##103;,&##104;,&##105;,&##106;,&##107;,&##108;,&##109;,&##110;,&##111;,&##112;,&##113;,&##114;,&##115;,&##116;,&##117;,&##118;,&##119;,&##120;,&##121;,&##122;,&##123;,&##124;,&##125;,&##126;,&##160;,&##161;,&##162;,&##163;,&##164;,&##165;,&##166;,&##167;,&##168;,&##169;,&##170;,&##171;,&##172;,&##173;,&##174;,&##175;,&##176;,&##177;,&##178;,&##179;,&##180;,&##181;,&##182;,&##183;,&##184;,&##185;,&##186;,&##187;,&##188;,&##189;,&##190;,&##191;,&##192;,&##193;,&##194;,&##195;,&##196;,&##197;,&##198;,&##199;,&##200;,&##201;,&##202;,&##203;,&##204;,&##205;,&##206;,&##207;,&##208;,&##209;,&##210;,&##211;,&##212;,&##213;,&##214;,&##215;,&##216;,&##217;,&##218;,&##219;,&##220;,&##221;,&##222;,&##223;,&##224;,&##225;,&##226;,&##227;,&##228;,&##229;,&##230;,&##231;,&##232;,&##233;,&##234;,&##235;,&##236;,&##237;,&##238;,&##239;,&##240;,&##241;,&##242;,&##243;,&##244;,&##245;,&##246;,&##247;,&##248;,&##249;,&##250;,&##251;,&##252;,&##253;,&##254;,&##255;">
		<cfset local.normal = "#chr(8211)#,#chr(8212)#,#chr(161)#,#chr(191)#,#chr(34)#,#chr(8220)#,#chr(8221)#,#chr(39)#,#chr(39)#,#chr(171)#,#chr(187)#,#chr(32)#,#chr(38)#,#chr(162)#,#chr(169)#,#chr(247)#,#chr(62)#,#chr(60)#,#chr(181)#,#chr(183)#,#chr(182)#,#chr(177)#,#chr(8364)#,#chr(163)#,#chr(174)#,#chr(167)#,#chr(8482)#,#chr(165)#,#chr(225)#,#chr(193)#,#chr(224)#,#chr(192)#,#chr(226)#,#chr(194)#,#chr(229)#,#chr(197)#,#chr(227)#,#chr(195)#,#chr(228)#,#chr(196)#,#chr(230)#,#chr(198)#,#chr(231)#,#chr(199)#,#chr(233)#,#chr(201)#,#chr(232)#,#chr(200)#,#chr(234)#,#chr(202)#,#chr(235)#,#chr(203)#,#chr(237)#,#chr(205)#,#chr(236)#,#chr(204)#,#chr(238)#,#chr(206)#,#chr(239)#,#chr(207)#,#chr(241)#,#chr(209)#,#chr(243)#,#chr(211)#,#chr(242)#,#chr(210)#,#chr(244)#,#chr(212)#,#chr(248)#,#chr(216)#,#chr(245)#,#chr(213)#,#chr(246)#,#chr(214)#,#chr(223)#,#chr(250)#,#chr(218)#,#chr(249)#,#chr(217)#,#chr(251)#,#chr(219)#,#chr(252)#,#chr(220)#,#chr(255)#,#chr(32)#,#chr(33)#,#chr(34)#,#chr(35)#,#chr(36)#,#chr(37)#,#chr(38)#,#chr(39)#,#chr(40)#,#chr(41)#,#chr(42)#,#chr(43)#,#chr(44)#,#chr(45)#,#chr(46)#,#chr(47)#,#chr(48)#,#chr(49)#,#chr(50)#,#chr(51)#,#chr(52)#,#chr(53)#,#chr(54)#,#chr(55)#,#chr(56)#,#chr(57)#,#chr(58)#,#chr(59)#,#chr(60)#,#chr(61)#,#chr(62)#,#chr(63)#,#chr(64)#,#chr(65)#,#chr(66)#,#chr(67)#,#chr(68)#,#chr(69)#,#chr(70)#,#chr(71)#,#chr(72)#,#chr(73)#,#chr(74)#,#chr(75)#,#chr(76)#,#chr(77)#,#chr(78)#,#chr(79)#,#chr(80)#,#chr(81)#,#chr(82)#,#chr(83)#,#chr(84)#,#chr(85)#,#chr(86)#,#chr(87)#,#chr(88)#,#chr(89)#,#chr(90)#,#chr(91)#,#chr(92)#,#chr(93)#,#chr(94)#,#chr(95)#,#chr(96)#,#chr(97)#,#chr(98)#,#chr(99)#,#chr(100)#,#chr(101)#,#chr(102)#,#chr(103)#,#chr(104)#,#chr(105)#,#chr(106)#,#chr(107)#,#chr(108)#,#chr(109)#,#chr(110)#,#chr(111)#,#chr(112)#,#chr(113)#,#chr(114)#,#chr(115)#,#chr(116)#,#chr(117)#,#chr(118)#,#chr(119)#,#chr(120)#,#chr(121)#,#chr(122)#,#chr(123)#,#chr(124)#,#chr(125)#,#chr(126)#,#chr(160)#,#chr(161)#,#chr(162)#,#chr(163)#,#chr(164)#,#chr(165)#,#chr(166)#,#chr(167)#,#chr(168)#,#chr(169)#,#chr(170)#,#chr(171)#,#chr(172)#,#chr(173)#,#chr(174)#,#chr(175)#,#chr(176)#,#chr(177)#,#chr(178)#,#chr(179)#,#chr(180)#,#chr(181)#,#chr(182)#,#chr(183)#,#chr(184)#,#chr(185)#,#chr(186)#,#chr(187)#,#chr(188)#,#chr(189)#,#chr(190)#,#chr(191)#,#chr(192)#,#chr(193)#,#chr(194)#,#chr(195)#,#chr(196)#,#chr(197)#,#chr(198)#,#chr(199)#,#chr(200)#,#chr(201)#,#chr(202)#,#chr(203)#,#chr(204)#,#chr(205)#,#chr(206)#,#chr(207)#,#chr(208)#,#chr(209)#,#chr(210)#,#chr(211)#,#chr(212)#,#chr(213)#,#chr(214)#,#chr(215)#,#chr(216)#,#chr(217)#,#chr(218)#,#chr(219)#,#chr(220)#,#chr(221)#,#chr(222)#,#chr(223)#,#chr(224)#,#chr(225)#,#chr(226)#,#chr(227)#,#chr(228)#,#chr(229)#,#chr(230)#,#chr(231)#,#chr(232)#,#chr(233)#,#chr(234)#,#chr(235)#,#chr(236)#,#chr(237)#,#chr(238)#,#chr(239)#,#chr(240)#,#chr(241)#,#chr(242)#,#chr(243)#,#chr(244)#,#chr(245)#,#chr(246)#,#chr(247)#,#chr(248)#,#chr(249)#,#chr(250)#,#chr(251)#,#chr(252)#,#chr(253)#,#chr(254)#,#chr(255)#">
		<cfset local.formated = ReplaceList(arguments.string, local.special, local.normal)>
		<cfreturn local.formated>
	</cffunction>
<!--- ################## Private (Helper) Functions ####################### --->


<cfscript>
	// TODO: Manage with ColdSpring, instead. Maybe make a wrapper, so external
	// code never needs to know about JavaLoader.
	private struct function getSumTotalMaestroUtils(
		required string wsUrl,
		required struct args
	) {
		
		/*
		* In CF, URLClassLoaders are not garbage collected, so repeated 
		* instantiation leads to a memory leak into PermGen memory space.
		* Instances of JavaLoader must be cached in the Server scope to avoid
		* repeated instantiation.
		* 
		* The Application scope would seem to be a good place to cache JL, but
		* apps can be restarted/reloaded multiple times during the life of the
		* server (i.e., the time between instance restarts).
		*/
		
		// get application's name
		local.appKey = "onecpd";
		// name of utility
		local.utilKey = "sumTotalMaestroUtils";
		// name of environment/(wsUrl)
		local.envKey = arguments.wsUrl;
		
		// lock name
		local.lockName = "server.#local.appKey#.#local.utilKey#";
		
		lock
			name = local.lockName
			type = "exclusive"
			timeout = 30 {
			
			// use application name as a key under server, which is where 
			// all server variables will be stored, for the sake of tidiness
			if ( !structKeyExists(server, local.appKey) ) {
			
				writeLog("server['#local.appKey#'] doesn't exist. creating...");
				server[local.appKey] = {};
				
			} else {
			
				// writeLog("server['#local.appKey#'] exists; using that.");
				
			}

			if ( !structKeyExists(server[local.appKey], local.utilKey) ) {
				
				writeLog("server['#local.appKey#']['#local.utilKey#'] doesn't exist. creating...");				
				server[local.appKey][local.utilKey] = {};
				
			} else {
			
				// writeLog("server['#local.appKey#']['#local.utilKey#'] exists; using that.");
				
			}
			
				/*
			* Using an "environment" key, we don't need to restart the instance
			* to switch API environments (sandbox/production).
			* */
			if ( !structKeyExists(server[local.appKey][local.utilKey], local.envKey) ) {
			
				writeLog("server['#local.appKey#']['#local.utilKey#']['#local.envKey#'] doesn't exist. creating...");	
				
				/*
				* In this use case, JavaLoader is tightly bound to the web
				* service, so cache the web service object along with it.
				* (Besides, a web service object is a Singleton, so
				* it makes sense to cache it, anyway.)
				* */
				
				// create web service object
				local.webServiceObj = 
					createObject("webservice", arguments.wsUrl, arguments.args);
				
				writeLog("web service has just been created.");
				writeLog("  * is 'local' a struct (as it should be)? " & isStruct(local));
				writeLog("  * is the web service object an object (as it should be)? " & isObject(local.webServiceObj));
				
				// create javaloader using web service's classloader
				local.javaLoader = 
					createObject("component", "javaLoader.JavaLoader")
						.init(
							loadPaths = [],
			                parentClassLoader = local.webServiceObj.getClass().getClassLoader()
						);
				
				writeLog("JavaLoader has just been created.");
				writeLog("  * is it an object (as it should be)? " & isObject(local.javaLoader));
				
				// set struct to server scope
				server[local.appKey][local.utilKey][local.envKey] =
					{
						webService = local.webServiceObj,
						javaLoader = local.javaLoader
					};
							
			} else {				
			
				// writeLog("server['#local.appKey#']['#local.utilKey#']['#local.envKey#'] exists; using that.");
				
			}
		
		}

		lock
			name = local.lockName
			type = "readOnly"
			timeout = 30 {
		
			return server[local.appKey][local.utilKey][local.envKey];

	}
		
	}
</cfscript>

</cfcomponent>
	<cfset docRequest.addFile(createObject("java","java.io.File").init(ARGUMENTS.file),"application/octet-stream") />
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
