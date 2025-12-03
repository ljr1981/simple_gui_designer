note
	description: "[
		HTML rendering features for GUI Designer using simple_htmx.

		Provides all HTML rendering functions:
		- render_canvas: Screen canvas with controls
		- render_control: Single control (simple, card, or tabs)
		- render_palette: Control palette sidebar
		- render_properties: Properties panel for selected control
		- render_screen_list: Screen list sidebar
		- render_spec_list: Spec list for index page

		Refactored to use simple_htmx fluent HTML builder.
	]"
	author: "Claude Code"
	date: "$Date$"
	revision: "$Revision$"

deferred class
	GDS_HTML_RENDERER

inherit
	GDS_SHARED_STATE

feature {GDS_HTML_RENDERER, GDS_STATIC_HTML} -- HTML Factory

	html: HTMX_FACTORY
			-- HTML element factory.
		once
			create Result
		end

feature -- Canvas Rendering

	render_canvas (a_screen: GUI_DESIGNER_SCREEN; a_spec_id: STRING_32): STRING
			-- Render screen as HTML canvas with 12-column grid.
		local
			l_row, l_max_row: INTEGER
			l_canvas, l_row_div: HTMX_DIV
		do
			l_canvas := html.div.class_ ("canvas-grid")
			l_canvas.containing (html.h3.text (s8 (a_screen.title))).do_nothing

			l_max_row := a_screen.row_count.max (6)
			from l_row := 1 until l_row > l_max_row loop
				l_row_div := html.div.class_ ("grid-row")
				across a_screen.controls_at_row (l_row) as l_control loop
					l_row_div.raw_html (render_control (l_control, a_spec_id, a_screen.id)).do_nothing
				end
				l_canvas.containing (l_row_div).do_nothing
				l_row := l_row + 1
			end
			Result := l_canvas.to_html_8
		end

