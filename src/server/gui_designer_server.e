note
	description: "[
		GUI Designer Server using simple_web.

		Serves the HTMX-based designer frontend and handles:
		- Spec CRUD operations (create, read, update, delete)
		- Control palette API
		- Screen management
		- AI suggestion integration (future)
		- Final spec generation
	]"
	author: "Claude Code"
	date: "$Date$"
	revision: "$Revision$"

class
	GUI_DESIGNER_SERVER

inherit
	GUI_DESIGNER_LOGGER

create
	make

feature {NONE} -- Initialization

	make (a_port: INTEGER)
			-- Create server on specified port.
		require
			valid_port: a_port > 0 and a_port < 65536
		do
			port := a_port
			create server.make (a_port)
			create specs.make (10)
			specs_directory := "D:\prod\simple_gui_designer\specs"
			load_specs_from_directory
			if specs.is_empty then
				create current_spec.make ("untitled")
				specs.force (current_spec, "untitled")
			else
				specs.start
				current_spec := specs.item_for_iteration
			end
			setup_routes
		ensure
			port_set: port = a_port
			specs_created: specs /= Void
			current_spec_created: current_spec /= Void
		end

	load_specs_from_directory
			-- Load all JSON spec files from specs directory.
		local
			l_dir: DIRECTORY
			l_json: SIMPLE_JSON
			l_file_path: STRING_32
		do
			log_debug ("[INIT] Loading specs from directory: " + specs_directory)
			create l_dir.make (specs_directory)
			if l_dir.exists then
				create l_json
				across l_dir.linear_representation as al_entry loop
					if al_entry.ends_with (".json") then
						l_file_path := specs_directory + "/" + al_entry
						log_debug ("[INIT] Attempting to parse: " + l_file_path.to_string_8)
						if attached l_json.parse_file (l_file_path) as al_parsed and then
						   al_parsed.is_object and then attached al_parsed.as_object as al_obj then
							if al_obj.has_key ("app_name") or al_obj.has_key ("app") then
								load_spec_from_json (al_obj, al_entry)
							else
								log_warning ("[INIT] Skipping file without app_name/app: " + l_file_path.to_string_8)
							end
						else
							log_parse_error (l_file_path.to_string_8, l_json.errors_as_string.to_string_8)
						end
					end
				end
			else
				log_warning ("[INIT] Specs directory not found: " + specs_directory)
			end
		end

	load_spec_from_json (a_json: SIMPLE_JSON_OBJECT; a_filename: STRING_32)
			-- Create spec from JSON and add to specs table.
		local
			l_spec: GUI_DESIGNER_SPEC
			l_name: STRING_32
		do
			create l_spec.make_from_json (a_json)
			l_name := l_spec.app_name
			specs.force (l_spec, l_name)
			log_spec_loaded (l_name.to_string_8, a_filename.to_string_8)
			log_debug ("[SPEC] " + l_name.to_string_8 + " has " + l_spec.screens.count.out + " screens")
		end

	setup_routes
			-- Configure all routes for the designer.
		do
			-- Static pages
			server.on_get ("/", agent handle_index)
			server.on_get ("/designer", agent handle_designer)

			-- Spec API (specific routes before parameterized routes)
			server.on_get ("/api/specs", agent handle_list_specs)
			server.on_get ("/api/specs/download-all", agent handle_download_all_specs)
			server.on_post ("/api/specs/upload", agent handle_upload_spec)
			server.on_get ("/api/specs/{id}", agent handle_get_spec)
			server.on_post ("/api/specs", agent handle_create_spec)
			server.on_put ("/api/specs/{id}", agent handle_update_spec)
			server.on_delete ("/api/specs/{id}", agent handle_delete_spec)

			-- Screen API
			server.on_get ("/api/specs/{spec_id}/screens", agent handle_list_screens)
			server.on_post ("/api/specs/{spec_id}/screens", agent handle_create_screen)
			server.on_put ("/api/specs/{spec_id}/screens/{screen_id}", agent handle_update_screen)
			server.on_delete ("/api/specs/{spec_id}/screens/{screen_id}", agent handle_delete_screen)

			-- Control API
			server.on_get ("/api/palette", agent handle_control_palette)
			server.on_post ("/api/specs/{spec_id}/screens/{screen_id}/controls", agent handle_add_control)
			server.on_put ("/api/specs/{spec_id}/screens/{screen_id}/controls/{control_id}", agent handle_update_control)
			server.on_delete ("/api/specs/{spec_id}/screens/{screen_id}/controls/{control_id}", agent handle_delete_control)

			-- Container API (children, tabs)
			server.on_post ("/api/specs/{spec_id}/screens/{screen_id}/controls/{parent_id}/children", agent handle_add_child_control)
			server.on_put ("/api/specs/{spec_id}/screens/{screen_id}/controls/{control_id}/active-tab", agent handle_set_active_tab)
			server.on_post ("/api/specs/{spec_id}/screens/{screen_id}/controls/{control_id}/tabs", agent handle_add_tab)

			-- HTMX partials (return HTML fragments)
			server.on_get ("/htmx/canvas/{spec_id}/{screen_id}", agent handle_canvas_partial)
			server.on_get ("/htmx/palette", agent handle_palette_partial)
			server.on_get ("/htmx/properties/{spec_id}/{screen_id}/{control_id}", agent handle_properties_partial)
			server.on_get ("/htmx/screen-list/{spec_id}", agent handle_screen_list_partial)
			server.on_get ("/htmx/spec-list", agent handle_spec_list_partial)

			-- Export
			server.on_post ("/api/specs/{id}/finalize", agent handle_finalize_spec)
			server.on_get ("/api/specs/{id}/export", agent handle_export_spec)

			-- Save/Download
			server.on_post ("/api/specs/{id}/save", agent handle_save_spec_to_disk)
			server.on_get ("/api/specs/{id}/download", agent handle_download_spec)
		end

feature -- Access

	port: INTEGER
			-- Server port.

	server: SIMPLE_WEB_SERVER
			-- HTTP server instance.

	specs: HASH_TABLE [GUI_DESIGNER_SPEC, STRING_32]
			-- All loaded specs by ID/app_name.

	current_spec: GUI_DESIGNER_SPEC
			-- Currently active spec.

	specs_directory: STRING
			-- Directory to load/save spec files from.

feature -- Server Control

	start
			-- Start the server (blocking).
		do
			log_server_start (port, specs.count)
			log_info ("[SERVER] Open http://localhost:" + port.out + " in your browser")
			print ("GUI Designer starting on port " + port.out + "...%N")
			print ("Open http://localhost:" + port.out + " in your browser.%N")
			print ("Log file: D:\prod\simple_gui_designer\gui_designer.log%N")
			server.start
		end

feature -- Page Handlers

	handle_index (a_request: SIMPLE_WEB_SERVER_REQUEST; a_response: SIMPLE_WEB_SERVER_RESPONSE)
			-- Serve the main index page.
		do
			log_request ("GET", "/")
			log_debug ("[PAGE] Serving index page with " + specs.count.out + " specs")
			a_response.send_html (index_html)
		end

	handle_designer (a_request: SIMPLE_WEB_SERVER_REQUEST; a_response: SIMPLE_WEB_SERVER_RESPONSE)
			-- Serve the designer page.
		local
			l_spec_name: STRING_32
			l_html: STRING
		do
			log_request ("GET", "/designer")
			if attached a_request.query_parameter ("spec") as al_spec then
				l_spec_name := al_spec
				log_debug ("[PAGE] Designer page with spec param: " + l_spec_name.to_string_8)
			else
				l_spec_name := current_spec.app_name
				log_debug ("[PAGE] Designer page using current spec: " + l_spec_name.to_string_8)
			end
			l_html := designer_html_for_spec (l_spec_name)
			a_response.send_html (l_html)
		end

feature -- Spec API Handlers

	handle_list_specs (a_request: SIMPLE_WEB_SERVER_REQUEST; a_response: SIMPLE_WEB_SERVER_RESPONSE)
			-- List all specs.
		local
			l_arr: SIMPLE_JSON_ARRAY
			l_obj: SIMPLE_JSON_OBJECT
		do
			log_request ("GET", "/api/specs")
			log_debug ("[API] Listing " + specs.count.out + " specs")
			create l_arr.make
			across specs as al_spec loop
				create l_obj.make
				l_obj.put_string (al_spec.app_name, "name").do_nothing
				l_obj.put_integer (al_spec.version, "version").do_nothing
				l_obj.put_integer (al_spec.screens.count, "screen_count").do_nothing
				l_arr.add_object (l_obj).do_nothing
			end
			a_response.send_json (l_arr.as_json)
		end

	handle_get_spec (a_request: SIMPLE_WEB_SERVER_REQUEST; a_response: SIMPLE_WEB_SERVER_RESPONSE)
			-- Get single spec.
		do
			log_request ("GET", a_request.path.to_string_8)
			if attached a_request.path_parameter ("id") as al_id and then attached specs.item (al_id) as al_spec then
				log_debug ("[API] Found spec: " + al_id.to_string_8 + " with " + al_spec.screens.count.out + " screens")
				a_response.send_json (al_spec.to_json.as_json)
			else
				log_not_found ("Spec", a_request.path_parameter ("id"))
				a_response.set_not_found
				a_response.send_json ("{%"error%":%"Spec not found%"}")
			end
		end

	handle_create_spec (a_request: SIMPLE_WEB_SERVER_REQUEST; a_response: SIMPLE_WEB_SERVER_RESPONSE)
			-- Create new spec.
		local
			l_spec: GUI_DESIGNER_SPEC
		do
			log_request ("POST", "/api/specs")
			if attached a_request.body_as_json as al_json and then
			   attached al_json.string_item ("name") as al_name then
				log_spec_created (al_name.to_string_8)
				create l_spec.make (al_name)
				specs.force (l_spec, al_name)
				current_spec := l_spec
				a_response.set_created
				a_response.send_json (l_spec.to_json.as_json)
			else
				log_bad_request ("Missing name field in create spec request")
				a_response.set_bad_request
				a_response.send_json ("{%"error%":%"Invalid request - name required%"}")
			end
		end

	handle_update_spec (a_request: SIMPLE_WEB_SERVER_REQUEST; a_response: SIMPLE_WEB_SERVER_RESPONSE)
			-- Update existing spec.
		do
			log_request ("PUT", a_request.path.to_string_8)
			if attached a_request.path_parameter ("id") as al_id and then attached specs.item (al_id) as al_spec then
				if attached a_request.body_as_json as al_json then
					log_debug ("[API] Updating spec: " + al_id.to_string_8)
					al_spec.apply_json (al_json)
					a_response.send_json (al_spec.to_json.as_json)
				else
					log_bad_request ("Invalid JSON in update spec request")
					a_response.set_bad_request
					a_response.send_json ("{%"error%":%"Invalid JSON%"}")
				end
			else
				log_not_found ("Spec", a_request.path_parameter ("id"))
				a_response.set_not_found
				a_response.send_json ("{%"error%":%"Spec not found%"}")
			end
		end

	handle_delete_spec (a_request: SIMPLE_WEB_SERVER_REQUEST; a_response: SIMPLE_WEB_SERVER_RESPONSE)
			-- Delete spec.
		do
			log_request ("DELETE", a_request.path.to_string_8)
			if attached a_request.path_parameter ("id") as al_id and then specs.has (al_id) then
				log_spec_deleted (al_id.to_string_8)
				specs.remove (al_id)
				a_response.set_no_content
				a_response.send_empty
			else
				log_not_found ("Spec", a_request.path_parameter ("id"))
				a_response.set_not_found
				a_response.send_json ("{%"error%":%"Spec not found%"}")
			end
		end

