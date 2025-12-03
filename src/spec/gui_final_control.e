note
	description: "[
		Final production-ready control specification.

		Clean version for consumption by target application.
		Contains only what's needed to render and wire up the control.
	]"
	author: "Claude Code"
	date: "$Date$"
	revision: "$Revision$"

class
	GUI_FINAL_CONTROL

inherit
	SIMPLE_JSON_SERIALIZABLE

create
	make,
	make_from_json,
	make_from_designer_control

feature {NONE} -- Initialization

	make (a_id, a_type: STRING_32)
			-- Create control.
		require
			id_not_empty: not a_id.is_empty
			type_not_empty: not a_type.is_empty
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

			grid_row := a_json.optional_integer ("row", 1).to_integer_32
			grid_col := a_json.optional_integer ("col", 1).to_integer_32
			col_span := a_json.optional_integer ("col_span", 3).to_integer_32
			row_span := a_json.optional_integer ("row_span", 1).to_integer_32

			data_binding := a_json.optional_string ("data_binding")

			create properties.make (5)
			create validation_rules.make (0)

			if attached a_json.object_item ("properties") as l_props then
				across l_props.keys as k loop
					if attached l_props.string_item (k) as v then
						properties.force (v, k)
					end
				end
			end

			if attached a_json.array_item ("validation") as l_validation then
				l_arr := l_validation
				from idx := 1 until idx > l_arr.count loop
					if l_arr.item (idx).is_string then
						validation_rules.extend (l_arr.item (idx).as_string_32)
					end
					idx := idx + 1
				end
			end
		end

	make_from_designer_control (a_designer: GUI_DESIGNER_CONTROL)
			-- Convert from designer control, stripping notes.
		do
			id := a_designer.id
			control_type := a_designer.control_type
			label := a_designer.label
			grid_row := a_designer.grid_row
			grid_col := a_designer.grid_col
			col_span := a_designer.col_span
			row_span := a_designer.row_span
			data_binding := a_designer.data_binding

			-- Copy properties
			create properties.make (a_designer.properties.count)
			across a_designer.properties as p loop
				properties.force (p, @p.key)
			end

			-- Copy validation rules
			create validation_rules.make (a_designer.validation_rules.count)
			across a_designer.validation_rules as r loop
				validation_rules.extend (r)
			end

			-- Notes are NOT copied - they're designer-only
		end

feature -- Access

	id: STRING_32
			-- Control identifier.

	control_type: STRING_32
			-- Type of control.

	label: STRING_32
			-- Display label.

	grid_row: INTEGER
			-- Row in grid.

	grid_col: INTEGER
			-- Column in grid (1-12).

	col_span: INTEGER
			-- Columns to span.

	row_span: INTEGER
			-- Rows to span.

	properties: HASH_TABLE [STRING_32, STRING_32]
			-- Type-specific properties.

	validation_rules: ARRAYED_LIST [STRING_32]
			-- Validation rules.

	data_binding: detachable STRING_32
			-- Data field binding.

feature -- Query

	property (a_key: STRING_32): detachable STRING_32
			-- Get property.
		do
			Result := properties.item (a_key)
		end

	is_required: BOOLEAN
			-- Is required validation set?
		do
			Result := across validation_rules as r some r.same_string ("required") end
		end

feature -- JSON Serialization

	to_json: SIMPLE_JSON_OBJECT
			-- Convert to JSON.
		local
			l_props: SIMPLE_JSON_OBJECT
			l_validation_arr: SIMPLE_JSON_ARRAY
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

			create l_props.make
			across properties as p loop
				l_props.put_string (p, @p.key).do_nothing
			end
			Result.put_object (l_props, "properties").do_nothing

			create l_validation_arr.make
			across validation_rules as r loop
				l_validation_arr.add_string (r).do_nothing
			end
			Result.put_array (l_validation_arr, "validation").do_nothing
		end

feature -- JSON Deserialization

	apply_json (a_json: SIMPLE_JSON_OBJECT)
			-- Apply JSON (not typically used).
		do
			-- Final controls are read-only
		end

feature -- Validation

	json_has_required_fields (a_json: SIMPLE_JSON_OBJECT): BOOLEAN
			-- Check required fields.
		do
			Result := a_json.has_all_keys (<<"id", "type">>)
		end

invariant
	id_not_empty: not id.is_empty
	type_not_empty: not control_type.is_empty

end
