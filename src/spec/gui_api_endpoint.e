note
	description: "[
		API endpoint specification.

		Describes an HTTP endpoint that the GUI interacts with:
		- Method (GET, POST, PUT, DELETE)
		- Path with parameters
		- Request/response shape
		- Bound to which controls/actions
	]"
	author: "Claude Code"
	date: "$Date$"
	revision: "$Revision$"

class
	GUI_API_ENDPOINT

inherit
	SIMPLE_JSON_SERIALIZABLE

create
	make,
	make_from_json

feature {NONE} -- Initialization

	make (a_method, a_path: STRING_32)
			-- Create endpoint.
		require
			method_valid: is_valid_method (a_method)
			path_not_empty: not a_path.is_empty
		do
			method := a_method.as_upper
			path := a_path
			create request_fields.make (5)
			create response_fields.make (5)
		ensure
			method_set: method.same_string (a_method.as_upper)
			path_set: path.same_string (a_path)
		end

	make_from_json (a_json: SIMPLE_JSON_OBJECT)
			-- Load from JSON.
		require
			has_required: a_json.has_all_keys (<<"method", "path">>)
		local
			i: INTEGER
		do
			if attached a_json.string_item ("method") as m then
				method := m.as_upper
			else
				method := "GET"
			end
			if attached a_json.string_item ("path") as p then
				path := p
			else
				path := "/"
			end

			description := a_json.optional_string ("description")
			trigger_control := a_json.optional_string ("trigger_control")
			target_control := a_json.optional_string ("target_control")

			create request_fields.make (5)
			create response_fields.make (5)

			-- Load request fields
			if attached a_json.array_item ("request_fields") as l_req then
				from i := 1 until i > l_req.count loop
					if l_req.item (i).is_string then
						request_fields.extend (l_req.item (i).as_string_32)
					end
					i := i + 1
				end
			end

			-- Load response fields
			if attached a_json.array_item ("response_fields") as l_resp then
				from i := 1 until i > l_resp.count loop
					if l_resp.item (i).is_string then
						response_fields.extend (l_resp.item (i).as_string_32)
					end
					i := i + 1
				end
			end
		end

feature -- Access

	method: STRING_32
			-- HTTP method (GET, POST, PUT, PATCH, DELETE).

	path: STRING_32
			-- URL path (e.g., "/api/todos/{id}").

	description: detachable STRING_32
			-- Human-readable description.

	trigger_control: detachable STRING_32
			-- Control ID that triggers this call (e.g., button).

	target_control: detachable STRING_32
			-- Control ID to update with response (e.g., table).

	request_fields: ARRAYED_LIST [STRING_32]
			-- Fields sent in request body.

	response_fields: ARRAYED_LIST [STRING_32]
			-- Fields expected in response.

feature -- Query

	is_valid_method (a_method: STRING_32): BOOLEAN
			-- Is this a valid HTTP method?
		local
			l_upper: STRING_32
		do
			l_upper := a_method.as_upper
			Result := l_upper.same_string ("GET") or
					  l_upper.same_string ("POST") or
					  l_upper.same_string ("PUT") or
					  l_upper.same_string ("PATCH") or
					  l_upper.same_string ("DELETE")
		end

	has_path_parameters: BOOLEAN
			-- Does path contain {param} placeholders?
		do
			Result := path.has ('{')
		end

	path_parameters: ARRAYED_LIST [STRING_32]
			-- Extract parameter names from path.
		local
			i, j: INTEGER
			l_param: STRING_32
		do
			create Result.make (3)
			from
				i := 1
			until
				i > path.count
			loop
				if path.item (i) = '{' then
					j := path.index_of ('}', i)
					if j > i then
						l_param := path.substring (i + 1, j - 1)
						Result.extend (l_param)
						i := j + 1
					else
						i := i + 1
					end
				else
					i := i + 1
				end
			end
		end

	unique_key: STRING_32
			-- Unique identifier for this endpoint.
		do
			Result := method + " " + path
		end

feature -- Modification

	set_description (a_desc: STRING_32)
			-- Set description.
		do
			description := a_desc
		end

	set_trigger_control (a_control_id: STRING_32)
			-- Set triggering control.
		do
			trigger_control := a_control_id
		end

	set_target_control (a_control_id: STRING_32)
			-- Set target control for response.
		do
			target_control := a_control_id
		end

	add_request_field (a_field: STRING_32)
			-- Add request field.
		require
			not_empty: not a_field.is_empty
		do
			request_fields.extend (a_field)
		end

	add_response_field (a_field: STRING_32)
			-- Add response field.
		require
			not_empty: not a_field.is_empty
		do
			response_fields.extend (a_field)
		end

feature -- JSON Serialization

	to_json: SIMPLE_JSON_OBJECT
			-- Convert to JSON.
		local
			l_req_arr, l_resp_arr: SIMPLE_JSON_ARRAY
		do
			create Result.make
			Result.put_string (method, "method").do_nothing
			Result.put_string (path, "path").do_nothing

			if attached description as d then
				Result.put_string (d, "description").do_nothing
			end
			if attached trigger_control as tc then
				Result.put_string (tc, "trigger_control").do_nothing
			end
			if attached target_control as tgt then
				Result.put_string (tgt, "target_control").do_nothing
			end

			-- Request fields
			create l_req_arr.make
			across request_fields as f loop
				l_req_arr.add_string (f).do_nothing
			end
			Result.put_array (l_req_arr, "request_fields").do_nothing

			-- Response fields
			create l_resp_arr.make
			across response_fields as f loop
				l_resp_arr.add_string (f).do_nothing
			end
			Result.put_array (l_resp_arr, "response_fields").do_nothing
		end

feature -- JSON Deserialization

	apply_json (a_json: SIMPLE_JSON_OBJECT)
			-- Apply JSON updates.
		do
			if attached a_json.optional_string ("description") as d then
				description := d
			end
		end

feature -- Validation

	json_has_required_fields (a_json: SIMPLE_JSON_OBJECT): BOOLEAN
			-- Check required fields.
		do
			Result := a_json.has_all_keys (<<"method", "path">>)
		end

invariant
	method_valid: is_valid_method (method)
	path_not_empty: not path.is_empty

end