feature -- Control Rendering

	render_control (a_control: GUI_DESIGNER_CONTROL; a_spec_id, a_screen_id: STRING_32): STRING
			-- Render single control HTML with click handler for properties.
			-- Handles containers (card, tabs) specially with drop zones.
		do
			if a_control.is_card then
				Result := render_card_control (a_control, a_spec_id, a_screen_id)
			elseif a_control.is_tabs then
				Result := render_tabs_control (a_control, a_spec_id, a_screen_id)
			else
				Result := render_simple_control (a_control, a_spec_id, a_screen_id)
			end
		end

	render_simple_control (a_control: GUI_DESIGNER_CONTROL; a_spec_id, a_screen_id: STRING_32): STRING
			-- Render non-container control.
		local
			l_div, l_label_span: HTMX_DIV
			l_props_url: STRING
		do
			l_props_url := "/htmx/properties/" + s8 (a_spec_id) + "/" + s8 (a_screen_id) + "/" + s8 (a_control.id)

			l_div := html.div
				.class_ ("control")
				.class_ ("col-" + a_control.col_span.out)
				.class_ ("type-" + s8 (a_control.control_type))
				.data ("id", s8 (a_control.id))
				.attr ("draggable", "true")
				.hx_get (l_props_url)
				.hx_target ("#properties")
				.hx_swap_inner_html
				.attr ("onclick", "event.stopPropagation(); document.querySelectorAll('.control.selected').forEach(c=>c.classList.remove('selected')); this.classList.add('selected');")

			create l_label_span.make
			l_label_span.class_ ("control-label").do_nothing
			if a_control.label.is_empty then
				l_label_span.text ("[" + s8 (a_control.id) + "]").do_nothing
			else
				l_label_span.text (s8 (a_control.label)).do_nothing
			end
			l_div.containing (l_label_span).do_nothing

			Result := l_div.to_html_8
		end

	render_card_control (a_control: GUI_DESIGNER_CONTROL; a_spec_id, a_screen_id: STRING_32): STRING
			-- Render card container with drop zone for children.
		local
			l_card, l_header, l_body: HTMX_DIV
			l_props_url: STRING
		do
			log_debug ("[RENDER] Card '" + s8 (a_control.id) + "' with " + a_control.children.count.out + " children")

			l_props_url := "/htmx/properties/" + s8 (a_spec_id) + "/" + s8 (a_screen_id) + "/" + s8 (a_control.id)

			l_card := html.div
				.class_ ("control")
				.class_ ("container-control")
				.class_ ("card-control")
				.class_ ("col-" + a_control.col_span.out)
				.data ("id", s8 (a_control.id))
				.data ("container", "card")
				.hx_get (l_props_url)
				.hx_target ("#properties")
				.hx_swap_inner_html
				.attr ("onclick", "event.stopPropagation(); document.querySelectorAll('.control.selected').forEach(c=>c.classList.remove('selected')); this.classList.add('selected');")

			-- Card header
			l_header := html.div.class_ ("card-header")
			if a_control.label.is_empty then
				l_header.text ("Card").do_nothing
			else
				l_header.text (s8 (a_control.label)).do_nothing
			end
			l_card.containing (l_header).do_nothing

			-- Card body (drop zone)
			l_body := html.div
				.class_ ("card-body")
				.class_ ("drop-zone")
				.data ("parent", s8 (a_control.id))

			if a_control.children.is_empty then
				l_body.containing (html.div.class_ ("drop-placeholder").text ("Drop controls here")).do_nothing
			else
				across a_control.children as l_child loop
					l_body.raw_html (render_control (l_child, a_spec_id, a_screen_id)).do_nothing
				end
			end
			l_card.containing (l_body).do_nothing

			Result := l_card.to_html_8
		end

	render_tabs_control (a_control: GUI_DESIGNER_CONTROL; a_spec_id, a_screen_id: STRING_32): STRING
			-- Render tabs container with tab headers and panels.
		local
			l_tabs, l_header_row, l_tab_header, l_add_btn, l_panel: HTMX_DIV
			l_tab_idx, l_active_idx: INTEGER
			l_props_url: STRING
		do
			log_debug ("[RENDER] Tabs '" + s8 (a_control.id) + "' with " + a_control.tab_panels.count.out + " panels")
			l_active_idx := a_control.active_tab_index.max (1)

			l_props_url := "/htmx/properties/" + s8 (a_spec_id) + "/" + s8 (a_screen_id) + "/" + s8 (a_control.id)

			l_tabs := html.div
				.class_ ("control")
				.class_ ("container-control")
				.class_ ("tabs-control")
				.class_ ("col-" + a_control.col_span.out)
				.data ("id", s8 (a_control.id))
				.data ("container", "tabs")
				.hx_get (l_props_url)
				.hx_target ("#properties")
				.hx_swap_inner_html
				.attr ("onclick", "event.stopPropagation(); document.querySelectorAll('.control.selected').forEach(c=>c.classList.remove('selected')); this.classList.add('selected');")

			-- Tab headers
			l_header_row := html.div.class_ ("tabs-header")
			l_tab_idx := 1
			across a_control.tab_panels as l_panel_data loop
				l_tab_header := html.div.class_ ("tab-header")
				if l_tab_idx = l_active_idx then
					l_tab_header.class_ ("active").do_nothing
				end
				l_tab_header
					.data ("tab-idx", l_tab_idx.out)
					.data ("tabs-id", s8 (a_control.id))
					.attr ("onclick", "switchTab(this, event)")
					.text (s8 (l_panel_data.name)).do_nothing
				l_header_row.containing (l_tab_header).do_nothing
				l_tab_idx := l_tab_idx + 1
			end
			-- Add tab button
			l_add_btn := html.div
				.class_ ("tab-add-btn")
				.attr ("onclick", "addTab('" + s8 (a_control.id) + "', event)")
				.text ("+")
			l_header_row.containing (l_add_btn).do_nothing
			l_tabs.containing (l_header_row).do_nothing

			-- Tab panels (only active one visible)
			l_tab_idx := 1
			across a_control.tab_panels as l_panel_data loop
				l_panel := html.div
					.class_ ("tab-panel")
					.class_ ("drop-zone")
				if l_tab_idx = l_active_idx then
					l_panel.class_ ("active").do_nothing
				end
				l_panel
					.data ("tab-idx", l_tab_idx.out)
					.data ("parent", s8 (a_control.id))
					.data ("panel-idx", l_tab_idx.out).do_nothing

				if l_panel_data.children.is_empty then
					l_panel.containing (html.div.class_ ("drop-placeholder").text ("Drop controls here")).do_nothing
				else
					across l_panel_data.children as l_child loop
						l_panel.raw_html (render_control (l_child, a_spec_id, a_screen_id)).do_nothing
					end
				end
				l_tabs.containing (l_panel).do_nothing
				l_tab_idx := l_tab_idx + 1
			end

			Result := l_tabs.to_html_8
		end