feature -- Screen API Handlers

	handle_list_screens (a_request: SIMPLE_WEB_SERVER_REQUEST; a_response: SIMPLE_WEB_SERVER_RESPONSE)
			-- List screens in a spec.
		local
			l_arr: SIMPLE_JSON_ARRAY
		do
			log_request ("GET", a_request.path.to_string_8)
			if attached a_request.path_parameter ("spec_id") as al_spec_id and then attached specs.item (al_spec_id) as al_spec then
				log_debug ("[API] Listing " + al_spec.screens.count.out + " screens for spec " + al_spec_id.to_string_8)
				create l_arr.make
				across al_spec.screens as al_screen loop
					l_arr.add_object (al_screen.to_json).do_nothing
				end
				a_response.send_json (l_arr.as_json)
			else
				log_not_found ("Spec", a_request.path_parameter ("spec_id"))
				a_response.set_not_found
				a_response.send_json ("{%"error%":%"Spec not found%"}")
			end
		end

	handle_create_screen (a_request: SIMPLE_WEB_SERVER_REQUEST; a_response: SIMPLE_WEB_SERVER_RESPONSE)
			-- Create new screen.
		local
			l_screen: GUI_DESIGNER_SCREEN
		do
			log_request ("POST", a_request.path.to_string_8)
			if attached a_request.path_parameter ("spec_id") as al_spec_id and then attached specs.item (al_spec_id) as al_spec then
				if attached a_request.body_as_json as al_json and then
				   attached al_json.string_item ("id") as al_id and then
				   attached al_json.string_item ("title") as al_title then
					log_screen_created (al_spec_id.to_string_8, al_id.to_string_8)
					create l_screen.make (al_id, al_title)
					al_spec.add_screen (l_screen)
					a_response.set_created
					a_response.send_json (l_screen.to_json.as_json)
				else
					log_bad_request ("Missing id/title in create screen request")
					a_response.set_bad_request
					a_response.send_json ("{%"error%":%"id and title required%"}")
				end
			else
				log_not_found ("Spec", a_request.path_parameter ("spec_id"))
				a_response.set_not_found
				a_response.send_json ("{%"error%":%"Spec not found%"}")
			end
		end

	handle_update_screen (a_request: SIMPLE_WEB_SERVER_REQUEST; a_response: SIMPLE_WEB_SERVER_RESPONSE)
			-- Update screen.
		do
			log_request ("PUT", a_request.path.to_string_8)
			if attached a_request.path_parameter ("spec_id") as al_spec_id and then
			   attached a_request.path_parameter ("screen_id") as al_screen_id and then
			   attached specs.item (al_spec_id) as al_spec and then
			   attached al_spec.screen_by_id (al_screen_id) as al_screen then
				if attached a_request.body_as_json as al_json then
					log_screen_updated (al_spec_id.to_string_8, al_screen_id.to_string_8)
					al_screen.apply_json (al_json)
					a_response.send_json (al_screen.to_json.as_json)
				else
					log_bad_request ("Invalid JSON in update screen request")
					a_response.set_bad_request
					a_response.send_json ("{%"error%":%"Invalid JSON%"}")
				end
			else
				log_not_found ("Screen", a_request.path_parameter ("screen_id"))
				a_response.set_not_found
				a_response.send_json ("{%"error%":%"Screen not found%"}")
			end
		end

	handle_delete_screen (a_request: SIMPLE_WEB_SERVER_REQUEST; a_response: SIMPLE_WEB_SERVER_RESPONSE)
			-- Delete screen.
		do
			log_request ("DELETE", a_request.path.to_string_8)
			if attached a_request.path_parameter ("spec_id") as al_spec_id and then
			   attached a_request.path_parameter ("screen_id") as al_screen_id and then
			   attached specs.item (al_spec_id) as al_spec then
				log_screen_deleted (al_spec_id.to_string_8, al_screen_id.to_string_8)
				al_spec.remove_screen (al_screen_id)
				a_response.set_no_content
				a_response.send_empty
			else
				log_not_found ("Spec", a_request.path_parameter ("spec_id"))
				a_response.set_not_found
				a_response.send_json ("{%"error%":%"Spec not found%"}")
			end
		end

feature -- Control API Handlers

	handle_control_palette (a_request: SIMPLE_WEB_SERVER_REQUEST; a_response: SIMPLE_WEB_SERVER_RESPONSE)
			-- Return available control types.
		do
			log_request ("GET", "/api/palette")
			log_debug ("[API] Serving control palette JSON")
			a_response.send_json (control_palette_json)
		end

	handle_add_control (a_request: SIMPLE_WEB_SERVER_REQUEST; a_response: SIMPLE_WEB_SERVER_RESPONSE)
			-- Add control to screen.
		local
			l_control: GUI_DESIGNER_CONTROL
		do
			log_request ("POST", a_request.path.to_string_8)
			if attached a_request.path_parameter ("spec_id") as al_spec_id and then
			   attached a_request.path_parameter ("screen_id") as al_screen_id and then
			   attached specs.item (al_spec_id) as al_spec and then
			   attached al_spec.screen_by_id (al_screen_id) as al_screen then
				if attached a_request.body_as_json as al_json and then
				   al_json.has_all_keys (<<"id", "type">>) then
					create l_control.make_from_json (al_json)
					log_control_added (l_control.id.to_string_8, l_control.control_type.to_string_8, al_screen_id.to_string_8)
					al_screen.add_control (l_control)
					a_response.set_created
					a_response.send_json (l_control.to_json.as_json)
				else
					log_bad_request ("Missing id/type in add control request")
					a_response.set_bad_request
					a_response.send_json ("{%"error%":%"id and type required%"}")
				end
			else
				log_not_found ("Screen", a_request.path_parameter ("screen_id"))
				a_response.set_not_found
				a_response.send_json ("{%"error%":%"Screen not found%"}")
			end
		end

	handle_update_control (a_request: SIMPLE_WEB_SERVER_REQUEST; a_response: SIMPLE_WEB_SERVER_RESPONSE)
			-- Update control from form data or JSON.
		local
			l_form: HASH_TABLE [STRING_32, STRING_32]
			l_form_fields: STRING
		do
			log_request ("PUT", a_request.path.to_string_8)
			if attached a_request.path_parameter ("spec_id") as al_spec_id and then
			   attached a_request.path_parameter ("screen_id") as al_screen_id and then
			   attached a_request.path_parameter ("control_id") as al_control_id and then
			   attached specs.item (al_spec_id) as al_spec and then
			   attached al_spec.screen_by_id (al_screen_id) as al_screen and then
			   attached al_screen.control_by_id (al_control_id) as al_control then
				log_debug ("[CONTROL] Found control " + al_control_id.to_string_8 + " BEFORE update: row=" + al_control.grid_row.out + " col=" + al_control.grid_col.out + " span=" + al_control.col_span.out)
				-- Try JSON first, then form data
				if attached a_request.body_as_json as al_json then
					log_debug ("[CONTROL] Applying JSON update to " + al_control_id.to_string_8)
					al_control.apply_json (al_json)
					log_control_updated (al_control_id.to_string_8, al_control.grid_row, al_control.grid_col, al_control.col_span)
					a_response.send_json (al_control.to_json.as_json)
				else
					-- Form data from HTMX
					l_form := a_request.form_data
					if not l_form.is_empty then
						create l_form_fields.make_empty
						across l_form as al_field loop
							l_form_fields.append (@al_field.key.to_string_8 + "=" + al_field.to_string_8 + " ")
						end
						log_form_data (l_form_fields)
						apply_form_to_control (al_control, l_form)
						log_control_updated (al_control_id.to_string_8, al_control.grid_row, al_control.grid_col, al_control.col_span)
						a_response.send_json (al_control.to_json.as_json)
					else
						log_bad_request ("No form data or JSON body received")
						a_response.set_bad_request
						a_response.send_json ("{%"error%":%"No data received%"}")
					end
				end
			else
				log_not_found ("Control", a_request.path_parameter ("control_id"))
				a_response.set_not_found
				a_response.send_json ("{%"error%":%"Control not found%"}")
			end
		end

	apply_form_to_control (a_control: GUI_DESIGNER_CONTROL; a_form: HASH_TABLE [STRING_32, STRING_32])
			-- Apply form field values to control.
		do
			log_debug ("[FORM->CONTROL] Processing form for " + a_control.id.to_string_8)
			if attached a_form.item ("label") as al_label then
				log_debug ("[FORM->CONTROL] Setting label: " + al_label.to_string_8)
				a_control.set_label (al_label)
			end
			if attached a_form.item ("row") as al_row and then al_row.is_integer then
				log_debug ("[FORM->CONTROL] Setting row: " + al_row.to_string_8)
				a_control.set_grid_row (al_row.to_integer)
			end
			if attached a_form.item ("col") as al_col and then al_col.is_integer then
				log_debug ("[FORM->CONTROL] Setting col: " + al_col.to_string_8)
				a_control.set_grid_col (al_col.to_integer)
			end
			if attached a_form.item ("col_span") as al_span and then al_span.is_integer then
				log_debug ("[FORM->CONTROL] Setting col_span: " + al_span.to_string_8)
				a_control.set_col_span (al_span.to_integer)
			end
			if attached a_form.item ("notes") as al_notes then
				log_debug ("[FORM->CONTROL] Setting notes (length=" + al_notes.count.out + ")")
				a_control.set_notes_from_string (al_notes)
			end
		end

	handle_delete_control (a_request: SIMPLE_WEB_SERVER_REQUEST; a_response: SIMPLE_WEB_SERVER_RESPONSE)
			-- Delete control.
		do
			log_request ("DELETE", a_request.path.to_string_8)
			if attached a_request.path_parameter ("spec_id") as al_spec_id and then
			   attached a_request.path_parameter ("screen_id") as al_screen_id and then
			   attached a_request.path_parameter ("control_id") as al_control_id and then
			   attached specs.item (al_spec_id) as al_spec and then
			   attached al_spec.screen_by_id (al_screen_id) as al_screen then
				log_control_deleted (al_control_id.to_string_8, al_screen_id.to_string_8)
				al_screen.remove_control (al_control_id)
				a_response.set_no_content
				a_response.send_empty
			else
				log_not_found ("Screen", a_request.path_parameter ("screen_id"))
				a_response.set_not_found
				a_response.send_json ("{%"error%":%"Screen not found%"}")
			end
		end

