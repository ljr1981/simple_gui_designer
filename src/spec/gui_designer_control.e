note
	description: "[
		Designer-time control specification.

		Full control state during design including:
		- Grid position (row, column, spans)
		- Control type and properties
		- User notes/annotations
		- Validation rules
		- Data bindings
		- Children controls (for containers like card, tabs)
		- Tab panels (for tabs control)
	]"
	author: "Claude Code"
	date: "$Date$"
	revision: "$Revision$"

class
	GUI_DESIGNER_CONTROL

inherit
	SIMPLE_JSON_SERIALIZABLE

create
	make,
	make_from_json

feature {NONE} -- Initialization

	make (a_id: STRING_32; a_type: STRING_32)
			-- Create control with ID and type.
		require
			id_not_empty: not a_id.is_empty
			type_valid: is_valid_control_type (a_type)
		do
			id := a_id
			control_type := a_type
			label := ""
			grid_row := 1
			grid_col := 1
			col_span := 3
			row_span := 1
			create properties.make (5)
			create validation_rules.make (0)
			create notes.make (0)
			create children.make (0)
			create tab_panels.make (0)
			-- Initialize default tab for tabs control
			if a_type.same_string ("tabs") then
				add_tab_panel ("Tab 1")
			end
		ensure
			id_set: id.same_string (a_id)
			type_set: control_type.same_string (a_type)
		end

	make_from_json (a_json: SIMPLE_JSON_OBJECT)
			-- Load from JSON.
		require
			has_required: a_json.has_all_keys (<<"id", "type">>)
		local
			l_arr: SIMPLE_JSON_ARRAY
			idx: INTEGER
		do
			if attached a_json.string_item ("id") as l_id then
				id := l_id
			else
				id := "unknown"
			end
			if attached a_json.string_item ("type") as t then
				control_type := t
			else
				control_type := "label"
			end
			if attached a_json.optional_string ("label") as l then
				label := l
			else
				label := ""
			end

			-- Support both "grid_row"/"grid_col" and "row"/"col" key names
			if a_json.has_key ("grid_row") then
				grid_row := a_json.optional_integer ("grid_row", 1).to_integer_32
			else
				grid_row := a_json.optional_integer ("row", 1).to_integer_32
			end
			if a_json.has_key ("grid_col") then
				grid_col := a_json.optional_integer ("grid_col", 1).to_integer_32
			else
				grid_col := a_json.optional_integer ("col", 1).to_integer_32
			end
			col_span := a_json.optional_integer ("col_span", 3).to_integer_32
			row_span := a_json.optional_integer ("row_span", 1).to_integer_32

			data_binding := a_json.optional_string ("data_binding")

			create properties.make (5)
			create validation_rules.make (0)
			create notes.make (0)
			create children.make (0)
			create tab_panels.make (0)

			-- Load properties
			if attached a_json.object_item ("properties") as l_props then
				across l_props.keys as k loop
					if attached l_props.string_item (k) as v then
						properties.force (v, k)
					end
				end
			end

			-- Load validation rules
			if attached a_json.array_item ("validation") as l_validation then
				l_arr := l_validation
				from idx := 1 until idx > l_arr.count loop
					if l_arr.item (idx).is_string then
						validation_rules.extend (l_arr.item (idx).as_string_32)
					end
					idx := idx + 1
				end
			end

			-- Load notes
			if attached a_json.array_item ("notes") as l_notes then
				l_arr := l_notes
				from idx := 1 until idx > l_arr.count loop
					if l_arr.item (idx).is_string then
						notes.extend (l_arr.item (idx).as_string_32)
					end
					idx := idx + 1
				end
			end

			-- Load children (for container controls)
			if attached a_json.array_item ("children") as l_children then
				l_arr := l_children
				from idx := 1 until idx > l_arr.count loop
					if l_arr.item (idx).is_object and then attached l_arr.item (idx).as_object as l_child_json then
						if l_child_json.has_all_keys (<<"id", "type">>) then
							children.extend (create {GUI_DESIGNER_CONTROL}.make_from_json (l_child_json))
						end
					end
					idx := idx + 1
				end
			end

			-- Load tab panels (for tabs control)
			if attached a_json.array_item ("tab_panels") as l_panels then
				l_arr := l_panels
				from idx := 1 until idx > l_arr.count loop
					if l_arr.item (idx).is_object and then attached l_arr.item (idx).as_object as l_panel_json then
						load_tab_panel_from_json (l_panel_json)
					end
					idx := idx + 1
				end
			end

			-- Initialize default tab if tabs control has no panels
			if control_type.same_string ("tabs") and tab_panels.is_empty then
				add_tab_panel ("Tab 1")
			end
		end

	load_tab_panel_from_json (a_json: SIMPLE_JSON_OBJECT)
			-- Load a single tab panel from JSON.
		local
			l_panel: GUI_DESIGNER_TAB_PANEL
			l_children_arr: SIMPLE_JSON_ARRAY
			l_idx: INTEGER
		do
			if attached a_json.string_item ("name") as l_name then
				create l_panel.make (l_name)
				if attached a_json.array_item ("children") as l_children then
					l_children_arr := l_children
					from l_idx := 1 until l_idx > l_children_arr.count loop
						if l_children_arr.item (l_idx).is_object and then
						   attached l_children_arr.item (l_idx).as_object as l_child_json then
							if l_child_json.has_all_keys (<<"id", "type">>) then
								l_panel.children.extend (create {GUI_DESIGNER_CONTROL}.make_from_json (l_child_json))
							end
						end
						l_idx := l_idx + 1
					end
				end
				tab_panels.extend (l_panel)
			end
		end

