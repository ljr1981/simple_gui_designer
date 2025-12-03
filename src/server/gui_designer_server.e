note
	description: "[
		GUI Designer Server - Refactored using multiple inheritance.

		This class composes functionality from multiple deferred handler classes:
		- GDS_SPEC_HANDLERS: Spec CRUD operations
		- GDS_SCREEN_HANDLERS: Screen CRUD operations
		- GDS_CONTROL_HANDLERS: Control CRUD operations
		- GDS_CONTAINER_HANDLERS: Container (card/tabs) operations
		- GDS_HTMX_HANDLERS: HTMX partial responses
		- GDS_EXPORT_HANDLERS: Export and finalization
		- GDS_DOWNLOAD_UPLOAD_HANDLERS: File download/upload
		- GDS_STATIC_HTML: Static page templates (inherits GDS_HTML_RENDERER)

		All handlers inherit from GDS_SHARED_STATE which defines deferred
		features for accessing shared state (specs, server, etc.).
		This class provides the effective implementations of those features.
	]"
	author: "Claude Code"
	date: "$Date$"
	revision: "$Revision$"

class
	GUI_DESIGNER_SERVER

inherit
	GDS_SPEC_HANDLERS
	GDS_SCREEN_HANDLERS
	GDS_CONTROL_HANDLERS
	GDS_CONTAINER_HANDLERS
	GDS_HTMX_HANDLERS
	GDS_EXPORT_HANDLERS
	GDS_DOWNLOAD_UPLOAD_HANDLERS
	GDS_STATIC_HTML
		-- Note: GDS_STATIC_HTML inherits from GDS_HTML_RENDERER,
		-- which provides the html: HTMX_FACTORY feature

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
				create current_spec_impl.make ("untitled")
				specs.force (current_spec_impl, "untitled")
			else
				specs.start
				current_spec_impl := specs.item_for_iteration
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
						log_debug ("[INIT] Attempting to parse: " + s8 (l_file_path))
						if attached l_json.parse_file (l_file_path) as al_parsed and then
						   al_parsed.is_object and then attached al_parsed.as_object as al_obj then
							if al_obj.has_key ("app_name") or al_obj.has_key ("app") then
								load_spec_from_json (al_obj, al_entry)
							else
								log_warning ("[INIT] Skipping file without app_name/app: " + s8 (l_file_path))
							end
						else
							log_parse_error (s8 (l_file_path), l_json.errors_as_string.to_string_8)
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
			log_spec_loaded (s8 (l_name), s8 (a_filename))
			log_debug ("[SPEC] " + s8 (l_name) + " has " + l_spec.screens.count.out + " screens")
		end

	setup_routes
			-- Configure all routes for the designer.
		do
			-- Static pages
			server.on_get ("/", agent handle_index)
			server.on_get ("/designer", agent handle_designer)

			-- Setup routes from all handler mixins
			setup_spec_routes
			setup_screen_routes
			setup_control_routes
			setup_container_routes
			setup_htmx_routes
			setup_export_routes
			setup_download_upload_routes
		end

feature -- Access (GDS_SHARED_STATE implementations)

	port: INTEGER
			-- Server port.

	server: SIMPLE_WEB_SERVER
			-- HTTP server instance.

	specs: HASH_TABLE [GUI_DESIGNER_SPEC, STRING_32]
			-- All loaded specs by ID/app_name.

	current_spec: GUI_DESIGNER_SPEC
			-- Currently active spec.
		do
			Result := current_spec_impl
		end

	specs_directory: STRING
			-- Directory to load/save spec files from.

feature -- Setters

	set_current_spec (a_spec: GUI_DESIGNER_SPEC)
			-- Set the current spec.
		do
			current_spec_impl := a_spec
		end

feature {NONE} -- Implementation

	current_spec_impl: GUI_DESIGNER_SPEC
			-- Internal storage for current spec.

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
		do
			log_request ("GET", "/designer")
			if attached a_request.query_parameter ("spec") as al_spec then
				l_spec_name := al_spec
				log_debug ("[PAGE] Designer page with spec param: " + s8 (l_spec_name))
			else
				l_spec_name := current_spec.app_name
				log_debug ("[PAGE] Designer page using current spec: " + s8 (l_spec_name))
			end
			a_response.send_html (designer_html_for_spec (l_spec_name))
		end

invariant
	specs_attached: specs /= Void
	current_spec_attached: current_spec /= Void

end
