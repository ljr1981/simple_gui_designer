# Simple GUI Designer

A web-based GUI specification designer built with Eiffel and HTMX. Design application screens visually using drag-and-drop, then export the specification as JSON for code generation or documentation.

## Features

- **Visual Design Canvas**: Drag controls onto a 12-column grid layout
- **Rich Control Library**: Headings, labels, text fields, text areas, buttons, dropdowns, checkboxes, date pickers, tables, and links
- **Container Controls**: Cards and tabbed panels with nested children
- **Multi-Screen Support**: Design multiple screens per application
- **Properties Panel**: Edit control attributes, data bindings, and validation rules
- **Notes System**: Add design notes at control, screen, or global level
- **Import/Export**: Load existing specs or export as JSON
- **Finalize Workflow**: Lock specs for production use

## Requirements

- EiffelStudio 25.02 or later
- Environment variables:
  - `SIMPLE_JSON` - Path to [simple_json](https://github.com/jvelilla/simple_json) library
  - `SIMPLE_WEB` - Path to simple_web library
  - `TESTING_EXT` - Path to testing_ext library

## Building

```bash
# Compile the application
ec -config simple_gui_designer.ecf -target simple_gui_designer_app -c_compile -freeze

# Run the server
./EIFGENs/simple_gui_designer_app/W_code/simple_gui_designer.exe
```

The server starts on `http://localhost:9090`.

## Usage

1. **Start the server** and open `http://localhost:9090` in your browser
2. **Create a new spec** by entering an app name and clicking "Create New Spec"
3. **Add screens** using the "+ New Screen" button
4. **Drag controls** from the palette onto the canvas
5. **Edit properties** by clicking a control to select it
6. **Add notes** for implementation guidance
7. **Export** the spec as JSON when design is complete

## Spec JSON Format

```json
{
  "app": "my_app",
  "version": 1,
  "finalized": false,
  "screens": [
    {
      "id": "main_screen",
      "title": "Main Screen",
      "controls": [
        {
          "id": "title_heading",
          "type": "heading",
          "label": "Welcome",
          "row": 1,
          "col": 1,
          "col_span": 12,
          "row_span": 1,
          "properties": {},
          "validation": [],
          "notes": []
        }
      ],
      "notes": [],
      "api_bindings": []
    }
  ],
  "global_notes": [],
  "ai_suggestions": []
}
```

## Control Types

| Type | Description |
|------|-------------|
| `heading` | Section heading text |
| `label` | Static text display |
| `text_field` | Single-line text input |
| `text_area` | Multi-line text input |
| `button` | Clickable button (primary, secondary, danger variants) |
| `dropdown` | Selection from options |
| `checkbox` | Boolean toggle |
| `date_picker` | Date selection |
| `table` | Data grid display |
| `link` | Navigation link |
| `card` | Container with optional title |
| `tabs` | Tabbed container with multiple panels |

## Project Structure

```
simple_gui_designer/
├── src/
│   ├── app/                    # Application entry point
│   ├── server/                 # HTMX web server and handlers
│   │   └── handlers/           # Route handlers (modular)
│   ├── shared/                 # Logging utilities
│   └── spec/                   # Spec data classes
├── specs/                      # Saved specification files
├── testing/                    # Unit tests (10 tests)
├── simple_gui_designer.ecf    # Eiffel configuration
└── README.md                  # This file
```

## Roadmap

### Completed Features
- [x] Visual drag-and-drop canvas with 12-column grid
- [x] 12 control types (heading, label, text_field, text_area, button, dropdown, checkbox, date_picker, table, link, card, tabs)
- [x] Container controls with nested children (card, tabs)
- [x] Multi-screen support with navigation
- [x] Properties panel for editing control attributes
- [x] Import/Export JSON specifications
- [x] Finalize workflow for production specs
- [x] Refactored to use simple_htmx fluent HTML builder
- [x] Comprehensive regression tests

### Planned Features
- [ ] Undo/redo support
- [ ] Copy/paste controls between screens
- [ ] Control alignment helpers
- [ ] Preview mode (render as actual HTML)
- [ ] Code generation templates

## Dependencies

| Library | Purpose |
|---------|---------|
| `simple_json` | JSON parsing and serialization |
| `simple_web` | HTTP server and routing |
| `simple_htmx` | Fluent HTML/HTMX generation |
| `simple_process` | Process management |
| `testing_ext` | Test framework extensions |

## License

MIT License - Copyright (c) 2024-2025, Larry Rix