feature -- Access

	id: STRING_32
			-- Unique control identifier.

	control_type: STRING_32
			-- Type of control (text_field, button, dropdown, etc.).

	label: STRING_32
			-- Display label.

	grid_row: INTEGER
			-- Row position in 12-column grid (1-based).

	grid_col: INTEGER
			-- Column position (1-12).

	col_span: INTEGER
			-- Number of columns to span (1-12).

	row_span: INTEGER
			-- Number of rows to span.

	properties: HASH_TABLE [STRING_32, STRING_32]
			-- Type-specific properties (placeholder, options, etc.).

	validation_rules: ARRAYED_LIST [STRING_32]
			-- Validation rules (required, min_length:5, pattern:email, etc.).

	data_binding: detachable STRING_32
			-- Data field this control binds to (e.g., "todo.title").

	notes: ARRAYED_LIST [STRING_32]
			-- User annotations for this control.

	children: ARRAYED_LIST [GUI_DESIGNER_CONTROL]
			-- Child controls (for container controls like card).

	tab_panels: ARRAYED_LIST [GUI_DESIGNER_TAB_PANEL]
			-- Tab panels (for tabs control only).

	active_tab_index: INTEGER
			-- Currently active tab (1-based, for tabs control).

feature -- Container Query

	is_container: BOOLEAN
			-- Is this a container control that can hold children?
		do
			Result := across container_types as t some t.same_string (control_type) end
		end

	is_tabs: BOOLEAN
			-- Is this a tabs control?
		do
			Result := control_type.same_string ("tabs")
		end

	is_card: BOOLEAN
			-- Is this a card control?
		do
			Result := control_type.same_string ("card")
		end

	container_types: ARRAY [STRING]
			-- Control types that can contain children.
		once
			Result := <<"container", "card", "tabs", "accordion", "row", "column">>
		end

	has_children: BOOLEAN
			-- Does this container have any children?
		do
			if is_tabs then
				Result := across tab_panels as p some not p.children.is_empty end
			else
				Result := not children.is_empty
			end
		end

	child_count: INTEGER
			-- Total number of children.
		do
			if is_tabs then
				across tab_panels as p loop
					Result := Result + p.children.count
				end
			else
				Result := children.count
			end
		end

	child_by_id (a_id: STRING_32): detachable GUI_DESIGNER_CONTROL
			-- Find child control by ID (searches recursively).
		do
			if is_tabs then
				across tab_panels as p until Result /= Void loop
					Result := p.child_by_id (a_id)
				end
			else
				across children as c until Result /= Void loop
					if c.id.same_string (a_id) then
						Result := c
					elseif c.is_container then
						Result := c.child_by_id (a_id)
					end
				end
			end
		end

	active_tab_panel: detachable GUI_DESIGNER_TAB_PANEL
			-- Currently active tab panel.
		require
			is_tabs: is_tabs
		do
			if active_tab_index >= 1 and active_tab_index <= tab_panels.count then
				Result := tab_panels.i_th (active_tab_index)
			elseif not tab_panels.is_empty then
				Result := tab_panels.first
			end
		end

feature -- Query

	is_required: BOOLEAN
			-- Is this control required?
		do
			Result := across validation_rules as r some r.same_string ("required") end
		end

	property (a_key: STRING_32): detachable STRING_32
			-- Get property value.
		do
			Result := properties.item (a_key)
		end

	grid_end_col: INTEGER
			-- Last column this control occupies.
		do
			Result := grid_col + col_span - 1
		ensure
			valid: Result >= grid_col and Result <= 24
		end

	grid_end_row: INTEGER
			-- Last row this control occupies.
		do
			Result := grid_row + row_span - 1
		ensure
			valid: Result >= grid_row
		end

