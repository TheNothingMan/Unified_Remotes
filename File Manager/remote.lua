local fs = libs.fs;
local server = libs.server;
local device = libs.device;
local log = require("log");

-------------------------------------------------------------------

local dialog_items =
{
	{ type="item", text = "Details", id = "details" }, 
	{ type="item", text="Open", id = "open" },
	{ type="item", text="Open All", id = "open_all" },
	{ type="item", text="Copy", id = "copy" }, 
	{ type="item", text="Cut", id = "cut" }, 
	{ type="item", text="Delete", id = "delete" },
	{ type="item", text="Star", id = "star" }
}

local favorite_dialog_items =
{
	{ type="item", text = "Delete", id = "delete" }
}

local paste_item = nil;
local paste_mode = nil;
local selected;
local favorite_selected;
local items = {};
local stack = {};
local favorite_items = {};
-------------------------------------------------------------------

events.focus = function()
	stack = {};
	table.insert(stack, settings.path);
	update();
end

-------------------------------------------------------------------
-- Favorites stuff
-------------------------------------------------------------------
function table.contains(table, element)
  for _, value in pairs(table) do
    if value == element then
      return true
    end
  end
  return false
end

actions.launch = function()
	if settings.fav_path == nil then
		settings.fav_path=fs.combine(fs.remotedir(),"favorites.txt");
	end
end

function add_favorite(path)
	if settings.fav_path == nil then
		settings.fav_path=fs.combine(fs.remotedir(),"favorites.txt");
	end
	if not fs.exists(settings.fav_path) then
		fs.createfile(settings.fav_path);
	end
	if not table.contains(fs.readlines(settings.fav_path), fs.absolute(path)) then
		fs.append(settings.fav_path, fs.absolute(path));
		fs.append(settings.fav_path, "\n");
		device.toast(fs.fullname(path).." added to favorites");
	else
		device.toast(fs.fullname(path).." already starred");
	end
end

actions.star = function(path)
	add_favorite(settings.path);
end

actions.tab_change = function(index)
	if settings.fav_path == nil then
		settings.fav_path=fs.combine(fs.remotedir(),"favorites.txt");
	end
	log.info("hello");
	if index == 1 then
		favorites = fs.readlines(settings.fav_path);
		favorite_items = {};
		for t = 1, #favorites do
			if favorites[t] ~= "" and fs.exists(favorites[t]) then
				table.insert(favorite_items, {
					type = "item",
					icon = "folder",
					path = fs.path(favorites[t]),
					text = fs.fullname(fs.path(favorites[t])),
					isdir = true
				});
				if fs.fullname(fs.path(favorites[t])) == "" then
					favorite_items[t].text = ""..fs.absolute(fs.path(favorites[t]));
				end
				if fs.isfile(fs.absolute(fs.path(favorites[t]))) then
					favorite_items[t].icon = "file";
				end
			end
		end
		server.update({ id="favorites", children=favorite_items});
	end
end

actions.favorite_item = function(i)
	i = i + 1;
	if fs.isdir(favorite_items[i].path) then
		table.insert(stack, settings.path);
		settings.path = favorite_items[i].path;
		update();
		device.toast(favorite_items[i].path);
		server.update({ id="tabs", index=0});
	else
		device.toast("Opening"..favorite_items[i].path);
		actions.open(fs.absolute(favorite_items[i].path));
		
	end
end

-- Invoked when an item in the list is long-pressed.
-------------------------------------------------------------------
actions.favorite_hold = function (i)
	favorit_selected = items[i+1];
	server.update({ type="dialog", ontap="favorite_dialog", children = favorite_dialog_items });
end

actions.favorite_dialog = function (i)
	i = i + 1;
	local action = favorite_dialog_items[i].id;
	
	if action == "delete" then
		device.toast("deleting");
		table.remove(favorite_items, favorite_selected);
		fs.write(settings.fav_path, "");
		for k, v in ipairs(favorite_items) do
			fs.append(settings.fav_path, v["path"]);
		end
		server.update({ id="favorites", children=favorite_items});
	end
end
--xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
-- End of Favorites
--xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

function update ()
	local path = settings.path;
	items = {};
	if path == "" then
		local root = fs.roots();
		local homePath = "~/";
		if OS_WINDOWS then 
			homePath = "%HOMEPATH%"
		end
		local desktopPath = "~/Desktop";
		if OS_WINDOWS then 
			desktopPath = "%HOMEPATH%/Desktop"
		end
		table.insert(items, {
			type = "item",
			icon = "folder",
			text = "Home",
			path = homePath,
			isdir = true});
		table.insert(items, {
			type = "item",
			icon = "folder",
			text = "Desktop",
			path = desktopPath,
			isdir = true});
		for t = 1, #root do
			table.insert(items, {
				type = "item",
				icon = "folder",
				text = root[t],
				path = root[t],
				isdir = true
			});
		end
	else
		local dirs = fs.dirs(path);
		local files = fs.files(path);	
		for t = 1, #dirs do
			table.insert(items, {
				type = "item",
				icon = "folder",
				text = fs.fullname(dirs[t]),
				path = dirs[t],
				isdir = true
			});
		end
		for t = 1, #files do
			table.insert(items, {
				type = "item",
				icon = "file",
				text = fs.fullname(files[t]),
				path = files[t],
				isdir = false
			});
		end
	end
	server.update({ id = "list", children = items});
