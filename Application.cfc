component{
	THIS.name = "cfsolrlibDemo" />

	public boolean function onApplicationStart(){
		// load libraries needed for solrj
		var paths = arrayNew(1);
		arrayAppend(paths,expandPath("solrj-lib/solr-solrj-4.0.0.jar"));
		arrayAppend(paths,expandPath("solrj-lib/commons-io-2.4.jar"));
		arrayAppend(paths,expandPath("solrj-lib/commons-codec-1.7.jar"));
		arrayAppend(paths,expandPath("solrj-lib/slf4j-api-1.5.6.jar"));
		arrayAppend(paths,expandPath("solrj-lib/slf4j-jdk14-1.5.6.jar"));
		arrayAppend(paths,expandPath("solrj-lib/jcl-over-slf4j-1.5.6.jar"));
		arrayAppend(paths,expandPath("solrj-lib/httpclient-4.2.1.jar"));
		arrayAppend(paths,expandPath("solrj-lib/httpcore-4.2.2.jar"));
		arrayAppend(paths,expandPath("solrj-lib/httpmime-4.2.1.jar"));
		arrayAppend(paths,expandPath("solrj-lib/stax-api-1.0.1.jar"));
		arrayAppend(paths,expandPath("solrj-lib/wstx-asl-4.0.0.jar"));
		arrayAppend(paths,expandPath("solrj-lib/tika-app-1.2.jar"));

		// create an application instance of JavaLoader
		APPLICATION.javaloader = createObject("component", "javaloader.JavaLoader").init(loadpaths=paths,  loadColdFusionClassPath=true);
		// setup tika
		APPLICATION.tika = APPLICATION.javaloader.create("org.apache.tika.Tika").init();

		return true;
	}

	public boolean function onRequestStart(){
		if( structKeyExists(url, "reinit") ){
    			onApplicationStart();
    		}
    		
    		return true;
	}
}