feature -- Container Control Handlers

	handle_add_child_control (a_request: SIMPLE_WEB_SERVER_REQUEST; a_response: SIMPLE_WEB_SERVER_RESPONSE)
			-- Add child control to a container (card or tab panel).
		local
			l_control: GUI_DESIGNER_CONTROL
			l_panel_idx: INTEGER
			l_spec_id, l_screen_id, l_parent_id: detachable STRING_32
			l_spec: detachable GUI_DESIGNER_SPEC
			l_screen: detachable GUI_DESIGNER_SCREEN
			l_parent: detachable GUI_DESIGNER_CONTROL
			l_json: detachable SIMPLE_JSON_OBJECT
		do
			log_request ("POST", a_request.path.to_string_8)
			log_debug ("[CONTAINER] === handle_add_child_control START ===")

			-- Extract path parameters with logging
			l_spec_id := a_request.path_parameter ("spec_id")
			l_screen_id := a_request.path_parameter ("screen_id")
			l_parent_id := a_request.path_parameter ("parent_id")

			log_debug ("[CONTAINER] spec_id=" + if attached l_spec_id as s then s.to_string_8 else "(nil)" end)
			log_debug ("[CONTAINER] screen_id=" + if attached l_screen_id as s then s.to_string_8 else "(nil)" end)
			log_debug ("[CONTAINER] parent_id=" + if attached l_parent_id as s then s.to_string_8 else "(nil)" end)

			-- Lookup spec
			if attached l_spec_id then
				l_spec := specs.item (l_spec_id)
				if attached l_spec then
					log_debug ("[CONTAINER] Found spec: " + l_spec.app_name.to_string_8)
				else
					log_debug ("[CONTAINER] Spec NOT FOUND")
				end
			end

			-- Lookup screen
			if attached l_spec and attached l_screen_id then
				l_screen := l_spec.screen_by_id (l_screen_id)
				if attached l_screen then
					log_debug ("[CONTAINER] Found screen: " + l_screen.id.to_string_8 + " with " + l_screen.controls.count.out + " controls")
					-- List all controls for debugging
					across l_screen.controls as c loop
						log_debug ("[CONTAINER] Screen control: " + c.id.to_string_8 + " type=" + c.control_type.to_string_8 + " is_container=" + c.is_container.out)
					end
				else
					log_debug ("[CONTAINER] Screen NOT FOUND")
				end
			end

			-- Lookup parent container
			if attached l_screen and attached l_parent_id then
				l_parent := l_screen.control_by_id (l_parent_id)
				if attached l_parent then
					log_debug ("[CONTAINER] Found parent: " + l_parent.id.to_string_8 + " type=" + l_parent.control_type.to_string_8 + " is_container=" + l_parent.is_container.out)
				else
					log_debug ("[CONTAINER] Parent control NOT FOUND by control_by_id")
				end
			end

			-- Get JSON body
			l_json := a_request.body_as_json
			if attached l_json then
				log_debug ("[CONTAINER] Got JSON body")
			else
				log_debug ("[CONTAINER] No JSON body")
			end

			-- Now do the actual work
			if attached l_parent and then l_parent.is_container and then attached l_json and then attached l_parent_id then
				log_debug ("[CONTAINER] Parent is valid container, processing add child")
				if l_json.has_all_keys (<<"id", "type">>) then
					if attached l_json.string_item ("id") as l_id and then
					   attached l_json.string_item ("type") as l_type then
						log_debug ("[CONTAINER] Creating child: id=" + l_id.to_string_8 + " type=" + l_type.to_string_8)
						create l_control.make (l_id, l_type)
						if attached l_json.optional_string ("label") as l_label then
							l_control.set_label (l_label)
						end
						l_control.set_grid_position (
							l_json.optional_integer ("grid_row", 1).to_integer_32,
							l_json.optional_integer ("grid_col", 1).to_integer_32
						)
						l_control.set_col_span (l_json.optional_integer ("col_span", 3).to_integer_32)

						if l_parent.is_tabs then
							-- Add to specific tab panel
							l_panel_idx := l_json.optional_integer ("panel_index", 1).to_integer_32.max (1).min (l_parent.tab_panels.count)
							log_debug ("[CONTAINER] Adding to tab panel " + l_panel_idx.out + " of " + l_parent.tab_panels.count.out)
							l_parent.add_child_to_tab (l_control, l_panel_idx)
							log_info ("[CONTAINER] Added '" + l_id.to_string_8 + "' to tab " + l_panel_idx.out + " of '" + l_parent_id.to_string_8 + "'")
						else
							-- Add to card children
							log_debug ("[CONTAINER] Adding to card children (before: " + l_parent.children.count.out + ")")
							l_parent.add_child (l_control)
							log_debug ("[CONTAINER] Added to card children (after: " + l_parent.children.count.out + ")")
							log_info ("[CONTAINER] Added '" + l_id.to_string_8 + "' to card '" + l_parent_id.to_string_8 + "'")
						end

						a_response.set_status (201)
						a_response.send_json (l_control.to_json.representation)
					else
						log_bad_request ("Missing id or type in JSON")
						a_response.set_bad_request
						a_response.send_json ("{%"error%":%"Missing required fields%"}")
					end
				else
					log_bad_request ("JSON missing required keys")
					a_response.set_bad_request
					a_response.send_json ("{%"error%":%"JSON must have id and type%"}")
				end
			else
				log_debug ("[CONTAINER] FAILED: parent=" + (if attached l_parent then "found" else "nil" end) + " is_container=" + (if attached l_parent then l_parent.is_container.out else "n/a" end) + " json=" + (if attached l_json then "found" else "nil" end))
				log_not_found ("Container", l_parent_id)
				a_response.set_not_found
				a_response.send_json ("{%"error%":%"Container not found%"}")
			end
			log_debug ("[CONTAINER] === handle_add_child_control END ===")
		end

	handle_set_active_tab (a_request: SIMPLE_WEB_SERVER_REQUEST; a_response: SIMPLE_WEB_SERVER_RESPONSE)
			-- Set active tab index for tabs control.
		local
			l_tab_idx: INTEGER
		do
			log_request ("PUT", a_request.path.to_string_8)
			if attached a_request.path_parameter ("spec_id") as al_spec_id and then
			   attached a_request.path_parameter ("screen_id") as al_screen_id and then
			   attached a_request.path_parameter ("control_id") as al_control_id and then
			   attached specs.item (al_spec_id) as al_spec and then
			   attached al_spec.screen_by_id (al_screen_id) as al_screen and then
			   attached al_screen.control_by_id (al_control_id) as al_control and then
			   al_control.is_tabs and then
			   attached a_request.body_as_json as al_json then
				l_tab_idx := al_json.optional_integer ("active_tab", 1).to_integer_32.max (1).min (al_control.tab_panels.count)
				log_debug ("[TABS] Setting active tab to " + l_tab_idx.out + " for '" + al_control_id.to_string_8 + "'")
				al_control.set_active_tab (l_tab_idx)
				a_response.send_json ("{%"active_tab%":" + l_tab_idx.out + "}")
			else
				log_not_found ("Tabs control", a_request.path_parameter ("control_id"))
				a_response.set_not_found
				a_response.send_json ("{%"error%":%"Tabs control not found%"}")
			end
		end

	handle_add_tab (a_request: SIMPLE_WEB_SERVER_REQUEST; a_response: SIMPLE_WEB_SERVER_RESPONSE)
			-- Add new tab panel to tabs control.
		local
			l_tab_name: STRING_32
		do
			log_request ("POST", a_request.path.to_string_8)
			if attached a_request.path_parameter ("spec_id") as al_spec_id and then
			   attached a_request.path_parameter ("screen_id") as al_screen_id and then
			   attached a_request.path_parameter ("control_id") as al_control_id and then
			   attached specs.item (al_spec_id) as al_spec and then
			   attached al_spec.screen_by_id (al_screen_id) as al_screen and then
			   attached al_screen.control_by_id (al_control_id) as al_control and then
			   al_control.is_tabs and then
			   attached a_request.body_as_json as al_json then
				if attached al_json.string_item ("name") as l_name then
					l_tab_name := l_name
				else
					l_tab_name := "Tab " + (al_control.tab_panels.count + 1).out
				end
				log_debug ("[TABS] Adding new tab '" + l_tab_name.to_string_8 + "' to '" + al_control_id.to_string_8 + "'")
				al_control.add_tab_panel (l_tab_name)
				log_info ("[TABS] Added tab '" + l_tab_name.to_string_8 + "' (now " + al_control.tab_panels.count.out + " tabs)")
				a_response.set_status (201)
				a_response.send_json ("{%"tab_count%":" + al_control.tab_panels.count.out + ",%"name%":%"" + l_tab_name.to_string_8 + "%"}")
			else
				log_not_found ("Tabs control", a_request.path_parameter ("control_id"))
				a_response.set_not_found
				a_response.send_json ("{%"error%":%"Tabs control not found%"}")
			end
		end

feature -- HTMX Partial Handlers

	handle_canvas_partial (a_request: SIMPLE_WEB_SERVER_REQUEST; a_response: SIMPLE_WEB_SERVER_RESPONSE)
			-- Render canvas HTML partial.
		do
			log_request ("GET", a_request.path.to_string_8)
			if attached a_request.path_parameter ("spec_id") as al_spec_id and then
			   attached a_request.path_parameter ("screen_id") as al_screen_id and then
			   attached specs.item (al_spec_id) as al_spec and then
			   attached al_spec.screen_by_id (al_screen_id) as al_screen then
				log_canvas_render (al_screen_id.to_string_8, al_screen.controls.count)
				-- Log each control's position for debugging
				across al_screen.controls as al_ctrl loop
					log_debug ("[CANVAS] Rendering control " + al_ctrl.id.to_string_8 + " at row=" + al_ctrl.grid_row.out + " col=" + al_ctrl.grid_col.out + " span=" + al_ctrl.col_span.out)
				end
				a_response.send_html (render_canvas (al_screen, al_spec_id))
			else
				log_not_found ("Screen", a_request.path_parameter ("screen_id"))
				a_response.set_not_found
				a_response.send_html ("<div class=%"error%">Screen not found</div>")
			end
		end

	handle_palette_partial (a_request: SIMPLE_WEB_SERVER_REQUEST; a_response: SIMPLE_WEB_SERVER_RESPONSE)
			-- Render control palette HTML partial.
		do
			log_request ("GET", "/htmx/palette")
			log_debug ("[HTMX] Rendering palette partial")
			a_response.send_html (render_palette)
		end

	handle_properties_partial (a_request: SIMPLE_WEB_SERVER_REQUEST; a_response: SIMPLE_WEB_SERVER_RESPONSE)
			-- Render properties panel HTML partial.
		do
			log_request ("GET", a_request.path.to_string_8)
			if attached a_request.path_parameter ("spec_id") as al_spec_id and then
			   attached a_request.path_parameter ("screen_id") as al_screen_id and then
			   attached a_request.path_parameter ("control_id") as al_control_id and then
			   attached specs.item (al_spec_id) as al_spec and then
			   attached al_spec.screen_by_id (al_screen_id) as al_screen and then
			   attached al_screen.control_by_id (al_control_id) as al_control then
				log_control_selected (al_control_id.to_string_8)
				log_debug ("[PROPERTIES] Control " + al_control_id.to_string_8 + " row=" + al_control.grid_row.out + " col=" + al_control.grid_col.out + " span=" + al_control.col_span.out)
				a_response.send_html (render_properties (al_control, al_spec_id, al_screen_id))
			else
				log_not_found ("Control", a_request.path_parameter ("control_id"))
				a_response.set_not_found
				a_response.send_html ("<div class=%"error%">Control not found</div>")
			end
		end

	handle_screen_list_partial (a_request: SIMPLE_WEB_SERVER_REQUEST; a_response: SIMPLE_WEB_SERVER_RESPONSE)
			-- Render screen list HTML partial.
		do
			log_request ("GET", a_request.path.to_string_8)
			if attached a_request.path_parameter ("spec_id") as al_spec_id and then attached specs.item (al_spec_id) as al_spec then
				log_debug ("[HTMX] Rendering screen list for " + al_spec_id.to_string_8 + " with " + al_spec.screens.count.out + " screens")
				a_response.send_html (render_screen_list (al_spec))
			else
				log_not_found ("Spec", a_request.path_parameter ("spec_id"))
				a_response.set_not_found
				a_response.send_html ("<div class=%"error%">Spec not found</div>")
			end
		end

	handle_spec_list_partial (a_request: SIMPLE_WEB_SERVER_REQUEST; a_response: SIMPLE_WEB_SERVER_RESPONSE)
			-- Render spec list HTML partial for index page.
		do
			log_request ("GET", "/htmx/spec-list")
			log_debug ("[HTMX] Rendering spec list with " + specs.count.out + " specs")
			a_response.send_html (render_spec_list)
		end

feature -- Export Handlers

	handle_finalize_spec (a_request: SIMPLE_WEB_SERVER_REQUEST; a_response: SIMPLE_WEB_SERVER_RESPONSE)
			-- Mark spec as finalized.
		do
			log_request ("POST", a_request.path.to_string_8)
			if attached a_request.path_parameter ("id") as al_id and then attached specs.item (al_id) as al_spec then
				log_spec_finalized (al_id.to_string_8)
				al_spec.mark_finalized
				a_response.send_json ("{%"status%":%"finalized%"}")
			else
				log_not_found ("Spec", a_request.path_parameter ("id"))
				a_response.set_not_found
				a_response.send_json ("{%"error%":%"Spec not found%"}")
			end
		end

	handle_export_spec (a_request: SIMPLE_WEB_SERVER_REQUEST; a_response: SIMPLE_WEB_SERVER_RESPONSE)
			-- Export final spec.
		local
			l_final: GUI_FINAL_SPEC
		do
			log_request ("GET", a_request.path.to_string_8)
			if attached a_request.path_parameter ("id") as al_id and then attached specs.item (al_id) as al_spec then
				if al_spec.is_finalized then
					log_info ("[EXPORT] Exporting finalized spec: " + al_id.to_string_8)
					l_final := al_spec.to_final_spec
					a_response.set_header ("Content-Disposition", "attachment; filename=%"" + al_id.to_string_8 + "_final.json%"")
					a_response.set_header ("Content-Type", "application/json")
					a_response.send_json (l_final.to_json.as_json)
				else
					log_bad_request ("Export attempted on non-finalized spec: " + al_id.to_string_8)
					a_response.set_bad_request
					a_response.send_json ("{%"error%":%"Spec must be finalized first%"}")
				end
			else
				log_not_found ("Spec", a_request.path_parameter ("id"))
				a_response.set_not_found
				a_response.send_json ("{%"error%":%"Spec not found%"}")
			end
		end

	handle_save_spec_to_disk (a_request: SIMPLE_WEB_SERVER_REQUEST; a_response: SIMPLE_WEB_SERVER_RESPONSE)
			-- Save spec back to specs directory (overwrites existing file).
		local
			l_file: PLAIN_TEXT_FILE
			l_path: STRING
			l_json: STRING
		do
			log_request ("POST", a_request.path.to_string_8)
			if attached a_request.path_parameter ("id") as al_id and then attached specs.item (al_id) as al_spec then
				l_path := specs_directory + "/" + al_id.to_string_8 + ".json"
				l_json := al_spec.to_json.as_json
				log_debug ("[SAVE] Writing " + l_json.count.out + " bytes to " + l_path)
				create l_file.make_open_write (l_path)
				l_file.put_string (l_json)
				l_file.close
				log_spec_saved (al_id.to_string_8, l_path)
				a_response.send_json ("{%"status%":%"saved%",%"path%":%"" + l_path + "%"}")
			else
				log_not_found ("Spec", a_request.path_parameter ("id"))
				a_response.set_not_found
				a_response.send_json ("{%"error%":%"Spec not found%"}")
			end
		end

