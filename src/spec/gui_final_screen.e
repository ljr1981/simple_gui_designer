note
	description: "[
		Final production-ready screen specification.

		Clean version for consumption by target application.
		No designer artifacts - just what's needed to render.
	]"
	author: "Claude Code"
	date: "$Date$"
	revision: "$Revision$"

class
	GUI_FINAL_SCREEN

inherit
	SIMPLE_JSON_SERIALIZABLE

create
	make,
	make_from_json,
	make_from_designer_screen

feature {NONE} -- Initialization

	make (a_id, a_title: STRING_32)
			-- Create screen.
		require
			id_not_empty: not a_id.is_empty
		do
			id := a_id
			title := a_title
			create controls.make (10)
			create api_bindings.make (5)
		end

	make_from_json (a_json: SIMPLE_JSON_OBJECT)
			-- Load from JSON.
		require
			has_id: a_json.has_key ("id")
		local
			idx: INTEGER
		do
			if attached a_json.string_item ("id") as l_id then
				id := l_id
			else
				id := "unknown"
			end
			if attached a_json.optional_string ("title") as t then
				title := t
			else
				title := id
			end

			create controls.make (10)
			create api_bindings.make (5)

			if attached a_json.array_item ("controls") as l_controls then
				from idx := 1 until idx > l_controls.count loop
					if attached l_controls.item (idx).as_object as l_obj then
						controls.extend (create {GUI_FINAL_CONTROL}.make_from_json (l_obj))
					end
					idx := idx + 1
				end
			end

			if attached a_json.array_item ("api_bindings") as l_bindings then
				from idx := 1 until idx > l_bindings.count loop
					if attached l_bindings.item (idx).as_object as l_obj then
						api_bindings.extend (create {GUI_API_ENDPOINT}.make_from_json (l_obj))
					end
					idx := idx + 1
				end
			end
		end

	make_from_designer_screen (a_designer: GUI_DESIGNER_SCREEN)
			-- Convert from designer screen, stripping designer-only data.
		do
			id := a_designer.id
			title := a_designer.title
			create controls.make (a_designer.controls.count)
			create api_bindings.make (a_designer.api_bindings.count)

			-- Convert controls (strip notes, keep layout and properties)
			across a_designer.controls as ic loop
				controls.extend (create {GUI_FINAL_CONTROL}.make_from_designer_control (ic))
			end

			-- Copy API bindings directly
			across a_designer.api_bindings as ic loop
				api_bindings.extend (ic)
			end
		end

feature -- Access

	id: STRING_32
			-- Screen identifier.

	title: STRING_32
			-- Display title.

	controls: ARRAYED_LIST [GUI_FINAL_CONTROL]
			-- Controls on this screen.

	api_bindings: ARRAYED_LIST [GUI_API_ENDPOINT]
			-- API calls this screen makes.

feature -- Query

	control_by_id (a_id: STRING_32): detachable GUI_FINAL_CONTROL
			-- Find control by ID.
		do
			across controls as ic loop
				if ic.id.same_string (a_id) then
					Result := ic
				end
			end
		end

feature -- JSON Serialization

	to_json: SIMPLE_JSON_OBJECT
			-- Convert to JSON.
		local
			l_controls_arr, l_bindings_arr: SIMPLE_JSON_ARRAY
		do
			create Result.make
			Result.put_string (id, "id").do_nothing
			Result.put_string (title, "title").do_nothing

			create l_controls_arr.make
			across controls as ic loop
				l_controls_arr.add_object (ic.to_json).do_nothing
			end
			Result.put_array (l_controls_arr, "controls").do_nothing

			create l_bindings_arr.make
			across api_bindings as ic loop
				l_bindings_arr.add_object (ic.to_json).do_nothing
			end
			Result.put_array (l_bindings_arr, "api_bindings").do_nothing
		end

feature -- JSON Deserialization

	apply_json (a_json: SIMPLE_JSON_OBJECT)
			-- Apply JSON (not typically used).
		do
			-- Final specs are read-only
		end

feature -- Validation

	json_has_required_fields (a_json: SIMPLE_JSON_OBJECT): BOOLEAN
			-- Check required fields.
		do
			Result := a_json.has_key ("id")
		end

invariant
	id_not_empty: not id.is_empty

end
