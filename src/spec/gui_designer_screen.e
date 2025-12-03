note
	description: "[
		Designer-time screen specification.

		Contains the full working state of a screen during design:
		- Controls with grid positions
		- User notes per control
		- Pending changes
		- AI suggestions for this screen
	]"
	author: "Claude Code"
	date: "$Date$"
	revision: "$Revision$"

class
	GUI_DESIGNER_SCREEN

inherit
	SIMPLE_JSON_SERIALIZABLE

create
	make,
	make_from_json

feature {NONE} -- Initialization

	make (a_id: STRING_32; a_title: STRING_32)
			-- Create new screen.
		require
			id_not_empty: not a_id.is_empty
			title_not_empty: not a_title.is_empty
		do
			id := a_id
			title := a_title
			create controls.make (10)
			create notes.make (0)
			create api_bindings.make (5)
		ensure
			id_set: id.same_string (a_id)
			title_set: title.same_string (a_title)
		end

	make_from_json (a_json: SIMPLE_JSON_OBJECT)
			-- Load from JSON.
		require
			has_id: a_json.has_key ("id")
		local
			l_arr: SIMPLE_JSON_ARRAY
			i: INTEGER
		do
			if attached a_json.string_item ("id") as l_id then
				id := l_id
			else
				id := "unknown"
			end
			if attached a_json.string_item ("title") as t then
				title := t
			else
				title := id
			end

			create controls.make (10)
			create notes.make (0)
			create api_bindings.make (5)

			-- Load controls
			if attached a_json.array_item ("controls") as l_controls then
				l_arr := l_controls
				from i := 1 until i > l_arr.count loop
					if attached l_arr.item (i).as_object as l_obj then
						controls.extend (create {GUI_DESIGNER_CONTROL}.make_from_json (l_obj))
					end
					i := i + 1
				end
			end

			-- Load notes
			if attached a_json.array_item ("notes") as l_notes then
				l_arr := l_notes
				from i := 1 until i > l_arr.count loop
					if l_arr.item (i).is_string then
						notes.extend (l_arr.item (i).as_string_32)
					end
					i := i + 1
				end
			end

			-- Load API bindings
			if attached a_json.array_item ("api_bindings") as l_bindings then
				l_arr := l_bindings
				from i := 1 until i > l_arr.count loop
					if attached l_arr.item (i).as_object as l_obj then
						api_bindings.extend (create {GUI_API_ENDPOINT}.make_from_json (l_obj))
					end
					i := i + 1
				end
			end
		end

feature -- Access

	id: STRING_32
			-- Unique screen identifier.

	title: STRING_32
			-- Display title.

	controls: ARRAYED_LIST [GUI_DESIGNER_CONTROL]
			-- All controls on this screen.

	notes: ARRAYED_LIST [STRING_32]
			-- User notes for this screen.

	api_bindings: ARRAYED_LIST [GUI_API_ENDPOINT]
			-- API calls this screen makes.

feature -- Query

	control_by_id (a_id: STRING_32): detachable GUI_DESIGNER_CONTROL
			-- Find control by ID (searches recursively into containers).
		do
			across controls as ic until Result /= Void loop
				if ic.id.same_string (a_id) then
					Result := ic
				elseif ic.is_container then
					-- Search inside container children
					Result := ic.child_by_id (a_id)
				end
			end
		end

	controls_at_row (a_row: INTEGER): ARRAYED_LIST [GUI_DESIGNER_CONTROL]
			-- All controls in specified grid row.
		do
			create Result.make (6)
			across controls as ic loop
				if ic.grid_row = a_row then
					Result.extend (ic)
				end
			end
		end

	row_count: INTEGER
			-- Number of rows used.
		do
			across controls as ic loop
				if ic.grid_row + ic.row_span - 1 > Result then
					Result := ic.grid_row + ic.row_span - 1
				end
			end
		end

feature -- Modification

	add_control (a_control: GUI_DESIGNER_CONTROL)
			-- Add control to screen.
		require
			control_attached: a_control /= Void
			unique_id: control_by_id (a_control.id) = Void
		do
			controls.extend (a_control)
		ensure
			added: controls.has (a_control)
		end

	remove_control (a_id: STRING_32)
			-- Remove control by ID.
		local
			l_idx: INTEGER
		do
			from
				l_idx := 1
			until
				l_idx > controls.count
			loop
				if controls.i_th (l_idx).id.same_string (a_id) then
					controls.go_i_th (l_idx)
					controls.remove
				else
					l_idx := l_idx + 1
				end
			end
		end

	set_title (a_title: STRING_32)
			-- Update title.
		require
			not_empty: not a_title.is_empty
		do
			title := a_title
		ensure
			title_set: title.same_string (a_title)
		end

	add_note (a_note: STRING_32)
			-- Add user note.
		require
			not_empty: not a_note.is_empty
		do
			notes.extend (a_note)
		end

	add_api_binding (a_endpoint: GUI_API_ENDPOINT)
			-- Add API binding.
		require
			endpoint_attached: a_endpoint /= Void
		do
			api_bindings.extend (a_endpoint)
		end

feature -- JSON Serialization

	to_json: SIMPLE_JSON_OBJECT
			-- Convert to JSON.
		local
			l_controls_arr, l_notes_arr, l_bindings_arr: SIMPLE_JSON_ARRAY
		do
			create Result.make
			Result.put_string (id, "id").do_nothing
			Result.put_string (title, "title").do_nothing

			-- Controls
			create l_controls_arr.make
			across controls as ic loop
				l_controls_arr.add_object (ic.to_json).do_nothing
			end
			Result.put_array (l_controls_arr, "controls").do_nothing

			-- Notes
			create l_notes_arr.make
			across notes as ic loop
				l_notes_arr.add_string (ic).do_nothing
			end
			Result.put_array (l_notes_arr, "notes").do_nothing

			-- API bindings
			create l_bindings_arr.make
			across api_bindings as ic loop
				l_bindings_arr.add_object (ic.to_json).do_nothing
			end
			Result.put_array (l_bindings_arr, "api_bindings").do_nothing
		end

feature -- JSON Deserialization

	apply_json (a_json: SIMPLE_JSON_OBJECT)
			-- Apply JSON updates.
		do
			if attached a_json.string_item ("title") as t then
				title := t
			end
		end

feature -- Validation

	json_has_required_fields (a_json: SIMPLE_JSON_OBJECT): BOOLEAN
			-- Check required fields.
		do
			Result := a_json.has_key ("id")
		end

invariant
	id_not_empty: not id.is_empty
	title_not_empty: not title.is_empty
	controls_attached: controls /= Void

end
