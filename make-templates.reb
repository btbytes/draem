Rebol [
	Title: "Make Django Templates"
	Description: {

	Currently the way the realityhandbook website works is that there is
	no database, just a bunch of templates... one generated for each
	article, and then for each tag + category + character.  These 
	templates participate in Django's inheritance model... so each one
	adds its content to a baseline template without repeating the
	boilerplate.

	}

	Home: http://realityhandbook.org/
	License: 'mit

	Date: 20-Oct-2010
	Version: 3.0.4

	; Header conventions: http://www.rebol.org/one-click-submission-help.r
	File: %make-templates.reb
	Type: 'dialect
	Level: 'intermediate
]

do %common.reb

do %markdown.reb

do %htmlify.reb

django-block: function [name [string!] stuff [string! block!] /inline] [
	combine [
		"{% block" space name space "%}"
		unless inline newline
		stuff
		unless inline newline
		"{% endblock" space name space "%}"
		newline
	]
]

django-path: function [stuff [block!] ] [
	django-block "path" [
		<li>
			{<a href="} draem/config/site-url {" title="Home">} {Home} </a>
		</li>
		stuff
	]
]

django-google-analytics: function [] [
	combine [
		django-block "ga_id" [
			draem/config/google-analytics/tracking-id
		]
		django-block "ga_property" [
			draem/config/google-analytics/property
		]
	]
]

django-extends: function [template [file!]] [
	combine [
		["{% extends" space {"} to string! template {"} space "%}"]
		django-google-analytics
	]	
]

link-to-tag: function [tag [word!] /count num] [
	combine [
		open-anchor rejoin [
			draem/config/site-url "tag/" stringify/dashes tag {/}
		]
		stringify tag
		close-anchor
		if count [
			[space {:} space num {<br />}]
		]
	]
]

link-to-character: function [character [word!] /count num] [
	combine [
		open-anchor rejoin [
			draem/config/site-url "character/" lowercase stringify/dashes character {/}
		]
		stringify character
		close-anchor
		if count [
			[space {:} space num {<br />}]
		]
	]
]