feature -- Status Report

	is_valid_control_type (a_type: STRING_32): BOOLEAN
			-- Is this a known control type?
		do
			Result := across valid_control_types as t some t.same_string (a_type) end
		end

	valid_control_types: ARRAY [STRING]
			-- All valid control types.
		once
			Result := <<
				-- Layout
				"container", "row", "column", "card", "tabs", "accordion",
				-- Input
				"text_field", "text_area", "number_field", "date_picker",
				"dropdown", "checkbox", "radio_group", "toggle", "file_upload",
				-- Display
				"label", "heading", "image", "icon", "badge", "progress_bar",
				"table", "list",
				-- Actions
				"button", "link", "icon_button", "button_group",
				-- Feedback
				"alert", "modal", "tooltip",
				-- Navigation
				"nav_menu", "breadcrumbs", "pagination", "sidebar"
			>>
		end

feature -- Modification

	set_label (a_label: STRING_32)
			-- Set display label.
		do
			label := a_label
		ensure
			label_set: label.same_string (a_label)
		end

	set_grid_position (a_row, a_col: INTEGER)
			-- Set grid position.
		require
			valid_row: a_row >= 1
			valid_col: a_col >= 1 and a_col <= 24
		do
			grid_row := a_row
			grid_col := a_col
		ensure
			row_set: grid_row = a_row
			col_set: grid_col = a_col
		end

	set_grid_row (a_row: INTEGER)
			-- Set grid row.
		require
			valid_row: a_row >= 1
		do
			grid_row := a_row
		ensure
			row_set: grid_row = a_row
		end

	set_grid_col (a_col: INTEGER)
			-- Set grid column.
		require
			valid_col: a_col >= 1 and a_col <= 24
		do
			grid_col := a_col
		ensure
			col_set: grid_col = a_col
		end

	set_col_span (a_span: INTEGER)
			-- Set column span.
		require
			valid_span: a_span >= 1 and a_span <= 24
		do
			col_span := a_span
		ensure
			span_set: col_span = a_span
		end

	set_span (a_col_span, a_row_span: INTEGER)
			-- Set column and row span.
		require
			valid_col_span: a_col_span >= 1 and a_col_span <= 24
			valid_row_span: a_row_span >= 1
		do
			col_span := a_col_span
			row_span := a_row_span
		ensure
			col_span_set: col_span = a_col_span
			row_span_set: row_span = a_row_span
		end

	set_property (a_key, a_value: STRING_32)
			-- Set type-specific property.
		require
			key_not_empty: not a_key.is_empty
		do
			properties.force (a_value, a_key)
		ensure
			set: properties.item (a_key) ~ a_value
		end

	set_data_binding (a_binding: STRING_32)
			-- Set data binding.
		do
			data_binding := a_binding
		ensure
			set: attached data_binding as b and then b.same_string (a_binding)
		end

	add_validation_rule (a_rule: STRING_32)
			-- Add validation rule.
		require
			not_empty: not a_rule.is_empty
		do
			validation_rules.extend (a_rule)
		end

	add_note (a_note: STRING_32)
			-- Add user note.
		require
			not_empty: not a_note.is_empty
		do
			notes.extend (a_note)
		end

	set_notes_from_string (a_text: STRING_32)
			-- Replace notes with lines from text.
		local
			l_lines: LIST [STRING_32]
		do
			notes.wipe_out
			l_lines := a_text.split ('%N')
			across l_lines as al_line loop
				if not al_line.is_empty then
					notes.extend (al_line)
				end
			end
		end

