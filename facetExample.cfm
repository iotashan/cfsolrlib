<cfparam name="URL.q" default="*:*">
<cfparam name="URL.page" default="1">
<cfparam name="URL.perPage" default="10">

<cfset sampleSolrInstance = createObject("component","components.cfsolrlib").init(APPLICATION.javaloader,"localhost","8983","/solr") />

<cfif NOT isNumeric(URL.page) OR abs(round(URL.page)) NEQ URL.page>
	<cfset URL.page = 1>
</cfif>

<cfif NOT isNumeric(URL.perPage) OR abs(round(URL.perPage)) NEQ URL.perPage>
	<cfset URL.perPage = 10>
</cfif>

<cfset start = ((URL.page - 1) * URL.perPage)>
<cfset rows = URL.perPage>

<cfset cleanedUrlQuery = "?" & reReplaceNoCase(cgi.query_string,"&*\bpage=\d+","","all")>

<cfset facetFields = arrayNew(1) />
<cfset arrayAppend(facetFields,"cat") />
<cfset arrayAppend(facetFields,"author_s") />
<cfset arrayAppend(facetFields,"availability_s") />

<cfset facetFiltersArray = arrayNew(1)>

<cfif isDefined("URL.fq")>
	<cfset facetFiltersArray = listToArray(urlDecode(URL.fq))>
</cfif>

<cfset searchResponse = sampleSolrInstance.search(q=URL.q,start=start,rows=rows,facetFields=facetFields,facetFilters=facetFiltersArray,facetMinCount=1) />

<cfif isStruct(searchResponse)>
	<cfset searchSuccess = TRUE>
<cfelse>
	<cfset searchSuccess = FALSE>
</cfif>

<!doctype html>
<html lang="en">
<head>
	<meta charset="UTF-8">
	<title>CFSolrLib 3.0 | Faceted Search Example</title>
	<link href="//netdna.bootstrapcdn.com/twitter-bootstrap/2.3.0/css/bootstrap-combined.min.css" rel="stylesheet">
</head>
<body>
	<cfoutput>
		<div class="container">
			<div class="row">
				<div class="span12">
					<h1>Faceted Search Example</h1>
					<p class="lead">Here is a simple faceted search example.</p>
					<form action="" method="GET" class="form-search form-inline">
						<div class="input-append">
							<input type="text" name="q" value="#URL.q#" class="input-medium search-query" placeholder="Search..."><button type="submit" class="btn">Search</button>
						</div>
					</form>
					<p>Other Search Examples: <a href="?q=*:*">*:*</a> | <a href="?q=Charcoal">Charcoal</a> | <a href="?q=Media">Media</a></p>
				</div>
			</div>
			<div class="row">
				<div class="span3">
					<cfif searchSuccess AND structKeyExists(searchResponse,"facetFields") AND isArray(searchResponse.facetFields)>
						<cfoutput>
							<cfset facetDisplayName = structNew()>
							<cfset facetDisplayName["cat"] = "Media">
							<cfset facetDisplayName["Author_s"] = "Artist">
							<cfset facetDisplayName["Availability_s"] = "Availability">
							<cfloop index="a" array="#searchResponse.facetFields#">
								<cfif isArray(a.getValues())>
									<h4 style="text-transform:capitalize;">#facetDisplayName[a.getName()]#</h4>
									<ul>
										<cfloop index="b" from="1" to="#arrayLen(a.getValues())#">
											<cfif len(a.getValues()[b].getName())>
												<cfset filterString = "&fq=" & a.getName() & urlEncodedFormat(":("""& a.getValues()[b].getName()&""")")>
												<li><a href="#cleanedUrlQuery##filterString#">#a.getValues()[b].getName()#</a>&nbsp;<small class="muted">(#a.getValues()[b].getCount()#)</small>
													<cfif isDefined("URL.fq") and findNoCase(filterString,cleanedUrlQuery)> 	<a href="#replaceNoCase(cleanedUrlQuery,filterString,"")#" class="label label-important" style="float:none;">&times;</a>
													</cfif>
												</li>
											</cfif>
										</cfloop>
									</ul>
								</cfif>
							</cfloop>
						</cfoutput>
						&nbsp;
					</cfif>
				</div>
				<div class="span9">
					<cfif searchSuccess AND isArray(searchResponse.results)>
						<table class="table table-bordered table-hover">
							<thead>
								<tr>
									<th>ID</th>
									<th>Title</th>
									<th>Artist</th>
									<th>Media</th>
									<th>Availability</th>
								</tr>
							</thead>
							<tbody>
								<cfloop array="#searchResponse.results#" index="currentResult">
									<tr>
										<td>#currentResult.id#</td>
										<td><cfif isDefined("currentResult.title")>#currentResult.title#</cfif></td>
										<td><cfif isDefined("currentResult.Author_s")>#currentResult.Author_s#</cfif></td>
										<td><cfif isDefined("currentResult.cat")>#arrayToList(currentResult.cat)#</cfif></td>
										<td><cfif isDefined("currentResult.Availability_s")>#currentResult.Availability_s#</cfif></td>
									</tr>
								</cfloop>
							</tbody>
						</table>


						<!--- Begin Pagination --->
						<cfif searchResponse.totalResults GT rows>
							<div class="pagination">
								<ul>
									<cfoutput>
										<cfset totalPages = Ceiling(searchResponse.totalResults / url.perPage)>
						 				<cfif url.page GT 1>
						 					<cfset prevLink = cleanedUrlQuery>
											<cfif url.page GT 2>
												<cfset prevLink = cleanedUrlQuery & "&page=" & (url.page - 1)>
											</cfif>
											<li><a href="#prevLink#">&laquo;</a></li>
										<cfelse>
											<li class="disabled"><a href="##">&laquo;</a></li>
										</cfif>

										<cfset pageCount = 1>
										<cfset pageLink = 1>

										<cfloop index="c" from="1" to="#totalPages#">
											<cfif c EQ url.page>
												<li class="active"><a href="##">#c#</a></li>
											<cfelseif c NEQ 1>
												<li><a href="#cleanedUrlQuery#&page=#c#">#c#</a></li>
											<cfelse>
												<li><a href="#cleanedUrlQuery#">#c#</a></li>
											</cfif>
										</cfloop>

										<cfif url.page LT totalPages>
											<cfset nextLink = cleanedUrlQuery & "&page=" & (url.page + 1)>
											<li><a href="#nextLink#">&raquo;</a></li>
										<cfelse>
											<li class="disabled"><a href="##">&raquo;</a></li>
										</cfif>
									</cfoutput>
								</ul>
							</div>
						</cfif>
						<!--- End Pagination --->

					</cfif>
				</div>
			</div>
		</div>
	</cfoutput>
</body>
</html>