write-entry: function [
	entry [object!]

	earlier-entry [none! object!]

	later-entry [none! object!]

	html-file [file!]
] [

	print [{write-entry} html-file]
	
	content-html: htmlify entry/content

	sorted-tags: draem/entry-tags-by-popularity entry/header
	unsorted-characters: select draem/indexes/slug-to-characters entry/header/slug
	main-tag: first sorted-tags

	is-post: any [earlier-entry later-entry]

	;-- Currently we get the site global CSS from the configuration, and then
	;-- read any added literal CSS or included files from the Draem header

	css-all: append
		copy in-as-block draem/config 'css
		in-as-block entry/header 'css

	either empty? css-all [
		css-block: none
	] [
		css-block: copy ["{{ block.super }}"]

		foreach item css-all [
			append css-block either string? item [
				trim-head-tail-lines css-text: copy item
				take/last css-text ;--django-block adds newline
				combine [
					<style type="text/css">
					css-text
					</style>
				]
			] [
				combine [
					{<link rel="stylesheet" type="text/css" href=}
					{"} to string! item {"}
					{>}
				]
			]
		]
	]

	;-- Script handling parallels the CSS handling... defaults come from the
	;-- configuration, added scripts come from the Draem header

	script-all: append
		copy in-as-block draem/config 'javascript
		in-as-block entry/header 'javascript

	either empty? script-all [
		script-block: none
	] [
		script-block: copy ["{{ block.super }}"]

		foreach item script-all [
			append script-block either string? item [
				trim-head-tail-lines js-text: copy item
				take/last js-text ;-- django-block adds newline

				combine [
					<script type="text/javascript">
					(js-text) 
					</script>
				]
			] [
				combine [
					{<script type="text/javascript" src=}
					{"} to string! item {"} {>}
					{</script>}
				]
			]
		]
	]

	html: combine [
		django-extends (either is-post %post.html %page.html)
		
		if css-block [
			django-block "css" css-block
		]

		if script-block [
			django-block "scripts" script-block
		]

		;-- <meta name="keywords" ...> information
		django-block/inline "keywords" [
			combine/with (map-each tag sorted-tags [stringify tag]) [{,} space]
		]
		
		;-- <meta name="description" ...> information
		django-block "description" [
			combine/with [
				[{Author:} space draem/config/site-author]
				[{Title:} space entry/header/title]
				[{Date:} space entry/header/date/date]
				[{Length:} space length? (split content-html space) space "words"]
			] [{,} space]
		]
		
		django-block/inline "title" [
			if main-tag [stringify main-tag]
			space ":"
			space entry/header/title
		]
		
		django-block/inline "header" [
			entry/header/title
		]
		
		django-path [
			if main-tag [				
				<li>
					link-to-tag main-tag
				</li>
			]
			<li> <span>
				entry/header/title
			</span> </li>
		]
		
		django-block "date" [
			entry/header/date
		]

		django-block "tags" [
			either empty? sorted-tags [
				"(none)"
			] [
				combine/with (map-each tag sorted-tags [
					combine [
						{<a href="} draem/config/site-url {tag/}
						stringify/dashes tag
						{/" class="post-tag" rel="tag">} stringify tag </a>
					]
				]) {, }
			]
		]

		django-block "characters" [
			either empty? unsorted-characters [
				"(none)"
			] [
				 combine/with (map-each character unsorted-characters [
					combine [
						{<a href="} draem/config/site-url {character/}
						stringify/dashes character
						{/">} stringify character {</a>}
					]
				]) {, }
			]
		]

		django-block "content" [
			content-html
		]
		
		if later-entry [
			django-block/inline {nexttitle} [
				later-entry/header/title
			]
			django-block/inline {nexturl} [
				url-for-entry later-entry
			]
		]

		if earlier-entry [
			django-block/inline {prevtitle} [
				earlier-entry/header/title
			]
			django-block/inline {prevurl} [
				url-for-entry earlier-entry
			]
		]

		django-block "footer" [
			draem/config/site-footer
		]
	]

	make-dir/deep first split-path html-file
	write/lines html-file html
]

make-templates: function [
	{ Generates the django templates from the entries and draem/indexes }

	entries [block!]
	indexes [object!]
	templates-dir [file!]
] [
	draem/stage "TEMPLATES OUTPUT"

	unless exists? templates-dir [
		make-dir templates-dir
	]

	;; WRITE OUT THE INDIVIDUAL ENTRIES, MAKE USE OF SORTING INFORMATION
	;; OMIT ABOUT AND CONTACT CATEGORIES FROM MAIN INDEX AND USE SPECIAL URL
	;; ALSO WRITE OUT A MAIN PAGE IN REVERSE CHRONOLOGICAL ORDER

	draem/stage "MAIN OUTPUT LOOP"

	index-html: combine [
		django-extends %base.html

		django-block/inline "title" [
			draem/config/site-title
		]

		django-block/inline "header" [
			draem/config/site-tagline
		]

		django-block/inline "path" [
			<li> <span> draem/config/site-url </span> </li>
		]		

		"{% block main %}"

		draem/config/site-intro
	]

	iter: entries
	while [not tail? iter] [
		entry: first iter
		earlier-entry: draem/previous-entry entry/header ;-- maybe none
		later-entry: draem/next-entry entry/header ;-- maybe none

		write-entry entry earlier-entry later-entry (draem/config/file-for-template entry/header)
		unless all [
			none? earlier-entry
			none? later-entry
		] [
			;-- It's not "chained" into the index, so leave it standing alone
			append index-html link-to-entry entry
		]

		iter: next iter
	]

	append index-html "{% endblock main %}"

	append index-html combine [
		django-block/inline "footer" [
			draem/config/site-footer
		]		
	]

	write/lines rejoin [templates-dir %index.html] index-html



	;; GENERATE THE TAG LIST AND A PAGE FOR EACH TAG

	draem/stage "TAG OUTPUT"
	tag-list-html: combine [
		django-extends %taglist.html

		django-block/inline "title" [
			{All Tags}
		]
		
		django-block/inline "header" [
			{All Tags for} space draem/config/site-name
		]

		django-path [
			<li> <span> {Tag List} </span> </li>
		]
		
		"{% block tags %}"
	]

	taglist-sorted: make-sorted-block-from-map draem/indexes/tag-to-entries

	foreach [tag entries] taglist-sorted [
		assert [word? tag]
		assert [block? entries]

		directory: rejoin [templates-dir %tags/]
		if (not exists? directory) [
			make-dir directory
		]
		append tag-list-html link-to-tag/count tag length? entries
		
		tag-html: combine [
			django-extends %tag.html

			django-block/inline "title" [
				{tag:} space (stringify tag)
			]

			django-block/inline "header" [
				(stringify tag)
			]
		
			django-path [
				<li>
					{<a href="} draem/config/site-url {tag/" title="Tag List">}
						{Tag}
					</a>
				</li>
				<li> <span> (stringify tag) </span> </li>
			]
			
			"{% block entries %}"
		]

		foreach entry entries [
			if true or true? all [ ;-- allow pages to appear in the tag list for now
				draem/next-entry entry/header
				draem/previous-entry entry/header
			] [
				append tag-html link-to-entry entry
			]
		]
		
		append tag-html "{% endblock entries %}"
		write/lines (rejoin [directory stringify/dashes tag %.html]) tag-html
	]

	append tag-list-html "{% endblock tags %}"
	write/lines (join templates-dir %tags.html) tag-list-html


	;; GENERATE THE CHARACTER LIST AND A PAGE FOR EACH CHARACTER

	draem/stage "CHARACTER OUTPUT"
	character-list-html: combine [
		django-extends %characterlist.html

		django-block/inline "title" [
			{Character List}
		]

		django-block/inline "header" [
			{Character List}
		]

		django-path [
			<li> <span> {Character List} </span> </li>
		]

		"{% block characters %}"
	]

	characterlist-sorted: make-sorted-block-from-map draem/indexes/character-to-entries

	foreach [character entries] characterlist-sorted [
		assert [word? character]
		assert [block? entries]

		directory: to file! (join templates-dir %characters/)
		unless exists? directory [
			make-dir directory
		]
		append character-list-html link-to-character/count character length? entries
		
		character-html: combine [
			django-extends %character.html

			django-block/inline "title" [
				{character:} space (stringify character)
			]
			
			django-block/inline "header" [
				(stringify character)
			]
			
			django-path [
				<li>
					{<a href="} draem/config/site-url {character/" title="Character List">}
						{Character}
					</a>
				</li>
				<li>
					<span> (stringify character) </span>
				</li>
			]
			
			"{% block entries %}"
		]

		foreach entry entries [
			if true or true? all [ ;-- allow pages to appear in the character list for now
				draem/next-entry entry/header
				draem/previous-entry entry/header
			] [
				append character-html link-to-entry entry
			]
		]
				
		append character-html "{% endblock entries %}"
		write/lines rejoin [directory lowercase stringify/dashes character ".html"] character-html
	]

	append character-list-html "{% endblock characters %}"
	write/lines (join templates-dir %characters.html) character-list-html
]
