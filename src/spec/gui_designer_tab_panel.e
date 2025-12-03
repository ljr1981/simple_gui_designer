note
	description: "[
		Tab panel for tabs control.

		Each tab panel has:
		- Name (displayed in tab header)
		- Children controls
	]"
	author: "Claude Code"
	date: "$Date$"
	revision: "$Revision$"

class
	GUI_DESIGNER_TAB_PANEL

create
	make

feature {NONE} -- Initialization

	make (a_name: STRING_32)
			-- Create tab panel with name.
		require
			name_not_empty: not a_name.is_empty
		do
			name := a_name
			create children.make (0)
		ensure
			name_set: name.same_string (a_name)
		end

feature -- Access

	name: STRING_32
			-- Tab name displayed in header.

	children: ARRAYED_LIST [GUI_DESIGNER_CONTROL]
			-- Controls in this tab panel.

feature -- Query

	child_by_id (a_id: STRING_32): detachable GUI_DESIGNER_CONTROL
			-- Find child control by ID (searches recursively).
		do
			across children as c until Result /= Void loop
				if c.id.same_string (a_id) then
					Result := c
				elseif c.is_container then
					Result := c.child_by_id (a_id)
				end
			end
		end

	has_child (a_id: STRING_32): BOOLEAN
			-- Does this panel contain control with ID?
		do
			Result := child_by_id (a_id) /= Void
		end

feature -- Modification

	set_name (a_name: STRING_32)
			-- Set tab name.
		require
			name_not_empty: not a_name.is_empty
		do
			name := a_name
		ensure
			name_set: name.same_string (a_name)
		end

	add_child (a_control: GUI_DESIGNER_CONTROL)
			-- Add child control.
		do
			children.extend (a_control)
		ensure
			added: children.has (a_control)
		end

	remove_child (a_id: STRING_32)
			-- Remove child control by ID.
		do
			across children as c loop
				if c.id.same_string (a_id) then
					children.prune (c)
				end
			end
		end

feature -- JSON Serialization

	to_json: SIMPLE_JSON_OBJECT
			-- Convert to JSON.
		local
			l_children_arr: SIMPLE_JSON_ARRAY
		do
			create Result.make
			Result.put_string (name, "name").do_nothing

			create l_children_arr.make
			across children as c loop
				l_children_arr.add_object (c.to_json).do_nothing
			end
			Result.put_array (l_children_arr, "children").do_nothing
		end

invariant
	name_not_empty: not name.is_empty
	children_attached: children /= Void

end
