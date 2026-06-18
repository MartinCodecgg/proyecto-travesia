<p>
  <script>
    // Quitar margen del <p> que Moodle crea alrededor del script
    if (document.currentScript?.parentElement?.tagName === "P") {
      document.currentScript.parentElement.style.margin = "0";
    }
    
    // Ocultar el título de la página de Moodle lo más rápido posible
    (function() {
      var style = document.createElement("style");
      style.textContent = `
         h2:first-of-type, .page-header-headings, .activity-header {
           display: none !important;
         }
      `;
      document.head.appendChild(style);
    })();
  </script>
</p>

<!-- Pantalla Falsa (Seguridad por Oscuridad) -->
<div id="pantalla-falsa">
  <p style="font-size: 15px; color: #444; line-height: 1.8;"><strong>Página de pruebaa Moodle</strong></p>
  <p style="font-size: 14px; color: #555; line-height: 1.8;">Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.</p>
  <p style="font-size: 14px; color: #555; line-height: 1.8;">Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. Vestibulum tortor quam, feugiat vitae, ultricies eget, tempor sit amet, ante. Donec eu libero sit amet quam egestas semper. Aenean ultricies mi vitae est, et nunc <span id="btn-oculto" style="cursor: text;">accumsan</span> vehicula nisi. Mauris placerat eleifend leo, quisque sit amet est et sapien ullamcorper pharetra.</p>
  <p style="font-size: 14px; color: #555; line-height: 1.8;">Curabitur pretium tincidunt lacus. Nulla gravida orci a odio. Nullam varius, turpis molestie dictum semper, quam quam congue erat, vitae sodales nisi metus a nunc. Aliquam erat volutpat. Nam dui ligula, fringilla a, euismod sodales, sollicitudin vel, wisi.</p>
</div>

<!-- Tablero Real -->
<div id="tablero" style="display: none;">
  <!-- Estilos del Tablero (removidos de aquí e inyectados dinámicamente mediante JS para evitar la sanitización de Moodle) -->

  <div id="panel-1er-anio-container">
    <h3>
      📖 Panel de 1er Año - Gestión de Alumnos Ingresantes
    </h3>

    <div class="grid-controles">
      <!-- Carga de Alumnos (CSV A) -->
      <div class="card-control">
        <h4>Cargar Alumnos (CSV A)</h4>
        <div class="input-file-wrapper">
          <input type="file" id="input-csv-a" class="input-csv-file" accept=".csv" />
          <div id="preview-csv-a" class="preview-box">
            <div class="preview-info" id="info-csv-a">Cargado: 0 alumnos.</div>
            <button id="btn-import-a" class="btn-action" disabled>Confirmar Alta</button>
          </div>
          <div id="progress-a" class="progress-bar-container">
            <div id="fill-a" class="progress-bar-fill"></div>
          </div>
          <div id="status-a" class="status-text"></div>
        </div>
      </div>

      <!-- Carga de Notas (CSV B) -->
      <div class="card-control">
        <h4>Cargar Notas (CSV B)</h4>
        <div class="input-file-wrapper">
          <input type="file" id="input-csv-b" class="input-csv-file" accept=".csv" />
          <div id="preview-csv-b" class="preview-box">
            <div class="preview-info" id="info-csv-b">Cargado: 0 notas.</div>
            <button id="btn-import-b" class="btn-action" disabled>Confirmar Notas</button>
          </div>
          <div id="progress-b" class="progress-bar-container">
            <div id="fill-b" class="progress-bar-fill"></div>
          </div>
          <div id="status-b" class="status-text"></div>
        </div>
      </div>

      <!-- Acciones de Snapshot -->
      <div class="card-control">
        <h4>Historial del Cuatrimestre</h4>
        <p style="font-size: 13px; color: #666; margin-top: 0;">Guarda una captura de los datos de todos los alumnos correspondientes a este cuatrimestre.</p>
        <div style="display: flex; flex-direction: column; gap: 10px;">
          <button id="btn-guardar-historico" class="btn-action">
            💾 Guardar Histórico 1er Año
          </button>
          <span id="cooldown-timer" style="font-size: 12px; color: #666; font-weight: 500;"></span>
        </div>
        <div id="progress-hist" class="progress-bar-container" style="margin-top: 10px;">
          <div id="fill-hist" class="progress-bar-fill"></div>
        </div>
        <div id="status-hist" class="status-text"></div>
      </div>
    </div>

    <!-- Sección Tabla de Alumnos -->
    <div class="section-tabla">
      <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 16px; margin-bottom: 16px;">
        <h4 style="margin: 0; font-size: 16px; font-weight: 600; color: #495057;">Listado de Alumnos</h4>
      </div>

      <!-- Fila de Filtros -->
      <div class="filters-row">
        <div class="filter-item">
          <label for="search-student">Buscar alumno (Nombre o DNI)</label>
          <input type="text" id="search-student" class="filter-input" placeholder="Ej: Perez o 412345..." />
        </div>
        <div class="filter-item">
          <label for="filter-alargamiento-min">Alargamiento Mínimo (%)</label>
          <input type="number" id="filter-alargamiento-min" class="filter-input" style="width: 100px;" min="0" max="100" />
        </div>
        <div class="filter-item">
          <label for="filter-alargamiento-max">Alargamiento Máximo (%)</label>
          <input type="number" id="filter-alargamiento-max" class="filter-input" style="width: 100px;" min="0" max="100" />
        </div>
      </div>

      <div class="table-responsive">
        <table class="table-students" id="table-students-list">
          <thead>
            <tr>
              <th data-sort="id_alumno">DNI ↕</th>
              <th data-sort="alumno">Nombre ↕</th>
              <th>Materias</th>
              <th data-sort="aprobadas">Aprobadas ↕</th>
              <th data-sort="ralentizacion">Alargamiento ↕</th>
            </tr>
          </thead>
          <tbody id="students-tbody">
            <tr>
              <td colspan="5" style="text-align: center; color: #666; padding: 24px;">⏳ Cargando alumnos desde Moodle...</td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Fila de Paginación -->
      <div class="pagination-row">
        <div style="font-size: 13px; color: #666;" id="pagination-info">Mostrando 0-0 de 0 alumnos</div>
        <div class="pagination-buttons" id="pagination-nav"></div>
      </div>
    </div>

  </div>
