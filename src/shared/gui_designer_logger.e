note
	description: "[
		Centralized logging facility for GUI Designer.

		Provides process-wide logging to file with:
		- Debug, info, warning, error levels
		- Timestamped entries
		- Request/response logging
		- Control operation logging
	]"
	author: "Claude Code"
	date: "$Date$"
	revision: "$Revision$"

class
	GUI_DESIGNER_LOGGER

feature -- Access


	log_facility: SIMPLE_LOGGER
			-- Shared logging facility (process-wide singleton).
			-- Writes to system.log in current working directory.
		once ("PROCESS")
			create Result.make_to_file ("system.log")
			Result.set_log_level (Result.Level_debug)
			print ("LOG: Facility initialized with simple_logger%N")
		ensure
			result_attached: Result /= Void
		end

feature -- Logging Operations

	log_debug (a_message: STRING)
			-- Log debug-level message.
		do
			log_facility.debug_log (a_message)
		end

	log_info (a_message: STRING)
			-- Log information-level message.
		do
			log_facility.log_info (a_message)
		end

	log_warning (a_message: STRING)
			-- Log warning-level message.
		do
			log_facility.log_warn (a_message)
		end

	log_error (a_message: STRING)
			-- Log error-level message.
		do
			log_facility.log_error (a_message)
		end

feature -- Request Logging

	log_request (a_method, a_path: STRING)
			-- Log incoming HTTP request.
		do
			log_info ("[REQUEST] " + a_method + " " + a_path)
		end

	log_response (a_status: INTEGER; a_path: STRING)
			-- Log HTTP response with status.
		do
			log_info ("[RESPONSE] " + a_status.out + " for " + a_path)
		end

feature -- Route Logging

	log_route_match (a_route_pattern, a_path: STRING)
			-- Log when a route is matched.
		do
			log_debug ("[ROUTE] Matched pattern '" + a_route_pattern + "' for path '" + a_path + "'")
		end

	log_route_not_found (a_method, a_path: STRING)
			-- Log when no route matches.
		do
			log_warning ("[ROUTE] No match for " + a_method + " " + a_path)
		end

feature -- Spec Logging

	log_spec_loaded (a_spec_name, a_source: STRING)
			-- Log spec loading.
		do
			log_info ("[SPEC] Loaded '" + a_spec_name + "' from " + a_source)
		end

	log_spec_saved (a_spec_name, a_path: STRING)
			-- Log spec save operation.
		do
			log_info ("[SPEC] Saved '" + a_spec_name + "' to " + a_path)
		end

	log_spec_created (a_spec_name: STRING)
			-- Log new spec creation.
		do
			log_info ("[SPEC] Created new spec '" + a_spec_name + "'")
		end

	log_spec_deleted (a_spec_name: STRING)
			-- Log spec deletion.
		do
			log_info ("[SPEC] Deleted '" + a_spec_name + "'")
		end

	log_spec_finalized (a_spec_name: STRING)
			-- Log spec finalization.
		do
			log_info ("[SPEC] Finalized '" + a_spec_name + "'")
		end

feature -- Screen Logging

	log_screen_created (a_spec_name, a_screen_id: STRING)
			-- Log screen creation.
		do
			log_info ("[SCREEN] Created '" + a_screen_id + "' in spec '" + a_spec_name + "'")
		end

	log_screen_updated (a_spec_name, a_screen_id: STRING)
			-- Log screen update.
		do
			log_debug ("[SCREEN] Updated '" + a_screen_id + "' in spec '" + a_spec_name + "'")
		end

	log_screen_deleted (a_spec_name, a_screen_id: STRING)
			-- Log screen deletion.
		do
			log_info ("[SCREEN] Deleted '" + a_screen_id + "' from spec '" + a_spec_name + "'")
		end

feature -- Control Logging

	log_control_added (a_control_id, a_type, a_screen_id: STRING)
			-- Log control addition.
		do
			log_info ("[CONTROL] Added '" + a_control_id + "' (" + a_type + ") to screen '" + a_screen_id + "'")
		end

	log_control_updated (a_control_id: STRING; a_row, a_col, a_col_span: INTEGER)
			-- Log control update with position info.
		do
			log_debug ("[CONTROL] Updated '" + a_control_id + "' row=" + a_row.out + " col=" + a_col.out + " span=" + a_col_span.out)
		end

	log_control_deleted (a_control_id, a_screen_id: STRING)
			-- Log control deletion.
		do
			log_info ("[CONTROL] Deleted '" + a_control_id + "' from screen '" + a_screen_id + "'")
		end

	log_control_selected (a_control_id: STRING)
			-- Log control selection (for properties panel).
		do
			log_debug ("[CONTROL] Selected '" + a_control_id + "' for properties panel")
		end

feature -- Canvas Logging

	log_canvas_render (a_screen_id: STRING; a_control_count: INTEGER)
			-- Log canvas rendering.
		do
			log_debug ("[CANVAS] Rendering screen '" + a_screen_id + "' with " + a_control_count.out + " controls")
		end

	log_canvas_refresh (a_screen_id: STRING)
			-- Log canvas refresh request.
		do
			log_debug ("[CANVAS] Refresh requested for screen '" + a_screen_id + "'")
		end

feature -- Form Data Logging

	log_form_data (a_fields: STRING)
			-- Log form data received.
		do
			log_debug ("[FORM] Received fields: " + a_fields)
		end

	log_json_body (a_json_preview: STRING)
			-- Log JSON body received (truncated preview).
		do
			log_debug ("[JSON] Body: " + a_json_preview)
		end

feature -- Error Logging

	log_parse_error (a_file, a_error: STRING)
			-- Log JSON parse error.
		do
			log_error ("[PARSE] Error in " + a_file + ": " + a_error)
		end

	log_not_found (a_resource_type: STRING; a_id: detachable STRING_32)
			-- Log resource not found.
		local
			l_id: STRING
		do
			if attached a_id as al_id then
				l_id := al_id.to_string_8
			else
				l_id := "(unknown)"
			end
			log_warning ("[NOT_FOUND] " + a_resource_type + " '" + l_id + "' not found")
		end

	log_bad_request (a_reason: STRING)
			-- Log bad request.
		do
			log_warning ("[BAD_REQUEST] " + a_reason)
		end

feature -- Server Logging

	log_server_start (a_port: INTEGER; a_spec_count: INTEGER)
			-- Log server startup.
		do
			log_info ("[SERVER] Starting on port " + a_port.out + " with " + a_spec_count.out + " specs loaded")
		end

	log_server_route_registered (a_method, a_pattern: STRING)
			-- Log route registration.
		do
			log_debug ("[SERVER] Route registered: " + a_method + " " + a_pattern)
		end

end
