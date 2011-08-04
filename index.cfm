<cfset sampleSolrInstance = createObject("component","components.cfsolrlib").init(APPLICATION.javaloader,"localhost","8983","/solr") />
<html>
	<head>
		<title>CFSolrLib 2.0</title>
	</head>
	<body>
		<h2>Welcome to CFSolrLib</h2>
		<p>CFSolrLib is a library that lets you interact directly with a Solr server, using the native java client library.</p>
		
		<h2>Requirements</h2>
		<p>
			You need a few basic things to use CFSolrLib 2:<br/>
			<ul>
				<li>A Solr server, version 3.1 or greater. This was built &amp; tested with Solr 3.2. This library will not work with earlier versions of Solr.</li>
				<li><a href="http://wiki.apache.org/solr/Solrj">SolrJ</a> - The Solr java client library and supporting java libraries.</li>
				<li>Mark Mandel's <a href="http://www.compoundtheory.com/?action=javaloader.index">JavaLoader</a>, to load SolrJ.</li>
			</ul>
		</p>
		
		<h2>Installation</h2>
		<p>I've included everything you need right here... which also means that there might be updates to the included software. Let's quickly go over what all is included, and what I have pre-configured for you.</p>
		<ul>
			<li>components/</li>
				<ul>
					<li>This directory houses the CFSolrLib cfc. In your actual app, this cfc doesn't need to be accessible from the web.</li>
				</ul>
			<li>index.cfm</li>
				<ul>
					<li>You're looking at it right now.</li>
				</ul>
			<li>javaloader/</li>
				<ul>
					<li>The standard JavaLoader install. Again, this doesn't need to be in your root directory, and if you already use JavaLoader, you don't need another copy.</li>
				</ul>
			<li>solr-server/</li>
				<ul>
					<li>A copy of Solr 3.2 "example" directory.</li>
					<li>solr-server/solr/conf/schema.xml</li>
					<ul>
						<li>This schema file has been simplified for the examples.</li>
					</ul>
					<li>solr-server/work/Jetty_[...]/webapp/WEB-INF/lib</li>
					<ul>
						<li>This directory is normally created by the Jetty J2EE server using solr.war file. I've added in the necessary Java files to support reading rich documents (Apache Tika/Solr Cell). These libraries can be found in the contrib/dataimporthandler directory in a standard Solr download, and need to be placed in the lib directory of your deployment.</li>
					</ul>
				</ul>
			<li>solrj-lib/</li>
				<ul>
					<li>A collection of the java files needed to run the SolrJ client library. These files are normally located in various places in the solr-server directory, but copied here for convenience.</li>
				</ul>
		</ul>
		<p>In order to start the Solr server, you will need to run a command from the command line, inside the solr-server directory. Make sure you don't have another Solr server running, including the one built-in to CF9. If you are on Linux/OS X, you might need to run the command with sudo.</p>
		<ul>
			<li><strong>java -jar start.jar</strong></li>
		</ul>
		
		<h2>Examples</h2>
		<p>There are two basic examples, one for indexing content, and one for searching content. This is not a Solr tutorial, this just shows how to get your data in &amp; out using this CF library.</p>
		
		<ul>
			<li><a href="indexExample.cfm">Indexing Example</a> (requires the CFArtGallery datasource)</li>
			<li><a href="searchExample.cfm">Search Example</a></li>
		</ul>
		
		<p>The point of the examples is the CF code, not the HTML that you'll see in the browser, so be sure to dig in!</p>
		
		<h2>Ways to share your appreciation</h2>
		<p>If you like this, or any of my other open-source projects, you're always welcome to take a peek at my <a href="http://www.amazon.com/wishlist/172M0XGIRQ2S8">Amazon Wish List</a>.</p>
	</body>
</html>