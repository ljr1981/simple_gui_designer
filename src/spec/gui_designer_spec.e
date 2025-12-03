note
	description: "[
		Designer-time GUI specification.

		This is the WORKING spec used during design iteration. It includes:
		- All the visual layout information
		- User notes/annotations per control
		- Revision tracking
		- AI suggestions
		- Uncommitted changes

		This is NOT the final production spec. Use GUI_FINAL_SPEC for that.
	]"
	author: "Claude Code"
	date: "$Date$"
	revision: "$Revision$"

class
	GUI_DESIGNER_SPEC

inherit
	SIMPLE_JSON_SERIALIZABLE

create
	make,
	make_from_json

feature {NONE} -- Initialization

	make (a_app_name: STRING_32)
			-- Create empty designer spec.
		require
			name_not_empty: not a_app_name.is_empty
		do
			app_name := a_app_name
			version := 1
			create screens.make (5)
			create global_notes.make (0)
			create ai_suggestions.make (0)
			is_finalized := False
		ensure
			name_set: app_name.same_string (a_app_name)
			version_one: version = 1
			not_finalized: not is_finalized
		end

	make_from_json (a_json: SIMPLE_JSON_OBJECT)
			-- Load from JSON.
			-- Accepts both "app" and "app_name" keys for compatibility.
		require
			has_app: a_json.has_key ("app") or a_json.has_key ("app_name")
		local
			l_arr: SIMPLE_JSON_ARRAY
			i: INTEGER
		do
			if attached a_json.string_item ("app_name") as al_name then
				app_name := al_name
			elseif attached a_json.string_item ("app") as al_name then
				app_name := al_name
			else
				app_name := "unnamed"
			end
			version := a_json.optional_integer ("version", 1).to_integer_32
			is_finalized := a_json.optional_boolean ("finalized", False)

			create screens.make (5)
			create global_notes.make (0)
			create ai_suggestions.make (0)

			-- Load screens
			if attached a_json.array_item ("screens") as l_screens then
				l_arr := l_screens
				from i := 1 until i > l_arr.count loop
					if attached l_arr.item (i).as_object as l_obj then
						screens.extend (create {GUI_DESIGNER_SCREEN}.make_from_json (l_obj))
					end
					i := i + 1
				end
			end

			-- Load notes
			if attached a_json.array_item ("global_notes") as l_notes then
				l_arr := l_notes
				from i := 1 until i > l_arr.count loop
					if l_arr.item (i).is_string then
						global_notes.extend (l_arr.item (i).as_string_32)
					end
					i := i + 1
				end
			end

			-- Load AI suggestions
			if attached a_json.array_item ("ai_suggestions") as l_suggestions then
				l_arr := l_suggestions
				from i := 1 until i > l_arr.count loop
					if l_arr.item (i).is_string then
						ai_suggestions.extend (l_arr.item (i).as_string_32)
					end
					i := i + 1
				end
			end
		end

feature -- Access

	app_name: STRING_32
			-- Application name.

	version: INTEGER
			-- Revision number (increments on each submit).

	screens: ARRAYED_LIST [GUI_DESIGNER_SCREEN]
			-- All screens in design.

	global_notes: ARRAYED_LIST [STRING_32]
			-- User notes at app level.

	ai_suggestions: ARRAYED_LIST [STRING_32]
			-- AI-generated suggestions for improvement.

	is_finalized: BOOLEAN
			-- Has user approved this spec as final?

feature -- Query

	screen_by_id (a_id: STRING_32): detachable GUI_DESIGNER_SCREEN
			-- Find screen by ID.
		do
			across screens as ic loop
				if ic.id.same_string (a_id) then
					Result := ic
				end
			end
		end

	screen_ids: ARRAYED_LIST [STRING_32]
			-- List of all screen IDs.
		do
			create Result.make (screens.count)
			across screens as ic loop
				Result.extend (ic.id)
			end
		end

feature -- Modification

	add_screen (a_screen: GUI_DESIGNER_SCREEN)
			-- Add screen.
		require
			unique_id: screen_by_id (a_screen.id) = Void
		do
			screens.extend (a_screen)
		ensure
			added: screens.has (a_screen)
		end

	remove_screen (a_id: STRING_32)
			-- Remove screen by ID.
		local
			l_idx: INTEGER
		do
			from
				l_idx := 1
			until
				l_idx > screens.count
			loop
				if screens.i_th (l_idx).id.same_string (a_id) then
					screens.go_i_th (l_idx)
					screens.remove
				else
					l_idx := l_idx + 1
				end
			end
		end

	add_global_note (a_note: STRING_32)
			-- Add user note.
		require
			not_empty: not a_note.is_empty
		do
			global_notes.extend (a_note)
		end

	add_ai_suggestion (a_suggestion: STRING_32)
			-- Add AI suggestion.
		require
			not_empty: not a_suggestion.is_empty
		do
			ai_suggestions.extend (a_suggestion)
		end

	clear_ai_suggestions
			-- Clear all AI suggestions (after user reviews them).
		do
			ai_suggestions.wipe_out
		end

	increment_version
			-- Bump version number (called on submit).
		do
			version := version + 1
		ensure
			incremented: version = old version + 1
		end

	mark_finalized
			-- Mark spec as approved/final.
		do
			is_finalized := True
		ensure
			finalized: is_finalized
		end

feature -- Conversion

	to_final_spec: GUI_FINAL_SPEC
			-- Convert to production-ready final spec.
		require
			is_finalized: is_finalized
		do
			create Result.make_from_designer_spec (Current)
		ensure
			result_attached: Result /= Void
		end

feature -- JSON Serialization

	to_json: SIMPLE_JSON_OBJECT
			-- Convert to JSON for saving/sending.
		local
			l_screens_arr, l_notes_arr, l_suggestions_arr: SIMPLE_JSON_ARRAY
		do
			create Result.make
			Result.put_string (app_name, "app").do_nothing
			Result.put_integer (version, "version").do_nothing
			Result.put_boolean (is_finalized, "finalized").do_nothing

			-- Screens
			create l_screens_arr.make
			across screens as ic loop
				l_screens_arr.add_object (ic.to_json).do_nothing
			end
			Result.put_array (l_screens_arr, "screens").do_nothing

			-- Notes
			create l_notes_arr.make
			across global_notes as ic loop
				l_notes_arr.add_string (ic).do_nothing
			end
			Result.put_array (l_notes_arr, "global_notes").do_nothing

			-- AI suggestions
			create l_suggestions_arr.make
			across ai_suggestions as ic loop
				l_suggestions_arr.add_string (ic).do_nothing
			end
			Result.put_array (l_suggestions_arr, "ai_suggestions").do_nothing
		end

feature -- JSON Deserialization

	apply_json (a_json: SIMPLE_JSON_OBJECT)
			-- Apply changes from JSON (merge).
		do
			if attached a_json.string_item ("app") as n then
				app_name := n
			end
			-- Additional merge logic as needed
		end

feature -- Validation

	json_has_required_fields (a_json: SIMPLE_JSON_OBJECT): BOOLEAN
			-- Check required fields.
		do
			Result := a_json.has_key ("app") or a_json.has_key ("app_name")
		end

invariant
	app_name_not_empty: not app_name.is_empty
	version_positive: version >= 1
	screens_attached: screens /= Void

end