feature -- Download/Upload Handlers

	handle_download_spec (a_request: SIMPLE_WEB_SERVER_REQUEST; a_response: SIMPLE_WEB_SERVER_RESPONSE)
			-- Download single spec as JSON file.
		do
			log_request ("GET", a_request.path.to_string_8)
			if attached a_request.path_parameter ("id") as al_id and then attached specs.item (al_id) as al_spec then
				log_info ("[DOWNLOAD] Serving spec download: " + al_id.to_string_8)
				a_response.set_header ("Content-Disposition", "attachment; filename=%"" + al_id.to_string_8 + ".json%"")
				a_response.set_header ("Content-Type", "application/json")
				a_response.send_json (al_spec.to_json.as_json)
			else
				log_not_found ("Spec", a_request.path_parameter ("id"))
				a_response.set_not_found
				a_response.send_json ("{%"error%":%"Spec not found%"}")
			end
		end

	handle_download_all_specs (a_request: SIMPLE_WEB_SERVER_REQUEST; a_response: SIMPLE_WEB_SERVER_RESPONSE)
			-- Download all specs as JSON array file.
		local
			l_arr: SIMPLE_JSON_ARRAY
		do
			log_request ("GET", "/api/specs/download-all")
			log_info ("[DOWNLOAD] Serving all " + specs.count.out + " specs download")
			create l_arr.make
			across specs as al_spec loop
				l_arr.add_object (al_spec.to_json).do_nothing
			end
			a_response.set_header ("Content-Disposition", "attachment; filename=%"all_specs.json%"")
			a_response.set_header ("Content-Type", "application/json")
			a_response.send_json (l_arr.as_json)
		end

	handle_upload_spec (a_request: SIMPLE_WEB_SERVER_REQUEST; a_response: SIMPLE_WEB_SERVER_RESPONSE)
			-- Upload and add a new spec from JSON.
		local
			l_spec: GUI_DESIGNER_SPEC
			l_name: STRING_32
			l_validation_error: detachable STRING
		do
			log_request ("POST", "/api/specs/upload")
			if attached a_request.body_as_json as al_json then
				log_debug ("[UPLOAD] Received JSON body for spec upload")
				l_validation_error := validate_spec_json (al_json)
				if l_validation_error = Void then
					create l_spec.make_from_json (al_json)
					l_name := l_spec.app_name
					if specs.has (l_name) then
						-- Update existing
						log_info ("[UPLOAD] Updating existing spec: " + l_name.to_string_8)
						specs.force (l_spec, l_name)
						a_response.send_json ("{%"status%":%"updated%",%"name%":%"" + l_name.to_string_8 + "%"}")
					else
						-- Add new
						log_spec_created (l_name.to_string_8)
						specs.force (l_spec, l_name)
						a_response.set_created
						a_response.send_json ("{%"status%":%"created%",%"name%":%"" + l_name.to_string_8 + "%"}")
					end
				else
					log_bad_request ("Upload validation failed: " + l_validation_error)
					a_response.set_bad_request
					a_response.send_json ("{%"error%":%"" + l_validation_error + "%"}")
				end
			else
				log_bad_request ("Upload received invalid JSON body")
				a_response.set_bad_request
				a_response.send_json ("{%"error%":%"Invalid JSON body%"}")
			end
		end

feature {NONE} -- Validation

	validate_spec_json (a_json: SIMPLE_JSON_OBJECT): detachable STRING
			-- Validate spec JSON structure. Returns error message or Void if valid.
		local
			l_screens_arr: SIMPLE_JSON_ARRAY
			l_screen_obj: SIMPLE_JSON_OBJECT
			l_controls_arr: SIMPLE_JSON_ARRAY
			l_control_obj: SIMPLE_JSON_OBJECT
			i, j: INTEGER
		do
			-- Must have app or app_name
			if not (a_json.has_key ("app") or a_json.has_key ("app_name")) then
				Result := "Missing required field: app or app_name"
			elseif attached a_json.array_item ("screens") as l_screens then
				-- Validate each screen
				l_screens_arr := l_screens
				from i := 1 until i > l_screens_arr.count or Result /= Void loop
					if attached l_screens_arr.item (i).as_object as l_obj then
						l_screen_obj := l_obj
						if not l_screen_obj.has_key ("id") then
							Result := "Screen " + i.out + " missing required field: id"
						elseif attached l_screen_obj.array_item ("controls") as l_controls then
							-- Validate each control in this screen
							l_controls_arr := l_controls
							from j := 1 until j > l_controls_arr.count or Result /= Void loop
								if attached l_controls_arr.item (j).as_object as l_ctrl then
									l_control_obj := l_ctrl
									if not l_control_obj.has_key ("id") then
										Result := "Control " + j.out + " in screen " + i.out + " missing required field: id"
									elseif not l_control_obj.has_key ("type") then
										Result := "Control " + j.out + " in screen " + i.out + " missing required field: type"
									end
								end
								j := j + 1
							end
						end
					else
						Result := "Screen " + i.out + " is not a valid object"
					end
					i := i + 1
				end
			end
			-- No screens array is OK (empty spec)
		end

