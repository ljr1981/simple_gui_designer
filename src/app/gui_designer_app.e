note
	description: "GUI Designer Application entry point."
	author: "Claude Code"
	date: "$Date$"
	revision: "$Revision$"

class
	GUI_DESIGNER_APP

create
	make

feature {NONE} -- Initialization

	make
			-- Launch the GUI Designer server.
		local
			l_server: GUI_DESIGNER_SERVER
		do
			create l_server.make (8080)
			l_server.start
		end

end
