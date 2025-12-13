note
	description: "Tests for SIMPLE_GUI_DESIGNER"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"
	testing: "covers"

class
	LIB_TESTS

inherit
	TEST_SET_BASE

feature -- Test: Designer Spec

	test_spec_make
			-- Test GUI designer spec creation.
		note
			testing: "covers/{GUI_DESIGNER_SPEC}.make"
		local
			spec: GUI_DESIGNER_SPEC
		do
			create spec.make ("my_app")
			assert_strings_equal ("app name", "my_app", spec.app_name)
		end

	test_spec_add_screen
			-- Test adding screen to spec.
		note
			testing: "covers/{GUI_DESIGNER_SPEC}.add_screen"
		local
			spec: GUI_DESIGNER_SPEC
			screen: GUI_DESIGNER_SCREEN
		do
			create spec.make ("test")
			create screen.make ("main", "Main Screen")
			spec.add_screen (screen)
			assert_integers_equal ("one screen", 1, spec.screens.count)
		end

feature -- Test: Designer Screen

	test_screen_make
			-- Test screen creation.
		note
			testing: "covers/{GUI_DESIGNER_SCREEN}.make"
		local
			screen: GUI_DESIGNER_SCREEN
		do
			create screen.make ("login", "Login Screen")
			assert_strings_equal ("id", "login", screen.id)
			assert_strings_equal ("title", "Login Screen", screen.title)
		end

feature -- Test: Final Spec

	test_final_spec_make
			-- Test final spec creation.
		note
			testing: "covers/{GUI_FINAL_SPEC}.make"
		local
			spec: GUI_FINAL_SPEC
		do
			create spec.make ("final_app")
			assert_strings_equal ("name", "final_app", spec.app_name)
		end

end