feature {NONE} -- HTML Rendering

	render_canvas (a_screen: GUI_DESIGNER_SCREEN; a_spec_id: STRING_32): STRING
			-- Render screen as HTML canvas with 12-column grid.
		local
			l_row, l_max_row: INTEGER
		do
			create Result.make (2000)
			Result.append ("<div class=%"canvas-grid%">%N")
			Result.append ("  <h3>")
			Result.append (a_screen.title.to_string_8)
			Result.append ("</h3>%N")

			l_max_row := a_screen.row_count.max (6)
			from l_row := 1 until l_row > l_max_row loop
				Result.append ("  <div class=%"grid-row%">%N")
				across a_screen.controls_at_row (l_row) as al_control loop
					Result.append (render_control (al_control, a_spec_id, a_screen.id))
				end
				Result.append ("  </div>%N")
				l_row := l_row + 1
			end
			Result.append ("</div>")
		end

	render_control (a_control: GUI_DESIGNER_CONTROL; a_spec_id, a_screen_id: STRING_32): STRING
			-- Render single control HTML with click handler for properties.
			-- Handles containers (card, tabs) specially with drop zones.
		do
			if a_control.is_card then
				Result := render_card_control (a_control, a_spec_id, a_screen_id)
			elseif a_control.is_tabs then
				Result := render_tabs_control (a_control, a_spec_id, a_screen_id)
			else
				Result := render_simple_control (a_control, a_spec_id, a_screen_id)
			end
		end

	render_simple_control (a_control: GUI_DESIGNER_CONTROL; a_spec_id, a_screen_id: STRING_32): STRING
			-- Render non-container control.
		do
			create Result.make (500)
			Result.append ("    <div class=%"control col-")
			Result.append (a_control.col_span.out)
			Result.append (" type-")
			Result.append (a_control.control_type.to_string_8)
			Result.append ("%" data-id=%"")
			Result.append (a_control.id.to_string_8)
			Result.append ("%" draggable=%"true%" ")
			Result.append ("hx-get=%"/htmx/properties/")
			Result.append (a_spec_id.to_string_8)
			Result.append ("/")
			Result.append (a_screen_id.to_string_8)
			Result.append ("/")
			Result.append (a_control.id.to_string_8)
			Result.append ("%" hx-target=%"#properties%" hx-swap=%"innerHTML%" ")
			Result.append ("onclick=%"event.stopPropagation(); document.querySelectorAll('.control.selected').forEach(c=>c.classList.remove('selected')); this.classList.add('selected');%">%N")
			Result.append ("      <span class=%"control-label%">")
			if a_control.label.is_empty then
				Result.append ("[" + a_control.id.to_string_8 + "]")
			else
				Result.append (a_control.label.to_string_8)
			end
			Result.append ("</span>%N")
			Result.append ("    </div>%N")
		end

	render_card_control (a_control: GUI_DESIGNER_CONTROL; a_spec_id, a_screen_id: STRING_32): STRING
			-- Render card container with drop zone for children.
		do
			log_debug ("[RENDER] Card '" + a_control.id.to_string_8 + "' with " + a_control.children.count.out + " children")
			create Result.make (1000)
			Result.append ("    <div class=%"control container-control card-control col-")
			Result.append (a_control.col_span.out)
			Result.append ("%" data-id=%"")
			Result.append (a_control.id.to_string_8)
			Result.append ("%" data-container=%"card%" ")
			Result.append ("hx-get=%"/htmx/properties/")
			Result.append (a_spec_id.to_string_8)
			Result.append ("/")
			Result.append (a_screen_id.to_string_8)
			Result.append ("/")
			Result.append (a_control.id.to_string_8)
			Result.append ("%" hx-target=%"#properties%" hx-swap=%"innerHTML%" ")
			Result.append ("onclick=%"event.stopPropagation(); document.querySelectorAll('.control.selected').forEach(c=>c.classList.remove('selected')); this.classList.add('selected');%">%N")
			-- Card header
			Result.append ("      <div class=%"card-header%">")
			if a_control.label.is_empty then
				Result.append ("Card")
			else
				Result.append (a_control.label.to_string_8)
			end
			Result.append ("</div>%N")
			-- Card body (drop zone)
			Result.append ("      <div class=%"card-body drop-zone%" data-parent=%"")
			Result.append (a_control.id.to_string_8)
			Result.append ("%">%N")
			if a_control.children.is_empty then
				Result.append ("        <div class=%"drop-placeholder%">Drop controls here</div>%N")
			else
				across a_control.children as al_child loop
					Result.append (render_control (al_child, a_spec_id, a_screen_id))
				end
			end
			Result.append ("      </div>%N")
			Result.append ("    </div>%N")
		end

	render_tabs_control (a_control: GUI_DESIGNER_CONTROL; a_spec_id, a_screen_id: STRING_32): STRING
			-- Render tabs container with tab headers and panels.
		local
			l_tab_idx: INTEGER
			l_active_idx: INTEGER
		do
			log_debug ("[RENDER] Tabs '" + a_control.id.to_string_8 + "' with " + a_control.tab_panels.count.out + " panels")
			l_active_idx := a_control.active_tab_index.max (1)
			create Result.make (2000)
			Result.append ("    <div class=%"control container-control tabs-control col-")
			Result.append (a_control.col_span.out)
			Result.append ("%" data-id=%"")
			Result.append (a_control.id.to_string_8)
			Result.append ("%" data-container=%"tabs%" ")
			Result.append ("hx-get=%"/htmx/properties/")
			Result.append (a_spec_id.to_string_8)
			Result.append ("/")
			Result.append (a_screen_id.to_string_8)
			Result.append ("/")
			Result.append (a_control.id.to_string_8)
			Result.append ("%" hx-target=%"#properties%" hx-swap=%"innerHTML%" ")
			Result.append ("onclick=%"event.stopPropagation(); document.querySelectorAll('.control.selected').forEach(c=>c.classList.remove('selected')); this.classList.add('selected');%">%N")
			-- Tab headers
			Result.append ("      <div class=%"tabs-header%">%N")
			l_tab_idx := 1
			across a_control.tab_panels as al_panel loop
				Result.append ("        <div class=%"tab-header")
				if l_tab_idx = l_active_idx then
					Result.append (" active")
				end
				Result.append ("%" data-tab-idx=%"")
				Result.append (l_tab_idx.out)
				Result.append ("%" data-tabs-id=%"")
				Result.append (a_control.id.to_string_8)
				Result.append ("%" onclick=%"switchTab(this, event)%">")
				Result.append (al_panel.name.to_string_8)
				Result.append ("</div>%N")
				l_tab_idx := l_tab_idx + 1
			end
			Result.append ("        <div class=%"tab-add-btn%" onclick=%"addTab('" + a_control.id.to_string_8 + "', event)%">+</div>%N")
			Result.append ("      </div>%N")
			-- Tab panels (only active one visible)
			l_tab_idx := 1
			across a_control.tab_panels as al_panel loop
				Result.append ("      <div class=%"tab-panel drop-zone")
				if l_tab_idx = l_active_idx then
					Result.append (" active")
				end
				Result.append ("%" data-tab-idx=%"")
				Result.append (l_tab_idx.out)
				Result.append ("%" data-parent=%"")
				Result.append (a_control.id.to_string_8)
				Result.append ("%" data-panel-idx=%"")
				Result.append (l_tab_idx.out)
				Result.append ("%">%N")
				if al_panel.children.is_empty then
					Result.append ("        <div class=%"drop-placeholder%">Drop controls here</div>%N")
				else
					across al_panel.children as al_child loop
						Result.append (render_control (al_child, a_spec_id, a_screen_id))
					end
				end
				Result.append ("      </div>%N")
				l_tab_idx := l_tab_idx + 1
			end
			Result.append ("    </div>%N")
		end

	render_palette: STRING
			-- Render control palette HTML.
		do
			create Result.make (3000)
			Result.append ("<div class=%"palette%">%N")
			Result.append ("  <h4>Controls</h4>%N")

			-- Input controls
			Result.append ("  <div class=%"palette-group%">%N")
			Result.append ("    <h5>Input</h5>%N")
			Result.append ("    <div class=%"palette-item%" draggable=%"true%" data-type=%"text_field%">Text Field</div>%N")
			Result.append ("    <div class=%"palette-item%" draggable=%"true%" data-type=%"text_area%">Text Area</div>%N")
			Result.append ("    <div class=%"palette-item%" draggable=%"true%" data-type=%"dropdown%">Dropdown</div>%N")
			Result.append ("    <div class=%"palette-item%" draggable=%"true%" data-type=%"checkbox%">Checkbox</div>%N")
			Result.append ("    <div class=%"palette-item%" draggable=%"true%" data-type=%"date_picker%">Date Picker</div>%N")
			Result.append ("  </div>%N")

			-- Action controls
			Result.append ("  <div class=%"palette-group%">%N")
			Result.append ("    <h5>Actions</h5>%N")
			Result.append ("    <div class=%"palette-item%" draggable=%"true%" data-type=%"button%">Button</div>%N")
			Result.append ("    <div class=%"palette-item%" draggable=%"true%" data-type=%"link%">Link</div>%N")
			Result.append ("  </div>%N")

			-- Display controls
			Result.append ("  <div class=%"palette-group%">%N")
			Result.append ("    <h5>Display</h5>%N")
			Result.append ("    <div class=%"palette-item%" draggable=%"true%" data-type=%"label%">Label</div>%N")
			Result.append ("    <div class=%"palette-item%" draggable=%"true%" data-type=%"heading%">Heading</div>%N")
			Result.append ("    <div class=%"palette-item%" draggable=%"true%" data-type=%"table%">Table</div>%N")
			Result.append ("    <div class=%"palette-item%" draggable=%"true%" data-type=%"list%">List</div>%N")
			Result.append ("  </div>%N")

			-- Layout controls
			Result.append ("  <div class=%"palette-group%">%N")
			Result.append ("    <h5>Layout</h5>%N")
			Result.append ("    <div class=%"palette-item%" draggable=%"true%" data-type=%"card%">Card</div>%N")
			Result.append ("    <div class=%"palette-item%" draggable=%"true%" data-type=%"tabs%">Tabs</div>%N")
			Result.append ("  </div>%N")

			Result.append ("</div>")
		end

	render_properties (a_control: GUI_DESIGNER_CONTROL; a_spec_id, a_screen_id: STRING_32): STRING
			-- Render properties panel HTML for control.
		do
			create Result.make (2000)
			Result.append ("<div class=%"properties-panel%">%N")
			Result.append ("  <h4>")
			Result.append (a_control.label.to_string_8)
			Result.append ("</h4>%N")
			Result.append ("  <p style=%"color:#666; font-size:12px; margin-top:-10px;%">")
			Result.append (a_control.control_type.to_string_8)
			Result.append ("</p>%N")
			Result.append ("  <form hx-put=%"/api/specs/")
			Result.append (a_spec_id.to_string_8)
			Result.append ("/screens/")
			Result.append (a_screen_id.to_string_8)
			Result.append ("/controls/")
			Result.append (a_control.id.to_string_8)
			Result.append ("%" hx-trigger=%"submit%" hx-swap=%"none%" ")
			Result.append ("hx-on::after-request=%"refreshCanvas()%"")
			Result.append (" data-canvas-url=%"/htmx/canvas/")
			Result.append (a_spec_id.to_string_8)
			Result.append ("/")
			Result.append (a_screen_id.to_string_8)
			Result.append ("%"")
			Result.append (" data-props-url=%"/htmx/properties/")
			Result.append (a_spec_id.to_string_8)
			Result.append ("/")
			Result.append (a_screen_id.to_string_8)
			Result.append ("/")
			Result.append (a_control.id.to_string_8)
			Result.append ("%"")
			Result.append (" data-control-id=%"")
			Result.append (a_control.id.to_string_8)
			Result.append ("%">%N")

			-- ID (read-only, not editable)
			Result.append ("    <label>ID</label>%N")
			Result.append ("    <input type=%"text%" value=%"")
			Result.append (a_control.id.to_string_8)
			Result.append ("%" disabled class=%"readonly-field%">%N")

			-- Type (read-only, not editable)
			Result.append ("    <label>Type</label>%N")
			Result.append ("    <input type=%"text%" value=%"")
			Result.append (a_control.control_type.to_string_8)
			Result.append ("%" disabled class=%"readonly-field%">%N")

			-- Label (auto-submit on change)
			Result.append ("    <label>Label</label>%N")
			Result.append ("    <input type=%"text%" name=%"label%" value=%"")
			Result.append (a_control.label.to_string_8)
			Result.append ("%" onchange=%"htmx.trigger(this.form, 'submit')%">%N")

			-- Grid position with spinner buttons
			Result.append ("    <label>Row</label>%N")
			Result.append ("    <div class=%"spinner-group%">%N")
			Result.append ("      <button type=%"button%" class=%"spin-btn%" onclick=%"var inp=this.nextElementSibling; inp.stepDown(); htmx.trigger(inp.form, 'submit')%">-</button>%N")
			Result.append ("      <input type=%"number%" name=%"row%" value=%"")
			Result.append (a_control.grid_row.out)
			Result.append ("%" min=%"1%" class=%"spin-input%">%N")
			Result.append ("      <button type=%"button%" class=%"spin-btn%" onclick=%"var inp=this.previousElementSibling; inp.stepUp(); htmx.trigger(inp.form, 'submit')%">+</button>%N")
			Result.append ("    </div>%N")

			Result.append ("    <label>Column</label>%N")
			Result.append ("    <div class=%"spinner-group%">%N")
			Result.append ("      <button type=%"button%" class=%"spin-btn%" onclick=%"var inp=this.nextElementSibling; inp.stepDown(); htmx.trigger(inp.form, 'submit')%">-</button>%N")
			Result.append ("      <input type=%"number%" name=%"col%" value=%"")
			Result.append (a_control.grid_col.out)
			Result.append ("%" min=%"1%" max=%"24%" class=%"spin-input%">%N")
			Result.append ("      <button type=%"button%" class=%"spin-btn%" onclick=%"var inp=this.previousElementSibling; inp.stepUp(); htmx.trigger(inp.form, 'submit')%">+</button>%N")
			Result.append ("    </div>%N")

			Result.append ("    <label>Column Span</label>%N")
			Result.append ("    <div class=%"spinner-group%">%N")
			Result.append ("      <button type=%"button%" class=%"spin-btn%" onclick=%"var inp=this.nextElementSibling; inp.stepDown(); htmx.trigger(inp.form, 'submit')%">-</button>%N")
			Result.append ("      <input type=%"number%" name=%"col_span%" value=%"")
			Result.append (a_control.col_span.out)
			Result.append ("%" min=%"1%" max=%"24%" class=%"spin-input%">%N")
			Result.append ("      <button type=%"button%" class=%"spin-btn%" onclick=%"var inp=this.previousElementSibling; inp.stepUp(); htmx.trigger(inp.form, 'submit')%">+</button>%N")
			Result.append ("    </div>%N")

			-- Notes section (auto-submit on change)
			Result.append ("    <label>Notes</label>%N")
			Result.append ("    <textarea name=%"notes%" onchange=%"htmx.trigger(this.form, 'submit')%">")
			across a_control.notes as al_note loop
				Result.append (al_note.to_string_8)
				Result.append ("%N")
			end
			Result.append ("</textarea>%N")

			Result.append ("  </form>%N")

			-- Delete button (outside the form)
			Result.append ("  <hr style=%"margin: 20px 0; border: none; border-top: 1px solid #ddd;%">%N")
			Result.append ("  <button type=%"button%" class=%"delete-btn%" ")
			Result.append ("onclick=%"deleteControl('")
			Result.append (a_spec_id.to_string_8)
			Result.append ("', '")
			Result.append (a_screen_id.to_string_8)
			Result.append ("', '")
			Result.append (a_control.id.to_string_8)
			Result.append ("')%">Delete Control</button>%N")

			Result.append ("</div>")
		end

	render_screen_list (a_spec: GUI_DESIGNER_SPEC): STRING
			-- Render screen list HTML.
		do
			create Result.make (1000)
			Result.append ("<ul class=%"screen-list%">%N")
			across a_spec.screens as al_screen loop
				Result.append ("  <li hx-get=%"/htmx/canvas/")
				Result.append (a_spec.app_name.to_string_8)
				Result.append ("/")
				Result.append (al_screen.id.to_string_8)
				Result.append ("%" hx-target=%"#canvas%">")
				Result.append (al_screen.title.to_string_8)
				Result.append ("</li>%N")
			end
			Result.append ("</ul>")
		end

	render_spec_list: STRING
			-- Render spec list HTML for index page.
		do
			create Result.make (2000)
			if specs.is_empty then
				Result.append ("<p style=%"color:#888; font-style:italic;%">No specifications loaded. Upload a JSON spec file to get started.</p>")
			else
				Result.append ("<ul class=%"spec-list%">%N")
				across specs as al_spec loop
					Result.append ("  <div class=%"spec-item%">%N")
					Result.append ("    <div class=%"spec-info%">%N")
					Result.append ("      <div class=%"spec-name%">")
					Result.append (al_spec.app_name.to_string_8)
					Result.append ("</div>%N")
					Result.append ("      <div class=%"spec-meta%">Version ")
					Result.append (al_spec.version.out)
					Result.append (" | ")
					Result.append (al_spec.screens.count.out)
					Result.append (" screen(s)</div>%N")
					Result.append ("    </div>%N")
					Result.append ("    <div class=%"spec-actions%">%N")
					Result.append ("      <a href=%"/api/specs/")
					Result.append (al_spec.app_name.to_string_8)
					Result.append ("/download%" class=%"btn btn-secondary btn-sm%">Download</a>%N")
					Result.append ("      <a href=%"/designer?spec=")
					Result.append (al_spec.app_name.to_string_8)
					Result.append ("%" class=%"btn btn-success btn-sm%">Edit</a>%N")
					Result.append ("    </div>%N")
					Result.append ("  </div>%N")
				end
				Result.append ("</ul>")
			end
		end

feature {NONE} -- Static HTML

	index_html: STRING
			-- Index page HTML with spec management.
		once
			Result := "[
<!DOCTYPE html>
<html>
<head>
	<title>GUI Designer</title>
	<script src="https://unpkg.com/htmx.org@1.9.10"></script>
	<style>
		* { box-sizing: border-box; }
		body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
		.container { max-width: 900px; margin: 0 auto; }
		h1 { color: #333; margin-bottom: 5px; }
		.subtitle { color: #666; margin-bottom: 30px; }

		/* Card styles */
		.card { background: white; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); padding: 20px; margin-bottom: 20px; }
		.card h2 { margin-top: 0; color: #333; border-bottom: 1px solid #eee; padding-bottom: 10px; }

		/* Button styles */
		.btn { display: inline-block; padding: 10px 20px; border-radius: 4px; text-decoration: none; font-weight: 500; cursor: pointer; border: none; font-size: 14px; }
		.btn-primary { background: #2196F3; color: white; }
		.btn-primary:hover { background: #1976D2; }
		.btn-success { background: #4CAF50; color: white; }
		.btn-success:hover { background: #388E3C; }
		.btn-secondary { background: #757575; color: white; }
		.btn-secondary:hover { background: #616161; }
		.btn-sm { padding: 6px 12px; font-size: 12px; }

		/* Spec list */
		.spec-list { list-style: none; padding: 0; margin: 0; }
		.spec-item { display: flex; align-items: center; justify-content: space-between; padding: 12px 15px; border: 1px solid #eee; border-radius: 4px; margin-bottom: 8px; background: #fafafa; }
		.spec-item:hover { background: #f0f7ff; border-color: #2196F3; }
		.spec-info { flex: 1; }
		.spec-name { font-weight: 600; color: #333; }
		.spec-meta { font-size: 12px; color: #888; margin-top: 4px; }
		.spec-actions { display: flex; gap: 8px; }

		/* Upload area */
		.upload-area { border: 2px dashed #ccc; border-radius: 8px; padding: 30px; text-align: center; margin-top: 15px; transition: all 0.3s; }
		.upload-area:hover { border-color: #2196F3; background: #f0f7ff; }
		.upload-area.dragover { border-color: #4CAF50; background: #e8f5e9; }
		.upload-area input[type="file"] { display: none; }
		.upload-area label { cursor: pointer; color: #666; }
		.upload-area label strong { color: #2196F3; }

		/* Status messages */
		.status { padding: 10px 15px; border-radius: 4px; margin-top: 10px; display: none; }
		.status.success { display: block; background: #e8f5e9; color: #2e7d32; }
		.status.error { display: block; background: #ffebee; color: #c62828; }

		/* Action bar */
		.action-bar { display: flex; justify-content: space-between; align-items: center; margin-bottom: 15px; }
		.action-bar-right { display: flex; gap: 10px; }
	</style>
</head>
<body>
	<div class="container">
		<h1>GUI Designer</h1>
		<p class="subtitle">Visual specification builder for Eiffel applications</p>

		<div class="card">
			<h2>Specifications</h2>
			<div class="action-bar">
				<a href="/designer" class="btn btn-primary">Open Designer</a>
				<div class="action-bar-right">
					<a href="/api/specs/download-all" class="btn btn-secondary btn-sm">Download All</a>
				</div>
			</div>

			<div id="spec-list" hx-get="/htmx/spec-list" hx-trigger="load">
				Loading specifications...
			</div>
		</div>

		<div class="card">
			<h2>Upload Specification</h2>
			<p>Upload a JSON spec file to add or update a specification.</p>

			<div class="upload-area" id="upload-area">
				<input type="file" id="spec-file" accept=".json" onchange="uploadFile(this)">
				<label for="spec-file">
					<strong>Click to browse</strong> or drag and drop a JSON file here
				</label>
			</div>

			<div id="upload-status" class="status"></div>
		</div>
	</div>

	<script>
		// Drag and drop handling
		const uploadArea = document.getElementById('upload-area');

		['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
			uploadArea.addEventListener(eventName, e => {
				e.preventDefault();
				e.stopPropagation();
			});
		});

		['dragenter', 'dragover'].forEach(eventName => {
			uploadArea.addEventListener(eventName, () => uploadArea.classList.add('dragover'));
		});

		['dragleave', 'drop'].forEach(eventName => {
			uploadArea.addEventListener(eventName, () => uploadArea.classList.remove('dragover'));
		});

		uploadArea.addEventListener('drop', e => {
			const files = e.dataTransfer.files;
			if (files.length > 0) {
				handleFile(files[0]);
			}
		});

		function uploadFile(input) {
			if (input.files.length > 0) {
				handleFile(input.files[0]);
			}
		}

		function handleFile(file) {
			const status = document.getElementById('upload-status');

			if (!file.name.endsWith('.json')) {
				status.className = 'status error';
				status.textContent = 'Error: Please upload a JSON file';
				return;
			}

			const reader = new FileReader();
			reader.onload = function(e) {
				try {
					const json = JSON.parse(e.target.result);

					fetch('/api/specs/upload', {
						method: 'POST',
						headers: { 'Content-Type': 'application/json' },
						body: JSON.stringify(json)
					})
					.then(r => r.json())
					.then(data => {
						if (data.error) {
							status.className = 'status error';
							status.textContent = 'Error: ' + data.error;
						} else {
							status.className = 'status success';
							status.textContent = 'Spec "' + data.name + '" ' + data.status + ' successfully!';
							htmx.trigger('#spec-list', 'load');
						}
					})
					.catch(err => {
						status.className = 'status error';
						status.textContent = 'Error: ' + err.message;
					});
				} catch (err) {
					status.className = 'status error';
					status.textContent = 'Error: Invalid JSON file';
				}
			};
			reader.readAsText(file);
		}
	</script>
</body>
</html>
			]"
		end

	designer_html_for_spec (a_spec_name: STRING_32): STRING
			-- Designer page HTML for specific spec.
		local
			l_name: STRING
		do
			l_name := a_spec_name.to_string_8
			create Result.make (5000)
			Result.append ("<!DOCTYPE html>%N<html>%N<head>%N")
			Result.append ("<title>GUI Designer - " + l_name + "</title>%N")
			Result.append ("<script src=%"https://unpkg.com/htmx.org@1.9.10%"></script>%N")
			Result.append ("<style>%N")
			Result.append ("* { box-sizing: border-box; }%N")
			Result.append ("body { font-family: sans-serif; margin: 0; display: flex; height: 100vh; }%N")
			Result.append (".sidebar { width: 200px; background: #f5f5f5; padding: 10px; border-right: 1px solid #ddd; }%N")
			Result.append (".sidebar h3 { margin: 0 0 10px 0; }%N")
			Result.append (".main { flex: 1; display: flex; flex-direction: column; }%N")
			Result.append (".toolbar { padding: 10px; background: #333; color: white; }%N")
			Result.append (".toolbar .btn { display: inline-block; padding: 4px 12px; background: #555; color: white; text-decoration: none; border-radius: 3px; margin-left: 5px; }%N")
			Result.append (".toolbar .btn:hover { background: #666; }%N")
			Result.append ("#canvas { flex: 1; padding: 20px; overflow: auto; background: #fafafa; }%N")
			Result.append (".canvas-grid { background: white; border: 1px solid #ddd; padding: 20px; min-height: 400px; overflow-x: auto; }%N")
			Result.append (".grid-row { display: flex; flex-wrap: wrap; gap: 8px; margin-bottom: 10px; }%N")
			Result.append (".control { background: #e3f2fd; border: 2px solid #2196F3; padding: 10px; cursor: pointer; }%N")
			Result.append (".control:hover { border-color: #1565C0; }%N")
			Result.append (".control.selected { border-color: #ff9800; background: #fff3e0; box-shadow: 0 0 8px rgba(255,152,0,0.5); }%N")
			Result.append (".col-1 { flex: 0 0 calc(4.16%% - 6px); } .col-2 { flex: 0 0 calc(8.33%% - 6px); } .col-3 { flex: 0 0 calc(12.5%% - 6px); }%N")
			Result.append (".col-4 { flex: 0 0 calc(16.66%% - 6px); } .col-5 { flex: 0 0 calc(20.83%% - 6px); } .col-6 { flex: 0 0 calc(25%% - 6px); }%N")
			Result.append (".col-7 { flex: 0 0 calc(29.16%% - 6px); } .col-8 { flex: 0 0 calc(33.33%% - 6px); } .col-9 { flex: 0 0 calc(37.5%% - 6px); }%N")
			Result.append (".col-10 { flex: 0 0 calc(41.66%% - 6px); } .col-11 { flex: 0 0 calc(45.83%% - 6px); } .col-12 { flex: 0 0 calc(50%% - 6px); }%N")
			Result.append (".col-13 { flex: 0 0 calc(54.16%% - 6px); } .col-14 { flex: 0 0 calc(58.33%% - 6px); } .col-15 { flex: 0 0 calc(62.5%% - 6px); }%N")
			Result.append (".col-16 { flex: 0 0 calc(66.66%% - 6px); } .col-17 { flex: 0 0 calc(70.83%% - 6px); } .col-18 { flex: 0 0 calc(75%% - 6px); }%N")
			Result.append (".col-19 { flex: 0 0 calc(79.16%% - 6px); } .col-20 { flex: 0 0 calc(83.33%% - 6px); } .col-21 { flex: 0 0 calc(87.5%% - 6px); }%N")
			Result.append (".col-22 { flex: 0 0 calc(91.66%% - 6px); } .col-23 { flex: 0 0 calc(95.83%% - 6px); } .col-24 { flex: 0 0 100%%; }%N")
			Result.append (".palette-group { margin-bottom: 15px; }%N")
			Result.append (".palette-group h5 { margin: 5px 0; color: #666; }%N")
			Result.append (".palette-item { padding: 8px; background: white; border: 1px solid #ddd; margin: 2px 0; cursor: grab; }%N")
			Result.append (".palette-item:hover { background: #e3f2fd; }%N")
			Result.append (".properties { width: 250px; background: #f5f5f5; padding: 10px; border-left: 1px solid #ddd; }%N")
			Result.append (".properties label { display: block; margin-top: 10px; font-size: 12px; color: #666; }%N")
			Result.append (".properties input, .properties textarea { width: 100%%; padding: 5px; }%N")
			Result.append (".properties input.readonly-field { background: #e0e0e0; color: #666; cursor: not-allowed; border: 1px solid #ccc; }%N")
			Result.append (".spinner-group { display: flex; align-items: center; }%N")
			Result.append (".spin-btn { width: 30px; height: 30px; border: 1px solid #ccc; background: #fff; cursor: pointer; font-size: 16px; }%N")
			Result.append (".spin-btn:hover { background: #e3f2fd; }%N")
			Result.append (".spin-input { width: 50px; text-align: center; margin: 0 4px; }%N")
			Result.append (".delete-btn { width: 100%%; padding: 10px; background: #f44336; color: white; border: none; border-radius: 4px; cursor: pointer; font-size: 14px; font-weight: bold; }%N")
			Result.append (".delete-btn:hover { background: #d32f2f; }%N")
			Result.append (".screen-list { list-style: none; padding: 0; }%N")
			Result.append (".screen-list li { padding: 8px; cursor: pointer; }%N")
			Result.append (".screen-list li:hover { background: #e3f2fd; }%N")
			-- Container control styles
			Result.append (".container-control { position: relative; min-height: 80px; }%N")
			Result.append (".card-control { background: #fff; border: 2px solid #9c27b0; border-radius: 8px; padding: 0; overflow: hidden; }%N")
			Result.append (".card-control:hover { border-color: #7b1fa2; }%N")
			Result.append (".card-control.selected { border-color: #ff9800; box-shadow: 0 0 8px rgba(255,152,0,0.5); }%N")
			Result.append (".card-header { background: #9c27b0; color: white; padding: 8px 12px; font-weight: bold; }%N")
			Result.append (".card-body { padding: 10px; min-height: 60px; background: #fce4ec; }%N")
			Result.append (".tabs-control { background: #fff; border: 2px solid #00bcd4; border-radius: 8px; padding: 0; overflow: hidden; }%N")
			Result.append (".tabs-control:hover { border-color: #0097a7; }%N")
			Result.append (".tabs-control.selected { border-color: #ff9800; box-shadow: 0 0 8px rgba(255,152,0,0.5); }%N")
			Result.append (".tabs-header { display: flex; background: #00bcd4; }%N")
			Result.append (".tab-header { padding: 8px 16px; color: white; cursor: pointer; border-right: 1px solid rgba(255,255,255,0.3); }%N")
			Result.append (".tab-header:hover { background: rgba(255,255,255,0.2); }%N")
			Result.append (".tab-header.active { background: #e0f7fa; color: #00bcd4; font-weight: bold; }%N")
			Result.append (".tab-add-btn { padding: 8px 12px; color: white; cursor: pointer; font-weight: bold; }%N")
			Result.append (".tab-add-btn:hover { background: rgba(255,255,255,0.2); }%N")
			Result.append (".tab-panel { display: none; padding: 10px; min-height: 60px; background: #e0f7fa; }%N")
			Result.append (".tab-panel.active { display: block; }%N")
			Result.append (".drop-zone { transition: background 0.2s; }%N")
			Result.append (".drop-zone.drag-over { background: #c8e6c9 !important; border: 2px dashed #4caf50; }%N")
			Result.append (".drop-placeholder { color: #999; font-style: italic; text-align: center; padding: 20px; border: 2px dashed #ccc; border-radius: 4px; }%N")
			Result.append ("</style>%N</head>%N<body>%N")
			-- Sidebar
			Result.append ("<div class=%"sidebar%">%N")
			Result.append ("<h3>Screens</h3>%N")
			Result.append ("<div id=%"screen-list%" hx-get=%"/htmx/screen-list/" + l_name + "%" hx-trigger=%"load%">Loading...</div>%N")
			Result.append ("<hr>%N")
			Result.append ("<div id=%"palette%" hx-get=%"/htmx/palette%" hx-trigger=%"load%">Loading palette...</div>%N")
			Result.append ("</div>%N")
			-- Main area
			Result.append ("<div class=%"main%">%N")
			Result.append ("<div class=%"toolbar%">%N")
			Result.append ("<strong>GUI Designer</strong> - " + l_name + " | %N")
			Result.append ("<button type=%"button%" onclick=%"createNewScreen('" + l_name + "')%">+ New Screen</button> %N")
			Result.append ("<button hx-post=%"/api/specs/" + l_name + "/finalize%" hx-swap=%"none%" ")
			Result.append ("hx-on::after-request=%"this.textContent='Finalized!'; this.style.background='#4CAF50'; var eb=document.getElementById('export-btn'); eb.style.opacity='1'; eb.style.pointerEvents='auto';%">Finalize</button> %N")
			Result.append ("<a id=%"export-btn%" href=%"/api/specs/" + l_name + "/export%" class=%"btn%" ")
			Result.append ("style=%"opacity:0.5; pointer-events:none%">Export</a> %N")
			Result.append ("<button hx-post=%"/api/specs/" + l_name + "/save%" hx-swap=%"none%" ")
			Result.append ("hx-on::after-request=%"this.textContent='Saved!'; this.style.background='#4CAF50'; setTimeout(function(){this.textContent='Save'; this.style.background='';},2000)%">Save</button> %N")
			Result.append ("<a href=%"/api/specs/" + l_name + "/download%" class=%"btn%">Download</a> %N")
			Result.append ("<a href=%"/%" style=%"color:#aaa; margin-left:20px;%">Back to Home</a>%N")
			Result.append ("</div>%N")
			Result.append ("<div id=%"canvas%"><p>Select a screen from the sidebar to begin designing.</p></div>%N")
			Result.append ("</div>%N")
			-- Properties panel
			Result.append ("<div class=%"properties%" id=%"properties%">%N")
			Result.append ("<h4>Properties</h4>%N")
			Result.append ("<p>Select a control to edit its properties.</p>%N")
			Result.append ("</div>%N")
			-- JavaScript for canvas refresh and drag-and-drop
			Result.append ("<script>%N")
			Result.append ("var currentSpecId = '" + l_name + "';%N")
			Result.append ("var currentScreenId = null;%N")
			Result.append ("var controlCounter = 0;%N")
			Result.append ("%N")
			Result.append ("function refreshCanvas() {%N")
			Result.append ("  var form = event.target;%N")
			Result.append ("  var canvasUrl = form.getAttribute('data-canvas-url');%N")
			Result.append ("  var propsUrl = form.getAttribute('data-props-url');%N")
			Result.append ("  var controlId = form.getAttribute('data-control-id');%N")
			Result.append ("  htmx.ajax('GET', canvasUrl, {target:'#canvas'}).then(function(){%N")
			Result.append ("    var el = document.querySelector('[data-id=' + JSON.stringify(controlId) + ']');%N")
			Result.append ("    if(el) el.classList.add('selected');%N")
			Result.append ("    htmx.ajax('GET', propsUrl, {target:'#properties'});%N")
			Result.append ("    setupCanvasDrop();%N")
			Result.append ("  });%N")
			Result.append ("}%N")
			Result.append ("%N")
			Result.append ("function deleteControl(specId, screenId, controlId) {%N")
			Result.append ("  if (!confirm('Delete this control?')) return;%N")
			Result.append ("  var url = '/api/specs/' + specId + '/screens/' + screenId + '/controls/' + controlId;%N")
			Result.append ("  console.log('[DELETE] Deleting control:', url);%N")
			Result.append ("  fetch(url, { method: 'DELETE' })%N")
			Result.append ("  .then(function(r) {%N")
			Result.append ("    if (r.ok) {%N")
			Result.append ("      console.log('[DELETE] Control deleted successfully');%N")
			Result.append ("      var canvasUrl = '/htmx/canvas/' + specId + '/' + screenId;%N")
			Result.append ("      htmx.ajax('GET', canvasUrl, {target:'#canvas'});%N")
			Result.append ("      document.getElementById('properties').innerHTML = '<p style=%"color:#666;padding:20px;%">Select a control to edit its properties</p>';%N")
			Result.append ("    } else {%N")
			Result.append ("      alert('Failed to delete control');%N")
			Result.append ("    }%N")
			Result.append ("  })%N")
			Result.append ("  .catch(function(err) {%N")
			Result.append ("    console.error('[DELETE] Error:', err);%N")
			Result.append ("    alert('Error deleting control: ' + err.message);%N")
			Result.append ("  });%N")
			Result.append ("}%N")
			Result.append ("%N")
			Result.append ("function createNewScreen(specId) {%N")
			Result.append ("  var title = prompt('Enter screen title:', 'New Screen');%N")
			Result.append ("  if (!title) return;%N")
			Result.append ("  var id = title.toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_|_$/g, '');%N")
			Result.append ("  if (!id) { alert('Invalid screen title'); return; }%N")
			Result.append ("  console.log('[SCREEN] Creating new screen:', id, title);%N")
			Result.append ("  fetch('/api/specs/' + specId + '/screens', {%N")
			Result.append ("    method: 'POST',%N")
			Result.append ("    headers: { 'Content-Type': 'application/json' },%N")
			Result.append ("    body: JSON.stringify({ id: id, title: title })%N")
			Result.append ("  })%N")
			Result.append ("  .then(function(r) {%N")
			Result.append ("    if (r.ok) {%N")
			Result.append ("      console.log('[SCREEN] Screen created successfully');%N")
			Result.append ("      htmx.ajax('GET', '/htmx/screen-list/' + specId, {target:'#screen-list'});%N")
			Result.append ("    } else {%N")
			Result.append ("      r.json().then(function(data) { alert('Failed: ' + (data.error || 'Unknown error')); });%N")
			Result.append ("    }%N")
			Result.append ("  })%N")
			Result.append ("  .catch(function(err) {%N")
			Result.append ("    console.error('[SCREEN] Error:', err);%N")
			Result.append ("    alert('Error creating screen: ' + err.message);%N")
			Result.append ("  });%N")
			Result.append ("}%N")
			Result.append ("%N")
			Result.append ("// Track current screen when loading canvas%N")
			Result.append ("document.body.addEventListener('htmx:afterSwap', function(evt) {%N")
			Result.append ("  if (evt.detail.target.id === 'canvas') {%N")
			Result.append ("    // Extract screen ID from the request URL%N")
			Result.append ("    var url = evt.detail.pathInfo.requestPath;%N")
			Result.append ("    var parts = url.split('/');%N")
			Result.append ("    if (parts.length >= 4) {%N")
			Result.append ("      currentScreenId = parts[parts.length - 1];%N")
			Result.append ("      console.log('Current screen set to:', currentScreenId);%N")
			Result.append ("    }%N")
			Result.append ("    setupCanvasDrop();%N")
			Result.append ("  }%N")
			Result.append ("});%N")
			Result.append ("%N")
			Result.append ("// Setup palette drag handlers%N")
			Result.append ("document.body.addEventListener('htmx:afterSwap', function(evt) {%N")
			Result.append ("  if (evt.detail.target.id === 'palette') {%N")
			Result.append ("    setupPaletteDrag();%N")
			Result.append ("  }%N")
			Result.append ("});%N")
			Result.append ("%N")
			Result.append ("function setupPaletteDrag() {%N")
			Result.append ("  document.querySelectorAll('.palette-item').forEach(function(item) {%N")
			Result.append ("    item.addEventListener('dragstart', function(e) {%N")
			Result.append ("      var controlType = this.getAttribute('data-type');%N")
			Result.append ("      e.dataTransfer.setData('text/plain', controlType);%N")
			Result.append ("      e.dataTransfer.effectAllowed = 'copy';%N")
			Result.append ("      console.log('Drag started:', controlType);%N")
			Result.append ("    });%N")
			Result.append ("  });%N")
			Result.append ("}%N")
			Result.append ("%N")
			Result.append ("function setupCanvasDrop() {%N")
			Result.append ("  var canvas = document.getElementById('canvas');%N")
			Result.append ("  var canvasGrid = canvas.querySelector('.canvas-grid');%N")
			Result.append ("  if (!canvasGrid) {%N")
			Result.append ("    console.log('No canvas-grid found yet');%N")
			Result.append ("    return;%N")
			Result.append ("  }%N")
			Result.append ("  %N")
			Result.append ("  // Prevent duplicate event listener registration%N")
			Result.append ("  if (canvasGrid.dataset.dropSetup === 'true') {%N")
			Result.append ("    console.log('[CANVAS] Drop handlers already setup');%N")
			Result.append ("    return;%N")
			Result.append ("  }%N")
			Result.append ("  canvasGrid.dataset.dropSetup = 'true';%N")
			Result.append ("  console.log('[CANVAS] Attaching drop handlers');%N")
			Result.append ("  %N")
			Result.append ("  canvasGrid.addEventListener('dragover', function(e) {%N")
			Result.append ("    e.preventDefault();%N")
			Result.append ("    e.dataTransfer.dropEffect = 'copy';%N")
			Result.append ("    this.style.background = '#e8f5e9';%N")
			Result.append ("  });%N")
			Result.append ("  %N")
			Result.append ("  canvasGrid.addEventListener('dragleave', function(e) {%N")
			Result.append ("    this.style.background = '';%N")
			Result.append ("  });%N")
			Result.append ("  %N")
			Result.append ("  canvasGrid.addEventListener('drop', function(e) {%N")
			Result.append ("    e.preventDefault();%N")
			Result.append ("    this.style.background = '';%N")
			Result.append ("    %N")
			Result.append ("    var controlType = e.dataTransfer.getData('text/plain');%N")
			Result.append ("    if (!controlType) {%N")
			Result.append ("      console.log('No control type in drop data');%N")
			Result.append ("      return;%N")
			Result.append ("    }%N")
			Result.append ("    %N")
			Result.append ("    if (!currentScreenId) {%N")
			Result.append ("      alert('Please select a screen first');%N")
			Result.append ("      return;%N")
			Result.append ("    }%N")
			Result.append ("    %N")
			Result.append ("    console.log('Dropped:', controlType, 'on screen:', currentScreenId);%N")
			Result.append ("    addControlToScreen(controlType);%N")
			Result.append ("  });%N")
			Result.append ("  %N")
			Result.append ("  console.log('Canvas drop handlers set up');%N")
			Result.append ("}%N")
			Result.append ("%N")
			Result.append ("function addControlToScreen(controlType) {%N")
			Result.append ("  controlCounter++;%N")
			Result.append ("  var controlId = controlType + '_' + Date.now();%N")
			Result.append ("  var defaultColSpan = getDefaultColSpan(controlType);%N")
			Result.append ("  var label = getDefaultLabel(controlType);%N")
			Result.append ("  %N")
			Result.append ("  var payload = {%N")
			Result.append ("    id: controlId,%N")
			Result.append ("    type: controlType,%N")
			Result.append ("    label: label,%N")
			Result.append ("    grid_row: 1,%N")
			Result.append ("    grid_col: 1,%N")
			Result.append ("    col_span: defaultColSpan%N")
			Result.append ("  };%N")
			Result.append ("  %N")
			Result.append ("  var url = '/api/specs/' + currentSpecId + '/screens/' + currentScreenId + '/controls';%N")
			Result.append ("  console.log('POST to:', url, payload);%N")
			Result.append ("  %N")
			Result.append ("  fetch(url, {%N")
			Result.append ("    method: 'POST',%N")
			Result.append ("    headers: { 'Content-Type': 'application/json' },%N")
			Result.append ("    body: JSON.stringify(payload)%N")
			Result.append ("  })%N")
			Result.append ("  .then(function(r) { return r.json(); })%N")
			Result.append ("  .then(function(data) {%N")
			Result.append ("    console.log('Control added:', data);%N")
			Result.append ("    var newControlId = data.id;%N")
			Result.append ("    // Refresh the canvas, then select the new control%N")
			Result.append ("    var canvasUrl = '/htmx/canvas/' + currentSpecId + '/' + currentScreenId;%N")
			Result.append ("    htmx.ajax('GET', canvasUrl, {target:'#canvas'}).then(function(){%N")
			Result.append ("      // Select the new control (orange highlight)%N")
			Result.append ("      document.querySelectorAll('.control.selected').forEach(function(c) { c.classList.remove('selected'); });%N")
			Result.append ("      var newEl = document.querySelector('[data-id=%"' + newControlId + '%"]');%N")
			Result.append ("      if (newEl) {%N")
			Result.append ("        newEl.classList.add('selected');%N")
			Result.append ("        console.log('Selected new control:', newControlId);%N")
			Result.append ("      }%N")
			Result.append ("      // Load properties for the new control%N")
			Result.append ("      var propsUrl = '/htmx/properties/' + currentSpecId + '/' + currentScreenId + '/' + newControlId;%N")
			Result.append ("      htmx.ajax('GET', propsUrl, {target:'#properties'});%N")
			Result.append ("    });%N")
			Result.append ("  })%N")
			Result.append ("  .catch(function(err) {%N")
			Result.append ("    console.error('Failed to add control:', err);%N")
			Result.append ("    alert('Failed to add control: ' + err.message);%N")
			Result.append ("  });%N")
			Result.append ("}%N")
			Result.append ("%N")
			Result.append ("function getDefaultColSpan(controlType) {%N")
			Result.append ("  var spans = {%N")
			Result.append ("    'text_field': 4, 'text_area': 6, 'number_field': 2,%N")
			Result.append ("    'dropdown': 3, 'checkbox': 2, 'date_picker': 3,%N")
			Result.append ("    'button': 2, 'link': 2,%N")
			Result.append ("    'label': 3, 'heading': 12, 'table': 12, 'list': 6,%N")
			Result.append ("    'card': 6, 'tabs': 12%N")
			Result.append ("  };%N")
			Result.append ("  return spans[controlType] || 4;%N")
			Result.append ("}%N")
			Result.append ("%N")
			Result.append ("function getDefaultLabel(controlType) {%N")
			Result.append ("  var labels = {%N")
			Result.append ("    'text_field': 'Text Field', 'text_area': 'Text Area', 'number_field': 'Number',%N")
			Result.append ("    'dropdown': 'Dropdown', 'checkbox': 'Checkbox', 'date_picker': 'Date',%N")
			Result.append ("    'button': 'Button', 'link': 'Link',%N")
			Result.append ("    'label': 'Label', 'heading': 'Heading', 'table': 'Table', 'list': 'List',%N")
			Result.append ("    'card': 'Card', 'tabs': 'Tabs'%N")
			Result.append ("  };%N")
			Result.append ("  return labels[controlType] || controlType;%N")
			Result.append ("}%N")
			Result.append ("%N")
			-- Container-specific JavaScript
			Result.append ("// Setup drop zones for containers after canvas loads%N")
			Result.append ("function setupContainerDropZones() {%N")
			Result.append ("  console.log('[CONTAINER] Setting up container drop zones');%N")
			Result.append ("  document.querySelectorAll('.drop-zone').forEach(function(zone) {%N")
			Result.append ("    // Prevent duplicate event listener registration%N")
			Result.append ("    if (zone.dataset.dropSetup === 'true') {%N")
			Result.append ("      console.log('[CONTAINER] Drop zone already setup:', zone.dataset.parent);%N")
			Result.append ("      return;%N")
			Result.append ("    }%N")
			Result.append ("    zone.dataset.dropSetup = 'true';%N")
			Result.append ("    console.log('[CONTAINER] Attaching listeners to:', zone.dataset.parent);%N")
			Result.append ("    zone.addEventListener('dragover', function(e) {%N")
			Result.append ("      e.preventDefault();%N")
			Result.append ("      e.stopPropagation();%N")
			Result.append ("      e.dataTransfer.dropEffect = 'copy';%N")
			Result.append ("      this.classList.add('drag-over');%N")
			Result.append ("      console.log('[CONTAINER] Drag over drop zone:', this.dataset.parent);%N")
			Result.append ("    });%N")
			Result.append ("    zone.addEventListener('dragleave', function(e) {%N")
			Result.append ("      e.stopPropagation();%N")
			Result.append ("      this.classList.remove('drag-over');%N")
			Result.append ("    });%N")
			Result.append ("    zone.addEventListener('drop', function(e) {%N")
			Result.append ("      e.preventDefault();%N")
			Result.append ("      e.stopPropagation();%N")
			Result.append ("      this.classList.remove('drag-over');%N")
			Result.append ("      var controlType = e.dataTransfer.getData('text/plain');%N")
			Result.append ("      var parentId = this.dataset.parent;%N")
			Result.append ("      var panelIdx = this.dataset.panelIdx || null;%N")
			Result.append ("      console.log('[CONTAINER] Dropped', controlType, 'onto container', parentId, 'panel', panelIdx);%N")
			Result.append ("      if (controlType && parentId) {%N")
			Result.append ("        addControlToContainer(controlType, parentId, panelIdx);%N")
			Result.append ("      }%N")
			Result.append ("    });%N")
			Result.append ("  });%N")
			Result.append ("}%N")
			Result.append ("%N")
			Result.append ("function addControlToContainer(controlType, parentId, panelIdx) {%N")
			Result.append ("  var controlId = controlType + '_' + Date.now();%N")
			Result.append ("  var defaultColSpan = getDefaultColSpan(controlType);%N")
			Result.append ("  var label = getDefaultLabel(controlType);%N")
			Result.append ("  %N")
			Result.append ("  var payload = {%N")
			Result.append ("    id: controlId,%N")
			Result.append ("    type: controlType,%N")
			Result.append ("    label: label,%N")
			Result.append ("    grid_row: 1,%N")
			Result.append ("    grid_col: 1,%N")
			Result.append ("    col_span: defaultColSpan,%N")
			Result.append ("    parent_id: parentId%N")
			Result.append ("  };%N")
			Result.append ("  if (panelIdx) {%N")
			Result.append ("    payload.panel_index = parseInt(panelIdx);%N")
			Result.append ("  }%N")
			Result.append ("  %N")
			Result.append ("  var url = '/api/specs/' + currentSpecId + '/screens/' + currentScreenId + '/controls/' + parentId + '/children';%N")
			Result.append ("  console.log('[CONTAINER] POST to:', url, payload);%N")
			Result.append ("  %N")
			Result.append ("  fetch(url, {%N")
			Result.append ("    method: 'POST',%N")
			Result.append ("    headers: { 'Content-Type': 'application/json' },%N")
			Result.append ("    body: JSON.stringify(payload)%N")
			Result.append ("  })%N")
			Result.append ("  .then(function(r) { return r.json(); })%N")
			Result.append ("  .then(function(data) {%N")
			Result.append ("    console.log('[CONTAINER] Child control added:', data);%N")
			Result.append ("    var canvasUrl = '/htmx/canvas/' + currentSpecId + '/' + currentScreenId;%N")
			Result.append ("    htmx.ajax('GET', canvasUrl, {target:'#canvas'}).then(function(){%N")
			Result.append ("      document.querySelectorAll('.control.selected').forEach(function(c) { c.classList.remove('selected'); });%N")
			Result.append ("      var newEl = document.querySelector('[data-id=%"' + data.id + '%"]');%N")
			Result.append ("      if (newEl) {%N")
			Result.append ("        newEl.classList.add('selected');%N")
			Result.append ("      }%N")
			Result.append ("      var propsUrl = '/htmx/properties/' + currentSpecId + '/' + currentScreenId + '/' + data.id;%N")
			Result.append ("      htmx.ajax('GET', propsUrl, {target:'#properties'});%N")
			Result.append ("    });%N")
			Result.append ("  })%N")
			Result.append ("  .catch(function(err) {%N")
			Result.append ("    console.error('[CONTAINER] Failed to add child:', err);%N")
			Result.append ("    alert('Failed to add control to container: ' + err.message);%N")
			Result.append ("  });%N")
			Result.append ("}%N")
			Result.append ("%N")
			Result.append ("// Tab switching%N")
			Result.append ("function switchTab(tabHeader, event) {%N")
			Result.append ("  event.stopPropagation();%N")
			Result.append ("  var tabsId = tabHeader.dataset.tabsId;%N")
			Result.append ("  var tabIdx = tabHeader.dataset.tabIdx;%N")
			Result.append ("  console.log('[TABS] Switching to tab', tabIdx, 'in', tabsId);%N")
			Result.append ("  %N")
			Result.append ("  // Update tab headers%N")
			Result.append ("  var tabsControl = tabHeader.closest('.tabs-control');%N")
			Result.append ("  tabsControl.querySelectorAll('.tab-header').forEach(function(h) { h.classList.remove('active'); });%N")
			Result.append ("  tabHeader.classList.add('active');%N")
			Result.append ("  %N")
			Result.append ("  // Update tab panels%N")
			Result.append ("  tabsControl.querySelectorAll('.tab-panel').forEach(function(p) { p.classList.remove('active'); });%N")
			Result.append ("  tabsControl.querySelector('.tab-panel[data-tab-idx=%"' + tabIdx + '%"]').classList.add('active');%N")
			Result.append ("  %N")
			Result.append ("  // Persist to server%N")
			Result.append ("  fetch('/api/specs/' + currentSpecId + '/screens/' + currentScreenId + '/controls/' + tabsId + '/active-tab', {%N")
			Result.append ("    method: 'PUT',%N")
			Result.append ("    headers: { 'Content-Type': 'application/json' },%N")
			Result.append ("    body: JSON.stringify({ active_tab: parseInt(tabIdx) })%N")
			Result.append ("  }).then(function(r) { console.log('[TABS] Active tab saved'); });%N")
			Result.append ("}%N")
			Result.append ("%N")
			Result.append ("// Add new tab%N")
			Result.append ("function addTab(tabsId, event) {%N")
			Result.append ("  event.stopPropagation();%N")
			Result.append ("  var tabName = prompt('Enter tab name:', 'New Tab');%N")
			Result.append ("  if (!tabName) return;%N")
			Result.append ("  console.log('[TABS] Adding new tab to', tabsId, ':', tabName);%N")
			Result.append ("  %N")
			Result.append ("  fetch('/api/specs/' + currentSpecId + '/screens/' + currentScreenId + '/controls/' + tabsId + '/tabs', {%N")
			Result.append ("    method: 'POST',%N")
			Result.append ("    headers: { 'Content-Type': 'application/json' },%N")
			Result.append ("    body: JSON.stringify({ name: tabName })%N")
			Result.append ("  })%N")
			Result.append ("  .then(function(r) { return r.json(); })%N")
			Result.append ("  .then(function(data) {%N")
			Result.append ("    console.log('[TABS] Tab added:', data);%N")
			Result.append ("    var canvasUrl = '/htmx/canvas/' + currentSpecId + '/' + currentScreenId;%N")
			Result.append ("    htmx.ajax('GET', canvasUrl, {target:'#canvas'});%N")
			Result.append ("  });%N")
			Result.append ("}%N")
			Result.append ("%N")
			Result.append ("// Modify setupCanvasDrop to also setup container zones%N")
			Result.append ("var originalSetupCanvasDrop = setupCanvasDrop;%N")
			Result.append ("setupCanvasDrop = function() {%N")
			Result.append ("  originalSetupCanvasDrop();%N")
			Result.append ("  setupContainerDropZones();%N")
			Result.append ("};%N")
			Result.append ("</script>%N")
			Result.append ("</body>%N</html>")
		end

	control_palette_json: STRING
			-- Control palette as JSON.
		once
			Result := "[
{
	"categories": [
		{
			"name": "Input",
			"controls": [
				{"type": "text_field", "label": "Text Field", "default_col_span": 4},
				{"type": "text_area", "label": "Text Area", "default_col_span": 6},
				{"type": "number_field", "label": "Number", "default_col_span": 2},
				{"type": "dropdown", "label": "Dropdown", "default_col_span": 3},
				{"type": "checkbox", "label": "Checkbox", "default_col_span": 2},
				{"type": "date_picker", "label": "Date Picker", "default_col_span": 3}
			]
		},
		{
			"name": "Actions",
			"controls": [
				{"type": "button", "label": "Button", "default_col_span": 2},
				{"type": "link", "label": "Link", "default_col_span": 2}
			]
		},
		{
			"name": "Display",
			"controls": [
				{"type": "label", "label": "Label", "default_col_span": 3},
				{"type": "heading", "label": "Heading", "default_col_span": 12},
				{"type": "table", "label": "Table", "default_col_span": 12},
				{"type": "list", "label": "List", "default_col_span": 6}
			]
		},
		{
			"name": "Layout",
			"controls": [
				{"type": "card", "label": "Card", "default_col_span": 6},
				{"type": "tabs", "label": "Tabs", "default_col_span": 12}
			]
		}
	]
}
			]"
		end

invariant
	specs_attached: specs /= Void
	current_spec_attached: current_spec /= Void

end