feature -- Container Modification

	add_child (a_control: GUI_DESIGNER_CONTROL)
			-- Add child control to this container.
		require
			is_container: is_container
			not_tabs: not is_tabs -- Use add_child_to_tab for tabs
		do
			children.extend (a_control)
		ensure
			added: children.has (a_control)
		end

	remove_child (a_id: STRING_32)
			-- Remove child control by ID.
		require
			is_container: is_container
		local
			l_found: BOOLEAN
		do
			if is_tabs then
				across tab_panels as p until l_found loop
					across p.children as c loop
						if c.id.same_string (a_id) then
							p.children.prune (c)
							l_found := True
						end
					end
				end
			else
				across children as c loop
					if c.id.same_string (a_id) then
						children.prune (c)
					end
				end
			end
		end

	add_child_to_tab (a_control: GUI_DESIGNER_CONTROL; a_tab_index: INTEGER)
			-- Add child control to specific tab panel.
		require
			is_tabs: is_tabs
			valid_index: a_tab_index >= 1 and a_tab_index <= tab_panels.count
		do
			tab_panels.i_th (a_tab_index).children.extend (a_control)
		end

	add_tab_panel (a_name: STRING_32)
			-- Add new tab panel.
		require
			is_tabs: is_tabs or control_type.same_string ("tabs")
		local
			l_panel: GUI_DESIGNER_TAB_PANEL
		do
			create l_panel.make (a_name)
			tab_panels.extend (l_panel)
			if active_tab_index = 0 then
				active_tab_index := 1
			end
		ensure
			added: tab_panels.count = old tab_panels.count + 1
		end

	remove_tab_panel (a_index: INTEGER)
			-- Remove tab panel by index.
		require
			is_tabs: is_tabs
			valid_index: a_index >= 1 and a_index <= tab_panels.count
			not_last: tab_panels.count > 1
		do
			tab_panels.go_i_th (a_index)
			tab_panels.remove
			if active_tab_index > tab_panels.count then
				active_tab_index := tab_panels.count
			end
		ensure
			removed: tab_panels.count = old tab_panels.count - 1
		end

	set_active_tab (a_index: INTEGER)
			-- Set active tab index.
		require
			is_tabs: is_tabs
			valid_index: a_index >= 1 and a_index <= tab_panels.count
		do
			active_tab_index := a_index
		ensure
			set: active_tab_index = a_index
		end

	rename_tab_panel (a_index: INTEGER; a_new_name: STRING_32)
			-- Rename tab panel.
		require
			is_tabs: is_tabs
			valid_index: a_index >= 1 and a_index <= tab_panels.count
		do
			tab_panels.i_th (a_index).set_name (a_new_name)
		end

feature -- JSON Serialization

	to_json: SIMPLE_JSON_OBJECT
			-- Convert to JSON.
		local
			l_props: SIMPLE_JSON_OBJECT
			l_validation_arr, l_notes_arr, l_children_arr, l_panels_arr: SIMPLE_JSON_ARRAY
		do
			create Result.make
			Result.put_string (id, "id").do_nothing
			Result.put_string (control_type, "type").do_nothing
			Result.put_string (label, "label").do_nothing
			Result.put_integer (grid_row, "row").do_nothing
			Result.put_integer (grid_col, "col").do_nothing
			Result.put_integer (col_span, "col_span").do_nothing
			Result.put_integer (row_span, "row_span").do_nothing

			if attached data_binding as db then
				Result.put_string (db, "data_binding").do_nothing
			end

			-- Properties
			create l_props.make
			across properties as p loop
				l_props.put_string (p, @p.key).do_nothing
			end
			Result.put_object (l_props, "properties").do_nothing

			-- Validation
			create l_validation_arr.make
			across validation_rules as r loop
				l_validation_arr.add_string (r).do_nothing
			end
			Result.put_array (l_validation_arr, "validation").do_nothing

			-- Notes
			create l_notes_arr.make
			across notes as n loop
				l_notes_arr.add_string (n).do_nothing
			end
			Result.put_array (l_notes_arr, "notes").do_nothing

			-- Children (for non-tabs containers)
			if is_container and not is_tabs and not children.is_empty then
				create l_children_arr.make
				across children as c loop
					l_children_arr.add_object (c.to_json).do_nothing
				end
				Result.put_array (l_children_arr, "children").do_nothing
			end

			-- Tab panels (for tabs control)
			if is_tabs and not tab_panels.is_empty then
				create l_panels_arr.make
				across tab_panels as p loop
					l_panels_arr.add_object (p.to_json).do_nothing
				end
				Result.put_array (l_panels_arr, "tab_panels").do_nothing
				Result.put_integer (active_tab_index, "active_tab").do_nothing
			end
		end

feature -- JSON Deserialization

	apply_json (a_json: SIMPLE_JSON_OBJECT)
			-- Apply JSON updates.
		do
			if attached a_json.optional_string ("label") as l then
				label := l
			end
			if a_json.has_key ("row") then
				grid_row := a_json.integer_32_item ("row")
			end
			if a_json.has_key ("col") then
				grid_col := a_json.integer_32_item ("col")
			end
			if a_json.has_key ("col_span") then
				col_span := a_json.integer_32_item ("col_span")
			end
			if a_json.has_key ("row_span") then
				row_span := a_json.integer_32_item ("row_span")
			end
		end

feature -- Validation

	json_has_required_fields (a_json: SIMPLE_JSON_OBJECT): BOOLEAN
			-- Check required fields.
		do
			Result := a_json.has_all_keys (<<"id", "type">>)
		end

invariant
	id_not_empty: not id.is_empty
	valid_type: is_valid_control_type (control_type)
	valid_grid_row: grid_row >= 1
	valid_grid_col: grid_col >= 1 and grid_col <= 24
	valid_col_span: col_span >= 1 and col_span <= 24
	valid_row_span: row_span >= 1
	properties_attached: properties /= Void

end