</div>

<p>
  <script>
    (function() {
      // Inyectar estilos CSS del tablero dinámicamente para evitar la sanitización de Moodle
      (function() {
        const style = document.createElement("style");
        style.textContent = `
          #panel-1er-anio-container {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
            color: #333;
            background-color: #fdfdfd;
            border: 1px solid #e3e6f0;
            border-radius: 8px;
            padding: 24px;
            margin: 20px 0;
            box-shadow: 0 0.15rem 1.75rem 0 rgba(58, 59, 69, 0.05);
          }
          
          #panel-1er-anio-container h3 {
            color: hsl(168, 60%, 35%);
            font-weight: 700;
            border-bottom: 2px solid hsl(168, 60%, 90%);
            padding-bottom: 10px;
            margin-top: 0;
            margin-bottom: 24px;
            display: flex;
            align-items: center;
            gap: 10px;
          }
          
          .grid-controles {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin-bottom: 24px;
          }
          
          .card-control {
            background: #ffffff;
            border: 1px solid #e3e6f0;
            border-radius: 6px;
            padding: 16px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.02);
          }
          
          .card-control h4 {
            margin-top: 0;
            margin-bottom: 12px;
            color: hsl(168, 60%, 25%);
            font-size: 16px;
            font-weight: 600;
          }
          
          .input-file-wrapper {
            display: flex;
            flex-direction: column;
            gap: 10px;
          }
          
          .input-csv-file {
            border: 1px solid #d1d3e2;
            border-radius: 6px;
            padding: 8px 12px;
            background: #f8f9fa;
            color: #495057;
            font-size: 13px;
            cursor: pointer;
            width: 100%;
            transition: all 0.2s ease;
            box-sizing: border-box;
          }
          
          .input-csv-file:hover {
            border-color: hsl(168, 60%, 35%);
            background: #fff;
          }
          
          .input-csv-file::file-selector-button {
            background: hsl(168, 60%, 35%);
            color: white;
            border: none;
            padding: 6px 12px;
            border-radius: 4px;
            cursor: pointer;
            margin-right: 10px;
            font-size: 13px;
            font-weight: 600;
            transition: background 0.15s ease;
          }
          
          .input-csv-file::file-selector-button:hover {
            background: hsl(168, 60%, 28%);
          }
          
          .btn-action {
            background: hsl(168, 60%, 35%);
            color: white;
            border: none;
            padding: 10px 18px;
            font-size: 14px;
            font-weight: 600;
            border-radius: 6px;
            cursor: pointer;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            gap: 8px;
            transition: background 0.15s ease;
          }
          
          .btn-action:hover:not(:disabled) {
            background: hsl(168, 60%, 28%);
          }
          
          .btn-action:disabled {
            background: #a5c7be;
            cursor: not-allowed;
          }
          
          .btn-secondary-action {
            background: #f8f9fa;
            color: #333;
            border: 1px solid #ccc;
          }
          
          .btn-secondary-action:hover:not(:disabled) {
            background: #e9ecef;
          }
          
          /* Previsualización del CSV */
          .preview-box {
            margin-top: 12px;
            background: #fdfdfd;
            border: 1px solid hsl(168, 60%, 90%);
            border-radius: 6px;
            padding: 12px;
            display: none;
          }
          
          .preview-info {
            font-size: 13px;
            color: #666;
            margin-bottom: 8px;
          }
          
          /* Barra de Progreso y Estados */
          .progress-bar-container {
            margin-top: 12px;
            background-color: #eaecf4;
            border-radius: 4px;
            height: 12px;
            overflow: hidden;
            display: none;
          }
          
          .progress-bar-fill {
            height: 100%;
            background-color: hsl(168, 60%, 35%);
            width: 0%;
            transition: width 0.1s ease;
          }
          
          .status-text {
            font-size: 13px;
            font-weight: 500;
            margin-top: 6px;
            color: #555;
          }
          
          /* Filtros y Tabla */
          .section-tabla {
            margin-top: 24px;
            background: white;
            border: 1px solid #e3e6f0;
            border-radius: 6px;
            padding: 16px;
          }
          
          .filters-row {
            display: flex;
            flex-wrap: wrap;
            gap: 16px;
            margin-bottom: 16px;
            align-items: flex-end;
          }
          
          .filter-item {
            display: flex;
            flex-direction: column;
            gap: 6px;
          }
          
          .filter-item label {
            font-size: 12px;
            font-weight: 600;
            color: #555;
          }
          
          .filter-input {
            padding: 8px 12px;
            border: 1px solid #d1d3e2;
            border-radius: 6px;
            font-size: 14px;
          }
          
          .filter-input:focus {
            outline: none;
            border-color: hsl(168, 60%, 35%);
          }
          
          /* Tabla */
          .table-responsive {
            overflow-x: auto;
            margin-bottom: 16px;
          }
          
          .table-students {
            width: 100%;
            border-collapse: collapse;
            font-size: 14px;
          }
          
          .table-students th, .table-students td {
            padding: 12px;
            border-bottom: 1px solid #e3e6f0;
            text-align: left;
          }
          
          .table-students th {
            background-color: #f8f9fa;
            font-weight: 700;
            color: #495057;
            cursor: pointer;
            user-select: none;
          }
          
          .table-students th:hover {
            background-color: #e9ecef;
          }
          
          .table-students tr:hover {
            background-color: #f8f9fa;
          }
          
          /* Badges */
          .badge-alargamiento {
            display: inline-block;
            padding: 4px 8px;
            font-size: 12px;
            font-weight: 600;
            border-radius: 12px;
          }
          
          .badge-red {
            background-color: #fadbd8;
            color: #78281f;
          }
          
          .badge-yellow {
            background-color: #fdebd0;
            color: #7e5109;
          }
          
          .badge-green {
            background-color: #d4efdf;
            color: #145a32;
          }
          
          .badge-neutral {
            background-color: #ebedef;
            color: #5d6d7e;
          }
          
          .chip-materia {
            display: inline-block;
            background: hsl(168, 60%, 95%);
            color: hsl(168, 60%, 20%);
            border: 1px solid hsl(168, 60%, 85%);
            border-radius: 4px;
            padding: 2px 6px;
            margin: 2px;
            font-size: 12px;
          }
          
          /* Paginación */
          .pagination-row {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-top: 16px;
          }
          
          .pagination-buttons {
            display: flex;
            gap: 6px;
          }
          
          .page-btn {
            padding: 6px 12px;
            background: #f8f9fa;
            border: 1px solid #ccc;
            border-radius: 4px;
            cursor: pointer;
            font-size: 13px;
          }
          
          .page-btn.active {
            background: hsl(168, 60%, 35%);
            color: white;
            border-color: hsl(168, 60%, 35%);
          }
          
          .page-btn:hover:not(.active):not(:disabled) {
            background: #e9ecef;
          }
          
          .page-btn:disabled {
            opacity: 0.5;
            cursor: not-allowed;
          }
        `;
        document.head.appendChild(style);
      })();

      // Revelado del tablero con click en accumsan
      document.getElementById('btn-oculto').addEventListener('click', function() {
        document.getElementById('pantalla-falsa').style.display = 'none';
        document.getElementById('tablero').style.display = 'block';
        initPanel(); // Inicializar el panel al revelar
      });

      // Configuración de Moodle
      const MOODLE_BASE_URL = window.location.origin;
      const DATAID_DB_1ER_ANIO = 19;       // DB 1er Año
      const DATAID_DB_HIST_1ER_ANIO = 20;  // DB Histórico 1er Año
      const MATERIAS_ESPERADAS_1ER_ANIO = 7;
      const COOLDOWN_SNAPSHOT_SEG = 30;

      // Estado de datos en memoria
      let alumnosCargados = [];
      let mappedFieldsDB = null;
      let mappedFieldsHist = null;

      // Variables para paginación, orden y filtros
      let pageActual = 1;
      const PAGE_SIZE = 30;
      let filterText = "";
      let filterMinAlarg = null;
      let filterMaxAlarg = null;
      let colOrden = "alumno";
      let dirOrden = "asc"; // asc o desc

      // Parsea el JSON almacenado con formato Moodle (limpia etiquetas HTML)
      function parseCleanJSON(rawText) {
        if (!rawText) return [];
        let clean = rawText.replace(/<[^>]*>/g, '');
        clean = clean.replace(/&nbsp;/g, ' ').replace(/&quot;/g, '"');
        clean = clean.replace(/\s+/g, ' ').trim();
        try {
          return JSON.parse(clean);
        } catch (e) {
          console.error("Error al parsear JSON:", rawText, e);
          return [];
        }
      }

      // Parsea los alumnos de la respuesta HTML de Moodle
      function parseDatabaseHTML(html) {
        const parser = new DOMParser();
        const doc = parser.parseFromString(html, 'text/html');
        const entryWrappers = doc.querySelectorAll('.defaulttemplate-listentry, .defaulttemplate-single-body, .defaulttemplate-list-body, .defaulttemplate-single');
        const records = [];

        let targets = Array.from(entryWrappers);
        if (targets.length === 0) {
          const cards = doc.querySelectorAll('.card');
          if (cards.length > 0) targets = Array.from(cards);
        }

        // Filtrar wrappers para quedarnos sólo con los más específicos (descartar ancestros contenedores)
        targets = targets.filter(t => !targets.some(other => other !== t && t.contains(other)));

        targets.forEach(wrapper => {
          const fields = {};
          const rows = wrapper.querySelectorAll('.row, div');
          rows.forEach(row => {
            const labelEl = row.querySelector('.font-weight-bold');
            if (labelEl) {
              const key = labelEl.textContent.trim().toLowerCase();
              const valEl = row.querySelector('.col-8, .col-lg-9, p.mt-2, .data-field-html');
              if (valEl) {
                fields[key] = valEl.textContent.trim();
              } else {
                const nextEl = labelEl.nextElementSibling;
                if (nextEl) {
                  fields[key] = nextEl.textContent.trim();
                }
              }
            }
          });

          const editLink = wrapper.querySelector('a[href*="rid="], a[href*="delete="]');
          if (editLink) {
            const match = editLink.href.match(/(?:rid|delete)=(\d+)/);
            if (match) {
              fields.rid = match[1];
            }
          }

          if (Object.keys(fields).length > 0) {
            records.push(fields);
          }
        });

        // Desduplicar registros finales por 'rid' y por 'id_alumno' (DNI) como doble reaseguro
        const uniqueRecords = [];
        const seenRids = new Set();
        const seenDnis = new Set();

        records.forEach(r => {
          const ridKey = r.rid || null;
          const dniKey = r.id_alumno || null;

          let isDuplicate = false;
          if (ridKey && seenRids.has(ridKey)) isDuplicate = true;
          if (dniKey && seenDnis.has(dniKey)) isDuplicate = true;

          if (!isDuplicate) {
            if (ridKey) seenRids.add(ridKey);
            if (dniKey) seenDnis.add(dniKey);
            uniqueRecords.push(r);
          }
        });

        return uniqueRecords;
      }

      // Obtiene sesskey
      function getSesskey() {
        if (window.M && M.cfg && M.cfg.sesskey) return M.cfg.sesskey;
        const meta = document.querySelector('meta[name="sesskey"]');
        if (meta) return meta.getAttribute("content");
        const input = document.querySelector('input[name="sesskey"]');
        if (input) return input.value;
        const link = document.querySelector('a[href*="sesskey="]');
        if (link) {
          const match = link.href.match(/sesskey=([a-zA-Z0-9]+)/);
          if (match) return match[1];
        }
        return null;
      }

      // Carga todos los registros de la DB paginada en Moodle
      async function fetchAllDatabaseEntries(dataId) {
        const baseUrl = `${MOODLE_BASE_URL}/mod/data/view.php?d=${dataId}&perpage=1000`;
        const response = await fetch(baseUrl);
        const html = await response.text();
        let entries = parseDatabaseHTML(html);

        const parser = new DOMParser();
        const doc = parser.parseFromString(html, 'text/html');
        const pageLinks = doc.querySelectorAll('.pagination .page-item a[href*="page="]');
        const pageNumbers = [];
        pageLinks.forEach(link => {
          const match = link.href.match(/page=(\d+)/);
          if (match) pageNumbers.push(parseInt(match[1]));
        });

        if (pageNumbers.length > 0) {
          const maxPage = Math.max(...pageNumbers);
          const promises = [];
          for (let p = 1; p <= maxPage; p++) {
            promises.push(
              fetch(`${MOODLE_BASE_URL}/mod/data/view.php?d=${dataId}&perpage=1000&page=${p}`)
                .then(r => r.text())
                .then(pageHtml => parseDatabaseHTML(pageHtml))
            );
          }
          const restResults = await Promise.all(promises);
          restResults.forEach(res => {
            entries = entries.concat(res);
          });
        }
        return entries;
      }

      // Obtiene el mapeo dinámico de campos
      async function getFieldMapping(dataId) {
        const url = `${MOODLE_BASE_URL}/mod/data/edit.php?d=${dataId}`;
        const response = await fetch(url);
        const html = await response.text();
        const parser = new DOMParser();
        const doc = parser.parseFromString(html, 'text/html');
        const mapping = {};

        // Mapeo por labels del input
        const labels = doc.querySelectorAll('label[for^="field_"]');
        labels.forEach(label => {
          const labelText = label.textContent.trim().toLowerCase();
          const forAttr = label.getAttribute('for');
          const match = forAttr.match(/field_(\d+)/);
          if (match && labelText) {
            mapping[labelText] = match[1];
          }
        });

        // Fallback por contenedores
        const boldLabels = doc.querySelectorAll('.font-weight-bold');
        boldLabels.forEach(label => {
          const labelText = label.textContent.trim().toLowerCase();
          if (mapping[labelText]) return;

          let parent = label.parentElement;
          let input = null;
          for (let depth = 0; depth < 3 && parent; depth++) {
            input = parent.querySelector('[name^="field_"], [id^="field_"]');
            if (input) break;
            parent = parent.parentElement;
          }

          if (input) {
            const nameOrId = input.name || input.id;
            const match = nameOrId.match(/field_(\d+)/);
            if (match) {
              mapping[labelText] = match[1];
            }
          }
        });

        return mapping;
      }

      // Calcula cuatrimestre actual
      function getCuatrimestreActual() {
        const date = new Date();
        const year = date.getFullYear();
        const month = date.getMonth(); // 0 a 11
        const cuat = month <= 6 ? 1 : 2;
        return `${year}-${cuat}`;
      }

      // Inicializa los datos del panel
      async function initPanel() {
        try {
          // Cargar alumnos y resolver mapeo en paralelo
          const [alumnos, fields] = await Promise.all([
            fetchAllDatabaseEntries(DATAID_DB_1ER_ANIO),
            getFieldMapping(DATAID_DB_1ER_ANIO)
          ]);

          alumnosCargados = alumnos;
          mappedFieldsDB = fields;

          renderTable();
          setupEventListeners();
        } catch (e) {
          console.error("Error al iniciar el tablero:", e);
          document.getElementById('students-tbody').innerHTML =
            `<tr><td colspan="5" style="text-align: center; color: #c0392b; padding: 24px; font-weight: bold;">❌ Error al conectar con la base de datos de Moodle. Recarga la página.</td></tr>`;
        }
      }

      // Setup de Event Listeners
      let fileAData = [];
      let fileBData = [];

      function setupEventListeners() {
        // Selector CSV A
        const inputA = document.getElementById('input-csv-a');
        inputA.addEventListener('change', function(e) {
          const file = e.target.files[0];
          if (!file) return;

          const reader = new FileReader();
          reader.onload = function(evt) {
            const parsed = parseCSV(evt.target.result);
            fileAData = parsed;

            // Validar que tenga las columnas correctas
            if (parsed.length > 0 && parsed[0].hasOwnProperty('id_alumno') && parsed[0].hasOwnProperty('alumno')) {
              document.getElementById('info-csv-a').textContent = `Detectados: ${parsed.length} alumnos para dar de alta.`;
              document.getElementById('preview-csv-a').style.display = 'block';
              document.getElementById('btn-import-a').disabled = false;
            } else {
              document.getElementById('info-csv-a').textContent = `❌ Formato inválido. Debe tener columnas: id_alumno, alumno, año, cuatrimestre.`;
              document.getElementById('preview-csv-a').style.display = 'block';
              document.getElementById('btn-import-a').disabled = true;
            }
          };
          reader.readAsText(file, "UTF-8");
        });

        // Selector CSV B
        const inputB = document.getElementById('input-csv-b');
        inputB.addEventListener('change', function(e) {
          const file = e.target.files[0];
          if (!file) return;

          const reader = new FileReader();
          reader.onload = function(evt) {
            const parsed = parseCSV(evt.target.result);
            fileBData = parsed;

            // Validar columnas
            if (parsed.length > 0 && parsed[0].hasOwnProperty('id_alumno') && parsed[0].hasOwnProperty('materia') && parsed[0].hasOwnProperty('nota')) {
              document.getElementById('info-csv-b').textContent = `Detectados: ${parsed.length} materias/notas registradas.`;
              document.getElementById('preview-csv-b').style.display = 'block';
              document.getElementById('btn-import-b').disabled = false;
            } else {
              document.getElementById('info-csv-b').textContent = `❌ Formato inválido. Debe tener columnas: id_alumno, materia, nota.`;
              document.getElementById('preview-csv-b').style.display = 'block';
              document.getElementById('btn-import-b').disabled = true;
            }
          };
          reader.readAsText(file, "UTF-8");
        });

        // Botón Importar A
        document.getElementById('import-actions-a')?.remove(); // Evitar duplicaciones
        const btnImportA = document.getElementById('btn-import-a');
        btnImportA.addEventListener('click', async function() {
          btnImportA.disabled = true;
          document.getElementById('progress-a').style.display = 'block';
          const fill = document.getElementById('fill-a');
          const status = document.getElementById('status-a');

          status.style.color = '#555';
          status.textContent = '⏳ Iniciando importación...';

          // Filtrar los que no existen
          const existentes = new Set(alumnosCargados.map(a => a.id_alumno));
          const nuevos = fileAData.filter(row => row.id_alumno && !existentes.has(row.id_alumno));

          if (nuevos.length === 0) {
            status.style.color = '#27ae60';
            status.textContent = '✅ Todos los alumnos del CSV ya existen en el sistema.';
            fill.style.width = '100%';
            return;
          }

          let correctos = 0;
          let fallidos = 0;
          const sesskey = getSesskey();

          for (let i = 0; i < nuevos.length; i++) {
            const row = nuevos[i];
            status.textContent = `⏳ Subiendo alumno: ${row.alumno} (${i+1}/${nuevos.length})...`;

            const formData = new FormData();
            formData.append("d", DATAID_DB_1ER_ANIO.toString());
            formData.append("rid", "0");
            formData.append("sesskey", sesskey);
            formData.append("saveandview", "Guardar");
            formData.append("field_" + mappedFieldsDB.id_alumno, row.id_alumno);
            formData.append("field_" + mappedFieldsDB.alumno, row.alumno);
            formData.append("field_" + mappedFieldsDB.anio_ingreso, row.ano || row.anio || row.anio_ingreso || new Date().getFullYear().toString());
            formData.append("field_" + mappedFieldsDB.cuatrimestre_ingreso, row.cuatrimestre || row.cuatrimestre_ingreso || "1");
            formData.append("field_" + mappedFieldsDB.aprobadas, "0");
            formData.append("field_" + mappedFieldsDB.ralentizacion, "100");
            formData.append("field_" + mappedFieldsDB.materias, "[]");

            try {
              const res = await fetch(`${MOODLE_BASE_URL}/mod/data/edit.php`, {
                method: "POST",
                body: formData,
                credentials: "include"
              });
              if (res.status === 200 || res.status === 303 || res.type === "opaqueredirect") {
                correctos++;
              } else {
                fallidos++;
              }
            } catch (err) {
              fallidos++;
            }

            // Barra de progreso
            const percent = Math.round(((i + 1) / nuevos.length) * 100);
            fill.style.width = percent + '%';

            // Delay de 500ms
            await new Promise(r => setTimeout(r, 500));
          }

          status.style.color = fallidos === 0 ? '#27ae60' : '#c0392b';
          status.textContent = `✅ Finalizado. Exitosos: ${correctos}. Fallidos: ${fallidos}.`;

          // Recargar tabla
          initPanel();
        });

        // Botón Importar B
        const btnImportB = document.getElementById('btn-import-b');
        btnImportB.addEventListener('click', async function() {
          btnImportB.disabled = true;
          document.getElementById('progress-b').style.display = 'block';
          const fill = document.getElementById('fill-b');
          const status = document.getElementById('status-b');

          status.style.color = '#555';
          status.textContent = '⏳ Procesando notas...';

          // Agrupar las materias y notas por id_alumno
          const notasPorAlumno = {};
          fileBData.forEach(row => {
            if (!row.id_alumno || !row.materia || !row.nota) return;
            if (!notasPorAlumno[row.id_alumno]) {
              notasPorAlumno[row.id_alumno] = [];
            }
            notasPorAlumno[row.id_alumno].push({
              materia: row.materia,
              nota: parseFloat(row.nota)
            });
          });

          // Obtener alumnos actuales para mapear sus rids y datos previos
          const totalAlumnos = Object.keys(notasPorAlumno);
          let correctos = 0;
          let fallidos = 0;
          const sesskey = getSesskey();

          for (let i = 0; i < totalAlumnos.length; i++) {
            const idAlumno = totalAlumnos[i];
            const alumnoDB = alumnosCargados.find(a => a.id_alumno === idAlumno);

            if (!alumnoDB || !alumnoDB.rid) {
              console.warn(`Alumno ${idAlumno} no encontrado en la base de datos de 1er año. Omitido.`);
              fallidos++;
              continue;
            }

            status.textContent = `⏳ Actualizando notas del alumno con DNI ${idAlumno} (${i+1}/${totalAlumnos.length})...`;

            // Materias previas
            let materiasArray = parseCleanJSON(alumnoDB.materias);

            // Merge con las notas del CSV (sobrescribe si coincide el nombre de la materia)
            const nuevasNotas = notasPorAlumno[idAlumno];
            nuevasNotas.forEach(nueva => {
              const prevIndex = materiasArray.findIndex(m => m.materia.trim().toLowerCase() === nueva.materia.trim().toLowerCase());
              if (prevIndex > -1) {
                materiasArray[prevIndex].nota = nueva.nota;
              } else {
                materiasArray.push(nueva);
              }
            });

            // Recalcular aprobadas (nota >= 6) y alargamiento
            const aprobadas = materiasArray.filter(m => m.nota >= 6).length;
            const alargamiento = Math.max(0, Math.round((1 - (aprobadas / MATERIAS_ESPERADAS_1ER_ANIO)) * 100));

            // Guardar en Moodle
            const formData = new FormData();
            formData.append("d", DATAID_DB_1ER_ANIO.toString());
            formData.append("rid", alumnoDB.rid);
            formData.append("sesskey", sesskey);
            formData.append("saveandview", "Guardar");

            // Re-enviar datos obligatorios o estables
            formData.append("field_" + mappedFieldsDB.id_alumno, alumnoDB.id_alumno);
            formData.append("field_" + mappedFieldsDB.alumno, alumnoDB.alumno);
            formData.append("field_" + mappedFieldsDB.anio_ingreso, alumnoDB.anio_ingreso || "");
            formData.append("field_" + mappedFieldsDB.cuatrimestre_ingreso, alumnoDB.cuatrimestre_ingreso || "");

            // Campos calculados
            formData.append("field_" + mappedFieldsDB.aprobadas, aprobadas.toString());
            formData.append("field_" + mappedFieldsDB.ralentizacion, alargamiento.toString());
            formData.append("field_" + mappedFieldsDB.materias, JSON.stringify(materiasArray));

            try {
              const res = await fetch(`${MOODLE_BASE_URL}/mod/data/edit.php`, {
                method: "POST",
                body: formData,
                credentials: "include"
              });
              if (res.status === 200 || res.status === 303 || res.type === "opaqueredirect") {
                correctos++;
              } else {
                fallidos++;
              }
            } catch (err) {
              fallidos++;
            }

            const percent = Math.round(((i + 1) / totalAlumnos.length) * 100);
            fill.style.width = percent + '%';

            await new Promise(r => setTimeout(r, 500));
          }

          status.style.color = fallidos === 0 ? '#27ae60' : '#c0392b';
          status.textContent = `✅ Finalizado. Exitosos: ${correctos}. Fallidos: ${fallidos}.`;

          initPanel();
        });

        // Botón Guardar Histórico
        const btnHist = document.getElementById('btn-guardar-historico');
        btnHist.addEventListener('click', async function() {
          btnHist.disabled = true;
          document.getElementById('progress-hist').style.display = 'block';
          const fill = document.getElementById('fill-hist');
          const status = document.getElementById('status-hist');

          status.style.color = '#555';
          status.textContent = '⏳ Analizando registros del cuatrimestre actual...';

          // Obtener cuatrimestre actual y mapeo de histórico
          const cuatActual = getCuatrimestreActual();

          try {
            mappedFieldsHist = await getFieldMapping(DATAID_DB_HIST_1ER_ANIO);
          } catch(err) {
            status.style.color = '#c0392b';
            status.textContent = '❌ Error al obtener mapeo de histórico.';
            btnHist.disabled = false;
            return;
          }

          // Filtrar registros editados en este cuatrimestre
          // Analizamos la fecha de última modificación (ej: "11 jun 2026")
          const alumnosAHistorial = alumnosCargados.filter(a => {
            const modDateStr = a["editado por última vez"];
            if (!modDateStr) return false;

            // Mapeo simple de meses en español
            const meses = {
              'ene': 0, 'feb': 1, 'mar': 2, 'abr': 3, 'may': 4, 'jun': 5,
              'jul': 6, 'ago': 7, 'sep': 8, 'oct': 9, 'nov': 10, 'dic': 11
            };

            // Intentar formatear la fecha
            // Formato habitual Moodle: "11 jun 2026"
            const parts = modDateStr.toLowerCase().split(' ');
            if (parts.length < 3) return false;

            const dia = parseInt(parts[0]);
            const mesName = parts[1].substring(0, 3);
            const anio = parseInt(parts[2]);
            const mes = meses[mesName];

            if (isNaN(dia) || isNaN(anio) || mes === undefined) return false;

            const modDate = new Date(anio, mes, dia);
            const modYear = modDate.getFullYear();
            const modMonth = modDate.getMonth();
            const modCuat = modMonth <= 6 ? 1 : 2;
            const cuatRegistro = `${modYear}-${modCuat}`;

            return cuatRegistro === cuatActual;
          });

          if (alumnosAHistorial.length === 0) {
            status.style.color = '#e67e22';
            status.textContent = '⚠️ No hay alumnos que hayan tenido actualizaciones en este cuatrimestre.';
            fill.style.width = '100%';
            activarCooldownSnapshot();
            return;
          }

          let correctos = 0;
          let fallidos = 0;
          const sesskey = getSesskey();
          const fechaSnapshot = new Date().toISOString().split('T')[0];

          for (let i = 0; i < alumnosAHistorial.length; i++) {
            const al = alumnosAHistorial[i];
            status.textContent = `⏳ Guardando snapshot de: ${al.alumno} (${i+1}/${alumnosAHistorial.length})...`;

            const formData = new FormData();
            formData.append("d", DATAID_DB_HIST_1ER_ANIO.toString());
            formData.append("rid", "0");
            formData.append("sesskey", sesskey);
            formData.append("saveandview", "Guardar");

            formData.append("field_" + mappedFieldsHist.id_alumno, al.id_alumno);
            formData.append("field_" + mappedFieldsHist.alumno, al.alumno);
            formData.append("field_" + mappedFieldsHist.cuatrimestre, cuatActual);
            formData.append("field_" + mappedFieldsHist.fecha_snapshot, fechaSnapshot);
            formData.append("field_" + mappedFieldsHist.aprobadas, al.aprobadas || "0");
            formData.append("field_" + mappedFieldsHist.ralentizacion, al.ralentizacion || "100");

            try {
              const res = await fetch(`${MOODLE_BASE_URL}/mod/data/edit.php`, {
                method: "POST",
                body: formData,
                credentials: "include"
              });
              if (res.status === 200 || res.status === 303 || res.type === "opaqueredirect") {
                correctos++;
              } else {
                fallidos++;
              }
            } catch (err) {
              fallidos++;
            }

            const percent = Math.round(((i + 1) / alumnosAHistorial.length) * 100);
            fill.style.width = percent + '%';

            await new Promise(r => setTimeout(r, 500));
          }

          status.style.color = fallidos === 0 ? '#27ae60' : '#c0392b';
          status.textContent = `✅ Historial guardado correctamente. Registrados: ${correctos}. Fallidos: ${fallidos}.`;

          activarCooldownSnapshot();
        });

        // Filtros e inputs de búsqueda
        const searchInput = document.getElementById('search-student');
        searchInput.addEventListener('input', function(e) {
          filterText = e.target.value.toLowerCase().trim();
          pageActual = 1;
          renderTable();
        });

        const minAlargInput = document.getElementById('filter-alargamiento-min');
        minAlargInput.addEventListener('input', function(e) {
          filterMinAlarg = e.target.value !== "" ? parseFloat(e.target.value) : null;
          pageActual = 1;
          renderTable();
        });

        const maxAlargInput = document.getElementById('filter-alargamiento-max');
        maxAlargInput.addEventListener('input', function(e) {
          filterMaxAlarg = e.target.value !== "" ? parseFloat(e.target.value) : null;
          pageActual = 1;
          renderTable();
        });

        // Botón Exportar CSV removido

        // Sorting de columnas
        const headers = document.querySelectorAll('.table-students th[data-sort]');
        headers.forEach(h => {
          h.addEventListener('click', function() {
            const col = h.getAttribute('data-sort');
            if (colOrden === col) {
              dirOrden = dirOrden === 'asc' ? 'desc' : 'asc';
            } else {
              colOrden = col;
              dirOrden = 'asc';
            }
            renderTable();
          });
        });
      }

      // Activa cooldown del botón snapshot
      function activarCooldownSnapshot() {
        const btn = document.getElementById('btn-guardar-historico');
        const timer = document.getElementById('cooldown-timer');
        let remaining = COOLDOWN_SNAPSHOT_SEG;

        btn.disabled = true;

        const interval = setInterval(function() {
          remaining--;
          if (remaining <= 0) {
            clearInterval(interval);
            btn.disabled = false;
            timer.textContent = '';
            document.getElementById('progress-hist').style.display = 'none';
            document.getElementById('status-hist').textContent = '';
          } else {
            timer.textContent = `⏳ Esperar ${remaining}s antes de guardar de nuevo.`;
          }
        }, 1000);
      }

      // Parsea CSV genérico (separa por líneas y comas, respetando comillas)
      function parseCSV(text) {
        const lines = text.split(/\r?\n/);
        if (lines.length === 0) return [];

        function parseLine(line) {
          const result = [];
          let current = "";
          let inQuotes = false;
          for (let i = 0; i < line.length; i++) {
            const char = line[i];
            if (char === '"') {
              inQuotes = !inQuotes;
            } else if (char === ',' && !inQuotes) {
              result.push(current.trim());
              current = "";
            } else {
              current += char;
            }
          }
          result.push(current.trim());
          return result;
        }

        const rawHeaders = parseLine(lines[0]);
        // Normalizar cabeceras a minúsculas y quitar acentos/caracteres especiales
        const headers = rawHeaders.map(h =>
          h.toLowerCase()
           .normalize("NFD")
           .replace(/[\u0300-\u036f]/g, "") // Remueve acentos
           .replace(/[^a-z0-9_]/g, "")     // Solo letras, números y guión bajo
        );

        const rows = [];
        for (let i = 1; i < lines.length; i++) {
          if (!lines[i].trim()) continue;
          const values = parseLine(lines[i]);
          if (values.length < headers.length) continue;
          const row = {};
          headers.forEach((header, index) => {
            row[header] = values[index];
          });
          rows.push(row);
        }
        return rows;
      }

      // Renderiza la tabla de estudiantes con ordenamiento, filtrado y paginación
      function renderTable() {
        const tbody = document.getElementById('students-tbody');

        // 1. Filtrado
        let alumnosFiltrados = alumnosCargados.filter(al => {
          // Búsqueda textual
          const nombreMatch = al.alumno ? al.alumno.toLowerCase().includes(filterText) : false;
          const dniMatch = al.id_alumno ? al.id_alumno.toLowerCase().includes(filterText) : false;
          if (filterText && !nombreMatch && !dniMatch) return false;

          // Alargamiento (ralentización)
          const alarg = al.ralentizacion ? parseFloat(al.ralentizacion) : 0;
          if (filterMinAlarg !== null && alarg < filterMinAlarg) return false;
          if (filterMaxAlarg !== null && alarg > filterMaxAlarg) return false;

          return true;
        });

        // 2. Ordenamiento
        alumnosFiltrados.sort((a, b) => {
          let valA = a[colOrden] || "";
          let valB = b[colOrden] || "";

          // Tratar números
          if (colOrden === 'aprobadas' || colOrden === 'ralentizacion') {
            valA = valA !== "" ? parseFloat(valA) : 0;
            valB = valB !== "" ? parseFloat(valB) : 0;
          } else {
            valA = valA.toString().toLowerCase();
            valB = valB.toString().toLowerCase();
          }

          if (valA < valB) return dirOrden === 'asc' ? -1 : 1;
          if (valA > valB) return dirOrden === 'asc' ? 1 : -1;
          return 0;
        });

        // 3. Paginación
        const total = alumnosFiltrados.length;
        const totalPaginas = Math.ceil(total / PAGE_SIZE) || 1;
        if (pageActual > totalPaginas) pageActual = totalPaginas;

        const inicio = (pageActual - 1) * PAGE_SIZE;
        const fin = Math.min(inicio + PAGE_SIZE, total);
        const alumnosPagina = alumnosFiltrados.slice(inicio, fin);

        // Renderizar filas
        if (alumnosPagina.length === 0) {
          tbody.innerHTML = `<tr><td colspan="5" style="text-align: center; color: #666; padding: 24px;">No se encontraron alumnos con los filtros seleccionados.</td></tr>`;
          document.getElementById('pagination-info').textContent = 'Mostrando 0 de 0 alumnos';
          document.getElementById('pagination-nav').innerHTML = '';
          return;
        }

        let html = "";
        alumnosPagina.forEach(al => {
          const materias = parseCleanJSON(al.materias);
          let materiasHTML = "";
          if (materias.length === 0) {
            materiasHTML = `<span style="color: #888; font-style: italic;">Sin notas cargadas</span>`;
          } else {
            materiasHTML = materias.map(m => `<span class="chip-materia">${m.materia}: <strong>${m.nota}</strong></span>`).join(' ');
          }

          // Badge de alargamiento
          const alarg = al.ralentizacion !== undefined ? parseFloat(al.ralentizacion) : null;
          let badgeClass = "badge-neutral";
          let badgeText = "Sin datos";

          if (alarg !== null) {
            badgeText = `${alarg.toFixed(1)}%`;
            if (materias.length === 0) {
              // Estudiante recién ingresado sin materias cargadas
              badgeClass = "badge-neutral";
              badgeText = "-";
            } else if (alarg >= 80) {
              badgeClass = "badge-red";
            } else if (alarg >= 40) {
              badgeClass = "badge-yellow";
            } else {
              badgeClass = "badge-green";
            }
          }

          html += `
            <tr>
              <td><strong>${al.id_alumno || '-'}</strong></td>
              <td>${al.alumno || '-'}</td>
              <td>${materiasHTML}</td>
              <td style="text-align: center;">${al.aprobadas !== undefined ? al.aprobadas : '0'}</td>
              <td>
                <span class="badge-alargamiento ${badgeClass}">${badgeText}</span>
              </td>
            </tr>
          `;
        });
        tbody.innerHTML = html;

        // Info de paginación
        document.getElementById('pagination-info').textContent = `Mostrando ${total === 0 ? 0 : inicio + 1}-${fin} de ${total} alumnos`;

        // Renderizar botones de navegación
        let navHtml = "";
        navHtml += `<button class="page-btn" ${pageActual === 1 ? 'disabled' : ''} id="btn-prev-page">◀ Prev</button>`;
        for (let i = 1; i <= totalPaginas; i++) {
          if (i === 1 || i === totalPaginas || (i >= pageActual - 2 && i <= pageActual + 2)) {
            navHtml += `<button class="page-btn ${pageActual === i ? 'active' : ''}" data-page="${i}">${i}</button>`;
          } else if (i === pageActual - 3 || i === pageActual + 3) {
            navHtml += `<span style="padding: 0 4px; align-self: flex-end;">...</span>`;
          }
        }
        navHtml += `<button class="page-btn" ${pageActual === totalPaginas ? 'disabled' : ''} id="btn-next-page">Sig ▶</button>`;

        const navContainer = document.getElementById('pagination-nav');
        navContainer.innerHTML = navHtml;

        // Registrar eventos de navegación
        document.getElementById('btn-prev-page').addEventListener('click', () => { pageActual--; renderTable(); });
        document.getElementById('btn-next-page').addEventListener('click', () => { pageActual++; renderTable(); });
        navContainer.querySelectorAll('.page-btn[data-page]').forEach(btn => {
          btn.addEventListener('click', function() {
            pageActual = parseInt(btn.getAttribute('data-page'));
            renderTable();
          });
        });
      }

      // Función exportarListadoActual removida

    })();

  </script>
</p>
