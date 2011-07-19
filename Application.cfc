<cfset THIS.name = "cfsolrlibDemo" />

<cffunction name="onApplicationStart">
	<cfscript>
		// load libraries needed for solrj
		var paths = arrayNew(1);
		arrayAppend(paths,expandPath("solrj-lib/commons-io-1.4.jar"));
		arrayAppend(paths,expandPath("solrj-lib/commons-codec-1.4.jar"));
		arrayAppend(paths,expandPath("solrj-lib/slf4j-api-1.5.5.jar"));
		arrayAppend(paths,expandPath("solrj-lib/slf4j-jdk14-1.5.5.jar"));
		arrayAppend(paths,expandPath("solrj-lib/commons-httpclient-3.1.jar"));
		arrayAppend(paths,expandPath("solrj-lib/apache-solr-solrj-3.2.0.jar"));
		arrayAppend(paths,expandPath("solrj-lib/geronimo-stax-api_1.0_spec-1.0.1.jar"));
		arrayAppend(paths,expandPath("solrj-lib/wstx-asl-3.2.7.jar"));
		arrayAppend(paths,expandPath("solrj-lib/jcl-over-slf4j-1.5.5.jar"));

		// create an application instance of JavaLoader
		APPLICATION.javaloader = createObject("component", "javaloader.JavaLoader").init(paths);
	
	</cfscript>
</cffunction>