end

-------------------------------------------------------------------
-- Invoked when an item in the list is pressed.
-------------------------------------------------------------------
actions.item = function (i)
	i = i + 1;
	if items[i].isdir then
		table.insert(stack, settings.path);
		settings.path = items[i].path;
		update();
	else
		actions.open(items[i].path);
	end
end

-------------------------------------------------------------------
-- Invoked when an item in the list is long-pressed.
-------------------------------------------------------------------
actions.hold = function (i)
	selected = items[i+1];
	server.update({ type="dialog", ontap="dialog", children = dialog_items });
end

-------------------------------------------------------------------
-- Invoked when a dialog item is selected.
-------------------------------------------------------------------

function show_dir_details (path)
	local details = 
		" Name: " .. fs.fullname(path) .. 
		"\n Location: " .. fs.parent(path) ..
		"\n Files: " .. #fs.files(path) ..
		"\n Folders: " .. #fs.dirs(path) ..
		"\n Created: " .. os.date("%c", fs.created(path));
	server.update({ type = "dialog", text = details, children = {{type="button", text="OK"}} });
end

function show_file_details (path)
	local details =
		" Name: " .. fs.fullname(path) .. 
		"\n Location: " .. fs.parent(path) ..
		"\n Size: " .. fs.size(path) ..
		"\n Created: " .. os.date("%c", fs.created(path)) ..
		"\n Modified: " .. os.date("%c", fs.modified(path));
	server.update({ type = "dialog", text = details, children = {{type="button", text="OK"}} });
end

actions.dialog = function (i)
	i = i + 1;
	local action = dialog_items[i].id;
	local path = selected.path;
	
	if action == "details" then
		
		-- Show details for file or folder
		if (fs.isdir(path)) then
			show_dir_details(path);
		else
			show_file_details(path);
		end
		
	elseif (action == "cut") then
	
		-- Explain how to move
		server.update({
			type = "message", 
			text = "Long-press a folder to paste."
		});
		if (paste_mode == nil) then
			table.insert(dialog_items, { type="item", text="Paste", id="paste"});
		end
		paste_item = selected;
		paste_mode = "move";
		update();
	
	elseif (action == "copy") then
	
		-- Explain how to move
		server.update({
			type = "message", 
			text = "Long-press a folder to paste."
		});
		if (paste_mode == nil) then
			table.insert(dialog_items, { type="item", text="Paste", id="paste"});
		end
		paste_item = selected;
		paste_mode = "copy";
		update();
	
	elseif (action == "paste") then
		
		-- Determine source and destination
		local source = paste_item.path;
		local destination = "";
		if (fs.isdir(path)) then
			destination = fs.combine(path, fs.fullname(paste_item.path));
		else
			destination = fs.combine(fs.parent(path), fs.fullname(paste_item.path));
		end
		
		-- Perform paste depending on mode
		if (paste_mode == "move") then
			fs.move(source, destination);
		elseif (paste_mode == "copy") then
			fs.copy(source, destination);
		end
		
		-- Reset paste stuff
		table.remove(dialog_items);
		paste_item = nil;
		paste_mode = nil;
		update();
		
	elseif (action == "delete") then
	
		-- Prompt to delete
		server.update({ 
			type="dialog", text="Are you sure you want to delete " .. path .. "?", 
			children = {
				{ type="button", text="Yes", ontap="delete" }, 
				{ type="button", text="No" }
			}
		});
	
	elseif (action == "open") then
	
		-- Open the file or folder
		actions.open(path);
	
	elseif (action == "open_all") then
	
		-- Open all the files inside a folder
		if (fs.isdir(path)) then
			actions.open_all(path);
		else
			actions.open_all(fs.parent(path));
		end
	elseif (action == "star") then
		
		--add a file or path to favorites
		add_favorite(path);
		
	end

end

actions.delete = function ()
	local path = selected.path;
	fs.delete(path, true);
	update();
end

actions.back = function ()
	settings.path = table.remove(stack);
	update();
	if #stack == 0 then
		table.insert(stack, "");
	end
end

actions.up = function ()
	table.insert(stack, settings.path);
	settings.path = fs.parent(stack[#stack]);
	update();
end

actions.home = function ()
	table.insert(stack, settings.path);
	settings.path = "";
	update();
end

actions.refresh = function ()
	update();
end

actions.goto = function ()
	server.update({id = "go", type="input", ontap="gotopath", title="Goto"});
end

actions.gotopath = function (p)
	if fs.isfile(p) then
		actions.open(p);
	else
		settings.path = p;
		update();
	end
end

--@help Open file or folder on computer.
--@param path:string The path to the file
actions.open = function (path)
	os.open(path);
end

--@help Open all files in specified path.
--@param path The path to the files
actions.open_all = function (path)
	os.openall(path);
end