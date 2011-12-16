<cfcomponent extends="controller" output="false">

	<cffunction name="import" output="false" returntype="any">
		<cfargument name="rc" />
		
		<cfparam name="arguments.rc.parentContentID" default="00000000000000000000000000000000001" />

		<cfset var newFilename = createUUID() & ".xml" />
		<cfset var importDirectory = expandPath(rc.$.siteConfig('assetPath')) & '/assets/file/muraConverter/wordpressImport/' />
		<cfset var rawXML = "" />
		<cfset var wpXML = "" />
		<cfset var item = "" />
		<cfset var parentContent = "" />
		<cfset var content = "" />
		<cfset var allParentsFound = false />
		<cfset var categoryList = "" />
		
		<cfif not directoryExists(importDirectory)>
			<cfset directoryCreate(importDirectory) />
		</cfif>
		
		<cffile action="upload" filefield="wordpressXML" destination="#importDirectory#" nameConflict="makeunique" result="uploadedFile">
		<cffile action="rename" destination="#importDirectory##newFilename#" source="#importDirectory##uploadedFile.serverFile#" >
		
		<cffile action="read" file="#importDirectory##newFilename#" variable="rawXML" >
		
		<cfset wpXML = xmlParse(rawXML) />
		
		<cfloop condition="allParentsFound eq false">
			<cfset allParentsFound = true />
			<cfloop array="#wpXML.rss.channel.item#" index="item">
				<cfscript>
					if(item["wp:post_type"].xmlText == "post" && len(item["title"].xmlText)) {
						
						// If this content-node has a parent that is 0 then use the parentContentID that was passed in, otherwise try to figure out where it was nested
						if(item["wp:post_parent"].xmlText eq 0) {
							parentContent = rc.$.getBean("content").loadBy(contentID=arguments.rc.parentContentID);
						} else {
							parentContent = rc.$.getBean("content").loadBy(remoteID=item["wp:post_parent"].xmlText);
						}
						
						// If the parentContent doesn't exist yet in Mura, then we will have to come back to this node on the next pass
						if(parentContent.getIsNew()) {
							allParentsFound = false;
							
						// If the parentContent was found, then we can add this content node to mura.
						} else {
							
							// Try to load the content first, in case this is a second upload of the same data
							content = rc.$.getBean("content").loadBy(remoteID=item["wp:post_id"].xmlText);
							
							// Set all the simple values of the content
							content.setParentID(parentContent.getContentID());
							content.setTitle(item["title"].xmlText);
							content.setBody(item["content:encoded"].xmlText);
							content.setRemoteID(item["wp:post_id"].xmlText);
							content.setApproved(1);
							content.setSiteID(rc.$.event('siteID'));
							
							// This will be used to set up 
							categoryList = "";
							
							// Loop over the categories from WP to build out the categoryList to set in the content
							for(var i=1; i<=arrayLen(item.category); i++) {
								var category = rc.$.getBean("category").loadBy(name="#item.category[i].xmlText#");
								if(category.getIsNew()) {
									category.setName(item.category[i].xmlText);
									
									category.save();	
								}
								categoryList = listAppend(categoryList, category.getCategoryID());
							}
							
							// Set the category list into the content
							content.setCategories(categoryList);
							
							// Loop over the comments that were assigned to this wp node
							for(var i=1; i<=arrayLen(item["wp:comment"]); i++) {
								
								// We look to load the comment first before adding it.  We try to find one where the contentID & the date entered match.
								var comment = rc.$.getBean("comment").loadBy(entered="#item["wp:comment"][i]["wp:comment_date"].xmlText#", contentID=content.getContentID());
								
								// If the comment is new, then we can add it.
								if(comment.getIsNew()) {
									
									// Set the simple values of the comment
									comment.setContentID(content.getContentID());
									comment.setName(item["wp:comment"]["wp:comment_author"].xmlText);
									comment.setComments(item["wp:comment"]["wp:comment_content"].xmlText);
									comment.setEntered(item["wp:comment"]["wp:comment_date"].xmlText);
									comment.setUrl(item["wp:comment"]["wp:comment_author_url"].xmlText);
									comment.setIsApproved(1);
									comment.setSiteID(rc.$.event('siteID'));
									
									// Save the comment
									comment.save();	
								}	
							}
							
							// Call save on the content object
							content.save();	
						}
					}
				</cfscript>
			</cfloop>
		</cfloop>
		
	</cffunction>

</cfcomponent>