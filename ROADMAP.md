# Simple GUI Designer Roadmap

## Completed

- [x] HTMX-based web interface for designing GUI specifications
- [x] Drag-and-drop control placement on canvas grid
- [x] Control types: heading, label, text_field, text_area, button, dropdown, checkbox, date_picker, table, link
- [x] Container controls: Card and Tabs with nested children
- [x] Properties panel for editing control attributes
- [x] Delete control functionality
- [x] Label auto-save on change
- [x] Read-only ID/Type fields
- [x] Multi-screen support with screen navigation
- [x] New screen creation
- [x] Import/Upload existing spec JSON files
- [x] Export spec as downloadable JSON file
- [x] Basic JSON validation on upload (required fields check)
- [x] Finalize workflow for production specs
- [x] Server-side logging for debugging

## Planned

### JSON Schema Validation
- [ ] Define JSON Schema for GUI spec format
- [ ] Use simple_json's SIMPLE_JSON_SCHEMA_VALIDATOR for upload validation
- [ ] Provide detailed validation error messages with field paths
- [ ] Validate control types against allowed list
- [ ] Validate property values against control-specific rules

### Future Enhancements
- [ ] Undo/Redo support
- [ ] Copy/Paste controls
- [ ] Keyboard shortcuts (n=new, d=delete, space=toggle)
- [ ] Visual distinction for completed items (from todo_app notes)
- [ ] Grid position editing in properties panel
- [ ] Control reordering via drag-and-drop on canvas
- [ ] Preview mode to see rendered UI
- [ ] API binding configuration UI
