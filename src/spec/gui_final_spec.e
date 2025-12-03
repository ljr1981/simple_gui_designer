note
	description: "[
		Final production-ready GUI specification.

		This is the CLEAN spec consumed by the actual application being built.
		It contains only what's needed to render the UI and wire up the backend:
		- Screen definitions
		- Control layouts
		- API bindings
		- Validation rules

		NO designer artifacts (notes, suggestions, positions in designer grid).
		The app interprets this spec to render its UI.
	]"
	author: "Claude Code"
	date: "$Date$"
	revision: "$Revision$"

class
	GUI_FINAL_SPEC

inherit
	SIMPLE_JSON_SERIALIZABLE

create
	make,
	make_from_json,
	make_from_designer_spec

feature {NONE} -- Initialization

	make (a_app_name: STRING_32)
			-- Create empty final spec.
		require
			name_not_empty: not a_app_name.is_empty
		do
			app_name := a_app_name
			create screens.make (5)
			create api_endpoints.make (10)
		ensure
			name_set: app_name.same_string (a_app_name)
		end

	make_from_json (a_json: SIMPLE_JSON_OBJECT)
			-- Load from JSON.
		require
			has_app: a_json.has_key ("app")
		local
			i: INTEGER
		do
			if attached a_json.string_item ("app") as n then
				app_name := n
			else
				app_name := "unnamed"
			end

			create screens.make (5)
			create api_endpoints.make (10)

			-- Load screens
			if attached a_json.array_item ("screens") as l_screens then
				from i := 1 until i > l_screens.count loop
					if attached l_screens.item (i).as_object as l_obj then
						screens.extend (create {GUI_FINAL_SCREEN}.make_from_json (l_obj))
					end
					i := i + 1
				end
			end

			-- Load API endpoints
			if attached a_json.array_item ("api_endpoints") as l_endpoints then
				from i := 1 until i > l_endpoints.count loop
					if attached l_endpoints.item (i).as_object as l_obj then
						api_endpoints.extend (create {GUI_API_ENDPOINT}.make_from_json (l_obj))
					end
					i := i + 1
				end
			end
		end

	make_from_designer_spec (a_designer: GUI_DESIGNER_SPEC)
			-- Convert from designer spec, stripping designer-only data.
		require
			designer_finalized: a_designer.is_finalized
		do
			app_name := a_designer.app_name
			create screens.make (a_designer.screens.count)
			create api_endpoints.make (10)

			-- Convert each screen, extracting only production data
			across a_designer.screens as ic loop
				screens.extend (create {GUI_FINAL_SCREEN}.make_from_designer_screen (ic))
			end

			-- Collect all API endpoints from screens
			collect_api_endpoints
		ensure
			name_matches: app_name.same_string (a_designer.app_name)
		end

feature -- Access

	app_name: STRING_32
			-- Application name.

	screens: ARRAYED_LIST [GUI_FINAL_SCREEN]
			-- Production screen definitions.

	api_endpoints: ARRAYED_LIST [GUI_API_ENDPOINT]
			-- All API endpoints required by this UI.

feature -- Query

	screen_by_id (a_id: STRING_32): detachable GUI_FINAL_SCREEN
			-- Find screen by ID.
		do
			across screens as ic loop
				if ic.id.same_string (a_id) then
					Result := ic
				end
			end
		end

	endpoint_by_path (a_path: STRING_32): detachable GUI_API_ENDPOINT
			-- Find endpoint by path.
		do
			across api_endpoints as ic loop
				if ic.path.same_string (a_path) then
					Result := ic
				end
			end
		end

feature {NONE} -- Implementation

	collect_api_endpoints
			-- Extract all unique API endpoints from screens.
		local
			l_seen: ARRAYED_LIST [STRING_32]
		do
			create l_seen.make (10)
			across screens as scr loop
				across scr.api_bindings as binding loop
					if not across l_seen as s some s.same_string (binding.path) end then
						l_seen.extend (binding.path)
						api_endpoints.extend (binding)
					end
				end
			end
		end

feature -- JSON Serialization

	to_json: SIMPLE_JSON_OBJECT
			-- Convert to JSON for consumption by target app.
		local
			l_screens_arr, l_endpoints_arr: SIMPLE_JSON_ARRAY
		do
			create Result.make
			Result.put_string (app_name, "app").do_nothing

			-- Screens
			create l_screens_arr.make
			across screens as ic loop
				l_screens_arr.add_object (ic.to_json).do_nothing
			end
			Result.put_array (l_screens_arr, "screens").do_nothing

			-- API endpoints
			create l_endpoints_arr.make
			across api_endpoints as ic loop
				l_endpoints_arr.add_object (ic.to_json).do_nothing
			end
			Result.put_array (l_endpoints_arr, "api_endpoints").do_nothing
		end

feature -- JSON Deserialization

	apply_json (a_json: SIMPLE_JSON_OBJECT)
			-- Apply JSON (not typically used for final spec).
		do
			-- Final specs are read-only once generated
		end

feature -- Validation

	json_has_required_fields (a_json: SIMPLE_JSON_OBJECT): BOOLEAN
			-- Check required fields.
		do
			Result := a_json.has_key ("app")
		end

invariant
	app_name_not_empty: not app_name.is_empty
	screens_attached: screens /= Void
	endpoints_attached: api_endpoints /= Void

end