feature -- Palette Rendering

	render_palette: STRING
			-- Render control palette HTML.
		local
			l_palette, l_group: HTMX_DIV
		do
			l_palette := html.div.class_ ("palette")
			l_palette.containing (html.h4.text ("Controls")).do_nothing

			-- Input controls
			l_group := html.div.class_ ("palette-group")
			l_group.containing (html.h5.text ("Input")).do_nothing
			l_group.containing (palette_item ("text_field", "Text Field")).do_nothing
			l_group.containing (palette_item ("text_area", "Text Area")).do_nothing
			l_group.containing (palette_item ("dropdown", "Dropdown")).do_nothing
			l_group.containing (palette_item ("checkbox", "Checkbox")).do_nothing
			l_group.containing (palette_item ("date_picker", "Date Picker")).do_nothing
			l_palette.containing (l_group).do_nothing

			-- Action controls
			l_group := html.div.class_ ("palette-group")
			l_group.containing (html.h5.text ("Actions")).do_nothing
			l_group.containing (palette_item ("button", "Button")).do_nothing
			l_group.containing (palette_item ("link", "Link")).do_nothing
			l_palette.containing (l_group).do_nothing

			-- Display controls
			l_group := html.div.class_ ("palette-group")
			l_group.containing (html.h5.text ("Display")).do_nothing
			l_group.containing (palette_item ("label", "Label")).do_nothing
			l_group.containing (palette_item ("heading", "Heading")).do_nothing
			l_group.containing (palette_item ("table", "Table")).do_nothing
			l_group.containing (palette_item ("list", "List")).do_nothing
			l_palette.containing (l_group).do_nothing

			-- Layout controls
			l_group := html.div.class_ ("palette-group")
			l_group.containing (html.h5.text ("Layout")).do_nothing
			l_group.containing (palette_item ("card", "Card")).do_nothing
			l_group.containing (palette_item ("tabs", "Tabs")).do_nothing
			l_palette.containing (l_group).do_nothing

			Result := l_palette.to_html_8
		end

	palette_item (a_type, a_label: STRING): HTMX_DIV
			-- Create a single palette item.
		do
			Result := html.div
				.class_ ("palette-item")
				.attr ("draggable", "true")
				.data ("type", a_type)
				.text (a_label)
		end

feature -- Properties Rendering

	render_properties (a_control: GUI_DESIGNER_CONTROL; a_spec_id, a_screen_id: STRING_32): STRING
			-- Render properties panel HTML for control.
		local
			l_panel: HTMX_DIV
			l_form: HTMX_FORM
			l_api_url, l_canvas_url, l_props_url: STRING
		do
			l_api_url := "/api/specs/" + s8 (a_spec_id) + "/screens/" + s8 (a_screen_id) + "/controls/" + s8 (a_control.id)
			l_canvas_url := "/htmx/canvas/" + s8 (a_spec_id) + "/" + s8 (a_screen_id)
			l_props_url := "/htmx/properties/" + s8 (a_spec_id) + "/" + s8 (a_screen_id) + "/" + s8 (a_control.id)

			l_panel := html.div.class_ ("properties-panel")
			l_panel.containing (html.h4.text (s8 (a_control.label))).do_nothing
			l_panel.containing (html.p.style ("color:#666; font-size:12px; margin-top:-10px;").text (s8 (a_control.control_type))).do_nothing

			-- Form with HTMX auto-submit
			l_form := html.form
				.hx_put (l_api_url)
				.hx_trigger ("submit")
				.hx_swap ("none")
				.attr ("hx-on::after-request", "refreshCanvas()")
				.data ("canvas-url", l_canvas_url)
				.data ("props-url", l_props_url)
				.data ("control-id", s8 (a_control.id))

			-- ID (read-only)
			l_form.containing (html.label.text ("ID")).do_nothing
			l_form.containing (
				html.input_text ("").value (s8 (a_control.id)).attr ("disabled", "disabled").class_ ("readonly-field")
			).do_nothing

			-- Type (read-only)
			l_form.containing (html.label.text ("Type")).do_nothing
			l_form.containing (
				html.input_text ("").value (s8 (a_control.control_type)).attr ("disabled", "disabled").class_ ("readonly-field")
			).do_nothing

			-- Label (auto-submit)
			l_form.containing (html.label.text ("Label")).do_nothing
			l_form.containing (
				html.input_text ("label").value (s8 (a_control.label)).attr ("onchange", "htmx.trigger(this.form, 'submit')")
			).do_nothing

			-- Grid Row spinner
			l_form.containing (html.label.text ("Row")).do_nothing
			l_form.containing (spinner_input ("row", a_control.grid_row, 1, 100)).do_nothing

			-- Grid Column spinner
			l_form.containing (html.label.text ("Column")).do_nothing
			l_form.containing (spinner_input ("col", a_control.grid_col, 1, 24)).do_nothing

			-- Column Span spinner
			l_form.containing (html.label.text ("Column Span")).do_nothing
			l_form.containing (spinner_input ("col_span", a_control.col_span, 1, 24)).do_nothing

			-- Notes
			l_form.containing (html.label.text ("Notes")).do_nothing
			l_form.containing (notes_textarea (a_control)).do_nothing

			l_panel.containing (l_form).do_nothing

			-- Delete button (outside form)
			l_panel.containing (html.hr.style ("margin: 20px 0; border: none; border-top: 1px solid #ddd;")).do_nothing
			l_panel.containing (
				html.button_text ("Delete Control")
					.attr ("type", "button")
					.class_ ("delete-btn")
					.attr ("onclick", "deleteControl('" + s8 (a_spec_id) + "', '" + s8 (a_screen_id) + "', '" + s8 (a_control.id) + "')")
			).do_nothing

			Result := l_panel.to_html_8
		end

	spinner_input (a_name: STRING; a_value, a_min, a_max: INTEGER): HTMX_DIV
			-- Create spinner input group with +/- buttons.
		local
			l_group: HTMX_DIV
		do
			l_group := html.div.class_ ("spinner-group")
			l_group.containing (
				html.button_text ("-")
					.attr ("type", "button")
					.class_ ("spin-btn")
					.attr ("onclick", "var inp=this.nextElementSibling; inp.stepDown(); htmx.trigger(inp.form, 'submit')")
			).do_nothing
			l_group.containing (
				html.input_number (a_name)
					.value (a_value.out)
					.attr ("min", a_min.out)
					.attr ("max", a_max.out)
					.class_ ("spin-input")
			).do_nothing
			l_group.containing (
				html.button_text ("+")
					.attr ("type", "button")
					.class_ ("spin-btn")
					.attr ("onclick", "var inp=this.previousElementSibling; inp.stepUp(); htmx.trigger(inp.form, 'submit')")
			).do_nothing
			Result := l_group
		end

	notes_textarea (a_control: GUI_DESIGNER_CONTROL): HTMX_TEXTAREA
			-- Create notes textarea with current content.
		local
			l_notes: STRING
		do
			create l_notes.make (200)
			across a_control.notes as l_note loop
				l_notes.append (s8 (l_note))
				l_notes.append ("%N")
			end
			Result := html.textarea ("notes")
				.attr ("onchange", "htmx.trigger(this.form, 'submit')")
				.text (l_notes)
		end

