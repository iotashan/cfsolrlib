<cfset THIS.name = "cfsolrlibDemo" />

<cffunction name="onApplicationStart">
	<cfscript>
		// load libraries needed for solrj
		var paths = arrayNew(1);
		arrayAppend(paths,expandPath("solrj-lib/solr-solrj-4.0.0.jar"));
		arrayAppend(paths,expandPath("solrj-lib/commons-io-2.4.jar"));
		arrayAppend(paths,expandPath("solrj-lib/commons-codec-1.7.jar"));
		arrayAppend(paths,expandPath("solrj-lib/slf4j-api-1.6.6.jar"));
		arrayAppend(paths,expandPath("solrj-lib/slf4j-jdk14-1.6.6.jar"));
		arrayAppend(paths,expandPath("solrj-lib/jcl-over-slf4j-1.6.6.jar"));
		//arrayAppend(paths,expandPath("solrj-lib/log4j-over-slf4j-1.6.6.jar"));
		arrayAppend(paths,expandPath("solrj-lib/httpclient-4.2.1.jar"));
		arrayAppend(paths,expandPath("solrj-lib/httpcore-4.2.2.jar"));
		arrayAppend(paths,expandPath("solrj-lib/httpmime-4.2.1.jar"));
		arrayAppend(paths,expandPath("solrj-lib/stax-api-1.0.1.jar"));
		arrayAppend(paths,expandPath("solrj-lib/wstx-asl-4.0.0.jar"));
		arrayAppend(paths,expandPath("solrj-lib/tika-app-1.2.jar"));

		// create an application instance of JavaLoader
		APPLICATION.javaloader = createObject("component", "javaloader.JavaLoader").init(loadpaths=paths, loadColdFusionClassPath=true);
		// setup tika
		APPLICATION.tika = APPLICATION.javaloader.create("org.apache.tika.Tika").init();

	</cfscript>
</cffunction>

<cffunction name="onRequestStart">
	<cfif structKeyExists(url, "reinit")>
    	<cfset onApplicationStart()>
    </cfif>
</cffunction>
