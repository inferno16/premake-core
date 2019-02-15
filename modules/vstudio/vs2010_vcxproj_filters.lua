--
-- vs2010_vcxproj_filters.lua
-- Generate a Visual Studio 201x C/C++ filters file.
-- Copyright (c) Jason Perkins and the Premake project
--

	local p = premake
	local project = p.project
	local tree = p.tree

	local m = p.vstudio.vc2010


--
-- Generate a Visual Studio 201x C++ project, with support for the new platforms API.
--

	function m.generateFilters(prj)
		m.xmlDeclaration()
		m.filtersProject()
		m.generateFilterExtensions(prj)
		m.uniqueIdentifiers(prj)
		m.filterGroups(prj)
		p.out('</Project>')
	end


--
-- Output the XML declaration and opening <Project> tag.
--

	function m.filtersProject()
		local action = p.action.current()
		p.push('<Project ToolsVersion="%s" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">',
			action.vstudio.filterToolsVersion or action.vstudio.toolsVersion)
	end



	function m.filterGroups(prj)
		local groups = m.categorizeSources(prj)
		for _, group in ipairs(groups) do
			group.category.emitFilter(prj, group)
		end
	end

--
-- Generates a string containing the wildcarded extensions that can 
-- later be added between <Extensions> tags in the filter file
--

	function m.generateFilterExtensions(prj)
		local vpaths = prj.vpaths
		local extensions = {}
		
		for _, vpath in pairs(vpaths) do
			for name, data in pairs(vpath) do
				extensions[name] = {}
				local tbl = extensions[name]
				tbl.extensionString = ""
				for i, path in ipairs(data) do
					local ext = string.match(path, "%*%.(.+)$") -- /\*\.(.+)$/ - captures wildcard extensions
					if ext and not tbl[ext] then -- if it matches the pattern and is not yet added
						tbl.extensionString = tbl.extensionString .. iif(tbl.extensionString == "", ext, ";" .. ext)
						tbl[ext] = 1 -- used for avoiding duplicates
					end
				end
				-- setting the top level value to the string or nil if empty (removing the duplicates LUT)
				extensions[name] = iif(tbl.extensionString ~= "", tbl.extensionString, nil)
			end
		end
		prj.filterExtensions = extensions
	end

--
-- The first portion of the filters file assigns unique IDs to each
-- directory or virtual group. Would be cool if we could automatically
-- map vpaths like "**.h" to an <Extensions>h</Extensions> element.
--

	function m.uniqueIdentifiers(prj)
		local tr = project.getsourcetree(prj)
		local contents = p.capture(function()
			p.push()
			tree.traverse(tr, {
				onbranch = function(node, depth)
					local filterName = path.translate(node.path, '\\')
					p.push('<Filter Include="%s">', filterName)
					p.w('<UniqueIdentifier>{%s}</UniqueIdentifier>', os.uuid(node.path))
					if(prj.filterExtensions and prj.filterExtensions[filterName]) then
						p.w("<Extensions>%s</Extensions>", prj.filterExtensions[filterName])
					end
					p.pop('</Filter>')
				end
			}, false)
			p.pop()
		end)

		if #contents > 0 then
			p.push('<ItemGroup>')
			p.outln(contents)
			p.pop('</ItemGroup>')
		end
	end


	function m.filterGroup(prj, group, tag)
		local files = group.files
		if files and #files > 0 then
			p.push('<ItemGroup>')
			for _, file in ipairs(files) do
				if file.parent.path then
					p.push('<%s Include=\"%s\">', tag, path.translate(file.relpath))
					p.w('<Filter>%s</Filter>', path.translate(file.parent.path, '\\'))
					p.pop('</%s>', tag)
				else
					p.w('<%s Include=\"%s\" />', tag, path.translate(file.relpath))
				end
			end
			p.pop('</ItemGroup>')
		end
	end