feature -- List Rendering

	render_screen_list (a_spec: GUI_DESIGNER_SPEC): STRING
			-- Render screen list HTML.
		local
			l_ul: HTMX_UL
			l_li: HTMX_LI
		do
			l_ul := html.ul.class_ ("screen-list")
			across a_spec.screens as l_screen loop
				create l_li.make
				l_li
					.hx_get ("/htmx/canvas/" + s8 (a_spec.app_name) + "/" + s8 (l_screen.id))
					.hx_target ("#canvas")
					.text (s8 (l_screen.title)).do_nothing
				l_ul.containing (l_li).do_nothing
			end
			Result := l_ul.to_html_8
		end

	render_spec_list: STRING
			-- Render spec list HTML for index page.
		local
			l_ul: HTMX_UL
			l_item, l_info, l_actions: HTMX_DIV
		do
			if specs.is_empty then
				Result := html.p.style ("color:#888; font-style:italic;").text ("No specifications loaded. Upload a JSON spec file to get started.").to_html_8
			else
				l_ul := html.ul.class_ ("spec-list")
				across specs as l_spec loop
					l_item := html.div.class_ ("spec-item")

					-- Spec info
					l_info := html.div.class_ ("spec-info")
					l_info.containing (html.div.class_ ("spec-name").text (s8 (l_spec.app_name))).do_nothing
					l_info.containing (
						html.div.class_ ("spec-meta").text ("Version " + l_spec.version.out + " | " + l_spec.screens.count.out + " screen(s)")
					).do_nothing
					l_item.containing (l_info).do_nothing

					-- Spec actions
					l_actions := html.div.class_ ("spec-actions")
					l_actions.containing (
						html.link ("/api/specs/" + s8 (l_spec.app_name) + "/download", "Download").class_ ("btn btn-secondary btn-sm")
					).do_nothing
					l_actions.containing (
						html.link ("/designer?spec=" + s8 (l_spec.app_name), "Edit").class_ ("btn btn-success btn-sm")
					).do_nothing
					l_item.containing (l_actions).do_nothing

					l_ul.containing (l_item).do_nothing
				end
				Result := l_ul.to_html_8
			end
		end

end
