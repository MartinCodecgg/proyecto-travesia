# Código Específico de la Pestaña "Estados de Encuesta"

Este documento agrupa todo el código (HTML, CSS y JS) relacionado con la pestaña **"Estado Encuesta Cuatrimestral"** extraído de [tablero_principal_renzo.html](file:///c:/Users/defin/Desktop/FACULTAD/Facultad%202026/AEC/proyecto-travesia/others-scripts/tablero_principal_renzo.html).

---

## 1. Código HTML

### Botón de Navegación (Pestaña)
```html
<button type="button" class="tab-btn" data-tab="tab-estado-encuestas">📝 Estado Encuesta Cuatrimestral</button>
```

### Contenedor de la Pestaña y Tabla
```html
<!-- Tab 5: Estado Encuesta Cuatrimestral -->
<div id="tab-estado-encuestas" class="tab-content">
  <div class="section-card">
    <h3 style="margin-top: 0; margin-bottom: 16px; color: hsl(168, 60%, 25%);">
      📝 Estado de Encuesta Cuatrimestral
    </h3>

    <div style="display: flex; gap: 10px; margin-bottom: 16px; flex-wrap: wrap;">
      <button
        type="button"
        id="btn-encuesta-cuat-si"
        class="btn-action"
      >
        Hicieron la encuesta
      </button>

      <button
        type="button"
        id="btn-encuesta-cuat-no"
        class="btn-action btn-secondary-action"
      >
        No hicieron la encuesta
      </button>
    </div>

    <div style="display: flex; gap: 10px; margin-bottom: 16px; flex-wrap: wrap; align-items: center;">
      <input
        type="text"
        id="filter-estado-encuesta-cuat"
        class="filter-input"
        placeholder="Buscar por nombre, DNI o correo..."
        autocomplete="off"
        style="min-width: 260px; flex: 1;"
      />

      <button
        type="button"
        id="btn-clear-filter-estado-encuesta-cuat"
        class="btn-action btn-secondary-action"
      >
        Limpiar filtro
      </button>
    </div>

    <div class="table-responsive">
      <table class="table-dashboard" id="table-estado-encuesta-cuat">
        <thead>
          <tr>
            <th>Nombre</th>
            <th>DNI</th>
            <th>Correo</th>
          </tr>
        </thead>
        <tbody id="estado-encuesta-cuat-tbody">
          <tr>
            <td colspan="3" style="text-align: center; padding: 32px; color: #666;">
              Elegí una opción para cargar la lista desde Moodle.
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <div style="margin-top: 16px; padding: 14px 18px; border-radius: 8px; background: #e8f8f0; border: 1px solid #b7e4c7; color: #145a32; font-weight: 700; display: inline-block;">
      Total en lista: <span id="total-estado-encuesta-cuat">0</span>
    </div>
  </div>
</div>
```

---

## 2. Código CSS Asociado
Estilos generales aplicados a los componentes de esta pestaña:

```css
.tab-content {
  display: none;
}

.tab-content.active {
  display: block;
}

.section-card {
  background: white;
  border: 1px solid #e3e6f0;
  border-radius: 6px;
  padding: 20px;
  box-shadow: 0 4px 6px rgba(0,0,0,0.02);
}

.filter-input {
  padding: 8px 12px;
  border: 1px solid #d1d3e2;
  border-radius: 6px;
  font-size: 13px;
  color: #333;
  background-color: white;
  height: 38px;
  transition: border-color 0.15s ease;
}

.filter-input:focus {
  outline: none;
  border-color: hsl(168, 60%, 35%);
}

.btn-action {
  background: hsl(168, 60%, 35%);
  color: white !important;
  border: none;
  padding: 8px 14px;
  font-size: 13px;
  font-weight: 600;
  border-radius: 6px;
  cursor: pointer;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  height: 38px;
  transition: background 0.15s ease;
}

.btn-action:hover:not(:disabled) {
  background: hsl(168, 60%, 28%);
}

.btn-action:disabled {
  background: #a5c7be;
  cursor: not-allowed;
  opacity: 0.7;
}

.btn-secondary-action {
  background: #f8f9fa;
  color: #495057 !important;
  border: 1px solid #d1d3e2;
}

.btn-secondary-action:hover:not(:disabled) {
  background: #e9ecef;
}

.table-responsive {
  overflow-x: auto;
  margin-bottom: 16px;
}

.table-dashboard {
  width: 100%;
  border-collapse: collapse;
  font-size: 13px;
}

.table-dashboard th, .table-dashboard td {
  padding: 10px 12px;
  border-bottom: 1px solid #e3e6f0;
  text-align: left;
  vertical-align: middle;
}

.table-dashboard th {
  background-color: #f8f9fa;
  font-weight: 600;
  color: #495057;
  user-select: none;
}

.table-dashboard tr:hover {
  background-color: #fcfcfc;
}
```

---

## 3. Código JavaScript (Lógica y Controladores)

```javascript
// Encabezados esperados del CSV exportado por Moodle.
const COL_NOMBRE_ESTADO_ENCUESTA = "Nombre completo del usuario";
const COL_EMAIL_ESTADO_ENCUESTA = "Dirección de correo";
const COL_DNI_ESTADO_ENCUESTA = "id_alumno";

let cacheEstadoEncuestaCuat = null;
let estadoEncuestaCuatSeleccionado = null;

// Normaliza texto para comparar y filtrar.
function normalizarTextoEstadoEncuesta(value) {
  return String(value || "")
    .trim()
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "");
}

// Escapa texto antes de insertarlo en HTML.
function escapeHtmlEstadoEncuesta(value) {
  return String(value || "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

// Obtiene el correo de una fila del CSV.
function getEmailEstadoEncuesta(row) {
  return String(
    row?.[COL_EMAIL_ESTADO_ENCUESTA] ||
    row?.["Dirección de correo electrónico"] ||
    row?.["Correo"] ||
    row?.["Email"] ||
    ""
  ).trim();
}

// Obtiene el nombre de una fila del CSV.
function getNombreEstadoEncuesta(row) {
  return String(
    row?.[COL_NOMBRE_ESTADO_ENCUESTA] ||
    row?.["Nombre completo"] ||
    row?.["Nombre"] ||
    ""
  ).trim();
}

// Obtiene el DNI si existe en la fila.
function getDniEstadoEncuesta(row) {
  return String(
    row?.[COL_DNI_ESTADO_ENCUESTA] ||
    row?.["DNI"] ||
    row?.["dni"] ||
    ""
  ).replace(/[^\d]/g, "");
}

// Carga una sola vez los CSV necesarios para esta pestaña.
async function obtenerDatosEstadoEncuestaCuatrimestral() {
  if (cacheEstadoEncuestaCuat) {
    return cacheEstadoEncuestaCuat;
  }

  const urlInicial =
    `${window.location.origin}/mod/feedback/show_entries.php?sesskey=${sesskey}&download=csv&id=${systemConfig.urls.cmids.encuesta_inicial}`;

  const urlCuat =
    `${window.location.origin}/mod/feedback/show_entries.php?sesskey=${sesskey}&download=csv&id=${systemConfig.urls.cmids.encuesta_cuatrimestral}`;

  const [responseInicial, responseCuat] = await Promise.all([
    fetch(urlInicial, { credentials: "include" }),
    fetch(urlCuat, { credentials: "include" })
  ]);

  if (!responseInicial.ok) {
    throw new Error("No se pudo descargar la encuesta inicial.");
  }

  if (!responseCuat.ok) {
    throw new Error("No se pudo descargar la encuesta cuatrimestral.");
  }

  const [textInicial, textCuat] = await Promise.all([
    responseInicial.text(),
    responseCuat.text()
  ]);

  cacheEstadoEncuestaCuat = {
    csvInicial: parseCSV(textInicial),
    csvCuat: parseCSV(textCuat)
  };

  return cacheEstadoEncuestaCuat;
}

// Marca visualmente qué botón está activo.
function marcarBotonEstadoEncuestaCuatrimestral(completaron) {
  const btnSi = document.getElementById("btn-encuesta-cuat-si");
  const btnNo = document.getElementById("btn-encuesta-cuat-no");

  if (!btnSi || !btnNo) return;

  btnSi.classList.toggle("btn-secondary-action", !completaron);
  btnNo.classList.toggle("btn-secondary-action", completaron);
}

// Carga la lista de alumnos según si hicieron o no hicieron la encuesta.
async function cargarListaEstadoEncuestaCuatrimestral(completaron) {
  completaron = completaron === true || completaron === "true";
  estadoEncuestaCuatSeleccionado = completaron;

  const tbody = document.getElementById("estado-encuesta-cuat-tbody");
  const totalEl = document.getElementById("total-estado-encuesta-cuat");
  const btnSi = document.getElementById("btn-encuesta-cuat-si");
  const btnNo = document.getElementById("btn-encuesta-cuat-no");
  const inputFiltro = document.getElementById("filter-estado-encuesta-cuat");

  if (!tbody || !totalEl) return;

  marcarBotonEstadoEncuestaCuatrimestral(completaron);

  tbody.innerHTML = `
    <tr>
      <td colspan="3" style="text-align: center; padding: 32px; color: #666;">
        ⏳ Cargando encuestas desde Moodle...
      </td>
    </tr>
  `;

  totalEl.textContent = "0";

  if (inputFiltro) inputFiltro.value = "";
  if (btnSi) btnSi.disabled = true;
  if (btnNo) btnNo.disabled = true;

  try {
    const { csvInicial, csvCuat } = await obtenerDatosEstadoEncuestaCuatrimestral();

    const emailsCuat = new Set();

    csvCuat.forEach((row) => {
      const email = getEmailEstadoEncuesta(row).toLowerCase();
      if (email) emailsCuat.add(email);
    });

    const lista = [];

    csvInicial.forEach((rowInic) => {
      const email = getEmailEstadoEncuesta(rowInic);
      if (!email) return;

      const emailKey = email.toLowerCase();
      const hizoCuat = emailsCuat.has(emailKey);

      if (hizoCuat !== completaron) return;

      lista.push({
        nombre: getNombreEstadoEncuesta(rowInic) || "—",
        dni: getDniEstadoEncuesta(rowInic) || "—",
        email: email
      });
    });

    lista.sort((a, b) => String(a.nombre).localeCompare(String(b.nombre), "es"));

    console.log(
      "Estado encuesta cuatrimestral:",
      completaron ? "Hicieron la encuesta" : "No hicieron la encuesta",
      lista.length
    );

    renderListaEstadoEncuestaCuatrimestral(lista);
  } catch (error) {
    console.error("Error al cargar estado de encuesta cuatrimestral:", error);

    tbody.innerHTML = `
      <tr>
        <td colspan="3" style="text-align: center; padding: 32px; color: #c0392b;">
          Error al cargar datos desde Moodle: ${escapeHtmlEstadoEncuesta(error.message)}
        </td>
      </tr>
    `;

    totalEl.textContent = "0";
  } finally {
    if (btnSi) btnSi.disabled = false;
    if (btnNo) btnNo.disabled = false;
  }
}

// Renderiza la tabla de alumnos.
function renderListaEstadoEncuestaCuatrimestral(lista) {
  const tbody = document.getElementById("estado-encuesta-cuat-tbody");
  const totalEl = document.getElementById("total-estado-encuesta-cuat");

  if (!tbody || !totalEl) return;

  totalEl.textContent = lista.length;

  if (!lista || lista.length === 0) {
    tbody.innerHTML = `
      <tr>
        <td colspan="3" style="text-align: center; padding: 32px; color: #666;">
          No hay alumnos para mostrar en esta categoría.
        </td>
      </tr>
    `;
    return;
  }

  tbody.innerHTML = lista.map((alumno) => {
    const nombre = escapeHtmlEstadoEncuesta(alumno.nombre || "—");
    const dni = escapeHtmlEstadoEncuesta(alumno.dni || "—");
    const email = escapeHtmlEstadoEncuesta(alumno.email || "—");

    const textoFiltro = normalizarTextoEstadoEncuesta(
      `${alumno.nombre || ""} ${alumno.dni || ""} ${alumno.email || ""}`
    );

    return `
      <tr data-filter-text="${escapeHtmlEstadoEncuesta(textoFiltro)}">
        <td>${nombre}</td>
        <td>${dni}</td>
        <td>${email}</td>
      </tr>
    `;
  }).join("");

  filtrarTablaEstadoEncuestaDesdeDOM();
}

// Filtra las filas ya cargadas en la tabla.
function filtrarTablaEstadoEncuestaDesdeDOM() {
  const input = document.getElementById("filter-estado-encuesta-cuat");
  const totalEl = document.getElementById("total-estado-encuesta-cuat");
  const tbody = document.getElementById("estado-encuesta-cuat-tbody");

  if (!input || !totalEl || !tbody) return;

  const filtro = normalizarTextoEstadoEncuesta(input.value);
  const rows = Array.from(tbody.querySelectorAll("tr[data-filter-text]"));

  let visibles = 0;

  rows.forEach((row) => {
    const text = row.getAttribute("data-filter-text") || "";
    const coincide = !filtro || text.includes(filtro);

    row.style.display = coincide ? "" : "none";

    if (coincide) visibles++;
  });

  if (rows.length > 0) {
    totalEl.textContent = visibles;
  }
}

// Inicialización de Manejadores de Eventos
const btnEncuestaCuatSi = document.getElementById("btn-encuesta-cuat-si");
const btnEncuestaCuatNo = document.getElementById("btn-encuesta-cuat-no");
const inputFiltroEncuestaCuat = document.getElementById("filter-estado-encuesta-cuat");
const btnClearFiltroEncuestaCuat = document.getElementById("btn-clear-filter-estado-encuesta-cuat");

if (btnEncuestaCuatSi) {
  btnEncuestaCuatSi.addEventListener("click", function () {
    cargarListaEstadoEncuestaCuatrimestral(true);
  });
}

if (btnEncuestaCuatNo) {
  btnEncuestaCuatNo.addEventListener("click", function () {
    cargarListaEstadoEncuestaCuatrimestral(false);
  });
}

if (inputFiltroEncuestaCuat) {
  inputFiltroEncuestaCuat.addEventListener("input", function () {
    filtrarTablaEstadoEncuestaDesdeDOM();
  });
}

if (btnClearFiltroEncuestaCuat && inputFiltroEncuestaCuat) {
  btnClearFiltroEncuestaCuat.addEventListener("click", function () {
    inputFiltroEncuestaCuat.value = "";
    filtrarTablaEstadoEncuestaDesdeDOM();
  });
}
```
