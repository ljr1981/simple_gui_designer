note
	description: "Tests for GUI Designer"
	author: "Claude Code"
	date: "$Date$"
	revision: "$Revision$"

class
	TEST_GUI_DESIGNER

inherit
	TEST_SET_BASE

feature -- Tests: Control Type Validation

	test_is_valid_control_type_valid_types
			-- Test that known control types are recognized.
			-- Regression test: Previously used ARRAY.has which uses reference equality.
			-- Fixed to use `across ... some ... same_string`.
		local
			l_control: GUI_DESIGNER_CONTROL
		do
			create l_control.make ("test_btn", "button")
			assert ("button is valid", l_control.is_valid_control_type ("button"))
			assert ("text_field is valid", l_control.is_valid_control_type ("text_field"))
			assert ("heading is valid", l_control.is_valid_control_type ("heading"))
			assert ("card is valid", l_control.is_valid_control_type ("card"))
			assert ("tabs is valid", l_control.is_valid_control_type ("tabs"))
			assert ("dropdown is valid", l_control.is_valid_control_type ("dropdown"))
			assert ("label is valid", l_control.is_valid_control_type ("label"))
			assert ("table is valid", l_control.is_valid_control_type ("table"))
		end

	test_is_valid_control_type_invalid_types
			-- Test that unknown control types are rejected.
		local
			l_control: GUI_DESIGNER_CONTROL
		do
			create l_control.make ("test_btn", "button")
			assert ("xyz is invalid", not l_control.is_valid_control_type ("xyz"))
			assert ("unknown is invalid", not l_control.is_valid_control_type ("unknown"))
			assert ("empty is invalid", not l_control.is_valid_control_type (""))
		end

	test_is_valid_control_type_with_string_32
			-- Test that STRING_32 control types work correctly.
			-- This is the specific case that failed with ARRAY.has.
		local
			l_control: GUI_DESIGNER_CONTROL
			l_type: STRING_32
		do
			create l_control.make ("test_heading", "heading")
			create l_type.make_from_string ("heading")
			assert ("STRING_32 heading is valid", l_control.is_valid_control_type (l_type))
		end

feature -- Tests: Control Creation

	test_control_creation
			-- Test basic control creation.
		local
			l_control: GUI_DESIGNER_CONTROL
		do
			create l_control.make ("my_button", "button")
			assert_strings_equal ("id", "my_button", l_control.id.to_string_8)
			assert_strings_equal ("type", "button", l_control.control_type.to_string_8)
			assert ("row is 1", l_control.grid_row = 1)
			assert ("col is 1", l_control.grid_col = 1)
		end

feature -- Tests: JSON Loading (grid_row vs row key names)

	test_control_from_json_with_row_keys
			-- Test loading control with "row"/"col" key names.
		local
			l_control: GUI_DESIGNER_CONTROL
			l_json: SIMPLE_JSON_OBJECT
		do
			create l_json.make
			l_json.put_string ("btn1", "id").do_nothing
			l_json.put_string ("button", "type").do_nothing
			l_json.put_integer (3, "row").do_nothing
			l_json.put_integer (5, "col").do_nothing
			l_json.put_integer (4, "col_span").do_nothing
			create l_control.make_from_json (l_json)
			assert ("row loaded", l_control.grid_row = 3)
			assert ("col loaded", l_control.grid_col = 5)
			assert ("col_span loaded", l_control.col_span = 4)
		end

	test_control_from_json_with_grid_row_keys
			-- Test loading control with "grid_row"/"grid_col" key names.
			-- Regression test: Previously only supported "row"/"col".
		local
			l_control: GUI_DESIGNER_CONTROL
			l_json: SIMPLE_JSON_OBJECT
		do
			create l_json.make
			l_json.put_string ("btn2", "id").do_nothing
			l_json.put_string ("button", "type").do_nothing
			l_json.put_integer (2, "grid_row").do_nothing
			l_json.put_integer (7, "grid_col").do_nothing
			l_json.put_integer (6, "col_span").do_nothing
			create l_control.make_from_json (l_json)
			assert ("grid_row loaded", l_control.grid_row = 2)
			assert ("grid_col loaded", l_control.grid_col = 7)
			assert ("col_span loaded", l_control.col_span = 6)
		end

	test_control_is_container
			-- Test container type detection.
		local
			l_card, l_tabs, l_button: GUI_DESIGNER_CONTROL
		do
			create l_card.make ("my_card", "card")
			create l_tabs.make ("my_tabs", "tabs")
			create l_button.make ("my_btn", "button")
			assert ("card is container", l_card.is_container)
			assert ("tabs is container", l_tabs.is_container)
			assert ("button not container", not l_button.is_container)
		end

end
