<cfset local.sampleSolrInstance = createObject("component","components.cfsolrlib").init(APPLICATION.javaloader,"localhost","8983","/solr") />

<cfif structKeyExists(form,"coreSubmit")>
	<cfset local.coreResponse = local.sampleSolrInstance.checkForCore("#form.coreName#")/>
    <cfif local.coreResponse.success eq false>
    	<cfset local.newCoreResponse = local.sampleSolrInstance.createNewCore("#form.coreName#","core0")/>
    </cfif>
</cfif>

<html>
	<head>
		<title>CFSolrLib 3.0 | Core creation example</title>
	</head>
	<body>
    	<h2>Create Solr Core Example</h2>
		<p>This will check for the existance of a core and create the core if it does not exist.<br />
        Solr must have been started in multicore mode for this example to function correctly.<br />
        This is done by adding "-Dsolr.solr.home=multicore" to the start command.</p>
		<form action="" method="POST">
			New Core Name: <input name="coreName" type="text" /><br />
            <input type="submit" name="coreSubmit" value="Create Core" /><br />
		</form>
		<p>
        <cfoutput>
        <cfif structKeyExists(local,"coreResponse")>
        	Core Exists: #local.coreResponse.success#<br />
            Status Code: #local.coreResponse.statusCode#<br />
            <cfif local.coreResponse.success eq true>
            	Core Exists. No new core created.<br />
            </cfif>
            <br />
        </cfif>
        
        <cfif structKeyExists(local,"newCoreResponse")>
        	Core Creation Attempt Success: #local.newCoreResponse.success#<br />
            <cfif local.newCoreResponse.success eq false>
            	Error Message: #local.newCoreResponse.message#<br />
            </cfif>
        	<br />
        </cfif>
        </cfoutput>
	</body>
</html>