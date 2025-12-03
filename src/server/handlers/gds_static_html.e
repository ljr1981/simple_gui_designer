note
	description: "[
		Static HTML page templates for GUI Designer.

		Provides:
		- index_html: Main index page
		- designer_html_for_spec: Designer page for a specific spec
		- control_palette_json: JSON palette data
	]"
	author: "Claude Code"
	date: "$Date$"
	revision: "$Revision$"

deferred class
	GDS_STATIC_HTML

inherit
	GDS_HTML_RENDERER

feature -- Static HTML

	index_html: STRING
			-- Index page HTML with spec management.
		once
			Result := "[
<!DOCTYPE html>
<html>
<head>
	<title>GUI Designer</title>
	<script src="https://unpkg.com/htmx.org@1.9.10"></script>
	<style>
		* { box-sizing: border-box; }
		body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
		.container { max-width: 900px; margin: 0 auto; }
		h1 { color: #333; margin-bottom: 5px; }
		.subtitle { color: #666; margin-bottom: 30px; }

		/* Card styles */
		.card { background: white; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); padding: 20px; margin-bottom: 20px; }
		.card h2 { margin-top: 0; color: #333; border-bottom: 1px solid #eee; padding-bottom: 10px; }

		/* Button styles */
		.btn { display: inline-block; padding: 10px 20px; border-radius: 4px; text-decoration: none; font-weight: 500; cursor: pointer; border: none; font-size: 14px; }
		.btn-primary { background: #2196F3; color: white; }
		.btn-primary:hover { background: #1976D2; }
		.btn-success { background: #4CAF50; color: white; }
		.btn-success:hover { background: #388E3C; }
		.btn-secondary { background: #757575; color: white; }
		.btn-secondary:hover { background: #616161; }
		.btn-sm { padding: 6px 12px; font-size: 12px; }

		/* Spec list */
		.spec-list { list-style: none; padding: 0; margin: 0; }
		.spec-item { display: flex; align-items: center; justify-content: space-between; padding: 12px 15px; border: 1px solid #eee; border-radius: 4px; margin-bottom: 8px; background: #fafafa; }
		.spec-item:hover { background: #f0f7ff; border-color: #2196F3; }
		.spec-info { flex: 1; }
		.spec-name { font-weight: 600; color: #333; }
		.spec-meta { font-size: 12px; color: #888; margin-top: 4px; }
		.spec-actions { display: flex; gap: 8px; }

		/* Upload area */
		.upload-area { border: 2px dashed #ccc; border-radius: 8px; padding: 30px; text-align: center; margin-top: 15px; transition: all 0.3s; }
		.upload-area:hover { border-color: #2196F3; background: #f0f7ff; }
		.upload-area.dragover { border-color: #4CAF50; background: #e8f5e9; }
		.upload-area input[type="file"] { display: none; }
		.upload-area label { cursor: pointer; color: #666; }
		.upload-area label strong { color: #2196F3; }

		/* Status messages */
		.status { padding: 10px 15px; border-radius: 4px; margin-top: 10px; display: none; }
		.status.success { display: block; background: #e8f5e9; color: #2e7d32; }
		.status.error { display: block; background: #ffebee; color: #c62828; }

		/* Action bar */
		.action-bar { display: flex; justify-content: space-between; align-items: center; margin-bottom: 15px; }
		.action-bar-right { display: flex; gap: 10px; }
	</style>
</head>
<body>
	<div class="container">
		<h1>GUI Designer</h1>
		<p class="subtitle">Visual specification builder for Eiffel applications</p>

		<div class="card">
			<h2>Specifications</h2>
			<div class="action-bar">
				<a href="/designer" class="btn btn-primary">Open Designer</a>
				<div class="action-bar-right">
					<a href="/api/specs/download-all" class="btn btn-secondary btn-sm">Download All</a>
				</div>
			</div>

			<div id="spec-list" hx-get="/htmx/spec-list" hx-trigger="load">
				Loading specifications...
			</div>
		</div>

		<div class="card">
			<h2>Upload Specification</h2>
			<p>Upload a JSON spec file to add or update a specification.</p>

			<div class="upload-area" id="upload-area">
				<input type="file" id="spec-file" accept=".json" onchange="uploadFile(this)">
				<label for="spec-file">
					<strong>Click to browse</strong> or drag and drop a JSON file here
				</label>
			</div>

			<div id="upload-status" class="status"></div>
		</div>
	</div>

	<script>
		// Drag and drop handling
		const uploadArea = document.getElementById('upload-area');

		['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
			uploadArea.addEventListener(eventName, e => {
				e.preventDefault();
				e.stopPropagation();
			});
		});

		['dragenter', 'dragover'].forEach(eventName => {
			uploadArea.addEventListener(eventName, () => uploadArea.classList.add('dragover'));
		});

		['dragleave', 'drop'].forEach(eventName => {
			uploadArea.addEventListener(eventName, () => uploadArea.classList.remove('dragover'));
		});

		uploadArea.addEventListener('drop', e => {
			const files = e.dataTransfer.files;
			if (files.length > 0) {
				handleFile(files[0]);
			}
		});

		function uploadFile(input) {
			if (input.files.length > 0) {
				handleFile(input.files[0]);
			}
		}

		function handleFile(file) {
			const status = document.getElementById('upload-status');

			if (!file.name.endsWith('.json')) {
				status.className = 'status error';
				status.textContent = 'Error: Please upload a JSON file';
				return;
			}

			const reader = new FileReader();
			reader.onload = function(e) {
				try {
					const json = JSON.parse(e.target.result);

					fetch('/api/specs/upload', {
						method: 'POST',
						headers: { 'Content-Type': 'application/json' },
						body: JSON.stringify(json)
					})
					.then(r => r.json())
					.then(data => {
						if (data.error) {
							status.className = 'status error';
							status.textContent = 'Error: ' + data.error;
						} else {
							status.className = 'status success';
							status.textContent = 'Spec "' + data.name + '" ' + data.status + ' successfully!';
							htmx.trigger('#spec-list', 'load');
						}
					})
					.catch(err => {
						status.className = 'status error';
						status.textContent = 'Error: ' + err.message;
					});
				} catch (err) {
					status.className = 'status error';
					status.textContent = 'Error: Invalid JSON file';
				}
			};
			reader.readAsText(file);
		}
	</script>
</body>
</html>
			]"
		end

	control_palette_json: STRING
			-- Control palette as JSON.
		once
			Result := "[
{
	"categories": [
		{
			"name": "Input",
			"controls": [
				{"type": "text_field", "label": "Text Field", "default_col_span": 4},
				{"type": "text_area", "label": "Text Area", "default_col_span": 6},
				{"type": "number_field", "label": "Number", "default_col_span": 2},
				{"type": "dropdown", "label": "Dropdown", "default_col_span": 3},
				{"type": "checkbox", "label": "Checkbox", "default_col_span": 2},
				{"type": "date_picker", "label": "Date Picker", "default_col_span": 3}
			]
		},
		{
			"name": "Actions",
			"controls": [
				{"type": "button", "label": "Button", "default_col_span": 2},
				{"type": "link", "label": "Link", "default_col_span": 2}
			]
		},
		{
			"name": "Display",
			"controls": [
				{"type": "label", "label": "Label", "default_col_span": 3},
				{"type": "heading", "label": "Heading", "default_col_span": 12},
				{"type": "table", "label": "Table", "default_col_span": 12},
				{"type": "list", "label": "List", "default_col_span": 6}
			]
		},
		{
			"name": "Layout",
			"controls": [
				{"type": "card", "label": "Card", "default_col_span": 6},
				{"type": "tabs", "label": "Tabs", "default_col_span": 12}
			]
		}
	]
}
			]"
		end

feature -- Dynamic HTML

	designer_html_for_spec (a_spec_name: STRING_32): STRING
			-- Designer page HTML for specific spec.
		local
			l_name: STRING
		do
			l_name := s8 (a_spec_name)
			create Result.make (15000)
			Result.append ("<!DOCTYPE html>%N<html>%N<head>%N")
			Result.append ("<title>GUI Designer - " + l_name + "</title>%N")
			Result.append ("<script src=%"https://unpkg.com/htmx.org@1.9.10%"></script>%N")
			Result.append (designer_css)
			Result.append ("</head>%N<body>%N")
			Result.append (designer_sidebar (l_name))
			Result.append (designer_main_area (l_name))
			Result.append (designer_properties_panel)
			Result.append (designer_javascript (l_name))
			Result.append ("</body>%N</html>")
		end

feature {NONE} -- Designer HTML Helpers

	designer_css: STRING
			-- CSS styles for designer page.
		once
			Result := "[
<style>
* { box-sizing: border-box; }
body { font-family: sans-serif; margin: 0; display: flex; height: 100vh; }
.sidebar { width: 200px; background: #f5f5f5; padding: 10px; border-right: 1px solid #ddd; }
.sidebar h3 { margin: 0 0 10px 0; }
.main { flex: 1; display: flex; flex-direction: column; }
.toolbar { padding: 10px; background: #333; color: white; }
.toolbar .btn { display: inline-block; padding: 4px 12px; background: #555; color: white; text-decoration: none; border-radius: 3px; margin-left: 5px; }
.toolbar .btn:hover { background: #666; }
#canvas { flex: 1; padding: 20px; overflow: auto; background: #fafafa; }
.canvas-grid { background: white; border: 1px solid #ddd; padding: 20px; min-height: 400px; overflow-x: auto; }
.grid-row { display: flex; flex-wrap: wrap; gap: 8px; margin-bottom: 10px; }
.control { background: #e3f2fd; border: 2px solid #2196F3; padding: 10px; cursor: pointer; }
.control:hover { border-color: #1565C0; }
.control.selected { border-color: #ff9800; background: #fff3e0; box-shadow: 0 0 8px rgba(255,152,0,0.5); }
.col-1 { flex: 0 0 calc(4.16% - 6px); } .col-2 { flex: 0 0 calc(8.33% - 6px); } .col-3 { flex: 0 0 calc(12.5% - 6px); }
.col-4 { flex: 0 0 calc(16.66% - 6px); } .col-5 { flex: 0 0 calc(20.83% - 6px); } .col-6 { flex: 0 0 calc(25% - 6px); }
.col-7 { flex: 0 0 calc(29.16% - 6px); } .col-8 { flex: 0 0 calc(33.33% - 6px); } .col-9 { flex: 0 0 calc(37.5% - 6px); }
.col-10 { flex: 0 0 calc(41.66% - 6px); } .col-11 { flex: 0 0 calc(45.83% - 6px); } .col-12 { flex: 0 0 calc(50% - 6px); }
.col-13 { flex: 0 0 calc(54.16% - 6px); } .col-14 { flex: 0 0 calc(58.33% - 6px); } .col-15 { flex: 0 0 calc(62.5% - 6px); }
.col-16 { flex: 0 0 calc(66.66% - 6px); } .col-17 { flex: 0 0 calc(70.83% - 6px); } .col-18 { flex: 0 0 calc(75% - 6px); }
.col-19 { flex: 0 0 calc(79.16% - 6px); } .col-20 { flex: 0 0 calc(83.33% - 6px); } .col-21 { flex: 0 0 calc(87.5% - 6px); }
.col-22 { flex: 0 0 calc(91.66% - 6px); } .col-23 { flex: 0 0 calc(95.83% - 6px); } .col-24 { flex: 0 0 100%; }
.palette-group { margin-bottom: 15px; }
.palette-group h5 { margin: 5px 0; color: #666; }
.palette-item { padding: 8px; background: white; border: 1px solid #ddd; margin: 2px 0; cursor: grab; }
.palette-item:hover { background: #e3f2fd; }
.properties { width: 250px; background: #f5f5f5; padding: 10px; border-left: 1px solid #ddd; }
.properties label { display: block; margin-top: 10px; font-size: 12px; color: #666; }
.properties input, .properties textarea { width: 100%; padding: 5px; }
.properties input.readonly-field { background: #e0e0e0; color: #666; cursor: not-allowed; border: 1px solid #ccc; }
.spinner-group { display: flex; align-items: center; }
.spin-btn { width: 30px; height: 30px; border: 1px solid #ccc; background: #fff; cursor: pointer; font-size: 16px; }
.spin-btn:hover { background: #e3f2fd; }
.spin-input { width: 50px; text-align: center; margin: 0 4px; }
.delete-btn { width: 100%; padding: 10px; background: #f44336; color: white; border: none; border-radius: 4px; cursor: pointer; font-size: 14px; font-weight: bold; }
.delete-btn:hover { background: #d32f2f; }
.screen-list { list-style: none; padding: 0; }
.screen-list li { padding: 8px; cursor: pointer; }
.screen-list li:hover { background: #e3f2fd; }
/* Container control styles */
.container-control { position: relative; min-height: 80px; }
.card-control { background: #fff; border: 2px solid #9c27b0; border-radius: 8px; padding: 0; overflow: hidden; }
.card-control:hover { border-color: #7b1fa2; }
.card-control.selected { border-color: #ff9800; box-shadow: 0 0 8px rgba(255,152,0,0.5); }
.card-header { background: #9c27b0; color: white; padding: 8px 12px; font-weight: bold; }
.card-body { padding: 10px; min-height: 60px; background: #fce4ec; }
.tabs-control { background: #fff; border: 2px solid #00bcd4; border-radius: 8px; padding: 0; overflow: hidden; }
.tabs-control:hover { border-color: #0097a7; }
.tabs-control.selected { border-color: #ff9800; box-shadow: 0 0 8px rgba(255,152,0,0.5); }
.tabs-header { display: flex; background: #00bcd4; }
.tab-header { padding: 8px 16px; color: white; cursor: pointer; border-right: 1px solid rgba(255,255,255,0.3); }
.tab-header:hover { background: rgba(255,255,255,0.2); }
.tab-header.active { background: #e0f7fa; color: #00bcd4; font-weight: bold; }
.tab-add-btn { padding: 8px 12px; color: white; cursor: pointer; font-weight: bold; }
.tab-add-btn:hover { background: rgba(255,255,255,0.2); }
.tab-panel { display: none; padding: 10px; min-height: 60px; background: #e0f7fa; }
.tab-panel.active { display: block; }
.drop-zone { transition: background 0.2s; }
.drop-zone.drag-over { background: #c8e6c9 !important; border: 2px dashed #4caf50; }
.drop-placeholder { color: #999; font-style: italic; text-align: center; padding: 20px; border: 2px dashed #ccc; border-radius: 4px; }
</style>
			]"
		end

	designer_sidebar (a_name: STRING): STRING
			-- Sidebar HTML.
		local
			l_sidebar: HTMX_DIV
		do
			l_sidebar := html.div.class_ ("sidebar")
			l_sidebar.containing (html.h3.text ("Screens")).do_nothing
			l_sidebar.containing (
				html.div.id ("screen-list")
					.hx_get ("/htmx/screen-list/" + a_name)
					.hx_trigger_load
					.text ("Loading...")
			).do_nothing
			l_sidebar.containing (html.hr).do_nothing
			l_sidebar.containing (
				html.div.id ("palette")
					.hx_get ("/htmx/palette")
					.hx_trigger_load
					.text ("Loading palette...")
			).do_nothing
			Result := l_sidebar.to_html_8
		end

	designer_main_area (a_name: STRING): STRING
			-- Main area HTML with toolbar.
		local
			l_main, l_toolbar: HTMX_DIV
			l_finalize_js, l_save_js: STRING
		do
			l_finalize_js := "this.textContent='Finalized!'; this.style.background='#4CAF50'; var eb=document.getElementById('export-btn'); eb.style.opacity='1'; eb.style.pointerEvents='auto';"
			l_save_js := "this.textContent='Saved!'; this.style.background='#4CAF50'; setTimeout(function(){this.textContent='Save'; this.style.background='';},2000)"

			l_toolbar := html.div.class_ ("toolbar")
			l_toolbar.raw_html ("<strong>GUI Designer</strong> - " + a_name + " | ").do_nothing
			l_toolbar.containing (
				html.button_text ("+ New Screen")
					.attr ("type", "button")
					.attr ("onclick", "createNewScreen('" + a_name + "')")
			).do_nothing
			l_toolbar.raw_html (" ").do_nothing
			l_toolbar.containing (
				html.button_text ("Finalize")
					.hx_post ("/api/specs/" + a_name + "/finalize")
					.hx_swap_none
					.attr ("hx-on::after-request", l_finalize_js)
			).do_nothing
			l_toolbar.raw_html (" ").do_nothing
			l_toolbar.containing (
				html.link ("/api/specs/" + a_name + "/export", "Export")
					.id ("export-btn")
					.class_ ("btn")
					.style ("opacity:0.5; pointer-events:none")
			).do_nothing
			l_toolbar.raw_html (" ").do_nothing
			l_toolbar.containing (
				html.button_text ("Save")
					.hx_post ("/api/specs/" + a_name + "/save")
					.hx_swap_none
					.attr ("hx-on::after-request", l_save_js)
			).do_nothing
			l_toolbar.raw_html (" ").do_nothing
			l_toolbar.containing (
				html.link ("/api/specs/" + a_name + "/download", "Download").class_ ("btn")
			).do_nothing
			l_toolbar.raw_html (" ").do_nothing
			l_toolbar.containing (
				html.link ("/", "Back to Home").style ("color:#aaa; margin-left:20px;")
			).do_nothing

			l_main := html.div.class_ ("main")
			l_main.containing (l_toolbar).do_nothing
			l_main.containing (
				html.div.id ("canvas").containing (html.p.text ("Select a screen from the sidebar to begin designing."))
			).do_nothing

			Result := l_main.to_html_8
		end

	designer_properties_panel: STRING
			-- Properties panel HTML.
		once
			Result := "[
<div class="properties" id="properties">
<h4>Properties</h4>
<p>Select a control to edit its properties.</p>
</div>
			]"
		end

	designer_javascript (a_name: STRING): STRING
			-- JavaScript for designer functionality.
		do
			create Result.make (8000)
			Result.append ("<script>%N")
			Result.append ("var currentSpecId = '" + a_name + "';%N")
			Result.append ("var currentScreenId = null;%N")
			Result.append ("var controlCounter = 0;%N%N")
			Result.append (designer_js_refresh_canvas)
			Result.append (designer_js_delete_control)
			Result.append (designer_js_create_screen)
			Result.append (designer_js_event_handlers)
			Result.append (designer_js_drag_drop)
			Result.append (designer_js_add_control)
			Result.append (designer_js_defaults)
			Result.append (designer_js_containers)
			Result.append (designer_js_tabs)
			Result.append ("</script>%N")
		end

	designer_js_refresh_canvas: STRING
		once
			Result := "[
function refreshCanvas() {
  var form = event.target;
  var canvasUrl = form.getAttribute('data-canvas-url');
  var propsUrl = form.getAttribute('data-props-url');
  var controlId = form.getAttribute('data-control-id');
  htmx.ajax('GET', canvasUrl, {target:'#canvas'}).then(function(){
    var el = document.querySelector('[data-id=' + JSON.stringify(controlId) + ']');
    if(el) el.classList.add('selected');
    htmx.ajax('GET', propsUrl, {target:'#properties'});
    setupCanvasDrop();
  });
}

			]"
		end

	designer_js_delete_control: STRING
		once
			Result := "[
function deleteControl(specId, screenId, controlId) {
  if (!confirm('Delete this control?')) return;
  var url = '/api/specs/' + specId + '/screens/' + screenId + '/controls/' + controlId;
  console.log('[DELETE] Deleting control:', url);
  fetch(url, { method: 'DELETE' })
  .then(function(r) {
    if (r.ok) {
      console.log('[DELETE] Control deleted successfully');
      var canvasUrl = '/htmx/canvas/' + specId + '/' + screenId;
      htmx.ajax('GET', canvasUrl, {target:'#canvas'});
      document.getElementById('properties').innerHTML = '<p style="color:#666;padding:20px;">Select a control to edit its properties</p>';
    } else {
      alert('Failed to delete control');
    }
  })
  .catch(function(err) {
    console.error('[DELETE] Error:', err);
    alert('Error deleting control: ' + err.message);
  });
}

			]"
		end

	designer_js_create_screen: STRING
		once
			Result := "[
function createNewScreen(specId) {
  var title = prompt('Enter screen title:', 'New Screen');
  if (!title) return;
  var id = title.toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_|_$/g, '');
  if (!id) { alert('Invalid screen title'); return; }
  console.log('[SCREEN] Creating new screen:', id, title);
  fetch('/api/specs/' + specId + '/screens', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ id: id, title: title })
  })
  .then(function(r) {
    if (r.ok) {
      console.log('[SCREEN] Screen created successfully');
      htmx.ajax('GET', '/htmx/screen-list/' + specId, {target:'#screen-list'});
    } else {
      r.json().then(function(data) { alert('Failed: ' + (data.error || 'Unknown error')); });
    }
  })
  .catch(function(err) {
    console.error('[SCREEN] Error:', err);
    alert('Error creating screen: ' + err.message);
  });
}

			]"
		end

	designer_js_event_handlers: STRING
		once
			Result := "[
// Track current screen when loading canvas
document.body.addEventListener('htmx:afterSwap', function(evt) {
  if (evt.detail.target.id === 'canvas') {
    var url = evt.detail.pathInfo.requestPath;
    var parts = url.split('/');
    if (parts.length >= 4) {
      currentScreenId = parts[parts.length - 1];
      console.log('Current screen set to:', currentScreenId);
    }
    setupCanvasDrop();
  }
});

// Setup palette drag handlers
document.body.addEventListener('htmx:afterSwap', function(evt) {
  if (evt.detail.target.id === 'palette') {
    setupPaletteDrag();
  }
});

			]"
		end

	designer_js_drag_drop: STRING
		once
			Result := "[
function setupPaletteDrag() {
  document.querySelectorAll('.palette-item').forEach(function(item) {
    item.addEventListener('dragstart', function(e) {
      var controlType = this.getAttribute('data-type');
      e.dataTransfer.setData('text/plain', controlType);
      e.dataTransfer.effectAllowed = 'copy';
      console.log('Drag started:', controlType);
    });
  });
}

function setupCanvasDrop() {
  var canvas = document.getElementById('canvas');
  var canvasGrid = canvas.querySelector('.canvas-grid');
  if (!canvasGrid) {
    console.log('No canvas-grid found yet');
    return;
  }

  if (canvasGrid.dataset.dropSetup === 'true') {
    console.log('[CANVAS] Drop handlers already setup');
    return;
  }
  canvasGrid.dataset.dropSetup = 'true';
  console.log('[CANVAS] Attaching drop handlers');

  canvasGrid.addEventListener('dragover', function(e) {
    e.preventDefault();
    e.dataTransfer.dropEffect = 'copy';
    this.style.background = '#e8f5e9';
  });

  canvasGrid.addEventListener('dragleave', function(e) {
    this.style.background = '';
  });

  canvasGrid.addEventListener('drop', function(e) {
    e.preventDefault();
    this.style.background = '';

    var controlType = e.dataTransfer.getData('text/plain');
    if (!controlType) {
      console.log('No control type in drop data');
      return;
    }

    if (!currentScreenId) {
      alert('Please select a screen first');
      return;
    }

    console.log('Dropped:', controlType, 'on screen:', currentScreenId);
    addControlToScreen(controlType);
  });

  console.log('Canvas drop handlers set up');
  setupContainerDropZones();
}

			]"
		end

	designer_js_add_control: STRING
		once
			Result := "[
function addControlToScreen(controlType) {
  controlCounter++;
  var controlId = controlType + '_' + Date.now();
  var defaultColSpan = getDefaultColSpan(controlType);
  var label = getDefaultLabel(controlType);

  var payload = {
    id: controlId,
    type: controlType,
    label: label,
    grid_row: 1,
    grid_col: 1,
    col_span: defaultColSpan
  };

  var url = '/api/specs/' + currentSpecId + '/screens/' + currentScreenId + '/controls';
  console.log('POST to:', url, payload);

  fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
  })
  .then(function(r) { return r.json(); })
  .then(function(data) {
    console.log('Control added:', data);
    var newControlId = data.id;
    var canvasUrl = '/htmx/canvas/' + currentSpecId + '/' + currentScreenId;
    htmx.ajax('GET', canvasUrl, {target:'#canvas'}).then(function(){
      document.querySelectorAll('.control.selected').forEach(function(c) { c.classList.remove('selected'); });
      var newEl = document.querySelector('[data-id="' + newControlId + '"]');
      if (newEl) {
        newEl.classList.add('selected');
        console.log('Selected new control:', newControlId);
      }
      var propsUrl = '/htmx/properties/' + currentSpecId + '/' + currentScreenId + '/' + newControlId;
      htmx.ajax('GET', propsUrl, {target:'#properties'});
    });
  })
  .catch(function(err) {
    console.error('Failed to add control:', err);
    alert('Failed to add control: ' + err.message);
  });
}

			]"
		end

	designer_js_defaults: STRING
		once
			Result := "[
function getDefaultColSpan(controlType) {
  var spans = {
    'text_field': 4, 'text_area': 6, 'number_field': 2,
    'dropdown': 3, 'checkbox': 2, 'date_picker': 3,
    'button': 2, 'link': 2,
    'label': 3, 'heading': 12, 'table': 12, 'list': 6,
    'card': 6, 'tabs': 12
  };
  return spans[controlType] || 4;
}

function getDefaultLabel(controlType) {
  var labels = {
    'text_field': 'Text Field', 'text_area': 'Text Area', 'number_field': 'Number',
    'dropdown': 'Dropdown', 'checkbox': 'Checkbox', 'date_picker': 'Date',
    'button': 'Button', 'link': 'Link',
    'label': 'Label', 'heading': 'Heading', 'table': 'Table', 'list': 'List',
    'card': 'Card', 'tabs': 'Tabs'
  };
  return labels[controlType] || controlType;
}

			]"
		end

	designer_js_containers: STRING
		once
			Result := "[
function setupContainerDropZones() {
  console.log('[CONTAINER] Setting up container drop zones');
  document.querySelectorAll('.drop-zone').forEach(function(zone) {
    if (zone.dataset.dropSetup === 'true') {
      console.log('[CONTAINER] Drop zone already setup:', zone.dataset.parent);
      return;
    }
    zone.dataset.dropSetup = 'true';
    console.log('[CONTAINER] Attaching listeners to:', zone.dataset.parent);
    zone.addEventListener('dragover', function(e) {
      e.preventDefault();
      e.stopPropagation();
      e.dataTransfer.dropEffect = 'copy';
      this.classList.add('drag-over');
      console.log('[CONTAINER] Drag over drop zone:', this.dataset.parent);
    });
    zone.addEventListener('dragleave', function(e) {
      e.stopPropagation();
      this.classList.remove('drag-over');
    });
    zone.addEventListener('drop', function(e) {
      e.preventDefault();
      e.stopPropagation();
      this.classList.remove('drag-over');
      var controlType = e.dataTransfer.getData('text/plain');
      var parentId = this.dataset.parent;
      var panelIdx = this.dataset.panelIdx || null;
      console.log('[CONTAINER] Dropped', controlType, 'onto container', parentId, 'panel', panelIdx);
      if (controlType && parentId) {
        addControlToContainer(controlType, parentId, panelIdx);
      }
    });
  });
}

function addControlToContainer(controlType, parentId, panelIdx) {
  var controlId = controlType + '_' + Date.now();
  var defaultColSpan = getDefaultColSpan(controlType);
  var label = getDefaultLabel(controlType);

  var payload = {
    id: controlId,
    type: controlType,
    label: label,
    grid_row: 1,
    grid_col: 1,
    col_span: defaultColSpan,
    parent_id: parentId
  };
  if (panelIdx) {
    payload.panel_index = parseInt(panelIdx);
  }

  var url = '/api/specs/' + currentSpecId + '/screens/' + currentScreenId + '/controls/' + parentId + '/children';
  console.log('[CONTAINER] POST to:', url, payload);

  fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
  })
  .then(function(r) { return r.json(); })
  .then(function(data) {
    console.log('[CONTAINER] Child control added:', data);
    var canvasUrl = '/htmx/canvas/' + currentSpecId + '/' + currentScreenId;
    htmx.ajax('GET', canvasUrl, {target:'#canvas'}).then(function(){
      document.querySelectorAll('.control.selected').forEach(function(c) { c.classList.remove('selected'); });
      var newEl = document.querySelector('[data-id="' + data.id + '"]');
      if (newEl) {
        newEl.classList.add('selected');
      }
      var propsUrl = '/htmx/properties/' + currentSpecId + '/' + currentScreenId + '/' + data.id;
      htmx.ajax('GET', propsUrl, {target:'#properties'});
    });
  })
  .catch(function(err) {
    console.error('[CONTAINER] Failed to add child:', err);
    alert('Failed to add control to container: ' + err.message);
  });
}

			]"
		end

	designer_js_tabs: STRING
		once
			Result := "[
function switchTab(tabHeader, event) {
  event.stopPropagation();
  var tabsId = tabHeader.dataset.tabsId;
  var tabIdx = tabHeader.dataset.tabIdx;
  console.log('[TABS] Switching to tab', tabIdx, 'in', tabsId);

  var tabsControl = tabHeader.closest('.tabs-control');
  tabsControl.querySelectorAll('.tab-header').forEach(function(h) { h.classList.remove('active'); });
  tabHeader.classList.add('active');

  tabsControl.querySelectorAll('.tab-panel').forEach(function(p) { p.classList.remove('active'); });
  tabsControl.querySelector('.tab-panel[data-tab-idx="' + tabIdx + '"]').classList.add('active');

  fetch('/api/specs/' + currentSpecId + '/screens/' + currentScreenId + '/controls/' + tabsId + '/active-tab', {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ active_tab: parseInt(tabIdx) })
  }).then(function(r) { console.log('[TABS] Active tab saved'); });
}

function addTab(tabsId, event) {
  event.stopPropagation();
  var tabName = prompt('Enter tab name:', 'New Tab');
  if (!tabName) return;
  console.log('[TABS] Adding new tab to', tabsId, ':', tabName);

  fetch('/api/specs/' + currentSpecId + '/screens/' + currentScreenId + '/controls/' + tabsId + '/tabs', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ name: tabName })
  })
  .then(function(r) { return r.json(); })
  .then(function(data) {
    console.log('[TABS] Tab added:', data);
    var canvasUrl = '/htmx/canvas/' + currentSpecId + '/' + currentScreenId;
    htmx.ajax('GET', canvasUrl, {target:'#canvas'});
  });
}

			]"
		end

end
