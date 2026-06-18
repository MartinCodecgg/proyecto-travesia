**Aclaracion:** Muchos HTML de vista fueron creados en vista Simple (muestra solo una entrada) en lugar de mostrar todas.
(Solo aplican a las bases de datos)
El agente debera informar si estos html necesitan actualizacion o no.

# Estructura de Bases de Datos Moodle

## Criterio general

La mayoría de los campos que almacenan datos compuestos se guardan como **texto plano en formato JSON serializado**. El código los lee como string y hace `JSON.parse(campo)` para trabajarlos como objeto normal. Esto evita tener que modificar la estructura de la DB en Moodle cada vez que cambia un campo del modelo de datos.

La excepción son campos simples donde Moodle los usa directamente:

- Campos numéricos donde se quiere ordenar o filtrar desde Moodle (`ird`, `aprobadas`, `ralentacion`).
- Menús desplegables que Moodle renderiza nativamente (`origen` en los logs).
- Textos cortos de identificación (`id_alumno`, `nombre_alumno`, `cuatrimestre`, `fecha_snapshot`).

---

# Obtención de datos desde actividades Feedback

Las bases de datos no permiten esto, aplica solamente a feedback.

### Decisión: fetch al endpoint de exportación CSV (no scraping del HTML de vista)

En lugar de hacer scraping al HTML de la página de visualización de entradas,
el script obtiene los datos haciendo fetch directo a la URL de exportación CSV
que Moodle expone en cada actividad Feedback. Moodle devuelve el
archivo como texto plano en el body de la respuesta, sin necesidad de descarga
ni interacción del usuario.

**Ventajas sobre el scraping:**

- No depende de clases CSS ni estructura HTML de Moodle (que puede cambiar entre versiones o temas)
- Una sola request trae todos los registros sin necesidad de paginación
- El formato es predecible y estable

**URL patrón para Feedback:**

/mod/feedback/export.php?id={CMID}&action=exportfile
(Verificar mas abajo los reales)

**Fetch desde el script:**

```javascript
const response = await fetch(BASE_URL + "/mod/data/export.php?d=" + DATAID, {
  credentials: "include",
});
const csvText = await response.text();
```

El csv que devuelve moodle viene con los campos separados por comas.

### Parser CSV obligatorio — no usar split(',')

El CSV exportado por Moodle sigue RFC 4180: los campos que contienen comas, comillas o saltos de línea van envueltos en comillas dobles. Un split simple rompe el parseo ante cualquier texto libre del usuario. Usar siempre el parser de campos con soporte de quoting:

```javascript
function parseCSVLine(line) {
  const result = [];
  let current = "";
  let inQuotes = false;
  for (let i = 0; i < line.length; i++) {
    const char = line[i];
    if (char === '"') {
      if (inQuotes && line[i + 1] === '"') {
        current += '"';
        i++;
      } else inQuotes = !inQuotes;
    } else if (char === "," && !inQuotes) {
      result.push(current);
      current = "";
    } else {
      current += char;
    }
  }
  result.push(current);
  return result;
}

function parseCSV(text) {
  const lines = text.trim().split("\n");
  const headers = parseCSVLine(lines[0]);
  return lines.slice(1).map((line) => {
    const values = parseCSVLine(line);
    return Object.fromEntries(
      headers.map((h, i) => [h.trim(), (values[i] ?? "").trim()]),
    );
  });
}
```

### Identificación del alumno

El CSV exportado por Moodle incluye `Nombre completo del usuario` pero **no** incluye el ID numérico de Moodle. Para cruzar los datos del CSV con el ID de Moodle, el script debe obtener el ID por separado (ej: desde el panel de participantes o desde el contexto de sesión).
"El cruce entre el CSV y el ID de Moodle se realiza por **email**. El CSV exportado incluye `Dirección de correo` y el listado de participantes expone el mismo email en el perfil de cada usuario. No hay riesgo de colisión."

> Este es un limitante conocido del enfoque CSV. Ver decisión sobre identificadores en la sección "Alumnos de 1er año — problema de cruce de datos".

**Este es un problema**
El 1er enfoque que se me ocurre, y quizas no sea el mejor, es simplemente seguir haciendo scraping normal y ademas obtener el csv.
Con el scraping se obtendrian los id solamente.
Y con csv todo lo demas.

Si hay que cruzar datos con el scraping manual y el csv.

El id de todos modos tambien debe adquirirse.

---

# CMID-DATAID-HTML

## URL BASE DEL CURSO

`https://ingenieria.campus.mdp.edu.ar/course/view.php?id=1732`

## Database de solicitudes de ayuda

### URL:

`https://ingenieria.campus.mdp.edu.ar/mod/data/view.php?d=15&rid=22`

### HTML de vista:

```
<form action="https://ingenieria.campus.mdp.edu.ar/mod/data/view.php?d=15&amp;sesskey=bN4VoosUA9" method="post"><div id="data-listview-content" class="box "><div class="defaulttemplate-listentry my-5 p-5 card">
    <div class="row my-6">
        <div class="col-auto"><a href="https://ingenieria.campus.mdp.edu.ar/user/view.php?id=2987&amp;course=1732" class="d-inline-block aabtn"><img src="https://ingenieria.campus.mdp.edu.ar/pluginfile.php/36551/user/icon/adaptable/f1?rev=890264" class="userpicture" width="64" height="64" alt="MARTIN ESTEBAN GIRAU" title="MARTIN ESTEBAN GIRAU"></a></div>
        <div class="col">
            <div class="row h-100">
                <div class="col-3 align-self-center">
                    <a href="https://ingenieria.campus.mdp.edu.ar/user/view.php?id=2987&amp;course=1732">MARTIN ESTEBAN GIRAU</a><br><span class="data-timeinfo"><span title="jueves, 11 de junio de 2026, 14:14">11 jun 2026</span></span>
                </div>
                <div class="col-4 col-md-6 text-right align-self-center data-timeinfo">
                    <span class="font-weight-bold ">Editado por última vez:&nbsp;</span><span title="jueves, 11 de junio de 2026, 14:14">11 jun 2026</span>
                </div>
                <div class="col-4 col-md-3 ml-auto align-self-center d-flex flex-row-reverse">
                    <div><div class="action-menu moodle-actionmenu entry-actionsmenu" id="action-menu-6" data-enhance="moodle-core-actionmenu">

        <div class="menubar d-flex " id="action-menu-6-menubar">




                <div class="action-menu-trigger">
                    <div class="dropdown">
                        <a href="#" tabindex="0" class="btn btn-icon d-flex align-items-center justify-content-center no-caret  dropdown-toggle icon-no-margin" id="action-menu-toggle-6" aria-label="Acciones" data-toggle="dropdown" role="button" aria-haspopup="true" aria-expanded="false" aria-controls="action-menu-6-menu">

                            <i class="icon fa fa-ellipsis-v fa-fw" title="Acciones" role="img" aria-label="Acciones"></i>

                            <b class="caret"></b>
                        </a>
                            <div class="dropdown-menu menu dropdown-menu-right" id="action-menu-6-menu" data-rel="menu-content" aria-labelledby="action-menu-toggle-6" role="menu">
                                                                <a href="https://ingenieria.campus.mdp.edu.ar/mod/data/view.php?d=15&amp;advanced=0&amp;paging&amp;page=0&amp;rid=22&amp;filter=1" class="dropdown-item menu-action" role="menuitem" tabindex="-1">
                                <span class="menu-action-text">Mostrar más</span>
                        </a>
                                                                <a href="https://ingenieria.campus.mdp.edu.ar/mod/data/edit.php?d=15&amp;advanced=0&amp;paging&amp;page=0&amp;rid=22&amp;sesskey=bN4VoosUA9&amp;backto=https%253A%252F%252Fingenieria.campus.mdp.edu.ar%252Fmod%252Fdata%252Fview.php%253Fd%253D15%2526advanced%253D0%2526paging%2526page%253D0%2526rid%253D22%2526mode%253Dsingle" class="dropdown-item menu-action" role="menuitem" tabindex="-1">
                                <span class="menu-action-text">Editar</span>
                        </a>
                                                                <a href="https://ingenieria.campus.mdp.edu.ar/mod/data/view.php?d=15&amp;advanced=0&amp;paging&amp;page=0&amp;delete=22&amp;sesskey=bN4VoosUA9&amp;mode=single" class="dropdown-item menu-action" role="menuitem" tabindex="-1">
                                <span class="menu-action-text">Borrar</span>
                        </a>
                                                                <a href="https://ingenieria.campus.mdp.edu.ar/mod/data/view.php?d=15&amp;advanced=0&amp;paging&amp;page=0&amp;disapprove=22&amp;sesskey=bN4VoosUA9" class="dropdown-item menu-action" role="menuitem" tabindex="-1">
                                <span class="menu-action-text">Desaprobar</span>
                        </a>
                            </div>
                    </div>
                </div>

        </div>

</div></div>
                    <div class="ml-auto my-auto approved"></div>
                </div>
            </div>
        </div>
    </div>
    <hr>

    <div class="defaulttemplate-list-body">
            <div class="row my-3 align-items-start justify-content-start">
                <div class="col-4 col-lg-3 font-weight-bold">Descripcion</div>
                <div class="col-8 col-lg-9 ml-n3"><div class="data-field-html"><p>Probando primer entrada</p>
<p>"Necesito una tutoria para aprobar mate I"</p></div></div>
            </div>
            <div class="mb-4">
                <span class="font-weight-bold">Marcas</span>
                <p class="mt-2"></p>
            </div>
    </div>
</div></div><div id="sticky-footer" class="stickyfooter bg-white border-top">
    <div class="sticky-footer-content-wrapper h-100 d-flex justify-content-center">
        <div class="sticky-footer-content w-100 d-flex align-items-center px-3 py-2  justify-content-end">
                <div class="navitem submit mr-auto ml-auto">

</div>
<div class="navitem">
        <a href="https://ingenieria.campus.mdp.edu.ar/mod/data/edit.php?id=54783&amp;backto=https%3A%2F%2Fingenieria.campus.mdp.edu.ar%2Fmod%2Fdata%2Fview.php%3Fd%3D15%26amp%3Badvanced%3D0%26amp%3Bpaging%26amp%3Bpage%3D0" id="action_link6a2aeddd5112d147" class="btn btn-primary mx-1" role="button">Añadir entrada</a>
</div>
        </div>
    </div>
</div></form>
```

### HTML PARA CREAR UNA NUEVA ENTRADA (form):

```
<form enctype="multipart/form-data" action="edit.php" method="post"><div><input name="d" value="15" type="hidden"><input name="rid" value="0" type="hidden"><input name="sesskey" value="bN4VoosUA9" type="hidden"><div class="box generalbox boxaligncenter boxwidthwide"><h2>Nueva entrada</h2><div id="defaulttemplate-addentry">
        <div class="mb-3 pt-3">
            <div class="font-weight-bold">Descripcion</div>
            <div title="Texto Libre sobre el motivo de la asistencia" class="d-inline-flex"><label for="field_41"><span class="accesshide">Descripcion</span><div class="inline-req"><i class="icon fa fa-exclamation-circle text-danger fa-fw" title="Campo obligatorio" role="img" aria-label="Campo obligatorio"></i></div></label><input type="hidden" name="field_41_itemid" value="57018692"><div class="mod-data-input"><div><textarea id="field_41" name="field_41" rows="35" class="form-control" data-fieldtype="editor" cols="60" spellcheck="true" style="display: none;" aria-hidden="true"></textarea><div role="application" class="tox tox-tinymce" aria-disabled="false" style="visibility: hidden; height: 760px;"><div class="tox-editor-container"><div data-alloy-vertical-dir="toptobottom" class="tox-editor-header"><div role="menubar" data-alloy-tabstop="true" class="tox-menubar"><button aria-haspopup="true" role="menuitem" type="button" tabindex="-1" data-alloy-tabstop="true" unselectable="on" class="tox-mbtn tox-mbtn--select" aria-expanded="false" style="user-select: none; width: 51.4531px;"><span class="tox-mbtn__select-label">Editar</span><div class="tox-mbtn__select-chevron"><svg width="10" height="10" focusable="false"><path d="M8.7 2.2c.3-.3.8-.3 1 0 .4.4.4.9 0 1.2L5.7 7.8c-.3.3-.9.3-1.2 0L.2 3.4a.8.8 0 0 1 0-1.2c.3-.3.8-.3 1.1 0L5 6l3.7-3.8Z" fill-rule="nonzero"></path></svg></div></button><button aria-haspopup="true" role="menuitem" type="button" tabindex="-1" data-alloy-tabstop="true" unselectable="on" class="tox-mbtn tox-mbtn--select" style="user-select: none; width: 36px;" aria-expanded="false"><span class="tox-mbtn__select-label">Ver</span><div class="tox-mbtn__select-chevron"><svg width="10" height="10" focusable="false"><path d="M8.7 2.2c.3-.3.8-.3 1 0 .4.4.4.9 0 1.2L5.7 7.8c-.3.3-.9.3-1.2 0L.2 3.4a.8.8 0 0 1 0-1.2c.3-.3.8-.3 1.1 0L5 6l3.7-3.8Z" fill-rule="nonzero"></path></svg></div></button><button aria-haspopup="true" role="menuitem" type="button" tabindex="-1" data-alloy-tabstop="true" unselectable="on" class="tox-mbtn tox-mbtn--select" style="user-select: none; width: 62.5156px;" aria-expanded="false"><span class="tox-mbtn__select-label">Insertar</span><div class="tox-mbtn__select-chevron"><svg width="10" height="10" focusable="false"><path d="M8.7 2.2c.3-.3.8-.3 1 0 .4.4.4.9 0 1.2L5.7 7.8c-.3.3-.9.3-1.2 0L.2 3.4a.8.8 0 0 1 0-1.2c.3-.3.8-.3 1.1 0L5 6l3.7-3.8Z" fill-rule="nonzero"></path></svg></div></button><button aria-haspopup="true" role="menuitem" type="button" tabindex="-1" data-alloy-tabstop="true" unselectable="on" class="tox-mbtn tox-mbtn--select" style="user-select: none; width: 68.0469px;" aria-expanded="false"><span class="tox-mbtn__select-label">Formato</span><div class="tox-mbtn__select-chevron"><svg width="10" height="10" focusable="false"><path d="M8.7 2.2c.3-.3.8-.3 1 0 .4.4.4.9 0 1.2L5.7 7.8c-.3.3-.9.3-1.2 0L.2 3.4a.8.8 0 0 1 0-1.2c.3-.3.8-.3 1.1 0L5 6l3.7-3.8Z" fill-rule="nonzero"></path></svg></div></button><button aria-haspopup="true" role="menuitem" type="button" tabindex="-1" data-alloy-tabstop="true" unselectable="on" class="tox-mbtn tox-mbtn--select" style="user-select: none; width: 98.625px;" aria-expanded="false"><span class="tox-mbtn__select-label">Herramientas</span><div class="tox-mbtn__select-chevron"><svg width="10" height="10" focusable="false"><path d="M8.7 2.2c.3-.3.8-.3 1 0 .4.4.4.9 0 1.2L5.7 7.8c-.3.3-.9.3-1.2 0L.2 3.4a.8.8 0 0 1 0-1.2c.3-.3.8-.3 1.1 0L5 6l3.7-3.8Z" fill-rule="nonzero"></path></svg></div></button><button aria-haspopup="true" role="menuitem" type="button" tabindex="-1" data-alloy-tabstop="true" unselectable="on" class="tox-mbtn tox-mbtn--select" style="user-select: none; width: 47.6406px;" aria-expanded="false"><span class="tox-mbtn__select-label">Tabla</span><div class="tox-mbtn__select-chevron"><svg width="10" height="10" focusable="false"><path d="M8.7 2.2c.3-.3.8-.3 1 0 .4.4.4.9 0 1.2L5.7 7.8c-.3.3-.9.3-1.2 0L.2 3.4a.8.8 0 0 1 0-1.2c.3-.3.8-.3 1.1 0L5 6l3.7-3.8Z" fill-rule="nonzero"></path></svg></div></button><button aria-haspopup="true" role="menuitem" type="button" tabindex="-1" data-alloy-tabstop="true" unselectable="on" class="tox-mbtn tox-mbtn--select" style="user-select: none; width: 54.8281px;" aria-expanded="false"><span class="tox-mbtn__select-label">Ayuda</span><div class="tox-mbtn__select-chevron"><svg width="10" height="10" focusable="false"><path d="M8.7 2.2c.3-.3.8-.3 1 0 .4.4.4.9 0 1.2L5.7 7.8c-.3.3-.9.3-1.2 0L.2 3.4a.8.8 0 0 1 0-1.2c.3-.3.8-.3 1.1 0L5 6l3.7-3.8Z" fill-rule="nonzero"></path></svg></div></button></div><div role="group" class="tox-toolbar-overlord" aria-disabled="false"><div role="group" class="tox-toolbar__primary"><div title="historial" role="toolbar" data-alloy-tabstop="true" tabindex="-1" class="tox-toolbar__group"><button aria-label="Deshacer" title="Deshacer" type="button" tabindex="-1" class="tox-tbtn tox-tbtn--disabled" aria-disabled="true" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M6.4 8H12c3.7 0 6.2 2 6.8 5.1.6 2.7-.4 5.6-2.3 6.8a1 1 0 0 1-1-1.8c1.1-.6 1.8-2.7 1.4-4.6-.5-2.1-2.1-3.5-4.9-3.5H6.4l3.3 3.3a1 1 0 1 1-1.4 1.4l-5-5a1 1 0 0 1 0-1.4l5-5a1 1 0 0 1 1.4 1.4L6.4 8Z" fill-rule="nonzero"></path></svg></span></button><button aria-label="Rehacer" title="Rehacer" type="button" tabindex="-1" class="tox-tbtn tox-tbtn--disabled" aria-disabled="true" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M17.6 10H12c-2.8 0-4.4 1.4-4.9 3.5-.4 2 .3 4 1.4 4.6a1 1 0 1 1-1 1.8c-2-1.2-2.9-4.1-2.3-6.8.6-3 3-5.1 6.8-5.1h5.6l-3.3-3.3a1 1 0 1 1 1.4-1.4l5 5a1 1 0 0 1 0 1.4l-5 5a1 1 0 0 1-1.4-1.4l3.3-3.3Z" fill-rule="nonzero"></path></svg></span></button></div><div title="formato" role="toolbar" data-alloy-tabstop="true" tabindex="-1" class="tox-toolbar__group"><button aria-label="Negrita" title="Negrita" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M7.8 19c-.3 0-.5 0-.6-.2l-.2-.5V5.7c0-.2 0-.4.2-.5l.6-.2h5c1.5 0 2.7.3 3.5 1 .7.6 1.1 1.4 1.1 2.5a3 3 0 0 1-.6 1.9c-.4.6-1 1-1.6 1.2.4.1.9.3 1.3.6s.8.7 1 1.2c.4.4.5 1 .5 1.6 0 1.3-.4 2.3-1.3 3-.8.7-2.1 1-3.8 1H7.8Zm5-8.3c.6 0 1.2-.1 1.6-.5.4-.3.6-.7.6-1.3 0-1.1-.8-1.7-2.3-1.7H9.3v3.5h3.4Zm.5 6c.7 0 1.3-.1 1.7-.4.4-.4.6-.9.6-1.5s-.2-1-.7-1.4c-.4-.3-1-.4-2-.4H9.4v3.8h4Z" fill-rule="evenodd"></path></svg></span></button><button aria-label="Cursiva" title="Cursiva" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="m16.7 4.7-.1.9h-.3c-.6 0-1 0-1.4.3-.3.3-.4.6-.5 1.1l-2.1 9.8v.6c0 .5.4.8 1.4.8h.2l-.2.8H8l.2-.8h.2c1.1 0 1.8-.5 2-1.5l2-9.8.1-.5c0-.6-.4-.8-1.4-.8h-.3l.2-.9h5.8Z" fill-rule="evenodd"></path></svg></span></button></div><div role="toolbar" data-alloy-tabstop="true" tabindex="-1" class="tox-toolbar__group"><button aria-label="Mostrar u ocultar elementos adicionales de la barra de herramientas" title="Mostrar u ocultar elementos adicionales de la barra de herramientas" type="button" tabindex="-1" data-alloy-tabstop="true" class="tox-tbtn" aria-pressed="false"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M6 10a2 2 0 0 0-2 2c0 1.1.9 2 2 2a2 2 0 0 0 2-2 2 2 0 0 0-2-2Zm12 0a2 2 0 0 0-2 2c0 1.1.9 2 2 2a2 2 0 0 0 2-2 2 2 0 0 0-2-2Zm-6 0a2 2 0 0 0-2 2c0 1.1.9 2 2 2a2 2 0 0 0 2-2 2 2 0 0 0-2-2Z" fill-rule="nonzero"></path></svg></span></button></div></div><div role="group" class="tox-toolbar__overflow tox-toolbar__overflow--closed" style="height: 0px;"><div title="content" role="toolbar" data-alloy-tabstop="true" tabindex="-1" class="tox-toolbar__group"><button aria-label="Imagen" title="Imagen" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="m5 15.7 3.3-3.2c.3-.3.7-.3 1 0L12 15l4.1-4c.3-.4.8-.4 1 0l2 1.9V5H5v10.7ZM5 18V19h3l2.8-2.9-2-2L5 17.9Zm14-3-2.5-2.4-6.4 6.5H19v-4ZM4 3h16c.6 0 1 .4 1 1v16c0 .6-.4 1-1 1H4a1 1 0 0 1-1-1V4c0-.6.4-1 1-1Zm6 8a2 2 0 1 0 0-4 2 2 0 0 0 0 4Z" fill-rule="nonzero"></path></svg></span></button><button aria-label="Multimedios" title="Multimedios" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M4 3h16c.6 0 1 .4 1 1v16c0 .6-.4 1-1 1H4a1 1 0 0 1-1-1V4c0-.6.4-1 1-1Zm1 2v14h14V5H5Zm4.8 2.6 5.6 4a.5.5 0 0 1 0 .8l-5.6 4A.5.5 0 0 1 9 16V8a.5.5 0 0 1 .8-.4Z" fill-rule="nonzero"></path></svg></span></button><button aria-label="Grabar audio" title="Grabar audio" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg data-buttonsource="moodle" width="24" height="24" xmlns="http://www.w3.org/2000/svg" focusable="false">
        <image href="https://ingenieria.campus.mdp.edu.ar/theme/image.php/adaptable/tiny_recordrtc/1775501275/audio" width="24" height="24"></image>
</svg></span></button><button aria-label="Grabar video" title="Grabar video" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg data-buttonsource="moodle" width="24" height="24" xmlns="http://www.w3.org/2000/svg" focusable="false">
        <image href="https://ingenieria.campus.mdp.edu.ar/theme/image.php/adaptable/tiny_recordrtc/1775501275/video" width="24" height="24"></image>
</svg></span></button><button aria-label="Configurar contenido H5P" title="Configurar contenido H5P" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg data-buttonsource="moodle" width="24" height="24" xmlns="http://www.w3.org/2000/svg" focusable="false">
        <image href="https://ingenieria.campus.mdp.edu.ar/theme/image.php/adaptable/tiny_h5p/1775501275/icon" width="24" height="24"></image>
</svg></span></button><button aria-label="Enlace" title="Enlace" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M6.2 12.3a1 1 0 0 1 1.4 1.4l-2 2a2 2 0 1 0 2.6 2.8l4.8-4.8a1 1 0 0 0 0-1.4 1 1 0 1 1 1.4-1.3 2.9 2.9 0 0 1 0 4L9.6 20a3.9 3.9 0 0 1-5.5-5.5l2-2Zm11.6-.6a1 1 0 0 1-1.4-1.4l2-2a2 2 0 1 0-2.6-2.8L11 10.3a1 1 0 0 0 0 1.4A1 1 0 1 1 9.6 13a2.9 2.9 0 0 1 0-4L14.4 4a3.9 3.9 0 0 1 5.5 5.5l-2 2Z" fill-rule="nonzero"></path></svg></span></button><button aria-label="Desenlanzar" title="Desenlanzar" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M6.2 12.3a1 1 0 0 1 1.4 1.4l-2 2a2 2 0 1 0 2.6 2.8l4.8-4.8a1 1 0 0 0 0-1.4 1 1 0 1 1 1.4-1.3 2.9 2.9 0 0 1 0 4L9.6 20a3.9 3.9 0 0 1-5.5-5.5l2-2Zm11.6-.6a1 1 0 0 1-1.4-1.4l2.1-2a2 2 0 1 0-2.7-2.8L11 10.3a1 1 0 0 0 0 1.4A1 1 0 1 1 9.6 13a2.9 2.9 0 0 1 0-4L14.4 4a3.9 3.9 0 0 1 5.5 5.5l-2 2ZM7.6 6.3a.8.8 0 0 1-1 1.1L3.3 4.2a.7.7 0 1 1 1-1l3.2 3.1ZM5.1 8.6a.8.8 0 0 1 0 1.5H3a.8.8 0 0 1 0-1.5H5Zm5-3.5a.8.8 0 0 1-1.5 0V3a.8.8 0 0 1 1.5 0V5Zm6 11.8a.8.8 0 0 1 1-1l3.2 3.2a.8.8 0 0 1-1 1L16 17Zm-2.2 2a.8.8 0 0 1 1.5 0V21a.8.8 0 0 1-1.5 0V19Zm5-3.5a.7.7 0 1 1 0-1.5H21a.8.8 0 0 1 0 1.5H19Z" fill-rule="nonzero"></path></svg></span></button></div><div title="Ver" role="toolbar" data-alloy-tabstop="true" tabindex="-1" class="tox-toolbar__group"><button aria-label="Pantalla completa" title="Pantalla completa" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="m15.3 10-1.2-1.3 2.9-3h-2.3a.9.9 0 1 1 0-1.7H19c.5 0 .9.4.9.9v4.4a.9.9 0 1 1-1.8 0V7l-2.9 3Zm0 4 3 3v-2.3a.9.9 0 1 1 1.7 0V19c0 .5-.4.9-.9.9h-4.4a.9.9 0 1 1 0-1.8H17l-3-2.9 1.3-1.2ZM10 15.4l-2.9 3h2.3a.9.9 0 1 1 0 1.7H5a.9.9 0 0 1-.9-.9v-4.4a.9.9 0 1 1 1.8 0V17l2.9-3 1.2 1.3ZM8.7 10 5.7 7v2.3a.9.9 0 0 1-1.7 0V5c0-.5.4-.9.9-.9h4.4a.9.9 0 0 1 0 1.8H7l3 2.9-1.3 1.2Z" fill-rule="nonzero"></path></svg></span></button></div><div title="alineación" role="toolbar" data-alloy-tabstop="true" tabindex="-1" class="tox-toolbar__group"><button aria-label="Alinear a la izquierda" title="Alinear a la izquierda" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M5 5h14c.6 0 1 .4 1 1s-.4 1-1 1H5a1 1 0 1 1 0-2Zm0 4h8c.6 0 1 .4 1 1s-.4 1-1 1H5a1 1 0 1 1 0-2Zm0 8h8c.6 0 1 .4 1 1s-.4 1-1 1H5a1 1 0 0 1 0-2Zm0-4h14c.6 0 1 .4 1 1s-.4 1-1 1H5a1 1 0 0 1 0-2Z" fill-rule="evenodd"></path></svg></span></button><button aria-label="Alinear al centro" title="Alinear al centro" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M5 5h14c.6 0 1 .4 1 1s-.4 1-1 1H5a1 1 0 1 1 0-2Zm3 4h8c.6 0 1 .4 1 1s-.4 1-1 1H8a1 1 0 1 1 0-2Zm0 8h8c.6 0 1 .4 1 1s-.4 1-1 1H8a1 1 0 0 1 0-2Zm-3-4h14c.6 0 1 .4 1 1s-.4 1-1 1H5a1 1 0 0 1 0-2Z" fill-rule="evenodd"></path></svg></span></button><button aria-label="Alinear a la derecha" title="Alinear a la derecha" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M5 5h14c.6 0 1 .4 1 1s-.4 1-1 1H5a1 1 0 1 1 0-2Zm6 4h8c.6 0 1 .4 1 1s-.4 1-1 1h-8a1 1 0 0 1 0-2Zm0 8h8c.6 0 1 .4 1 1s-.4 1-1 1h-8a1 1 0 0 1 0-2Zm-6-4h14c.6 0 1 .4 1 1s-.4 1-1 1H5a1 1 0 0 1 0-2Z" fill-rule="evenodd"></path></svg></span></button></div><div title="directionality" role="toolbar" data-alloy-tabstop="true" tabindex="-1" class="tox-toolbar__group"><button aria-label="Izquierda a derecha" title="Izquierda a derecha" type="button" tabindex="-1" class="tox-tbtn tox-tbtn--enabled" aria-disabled="false" aria-pressed="true" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M11 5h7a1 1 0 0 1 0 2h-1v11a1 1 0 0 1-2 0V7h-2v11a1 1 0 0 1-2 0v-6c-.5 0-1 0-1.4-.3A3.4 3.4 0 0 1 7.8 10a3.3 3.3 0 0 1 0-2.8 3.4 3.4 0 0 1 1.8-1.8L11 5ZM4.4 16.2 6.2 15l-1.8-1.2a1 1 0 0 1 1.2-1.6l3 2a1 1 0 0 1 0 1.6l-3 2a1 1 0 1 1-1.2-1.6Z" fill-rule="evenodd"></path></svg></span></button><button aria-label="Derecha a izquierda" title="Derecha a izquierda" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M8 5h8v2h-2v12h-2V7h-2v12H8v-7c-.5 0-1 0-1.4-.3A3.4 3.4 0 0 1 4.8 10a3.3 3.3 0 0 1 0-2.8 3.4 3.4 0 0 1 1.8-1.8L8 5Zm12 11.2a1 1 0 1 1-1 1.6l-3-2a1 1 0 0 1 0-1.6l3-2a1 1 0 1 1 1 1.6L18.4 15l1.8 1.2Z" fill-rule="evenodd"></path></svg></span></button></div><div title="sangría" role="toolbar" data-alloy-tabstop="true" tabindex="-1" class="tox-toolbar__group"><button aria-label="Disminuir sangría" title="Disminuir sangría" type="button" tabindex="-1" class="tox-tbtn tox-tbtn--disabled" aria-disabled="true" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M7 5h12c.6 0 1 .4 1 1s-.4 1-1 1H7a1 1 0 1 1 0-2Zm5 4h7c.6 0 1 .4 1 1s-.4 1-1 1h-7a1 1 0 0 1 0-2Zm0 4h7c.6 0 1 .4 1 1s-.4 1-1 1h-7a1 1 0 0 1 0-2Zm-5 4h12a1 1 0 0 1 0 2H7a1 1 0 0 1 0-2Zm1.6-3.8a1 1 0 0 1-1.2 1.6l-3-2a1 1 0 0 1 0-1.6l3-2a1 1 0 0 1 1.2 1.6L6.8 12l1.8 1.2Z" fill-rule="evenodd"></path></svg></span></button><button aria-label="Incrementar sangría" title="Incrementar sangría" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M7 5h12c.6 0 1 .4 1 1s-.4 1-1 1H7a1 1 0 1 1 0-2Zm5 4h7c.6 0 1 .4 1 1s-.4 1-1 1h-7a1 1 0 0 1 0-2Zm0 4h7c.6 0 1 .4 1 1s-.4 1-1 1h-7a1 1 0 0 1 0-2Zm-5 4h12a1 1 0 0 1 0 2H7a1 1 0 0 1 0-2Zm-2.6-3.8L6.2 12l-1.8-1.2a1 1 0 0 1 1.2-1.6l3 2a1 1 0 0 1 0 1.6l-3 2a1 1 0 1 1-1.2-1.6Z" fill-rule="evenodd"></path></svg></span></button></div><div title="lists" role="toolbar" data-alloy-tabstop="true" tabindex="-1" class="tox-toolbar__group"><button aria-label="Lista de viñetas" title="Lista de viñetas" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M11 5h8c.6 0 1 .4 1 1s-.4 1-1 1h-8a1 1 0 0 1 0-2Zm0 6h8c.6 0 1 .4 1 1s-.4 1-1 1h-8a1 1 0 0 1 0-2Zm0 6h8c.6 0 1 .4 1 1s-.4 1-1 1h-8a1 1 0 0 1 0-2ZM4.5 6c0-.4.1-.8.4-1 .3-.4.7-.5 1.1-.5.4 0 .8.1 1 .4.4.3.5.7.5 1.1 0 .4-.1.8-.4 1-.3.4-.7.5-1.1.5-.4 0-.8-.1-1-.4-.4-.3-.5-.7-.5-1.1Zm0 6c0-.4.1-.8.4-1 .3-.4.7-.5 1.1-.5.4 0 .8.1 1 .4.4.3.5.7.5 1.1 0 .4-.1.8-.4 1-.3.4-.7.5-1.1.5-.4 0-.8-.1-1-.4-.4-.3-.5-.7-.5-1.1Zm0 6c0-.4.1-.8.4-1 .3-.4.7-.5 1.1-.5.4 0 .8.1 1 .4.4.3.5.7.5 1.1 0 .4-.1.8-.4 1-.3.4-.7.5-1.1.5-.4 0-.8-.1-1-.4-.4-.3-.5-.7-.5-1.1Z" fill-rule="evenodd"></path></svg></span></button><button aria-label="Lista numerada" title="Lista numerada" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M10 17h8c.6 0 1 .4 1 1s-.4 1-1 1h-8a1 1 0 0 1 0-2Zm0-6h8c.6 0 1 .4 1 1s-.4 1-1 1h-8a1 1 0 0 1 0-2Zm0-6h8c.6 0 1 .4 1 1s-.4 1-1 1h-8a1 1 0 1 1 0-2ZM6 4v3.5c0 .3-.2.5-.5.5a.5.5 0 0 1-.5-.5V5h-.5a.5.5 0 0 1 0-1H6Zm-1 8.8.2.2h1.3c.3 0 .5.2.5.5s-.2.5-.5.5H4.9a1 1 0 0 1-.9-1V13c0-.4.3-.8.6-1l1.2-.4.2-.3a.2.2 0 0 0-.2-.2H4.5a.5.5 0 0 1-.5-.5c0-.3.2-.5.5-.5h1.6c.5 0 .9.4.9 1v.1c0 .4-.3.8-.6 1l-1.2.4-.2.3ZM7 17v2c0 .6-.4 1-1 1H4.5a.5.5 0 0 1 0-1h1.2c.2 0 .3-.1.3-.3 0-.2-.1-.3-.3-.3H4.4a.4.4 0 1 1 0-.8h1.3c.2 0 .3-.1.3-.3 0-.2-.1-.3-.3-.3H4.5a.5.5 0 1 1 0-1H6c.6 0 1 .4 1 1Z" fill-rule="evenodd"></path></svg></span></button></div><div title="Avanzado" role="toolbar" data-alloy-tabstop="true" tabindex="-1" class="tox-toolbar__group"><button aria-label="Editor de ecuación" title="Editor de ecuación" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg data-buttonsource="moodle" width="24" height="24" xmlns="http://www.w3.org/2000/svg" focusable="false">
        <image href="https://ingenieria.campus.mdp.edu.ar/theme/image.php/adaptable/tiny_equation/1775501275/icon" width="24" height="24"></image>
</svg></span></button></div></div></div><div class="tox-anchorbar"></div></div><div class="tox-sidebar-wrap" style="height: 748.125px;"><div class="tox-edit-area"><iframe id="field_41_ifr" frameborder="0" allowtransparency="true" title="Área de Texto Enriquecido" class="tox-edit-area__iframe" srcdoc="&lt;!DOCTYPE html&gt;&lt;html&gt;&lt;head&gt;&lt;meta http-equiv=&quot;Content-Type&quot; content=&quot;text/html; charset=UTF-8&quot; /&gt;&lt;/head&gt;&lt;body id=&quot;tinymce&quot; class=&quot;mce-content-body &quot; data-id=&quot;field_41&quot; aria-label=&quot;Área de texto enriquecido. Pulse ALT-0 para abrir la ayuda.&quot;&gt;&lt;br&gt;&lt;/body&gt;&lt;/html&gt;"></iframe></div><div role="presentation" class="tox-sidebar"><div data-alloy-tabstop="true" tabindex="-1" class="tox-sidebar__slider tox-sidebar--sliding-closed" style="width: 0px;"><div class="tox-sidebar__pane-container"></div></div></div></div><div class="tox-bottom-anchorbar"></div><div class="tox-statusbar"><div class="tox-statusbar__text-container tox-statusbar__text-container--flex-start"><div role="navigation" data-alloy-tabstop="true" class="tox-statusbar__path" aria-disabled="false"><div data-index="0" aria-level="1" role="button" tabindex="-1" class="tox-statusbar__path-item" aria-disabled="false">p</div></div><div class="tox-statusbar__right-container"><button type="button" tabindex="-1" data-alloy-tabstop="true" class="tox-statusbar__wordcount">0 palabras</button><span class="tox-statusbar__branding"><a href="https://www.tiny.cloud/powered-by-tiny?utm_campaign=poweredby&amp;utm_source=tiny&amp;utm_medium=referral&amp;utm_content=v6" rel="noopener" target="_blank" aria-label="Con tecnología de Tiny" tabindex="-1"><svg width="50px" height="16px" viewBox="0 0 50 16" xmlns="http://www.w3.org/2000/svg">
  <path fill-rule="evenodd" clip-rule="evenodd" d="M10.143 0c2.608.015 5.186 2.178 5.186 5.331 0 0 .077 3.812-.084 4.87-.361 2.41-2.164 4.074-4.65 4.496-1.453.284-2.523.49-3.212.623-.373.071-.634.122-.785.152-.184.038-.997.145-1.35.145-2.732 0-5.21-2.04-5.248-5.33 0 0 0-3.514.03-4.442.093-2.4 1.758-4.342 4.926-4.963 0 0 3.875-.752 4.036-.782.368-.07.775-.1 1.15-.1Zm1.826 2.8L5.83 3.989v2.393l-2.455.475v5.968l6.137-1.189V9.243l2.456-.476V2.8ZM5.83 6.382l3.682-.713v3.574l-3.682.713V6.382Zm27.173-1.64-.084-1.066h-2.226v9.132h2.456V7.743c-.008-1.151.998-2.064 2.149-2.072 1.15-.008 1.987.92 1.995 2.072v5.065h2.455V7.359c-.015-2.18-1.657-3.929-3.837-3.913a3.993 3.993 0 0 0-2.908 1.296Zm-6.3-4.266L29.16 0v2.387l-2.456.475V.476Zm0 3.2v9.132h2.456V3.676h-2.456Zm18.179 11.787L49.11 3.676H46.58l-1.612 4.527-.46 1.382-.384-1.382-1.611-4.527H39.98l3.3 9.132L42.15 16l2.732-.537ZM22.867 9.738c0 .752.568 1.075.921 1.075.353 0 .668-.047.998-.154l.537 1.765c-.23.154-.92.537-2.225.537-1.305 0-2.655-.997-2.686-2.686a136.877 136.877 0 0 1 0-4.374H18.8V3.676h1.612v-1.98l2.455-.476v2.456h2.302V5.9h-2.302v3.837Z"></path>
</svg></a></span></div></div><div title="Redimensionar" aria-label="Pulse las teclas de flechas arriba y abajo para cambiar el tamaño del editor." data-alloy-tabstop="true" tabindex="-1" class="tox-statusbar__resize-handle"><svg width="10" height="10" focusable="false"><g fill-rule="nonzero"><path d="M8.1 1.1A.5.5 0 1 1 9 2l-7 7A.5.5 0 1 1 1 8l7-7ZM8.1 5.1A.5.5 0 1 1 9 6l-3 3A.5.5 0 1 1 5 8l3-3Z"></path></g></svg></div></div></div><div aria-hidden="true" class="tox-view-wrap" style="display: none;"><div class="tox-view-wrap__slot-container"></div></div><div aria-hidden="true" class="tox-throbber" style="display: none;"></div></div><div class="tox tox-silver-sink tox-silver-popup-sink tox-tinymce-aux" style="position: relative;"></div></div><div><label class="accesshide" for="field_41_content1">Formato</label><select id="field_41_content1" name="field_41_content1"><option value="1" selected="selected">Formato HTML</option></select></div></div></div>
        </div>

        <div class="mb-3 pt-3">
            <div class="font-weight-bold">Marcas</div>
            <div class="datatagcontrol"><select class="custom-select" name="tags[]" id="tags" multiple="" aria-hidden="true" data-aria-hidden-tab-index="" tabindex="-1" style="visibility: hidden; display: none;"></select><span class="sr-only" id="form_autocomplete_selection-1781203670169-label">Ítems seleccioandos:</span>
<div class="form-autocomplete-selection w-100 form-autocomplete-multiple" id="form_autocomplete_selection-1781203670169" aria-labelledby="form_autocomplete_selection-1781203670169-label" role="listbox" aria-atomic="true" tabindex="0" aria-multiselectable="true">


        <span class="m-1 h-5">No hay selección</span>
</div>
<div class="form-autocomplete-input d-md-inline-block mr-md-2 position-relative">
    <input type="text" id="form_autocomplete_input-1781203670169" class="form-control" list="form_autocomplete_suggestions-1781203670169" placeholder="Introduzca etiquetas..." role="combobox" aria-expanded="false" autocomplete="off" autocorrect="off" autocapitalize="off" aria-autocomplete="list" aria-owns="form_autocomplete_suggestions-1781203670169 form_autocomplete_selection-1781203670169" data-tags="1" data-multiple="multiple" data-fieldtype="autocomplete" style="min-width: 23ch;">
    <span class="form-autocomplete-downarrow position-absolute p-1" id="form_autocomplete_downarrow-1781203670169">▼</span>
</div>
<ul class="form-autocomplete-suggestions" id="form_autocomplete_suggestions-1781203670169" role="listbox" aria-label="Sugerencias" aria-hidden="true" tabindex="-1" style="display: none;">
</ul></div>
        </div>
</div><div id="sticky-footer" class="stickyfooter bg-white border-top">
    <div class="sticky-footer-content-wrapper h-100 d-flex justify-content-center">
        <div class="sticky-footer-content w-100 d-flex align-items-center px-3 py-2  justify-content-end">
                <a class="btn btn-secondary mx-1" role="button" href="https://ingenieria.campus.mdp.edu.ar/mod/data/view.php?d=15&amp;amp;advanced=0&amp;amp;paging&amp;amp;page=0">Cancelar</a><input type="submit" name="saveandview" value="Guardar" class="btn btn-primary mx-1"><input type="submit" name="saveandadd" value="Guardar y añadir otro" class="btn btn-primary mx-1">
        </div>
    </div>
</div></div></div></form>
```

## DB de Logs de Asistencia

### URL:

`https://ingenieria.campus.mdp.edu.ar/mod/data/view.php?id=54784`

### HTML Vista:

```
<form action="https://ingenieria.campus.mdp.edu.ar/mod/data/view.php?d=16&amp;sesskey=bN4VoosUA9" method="post"><div id="data-singleview-content" class="box "><div id="defaulttemplate-single" class="my-5">
    <div class="defaulttemplate-single-body my-5">
        <div class="row my-6">
            <div class="col-auto"><a href="https://ingenieria.campus.mdp.edu.ar/user/view.php?id=2987&amp;course=1732" class="d-inline-block aabtn"><img src="https://ingenieria.campus.mdp.edu.ar/pluginfile.php/36551/user/icon/adaptable/f1?rev=890264" class="userpicture" width="64" height="64" alt="MARTIN ESTEBAN GIRAU" title="MARTIN ESTEBAN GIRAU"></a></div>
            <div class="col">
                <div class="row h-100">
                    <div class="col-3 align-self-center">
                        <a href="https://ingenieria.campus.mdp.edu.ar/user/view.php?id=2987&amp;course=1732">MARTIN ESTEBAN GIRAU</a><br><span class="data-timeinfo"><span title="jueves, 11 de junio de 2026, 14:33">11 jun 2026</span></span>
                    </div>
                    <div class="col-4 col-md-6 text-right align-self-center data-timeinfo">
                        <span class="font-weight-bold ">Editado por última vez:&nbsp;</span><span title="jueves, 11 de junio de 2026, 14:33">11 jun 2026</span>
                    </div>
                    <div class="col-4 col-md-3 ml-auto align-self-center d-flex flex-row-reverse">
                        <div><div class="action-menu moodle-actionmenu entry-actionsmenu" id="action-menu-6" data-enhance="moodle-core-actionmenu">

        <div class="menubar d-flex " id="action-menu-6-menubar">




                <div class="action-menu-trigger">
                    <div class="dropdown">
                        <a href="#" tabindex="0" class="btn btn-icon d-flex align-items-center justify-content-center no-caret  dropdown-toggle icon-no-margin" id="action-menu-toggle-6" aria-label="Acciones" data-toggle="dropdown" role="button" aria-haspopup="true" aria-expanded="false" aria-controls="action-menu-6-menu">

                            <i class="icon fa fa-ellipsis-v fa-fw" title="Acciones" role="img" aria-label="Acciones"></i>

                            <b class="caret"></b>
                        </a>
                            <div class="dropdown-menu menu dropdown-menu-right" id="action-menu-6-menu" data-rel="menu-content" aria-labelledby="action-menu-toggle-6" role="menu">
                                                                <a href="https://ingenieria.campus.mdp.edu.ar/mod/data/edit.php?d=16&amp;mode=single&amp;page=0&amp;rid=23&amp;sesskey=bN4VoosUA9&amp;backto=https%253A%252F%252Fingenieria.campus.mdp.edu.ar%252Fmod%252Fdata%252Fview.php%253Fd%253D16%2526mode%253Dsingle%2526page%253D0%2526rid%253D23" class="dropdown-item menu-action" role="menuitem" tabindex="-1">
                                <span class="menu-action-text">Editar</span>
                        </a>
                                                                <a href="https://ingenieria.campus.mdp.edu.ar/mod/data/view.php?d=16&amp;mode=single&amp;page=0&amp;delete=23&amp;sesskey=bN4VoosUA9" class="dropdown-item menu-action" role="menuitem" tabindex="-1">
                                <span class="menu-action-text">Borrar</span>
                        </a>
                            </div>
                    </div>
                </div>

        </div>

</div></div>
                        <div class="ml-auto my-auto "></div>
                    </div>
                </div>
            </div>
        </div>
        <hr>

        <div class="my-6">
            <div class="mt-4">
                <span class="font-weight-bold">nombre_alumno</span>
                <p class="mt-2">Martin Girau</p>
            </div>
            <div class="mt-4">
                <span class="font-weight-bold">id_alumno</span>
                <p class="mt-2">2987</p>
            </div>
            <div class="mt-4">
                <span class="font-weight-bold">nombre_tutor</span>
                <p class="mt-2">Tutor_1</p>
            </div>
            <div class="mt-4">
                <span class="font-weight-bold">origen</span>
                <p class="mt-2">Proactivo<br>
</p>
            </div>
            <div class="mt-4">
                <span class="font-weight-bold">mensaje</span>
                <p class="mt-2"></p><div class="data-field-html"><p>Mensaje Ejemplo</p></div><p></p>
            </div>
        <div class="tag_otherfields ">
</div>
            <div class="mt-4">
                <span class="font-weight-bold">Marcas</span>
                <p class="mt-2"></p>
            </div>
        </div>
    </div>
</div><div style="display:none" id="cmt-tmpl"><div class="comment-message"><div class="comment-message-meta mr-3"><span class="picture">___picture___</span><span class="user">___name___</span> - <span class="time">___time___</span></div><div class="text">___content___</div></div></div><div class="mdl-left"><a class="showcommentsnonjs" href="https://ingenieria.campus.mdp.edu.ar/mod/data/view.php?d=16&amp;rid=23&amp;nonjscomment=1&amp;comment_itemid=23&amp;comment_context=78639&amp;comment_component=mod_data&amp;comment_area=database_entry">Mostrar comentarios</a><a class="comment-link" id="comment-link-6a2af1778106d" href="#" role="button" aria-expanded="false"><i class="icon fa fa-caret-right fa-fw" title="Comentarios" role="img" aria-label="Comentarios"></i><span id="comment-link-text-6a2af1778106d">Comentarios (0)</span></a><div id="comment-ctrl-6a2af1778106d" class="comment-ctrl"><ul id="comment-list-6a2af1778106d" class="comment-list"><li class="first"></li></ul><div id="comment-pagination-6a2af1778106d" class="comment-pagination"></div><div class="comment-area"><div class="db"><label for="dlg-content-6a2af1778106d" class="sr-only">Comentario</label><textarea name="content" rows="2" id="dlg-content-6a2af1778106d" aria-label="Agregar un comentario..." cols="20" style="color: grey; --darkreader-inline-color: var(--darkreader-text-808080, #988f81);" data-darkreader-inline-color=""></textarea></div><div class="fd" id="comment-action-6a2af1778106d"><a id="comment-action-post-6a2af1778106d" href="#">Guardar comentario</a></div></div><div class="clearer"></div></div></div></div><div id="sticky-footer" class="stickyfooter bg-white border-top">
    <div class="sticky-footer-content-wrapper h-100 d-flex justify-content-center">
        <div class="sticky-footer-content w-100 d-flex align-items-center px-3 py-2  justify-content-end">
                <div class="navitem submit mr-auto ml-auto">

</div>
<div class="navitem">
        <a href="https://ingenieria.campus.mdp.edu.ar/mod/data/edit.php?id=54784&amp;backto=https%3A%2F%2Fingenieria.campus.mdp.edu.ar%2Fmod%2Fdata%2Fview.php%3Fd%3D16%26amp%3Bmode%3Dsingle%26amp%3Bpage%3D0" id="action_link6a2af17768750146" class="btn btn-primary mx-1" role="button">Añadir entrada</a>
</div>
        </div>
    </div>
</div></form>
```

### FORM PARA CREAR ENTRADAS:

```
<form enctype="multipart/form-data" action="edit.php" method="post"><div><input name="d" value="16" type="hidden"><input name="rid" value="0" type="hidden"><input name="sesskey" value="bN4VoosUA9" type="hidden"><div class="box generalbox boxaligncenter boxwidthwide"><h2>Nueva entrada</h2><div id="defaulttemplate-addentry">
        <div class="mb-3 pt-3">
            <div class="font-weight-bold">nombre_alumno</div>
            <div title=""><label for="field_42"><span class="accesshide">nombre_alumno</span><div class="inline-req"><i class="icon fa fa-exclamation-circle text-danger fa-fw" title="Campo obligatorio" role="img" aria-label="Campo obligatorio"></i></div></label><input class="basefieldinput form-control d-inline mod-data-input" type="text" name="field_42" id="field_42" value=""></div>
        </div>
        <div class="mb-3 pt-3">
            <div class="font-weight-bold">id_alumno</div>
            <div title=""><label for="field_43"><span class="accesshide">id_alumno</span><div class="inline-req"><i class="icon fa fa-exclamation-circle text-danger fa-fw" title="Campo obligatorio" role="img" aria-label="Campo obligatorio"></i></div></label><input class="basefieldinput form-control d-inline mod-data-input" type="text" name="field_43" id="field_43" value=""></div>
        </div>
        <div class="mb-3 pt-3">
            <div class="font-weight-bold">nombre_tutor</div>
            <div title=""><label for="field_44"><span class="accesshide">nombre_tutor</span></label><input class="basefieldinput form-control d-inline mod-data-input" type="text" name="field_44" id="field_44" value=""></div>
        </div>
        <div class="mb-3 pt-3">
            <div class="font-weight-bold">origen</div>
            <div title=""><input name="field_45[xxx]" type="hidden" value="xxx"><label for="field_45"><legend><span class="accesshide">origen&nbsp;Campo obligatorio</span></legend><div class="inline-req"><i class="icon fa fa-exclamation-circle text-danger fa-fw" title="Campo obligatorio" role="img" aria-label="Campo obligatorio"></i></div></label><select name="field_45[]" id="field_45" multiple="multiple" class="mod-data-input form-control"><option value="Proactivo">Proactivo</option><option value="Solicitud">Solicitud</option></select></div>
        </div>
        <div class="mb-3 pt-3">
            <div class="font-weight-bold">mensaje</div>
            <div title="Area de Texto Adicional para dar contexto de la situacion" class="d-inline-flex"><label for="field_46"><span class="accesshide">mensaje</span></label><input type="hidden" name="field_46_itemid" value="530630082"><div class="mod-data-input"><div><textarea id="field_46" name="field_46" rows="35" class="form-control" data-fieldtype="editor" cols="60" spellcheck="true" style="display: none;" aria-hidden="true"></textarea><div role="application" class="tox tox-tinymce" aria-disabled="false" style="visibility: hidden; height: 760px;"><div class="tox-editor-container"><div data-alloy-vertical-dir="toptobottom" class="tox-editor-header"><div role="menubar" data-alloy-tabstop="true" class="tox-menubar"><button aria-haspopup="true" role="menuitem" type="button" tabindex="-1" data-alloy-tabstop="true" unselectable="on" class="tox-mbtn tox-mbtn--select" aria-expanded="false" style="user-select: none; width: 51.4531px;"><span class="tox-mbtn__select-label">Editar</span><div class="tox-mbtn__select-chevron"><svg width="10" height="10" focusable="false"><path d="M8.7 2.2c.3-.3.8-.3 1 0 .4.4.4.9 0 1.2L5.7 7.8c-.3.3-.9.3-1.2 0L.2 3.4a.8.8 0 0 1 0-1.2c.3-.3.8-.3 1.1 0L5 6l3.7-3.8Z" fill-rule="nonzero"></path></svg></div></button><button aria-haspopup="true" role="menuitem" type="button" tabindex="-1" data-alloy-tabstop="true" unselectable="on" class="tox-mbtn tox-mbtn--select" style="user-select: none; width: 36px;" aria-expanded="false"><span class="tox-mbtn__select-label">Ver</span><div class="tox-mbtn__select-chevron"><svg width="10" height="10" focusable="false"><path d="M8.7 2.2c.3-.3.8-.3 1 0 .4.4.4.9 0 1.2L5.7 7.8c-.3.3-.9.3-1.2 0L.2 3.4a.8.8 0 0 1 0-1.2c.3-.3.8-.3 1.1 0L5 6l3.7-3.8Z" fill-rule="nonzero"></path></svg></div></button><button aria-haspopup="true" role="menuitem" type="button" tabindex="-1" data-alloy-tabstop="true" unselectable="on" class="tox-mbtn tox-mbtn--select" style="user-select: none; width: 62.5156px;" aria-expanded="false"><span class="tox-mbtn__select-label">Insertar</span><div class="tox-mbtn__select-chevron"><svg width="10" height="10" focusable="false"><path d="M8.7 2.2c.3-.3.8-.3 1 0 .4.4.4.9 0 1.2L5.7 7.8c-.3.3-.9.3-1.2 0L.2 3.4a.8.8 0 0 1 0-1.2c.3-.3.8-.3 1.1 0L5 6l3.7-3.8Z" fill-rule="nonzero"></path></svg></div></button><button aria-haspopup="true" role="menuitem" type="button" tabindex="-1" data-alloy-tabstop="true" unselectable="on" class="tox-mbtn tox-mbtn--select" style="user-select: none; width: 68.0469px;" aria-expanded="false"><span class="tox-mbtn__select-label">Formato</span><div class="tox-mbtn__select-chevron"><svg width="10" height="10" focusable="false"><path d="M8.7 2.2c.3-.3.8-.3 1 0 .4.4.4.9 0 1.2L5.7 7.8c-.3.3-.9.3-1.2 0L.2 3.4a.8.8 0 0 1 0-1.2c.3-.3.8-.3 1.1 0L5 6l3.7-3.8Z" fill-rule="nonzero"></path></svg></div></button><button aria-haspopup="true" role="menuitem" type="button" tabindex="-1" data-alloy-tabstop="true" unselectable="on" class="tox-mbtn tox-mbtn--select" style="user-select: none; width: 98.625px;" aria-expanded="false"><span class="tox-mbtn__select-label">Herramientas</span><div class="tox-mbtn__select-chevron"><svg width="10" height="10" focusable="false"><path d="M8.7 2.2c.3-.3.8-.3 1 0 .4.4.4.9 0 1.2L5.7 7.8c-.3.3-.9.3-1.2 0L.2 3.4a.8.8 0 0 1 0-1.2c.3-.3.8-.3 1.1 0L5 6l3.7-3.8Z" fill-rule="nonzero"></path></svg></div></button><button aria-haspopup="true" role="menuitem" type="button" tabindex="-1" data-alloy-tabstop="true" unselectable="on" class="tox-mbtn tox-mbtn--select" style="user-select: none; width: 47.6406px;" aria-expanded="false"><span class="tox-mbtn__select-label">Tabla</span><div class="tox-mbtn__select-chevron"><svg width="10" height="10" focusable="false"><path d="M8.7 2.2c.3-.3.8-.3 1 0 .4.4.4.9 0 1.2L5.7 7.8c-.3.3-.9.3-1.2 0L.2 3.4a.8.8 0 0 1 0-1.2c.3-.3.8-.3 1.1 0L5 6l3.7-3.8Z" fill-rule="nonzero"></path></svg></div></button><button aria-haspopup="true" role="menuitem" type="button" tabindex="-1" data-alloy-tabstop="true" unselectable="on" class="tox-mbtn tox-mbtn--select" style="user-select: none; width: 54.8281px;" aria-expanded="false"><span class="tox-mbtn__select-label">Ayuda</span><div class="tox-mbtn__select-chevron"><svg width="10" height="10" focusable="false"><path d="M8.7 2.2c.3-.3.8-.3 1 0 .4.4.4.9 0 1.2L5.7 7.8c-.3.3-.9.3-1.2 0L.2 3.4a.8.8 0 0 1 0-1.2c.3-.3.8-.3 1.1 0L5 6l3.7-3.8Z" fill-rule="nonzero"></path></svg></div></button></div><div role="group" class="tox-toolbar-overlord" aria-disabled="false"><div role="group" class="tox-toolbar__primary"><div title="historial" role="toolbar" data-alloy-tabstop="true" tabindex="-1" class="tox-toolbar__group"><button aria-label="Deshacer" title="Deshacer" type="button" tabindex="-1" class="tox-tbtn tox-tbtn--disabled" aria-disabled="true" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M6.4 8H12c3.7 0 6.2 2 6.8 5.1.6 2.7-.4 5.6-2.3 6.8a1 1 0 0 1-1-1.8c1.1-.6 1.8-2.7 1.4-4.6-.5-2.1-2.1-3.5-4.9-3.5H6.4l3.3 3.3a1 1 0 1 1-1.4 1.4l-5-5a1 1 0 0 1 0-1.4l5-5a1 1 0 0 1 1.4 1.4L6.4 8Z" fill-rule="nonzero"></path></svg></span></button><button aria-label="Rehacer" title="Rehacer" type="button" tabindex="-1" class="tox-tbtn tox-tbtn--disabled" aria-disabled="true" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M17.6 10H12c-2.8 0-4.4 1.4-4.9 3.5-.4 2 .3 4 1.4 4.6a1 1 0 1 1-1 1.8c-2-1.2-2.9-4.1-2.3-6.8.6-3 3-5.1 6.8-5.1h5.6l-3.3-3.3a1 1 0 1 1 1.4-1.4l5 5a1 1 0 0 1 0 1.4l-5 5a1 1 0 0 1-1.4-1.4l3.3-3.3Z" fill-rule="nonzero"></path></svg></span></button></div><div title="formato" role="toolbar" data-alloy-tabstop="true" tabindex="-1" class="tox-toolbar__group"><button aria-label="Negrita" title="Negrita" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M7.8 19c-.3 0-.5 0-.6-.2l-.2-.5V5.7c0-.2 0-.4.2-.5l.6-.2h5c1.5 0 2.7.3 3.5 1 .7.6 1.1 1.4 1.1 2.5a3 3 0 0 1-.6 1.9c-.4.6-1 1-1.6 1.2.4.1.9.3 1.3.6s.8.7 1 1.2c.4.4.5 1 .5 1.6 0 1.3-.4 2.3-1.3 3-.8.7-2.1 1-3.8 1H7.8Zm5-8.3c.6 0 1.2-.1 1.6-.5.4-.3.6-.7.6-1.3 0-1.1-.8-1.7-2.3-1.7H9.3v3.5h3.4Zm.5 6c.7 0 1.3-.1 1.7-.4.4-.4.6-.9.6-1.5s-.2-1-.7-1.4c-.4-.3-1-.4-2-.4H9.4v3.8h4Z" fill-rule="evenodd"></path></svg></span></button><button aria-label="Cursiva" title="Cursiva" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="m16.7 4.7-.1.9h-.3c-.6 0-1 0-1.4.3-.3.3-.4.6-.5 1.1l-2.1 9.8v.6c0 .5.4.8 1.4.8h.2l-.2.8H8l.2-.8h.2c1.1 0 1.8-.5 2-1.5l2-9.8.1-.5c0-.6-.4-.8-1.4-.8h-.3l.2-.9h5.8Z" fill-rule="evenodd"></path></svg></span></button></div><div role="toolbar" data-alloy-tabstop="true" tabindex="-1" class="tox-toolbar__group"><button aria-label="Mostrar u ocultar elementos adicionales de la barra de herramientas" title="Mostrar u ocultar elementos adicionales de la barra de herramientas" type="button" tabindex="-1" data-alloy-tabstop="true" class="tox-tbtn" aria-pressed="false"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M6 10a2 2 0 0 0-2 2c0 1.1.9 2 2 2a2 2 0 0 0 2-2 2 2 0 0 0-2-2Zm12 0a2 2 0 0 0-2 2c0 1.1.9 2 2 2a2 2 0 0 0 2-2 2 2 0 0 0-2-2Zm-6 0a2 2 0 0 0-2 2c0 1.1.9 2 2 2a2 2 0 0 0 2-2 2 2 0 0 0-2-2Z" fill-rule="nonzero"></path></svg></span></button></div></div><div role="group" class="tox-toolbar__overflow tox-toolbar__overflow--closed" style="height: 0px;"><div title="content" role="toolbar" data-alloy-tabstop="true" tabindex="-1" class="tox-toolbar__group"><button aria-label="Imagen" title="Imagen" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="m5 15.7 3.3-3.2c.3-.3.7-.3 1 0L12 15l4.1-4c.3-.4.8-.4 1 0l2 1.9V5H5v10.7ZM5 18V19h3l2.8-2.9-2-2L5 17.9Zm14-3-2.5-2.4-6.4 6.5H19v-4ZM4 3h16c.6 0 1 .4 1 1v16c0 .6-.4 1-1 1H4a1 1 0 0 1-1-1V4c0-.6.4-1 1-1Zm6 8a2 2 0 1 0 0-4 2 2 0 0 0 0 4Z" fill-rule="nonzero"></path></svg></span></button><button aria-label="Multimedios" title="Multimedios" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M4 3h16c.6 0 1 .4 1 1v16c0 .6-.4 1-1 1H4a1 1 0 0 1-1-1V4c0-.6.4-1 1-1Zm1 2v14h14V5H5Zm4.8 2.6 5.6 4a.5.5 0 0 1 0 .8l-5.6 4A.5.5 0 0 1 9 16V8a.5.5 0 0 1 .8-.4Z" fill-rule="nonzero"></path></svg></span></button><button aria-label="Grabar audio" title="Grabar audio" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg data-buttonsource="moodle" width="24" height="24" xmlns="http://www.w3.org/2000/svg" focusable="false">
        <image href="https://ingenieria.campus.mdp.edu.ar/theme/image.php/adaptable/tiny_recordrtc/1775501275/audio" width="24" height="24"></image>
</svg></span></button><button aria-label="Grabar video" title="Grabar video" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg data-buttonsource="moodle" width="24" height="24" xmlns="http://www.w3.org/2000/svg" focusable="false">
        <image href="https://ingenieria.campus.mdp.edu.ar/theme/image.php/adaptable/tiny_recordrtc/1775501275/video" width="24" height="24"></image>
</svg></span></button><button aria-label="Configurar contenido H5P" title="Configurar contenido H5P" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg data-buttonsource="moodle" width="24" height="24" xmlns="http://www.w3.org/2000/svg" focusable="false">
        <image href="https://ingenieria.campus.mdp.edu.ar/theme/image.php/adaptable/tiny_h5p/1775501275/icon" width="24" height="24"></image>
</svg></span></button><button aria-label="Enlace" title="Enlace" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M6.2 12.3a1 1 0 0 1 1.4 1.4l-2 2a2 2 0 1 0 2.6 2.8l4.8-4.8a1 1 0 0 0 0-1.4 1 1 0 1 1 1.4-1.3 2.9 2.9 0 0 1 0 4L9.6 20a3.9 3.9 0 0 1-5.5-5.5l2-2Zm11.6-.6a1 1 0 0 1-1.4-1.4l2-2a2 2 0 1 0-2.6-2.8L11 10.3a1 1 0 0 0 0 1.4A1 1 0 1 1 9.6 13a2.9 2.9 0 0 1 0-4L14.4 4a3.9 3.9 0 0 1 5.5 5.5l-2 2Z" fill-rule="nonzero"></path></svg></span></button><button aria-label="Desenlanzar" title="Desenlanzar" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M6.2 12.3a1 1 0 0 1 1.4 1.4l-2 2a2 2 0 1 0 2.6 2.8l4.8-4.8a1 1 0 0 0 0-1.4 1 1 0 1 1 1.4-1.3 2.9 2.9 0 0 1 0 4L9.6 20a3.9 3.9 0 0 1-5.5-5.5l2-2Zm11.6-.6a1 1 0 0 1-1.4-1.4l2.1-2a2 2 0 1 0-2.7-2.8L11 10.3a1 1 0 0 0 0 1.4A1 1 0 1 1 9.6 13a2.9 2.9 0 0 1 0-4L14.4 4a3.9 3.9 0 0 1 5.5 5.5l-2 2ZM7.6 6.3a.8.8 0 0 1-1 1.1L3.3 4.2a.7.7 0 1 1 1-1l3.2 3.1ZM5.1 8.6a.8.8 0 0 1 0 1.5H3a.8.8 0 0 1 0-1.5H5Zm5-3.5a.8.8 0 0 1-1.5 0V3a.8.8 0 0 1 1.5 0V5Zm6 11.8a.8.8 0 0 1 1-1l3.2 3.2a.8.8 0 0 1-1 1L16 17Zm-2.2 2a.8.8 0 0 1 1.5 0V21a.8.8 0 0 1-1.5 0V19Zm5-3.5a.7.7 0 1 1 0-1.5H21a.8.8 0 0 1 0 1.5H19Z" fill-rule="nonzero"></path></svg></span></button></div><div title="Ver" role="toolbar" data-alloy-tabstop="true" tabindex="-1" class="tox-toolbar__group"><button aria-label="Pantalla completa" title="Pantalla completa" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="m15.3 10-1.2-1.3 2.9-3h-2.3a.9.9 0 1 1 0-1.7H19c.5 0 .9.4.9.9v4.4a.9.9 0 1 1-1.8 0V7l-2.9 3Zm0 4 3 3v-2.3a.9.9 0 1 1 1.7 0V19c0 .5-.4.9-.9.9h-4.4a.9.9 0 1 1 0-1.8H17l-3-2.9 1.3-1.2ZM10 15.4l-2.9 3h2.3a.9.9 0 1 1 0 1.7H5a.9.9 0 0 1-.9-.9v-4.4a.9.9 0 1 1 1.8 0V17l2.9-3 1.2 1.3ZM8.7 10 5.7 7v2.3a.9.9 0 0 1-1.7 0V5c0-.5.4-.9.9-.9h4.4a.9.9 0 0 1 0 1.8H7l3 2.9-1.3 1.2Z" fill-rule="nonzero"></path></svg></span></button></div><div title="alineación" role="toolbar" data-alloy-tabstop="true" tabindex="-1" class="tox-toolbar__group"><button aria-label="Alinear a la izquierda" title="Alinear a la izquierda" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M5 5h14c.6 0 1 .4 1 1s-.4 1-1 1H5a1 1 0 1 1 0-2Zm0 4h8c.6 0 1 .4 1 1s-.4 1-1 1H5a1 1 0 1 1 0-2Zm0 8h8c.6 0 1 .4 1 1s-.4 1-1 1H5a1 1 0 0 1 0-2Zm0-4h14c.6 0 1 .4 1 1s-.4 1-1 1H5a1 1 0 0 1 0-2Z" fill-rule="evenodd"></path></svg></span></button><button aria-label="Alinear al centro" title="Alinear al centro" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M5 5h14c.6 0 1 .4 1 1s-.4 1-1 1H5a1 1 0 1 1 0-2Zm3 4h8c.6 0 1 .4 1 1s-.4 1-1 1H8a1 1 0 1 1 0-2Zm0 8h8c.6 0 1 .4 1 1s-.4 1-1 1H8a1 1 0 0 1 0-2Zm-3-4h14c.6 0 1 .4 1 1s-.4 1-1 1H5a1 1 0 0 1 0-2Z" fill-rule="evenodd"></path></svg></span></button><button aria-label="Alinear a la derecha" title="Alinear a la derecha" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M5 5h14c.6 0 1 .4 1 1s-.4 1-1 1H5a1 1 0 1 1 0-2Zm6 4h8c.6 0 1 .4 1 1s-.4 1-1 1h-8a1 1 0 0 1 0-2Zm0 8h8c.6 0 1 .4 1 1s-.4 1-1 1h-8a1 1 0 0 1 0-2Zm-6-4h14c.6 0 1 .4 1 1s-.4 1-1 1H5a1 1 0 0 1 0-2Z" fill-rule="evenodd"></path></svg></span></button></div><div title="directionality" role="toolbar" data-alloy-tabstop="true" tabindex="-1" class="tox-toolbar__group"><button aria-label="Izquierda a derecha" title="Izquierda a derecha" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M11 5h7a1 1 0 0 1 0 2h-1v11a1 1 0 0 1-2 0V7h-2v11a1 1 0 0 1-2 0v-6c-.5 0-1 0-1.4-.3A3.4 3.4 0 0 1 7.8 10a3.3 3.3 0 0 1 0-2.8 3.4 3.4 0 0 1 1.8-1.8L11 5ZM4.4 16.2 6.2 15l-1.8-1.2a1 1 0 0 1 1.2-1.6l3 2a1 1 0 0 1 0 1.6l-3 2a1 1 0 1 1-1.2-1.6Z" fill-rule="evenodd"></path></svg></span></button><button aria-label="Derecha a izquierda" title="Derecha a izquierda" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M8 5h8v2h-2v12h-2V7h-2v12H8v-7c-.5 0-1 0-1.4-.3A3.4 3.4 0 0 1 4.8 10a3.3 3.3 0 0 1 0-2.8 3.4 3.4 0 0 1 1.8-1.8L8 5Zm12 11.2a1 1 0 1 1-1 1.6l-3-2a1 1 0 0 1 0-1.6l3-2a1 1 0 1 1 1 1.6L18.4 15l1.8 1.2Z" fill-rule="evenodd"></path></svg></span></button></div><div title="sangría" role="toolbar" data-alloy-tabstop="true" tabindex="-1" class="tox-toolbar__group"><button aria-label="Disminuir sangría" title="Disminuir sangría" type="button" tabindex="-1" class="tox-tbtn tox-tbtn--disabled" aria-disabled="true" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M7 5h12c.6 0 1 .4 1 1s-.4 1-1 1H7a1 1 0 1 1 0-2Zm5 4h7c.6 0 1 .4 1 1s-.4 1-1 1h-7a1 1 0 0 1 0-2Zm0 4h7c.6 0 1 .4 1 1s-.4 1-1 1h-7a1 1 0 0 1 0-2Zm-5 4h12a1 1 0 0 1 0 2H7a1 1 0 0 1 0-2Zm1.6-3.8a1 1 0 0 1-1.2 1.6l-3-2a1 1 0 0 1 0-1.6l3-2a1 1 0 0 1 1.2 1.6L6.8 12l1.8 1.2Z" fill-rule="evenodd"></path></svg></span></button><button aria-label="Incrementar sangría" title="Incrementar sangría" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M7 5h12c.6 0 1 .4 1 1s-.4 1-1 1H7a1 1 0 1 1 0-2Zm5 4h7c.6 0 1 .4 1 1s-.4 1-1 1h-7a1 1 0 0 1 0-2Zm0 4h7c.6 0 1 .4 1 1s-.4 1-1 1h-7a1 1 0 0 1 0-2Zm-5 4h12a1 1 0 0 1 0 2H7a1 1 0 0 1 0-2Zm-2.6-3.8L6.2 12l-1.8-1.2a1 1 0 0 1 1.2-1.6l3 2a1 1 0 0 1 0 1.6l-3 2a1 1 0 1 1-1.2-1.6Z" fill-rule="evenodd"></path></svg></span></button></div><div title="lists" role="toolbar" data-alloy-tabstop="true" tabindex="-1" class="tox-toolbar__group"><button aria-label="Lista de viñetas" title="Lista de viñetas" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M11 5h8c.6 0 1 .4 1 1s-.4 1-1 1h-8a1 1 0 0 1 0-2Zm0 6h8c.6 0 1 .4 1 1s-.4 1-1 1h-8a1 1 0 0 1 0-2Zm0 6h8c.6 0 1 .4 1 1s-.4 1-1 1h-8a1 1 0 0 1 0-2ZM4.5 6c0-.4.1-.8.4-1 .3-.4.7-.5 1.1-.5.4 0 .8.1 1 .4.4.3.5.7.5 1.1 0 .4-.1.8-.4 1-.3.4-.7.5-1.1.5-.4 0-.8-.1-1-.4-.4-.3-.5-.7-.5-1.1Zm0 6c0-.4.1-.8.4-1 .3-.4.7-.5 1.1-.5.4 0 .8.1 1 .4.4.3.5.7.5 1.1 0 .4-.1.8-.4 1-.3.4-.7.5-1.1.5-.4 0-.8-.1-1-.4-.4-.3-.5-.7-.5-1.1Zm0 6c0-.4.1-.8.4-1 .3-.4.7-.5 1.1-.5.4 0 .8.1 1 .4.4.3.5.7.5 1.1 0 .4-.1.8-.4 1-.3.4-.7.5-1.1.5-.4 0-.8-.1-1-.4-.4-.3-.5-.7-.5-1.1Z" fill-rule="evenodd"></path></svg></span></button><button aria-label="Lista numerada" title="Lista numerada" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M10 17h8c.6 0 1 .4 1 1s-.4 1-1 1h-8a1 1 0 0 1 0-2Zm0-6h8c.6 0 1 .4 1 1s-.4 1-1 1h-8a1 1 0 0 1 0-2Zm0-6h8c.6 0 1 .4 1 1s-.4 1-1 1h-8a1 1 0 1 1 0-2ZM6 4v3.5c0 .3-.2.5-.5.5a.5.5 0 0 1-.5-.5V5h-.5a.5.5 0 0 1 0-1H6Zm-1 8.8.2.2h1.3c.3 0 .5.2.5.5s-.2.5-.5.5H4.9a1 1 0 0 1-.9-1V13c0-.4.3-.8.6-1l1.2-.4.2-.3a.2.2 0 0 0-.2-.2H4.5a.5.5 0 0 1-.5-.5c0-.3.2-.5.5-.5h1.6c.5 0 .9.4.9 1v.1c0 .4-.3.8-.6 1l-1.2.4-.2.3ZM7 17v2c0 .6-.4 1-1 1H4.5a.5.5 0 0 1 0-1h1.2c.2 0 .3-.1.3-.3 0-.2-.1-.3-.3-.3H4.4a.4.4 0 1 1 0-.8h1.3c.2 0 .3-.1.3-.3 0-.2-.1-.3-.3-.3H4.5a.5.5 0 1 1 0-1H6c.6 0 1 .4 1 1Z" fill-rule="evenodd"></path></svg></span></button></div><div title="Avanzado" role="toolbar" data-alloy-tabstop="true" tabindex="-1" class="tox-toolbar__group"><button aria-label="Editor de ecuación" title="Editor de ecuación" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg data-buttonsource="moodle" width="24" height="24" xmlns="http://www.w3.org/2000/svg" focusable="false">
        <image href="https://ingenieria.campus.mdp.edu.ar/theme/image.php/adaptable/tiny_equation/1775501275/icon" width="24" height="24"></image>
</svg></span></button></div></div></div><div class="tox-anchorbar"></div></div><div class="tox-sidebar-wrap" style="height: 748.125px;"><div class="tox-edit-area"><iframe id="field_46_ifr" frameborder="0" allowtransparency="true" title="Área de Texto Enriquecido" class="tox-edit-area__iframe" srcdoc="&lt;!DOCTYPE html&gt;&lt;html&gt;&lt;head&gt;&lt;meta http-equiv=&quot;Content-Type&quot; content=&quot;text/html; charset=UTF-8&quot; /&gt;&lt;/head&gt;&lt;body id=&quot;tinymce&quot; class=&quot;mce-content-body &quot; data-id=&quot;field_46&quot; aria-label=&quot;Área de texto enriquecido. Pulse ALT-0 para abrir la ayuda.&quot;&gt;&lt;br&gt;&lt;/body&gt;&lt;/html&gt;"></iframe></div><div role="presentation" class="tox-sidebar"><div data-alloy-tabstop="true" tabindex="-1" class="tox-sidebar__slider tox-sidebar--sliding-closed" style="width: 0px;"><div class="tox-sidebar__pane-container"></div></div></div></div><div class="tox-bottom-anchorbar"></div><div class="tox-statusbar"><div class="tox-statusbar__text-container tox-statusbar__text-container--flex-start"><div role="navigation" data-alloy-tabstop="true" class="tox-statusbar__path" aria-disabled="false"><div data-index="0" aria-level="1" role="button" tabindex="-1" class="tox-statusbar__path-item" aria-disabled="false">p</div></div><div class="tox-statusbar__right-container"><button type="button" tabindex="-1" data-alloy-tabstop="true" class="tox-statusbar__wordcount">0 palabras</button><span class="tox-statusbar__branding"><a href="https://www.tiny.cloud/powered-by-tiny?utm_campaign=poweredby&amp;utm_source=tiny&amp;utm_medium=referral&amp;utm_content=v6" rel="noopener" target="_blank" aria-label="Con tecnología de Tiny" tabindex="-1"><svg width="50px" height="16px" viewBox="0 0 50 16" xmlns="http://www.w3.org/2000/svg">
  <path fill-rule="evenodd" clip-rule="evenodd" d="M10.143 0c2.608.015 5.186 2.178 5.186 5.331 0 0 .077 3.812-.084 4.87-.361 2.41-2.164 4.074-4.65 4.496-1.453.284-2.523.49-3.212.623-.373.071-.634.122-.785.152-.184.038-.997.145-1.35.145-2.732 0-5.21-2.04-5.248-5.33 0 0 0-3.514.03-4.442.093-2.4 1.758-4.342 4.926-4.963 0 0 3.875-.752 4.036-.782.368-.07.775-.1 1.15-.1Zm1.826 2.8L5.83 3.989v2.393l-2.455.475v5.968l6.137-1.189V9.243l2.456-.476V2.8ZM5.83 6.382l3.682-.713v3.574l-3.682.713V6.382Zm27.173-1.64-.084-1.066h-2.226v9.132h2.456V7.743c-.008-1.151.998-2.064 2.149-2.072 1.15-.008 1.987.92 1.995 2.072v5.065h2.455V7.359c-.015-2.18-1.657-3.929-3.837-3.913a3.993 3.993 0 0 0-2.908 1.296Zm-6.3-4.266L29.16 0v2.387l-2.456.475V.476Zm0 3.2v9.132h2.456V3.676h-2.456Zm18.179 11.787L49.11 3.676H46.58l-1.612 4.527-.46 1.382-.384-1.382-1.611-4.527H39.98l3.3 9.132L42.15 16l2.732-.537ZM22.867 9.738c0 .752.568 1.075.921 1.075.353 0 .668-.047.998-.154l.537 1.765c-.23.154-.92.537-2.225.537-1.305 0-2.655-.997-2.686-2.686a136.877 136.877 0 0 1 0-4.374H18.8V3.676h1.612v-1.98l2.455-.476v2.456h2.302V5.9h-2.302v3.837Z"></path>
</svg></a></span></div></div><div title="Redimensionar" aria-label="Pulse las teclas de flechas arriba y abajo para cambiar el tamaño del editor." data-alloy-tabstop="true" tabindex="-1" class="tox-statusbar__resize-handle"><svg width="10" height="10" focusable="false"><g fill-rule="nonzero"><path d="M8.1 1.1A.5.5 0 1 1 9 2l-7 7A.5.5 0 1 1 1 8l7-7ZM8.1 5.1A.5.5 0 1 1 9 6l-3 3A.5.5 0 1 1 5 8l3-3Z"></path></g></svg></div></div></div><div aria-hidden="true" class="tox-view-wrap" style="display: none;"><div class="tox-view-wrap__slot-container"></div></div><div aria-hidden="true" class="tox-throbber" style="display: none;"></div></div><div class="tox tox-silver-sink tox-silver-popup-sink tox-tinymce-aux" style="position: relative;"></div></div><div><label class="accesshide" for="field_46_content1">Formato</label><select id="field_46_content1" name="field_46_content1"><option value="1" selected="selected">Formato HTML</option></select></div></div></div>
        </div>

        <div class="mb-3 pt-3">
            <div class="font-weight-bold">Marcas</div>
            <div class="datatagcontrol"><select class="custom-select" name="tags[]" id="tags" multiple="" aria-hidden="true" data-aria-hidden-tab-index="" tabindex="-1" style="visibility: hidden; display: none;"></select><span class="sr-only" id="form_autocomplete_selection-1781203950823-label">Ítems seleccioandos:</span>
<div class="form-autocomplete-selection w-100 form-autocomplete-multiple" id="form_autocomplete_selection-1781203950823" aria-labelledby="form_autocomplete_selection-1781203950823-label" role="listbox" aria-atomic="true" tabindex="0" aria-multiselectable="true">


        <span class="m-1 h-5">No hay selección</span>
</div>
<div class="form-autocomplete-input d-md-inline-block mr-md-2 position-relative">
    <input type="text" id="form_autocomplete_input-1781203950823" class="form-control" list="form_autocomplete_suggestions-1781203950823" placeholder="Introduzca etiquetas..." role="combobox" aria-expanded="false" autocomplete="off" autocorrect="off" autocapitalize="off" aria-autocomplete="list" aria-owns="form_autocomplete_suggestions-1781203950823 form_autocomplete_selection-1781203950823" data-tags="1" data-multiple="multiple" data-fieldtype="autocomplete" style="min-width: 23ch;">
    <span class="form-autocomplete-downarrow position-absolute p-1" id="form_autocomplete_downarrow-1781203950823">▼</span>
</div>
<ul class="form-autocomplete-suggestions" id="form_autocomplete_suggestions-1781203950823" role="listbox" aria-label="Sugerencias" aria-hidden="true" tabindex="-1" style="display: none;">
</ul></div>
        </div>
</div><div id="sticky-footer" class="stickyfooter bg-white border-top">
    <div class="sticky-footer-content-wrapper h-100 d-flex justify-content-center">
        <div class="sticky-footer-content w-100 d-flex align-items-center px-3 py-2  justify-content-end">
                <a class="btn btn-secondary mx-1" role="button" href="https://ingenieria.campus.mdp.edu.ar/mod/data/view.php?d=16&amp;amp;advanced=0&amp;amp;paging&amp;amp;page=0">Cancelar</a><input type="submit" name="saveandview" value="Guardar" class="btn btn-primary mx-1"><input type="submit" name="saveandadd" value="Guardar y añadir otro" class="btn btn-primary mx-1">
        </div>
    </div>
</div></div></div></form>
```

## Db Config

### URL:

`https://ingenieria.campus.mdp.edu.ar/mod/data/view.php?d=17&rid=24`

### HTML RELEVANTE:

(El Json queda pendiente a armar su version, final, faltan reunir datos, el agente debera armar junto con el desarrollador el json final)

```
<div class="data-field-html"><p></p>
<p>{<br>"urls": {<br>"base": "<a class="external-link" target="_blank" rel="noreferrer noopener">https://moodle.tuuniversidad.edu.ar"</a>,<br>"cmids": {<br>"encuesta_inicial": 0,<br>"encuesta_cuatrimestral": 0,<br>"db_solicitudes": 0,<br>"db_logs": 0,<br>"db_historico": 0,<br>"db_historico_1er_anio": 0,<br>"db_1er_anio": 0<br>},<br>"dataids": {<br>"db_solicitudes": 0,<br>"db_logs": 0,<br>"db_historico": 0,<br>"db_historico_1er_anio": 0,<br>"db_1er_anio": 0<br>}<br>},<br>"umbrales": {<br>"threshold_ird": 40,<br>"cooldown_actualizar_seg": 30,<br>"quarterly_warning_days": 90,<br>"cuatrimestres_desercion": 2,<br>"historico_delay_ms": 500,<br>"results_per_page_moodle": 10,<br>"page_size_paneles": 30<br>},<br>"encuesta_inicial": {<br>"preguntas": [<br>{<br>"id": "PENDIENTE — completar con selector HTML del Feedback",<br>"texto": "PENDIENTE — texto visible de la pregunta en Moodle",<br>"beta": 0.0,<br>"max_value": 0,<br>"respuestas": {<br>"PENDIENTE texto opción <a class="autolink" title="a" href="https://ingenieria.campus.mdp.edu.ar/mod/page/view.php?id=54299">A</a>": 0,<br>"PENDIENTE texto opción B": 0<br>}<br>}<br>]<br>},<br>"encuesta_cuatrimestral": {<br>"preguntas": [<br>{<br>"id": "PENDIENTE — completar con selector HTML del Feedback",<br>"texto": "PENDIENTE — texto visible de la pregunta en Moodle",<br>"beta": 0.0,<br>"max_value": 0,<br>"respuestas": {<br>"PENDIENTE texto opción <a class="autolink" title="a" href="https://ingenieria.campus.mdp.edu.ar/mod/page/view.php?id=54299">A</a>": 0,<br>"PENDIENTE texto opción B": 0<br>}<br>}<br>]<br>},<br>"preguntas_especiales": {<br>"id_percepcion_riesgo": "PENDIENTE — selector HTML de la pregunta ¿Te percibís en riesgo?",<br>"id_egreso": "PENDIENTE — selector HTML de la pregunta ¿Estás egresado?",<br>"id_anio_ingreso": "PENDIENTE — selector HTML de la pregunta ¿En qué año ingresaste?"<br>}<br>}</p></div>
```

### HTML FORM

```
<form enctype="multipart/form-data" action="edit.php" method="post"><div><input name="d" value="17" type="hidden"><input name="rid" value="0" type="hidden"><input name="sesskey" value="bN4VoosUA9" type="hidden"><div class="box generalbox boxaligncenter boxwidthwide"><h2>Nueva entrada</h2><div id="defaulttemplate-addentry">
        <div class="mb-3 pt-3">
            <div class="font-weight-bold">json_config</div>
            <div title="" class="d-inline-flex"><label for="field_47"><span class="accesshide">json_config</span><div class="inline-req"><i class="icon fa fa-exclamation-circle text-danger fa-fw" title="Campo obligatorio" role="img" aria-label="Campo obligatorio"></i></div></label><input type="hidden" name="field_47_itemid" value="55944539"><div class="mod-data-input"><div><textarea id="field_47" name="field_47" rows="500" class="form-control" data-fieldtype="editor" cols="120" spellcheck="true" style="display: none;" aria-hidden="true"></textarea><div role="application" class="tox tox-tinymce" aria-disabled="false" style="visibility: hidden; height: 10699px;"><div class="tox-editor-container"><div data-alloy-vertical-dir="toptobottom" class="tox-editor-header"><div role="menubar" data-alloy-tabstop="true" class="tox-menubar"><button aria-haspopup="true" role="menuitem" type="button" tabindex="-1" data-alloy-tabstop="true" unselectable="on" class="tox-mbtn tox-mbtn--select" aria-expanded="false" style="user-select: none; width: 51.4531px;"><span class="tox-mbtn__select-label">Editar</span><div class="tox-mbtn__select-chevron"><svg width="10" height="10" focusable="false"><path d="M8.7 2.2c.3-.3.8-.3 1 0 .4.4.4.9 0 1.2L5.7 7.8c-.3.3-.9.3-1.2 0L.2 3.4a.8.8 0 0 1 0-1.2c.3-.3.8-.3 1.1 0L5 6l3.7-3.8Z" fill-rule="nonzero"></path></svg></div></button><button aria-haspopup="true" role="menuitem" type="button" tabindex="-1" data-alloy-tabstop="true" unselectable="on" class="tox-mbtn tox-mbtn--select" style="user-select: none; width: 36px;" aria-expanded="false"><span class="tox-mbtn__select-label">Ver</span><div class="tox-mbtn__select-chevron"><svg width="10" height="10" focusable="false"><path d="M8.7 2.2c.3-.3.8-.3 1 0 .4.4.4.9 0 1.2L5.7 7.8c-.3.3-.9.3-1.2 0L.2 3.4a.8.8 0 0 1 0-1.2c.3-.3.8-.3 1.1 0L5 6l3.7-3.8Z" fill-rule="nonzero"></path></svg></div></button><button aria-haspopup="true" role="menuitem" type="button" tabindex="-1" data-alloy-tabstop="true" unselectable="on" class="tox-mbtn tox-mbtn--select" style="user-select: none; width: 62.5156px;" aria-expanded="false"><span class="tox-mbtn__select-label">Insertar</span><div class="tox-mbtn__select-chevron"><svg width="10" height="10" focusable="false"><path d="M8.7 2.2c.3-.3.8-.3 1 0 .4.4.4.9 0 1.2L5.7 7.8c-.3.3-.9.3-1.2 0L.2 3.4a.8.8 0 0 1 0-1.2c.3-.3.8-.3 1.1 0L5 6l3.7-3.8Z" fill-rule="nonzero"></path></svg></div></button><button aria-haspopup="true" role="menuitem" type="button" tabindex="-1" data-alloy-tabstop="true" unselectable="on" class="tox-mbtn tox-mbtn--select" style="user-select: none; width: 68.0469px;" aria-expanded="false"><span class="tox-mbtn__select-label">Formato</span><div class="tox-mbtn__select-chevron"><svg width="10" height="10" focusable="false"><path d="M8.7 2.2c.3-.3.8-.3 1 0 .4.4.4.9 0 1.2L5.7 7.8c-.3.3-.9.3-1.2 0L.2 3.4a.8.8 0 0 1 0-1.2c.3-.3.8-.3 1.1 0L5 6l3.7-3.8Z" fill-rule="nonzero"></path></svg></div></button><button aria-haspopup="true" role="menuitem" type="button" tabindex="-1" data-alloy-tabstop="true" unselectable="on" class="tox-mbtn tox-mbtn--select" style="user-select: none; width: 98.625px;" aria-expanded="false"><span class="tox-mbtn__select-label">Herramientas</span><div class="tox-mbtn__select-chevron"><svg width="10" height="10" focusable="false"><path d="M8.7 2.2c.3-.3.8-.3 1 0 .4.4.4.9 0 1.2L5.7 7.8c-.3.3-.9.3-1.2 0L.2 3.4a.8.8 0 0 1 0-1.2c.3-.3.8-.3 1.1 0L5 6l3.7-3.8Z" fill-rule="nonzero"></path></svg></div></button><button aria-haspopup="true" role="menuitem" type="button" tabindex="-1" data-alloy-tabstop="true" unselectable="on" class="tox-mbtn tox-mbtn--select" style="user-select: none; width: 47.6406px;" aria-expanded="false"><span class="tox-mbtn__select-label">Tabla</span><div class="tox-mbtn__select-chevron"><svg width="10" height="10" focusable="false"><path d="M8.7 2.2c.3-.3.8-.3 1 0 .4.4.4.9 0 1.2L5.7 7.8c-.3.3-.9.3-1.2 0L.2 3.4a.8.8 0 0 1 0-1.2c.3-.3.8-.3 1.1 0L5 6l3.7-3.8Z" fill-rule="nonzero"></path></svg></div></button><button aria-haspopup="true" role="menuitem" type="button" tabindex="-1" data-alloy-tabstop="true" unselectable="on" class="tox-mbtn tox-mbtn--select" style="user-select: none; width: 54.8281px;" aria-expanded="false"><span class="tox-mbtn__select-label">Ayuda</span><div class="tox-mbtn__select-chevron"><svg width="10" height="10" focusable="false"><path d="M8.7 2.2c.3-.3.8-.3 1 0 .4.4.4.9 0 1.2L5.7 7.8c-.3.3-.9.3-1.2 0L.2 3.4a.8.8 0 0 1 0-1.2c.3-.3.8-.3 1.1 0L5 6l3.7-3.8Z" fill-rule="nonzero"></path></svg></div></button></div><div role="group" class="tox-toolbar-overlord" aria-disabled="false"><div role="group" class="tox-toolbar__primary"><div title="historial" role="toolbar" data-alloy-tabstop="true" tabindex="-1" class="tox-toolbar__group"><button aria-label="Deshacer" title="Deshacer" type="button" tabindex="-1" class="tox-tbtn tox-tbtn--disabled" aria-disabled="true" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M6.4 8H12c3.7 0 6.2 2 6.8 5.1.6 2.7-.4 5.6-2.3 6.8a1 1 0 0 1-1-1.8c1.1-.6 1.8-2.7 1.4-4.6-.5-2.1-2.1-3.5-4.9-3.5H6.4l3.3 3.3a1 1 0 1 1-1.4 1.4l-5-5a1 1 0 0 1 0-1.4l5-5a1 1 0 0 1 1.4 1.4L6.4 8Z" fill-rule="nonzero"></path></svg></span></button><button aria-label="Rehacer" title="Rehacer" type="button" tabindex="-1" class="tox-tbtn tox-tbtn--disabled" aria-disabled="true" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M17.6 10H12c-2.8 0-4.4 1.4-4.9 3.5-.4 2 .3 4 1.4 4.6a1 1 0 1 1-1 1.8c-2-1.2-2.9-4.1-2.3-6.8.6-3 3-5.1 6.8-5.1h5.6l-3.3-3.3a1 1 0 1 1 1.4-1.4l5 5a1 1 0 0 1 0 1.4l-5 5a1 1 0 0 1-1.4-1.4l3.3-3.3Z" fill-rule="nonzero"></path></svg></span></button></div><div title="formato" role="toolbar" data-alloy-tabstop="true" tabindex="-1" class="tox-toolbar__group"><button aria-label="Negrita" title="Negrita" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M7.8 19c-.3 0-.5 0-.6-.2l-.2-.5V5.7c0-.2 0-.4.2-.5l.6-.2h5c1.5 0 2.7.3 3.5 1 .7.6 1.1 1.4 1.1 2.5a3 3 0 0 1-.6 1.9c-.4.6-1 1-1.6 1.2.4.1.9.3 1.3.6s.8.7 1 1.2c.4.4.5 1 .5 1.6 0 1.3-.4 2.3-1.3 3-.8.7-2.1 1-3.8 1H7.8Zm5-8.3c.6 0 1.2-.1 1.6-.5.4-.3.6-.7.6-1.3 0-1.1-.8-1.7-2.3-1.7H9.3v3.5h3.4Zm.5 6c.7 0 1.3-.1 1.7-.4.4-.4.6-.9.6-1.5s-.2-1-.7-1.4c-.4-.3-1-.4-2-.4H9.4v3.8h4Z" fill-rule="evenodd"></path></svg></span></button><button aria-label="Cursiva" title="Cursiva" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="m16.7 4.7-.1.9h-.3c-.6 0-1 0-1.4.3-.3.3-.4.6-.5 1.1l-2.1 9.8v.6c0 .5.4.8 1.4.8h.2l-.2.8H8l.2-.8h.2c1.1 0 1.8-.5 2-1.5l2-9.8.1-.5c0-.6-.4-.8-1.4-.8h-.3l.2-.9h5.8Z" fill-rule="evenodd"></path></svg></span></button></div><div role="toolbar" data-alloy-tabstop="true" tabindex="-1" class="tox-toolbar__group"><button aria-label="Mostrar u ocultar elementos adicionales de la barra de herramientas" title="Mostrar u ocultar elementos adicionales de la barra de herramientas" type="button" tabindex="-1" data-alloy-tabstop="true" class="tox-tbtn" aria-pressed="false"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M6 10a2 2 0 0 0-2 2c0 1.1.9 2 2 2a2 2 0 0 0 2-2 2 2 0 0 0-2-2Zm12 0a2 2 0 0 0-2 2c0 1.1.9 2 2 2a2 2 0 0 0 2-2 2 2 0 0 0-2-2Zm-6 0a2 2 0 0 0-2 2c0 1.1.9 2 2 2a2 2 0 0 0 2-2 2 2 0 0 0-2-2Z" fill-rule="nonzero"></path></svg></span></button></div></div><div role="group" class="tox-toolbar__overflow tox-toolbar__overflow--closed" style="height: 0px;"><div title="content" role="toolbar" data-alloy-tabstop="true" tabindex="-1" class="tox-toolbar__group"><button aria-label="Imagen" title="Imagen" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="m5 15.7 3.3-3.2c.3-.3.7-.3 1 0L12 15l4.1-4c.3-.4.8-.4 1 0l2 1.9V5H5v10.7ZM5 18V19h3l2.8-2.9-2-2L5 17.9Zm14-3-2.5-2.4-6.4 6.5H19v-4ZM4 3h16c.6 0 1 .4 1 1v16c0 .6-.4 1-1 1H4a1 1 0 0 1-1-1V4c0-.6.4-1 1-1Zm6 8a2 2 0 1 0 0-4 2 2 0 0 0 0 4Z" fill-rule="nonzero"></path></svg></span></button><button aria-label="Multimedios" title="Multimedios" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M4 3h16c.6 0 1 .4 1 1v16c0 .6-.4 1-1 1H4a1 1 0 0 1-1-1V4c0-.6.4-1 1-1Zm1 2v14h14V5H5Zm4.8 2.6 5.6 4a.5.5 0 0 1 0 .8l-5.6 4A.5.5 0 0 1 9 16V8a.5.5 0 0 1 .8-.4Z" fill-rule="nonzero"></path></svg></span></button><button aria-label="Grabar audio" title="Grabar audio" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg data-buttonsource="moodle" width="24" height="24" xmlns="http://www.w3.org/2000/svg" focusable="false">
        <image href="https://ingenieria.campus.mdp.edu.ar/theme/image.php/adaptable/tiny_recordrtc/1775501275/audio" width="24" height="24"></image>
</svg></span></button><button aria-label="Grabar video" title="Grabar video" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg data-buttonsource="moodle" width="24" height="24" xmlns="http://www.w3.org/2000/svg" focusable="false">
        <image href="https://ingenieria.campus.mdp.edu.ar/theme/image.php/adaptable/tiny_recordrtc/1775501275/video" width="24" height="24"></image>
</svg></span></button><button aria-label="Configurar contenido H5P" title="Configurar contenido H5P" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg data-buttonsource="moodle" width="24" height="24" xmlns="http://www.w3.org/2000/svg" focusable="false">
        <image href="https://ingenieria.campus.mdp.edu.ar/theme/image.php/adaptable/tiny_h5p/1775501275/icon" width="24" height="24"></image>
</svg></span></button><button aria-label="Enlace" title="Enlace" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M6.2 12.3a1 1 0 0 1 1.4 1.4l-2 2a2 2 0 1 0 2.6 2.8l4.8-4.8a1 1 0 0 0 0-1.4 1 1 0 1 1 1.4-1.3 2.9 2.9 0 0 1 0 4L9.6 20a3.9 3.9 0 0 1-5.5-5.5l2-2Zm11.6-.6a1 1 0 0 1-1.4-1.4l2-2a2 2 0 1 0-2.6-2.8L11 10.3a1 1 0 0 0 0 1.4A1 1 0 1 1 9.6 13a2.9 2.9 0 0 1 0-4L14.4 4a3.9 3.9 0 0 1 5.5 5.5l-2 2Z" fill-rule="nonzero"></path></svg></span></button><button aria-label="Desenlanzar" title="Desenlanzar" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M6.2 12.3a1 1 0 0 1 1.4 1.4l-2 2a2 2 0 1 0 2.6 2.8l4.8-4.8a1 1 0 0 0 0-1.4 1 1 0 1 1 1.4-1.3 2.9 2.9 0 0 1 0 4L9.6 20a3.9 3.9 0 0 1-5.5-5.5l2-2Zm11.6-.6a1 1 0 0 1-1.4-1.4l2.1-2a2 2 0 1 0-2.7-2.8L11 10.3a1 1 0 0 0 0 1.4A1 1 0 1 1 9.6 13a2.9 2.9 0 0 1 0-4L14.4 4a3.9 3.9 0 0 1 5.5 5.5l-2 2ZM7.6 6.3a.8.8 0 0 1-1 1.1L3.3 4.2a.7.7 0 1 1 1-1l3.2 3.1ZM5.1 8.6a.8.8 0 0 1 0 1.5H3a.8.8 0 0 1 0-1.5H5Zm5-3.5a.8.8 0 0 1-1.5 0V3a.8.8 0 0 1 1.5 0V5Zm6 11.8a.8.8 0 0 1 1-1l3.2 3.2a.8.8 0 0 1-1 1L16 17Zm-2.2 2a.8.8 0 0 1 1.5 0V21a.8.8 0 0 1-1.5 0V19Zm5-3.5a.7.7 0 1 1 0-1.5H21a.8.8 0 0 1 0 1.5H19Z" fill-rule="nonzero"></path></svg></span></button></div><div title="Ver" role="toolbar" data-alloy-tabstop="true" tabindex="-1" class="tox-toolbar__group"><button aria-label="Pantalla completa" title="Pantalla completa" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="m15.3 10-1.2-1.3 2.9-3h-2.3a.9.9 0 1 1 0-1.7H19c.5 0 .9.4.9.9v4.4a.9.9 0 1 1-1.8 0V7l-2.9 3Zm0 4 3 3v-2.3a.9.9 0 1 1 1.7 0V19c0 .5-.4.9-.9.9h-4.4a.9.9 0 1 1 0-1.8H17l-3-2.9 1.3-1.2ZM10 15.4l-2.9 3h2.3a.9.9 0 1 1 0 1.7H5a.9.9 0 0 1-.9-.9v-4.4a.9.9 0 1 1 1.8 0V17l2.9-3 1.2 1.3ZM8.7 10 5.7 7v2.3a.9.9 0 0 1-1.7 0V5c0-.5.4-.9.9-.9h4.4a.9.9 0 0 1 0 1.8H7l3 2.9-1.3 1.2Z" fill-rule="nonzero"></path></svg></span></button></div><div title="alineación" role="toolbar" data-alloy-tabstop="true" tabindex="-1" class="tox-toolbar__group"><button aria-label="Alinear a la izquierda" title="Alinear a la izquierda" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M5 5h14c.6 0 1 .4 1 1s-.4 1-1 1H5a1 1 0 1 1 0-2Zm0 4h8c.6 0 1 .4 1 1s-.4 1-1 1H5a1 1 0 1 1 0-2Zm0 8h8c.6 0 1 .4 1 1s-.4 1-1 1H5a1 1 0 0 1 0-2Zm0-4h14c.6 0 1 .4 1 1s-.4 1-1 1H5a1 1 0 0 1 0-2Z" fill-rule="evenodd"></path></svg></span></button><button aria-label="Alinear al centro" title="Alinear al centro" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M5 5h14c.6 0 1 .4 1 1s-.4 1-1 1H5a1 1 0 1 1 0-2Zm3 4h8c.6 0 1 .4 1 1s-.4 1-1 1H8a1 1 0 1 1 0-2Zm0 8h8c.6 0 1 .4 1 1s-.4 1-1 1H8a1 1 0 0 1 0-2Zm-3-4h14c.6 0 1 .4 1 1s-.4 1-1 1H5a1 1 0 0 1 0-2Z" fill-rule="evenodd"></path></svg></span></button><button aria-label="Alinear a la derecha" title="Alinear a la derecha" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M5 5h14c.6 0 1 .4 1 1s-.4 1-1 1H5a1 1 0 1 1 0-2Zm6 4h8c.6 0 1 .4 1 1s-.4 1-1 1h-8a1 1 0 0 1 0-2Zm0 8h8c.6 0 1 .4 1 1s-.4 1-1 1h-8a1 1 0 0 1 0-2Zm-6-4h14c.6 0 1 .4 1 1s-.4 1-1 1H5a1 1 0 0 1 0-2Z" fill-rule="evenodd"></path></svg></span></button></div><div title="directionality" role="toolbar" data-alloy-tabstop="true" tabindex="-1" class="tox-toolbar__group"><button aria-label="Izquierda a derecha" title="Izquierda a derecha" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M11 5h7a1 1 0 0 1 0 2h-1v11a1 1 0 0 1-2 0V7h-2v11a1 1 0 0 1-2 0v-6c-.5 0-1 0-1.4-.3A3.4 3.4 0 0 1 7.8 10a3.3 3.3 0 0 1 0-2.8 3.4 3.4 0 0 1 1.8-1.8L11 5ZM4.4 16.2 6.2 15l-1.8-1.2a1 1 0 0 1 1.2-1.6l3 2a1 1 0 0 1 0 1.6l-3 2a1 1 0 1 1-1.2-1.6Z" fill-rule="evenodd"></path></svg></span></button><button aria-label="Derecha a izquierda" title="Derecha a izquierda" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M8 5h8v2h-2v12h-2V7h-2v12H8v-7c-.5 0-1 0-1.4-.3A3.4 3.4 0 0 1 4.8 10a3.3 3.3 0 0 1 0-2.8 3.4 3.4 0 0 1 1.8-1.8L8 5Zm12 11.2a1 1 0 1 1-1 1.6l-3-2a1 1 0 0 1 0-1.6l3-2a1 1 0 1 1 1 1.6L18.4 15l1.8 1.2Z" fill-rule="evenodd"></path></svg></span></button></div><div title="sangría" role="toolbar" data-alloy-tabstop="true" tabindex="-1" class="tox-toolbar__group"><button aria-label="Disminuir sangría" title="Disminuir sangría" type="button" tabindex="-1" class="tox-tbtn tox-tbtn--disabled" aria-disabled="true" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M7 5h12c.6 0 1 .4 1 1s-.4 1-1 1H7a1 1 0 1 1 0-2Zm5 4h7c.6 0 1 .4 1 1s-.4 1-1 1h-7a1 1 0 0 1 0-2Zm0 4h7c.6 0 1 .4 1 1s-.4 1-1 1h-7a1 1 0 0 1 0-2Zm-5 4h12a1 1 0 0 1 0 2H7a1 1 0 0 1 0-2Zm1.6-3.8a1 1 0 0 1-1.2 1.6l-3-2a1 1 0 0 1 0-1.6l3-2a1 1 0 0 1 1.2 1.6L6.8 12l1.8 1.2Z" fill-rule="evenodd"></path></svg></span></button><button aria-label="Incrementar sangría" title="Incrementar sangría" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M7 5h12c.6 0 1 .4 1 1s-.4 1-1 1H7a1 1 0 1 1 0-2Zm5 4h7c.6 0 1 .4 1 1s-.4 1-1 1h-7a1 1 0 0 1 0-2Zm0 4h7c.6 0 1 .4 1 1s-.4 1-1 1h-7a1 1 0 0 1 0-2Zm-5 4h12a1 1 0 0 1 0 2H7a1 1 0 0 1 0-2Zm-2.6-3.8L6.2 12l-1.8-1.2a1 1 0 0 1 1.2-1.6l3 2a1 1 0 0 1 0 1.6l-3 2a1 1 0 1 1-1.2-1.6Z" fill-rule="evenodd"></path></svg></span></button></div><div title="lists" role="toolbar" data-alloy-tabstop="true" tabindex="-1" class="tox-toolbar__group"><button aria-label="Lista de viñetas" title="Lista de viñetas" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M11 5h8c.6 0 1 .4 1 1s-.4 1-1 1h-8a1 1 0 0 1 0-2Zm0 6h8c.6 0 1 .4 1 1s-.4 1-1 1h-8a1 1 0 0 1 0-2Zm0 6h8c.6 0 1 .4 1 1s-.4 1-1 1h-8a1 1 0 0 1 0-2ZM4.5 6c0-.4.1-.8.4-1 .3-.4.7-.5 1.1-.5.4 0 .8.1 1 .4.4.3.5.7.5 1.1 0 .4-.1.8-.4 1-.3.4-.7.5-1.1.5-.4 0-.8-.1-1-.4-.4-.3-.5-.7-.5-1.1Zm0 6c0-.4.1-.8.4-1 .3-.4.7-.5 1.1-.5.4 0 .8.1 1 .4.4.3.5.7.5 1.1 0 .4-.1.8-.4 1-.3.4-.7.5-1.1.5-.4 0-.8-.1-1-.4-.4-.3-.5-.7-.5-1.1Zm0 6c0-.4.1-.8.4-1 .3-.4.7-.5 1.1-.5.4 0 .8.1 1 .4.4.3.5.7.5 1.1 0 .4-.1.8-.4 1-.3.4-.7.5-1.1.5-.4 0-.8-.1-1-.4-.4-.3-.5-.7-.5-1.1Z" fill-rule="evenodd"></path></svg></span></button><button aria-label="Lista numerada" title="Lista numerada" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M10 17h8c.6 0 1 .4 1 1s-.4 1-1 1h-8a1 1 0 0 1 0-2Zm0-6h8c.6 0 1 .4 1 1s-.4 1-1 1h-8a1 1 0 0 1 0-2Zm0-6h8c.6 0 1 .4 1 1s-.4 1-1 1h-8a1 1 0 1 1 0-2ZM6 4v3.5c0 .3-.2.5-.5.5a.5.5 0 0 1-.5-.5V5h-.5a.5.5 0 0 1 0-1H6Zm-1 8.8.2.2h1.3c.3 0 .5.2.5.5s-.2.5-.5.5H4.9a1 1 0 0 1-.9-1V13c0-.4.3-.8.6-1l1.2-.4.2-.3a.2.2 0 0 0-.2-.2H4.5a.5.5 0 0 1-.5-.5c0-.3.2-.5.5-.5h1.6c.5 0 .9.4.9 1v.1c0 .4-.3.8-.6 1l-1.2.4-.2.3ZM7 17v2c0 .6-.4 1-1 1H4.5a.5.5 0 0 1 0-1h1.2c.2 0 .3-.1.3-.3 0-.2-.1-.3-.3-.3H4.4a.4.4 0 1 1 0-.8h1.3c.2 0 .3-.1.3-.3 0-.2-.1-.3-.3-.3H4.5a.5.5 0 1 1 0-1H6c.6 0 1 .4 1 1Z" fill-rule="evenodd"></path></svg></span></button></div><div title="Avanzado" role="toolbar" data-alloy-tabstop="true" tabindex="-1" class="tox-toolbar__group"><button aria-label="Editor de ecuación" title="Editor de ecuación" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg data-buttonsource="moodle" width="24" height="24" xmlns="http://www.w3.org/2000/svg" focusable="false">
        <image href="https://ingenieria.campus.mdp.edu.ar/theme/image.php/adaptable/tiny_equation/1775501275/icon" width="24" height="24"></image>
</svg></span></button></div></div></div><div class="tox-anchorbar"></div></div><div class="tox-sidebar-wrap" style="height: 10687.5px;"><div class="tox-edit-area"><iframe id="field_47_ifr" frameborder="0" allowtransparency="true" title="Área de Texto Enriquecido" class="tox-edit-area__iframe" srcdoc="&lt;!DOCTYPE html&gt;&lt;html&gt;&lt;head&gt;&lt;meta http-equiv=&quot;Content-Type&quot; content=&quot;text/html; charset=UTF-8&quot; /&gt;&lt;/head&gt;&lt;body id=&quot;tinymce&quot; class=&quot;mce-content-body &quot; data-id=&quot;field_47&quot; aria-label=&quot;Área de texto enriquecido. Pulse ALT-0 para abrir la ayuda.&quot;&gt;&lt;br&gt;&lt;/body&gt;&lt;/html&gt;"></iframe></div><div role="presentation" class="tox-sidebar"><div data-alloy-tabstop="true" tabindex="-1" class="tox-sidebar__slider tox-sidebar--sliding-closed" style="width: 0px;"><div class="tox-sidebar__pane-container"></div></div></div></div><div class="tox-bottom-anchorbar"></div><div class="tox-statusbar"><div class="tox-statusbar__text-container tox-statusbar__text-container--flex-start"><div role="navigation" data-alloy-tabstop="true" class="tox-statusbar__path" aria-disabled="false"><div data-index="0" aria-level="1" role="button" tabindex="-1" class="tox-statusbar__path-item" aria-disabled="false">p</div></div><div class="tox-statusbar__right-container"><button type="button" tabindex="-1" data-alloy-tabstop="true" class="tox-statusbar__wordcount">0 palabras</button><span class="tox-statusbar__branding"><a href="https://www.tiny.cloud/powered-by-tiny?utm_campaign=poweredby&amp;utm_source=tiny&amp;utm_medium=referral&amp;utm_content=v6" rel="noopener" target="_blank" aria-label="Con tecnología de Tiny" tabindex="-1"><svg width="50px" height="16px" viewBox="0 0 50 16" xmlns="http://www.w3.org/2000/svg">
  <path fill-rule="evenodd" clip-rule="evenodd" d="M10.143 0c2.608.015 5.186 2.178 5.186 5.331 0 0 .077 3.812-.084 4.87-.361 2.41-2.164 4.074-4.65 4.496-1.453.284-2.523.49-3.212.623-.373.071-.634.122-.785.152-.184.038-.997.145-1.35.145-2.732 0-5.21-2.04-5.248-5.33 0 0 0-3.514.03-4.442.093-2.4 1.758-4.342 4.926-4.963 0 0 3.875-.752 4.036-.782.368-.07.775-.1 1.15-.1Zm1.826 2.8L5.83 3.989v2.393l-2.455.475v5.968l6.137-1.189V9.243l2.456-.476V2.8ZM5.83 6.382l3.682-.713v3.574l-3.682.713V6.382Zm27.173-1.64-.084-1.066h-2.226v9.132h2.456V7.743c-.008-1.151.998-2.064 2.149-2.072 1.15-.008 1.987.92 1.995 2.072v5.065h2.455V7.359c-.015-2.18-1.657-3.929-3.837-3.913a3.993 3.993 0 0 0-2.908 1.296Zm-6.3-4.266L29.16 0v2.387l-2.456.475V.476Zm0 3.2v9.132h2.456V3.676h-2.456Zm18.179 11.787L49.11 3.676H46.58l-1.612 4.527-.46 1.382-.384-1.382-1.611-4.527H39.98l3.3 9.132L42.15 16l2.732-.537ZM22.867 9.738c0 .752.568 1.075.921 1.075.353 0 .668-.047.998-.154l.537 1.765c-.23.154-.92.537-2.225.537-1.305 0-2.655-.997-2.686-2.686a136.877 136.877 0 0 1 0-4.374H18.8V3.676h1.612v-1.98l2.455-.476v2.456h2.302V5.9h-2.302v3.837Z"></path>
</svg></a></span></div></div><div title="Redimensionar" aria-label="Pulse las teclas de flechas arriba y abajo para cambiar el tamaño del editor." data-alloy-tabstop="true" tabindex="-1" class="tox-statusbar__resize-handle"><svg width="10" height="10" focusable="false"><g fill-rule="nonzero"><path d="M8.1 1.1A.5.5 0 1 1 9 2l-7 7A.5.5 0 1 1 1 8l7-7ZM8.1 5.1A.5.5 0 1 1 9 6l-3 3A.5.5 0 1 1 5 8l3-3Z"></path></g></svg></div></div></div><div aria-hidden="true" class="tox-view-wrap" style="display: none;"><div class="tox-view-wrap__slot-container"></div></div><div aria-hidden="true" class="tox-throbber" style="display: none;"></div></div><div class="tox tox-silver-sink tox-silver-popup-sink tox-tinymce-aux" style="position: relative;"></div></div><div><label class="accesshide" for="field_47_content1">Formato</label><select id="field_47_content1" name="field_47_content1"><option value="1" selected="selected">Formato HTML</option></select></div></div></div>
        </div>

        <div class="mb-3 pt-3">
            <div class="font-weight-bold">Marcas</div>
            <div class="datatagcontrol"><select class="custom-select" name="tags[]" id="tags" multiple="" aria-hidden="true" data-aria-hidden-tab-index="" tabindex="-1" style="visibility: hidden; display: none;"></select><span class="sr-only" id="form_autocomplete_selection-1781204017617-label">Ítems seleccioandos:</span>
<div class="form-autocomplete-selection w-100 form-autocomplete-multiple" id="form_autocomplete_selection-1781204017617" aria-labelledby="form_autocomplete_selection-1781204017617-label" role="listbox" aria-atomic="true" tabindex="0" aria-multiselectable="true">


        <span class="m-1 h-5">No hay selección</span>
</div>
<div class="form-autocomplete-input d-md-inline-block mr-md-2 position-relative">
    <input type="text" id="form_autocomplete_input-1781204017617" class="form-control" list="form_autocomplete_suggestions-1781204017617" placeholder="Introduzca etiquetas..." role="combobox" aria-expanded="false" autocomplete="off" autocorrect="off" autocapitalize="off" aria-autocomplete="list" aria-owns="form_autocomplete_suggestions-1781204017617 form_autocomplete_selection-1781204017617" data-tags="1" data-multiple="multiple" data-fieldtype="autocomplete" style="min-width: 23ch;">
    <span class="form-autocomplete-downarrow position-absolute p-1" id="form_autocomplete_downarrow-1781204017617">▼</span>
</div>
<ul class="form-autocomplete-suggestions" id="form_autocomplete_suggestions-1781204017617" role="listbox" aria-label="Sugerencias" aria-hidden="true" tabindex="-1" style="display: none;">
</ul></div>
        </div>
</div><div id="sticky-footer" class="stickyfooter bg-white border-top">
    <div class="sticky-footer-content-wrapper h-100 d-flex justify-content-center">
        <div class="sticky-footer-content w-100 d-flex align-items-center px-3 py-2  justify-content-end">
                <a class="btn btn-secondary mx-1" role="button" href="https://ingenieria.campus.mdp.edu.ar/mod/data/view.php?d=17&amp;amp;advanced=0&amp;amp;paging&amp;amp;page=0">Cancelar</a><input type="submit" name="saveandview" value="Guardar" class="btn btn-primary mx-1"><input type="submit" name="saveandadd" value="Guardar y añadir otro" class="btn btn-primary mx-1">
        </div>
    </div>
</div></div></div></form>
```

## Db Historico

### URL:

`https://ingenieria.campus.mdp.edu.ar/mod/data/view.php?id=54788`

### HTML VISTA:

```
<div class="defaulttemplate-listentry my-5 p-5 card">
    <div class="row my-6">
        <div class="col-auto"><a href="https://ingenieria.campus.mdp.edu.ar/user/view.php?id=2987&amp;course=1732" class="d-inline-block aabtn"><img src="https://ingenieria.campus.mdp.edu.ar/pluginfile.php/36551/user/icon/adaptable/f1?rev=890264" class="userpicture" width="64" height="64" alt="MARTIN ESTEBAN GIRAU" title="MARTIN ESTEBAN GIRAU"></a></div>
        <div class="col">
            <div class="row h-100">
                <div class="col-3 align-self-center">
                    <a href="https://ingenieria.campus.mdp.edu.ar/user/view.php?id=2987&amp;course=1732">MARTIN ESTEBAN GIRAU</a><br><span class="data-timeinfo"><span title="jueves, 11 de junio de 2026, 15:05">11 jun 2026</span></span>
                </div>
                <div class="col-4 col-md-6 text-right align-self-center data-timeinfo">
                    <span class="font-weight-bold ">Editado por última vez:&nbsp;</span><span title="jueves, 11 de junio de 2026, 15:05">11 jun 2026</span>
                </div>
                <div class="col-4 col-md-3 ml-auto align-self-center d-flex flex-row-reverse">
                    <div><div class="action-menu moodle-actionmenu entry-actionsmenu" id="action-menu-6" data-enhance="moodle-core-actionmenu">

        <div class="menubar d-flex " id="action-menu-6-menubar">




                <div class="action-menu-trigger">
                    <div class="dropdown">
                        <a href="#" tabindex="0" class="btn btn-icon d-flex align-items-center justify-content-center no-caret  dropdown-toggle icon-no-margin" id="action-menu-toggle-6" aria-label="Acciones" data-toggle="dropdown" role="button" aria-haspopup="true" aria-expanded="false" aria-controls="action-menu-6-menu">

                            <i class="icon fa fa-ellipsis-v fa-fw" title="Acciones" role="img" aria-label="Acciones"></i>

                            <b class="caret"></b>
                        </a>
                            <div class="dropdown-menu menu dropdown-menu-right" id="action-menu-6-menu" data-rel="menu-content" aria-labelledby="action-menu-toggle-6" role="menu">
                                                                <a href="https://ingenieria.campus.mdp.edu.ar/mod/data/view.php?d=18&amp;advanced=0&amp;paging&amp;page=0&amp;rid=25&amp;filter=1" class="dropdown-item menu-action" role="menuitem" tabindex="-1">
                                <span class="menu-action-text">Mostrar más</span>
                        </a>
                                                                <a href="https://ingenieria.campus.mdp.edu.ar/mod/data/edit.php?d=18&amp;advanced=0&amp;paging&amp;page=0&amp;rid=25&amp;sesskey=bN4VoosUA9&amp;backto=https%253A%252F%252Fingenieria.campus.mdp.edu.ar%252Fmod%252Fdata%252Fview.php%253Fd%253D18%2526advanced%253D0%2526paging%2526page%253D0%2526rid%253D25%2526mode%253Dsingle" class="dropdown-item menu-action" role="menuitem" tabindex="-1">
                                <span class="menu-action-text">Editar</span>
                        </a>
                                                                <a href="https://ingenieria.campus.mdp.edu.ar/mod/data/view.php?d=18&amp;advanced=0&amp;paging&amp;page=0&amp;delete=25&amp;sesskey=bN4VoosUA9&amp;mode=single" class="dropdown-item menu-action" role="menuitem" tabindex="-1">
                                <span class="menu-action-text">Borrar</span>
                        </a>
                            </div>
                    </div>
                </div>

        </div>

</div></div>
                    <div class="ml-auto my-auto "></div>
                </div>
            </div>
        </div>
    </div>
    <hr>

    <div class="defaulttemplate-list-body">
            <div class="row my-3 align-items-start justify-content-start">
                <div class="col-4 col-lg-3 font-weight-bold">id_alumno</div>
                <div class="col-8 col-lg-9 ml-n3">2987</div>
            </div>
            <div class="row my-3 align-items-start justify-content-start">
                <div class="col-4 col-lg-3 font-weight-bold">nombre_alumno</div>
                <div class="col-8 col-lg-9 ml-n3">Martin Girau</div>
            </div>
            <div class="row my-3 align-items-start justify-content-start">
                <div class="col-4 col-lg-3 font-weight-bold">cuatrimestre</div>
                <div class="col-8 col-lg-9 ml-n3">2026-1</div>
            </div>
            <div class="row my-3 align-items-start justify-content-start">
                <div class="col-4 col-lg-3 font-weight-bold">fecha_snapshot</div>
                <div class="col-8 col-lg-9 ml-n3">2026-06-11</div>
            </div>
            <div class="row my-3 align-items-start justify-content-start">
                <div class="col-4 col-lg-3 font-weight-bold">ird</div>
                <div class="col-8 col-lg-9 ml-n3">55</div>
            </div>
            <div class="row my-3 align-items-start justify-content-start">
                <div class="col-4 col-lg-3 font-weight-bold">ralentizacion</div>
                <div class="col-8 col-lg-9 ml-n3">70</div>
            </div>
            <div class="row my-3 align-items-start justify-content-start">
                <div class="col-4 col-lg-3 font-weight-bold">estado</div>
                <div class="col-8 col-lg-9 ml-n3">activo</div>
            </div>
            <div class="row my-3 align-items-start justify-content-start">
                <div class="col-4 col-lg-3 font-weight-bold">datos_json</div>
                <div class="col-8 col-lg-9 ml-n3"><div class="data-field-html"><p>{<br>&nbsp; "respuestas": {<br>&nbsp; &nbsp; "id_pregunta_1": 3,<br>&nbsp; &nbsp; "id_pregunta_2": 1<br>&nbsp; },<br>&nbsp; "materias": [<br>&nbsp; &nbsp; { "materia": "Física <a class="autolink" title="a" href="https://ingenieria.campus.mdp.edu.ar/mod/page/view.php?id=54299">A</a>", "nota": 8 },<br>&nbsp; &nbsp; { "materia": "Álgebra I-B", "nota": 6 }<br>&nbsp; ]<br>}</p></div></div>
            </div>
            <div class="mb-4">
                <span class="font-weight-bold">Marcas</span>
                <p class="mt-2"></p>
            </div>
    </div>
</div>
```

#### HTML JSON

```
<form enctype="multipart/form-data" action="edit.php" method="post"><div><input name="d" value="18" type="hidden"><input name="rid" value="0" type="hidden"><input name="sesskey" value="bN4VoosUA9" type="hidden"><div class="box generalbox boxaligncenter boxwidthwide"><h2>Nueva entrada</h2><div id="defaulttemplate-addentry">
        <div class="mb-3 pt-3">
            <div class="font-weight-bold">id_alumno</div>
            <div title=""><label for="field_48"><span class="accesshide">id_alumno</span><div class="inline-req"><i class="icon fa fa-exclamation-circle text-danger fa-fw" title="Campo obligatorio" role="img" aria-label="Campo obligatorio"></i></div></label><input class="basefieldinput form-control d-inline mod-data-input" type="text" name="field_48" id="field_48" value=""></div>
        </div>
        <div class="mb-3 pt-3">
            <div class="font-weight-bold">nombre_alumno</div>
            <div title=""><label for="field_49"><span class="accesshide">nombre_alumno</span><div class="inline-req"><i class="icon fa fa-exclamation-circle text-danger fa-fw" title="Campo obligatorio" role="img" aria-label="Campo obligatorio"></i></div></label><input class="basefieldinput form-control d-inline mod-data-input" type="text" name="field_49" id="field_49" value=""></div>
        </div>
        <div class="mb-3 pt-3">
            <div class="font-weight-bold">cuatrimestre</div>
            <div title=""><label for="field_50"><span class="accesshide">cuatrimestre</span><div class="inline-req"><i class="icon fa fa-exclamation-circle text-danger fa-fw" title="Campo obligatorio" role="img" aria-label="Campo obligatorio"></i></div></label><input class="basefieldinput form-control d-inline mod-data-input" type="text" name="field_50" id="field_50" value=""></div>
        </div>
        <div class="mb-3 pt-3">
            <div class="font-weight-bold">fecha_snapshot</div>
            <div title=""><label for="field_51"><span class="accesshide">fecha_snapshot</span><div class="inline-req"><i class="icon fa fa-exclamation-circle text-danger fa-fw" title="Campo obligatorio" role="img" aria-label="Campo obligatorio"></i></div></label><input class="basefieldinput form-control d-inline mod-data-input" type="text" name="field_51" id="field_51" value=""></div>
        </div>
        <div class="mb-3 pt-3">
            <div class="font-weight-bold">ird</div>
            <div title=""><label for="field_52"><span class="accesshide">ird</span></label><input class="basefieldinput form-control d-inline mod-data-input" type="text" name="field_52" id="field_52" value=""></div>
        </div>
        <div class="mb-3 pt-3">
            <div class="font-weight-bold">ralentizacion</div>
            <div title=""><label for="field_53"><span class="accesshide">ralentizacion</span></label><input class="basefieldinput form-control d-inline mod-data-input" type="text" name="field_53" id="field_53" value=""></div>
        </div>
        <div class="mb-3 pt-3">
            <div class="font-weight-bold">estado</div>
            <div title=""><label for="field_54"><span class="accesshide">estado</span></label><input class="basefieldinput form-control d-inline mod-data-input" type="text" name="field_54" id="field_54" value=""></div>
        </div>
        <div class="mb-3 pt-3">
            <div class="font-weight-bold">datos_json</div>
            <div title="Datos de encuestas inicial y Cuatrimestral de cada alumno" class="d-inline-flex"><label for="field_56"><span class="accesshide">datos_json</span></label><input type="hidden" name="field_56_itemid" value="724061177"><div class="mod-data-input"><div><textarea id="field_56" name="field_56" rows="70" class="form-control" data-fieldtype="editor" cols="120" spellcheck="true" style="display: none;" aria-hidden="true"></textarea><div role="application" class="tox tox-tinymce" aria-disabled="false" style="visibility: hidden; height: 1508px;"><div class="tox-editor-container"><div data-alloy-vertical-dir="toptobottom" class="tox-editor-header"><div role="menubar" data-alloy-tabstop="true" class="tox-menubar"><button aria-haspopup="true" role="menuitem" type="button" tabindex="-1" data-alloy-tabstop="true" unselectable="on" class="tox-mbtn tox-mbtn--select" aria-expanded="false" style="user-select: none; width: 51.4531px;"><span class="tox-mbtn__select-label">Editar</span><div class="tox-mbtn__select-chevron"><svg width="10" height="10" focusable="false"><path d="M8.7 2.2c.3-.3.8-.3 1 0 .4.4.4.9 0 1.2L5.7 7.8c-.3.3-.9.3-1.2 0L.2 3.4a.8.8 0 0 1 0-1.2c.3-.3.8-.3 1.1 0L5 6l3.7-3.8Z" fill-rule="nonzero"></path></svg></div></button><button aria-haspopup="true" role="menuitem" type="button" tabindex="-1" data-alloy-tabstop="true" unselectable="on" class="tox-mbtn tox-mbtn--select" style="user-select: none; width: 36px;" aria-expanded="false"><span class="tox-mbtn__select-label">Ver</span><div class="tox-mbtn__select-chevron"><svg width="10" height="10" focusable="false"><path d="M8.7 2.2c.3-.3.8-.3 1 0 .4.4.4.9 0 1.2L5.7 7.8c-.3.3-.9.3-1.2 0L.2 3.4a.8.8 0 0 1 0-1.2c.3-.3.8-.3 1.1 0L5 6l3.7-3.8Z" fill-rule="nonzero"></path></svg></div></button><button aria-haspopup="true" role="menuitem" type="button" tabindex="-1" data-alloy-tabstop="true" unselectable="on" class="tox-mbtn tox-mbtn--select" style="user-select: none; width: 62.5156px;" aria-expanded="false"><span class="tox-mbtn__select-label">Insertar</span><div class="tox-mbtn__select-chevron"><svg width="10" height="10" focusable="false"><path d="M8.7 2.2c.3-.3.8-.3 1 0 .4.4.4.9 0 1.2L5.7 7.8c-.3.3-.9.3-1.2 0L.2 3.4a.8.8 0 0 1 0-1.2c.3-.3.8-.3 1.1 0L5 6l3.7-3.8Z" fill-rule="nonzero"></path></svg></div></button><button aria-haspopup="true" role="menuitem" type="button" tabindex="-1" data-alloy-tabstop="true" unselectable="on" class="tox-mbtn tox-mbtn--select" style="user-select: none; width: 68.0469px;" aria-expanded="false"><span class="tox-mbtn__select-label">Formato</span><div class="tox-mbtn__select-chevron"><svg width="10" height="10" focusable="false"><path d="M8.7 2.2c.3-.3.8-.3 1 0 .4.4.4.9 0 1.2L5.7 7.8c-.3.3-.9.3-1.2 0L.2 3.4a.8.8 0 0 1 0-1.2c.3-.3.8-.3 1.1 0L5 6l3.7-3.8Z" fill-rule="nonzero"></path></svg></div></button><button aria-haspopup="true" role="menuitem" type="button" tabindex="-1" data-alloy-tabstop="true" unselectable="on" class="tox-mbtn tox-mbtn--select" style="user-select: none; width: 98.625px;" aria-expanded="false"><span class="tox-mbtn__select-label">Herramientas</span><div class="tox-mbtn__select-chevron"><svg width="10" height="10" focusable="false"><path d="M8.7 2.2c.3-.3.8-.3 1 0 .4.4.4.9 0 1.2L5.7 7.8c-.3.3-.9.3-1.2 0L.2 3.4a.8.8 0 0 1 0-1.2c.3-.3.8-.3 1.1 0L5 6l3.7-3.8Z" fill-rule="nonzero"></path></svg></div></button><button aria-haspopup="true" role="menuitem" type="button" tabindex="-1" data-alloy-tabstop="true" unselectable="on" class="tox-mbtn tox-mbtn--select" style="user-select: none; width: 47.6406px;" aria-expanded="false"><span class="tox-mbtn__select-label">Tabla</span><div class="tox-mbtn__select-chevron"><svg width="10" height="10" focusable="false"><path d="M8.7 2.2c.3-.3.8-.3 1 0 .4.4.4.9 0 1.2L5.7 7.8c-.3.3-.9.3-1.2 0L.2 3.4a.8.8 0 0 1 0-1.2c.3-.3.8-.3 1.1 0L5 6l3.7-3.8Z" fill-rule="nonzero"></path></svg></div></button><button aria-haspopup="true" role="menuitem" type="button" tabindex="-1" data-alloy-tabstop="true" unselectable="on" class="tox-mbtn tox-mbtn--select" style="user-select: none; width: 54.8281px;" aria-expanded="false"><span class="tox-mbtn__select-label">Ayuda</span><div class="tox-mbtn__select-chevron"><svg width="10" height="10" focusable="false"><path d="M8.7 2.2c.3-.3.8-.3 1 0 .4.4.4.9 0 1.2L5.7 7.8c-.3.3-.9.3-1.2 0L.2 3.4a.8.8 0 0 1 0-1.2c.3-.3.8-.3 1.1 0L5 6l3.7-3.8Z" fill-rule="nonzero"></path></svg></div></button></div><div role="group" class="tox-toolbar-overlord" aria-disabled="false"><div role="group" class="tox-toolbar__primary"><div title="historial" role="toolbar" data-alloy-tabstop="true" tabindex="-1" class="tox-toolbar__group"><button aria-label="Deshacer" title="Deshacer" type="button" tabindex="-1" class="tox-tbtn tox-tbtn--disabled" aria-disabled="true" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M6.4 8H12c3.7 0 6.2 2 6.8 5.1.6 2.7-.4 5.6-2.3 6.8a1 1 0 0 1-1-1.8c1.1-.6 1.8-2.7 1.4-4.6-.5-2.1-2.1-3.5-4.9-3.5H6.4l3.3 3.3a1 1 0 1 1-1.4 1.4l-5-5a1 1 0 0 1 0-1.4l5-5a1 1 0 0 1 1.4 1.4L6.4 8Z" fill-rule="nonzero"></path></svg></span></button><button aria-label="Rehacer" title="Rehacer" type="button" tabindex="-1" class="tox-tbtn tox-tbtn--disabled" aria-disabled="true" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M17.6 10H12c-2.8 0-4.4 1.4-4.9 3.5-.4 2 .3 4 1.4 4.6a1 1 0 1 1-1 1.8c-2-1.2-2.9-4.1-2.3-6.8.6-3 3-5.1 6.8-5.1h5.6l-3.3-3.3a1 1 0 1 1 1.4-1.4l5 5a1 1 0 0 1 0 1.4l-5 5a1 1 0 0 1-1.4-1.4l3.3-3.3Z" fill-rule="nonzero"></path></svg></span></button></div><div title="formato" role="toolbar" data-alloy-tabstop="true" tabindex="-1" class="tox-toolbar__group"><button aria-label="Negrita" title="Negrita" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M7.8 19c-.3 0-.5 0-.6-.2l-.2-.5V5.7c0-.2 0-.4.2-.5l.6-.2h5c1.5 0 2.7.3 3.5 1 .7.6 1.1 1.4 1.1 2.5a3 3 0 0 1-.6 1.9c-.4.6-1 1-1.6 1.2.4.1.9.3 1.3.6s.8.7 1 1.2c.4.4.5 1 .5 1.6 0 1.3-.4 2.3-1.3 3-.8.7-2.1 1-3.8 1H7.8Zm5-8.3c.6 0 1.2-.1 1.6-.5.4-.3.6-.7.6-1.3 0-1.1-.8-1.7-2.3-1.7H9.3v3.5h3.4Zm.5 6c.7 0 1.3-.1 1.7-.4.4-.4.6-.9.6-1.5s-.2-1-.7-1.4c-.4-.3-1-.4-2-.4H9.4v3.8h4Z" fill-rule="evenodd"></path></svg></span></button><button aria-label="Cursiva" title="Cursiva" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="m16.7 4.7-.1.9h-.3c-.6 0-1 0-1.4.3-.3.3-.4.6-.5 1.1l-2.1 9.8v.6c0 .5.4.8 1.4.8h.2l-.2.8H8l.2-.8h.2c1.1 0 1.8-.5 2-1.5l2-9.8.1-.5c0-.6-.4-.8-1.4-.8h-.3l.2-.9h5.8Z" fill-rule="evenodd"></path></svg></span></button></div><div role="toolbar" data-alloy-tabstop="true" tabindex="-1" class="tox-toolbar__group"><button aria-label="Mostrar u ocultar elementos adicionales de la barra de herramientas" title="Mostrar u ocultar elementos adicionales de la barra de herramientas" type="button" tabindex="-1" data-alloy-tabstop="true" class="tox-tbtn" aria-pressed="false"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M6 10a2 2 0 0 0-2 2c0 1.1.9 2 2 2a2 2 0 0 0 2-2 2 2 0 0 0-2-2Zm12 0a2 2 0 0 0-2 2c0 1.1.9 2 2 2a2 2 0 0 0 2-2 2 2 0 0 0-2-2Zm-6 0a2 2 0 0 0-2 2c0 1.1.9 2 2 2a2 2 0 0 0 2-2 2 2 0 0 0-2-2Z" fill-rule="nonzero"></path></svg></span></button></div></div><div role="group" class="tox-toolbar__overflow tox-toolbar__overflow--closed" style="height: 0px;"><div title="content" role="toolbar" data-alloy-tabstop="true" tabindex="-1" class="tox-toolbar__group"><button aria-label="Imagen" title="Imagen" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="m5 15.7 3.3-3.2c.3-.3.7-.3 1 0L12 15l4.1-4c.3-.4.8-.4 1 0l2 1.9V5H5v10.7ZM5 18V19h3l2.8-2.9-2-2L5 17.9Zm14-3-2.5-2.4-6.4 6.5H19v-4ZM4 3h16c.6 0 1 .4 1 1v16c0 .6-.4 1-1 1H4a1 1 0 0 1-1-1V4c0-.6.4-1 1-1Zm6 8a2 2 0 1 0 0-4 2 2 0 0 0 0 4Z" fill-rule="nonzero"></path></svg></span></button><button aria-label="Multimedios" title="Multimedios" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M4 3h16c.6 0 1 .4 1 1v16c0 .6-.4 1-1 1H4a1 1 0 0 1-1-1V4c0-.6.4-1 1-1Zm1 2v14h14V5H5Zm4.8 2.6 5.6 4a.5.5 0 0 1 0 .8l-5.6 4A.5.5 0 0 1 9 16V8a.5.5 0 0 1 .8-.4Z" fill-rule="nonzero"></path></svg></span></button><button aria-label="Grabar audio" title="Grabar audio" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg data-buttonsource="moodle" width="24" height="24" xmlns="http://www.w3.org/2000/svg" focusable="false">
        <image href="https://ingenieria.campus.mdp.edu.ar/theme/image.php/adaptable/tiny_recordrtc/1775501275/audio" width="24" height="24"></image>
</svg></span></button><button aria-label="Grabar video" title="Grabar video" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg data-buttonsource="moodle" width="24" height="24" xmlns="http://www.w3.org/2000/svg" focusable="false">
        <image href="https://ingenieria.campus.mdp.edu.ar/theme/image.php/adaptable/tiny_recordrtc/1775501275/video" width="24" height="24"></image>
</svg></span></button><button aria-label="Configurar contenido H5P" title="Configurar contenido H5P" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg data-buttonsource="moodle" width="24" height="24" xmlns="http://www.w3.org/2000/svg" focusable="false">
        <image href="https://ingenieria.campus.mdp.edu.ar/theme/image.php/adaptable/tiny_h5p/1775501275/icon" width="24" height="24"></image>
</svg></span></button><button aria-label="Enlace" title="Enlace" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M6.2 12.3a1 1 0 0 1 1.4 1.4l-2 2a2 2 0 1 0 2.6 2.8l4.8-4.8a1 1 0 0 0 0-1.4 1 1 0 1 1 1.4-1.3 2.9 2.9 0 0 1 0 4L9.6 20a3.9 3.9 0 0 1-5.5-5.5l2-2Zm11.6-.6a1 1 0 0 1-1.4-1.4l2-2a2 2 0 1 0-2.6-2.8L11 10.3a1 1 0 0 0 0 1.4A1 1 0 1 1 9.6 13a2.9 2.9 0 0 1 0-4L14.4 4a3.9 3.9 0 0 1 5.5 5.5l-2 2Z" fill-rule="nonzero"></path></svg></span></button><button aria-label="Desenlanzar" title="Desenlanzar" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M6.2 12.3a1 1 0 0 1 1.4 1.4l-2 2a2 2 0 1 0 2.6 2.8l4.8-4.8a1 1 0 0 0 0-1.4 1 1 0 1 1 1.4-1.3 2.9 2.9 0 0 1 0 4L9.6 20a3.9 3.9 0 0 1-5.5-5.5l2-2Zm11.6-.6a1 1 0 0 1-1.4-1.4l2.1-2a2 2 0 1 0-2.7-2.8L11 10.3a1 1 0 0 0 0 1.4A1 1 0 1 1 9.6 13a2.9 2.9 0 0 1 0-4L14.4 4a3.9 3.9 0 0 1 5.5 5.5l-2 2ZM7.6 6.3a.8.8 0 0 1-1 1.1L3.3 4.2a.7.7 0 1 1 1-1l3.2 3.1ZM5.1 8.6a.8.8 0 0 1 0 1.5H3a.8.8 0 0 1 0-1.5H5Zm5-3.5a.8.8 0 0 1-1.5 0V3a.8.8 0 0 1 1.5 0V5Zm6 11.8a.8.8 0 0 1 1-1l3.2 3.2a.8.8 0 0 1-1 1L16 17Zm-2.2 2a.8.8 0 0 1 1.5 0V21a.8.8 0 0 1-1.5 0V19Zm5-3.5a.7.7 0 1 1 0-1.5H21a.8.8 0 0 1 0 1.5H19Z" fill-rule="nonzero"></path></svg></span></button></div><div title="Ver" role="toolbar" data-alloy-tabstop="true" tabindex="-1" class="tox-toolbar__group"><button aria-label="Pantalla completa" title="Pantalla completa" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="m15.3 10-1.2-1.3 2.9-3h-2.3a.9.9 0 1 1 0-1.7H19c.5 0 .9.4.9.9v4.4a.9.9 0 1 1-1.8 0V7l-2.9 3Zm0 4 3 3v-2.3a.9.9 0 1 1 1.7 0V19c0 .5-.4.9-.9.9h-4.4a.9.9 0 1 1 0-1.8H17l-3-2.9 1.3-1.2ZM10 15.4l-2.9 3h2.3a.9.9 0 1 1 0 1.7H5a.9.9 0 0 1-.9-.9v-4.4a.9.9 0 1 1 1.8 0V17l2.9-3 1.2 1.3ZM8.7 10 5.7 7v2.3a.9.9 0 0 1-1.7 0V5c0-.5.4-.9.9-.9h4.4a.9.9 0 0 1 0 1.8H7l3 2.9-1.3 1.2Z" fill-rule="nonzero"></path></svg></span></button></div><div title="alineación" role="toolbar" data-alloy-tabstop="true" tabindex="-1" class="tox-toolbar__group"><button aria-label="Alinear a la izquierda" title="Alinear a la izquierda" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M5 5h14c.6 0 1 .4 1 1s-.4 1-1 1H5a1 1 0 1 1 0-2Zm0 4h8c.6 0 1 .4 1 1s-.4 1-1 1H5a1 1 0 1 1 0-2Zm0 8h8c.6 0 1 .4 1 1s-.4 1-1 1H5a1 1 0 0 1 0-2Zm0-4h14c.6 0 1 .4 1 1s-.4 1-1 1H5a1 1 0 0 1 0-2Z" fill-rule="evenodd"></path></svg></span></button><button aria-label="Alinear al centro" title="Alinear al centro" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M5 5h14c.6 0 1 .4 1 1s-.4 1-1 1H5a1 1 0 1 1 0-2Zm3 4h8c.6 0 1 .4 1 1s-.4 1-1 1H8a1 1 0 1 1 0-2Zm0 8h8c.6 0 1 .4 1 1s-.4 1-1 1H8a1 1 0 0 1 0-2Zm-3-4h14c.6 0 1 .4 1 1s-.4 1-1 1H5a1 1 0 0 1 0-2Z" fill-rule="evenodd"></path></svg></span></button><button aria-label="Alinear a la derecha" title="Alinear a la derecha" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M5 5h14c.6 0 1 .4 1 1s-.4 1-1 1H5a1 1 0 1 1 0-2Zm6 4h8c.6 0 1 .4 1 1s-.4 1-1 1h-8a1 1 0 0 1 0-2Zm0 8h8c.6 0 1 .4 1 1s-.4 1-1 1h-8a1 1 0 0 1 0-2Zm-6-4h14c.6 0 1 .4 1 1s-.4 1-1 1H5a1 1 0 0 1 0-2Z" fill-rule="evenodd"></path></svg></span></button></div><div title="directionality" role="toolbar" data-alloy-tabstop="true" tabindex="-1" class="tox-toolbar__group"><button aria-label="Izquierda a derecha" title="Izquierda a derecha" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M11 5h7a1 1 0 0 1 0 2h-1v11a1 1 0 0 1-2 0V7h-2v11a1 1 0 0 1-2 0v-6c-.5 0-1 0-1.4-.3A3.4 3.4 0 0 1 7.8 10a3.3 3.3 0 0 1 0-2.8 3.4 3.4 0 0 1 1.8-1.8L11 5ZM4.4 16.2 6.2 15l-1.8-1.2a1 1 0 0 1 1.2-1.6l3 2a1 1 0 0 1 0 1.6l-3 2a1 1 0 1 1-1.2-1.6Z" fill-rule="evenodd"></path></svg></span></button><button aria-label="Derecha a izquierda" title="Derecha a izquierda" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M8 5h8v2h-2v12h-2V7h-2v12H8v-7c-.5 0-1 0-1.4-.3A3.4 3.4 0 0 1 4.8 10a3.3 3.3 0 0 1 0-2.8 3.4 3.4 0 0 1 1.8-1.8L8 5Zm12 11.2a1 1 0 1 1-1 1.6l-3-2a1 1 0 0 1 0-1.6l3-2a1 1 0 1 1 1 1.6L18.4 15l1.8 1.2Z" fill-rule="evenodd"></path></svg></span></button></div><div title="sangría" role="toolbar" data-alloy-tabstop="true" tabindex="-1" class="tox-toolbar__group"><button aria-label="Disminuir sangría" title="Disminuir sangría" type="button" tabindex="-1" class="tox-tbtn tox-tbtn--disabled" aria-disabled="true" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M7 5h12c.6 0 1 .4 1 1s-.4 1-1 1H7a1 1 0 1 1 0-2Zm5 4h7c.6 0 1 .4 1 1s-.4 1-1 1h-7a1 1 0 0 1 0-2Zm0 4h7c.6 0 1 .4 1 1s-.4 1-1 1h-7a1 1 0 0 1 0-2Zm-5 4h12a1 1 0 0 1 0 2H7a1 1 0 0 1 0-2Zm1.6-3.8a1 1 0 0 1-1.2 1.6l-3-2a1 1 0 0 1 0-1.6l3-2a1 1 0 0 1 1.2 1.6L6.8 12l1.8 1.2Z" fill-rule="evenodd"></path></svg></span></button><button aria-label="Incrementar sangría" title="Incrementar sangría" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M7 5h12c.6 0 1 .4 1 1s-.4 1-1 1H7a1 1 0 1 1 0-2Zm5 4h7c.6 0 1 .4 1 1s-.4 1-1 1h-7a1 1 0 0 1 0-2Zm0 4h7c.6 0 1 .4 1 1s-.4 1-1 1h-7a1 1 0 0 1 0-2Zm-5 4h12a1 1 0 0 1 0 2H7a1 1 0 0 1 0-2Zm-2.6-3.8L6.2 12l-1.8-1.2a1 1 0 0 1 1.2-1.6l3 2a1 1 0 0 1 0 1.6l-3 2a1 1 0 1 1-1.2-1.6Z" fill-rule="evenodd"></path></svg></span></button></div><div title="lists" role="toolbar" data-alloy-tabstop="true" tabindex="-1" class="tox-toolbar__group"><button aria-label="Lista de viñetas" title="Lista de viñetas" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M11 5h8c.6 0 1 .4 1 1s-.4 1-1 1h-8a1 1 0 0 1 0-2Zm0 6h8c.6 0 1 .4 1 1s-.4 1-1 1h-8a1 1 0 0 1 0-2Zm0 6h8c.6 0 1 .4 1 1s-.4 1-1 1h-8a1 1 0 0 1 0-2ZM4.5 6c0-.4.1-.8.4-1 .3-.4.7-.5 1.1-.5.4 0 .8.1 1 .4.4.3.5.7.5 1.1 0 .4-.1.8-.4 1-.3.4-.7.5-1.1.5-.4 0-.8-.1-1-.4-.4-.3-.5-.7-.5-1.1Zm0 6c0-.4.1-.8.4-1 .3-.4.7-.5 1.1-.5.4 0 .8.1 1 .4.4.3.5.7.5 1.1 0 .4-.1.8-.4 1-.3.4-.7.5-1.1.5-.4 0-.8-.1-1-.4-.4-.3-.5-.7-.5-1.1Zm0 6c0-.4.1-.8.4-1 .3-.4.7-.5 1.1-.5.4 0 .8.1 1 .4.4.3.5.7.5 1.1 0 .4-.1.8-.4 1-.3.4-.7.5-1.1.5-.4 0-.8-.1-1-.4-.4-.3-.5-.7-.5-1.1Z" fill-rule="evenodd"></path></svg></span></button><button aria-label="Lista numerada" title="Lista numerada" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M10 17h8c.6 0 1 .4 1 1s-.4 1-1 1h-8a1 1 0 0 1 0-2Zm0-6h8c.6 0 1 .4 1 1s-.4 1-1 1h-8a1 1 0 0 1 0-2Zm0-6h8c.6 0 1 .4 1 1s-.4 1-1 1h-8a1 1 0 1 1 0-2ZM6 4v3.5c0 .3-.2.5-.5.5a.5.5 0 0 1-.5-.5V5h-.5a.5.5 0 0 1 0-1H6Zm-1 8.8.2.2h1.3c.3 0 .5.2.5.5s-.2.5-.5.5H4.9a1 1 0 0 1-.9-1V13c0-.4.3-.8.6-1l1.2-.4.2-.3a.2.2 0 0 0-.2-.2H4.5a.5.5 0 0 1-.5-.5c0-.3.2-.5.5-.5h1.6c.5 0 .9.4.9 1v.1c0 .4-.3.8-.6 1l-1.2.4-.2.3ZM7 17v2c0 .6-.4 1-1 1H4.5a.5.5 0 0 1 0-1h1.2c.2 0 .3-.1.3-.3 0-.2-.1-.3-.3-.3H4.4a.4.4 0 1 1 0-.8h1.3c.2 0 .3-.1.3-.3 0-.2-.1-.3-.3-.3H4.5a.5.5 0 1 1 0-1H6c.6 0 1 .4 1 1Z" fill-rule="evenodd"></path></svg></span></button></div><div title="Avanzado" role="toolbar" data-alloy-tabstop="true" tabindex="-1" class="tox-toolbar__group"><button aria-label="Editor de ecuación" title="Editor de ecuación" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg data-buttonsource="moodle" width="24" height="24" xmlns="http://www.w3.org/2000/svg" focusable="false">
        <image href="https://ingenieria.campus.mdp.edu.ar/theme/image.php/adaptable/tiny_equation/1775501275/icon" width="24" height="24"></image>
</svg></span></button></div></div></div><div class="tox-anchorbar"></div></div><div class="tox-sidebar-wrap" style="height: 1496.25px;"><div class="tox-edit-area"><iframe id="field_56_ifr" frameborder="0" allowtransparency="true" title="Área de Texto Enriquecido" class="tox-edit-area__iframe" srcdoc="&lt;!DOCTYPE html&gt;&lt;html&gt;&lt;head&gt;&lt;meta http-equiv=&quot;Content-Type&quot; content=&quot;text/html; charset=UTF-8&quot; /&gt;&lt;/head&gt;&lt;body id=&quot;tinymce&quot; class=&quot;mce-content-body &quot; data-id=&quot;field_56&quot; aria-label=&quot;Área de texto enriquecido. Pulse ALT-0 para abrir la ayuda.&quot;&gt;&lt;br&gt;&lt;/body&gt;&lt;/html&gt;"></iframe></div><div role="presentation" class="tox-sidebar"><div data-alloy-tabstop="true" tabindex="-1" class="tox-sidebar__slider tox-sidebar--sliding-closed" style="width: 0px;"><div class="tox-sidebar__pane-container"></div></div></div></div><div class="tox-bottom-anchorbar"></div><div class="tox-statusbar"><div class="tox-statusbar__text-container tox-statusbar__text-container--flex-start"><div role="navigation" data-alloy-tabstop="true" class="tox-statusbar__path" aria-disabled="false"><div data-index="0" aria-level="1" role="button" tabindex="-1" class="tox-statusbar__path-item" aria-disabled="false">p</div></div><div class="tox-statusbar__right-container"><button type="button" tabindex="-1" data-alloy-tabstop="true" class="tox-statusbar__wordcount">0 palabras</button><span class="tox-statusbar__branding"><a href="https://www.tiny.cloud/powered-by-tiny?utm_campaign=poweredby&amp;utm_source=tiny&amp;utm_medium=referral&amp;utm_content=v6" rel="noopener" target="_blank" aria-label="Con tecnología de Tiny" tabindex="-1"><svg width="50px" height="16px" viewBox="0 0 50 16" xmlns="http://www.w3.org/2000/svg">
  <path fill-rule="evenodd" clip-rule="evenodd" d="M10.143 0c2.608.015 5.186 2.178 5.186 5.331 0 0 .077 3.812-.084 4.87-.361 2.41-2.164 4.074-4.65 4.496-1.453.284-2.523.49-3.212.623-.373.071-.634.122-.785.152-.184.038-.997.145-1.35.145-2.732 0-5.21-2.04-5.248-5.33 0 0 0-3.514.03-4.442.093-2.4 1.758-4.342 4.926-4.963 0 0 3.875-.752 4.036-.782.368-.07.775-.1 1.15-.1Zm1.826 2.8L5.83 3.989v2.393l-2.455.475v5.968l6.137-1.189V9.243l2.456-.476V2.8ZM5.83 6.382l3.682-.713v3.574l-3.682.713V6.382Zm27.173-1.64-.084-1.066h-2.226v9.132h2.456V7.743c-.008-1.151.998-2.064 2.149-2.072 1.15-.008 1.987.92 1.995 2.072v5.065h2.455V7.359c-.015-2.18-1.657-3.929-3.837-3.913a3.993 3.993 0 0 0-2.908 1.296Zm-6.3-4.266L29.16 0v2.387l-2.456.475V.476Zm0 3.2v9.132h2.456V3.676h-2.456Zm18.179 11.787L49.11 3.676H46.58l-1.612 4.527-.46 1.382-.384-1.382-1.611-4.527H39.98l3.3 9.132L42.15 16l2.732-.537ZM22.867 9.738c0 .752.568 1.075.921 1.075.353 0 .668-.047.998-.154l.537 1.765c-.23.154-.92.537-2.225.537-1.305 0-2.655-.997-2.686-2.686a136.877 136.877 0 0 1 0-4.374H18.8V3.676h1.612v-1.98l2.455-.476v2.456h2.302V5.9h-2.302v3.837Z"></path>
</svg></a></span></div></div><div title="Redimensionar" aria-label="Pulse las teclas de flechas arriba y abajo para cambiar el tamaño del editor." data-alloy-tabstop="true" tabindex="-1" class="tox-statusbar__resize-handle"><svg width="10" height="10" focusable="false"><g fill-rule="nonzero"><path d="M8.1 1.1A.5.5 0 1 1 9 2l-7 7A.5.5 0 1 1 1 8l7-7ZM8.1 5.1A.5.5 0 1 1 9 6l-3 3A.5.5 0 1 1 5 8l3-3Z"></path></g></svg></div></div></div><div aria-hidden="true" class="tox-view-wrap" style="display: none;"><div class="tox-view-wrap__slot-container"></div></div><div aria-hidden="true" class="tox-throbber" style="display: none;"></div></div><div class="tox tox-silver-sink tox-silver-popup-sink tox-tinymce-aux" style="position: relative;"></div></div><div><label class="accesshide" for="field_56_content1">Formato</label><select id="field_56_content1" name="field_56_content1"><option value="1" selected="selected">Formato HTML</option></select></div></div></div>
        </div>

        <div class="mb-3 pt-3">
            <div class="font-weight-bold">Marcas</div>
            <div class="datatagcontrol"><select class="custom-select" name="tags[]" id="tags" multiple="" aria-hidden="true" data-aria-hidden-tab-index="" tabindex="-1" style="visibility: hidden; display: none;"></select><span class="sr-only" id="form_autocomplete_selection-1781204113837-label">Ítems seleccioandos:</span>
<div class="form-autocomplete-selection w-100 form-autocomplete-multiple" id="form_autocomplete_selection-1781204113837" aria-labelledby="form_autocomplete_selection-1781204113837-label" role="listbox" aria-atomic="true" tabindex="0" aria-multiselectable="true">


        <span class="m-1 h-5">No hay selección</span>
</div>
<div class="form-autocomplete-input d-md-inline-block mr-md-2 position-relative">
    <input type="text" id="form_autocomplete_input-1781204113837" class="form-control" list="form_autocomplete_suggestions-1781204113837" placeholder="Introduzca etiquetas..." role="combobox" aria-expanded="false" autocomplete="off" autocorrect="off" autocapitalize="off" aria-autocomplete="list" aria-owns="form_autocomplete_suggestions-1781204113837 form_autocomplete_selection-1781204113837" data-tags="1" data-multiple="multiple" data-fieldtype="autocomplete" style="min-width: 23ch;">
    <span class="form-autocomplete-downarrow position-absolute p-1" id="form_autocomplete_downarrow-1781204113837">▼</span>
</div>
<ul class="form-autocomplete-suggestions" id="form_autocomplete_suggestions-1781204113837" role="listbox" aria-label="Sugerencias" aria-hidden="true" tabindex="-1" style="display: none;">
</ul></div>
        </div>
</div><div id="sticky-footer" class="stickyfooter bg-white border-top">
    <div class="sticky-footer-content-wrapper h-100 d-flex justify-content-center">
        <div class="sticky-footer-content w-100 d-flex align-items-center px-3 py-2  justify-content-end">
                <a class="btn btn-secondary mx-1" role="button" href="https://ingenieria.campus.mdp.edu.ar/mod/data/view.php?d=18&amp;amp;advanced=0&amp;amp;paging&amp;amp;page=0">Cancelar</a><input type="submit" name="saveandview" value="Guardar" class="btn btn-primary mx-1"><input type="submit" name="saveandadd" value="Guardar y añadir otro" class="btn btn-primary mx-1">
        </div>
    </div>
</div></div></div></form>
```

## Db 1er año

### URL:

`https://ingenieria.campus.mdp.edu.ar/mod/data/view.php?id=54789`

### HTML PAGINA DE VISTA (TODAS LAS RTAS):

```
<form action="https://ingenieria.campus.mdp.edu.ar/mod/data/view.php?d=19&amp;sesskey=bN4VoosUA9" method="post"><div id="data-singleview-content" class="box "><div id="defaulttemplate-single" class="my-5">
    <div class="defaulttemplate-single-body my-5">
        <div class="row my-6">
            <div class="col-auto"><a href="https://ingenieria.campus.mdp.edu.ar/user/view.php?id=2987&amp;course=1732" class="d-inline-block aabtn"><img src="https://ingenieria.campus.mdp.edu.ar/pluginfile.php/36551/user/icon/adaptable/f1?rev=890264" class="userpicture" width="64" height="64" alt="MARTIN ESTEBAN GIRAU" title="MARTIN ESTEBAN GIRAU"></a></div>
            <div class="col">
                <div class="row h-100">
                    <div class="col-3 align-self-center">
                        <a href="https://ingenieria.campus.mdp.edu.ar/user/view.php?id=2987&amp;course=1732">MARTIN ESTEBAN GIRAU</a><br><span class="data-timeinfo"><span title="jueves, 11 de junio de 2026, 15:26">11 jun 2026</span></span>
                    </div>
                    <div class="col-4 col-md-6 text-right align-self-center data-timeinfo">
                        <span class="font-weight-bold ">Editado por última vez:&nbsp;</span><span title="jueves, 11 de junio de 2026, 15:26">11 jun 2026</span>
                    </div>
                    <div class="col-4 col-md-3 ml-auto align-self-center d-flex flex-row-reverse">
                        <div><div class="action-menu moodle-actionmenu entry-actionsmenu" id="action-menu-6" data-enhance="moodle-core-actionmenu">

        <div class="menubar d-flex " id="action-menu-6-menubar">




                <div class="action-menu-trigger">
                    <div class="dropdown">
                        <a href="#" tabindex="0" class="btn btn-icon d-flex align-items-center justify-content-center no-caret  dropdown-toggle icon-no-margin" id="action-menu-toggle-6" aria-label="Acciones" data-toggle="dropdown" role="button" aria-haspopup="true" aria-expanded="false" aria-controls="action-menu-6-menu">

                            <i class="icon fa fa-ellipsis-v fa-fw" title="Acciones" role="img" aria-label="Acciones"></i>

                            <b class="caret"></b>
                        </a>
                            <div class="dropdown-menu menu dropdown-menu-right" id="action-menu-6-menu" data-rel="menu-content" aria-labelledby="action-menu-toggle-6" role="menu">
                                                                <a href="https://ingenieria.campus.mdp.edu.ar/mod/data/edit.php?d=19&amp;mode=single&amp;page=0&amp;rid=26&amp;sesskey=bN4VoosUA9&amp;backto=https%253A%252F%252Fingenieria.campus.mdp.edu.ar%252Fmod%252Fdata%252Fview.php%253Fd%253D19%2526mode%253Dsingle%2526page%253D0%2526rid%253D26" class="dropdown-item menu-action" role="menuitem" tabindex="-1">
                                <span class="menu-action-text">Editar</span>
                        </a>
                                                                <a href="https://ingenieria.campus.mdp.edu.ar/mod/data/view.php?d=19&amp;mode=single&amp;page=0&amp;delete=26&amp;sesskey=bN4VoosUA9" class="dropdown-item menu-action" role="menuitem" tabindex="-1">
                                <span class="menu-action-text">Borrar</span>
                        </a>
                            </div>
                    </div>
                </div>

        </div>

</div></div>
                        <div class="ml-auto my-auto "></div>
                    </div>
                </div>
            </div>
        </div>
        <hr>

        <div class="my-6">
            <div class="mt-4">
                <span class="font-weight-bold">id_alumno</span>
                <p class="mt-2">2987</p>
            </div>
            <div class="mt-4">
                <span class="font-weight-bold">alumno</span>
                <p class="mt-2">Martin Girau</p>
            </div>
            <div class="mt-4">
                <span class="font-weight-bold">anio_ingreso</span>
                <p class="mt-2">2023</p>
            </div>
            <div class="mt-4">
                <span class="font-weight-bold">cuatrimestre_ingreso</span>
                <p class="mt-2">2</p>
            </div>
            <div class="mt-4">
                <span class="font-weight-bold">aprobadas</span>
                <p class="mt-2">3</p>
            </div>
            <div class="mt-4">
                <span class="font-weight-bold">ralentizacion</span>
                <p class="mt-2">23</p>
            </div>
            <div class="mt-4">
                <span class="font-weight-bold">materias</span>
                <p class="mt-2"></p><div class="data-field-html"><p>[<br>&nbsp; { "materia": "Análisis Matemático I", "nota": 7 },<br>&nbsp; { "materia": "Física <a class="autolink" title="a" href="https://ingenieria.campus.mdp.edu.ar/mod/page/view.php?id=54299">A</a>", "nota": 8 }<br>]</p></div><p></p>
            </div>
        <div class="tag_otherfields ">
</div>
            <div class="mt-4">
                <span class="font-weight-bold">Marcas</span>
                <p class="mt-2"></p>
            </div>
        </div>
    </div>
</div></div><div id="sticky-footer" class="stickyfooter bg-white border-top">
    <div class="sticky-footer-content-wrapper h-100 d-flex justify-content-center">
        <div class="sticky-footer-content w-100 d-flex align-items-center px-3 py-2  justify-content-end">
                <div class="navitem submit mr-auto ml-auto">

</div>
<div class="navitem">
        <a href="https://ingenieria.campus.mdp.edu.ar/mod/data/edit.php?id=54789&amp;backto=https%3A%2F%2Fingenieria.campus.mdp.edu.ar%2Fmod%2Fdata%2Fview.php%3Fd%3D19%26amp%3Bmode%3Dsingle%26amp%3Bpage%3D0" id="action_link6a2afde66cec3145" class="btn btn-primary mx-1" role="button">Añadir entrada</a>
</div>
        </div>
    </div>
</div></form>
```

### HTML FORMULARIO DE CREACION DE ENTRADA

(Etiqueta Form completa)

```
<form enctype="multipart/form-data" action="edit.php" method="post"><div><input name="d" value="19" type="hidden"><input name="rid" value="0" type="hidden"><input name="sesskey" value="bN4VoosUA9" type="hidden"><div class="box generalbox boxaligncenter boxwidthwide"><h2>Nueva entrada</h2><div id="defaulttemplate-addentry">
        <div class="mb-3 pt-3">
            <div class="font-weight-bold">id_alumno</div>
            <div title=""><label for="field_57"><span class="accesshide">id_alumno</span><div class="inline-req"><i class="icon fa fa-exclamation-circle text-danger fa-fw" title="Campo obligatorio" role="img" aria-label="Campo obligatorio"></i></div></label><input class="basefieldinput form-control d-inline mod-data-input" type="text" name="field_57" id="field_57" value=""></div>
        </div>
        <div class="mb-3 pt-3">
            <div class="font-weight-bold">alumno</div>
            <div title=""><label for="field_58"><span class="accesshide">alumno</span><div class="inline-req"><i class="icon fa fa-exclamation-circle text-danger fa-fw" title="Campo obligatorio" role="img" aria-label="Campo obligatorio"></i></div></label><input class="basefieldinput form-control d-inline mod-data-input" type="text" name="field_58" id="field_58" value=""></div>
        </div>
        <div class="mb-3 pt-3">
            <div class="font-weight-bold">anio_ingreso</div>
            <div title=""><label for="field_59"><span class="accesshide">anio_ingreso</span></label><input class="basefieldinput form-control d-inline mod-data-input" type="text" name="field_59" id="field_59" value=""></div>
        </div>
        <div class="mb-3 pt-3">
            <div class="font-weight-bold">cuatrimestre_ingreso</div>
            <div title=""><label for="field_60"><span class="accesshide">cuatrimestre_ingreso</span></label><input class="basefieldinput form-control d-inline mod-data-input" type="text" name="field_60" id="field_60" value=""></div>
        </div>
        <div class="mb-3 pt-3">
            <div class="font-weight-bold">aprobadas</div>
            <div title=""><label for="field_61"><span class="accesshide">aprobadas</span></label><input class="basefieldinput form-control d-inline mod-data-input" type="text" name="field_61" id="field_61" value=""></div>
        </div>
        <div class="mb-3 pt-3">
            <div class="font-weight-bold">ralentizacion</div>
            <div title=""><label for="field_62"><span class="accesshide">ralentizacion</span></label><input class="basefieldinput form-control d-inline mod-data-input" type="text" name="field_62" id="field_62" value=""></div>
        </div>
        <div class="mb-3 pt-3">
            <div class="font-weight-bold">materias</div>
            <div title="json con todas las materias y notas cargadas" class="d-inline-flex"><label for="field_63"><span class="accesshide">materias</span></label><input type="hidden" name="field_63_itemid" value="812802304"><div class="mod-data-input"><div><textarea id="field_63" name="field_63" rows="100" class="form-control" data-fieldtype="editor" cols="60" spellcheck="true" style="display: none;" aria-hidden="true"></textarea><div role="application" class="tox tox-tinymce" aria-disabled="false" style="visibility: hidden; height: 2149px;"><div class="tox-editor-container"><div data-alloy-vertical-dir="toptobottom" class="tox-editor-header"><div role="menubar" data-alloy-tabstop="true" class="tox-menubar"><button aria-haspopup="true" role="menuitem" type="button" tabindex="-1" data-alloy-tabstop="true" unselectable="on" class="tox-mbtn tox-mbtn--select" aria-expanded="false" style="user-select: none; width: 51.4531px;"><span class="tox-mbtn__select-label">Editar</span><div class="tox-mbtn__select-chevron"><svg width="10" height="10" focusable="false"><path d="M8.7 2.2c.3-.3.8-.3 1 0 .4.4.4.9 0 1.2L5.7 7.8c-.3.3-.9.3-1.2 0L.2 3.4a.8.8 0 0 1 0-1.2c.3-.3.8-.3 1.1 0L5 6l3.7-3.8Z" fill-rule="nonzero"></path></svg></div></button><button aria-haspopup="true" role="menuitem" type="button" tabindex="-1" data-alloy-tabstop="true" unselectable="on" class="tox-mbtn tox-mbtn--select" style="user-select: none; width: 36px;" aria-expanded="false"><span class="tox-mbtn__select-label">Ver</span><div class="tox-mbtn__select-chevron"><svg width="10" height="10" focusable="false"><path d="M8.7 2.2c.3-.3.8-.3 1 0 .4.4.4.9 0 1.2L5.7 7.8c-.3.3-.9.3-1.2 0L.2 3.4a.8.8 0 0 1 0-1.2c.3-.3.8-.3 1.1 0L5 6l3.7-3.8Z" fill-rule="nonzero"></path></svg></div></button><button aria-haspopup="true" role="menuitem" type="button" tabindex="-1" data-alloy-tabstop="true" unselectable="on" class="tox-mbtn tox-mbtn--select" style="user-select: none; width: 62.5156px;" aria-expanded="false"><span class="tox-mbtn__select-label">Insertar</span><div class="tox-mbtn__select-chevron"><svg width="10" height="10" focusable="false"><path d="M8.7 2.2c.3-.3.8-.3 1 0 .4.4.4.9 0 1.2L5.7 7.8c-.3.3-.9.3-1.2 0L.2 3.4a.8.8 0 0 1 0-1.2c.3-.3.8-.3 1.1 0L5 6l3.7-3.8Z" fill-rule="nonzero"></path></svg></div></button><button aria-haspopup="true" role="menuitem" type="button" tabindex="-1" data-alloy-tabstop="true" unselectable="on" class="tox-mbtn tox-mbtn--select" style="user-select: none; width: 68.0469px;" aria-expanded="false"><span class="tox-mbtn__select-label">Formato</span><div class="tox-mbtn__select-chevron"><svg width="10" height="10" focusable="false"><path d="M8.7 2.2c.3-.3.8-.3 1 0 .4.4.4.9 0 1.2L5.7 7.8c-.3.3-.9.3-1.2 0L.2 3.4a.8.8 0 0 1 0-1.2c.3-.3.8-.3 1.1 0L5 6l3.7-3.8Z" fill-rule="nonzero"></path></svg></div></button><button aria-haspopup="true" role="menuitem" type="button" tabindex="-1" data-alloy-tabstop="true" unselectable="on" class="tox-mbtn tox-mbtn--select" style="user-select: none; width: 98.625px;" aria-expanded="false"><span class="tox-mbtn__select-label">Herramientas</span><div class="tox-mbtn__select-chevron"><svg width="10" height="10" focusable="false"><path d="M8.7 2.2c.3-.3.8-.3 1 0 .4.4.4.9 0 1.2L5.7 7.8c-.3.3-.9.3-1.2 0L.2 3.4a.8.8 0 0 1 0-1.2c.3-.3.8-.3 1.1 0L5 6l3.7-3.8Z" fill-rule="nonzero"></path></svg></div></button><button aria-haspopup="true" role="menuitem" type="button" tabindex="-1" data-alloy-tabstop="true" unselectable="on" class="tox-mbtn tox-mbtn--select" style="user-select: none; width: 47.6406px;" aria-expanded="false"><span class="tox-mbtn__select-label">Tabla</span><div class="tox-mbtn__select-chevron"><svg width="10" height="10" focusable="false"><path d="M8.7 2.2c.3-.3.8-.3 1 0 .4.4.4.9 0 1.2L5.7 7.8c-.3.3-.9.3-1.2 0L.2 3.4a.8.8 0 0 1 0-1.2c.3-.3.8-.3 1.1 0L5 6l3.7-3.8Z" fill-rule="nonzero"></path></svg></div></button><button aria-haspopup="true" role="menuitem" type="button" tabindex="-1" data-alloy-tabstop="true" unselectable="on" class="tox-mbtn tox-mbtn--select" style="user-select: none; width: 54.8281px;" aria-expanded="false"><span class="tox-mbtn__select-label">Ayuda</span><div class="tox-mbtn__select-chevron"><svg width="10" height="10" focusable="false"><path d="M8.7 2.2c.3-.3.8-.3 1 0 .4.4.4.9 0 1.2L5.7 7.8c-.3.3-.9.3-1.2 0L.2 3.4a.8.8 0 0 1 0-1.2c.3-.3.8-.3 1.1 0L5 6l3.7-3.8Z" fill-rule="nonzero"></path></svg></div></button></div><div role="group" class="tox-toolbar-overlord" aria-disabled="false"><div role="group" class="tox-toolbar__primary"><div title="historial" role="toolbar" data-alloy-tabstop="true" tabindex="-1" class="tox-toolbar__group"><button aria-label="Deshacer" title="Deshacer" type="button" tabindex="-1" class="tox-tbtn tox-tbtn--disabled" aria-disabled="true" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M6.4 8H12c3.7 0 6.2 2 6.8 5.1.6 2.7-.4 5.6-2.3 6.8a1 1 0 0 1-1-1.8c1.1-.6 1.8-2.7 1.4-4.6-.5-2.1-2.1-3.5-4.9-3.5H6.4l3.3 3.3a1 1 0 1 1-1.4 1.4l-5-5a1 1 0 0 1 0-1.4l5-5a1 1 0 0 1 1.4 1.4L6.4 8Z" fill-rule="nonzero"></path></svg></span></button><button aria-label="Rehacer" title="Rehacer" type="button" tabindex="-1" class="tox-tbtn tox-tbtn--disabled" aria-disabled="true" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M17.6 10H12c-2.8 0-4.4 1.4-4.9 3.5-.4 2 .3 4 1.4 4.6a1 1 0 1 1-1 1.8c-2-1.2-2.9-4.1-2.3-6.8.6-3 3-5.1 6.8-5.1h5.6l-3.3-3.3a1 1 0 1 1 1.4-1.4l5 5a1 1 0 0 1 0 1.4l-5 5a1 1 0 0 1-1.4-1.4l3.3-3.3Z" fill-rule="nonzero"></path></svg></span></button></div><div title="formato" role="toolbar" data-alloy-tabstop="true" tabindex="-1" class="tox-toolbar__group"><button aria-label="Negrita" title="Negrita" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M7.8 19c-.3 0-.5 0-.6-.2l-.2-.5V5.7c0-.2 0-.4.2-.5l.6-.2h5c1.5 0 2.7.3 3.5 1 .7.6 1.1 1.4 1.1 2.5a3 3 0 0 1-.6 1.9c-.4.6-1 1-1.6 1.2.4.1.9.3 1.3.6s.8.7 1 1.2c.4.4.5 1 .5 1.6 0 1.3-.4 2.3-1.3 3-.8.7-2.1 1-3.8 1H7.8Zm5-8.3c.6 0 1.2-.1 1.6-.5.4-.3.6-.7.6-1.3 0-1.1-.8-1.7-2.3-1.7H9.3v3.5h3.4Zm.5 6c.7 0 1.3-.1 1.7-.4.4-.4.6-.9.6-1.5s-.2-1-.7-1.4c-.4-.3-1-.4-2-.4H9.4v3.8h4Z" fill-rule="evenodd"></path></svg></span></button><button aria-label="Cursiva" title="Cursiva" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="m16.7 4.7-.1.9h-.3c-.6 0-1 0-1.4.3-.3.3-.4.6-.5 1.1l-2.1 9.8v.6c0 .5.4.8 1.4.8h.2l-.2.8H8l.2-.8h.2c1.1 0 1.8-.5 2-1.5l2-9.8.1-.5c0-.6-.4-.8-1.4-.8h-.3l.2-.9h5.8Z" fill-rule="evenodd"></path></svg></span></button></div><div role="toolbar" data-alloy-tabstop="true" tabindex="-1" class="tox-toolbar__group"><button aria-label="Mostrar u ocultar elementos adicionales de la barra de herramientas" title="Mostrar u ocultar elementos adicionales de la barra de herramientas" type="button" tabindex="-1" data-alloy-tabstop="true" class="tox-tbtn" aria-pressed="false"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M6 10a2 2 0 0 0-2 2c0 1.1.9 2 2 2a2 2 0 0 0 2-2 2 2 0 0 0-2-2Zm12 0a2 2 0 0 0-2 2c0 1.1.9 2 2 2a2 2 0 0 0 2-2 2 2 0 0 0-2-2Zm-6 0a2 2 0 0 0-2 2c0 1.1.9 2 2 2a2 2 0 0 0 2-2 2 2 0 0 0-2-2Z" fill-rule="nonzero"></path></svg></span></button></div></div><div role="group" class="tox-toolbar__overflow tox-toolbar__overflow--closed" style="height: 0px;"><div title="content" role="toolbar" data-alloy-tabstop="true" tabindex="-1" class="tox-toolbar__group"><button aria-label="Imagen" title="Imagen" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="m5 15.7 3.3-3.2c.3-.3.7-.3 1 0L12 15l4.1-4c.3-.4.8-.4 1 0l2 1.9V5H5v10.7ZM5 18V19h3l2.8-2.9-2-2L5 17.9Zm14-3-2.5-2.4-6.4 6.5H19v-4ZM4 3h16c.6 0 1 .4 1 1v16c0 .6-.4 1-1 1H4a1 1 0 0 1-1-1V4c0-.6.4-1 1-1Zm6 8a2 2 0 1 0 0-4 2 2 0 0 0 0 4Z" fill-rule="nonzero"></path></svg></span></button><button aria-label="Multimedios" title="Multimedios" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M4 3h16c.6 0 1 .4 1 1v16c0 .6-.4 1-1 1H4a1 1 0 0 1-1-1V4c0-.6.4-1 1-1Zm1 2v14h14V5H5Zm4.8 2.6 5.6 4a.5.5 0 0 1 0 .8l-5.6 4A.5.5 0 0 1 9 16V8a.5.5 0 0 1 .8-.4Z" fill-rule="nonzero"></path></svg></span></button><button aria-label="Grabar audio" title="Grabar audio" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg data-buttonsource="moodle" width="24" height="24" xmlns="http://www.w3.org/2000/svg" focusable="false">
        <image href="https://ingenieria.campus.mdp.edu.ar/theme/image.php/adaptable/tiny_recordrtc/1775501275/audio" width="24" height="24"></image>
</svg></span></button><button aria-label="Grabar video" title="Grabar video" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg data-buttonsource="moodle" width="24" height="24" xmlns="http://www.w3.org/2000/svg" focusable="false">
        <image href="https://ingenieria.campus.mdp.edu.ar/theme/image.php/adaptable/tiny_recordrtc/1775501275/video" width="24" height="24"></image>
</svg></span></button><button aria-label="Configurar contenido H5P" title="Configurar contenido H5P" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg data-buttonsource="moodle" width="24" height="24" xmlns="http://www.w3.org/2000/svg" focusable="false">
        <image href="https://ingenieria.campus.mdp.edu.ar/theme/image.php/adaptable/tiny_h5p/1775501275/icon" width="24" height="24"></image>
</svg></span></button><button aria-label="Enlace" title="Enlace" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M6.2 12.3a1 1 0 0 1 1.4 1.4l-2 2a2 2 0 1 0 2.6 2.8l4.8-4.8a1 1 0 0 0 0-1.4 1 1 0 1 1 1.4-1.3 2.9 2.9 0 0 1 0 4L9.6 20a3.9 3.9 0 0 1-5.5-5.5l2-2Zm11.6-.6a1 1 0 0 1-1.4-1.4l2-2a2 2 0 1 0-2.6-2.8L11 10.3a1 1 0 0 0 0 1.4A1 1 0 1 1 9.6 13a2.9 2.9 0 0 1 0-4L14.4 4a3.9 3.9 0 0 1 5.5 5.5l-2 2Z" fill-rule="nonzero"></path></svg></span></button><button aria-label="Desenlanzar" title="Desenlanzar" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M6.2 12.3a1 1 0 0 1 1.4 1.4l-2 2a2 2 0 1 0 2.6 2.8l4.8-4.8a1 1 0 0 0 0-1.4 1 1 0 1 1 1.4-1.3 2.9 2.9 0 0 1 0 4L9.6 20a3.9 3.9 0 0 1-5.5-5.5l2-2Zm11.6-.6a1 1 0 0 1-1.4-1.4l2.1-2a2 2 0 1 0-2.7-2.8L11 10.3a1 1 0 0 0 0 1.4A1 1 0 1 1 9.6 13a2.9 2.9 0 0 1 0-4L14.4 4a3.9 3.9 0 0 1 5.5 5.5l-2 2ZM7.6 6.3a.8.8 0 0 1-1 1.1L3.3 4.2a.7.7 0 1 1 1-1l3.2 3.1ZM5.1 8.6a.8.8 0 0 1 0 1.5H3a.8.8 0 0 1 0-1.5H5Zm5-3.5a.8.8 0 0 1-1.5 0V3a.8.8 0 0 1 1.5 0V5Zm6 11.8a.8.8 0 0 1 1-1l3.2 3.2a.8.8 0 0 1-1 1L16 17Zm-2.2 2a.8.8 0 0 1 1.5 0V21a.8.8 0 0 1-1.5 0V19Zm5-3.5a.7.7 0 1 1 0-1.5H21a.8.8 0 0 1 0 1.5H19Z" fill-rule="nonzero"></path></svg></span></button></div><div title="Ver" role="toolbar" data-alloy-tabstop="true" tabindex="-1" class="tox-toolbar__group"><button aria-label="Pantalla completa" title="Pantalla completa" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="m15.3 10-1.2-1.3 2.9-3h-2.3a.9.9 0 1 1 0-1.7H19c.5 0 .9.4.9.9v4.4a.9.9 0 1 1-1.8 0V7l-2.9 3Zm0 4 3 3v-2.3a.9.9 0 1 1 1.7 0V19c0 .5-.4.9-.9.9h-4.4a.9.9 0 1 1 0-1.8H17l-3-2.9 1.3-1.2ZM10 15.4l-2.9 3h2.3a.9.9 0 1 1 0 1.7H5a.9.9 0 0 1-.9-.9v-4.4a.9.9 0 1 1 1.8 0V17l2.9-3 1.2 1.3ZM8.7 10 5.7 7v2.3a.9.9 0 0 1-1.7 0V5c0-.5.4-.9.9-.9h4.4a.9.9 0 0 1 0 1.8H7l3 2.9-1.3 1.2Z" fill-rule="nonzero"></path></svg></span></button></div><div title="alineación" role="toolbar" data-alloy-tabstop="true" tabindex="-1" class="tox-toolbar__group"><button aria-label="Alinear a la izquierda" title="Alinear a la izquierda" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M5 5h14c.6 0 1 .4 1 1s-.4 1-1 1H5a1 1 0 1 1 0-2Zm0 4h8c.6 0 1 .4 1 1s-.4 1-1 1H5a1 1 0 1 1 0-2Zm0 8h8c.6 0 1 .4 1 1s-.4 1-1 1H5a1 1 0 0 1 0-2Zm0-4h14c.6 0 1 .4 1 1s-.4 1-1 1H5a1 1 0 0 1 0-2Z" fill-rule="evenodd"></path></svg></span></button><button aria-label="Alinear al centro" title="Alinear al centro" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M5 5h14c.6 0 1 .4 1 1s-.4 1-1 1H5a1 1 0 1 1 0-2Zm3 4h8c.6 0 1 .4 1 1s-.4 1-1 1H8a1 1 0 1 1 0-2Zm0 8h8c.6 0 1 .4 1 1s-.4 1-1 1H8a1 1 0 0 1 0-2Zm-3-4h14c.6 0 1 .4 1 1s-.4 1-1 1H5a1 1 0 0 1 0-2Z" fill-rule="evenodd"></path></svg></span></button><button aria-label="Alinear a la derecha" title="Alinear a la derecha" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M5 5h14c.6 0 1 .4 1 1s-.4 1-1 1H5a1 1 0 1 1 0-2Zm6 4h8c.6 0 1 .4 1 1s-.4 1-1 1h-8a1 1 0 0 1 0-2Zm0 8h8c.6 0 1 .4 1 1s-.4 1-1 1h-8a1 1 0 0 1 0-2Zm-6-4h14c.6 0 1 .4 1 1s-.4 1-1 1H5a1 1 0 0 1 0-2Z" fill-rule="evenodd"></path></svg></span></button></div><div title="directionality" role="toolbar" data-alloy-tabstop="true" tabindex="-1" class="tox-toolbar__group"><button aria-label="Izquierda a derecha" title="Izquierda a derecha" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M11 5h7a1 1 0 0 1 0 2h-1v11a1 1 0 0 1-2 0V7h-2v11a1 1 0 0 1-2 0v-6c-.5 0-1 0-1.4-.3A3.4 3.4 0 0 1 7.8 10a3.3 3.3 0 0 1 0-2.8 3.4 3.4 0 0 1 1.8-1.8L11 5ZM4.4 16.2 6.2 15l-1.8-1.2a1 1 0 0 1 1.2-1.6l3 2a1 1 0 0 1 0 1.6l-3 2a1 1 0 1 1-1.2-1.6Z" fill-rule="evenodd"></path></svg></span></button><button aria-label="Derecha a izquierda" title="Derecha a izquierda" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M8 5h8v2h-2v12h-2V7h-2v12H8v-7c-.5 0-1 0-1.4-.3A3.4 3.4 0 0 1 4.8 10a3.3 3.3 0 0 1 0-2.8 3.4 3.4 0 0 1 1.8-1.8L8 5Zm12 11.2a1 1 0 1 1-1 1.6l-3-2a1 1 0 0 1 0-1.6l3-2a1 1 0 1 1 1 1.6L18.4 15l1.8 1.2Z" fill-rule="evenodd"></path></svg></span></button></div><div title="sangría" role="toolbar" data-alloy-tabstop="true" tabindex="-1" class="tox-toolbar__group"><button aria-label="Disminuir sangría" title="Disminuir sangría" type="button" tabindex="-1" class="tox-tbtn tox-tbtn--disabled" aria-disabled="true" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M7 5h12c.6 0 1 .4 1 1s-.4 1-1 1H7a1 1 0 1 1 0-2Zm5 4h7c.6 0 1 .4 1 1s-.4 1-1 1h-7a1 1 0 0 1 0-2Zm0 4h7c.6 0 1 .4 1 1s-.4 1-1 1h-7a1 1 0 0 1 0-2Zm-5 4h12a1 1 0 0 1 0 2H7a1 1 0 0 1 0-2Zm1.6-3.8a1 1 0 0 1-1.2 1.6l-3-2a1 1 0 0 1 0-1.6l3-2a1 1 0 0 1 1.2 1.6L6.8 12l1.8 1.2Z" fill-rule="evenodd"></path></svg></span></button><button aria-label="Incrementar sangría" title="Incrementar sangría" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M7 5h12c.6 0 1 .4 1 1s-.4 1-1 1H7a1 1 0 1 1 0-2Zm5 4h7c.6 0 1 .4 1 1s-.4 1-1 1h-7a1 1 0 0 1 0-2Zm0 4h7c.6 0 1 .4 1 1s-.4 1-1 1h-7a1 1 0 0 1 0-2Zm-5 4h12a1 1 0 0 1 0 2H7a1 1 0 0 1 0-2Zm-2.6-3.8L6.2 12l-1.8-1.2a1 1 0 0 1 1.2-1.6l3 2a1 1 0 0 1 0 1.6l-3 2a1 1 0 1 1-1.2-1.6Z" fill-rule="evenodd"></path></svg></span></button></div><div title="lists" role="toolbar" data-alloy-tabstop="true" tabindex="-1" class="tox-toolbar__group"><button aria-label="Lista de viñetas" title="Lista de viñetas" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M11 5h8c.6 0 1 .4 1 1s-.4 1-1 1h-8a1 1 0 0 1 0-2Zm0 6h8c.6 0 1 .4 1 1s-.4 1-1 1h-8a1 1 0 0 1 0-2Zm0 6h8c.6 0 1 .4 1 1s-.4 1-1 1h-8a1 1 0 0 1 0-2ZM4.5 6c0-.4.1-.8.4-1 .3-.4.7-.5 1.1-.5.4 0 .8.1 1 .4.4.3.5.7.5 1.1 0 .4-.1.8-.4 1-.3.4-.7.5-1.1.5-.4 0-.8-.1-1-.4-.4-.3-.5-.7-.5-1.1Zm0 6c0-.4.1-.8.4-1 .3-.4.7-.5 1.1-.5.4 0 .8.1 1 .4.4.3.5.7.5 1.1 0 .4-.1.8-.4 1-.3.4-.7.5-1.1.5-.4 0-.8-.1-1-.4-.4-.3-.5-.7-.5-1.1Zm0 6c0-.4.1-.8.4-1 .3-.4.7-.5 1.1-.5.4 0 .8.1 1 .4.4.3.5.7.5 1.1 0 .4-.1.8-.4 1-.3.4-.7.5-1.1.5-.4 0-.8-.1-1-.4-.4-.3-.5-.7-.5-1.1Z" fill-rule="evenodd"></path></svg></span></button><button aria-label="Lista numerada" title="Lista numerada" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg width="24" height="24" focusable="false"><path d="M10 17h8c.6 0 1 .4 1 1s-.4 1-1 1h-8a1 1 0 0 1 0-2Zm0-6h8c.6 0 1 .4 1 1s-.4 1-1 1h-8a1 1 0 0 1 0-2Zm0-6h8c.6 0 1 .4 1 1s-.4 1-1 1h-8a1 1 0 1 1 0-2ZM6 4v3.5c0 .3-.2.5-.5.5a.5.5 0 0 1-.5-.5V5h-.5a.5.5 0 0 1 0-1H6Zm-1 8.8.2.2h1.3c.3 0 .5.2.5.5s-.2.5-.5.5H4.9a1 1 0 0 1-.9-1V13c0-.4.3-.8.6-1l1.2-.4.2-.3a.2.2 0 0 0-.2-.2H4.5a.5.5 0 0 1-.5-.5c0-.3.2-.5.5-.5h1.6c.5 0 .9.4.9 1v.1c0 .4-.3.8-.6 1l-1.2.4-.2.3ZM7 17v2c0 .6-.4 1-1 1H4.5a.5.5 0 0 1 0-1h1.2c.2 0 .3-.1.3-.3 0-.2-.1-.3-.3-.3H4.4a.4.4 0 1 1 0-.8h1.3c.2 0 .3-.1.3-.3 0-.2-.1-.3-.3-.3H4.5a.5.5 0 1 1 0-1H6c.6 0 1 .4 1 1Z" fill-rule="evenodd"></path></svg></span></button></div><div title="Avanzado" role="toolbar" data-alloy-tabstop="true" tabindex="-1" class="tox-toolbar__group"><button aria-label="Editor de ecuación" title="Editor de ecuación" type="button" tabindex="-1" class="tox-tbtn" aria-disabled="false" aria-pressed="false" style="width: 34px;"><span class="tox-icon tox-tbtn__icon-wrap"><svg data-buttonsource="moodle" width="24" height="24" xmlns="http://www.w3.org/2000/svg" focusable="false">
        <image href="https://ingenieria.campus.mdp.edu.ar/theme/image.php/adaptable/tiny_equation/1775501275/icon" width="24" height="24"></image>
</svg></span></button></div></div></div><div class="tox-anchorbar"></div></div><div class="tox-sidebar-wrap" style="height: 2137.5px;"><div class="tox-edit-area"><iframe id="field_63_ifr" frameborder="0" allowtransparency="true" title="Área de Texto Enriquecido" class="tox-edit-area__iframe" srcdoc="&lt;!DOCTYPE html&gt;&lt;html&gt;&lt;head&gt;&lt;meta http-equiv=&quot;Content-Type&quot; content=&quot;text/html; charset=UTF-8&quot; /&gt;&lt;/head&gt;&lt;body id=&quot;tinymce&quot; class=&quot;mce-content-body &quot; data-id=&quot;field_63&quot; aria-label=&quot;Área de texto enriquecido. Pulse ALT-0 para abrir la ayuda.&quot;&gt;&lt;br&gt;&lt;/body&gt;&lt;/html&gt;"></iframe></div><div role="presentation" class="tox-sidebar"><div data-alloy-tabstop="true" tabindex="-1" class="tox-sidebar__slider tox-sidebar--sliding-closed" style="width: 0px;"><div class="tox-sidebar__pane-container"></div></div></div></div><div class="tox-bottom-anchorbar"></div><div class="tox-statusbar"><div class="tox-statusbar__text-container tox-statusbar__text-container--flex-start"><div role="navigation" data-alloy-tabstop="true" class="tox-statusbar__path" aria-disabled="false"><div data-index="0" aria-level="1" role="button" tabindex="-1" class="tox-statusbar__path-item" aria-disabled="false">p</div></div><div class="tox-statusbar__right-container"><button type="button" tabindex="-1" data-alloy-tabstop="true" class="tox-statusbar__wordcount">0 palabras</button><span class="tox-statusbar__branding"><a href="https://www.tiny.cloud/powered-by-tiny?utm_campaign=poweredby&amp;utm_source=tiny&amp;utm_medium=referral&amp;utm_content=v6" rel="noopener" target="_blank" aria-label="Con tecnología de Tiny" tabindex="-1"><svg width="50px" height="16px" viewBox="0 0 50 16" xmlns="http://www.w3.org/2000/svg">
  <path fill-rule="evenodd" clip-rule="evenodd" d="M10.143 0c2.608.015 5.186 2.178 5.186 5.331 0 0 .077 3.812-.084 4.87-.361 2.41-2.164 4.074-4.65 4.496-1.453.284-2.523.49-3.212.623-.373.071-.634.122-.785.152-.184.038-.997.145-1.35.145-2.732 0-5.21-2.04-5.248-5.33 0 0 0-3.514.03-4.442.093-2.4 1.758-4.342 4.926-4.963 0 0 3.875-.752 4.036-.782.368-.07.775-.1 1.15-.1Zm1.826 2.8L5.83 3.989v2.393l-2.455.475v5.968l6.137-1.189V9.243l2.456-.476V2.8ZM5.83 6.382l3.682-.713v3.574l-3.682.713V6.382Zm27.173-1.64-.084-1.066h-2.226v9.132h2.456V7.743c-.008-1.151.998-2.064 2.149-2.072 1.15-.008 1.987.92 1.995 2.072v5.065h2.455V7.359c-.015-2.18-1.657-3.929-3.837-3.913a3.993 3.993 0 0 0-2.908 1.296Zm-6.3-4.266L29.16 0v2.387l-2.456.475V.476Zm0 3.2v9.132h2.456V3.676h-2.456Zm18.179 11.787L49.11 3.676H46.58l-1.612 4.527-.46 1.382-.384-1.382-1.611-4.527H39.98l3.3 9.132L42.15 16l2.732-.537ZM22.867 9.738c0 .752.568 1.075.921 1.075.353 0 .668-.047.998-.154l.537 1.765c-.23.154-.92.537-2.225.537-1.305 0-2.655-.997-2.686-2.686a136.877 136.877 0 0 1 0-4.374H18.8V3.676h1.612v-1.98l2.455-.476v2.456h2.302V5.9h-2.302v3.837Z"></path>
</svg></a></span></div></div><div title="Redimensionar" aria-label="Pulse las teclas de flechas arriba y abajo para cambiar el tamaño del editor." data-alloy-tabstop="true" tabindex="-1" class="tox-statusbar__resize-handle"><svg width="10" height="10" focusable="false"><g fill-rule="nonzero"><path d="M8.1 1.1A.5.5 0 1 1 9 2l-7 7A.5.5 0 1 1 1 8l7-7ZM8.1 5.1A.5.5 0 1 1 9 6l-3 3A.5.5 0 1 1 5 8l3-3Z"></path></g></svg></div></div></div><div aria-hidden="true" class="tox-view-wrap" style="display: none;"><div class="tox-view-wrap__slot-container"></div></div><div aria-hidden="true" class="tox-throbber" style="display: none;"></div></div><div class="tox tox-silver-sink tox-silver-popup-sink tox-tinymce-aux" style="position: relative;"></div></div><div><label class="accesshide" for="field_63_content1">Formato</label><select id="field_63_content1" name="field_63_content1"><option value="1" selected="selected">Formato HTML</option></select></div></div></div>
        </div>

        <div class="mb-3 pt-3">
            <div class="font-weight-bold">Marcas</div>
            <div class="datatagcontrol"><select class="custom-select" name="tags[]" id="tags" multiple="" aria-hidden="true" data-aria-hidden-tab-index="" tabindex="-1" style="visibility: hidden; display: none;"></select><span class="sr-only" id="form_autocomplete_selection-1781202722580-label">Ítems seleccioandos:</span>
<div class="form-autocomplete-selection w-100 form-autocomplete-multiple" id="form_autocomplete_selection-1781202722580" aria-labelledby="form_autocomplete_selection-1781202722580-label" role="listbox" aria-atomic="true" tabindex="0" aria-multiselectable="true">


        <span class="m-1 h-5">No hay selección</span>
</div>
<div class="form-autocomplete-input d-md-inline-block mr-md-2 position-relative">
    <input type="text" id="form_autocomplete_input-1781202722580" class="form-control" list="form_autocomplete_suggestions-1781202722580" placeholder="Introduzca etiquetas..." role="combobox" aria-expanded="false" autocomplete="off" autocorrect="off" autocapitalize="off" aria-autocomplete="list" aria-owns="form_autocomplete_suggestions-1781202722580 form_autocomplete_selection-1781202722580" data-tags="1" data-multiple="multiple" data-fieldtype="autocomplete" style="min-width: 23ch;">
    <span class="form-autocomplete-downarrow position-absolute p-1" id="form_autocomplete_downarrow-1781202722580">▼</span>
</div>
<ul class="form-autocomplete-suggestions" id="form_autocomplete_suggestions-1781202722580" role="listbox" aria-label="Sugerencias" aria-hidden="true" tabindex="-1" style="display: none;">
</ul></div>
        </div>
</div><div id="sticky-footer" class="stickyfooter bg-white border-top">
    <div class="sticky-footer-content-wrapper h-100 d-flex justify-content-center">
        <div class="sticky-footer-content w-100 d-flex align-items-center px-3 py-2  justify-content-end">
                <a class="btn btn-secondary mx-1" role="button" href="https://ingenieria.campus.mdp.edu.ar/mod/data/view.php?d=19&amp;amp;mode=single&amp;amp;page=0">Cancelar</a><input type="submit" name="saveandview" value="Guardar" class="btn btn-primary mx-1"><input type="submit" name="saveandadd" value="Guardar y añadir otro" class="btn btn-primary mx-1">
        </div>
    </div>
</div></div></div></form>
```

## Db Historico 1er Año

### URL:

`https://ingenieria.campus.mdp.edu.ar/mod/data/view.php?id=54791`

### HTML VISTA DE ENTRADAS (Vista de todas las entradas)

```
<form action="https://ingenieria.campus.mdp.edu.ar/mod/data/view.php?d=20&amp;sesskey=bN4VoosUA9" method="post"><div id="data-listview-content" class="box "><div class="defaulttemplate-listentry my-5 p-5 card">
    <div class="row my-6">
        <div class="col-auto"><a href="https://ingenieria.campus.mdp.edu.ar/user/view.php?id=2987&amp;course=1732" class="d-inline-block aabtn"><img src="https://ingenieria.campus.mdp.edu.ar/pluginfile.php/36551/user/icon/adaptable/f1?rev=890264" class="userpicture" width="64" height="64" alt="MARTIN ESTEBAN GIRAU" title="MARTIN ESTEBAN GIRAU"></a></div>
        <div class="col">
            <div class="row h-100">
                <div class="col-3 align-self-center">
                    <a href="https://ingenieria.campus.mdp.edu.ar/user/view.php?id=2987&amp;course=1732">MARTIN ESTEBAN GIRAU</a><br><span class="data-timeinfo"><span title="jueves, 11 de junio de 2026, 15:41">11 jun 2026</span></span>
                </div>
                <div class="col-4 col-md-6 text-right align-self-center data-timeinfo">
                    <span class="font-weight-bold ">Editado por última vez:&nbsp;</span><span title="jueves, 11 de junio de 2026, 15:41">11 jun 2026</span>
                </div>
                <div class="col-4 col-md-3 ml-auto align-self-center d-flex flex-row-reverse">
                    <div><div class="action-menu moodle-actionmenu entry-actionsmenu" id="action-menu-6" data-enhance="moodle-core-actionmenu">

        <div class="menubar d-flex " id="action-menu-6-menubar">




                <div class="action-menu-trigger">
                    <div class="dropdown">
                        <a href="#" tabindex="0" class="btn btn-icon d-flex align-items-center justify-content-center no-caret  dropdown-toggle icon-no-margin" id="action-menu-toggle-6" aria-label="Acciones" data-toggle="dropdown" role="button" aria-haspopup="true" aria-expanded="false" aria-controls="action-menu-6-menu">

                            <i class="icon fa fa-ellipsis-v fa-fw" title="Acciones" role="img" aria-label="Acciones"></i>

                            <b class="caret"></b>
                        </a>
                            <div class="dropdown-menu menu dropdown-menu-right" id="action-menu-6-menu" data-rel="menu-content" aria-labelledby="action-menu-toggle-6" role="menu">
                                                                <a href="https://ingenieria.campus.mdp.edu.ar/mod/data/view.php?d=20&amp;advanced=0&amp;paging&amp;page=0&amp;rid=27&amp;filter=1" class="dropdown-item menu-action" role="menuitem" tabindex="-1">
                                <span class="menu-action-text">Mostrar más</span>
                        </a>
                                                                <a href="https://ingenieria.campus.mdp.edu.ar/mod/data/edit.php?d=20&amp;advanced=0&amp;paging&amp;page=0&amp;rid=27&amp;sesskey=bN4VoosUA9&amp;backto=https%253A%252F%252Fingenieria.campus.mdp.edu.ar%252Fmod%252Fdata%252Fview.php%253Fd%253D20%2526advanced%253D0%2526paging%2526page%253D0%2526rid%253D27%2526mode%253Dsingle" class="dropdown-item menu-action" role="menuitem" tabindex="-1">
                                <span class="menu-action-text">Editar</span>
                        </a>
                                                                <a href="https://ingenieria.campus.mdp.edu.ar/mod/data/view.php?d=20&amp;advanced=0&amp;paging&amp;page=0&amp;delete=27&amp;sesskey=bN4VoosUA9&amp;mode=single" class="dropdown-item menu-action" role="menuitem" tabindex="-1">
                                <span class="menu-action-text">Borrar</span>
                        </a>
                            </div>
                    </div>
                </div>

        </div>

</div></div>
                    <div class="ml-auto my-auto "></div>
                </div>
            </div>
        </div>
    </div>
    <hr>

    <div class="defaulttemplate-list-body">
            <div class="row my-3 align-items-start justify-content-start">
                <div class="col-4 col-lg-3 font-weight-bold">id_alumno</div>
                <div class="col-8 col-lg-9 ml-n3">2987</div>
            </div>
            <div class="row my-3 align-items-start justify-content-start">
                <div class="col-4 col-lg-3 font-weight-bold">alumno</div>
                <div class="col-8 col-lg-9 ml-n3">Martin Girau</div>
            </div>
            <div class="row my-3 align-items-start justify-content-start">
                <div class="col-4 col-lg-3 font-weight-bold">cuatrimestre</div>
                <div class="col-8 col-lg-9 ml-n3">2026-1</div>
            </div>
            <div class="row my-3 align-items-start justify-content-start">
                <div class="col-4 col-lg-3 font-weight-bold">fecha_snapshot</div>
                <div class="col-8 col-lg-9 ml-n3">2026-06-11</div>
            </div>
            <div class="row my-3 align-items-start justify-content-start">
                <div class="col-4 col-lg-3 font-weight-bold">aprobadas</div>
                <div class="col-8 col-lg-9 ml-n3">2</div>
            </div>
            <div class="row my-3 align-items-start justify-content-start">
                <div class="col-4 col-lg-3 font-weight-bold">ralentizacion</div>
                <div class="col-8 col-lg-9 ml-n3">30</div>
            </div>
            <div class="mb-4">
                <span class="font-weight-bold">Marcas</span>
                <p class="mt-2"></p>
            </div>
    </div>
</div><div class="defaulttemplate-listentry my-5 p-5 card">
    <div class="row my-6">
        <div class="col-auto"><a href="https://ingenieria.campus.mdp.edu.ar/user/view.php?id=2987&amp;course=1732" class="d-inline-block aabtn"><img src="https://ingenieria.campus.mdp.edu.ar/pluginfile.php/36551/user/icon/adaptable/f1?rev=890264" class="userpicture" width="64" height="64" alt="MARTIN ESTEBAN GIRAU" title="MARTIN ESTEBAN GIRAU"></a></div>
        <div class="col">
            <div class="row h-100">
                <div class="col-3 align-self-center">
                    <a href="https://ingenieria.campus.mdp.edu.ar/user/view.php?id=2987&amp;course=1732">MARTIN ESTEBAN GIRAU</a><br><span class="data-timeinfo"><span title="jueves, 11 de junio de 2026, 15:44">11 jun 2026</span></span>
                </div>
                <div class="col-4 col-md-6 text-right align-self-center data-timeinfo">
                    <span class="font-weight-bold ">Editado por última vez:&nbsp;</span><span title="jueves, 11 de junio de 2026, 15:44">11 jun 2026</span>
                </div>
                <div class="col-4 col-md-3 ml-auto align-self-center d-flex flex-row-reverse">
                    <div><div class="action-menu moodle-actionmenu entry-actionsmenu" id="action-menu-7" data-enhance="moodle-core-actionmenu">

        <div class="menubar d-flex " id="action-menu-7-menubar">




                <div class="action-menu-trigger">
                    <div class="dropdown">
                        <a href="#" tabindex="0" class="btn btn-icon d-flex align-items-center justify-content-center no-caret  dropdown-toggle icon-no-margin" id="action-menu-toggle-7" aria-label="Acciones" data-toggle="dropdown" role="button" aria-haspopup="true" aria-expanded="false" aria-controls="action-menu-7-menu">

                            <i class="icon fa fa-ellipsis-v fa-fw" title="Acciones" role="img" aria-label="Acciones"></i>

                            <b class="caret"></b>
                        </a>
                            <div class="dropdown-menu menu dropdown-menu-right" id="action-menu-7-menu" data-rel="menu-content" aria-labelledby="action-menu-toggle-7" role="menu">
                                                                <a href="https://ingenieria.campus.mdp.edu.ar/mod/data/view.php?d=20&amp;advanced=0&amp;paging&amp;page=0&amp;rid=28&amp;filter=1" class="dropdown-item menu-action" role="menuitem" tabindex="-1">
                                <span class="menu-action-text">Mostrar más</span>
                        </a>
                                                                <a href="https://ingenieria.campus.mdp.edu.ar/mod/data/edit.php?d=20&amp;advanced=0&amp;paging&amp;page=0&amp;rid=28&amp;sesskey=bN4VoosUA9&amp;backto=https%253A%252F%252Fingenieria.campus.mdp.edu.ar%252Fmod%252Fdata%252Fview.php%253Fd%253D20%2526advanced%253D0%2526paging%2526page%253D0%2526rid%253D28%2526mode%253Dsingle" class="dropdown-item menu-action" role="menuitem" tabindex="-1">
                                <span class="menu-action-text">Editar</span>
                        </a>
                                                                <a href="https://ingenieria.campus.mdp.edu.ar/mod/data/view.php?d=20&amp;advanced=0&amp;paging&amp;page=0&amp;delete=28&amp;sesskey=bN4VoosUA9&amp;mode=single" class="dropdown-item menu-action" role="menuitem" tabindex="-1">
                                <span class="menu-action-text">Borrar</span>
                        </a>
                            </div>
                    </div>
                </div>

        </div>

</div></div>
                    <div class="ml-auto my-auto "></div>
                </div>
            </div>
        </div>
    </div>
    <hr>

    <div class="defaulttemplate-list-body">
            <div class="row my-3 align-items-start justify-content-start">
                <div class="col-4 col-lg-3 font-weight-bold">id_alumno</div>
                <div class="col-8 col-lg-9 ml-n3">2987</div>
            </div>
            <div class="row my-3 align-items-start justify-content-start">
                <div class="col-4 col-lg-3 font-weight-bold">alumno</div>
                <div class="col-8 col-lg-9 ml-n3">Martin Girau</div>
            </div>
            <div class="row my-3 align-items-start justify-content-start">
                <div class="col-4 col-lg-3 font-weight-bold">cuatrimestre</div>
                <div class="col-8 col-lg-9 ml-n3">2026-2</div>
            </div>
            <div class="row my-3 align-items-start justify-content-start">
                <div class="col-4 col-lg-3 font-weight-bold">fecha_snapshot</div>
                <div class="col-8 col-lg-9 ml-n3">2026-9-02</div>
            </div>
            <div class="row my-3 align-items-start justify-content-start">
                <div class="col-4 col-lg-3 font-weight-bold">aprobadas</div>
                <div class="col-8 col-lg-9 ml-n3">9</div>
            </div>
            <div class="row my-3 align-items-start justify-content-start">
                <div class="col-4 col-lg-3 font-weight-bold">ralentizacion</div>
                <div class="col-8 col-lg-9 ml-n3">30</div>
            </div>
            <div class="mb-4">
                <span class="font-weight-bold">Marcas</span>
                <p class="mt-2"></p>
            </div>
    </div>
</div></div><div id="sticky-footer" class="stickyfooter bg-white border-top">
    <div class="sticky-footer-content-wrapper h-100 d-flex justify-content-center">
        <div class="sticky-footer-content w-100 d-flex align-items-center px-3 py-2  justify-content-end">
                <div class="navitem submit mr-auto ml-auto">

</div>
<div class="navitem">
        <a href="https://ingenieria.campus.mdp.edu.ar/mod/data/edit.php?id=54791&amp;backto=https%3A%2F%2Fingenieria.campus.mdp.edu.ar%2Fmod%2Fdata%2Fview.php%3Fd%3D20%26amp%3Badvanced%3D0%26amp%3Bpaging%26amp%3Bpage%3D0" id="action_link6a2b020dc7ee5149" class="btn btn-primary mx-1" role="button">Añadir entrada</a>
</div>
        </div>
    </div>
</div></form>
```

### HTML FORM

```
<form enctype="multipart/form-data" action="edit.php" method="post"><div><input name="d" value="20" type="hidden"><input name="rid" value="0" type="hidden"><input name="sesskey" value="bN4VoosUA9" type="hidden"><div class="box generalbox boxaligncenter boxwidthwide"><h2>Nueva entrada</h2><div id="defaulttemplate-addentry">
        <div class="mb-3 pt-3">
            <div class="font-weight-bold">id_alumno</div>
            <div title=""><label for="field_64"><span class="accesshide">id_alumno</span></label><input class="basefieldinput form-control d-inline mod-data-input" type="text" name="field_64" id="field_64" value=""></div>
        </div>
        <div class="mb-3 pt-3">
            <div class="font-weight-bold">alumno</div>
            <div title=""><label for="field_65"><span class="accesshide">alumno</span></label><input class="basefieldinput form-control d-inline mod-data-input" type="text" name="field_65" id="field_65" value=""></div>
        </div>
        <div class="mb-3 pt-3">
            <div class="font-weight-bold">cuatrimestre</div>
            <div title=""><label for="field_66"><span class="accesshide">cuatrimestre</span></label><input class="basefieldinput form-control d-inline mod-data-input" type="text" name="field_66" id="field_66" value=""></div>
        </div>
        <div class="mb-3 pt-3">
            <div class="font-weight-bold">fecha_snapshot</div>
            <div title=""><label for="field_67"><span class="accesshide">fecha_snapshot</span></label><input class="basefieldinput form-control d-inline mod-data-input" type="text" name="field_67" id="field_67" value=""></div>
        </div>
        <div class="mb-3 pt-3">
            <div class="font-weight-bold">aprobadas</div>
            <div title=""><label for="field_68"><span class="accesshide">aprobadas</span></label><input class="basefieldinput form-control d-inline mod-data-input" type="text" name="field_68" id="field_68" value=""></div>
        </div>
        <div class="mb-3 pt-3">
            <div class="font-weight-bold">ralentizacion</div>
            <div title=""><label for="field_69"><span class="accesshide">ralentizacion</span></label><input class="basefieldinput form-control d-inline mod-data-input" type="text" name="field_69" id="field_69" value=""></div>
        </div>

        <div class="mb-3 pt-3">
            <div class="font-weight-bold">Marcas</div>
            <div class="datatagcontrol"><select class="custom-select" name="tags[]" id="tags" multiple="" aria-hidden="true" data-aria-hidden-tab-index="" tabindex="-1" style="visibility: hidden; display: none;"></select><span class="sr-only" id="form_autocomplete_selection-1781203144692-label">Ítems seleccioandos:</span>
<div class="form-autocomplete-selection w-100 form-autocomplete-multiple" id="form_autocomplete_selection-1781203144692" aria-labelledby="form_autocomplete_selection-1781203144692-label" role="listbox" aria-atomic="true" tabindex="0" aria-multiselectable="true">


        <span class="m-1 h-5">No hay selección</span>
</div>
<div class="form-autocomplete-input d-md-inline-block mr-md-2 position-relative">
    <input type="text" id="form_autocomplete_input-1781203144692" class="form-control" list="form_autocomplete_suggestions-1781203144692" placeholder="Introduzca etiquetas..." role="combobox" aria-expanded="false" autocomplete="off" autocorrect="off" autocapitalize="off" aria-autocomplete="list" aria-owns="form_autocomplete_suggestions-1781203144692 form_autocomplete_selection-1781203144692" data-tags="1" data-multiple="multiple" data-fieldtype="autocomplete" style="min-width: 23ch;">
    <span class="form-autocomplete-downarrow position-absolute p-1" id="form_autocomplete_downarrow-1781203144692">▼</span>
</div>
<ul class="form-autocomplete-suggestions" id="form_autocomplete_suggestions-1781203144692" role="listbox" aria-label="Sugerencias" aria-hidden="true" tabindex="-1" style="display: none;">
</ul></div>
        </div>
</div><div id="sticky-footer" class="stickyfooter bg-white border-top">
    <div class="sticky-footer-content-wrapper h-100 d-flex justify-content-center">
        <div class="sticky-footer-content w-100 d-flex align-items-center px-3 py-2  justify-content-end">
                <a class="btn btn-secondary mx-1" role="button" href="https://ingenieria.campus.mdp.edu.ar/mod/data/view.php?d=20">Cancelar</a><input type="submit" name="saveandview" value="Guardar" class="btn btn-primary mx-1"><input type="submit" name="saveandadd" value="Guardar y añadir otro" class="btn btn-primary mx-1">
        </div>
    </div>
</div></div></div></form>
```

## Paginacion

En moodle, la cantidad maxima de entradas por pagina es de 1000.
Conviene usar este ajuste pero de todos modos considerar la paginacion, porque en un caso raro podrian llegar a ser mas de 1000.

### HTML Asociado para configuracion de resultados por pagina y demas.

```
<form id="options" action="view.php" method="get"><div class="d-flex" id="yui_3_18_1_1_1781206118280_301"><div id="yui_3_18_1_1_1781206118280_300"><input type="hidden" name="d" value="15"><label for="pref_perpage">Entradas por página</label> <select id="pref_perpage" class="select custom-select custom-select mr-1" name="perpage" data-initial-value="1000"><option value="2">2</option><option value="3">3</option><option value="4">4</option><option value="5">5</option><option value="6">6</option><option value="7">7</option><option value="8">8</option><option value="9">9</option><option value="10">10</option><option value="15">15</option><option value="20">20</option><option value="30">30</option><option value="40">40</option><option value="50">50</option><option value="100">100</option><option value="200">200</option><option value="300">300</option><option value="400">400</option><option value="500">500</option><option selected="selected" value="1000">1000</option></select><div id="reg_search" class="search_inline mr-1" style="display: inline;"><label for="pref_search" class="mr-1">Buscar</label><input type="text" class="form-control d-inline-block align-middle w-auto mr-1" size="16" name="search" id="pref_search" value=""></div><label for="pref_sortby">Ordenar por</label> <select name="sort" id="pref_sortby" class="custom-select mr-1" data-initial-value="0"><optgroup label="Campos"><option value="41">Descripcion</option></optgroup><optgroup label="Otro"><option value="0" selected="selected">Tiempo añadido</option><option value="-4">Tiempo modificado</option><option value="-1">Nombre</option><option value="-2">Apellido</option><option value="-3">Aprobado</option></optgroup></select><label for="pref_order" class="accesshide">Ordenar</label><select id="pref_order" name="order" class="custom-select mr-1"><option value="ASC" selected="selected">Ascendente</option><option value="DESC">Descendente</option></select><input type="hidden" name="advanced" value="0"><input type="hidden" name="filter" value="1"><input type="checkbox" id="advancedcheckbox" name="advanced" value="1" onchange="showHideAdvSearch(this.checked);" class="mx-1" data-initial-value="1"><label for="advancedcheckbox" id="yui_3_18_1_1_1781206118280_309">Búsqueda avanzada</label></div><div id="advsearch-save-sec" class="ml-auto search_inline" style="display: inline;"><input type="submit" class="btn btn-secondary" value="Guardar ajustes"></div></div><div><br><div class="search_none" id="data_adv_form" style="display: none;"><table class="boxaligncenter"><tbody><tr><td colspan="2">&nbsp;</td></tr><tr><td><div class="defaulttemplate-asearch container">
    <div class="row row-cols-1 row-cols-md-2 row-cols-lg-3">
        <div class="mb-3 col">
            <div class="font-weight-bold mb-2">Nombre</div>
            <label class="accesshide" for="u_fn">Nombre</label><input type="text" class="form-control" size="16" id="u_fn" name="u_fn" value="">
        </div>
        <div class="mb-3 col">
            <div class="font-weight-bold mb-2">Apellido</div>
            <label class="accesshide" for="u_ln">Apellido</label><input type="text" class="form-control" size="16" id="u_ln" name="u_ln" value="">
        </div>

            <div class="mb-3 col">
                <div class="font-weight-bold mb-2">Descripcion</div>
                <label class="accesshide" for="f_41">Descripcion</label><input type="text" size="16" id="f_41" name="f_41" value="" class="form-control">
            </div>

            <div class="mb-3 col">
                <div class="font-weight-bold mb-2">Marcas</div>
                <div class="datatagcontrol"><select class="custom-select" name="tags[]" id="tags" multiple="" aria-hidden="true" data-aria-hidden-tab-index="" tabindex="-1" style="visibility: hidden; display: none;"></select><span class="sr-only" id="form_autocomplete_selection-1781206118592-label">Ítems seleccioandos:</span>
<div class="form-autocomplete-selection w-100 form-autocomplete-multiple" id="form_autocomplete_selection-1781206118592" aria-labelledby="form_autocomplete_selection-1781206118592-label" role="listbox" aria-atomic="true" tabindex="0" aria-multiselectable="true">


        <span class="m-1 h-5">No hay selección</span>
</div>
<div class="form-autocomplete-input d-md-inline-block mr-md-2 position-relative">
    <input type="text" id="form_autocomplete_input-1781206118592" class="form-control" list="form_autocomplete_suggestions-1781206118592" placeholder="Introduzca etiquetas..." role="combobox" aria-expanded="false" autocomplete="off" autocorrect="off" autocapitalize="off" aria-autocomplete="list" aria-owns="form_autocomplete_suggestions-1781206118592 form_autocomplete_selection-1781206118592" data-tags="1" data-multiple="multiple" data-fieldtype="autocomplete" style="min-width: 23ch;">
    <span class="form-autocomplete-downarrow position-absolute p-1" id="form_autocomplete_downarrow-1781206118592">▼</span>
</div>
<ul class="form-autocomplete-suggestions" id="form_autocomplete_suggestions-1781206118592" role="listbox" aria-label="Sugerencias" aria-hidden="true" tabindex="-1" style="display: none;">
</ul></div>
            </div>
    </div>
</div></td></tr><tr><td colspan="4"><br><input type="submit" class="btn btn-primary mr-1" value="Guardar ajustes"><input type="submit" class="btn btn-secondary" name="resetadv" value="Restablecer filtros"></td></tr></tbody></table></div></div></form>
```

En la practica le tengo que dar en guardar ajuste para que la pagina cargue con el ajuste correcto.

### Html asociado de paginacion:

```
<div id="sticky-footer" class="stickyfooter bg-white border-top">
    <div class="sticky-footer-content-wrapper h-100 d-flex justify-content-center">
        <div class="sticky-footer-content w-100 d-flex align-items-center px-3 py-2  justify-content-end">
                <div class="navitem submit mr-auto ml-auto">
    <nav aria-label="Página" class="pagination pagination-centered justify-content-center">
        <ul class="mt-1 pagination " data-page-size="10">
                <li class="page-item active" data-page-number="1">
                    <a href="#" class="page-link" aria-current="page">
                        <span aria-hidden="true">1</span>
                        <span class="sr-only">Página 1</span>
                    </a>
                </li>
                <li class="page-item " data-page-number="2">
                    <a href="https://ingenieria.campus.mdp.edu.ar/mod/data/view.php?d=15&amp;advanced=0&amp;paging&amp;page=1" class="page-link">
                        <span aria-hidden="true">2</span>
                        <span class="sr-only">Página 2</span>
                    </a>
                </li>
                <li class="page-item " data-page-number="3">
                    <a href="https://ingenieria.campus.mdp.edu.ar/mod/data/view.php?d=15&amp;advanced=0&amp;paging&amp;page=2" class="page-link">
                        <span aria-hidden="true">3</span>
                        <span class="sr-only">Página 3</span>
                    </a>
                </li>
                <li class="page-item " data-page-number="4">
                    <a href="https://ingenieria.campus.mdp.edu.ar/mod/data/view.php?d=15&amp;advanced=0&amp;paging&amp;page=3" class="page-link">
                        <span aria-hidden="true">4</span>
                        <span class="sr-only">Página 4</span>
                    </a>
                </li>
                <li class="page-item " data-page-number="5">
                    <a href="https://ingenieria.campus.mdp.edu.ar/mod/data/view.php?d=15&amp;advanced=0&amp;paging&amp;page=4" class="page-link">
                        <span aria-hidden="true">5</span>
                        <span class="sr-only">Página 5</span>
                    </a>
                </li>
                <li class="page-item " data-page-number="6">
                    <a href="https://ingenieria.campus.mdp.edu.ar/mod/data/view.php?d=15&amp;advanced=0&amp;paging&amp;page=5" class="page-link">
                        <span aria-hidden="true">6</span>
                        <span class="sr-only">Página 6</span>
                    </a>
                </li>
                <li class="page-item " data-page-number="7">
                    <a href="https://ingenieria.campus.mdp.edu.ar/mod/data/view.php?d=15&amp;advanced=0&amp;paging&amp;page=6" class="page-link">
                        <span aria-hidden="true">7</span>
                        <span class="sr-only">Página 7</span>
                    </a>
                </li>
                <li class="page-item" data-page-number="2">
                    <a href="https://ingenieria.campus.mdp.edu.ar/mod/data/view.php?d=15&amp;advanced=0&amp;paging&amp;page=1" class="page-link">
                        <span aria-hidden="true">»</span>
                        <span class="sr-only">Siguiente página</span>
                    </a>
                </li>
        </ul>
    </nav>
</div>
<div class="navitem">
        <a href="https://ingenieria.campus.mdp.edu.ar/mod/data/edit.php?id=54783&amp;backto=https%3A%2F%2Fingenieria.campus.mdp.edu.ar%2Fmod%2Fdata%2Fview.php%3Fd%3D15%26amp%3Badvanced%3D0%26amp%3Bpaging%26amp%3Bpage%3D0" id="action_link6a2b0d8e01333183" class="btn btn-primary mx-1" role="button">Añadir entrada</a>
</div>
        </div>
    </div>
</div>
```

## Rechazar entradas

### Html del boton rechazar con Href

(Nose si es suficiente de todos modos)

```
<div class="dropdown-menu menu dropdown-menu-right show" id="action-menu-6-menu" data-rel="menu-content" aria-labelledby="action-menu-toggle-6" role="menu" x-placement="bottom-end" style="position: absolute; transform: translate3d(-116px, 36px, 0px); top: 0px; left: 0px; will-change: transform;">
                                                                <a href="https://ingenieria.campus.mdp.edu.ar/mod/data/view.php?d=15&amp;advanced=0&amp;paging&amp;page=0&amp;rid=89&amp;filter=1" class="dropdown-item menu-action" role="menuitem" tabindex="-1">
                                <span class="menu-action-text">Mostrar más</span>
                        </a>
                                                                <a href="https://ingenieria.campus.mdp.edu.ar/mod/data/edit.php?d=15&amp;advanced=0&amp;paging&amp;page=0&amp;rid=89&amp;sesskey=bN4VoosUA9&amp;backto=https%253A%252F%252Fingenieria.campus.mdp.edu.ar%252Fmod%252Fdata%252Fview.php%253Fd%253D15%2526advanced%253D0%2526paging%2526page%253D0%2526rid%253D89%2526mode%253Dsingle" class="dropdown-item menu-action" role="menuitem" tabindex="-1">
                                <span class="menu-action-text">Editar</span>
                        </a>
                                                                <a href="https://ingenieria.campus.mdp.edu.ar/mod/data/view.php?d=15&amp;advanced=0&amp;paging&amp;page=0&amp;delete=89&amp;sesskey=bN4VoosUA9&amp;mode=single" class="dropdown-item menu-action" role="menuitem" tabindex="-1">
                                <span class="menu-action-text">Borrar</span>
                        </a>
                                                                <a href="https://ingenieria.campus.mdp.edu.ar/mod/data/view.php?d=15&amp;advanced=0&amp;paging&amp;page=0&amp;approve=89&amp;sesskey=bN4VoosUA9" class="dropdown-item menu-action" role="menuitem" tabindex="-1">
                                <span class="menu-action-text">Aprobar</span>
                        </a>
                            </div>
```

## Encuesta Inicial

### HTML VISTA (Para scraping)

```
<tbody><tr class="" id="feedback-showentry-list-391_r0"><td class="cell c0 userpic" id="feedback-showentry-list-391_r0_c0"><a href="https://ingenieria.campus.mdp.edu.ar/user/view.php?id=2539&amp;course=1732" class="d-inline-block aabtn"><span class="userinitials size-35" title="GIAN LUCA ARRIGONI CARRARA" aria-label="GIAN LUCA ARRIGONI CARRARA" role="img">GA</span></a></td><td class="cell c1 fullname" id="feedback-showentry-list-391_r0_c1"><a href="https://ingenieria.campus.mdp.edu.ar/user/view.php?id=2539&amp;course=1732">GIAN LUCA ARRIGONI CARRARA</a></td><td class="cell c2 groups" id="feedback-showentry-list-391_r0_c2">2026-Glass Group</td><td class="cell c3 completed_timemodified" id="feedback-showentry-list-391_r0_c3"><a href="https://ingenieria.campus.mdp.edu.ar/mod/feedback/show_entries.php?id=54062&amp;userid=2539&amp;showcompleted=3245">viernes, 22 de mayo de 2026, 18:39</a></td><td class="cell c4 val4171" id="feedback-showentry-list-391_r0_c4"></td><td class="cell c5 val4172" id="feedback-showentry-list-391_r0_c5"></td><td class="cell c6 val4173" id="feedback-showentry-list-391_r0_c6"></td><td class="cell c7 val4219" id="feedback-showentry-list-391_r0_c7"></td><td class="cell c8 val4225" id="feedback-showentry-list-391_r0_c8"></td><td class="cell c9 val4022" id="feedback-showentry-list-391_r0_c9">Si</td><td class="cell c10 val4097" id="feedback-showentry-list-391_r0_c10"></td><td class="cell c11 val5147" id="feedback-showentry-list-391_r0_c11"></td><td class="cell c12 val4023" id="feedback-showentry-list-391_r0_c12">Terciario - Universitario completo</td><td class="cell c13 val4112" id="feedback-showentry-list-391_r0_c13">No</td><td class="cell c14 deleteentry" id="feedback-showentry-list-391_r0_c14"><a href="https://ingenieria.campus.mdp.edu.ar/mod/feedback/show_entries.php?id=54062&amp;delete=3245&amp;sesskey=bN4VoosUA9" id="action_link6a2b24f13581b143" class="action-icon"><i class="icon fa fa-trash fa-fw" title="Borrar entrada" role="img" aria-label="Borrar entrada"></i></a></td></tr><tr class="" id="feedback-showentry-list-391_r1"><td class="cell c0 userpic" id="feedback-showentry-list-391_r1_c0"><a href="https://ingenieria.campus.mdp.edu.ar/user/view.php?id=2987&amp;course=1732" class="d-inline-block aabtn"><img src="https://ingenieria.campus.mdp.edu.ar/pluginfile.php/36551/user/icon/adaptable/f2?rev=890264" class="userpicture" width="35" height="35" alt="MARTIN ESTEBAN GIRAU" title="MARTIN ESTEBAN GIRAU"></a></td><td class="cell c1 fullname" id="feedback-showentry-list-391_r1_c1"><a href="https://ingenieria.campus.mdp.edu.ar/user/view.php?id=2987&amp;course=1732">MARTIN ESTEBAN GIRAU</a></td><td class="cell c2 groups" id="feedback-showentry-list-391_r1_c2">2026-Glass Group</td><td class="cell c3 completed_timemodified" id="feedback-showentry-list-391_r1_c3"><a href="https://ingenieria.campus.mdp.edu.ar/mod/feedback/show_entries.php?id=54062&amp;userid=2987&amp;showcompleted=3286">jueves, 11 de junio de 2026, 13:48</a></td><td class="cell c4 val4171" id="feedback-showentry-list-391_r1_c4">2004</td><td class="cell c5 val4172" id="feedback-showentry-list-391_r1_c5">6</td><td class="cell c6 val4173" id="feedback-showentry-list-391_r1_c6">17</td><td class="cell c7 val4219" id="feedback-showentry-list-391_r1_c7">2023</td><td class="cell c8 val4225" id="feedback-showentry-list-391_r1_c8">Masculino</td><td class="cell c9 val4022" id="feedback-showentry-list-391_r1_c9">Si</td><td class="cell c10 val4097" id="feedback-showentry-list-391_r1_c10"></td><td class="cell c11 val5147" id="feedback-showentry-list-391_r1_c11"></td><td class="cell c12 val4023" id="feedback-showentry-list-391_r1_c12">No posee</td><td class="cell c13 val4112" id="feedback-showentry-list-391_r1_c13">Sí</td><td class="cell c14 deleteentry" id="feedback-showentry-list-391_r1_c14"><a href="https://ingenieria.campus.mdp.edu.ar/mod/feedback/show_entries.php?id=54062&amp;delete=3286&amp;sesskey=bN4VoosUA9" id="action_link6a2b24f13581b144" class="action-icon"><i class="icon fa fa-trash fa-fw" title="Borrar entrada" role="img" aria-label="Borrar entrada"></i></a></td></tr><tr class="" id="feedback-showentry-list-391_r2"><td class="cell c0 userpic" id="feedback-showentry-list-391_r2_c0"><a href="https://ingenieria.campus.mdp.edu.ar/user/view.php?id=3571&amp;course=1732" class="d-inline-block aabtn"><img src="https://ingenieria.campus.mdp.edu.ar/pluginfile.php/37135/user/icon/adaptable/f2?rev=465869" class="userpicture" width="35" height="35" alt="MAURO GABRIEL SCARDAMAGLIA GALBUSERA" title="MAURO GABRIEL SCARDAMAGLIA GALBUSERA"></a></td><td class="cell c1 fullname" id="feedback-showentry-list-391_r2_c1"><a href="https://ingenieria.campus.mdp.edu.ar/user/view.php?id=3571&amp;course=1732">MAURO GABRIEL SCARDAMAGLIA GALBUSERA</a></td><td class="cell c2 groups" id="feedback-showentry-list-391_r2_c2">2026-Glass Group</td><td class="cell c3 completed_timemodified" id="feedback-showentry-list-391_r2_c3"><a href="https://ingenieria.campus.mdp.edu.ar/mod/feedback/show_entries.php?id=54062&amp;userid=3571&amp;showcompleted=3242">lunes, 25 de mayo de 2026, 18:49</a></td><td class="cell c4 val4171" id="feedback-showentry-list-391_r2_c4">2025</td><td class="cell c5 val4172" id="feedback-showentry-list-391_r2_c5">10</td><td class="cell c6 val4173" id="feedback-showentry-list-391_r2_c6">10</td><td class="cell c7 val4219" id="feedback-showentry-list-391_r2_c7"></td><td class="cell c8 val4225" id="feedback-showentry-list-391_r2_c8"></td><td class="cell c9 val4022" id="feedback-showentry-list-391_r2_c9">Si</td><td class="cell c10 val4097" id="feedback-showentry-list-391_r2_c10"></td><td class="cell c11 val5147" id="feedback-showentry-list-391_r2_c11"></td><td class="cell c12 val4023" id="feedback-showentry-list-391_r2_c12">Primario completo</td><td class="cell c13 val4112" id="feedback-showentry-list-391_r2_c13">Sí</td><td class="cell c14 deleteentry" id="feedback-showentry-list-391_r2_c14"><a href="https://ingenieria.campus.mdp.edu.ar/mod/feedback/show_entries.php?id=54062&amp;delete=3242&amp;sesskey=bN4VoosUA9" id="action_link6a2b24f13581b145" class="action-icon"><i class="icon fa fa-trash fa-fw" title="Borrar entrada" role="img" aria-label="Borrar entrada"></i></a></td></tr><tr class="" id="feedback-showentry-list-391_r3"><td class="cell c0 userpic" id="feedback-showentry-list-391_r3_c0"><a href="https://ingenieria.campus.mdp.edu.ar/user/view.php?id=3641&amp;course=1732" class="d-inline-block aabtn"><img src="https://ingenieria.campus.mdp.edu.ar/pluginfile.php/37205/user/icon/adaptable/f2?rev=891185" class="userpicture" width="35" height="35" alt="SANTIAGO SULCA" title="SANTIAGO SULCA"></a></td><td class="cell c1 fullname" id="feedback-showentry-list-391_r3_c1"><a href="https://ingenieria.campus.mdp.edu.ar/user/view.php?id=3641&amp;course=1732">SANTIAGO SULCA</a></td><td class="cell c2 groups" id="feedback-showentry-list-391_r3_c2">2026-Glass Group</td><td class="cell c3 completed_timemodified" id="feedback-showentry-list-391_r3_c3"><a href="https://ingenieria.campus.mdp.edu.ar/mod/feedback/show_entries.php?id=54062&amp;userid=3641&amp;showcompleted=3287">jueves, 11 de junio de 2026, 17:45</a></td><td class="cell c4 val4171" id="feedback-showentry-list-391_r3_c4">2003</td><td class="cell c5 val4172" id="feedback-showentry-list-391_r3_c5">10</td><td class="cell c6 val4173" id="feedback-showentry-list-391_r3_c6">20</td><td class="cell c7 val4219" id="feedback-showentry-list-391_r3_c7">2027</td><td class="cell c8 val4225" id="feedback-showentry-list-391_r3_c8">Masculino</td><td class="cell c9 val4022" id="feedback-showentry-list-391_r3_c9">Si</td><td class="cell c10 val4097" id="feedback-showentry-list-391_r3_c10"></td><td class="cell c11 val5147" id="feedback-showentry-list-391_r3_c11"></td><td class="cell c12 val4023" id="feedback-showentry-list-391_r3_c12">No posee</td><td class="cell c13 val4112" id="feedback-showentry-list-391_r3_c13">Sí</td><td class="cell c14 deleteentry" id="feedback-showentry-list-391_r3_c14"><a href="https://ingenieria.campus.mdp.edu.ar/mod/feedback/show_entries.php?id=54062&amp;delete=3287&amp;sesskey=bN4VoosUA9" id="action_link6a2b24f13581b146" class="action-icon"><i class="icon fa fa-trash fa-fw" title="Borrar entrada" role="img" aria-label="Borrar entrada"></i></a></td></tr><tr class="emptyrow" id="feedback-showentry-list-391_r4"><td class="cell c0 userpic" id="feedback-showentry-list-391_r4_c0"></td><td class="cell c1 fullname" id="feedback-showentry-list-391_r4_c1"></td><td class="cell c2 groups" id="feedback-showentry-list-391_r4_c2"></td><td class="cell c3 completed_timemodified" id="feedback-showentry-list-391_r4_c3"></td><td class="cell c4 val4171" id="feedback-showentry-list-391_r4_c4"></td><td class="cell c5 val4172" id="feedback-showentry-list-391_r4_c5"></td><td class="cell c6 val4173" id="feedback-showentry-list-391_r4_c6"></td><td class="cell c7 val4219" id="feedback-showentry-list-391_r4_c7"></td><td class="cell c8 val4225" id="feedback-showentry-list-391_r4_c8"></td><td class="cell c9 val4022" id="feedback-showentry-list-391_r4_c9"></td><td class="cell c10 val4097" id="feedback-showentry-list-391_r4_c10"></td><td class="cell c11 val5147" id="feedback-showentry-list-391_r4_c11"></td><td class="cell c12 val4023" id="feedback-showentry-list-391_r4_c12"></td><td class="cell c13 val4112" id="feedback-showentry-list-391_r4_c13"></td><td class="cell c14 deleteentry" id="feedback-showentry-list-391_r4_c14"></td></tr><tr class="emptyrow" id="feedback-showentry-list-391_r5"><td class="cell c0 userpic" id="feedback-showentry-list-391_r5_c0"></td><td class="cell c1 fullname" id="feedback-showentry-list-391_r5_c1"></td><td class="cell c2 groups" id="feedback-showentry-list-391_r5_c2"></td><td class="cell c3 completed_timemodified" id="feedback-showentry-list-391_r5_c3"></td><td class="cell c4 val4171" id="feedback-showentry-list-391_r5_c4"></td><td class="cell c5 val4172" id="feedback-showentry-list-391_r5_c5"></td><td class="cell c6 val4173" id="feedback-showentry-list-391_r5_c6"></td><td class="cell c7 val4219" id="feedback-showentry-list-391_r5_c7"></td><td class="cell c8 val4225" id="feedback-showentry-list-391_r5_c8"></td><td class="cell c9 val4022" id="feedback-showentry-list-391_r5_c9"></td><td class="cell c10 val4097" id="feedback-showentry-list-391_r5_c10"></td><td class="cell c11 val5147" id="feedback-showentry-list-391_r5_c11"></td><td class="cell c12 val4023" id="feedback-showentry-list-391_r5_c12"></td><td class="cell c13 val4112" id="feedback-showentry-list-391_r5_c13"></td><td class="cell c14 deleteentry" id="feedback-showentry-list-391_r5_c14"></td></tr><tr class="emptyrow" id="feedback-showentry-list-391_r6"><td class="cell c0 userpic" id="feedback-showentry-list-391_r6_c0"></td><td class="cell c1 fullname" id="feedback-showentry-list-391_r6_c1"></td><td class="cell c2 groups" id="feedback-showentry-list-391_r6_c2"></td><td class="cell c3 completed_timemodified" id="feedback-showentry-list-391_r6_c3"></td><td class="cell c4 val4171" id="feedback-showentry-list-391_r6_c4"></td><td class="cell c5 val4172" id="feedback-showentry-list-391_r6_c5"></td><td class="cell c6 val4173" id="feedback-showentry-list-391_r6_c6"></td><td class="cell c7 val4219" id="feedback-showentry-list-391_r6_c7"></td><td class="cell c8 val4225" id="feedback-showentry-list-391_r6_c8"></td><td class="cell c9 val4022" id="feedback-showentry-list-391_r6_c9"></td><td class="cell c10 val4097" id="feedback-showentry-list-391_r6_c10"></td><td class="cell c11 val5147" id="feedback-showentry-list-391_r6_c11"></td><td class="cell c12 val4023" id="feedback-showentry-list-391_r6_c12"></td><td class="cell c13 val4112" id="feedback-showentry-list-391_r6_c13"></td><td class="cell c14 deleteentry" id="feedback-showentry-list-391_r6_c14"></td></tr><tr class="emptyrow" id="feedback-showentry-list-391_r7"><td class="cell c0 userpic" id="feedback-showentry-list-391_r7_c0"></td><td class="cell c1 fullname" id="feedback-showentry-list-391_r7_c1"></td><td class="cell c2 groups" id="feedback-showentry-list-391_r7_c2"></td><td class="cell c3 completed_timemodified" id="feedback-showentry-list-391_r7_c3"></td><td class="cell c4 val4171" id="feedback-showentry-list-391_r7_c4"></td><td class="cell c5 val4172" id="feedback-showentry-list-391_r7_c5"></td><td class="cell c6 val4173" id="feedback-showentry-list-391_r7_c6"></td><td class="cell c7 val4219" id="feedback-showentry-list-391_r7_c7"></td><td class="cell c8 val4225" id="feedback-showentry-list-391_r7_c8"></td><td class="cell c9 val4022" id="feedback-showentry-list-391_r7_c9"></td><td class="cell c10 val4097" id="feedback-showentry-list-391_r7_c10"></td><td class="cell c11 val5147" id="feedback-showentry-list-391_r7_c11"></td><td class="cell c12 val4023" id="feedback-showentry-list-391_r7_c12"></td><td class="cell c13 val4112" id="feedback-showentry-list-391_r7_c13"></td><td class="cell c14 deleteentry" id="feedback-showentry-list-391_r7_c14"></td></tr><tr class="emptyrow" id="feedback-showentry-list-391_r8"><td class="cell c0 userpic" id="feedback-showentry-list-391_r8_c0"></td><td class="cell c1 fullname" id="feedback-showentry-list-391_r8_c1"></td><td class="cell c2 groups" id="feedback-showentry-list-391_r8_c2"></td><td class="cell c3 completed_timemodified" id="feedback-showentry-list-391_r8_c3"></td><td class="cell c4 val4171" id="feedback-showentry-list-391_r8_c4"></td><td class="cell c5 val4172" id="feedback-showentry-list-391_r8_c5"></td><td class="cell c6 val4173" id="feedback-showentry-list-391_r8_c6"></td><td class="cell c7 val4219" id="feedback-showentry-list-391_r8_c7"></td><td class="cell c8 val4225" id="feedback-showentry-list-391_r8_c8"></td><td class="cell c9 val4022" id="feedback-showentry-list-391_r8_c9"></td><td class="cell c10 val4097" id="feedback-showentry-list-391_r8_c10"></td><td class="cell c11 val5147" id="feedback-showentry-list-391_r8_c11"></td><td class="cell c12 val4023" id="feedback-showentry-list-391_r8_c12"></td><td class="cell c13 val4112" id="feedback-showentry-list-391_r8_c13"></td><td class="cell c14 deleteentry" id="feedback-showentry-list-391_r8_c14"></td></tr><tr class="emptyrow" id="feedback-showentry-list-391_r9"><td class="cell c0 userpic" id="feedback-showentry-list-391_r9_c0"></td><td class="cell c1 fullname" id="feedback-showentry-list-391_r9_c1"></td><td class="cell c2 groups" id="feedback-showentry-list-391_r9_c2"></td><td class="cell c3 completed_timemodified" id="feedback-showentry-list-391_r9_c3"></td><td class="cell c4 val4171" id="feedback-showentry-list-391_r9_c4"></td><td class="cell c5 val4172" id="feedback-showentry-list-391_r9_c5"></td><td class="cell c6 val4173" id="feedback-showentry-list-391_r9_c6"></td><td class="cell c7 val4219" id="feedback-showentry-list-391_r9_c7"></td><td class="cell c8 val4225" id="feedback-showentry-list-391_r9_c8"></td><td class="cell c9 val4022" id="feedback-showentry-list-391_r9_c9"></td><td class="cell c10 val4097" id="feedback-showentry-list-391_r9_c10"></td><td class="cell c11 val5147" id="feedback-showentry-list-391_r9_c11"></td><td class="cell c12 val4023" id="feedback-showentry-list-391_r9_c12"></td><td class="cell c13 val4112" id="feedback-showentry-list-391_r9_c13"></td><td class="cell c14 deleteentry" id="feedback-showentry-list-391_r9_c14"></td></tr><tr class="emptyrow" id="feedback-showentry-list-391_r10"><td class="cell c0 userpic" id="feedback-showentry-list-391_r10_c0"></td><td class="cell c1 fullname" id="feedback-showentry-list-391_r10_c1"></td><td class="cell c2 groups" id="feedback-showentry-list-391_r10_c2"></td><td class="cell c3 completed_timemodified" id="feedback-showentry-list-391_r10_c3"></td><td class="cell c4 val4171" id="feedback-showentry-list-391_r10_c4"></td><td class="cell c5 val4172" id="feedback-showentry-list-391_r10_c5"></td><td class="cell c6 val4173" id="feedback-showentry-list-391_r10_c6"></td><td class="cell c7 val4219" id="feedback-showentry-list-391_r10_c7"></td><td class="cell c8 val4225" id="feedback-showentry-list-391_r10_c8"></td><td class="cell c9 val4022" id="feedback-showentry-list-391_r10_c9"></td><td class="cell c10 val4097" id="feedback-showentry-list-391_r10_c10"></td><td class="cell c11 val5147" id="feedback-showentry-list-391_r10_c11"></td><td class="cell c12 val4023" id="feedback-showentry-list-391_r10_c12"></td><td class="cell c13 val4112" id="feedback-showentry-list-391_r10_c13"></td><td class="cell c14 deleteentry" id="feedback-showentry-list-391_r10_c14"></td></tr><tr class="emptyrow" id="feedback-showentry-list-391_r11"><td class="cell c0 userpic" id="feedback-showentry-list-391_r11_c0"></td><td class="cell c1 fullname" id="feedback-showentry-list-391_r11_c1"></td><td class="cell c2 groups" id="feedback-showentry-list-391_r11_c2"></td><td class="cell c3 completed_timemodified" id="feedback-showentry-list-391_r11_c3"></td><td class="cell c4 val4171" id="feedback-showentry-list-391_r11_c4"></td><td class="cell c5 val4172" id="feedback-showentry-list-391_r11_c5"></td><td class="cell c6 val4173" id="feedback-showentry-list-391_r11_c6"></td><td class="cell c7 val4219" id="feedback-showentry-list-391_r11_c7"></td><td class="cell c8 val4225" id="feedback-showentry-list-391_r11_c8"></td><td class="cell c9 val4022" id="feedback-showentry-list-391_r11_c9"></td><td class="cell c10 val4097" id="feedback-showentry-list-391_r11_c10"></td><td class="cell c11 val5147" id="feedback-showentry-list-391_r11_c11"></td><td class="cell c12 val4023" id="feedback-showentry-list-391_r11_c12"></td><td class="cell c13 val4112" id="feedback-showentry-list-391_r11_c13"></td><td class="cell c14 deleteentry" id="feedback-showentry-list-391_r11_c14"></td></tr><tr class="emptyrow" id="feedback-showentry-list-391_r12"><td class="cell c0 userpic" id="feedback-showentry-list-391_r12_c0"></td><td class="cell c1 fullname" id="feedback-showentry-list-391_r12_c1"></td><td class="cell c2 groups" id="feedback-showentry-list-391_r12_c2"></td><td class="cell c3 completed_timemodified" id="feedback-showentry-list-391_r12_c3"></td><td class="cell c4 val4171" id="feedback-showentry-list-391_r12_c4"></td><td class="cell c5 val4172" id="feedback-showentry-list-391_r12_c5"></td><td class="cell c6 val4173" id="feedback-showentry-list-391_r12_c6"></td><td class="cell c7 val4219" id="feedback-showentry-list-391_r12_c7"></td><td class="cell c8 val4225" id="feedback-showentry-list-391_r12_c8"></td><td class="cell c9 val4022" id="feedback-showentry-list-391_r12_c9"></td><td class="cell c10 val4097" id="feedback-showentry-list-391_r12_c10"></td><td class="cell c11 val5147" id="feedback-showentry-list-391_r12_c11"></td><td class="cell c12 val4023" id="feedback-showentry-list-391_r12_c12"></td><td class="cell c13 val4112" id="feedback-showentry-list-391_r12_c13"></td><td class="cell c14 deleteentry" id="feedback-showentry-list-391_r12_c14"></td></tr><tr class="emptyrow" id="feedback-showentry-list-391_r13"><td class="cell c0 userpic" id="feedback-showentry-list-391_r13_c0"></td><td class="cell c1 fullname" id="feedback-showentry-list-391_r13_c1"></td><td class="cell c2 groups" id="feedback-showentry-list-391_r13_c2"></td><td class="cell c3 completed_timemodified" id="feedback-showentry-list-391_r13_c3"></td><td class="cell c4 val4171" id="feedback-showentry-list-391_r13_c4"></td><td class="cell c5 val4172" id="feedback-showentry-list-391_r13_c5"></td><td class="cell c6 val4173" id="feedback-showentry-list-391_r13_c6"></td><td class="cell c7 val4219" id="feedback-showentry-list-391_r13_c7"></td><td class="cell c8 val4225" id="feedback-showentry-list-391_r13_c8"></td><td class="cell c9 val4022" id="feedback-showentry-list-391_r13_c9"></td><td class="cell c10 val4097" id="feedback-showentry-list-391_r13_c10"></td><td class="cell c11 val5147" id="feedback-showentry-list-391_r13_c11"></td><td class="cell c12 val4023" id="feedback-showentry-list-391_r13_c12"></td><td class="cell c13 val4112" id="feedback-showentry-list-391_r13_c13"></td><td class="cell c14 deleteentry" id="feedback-showentry-list-391_r13_c14"></td></tr><tr class="emptyrow" id="feedback-showentry-list-391_r14"><td class="cell c0 userpic" id="feedback-showentry-list-391_r14_c0"></td><td class="cell c1 fullname" id="feedback-showentry-list-391_r14_c1"></td><td class="cell c2 groups" id="feedback-showentry-list-391_r14_c2"></td><td class="cell c3 completed_timemodified" id="feedback-showentry-list-391_r14_c3"></td><td class="cell c4 val4171" id="feedback-showentry-list-391_r14_c4"></td><td class="cell c5 val4172" id="feedback-showentry-list-391_r14_c5"></td><td class="cell c6 val4173" id="feedback-showentry-list-391_r14_c6"></td><td class="cell c7 val4219" id="feedback-showentry-list-391_r14_c7"></td><td class="cell c8 val4225" id="feedback-showentry-list-391_r14_c8"></td><td class="cell c9 val4022" id="feedback-showentry-list-391_r14_c9"></td><td class="cell c10 val4097" id="feedback-showentry-list-391_r14_c10"></td><td class="cell c11 val5147" id="feedback-showentry-list-391_r14_c11"></td><td class="cell c12 val4023" id="feedback-showentry-list-391_r14_c12"></td><td class="cell c13 val4112" id="feedback-showentry-list-391_r14_c13"></td><td class="cell c14 deleteentry" id="feedback-showentry-list-391_r14_c14"></td></tr><tr class="emptyrow" id="feedback-showentry-list-391_r15"><td class="cell c0 userpic" id="feedback-showentry-list-391_r15_c0"></td><td class="cell c1 fullname" id="feedback-showentry-list-391_r15_c1"></td><td class="cell c2 groups" id="feedback-showentry-list-391_r15_c2"></td><td class="cell c3 completed_timemodified" id="feedback-showentry-list-391_r15_c3"></td><td class="cell c4 val4171" id="feedback-showentry-list-391_r15_c4"></td><td class="cell c5 val4172" id="feedback-showentry-list-391_r15_c5"></td><td class="cell c6 val4173" id="feedback-showentry-list-391_r15_c6"></td><td class="cell c7 val4219" id="feedback-showentry-list-391_r15_c7"></td><td class="cell c8 val4225" id="feedback-showentry-list-391_r15_c8"></td><td class="cell c9 val4022" id="feedback-showentry-list-391_r15_c9"></td><td class="cell c10 val4097" id="feedback-showentry-list-391_r15_c10"></td><td class="cell c11 val5147" id="feedback-showentry-list-391_r15_c11"></td><td class="cell c12 val4023" id="feedback-showentry-list-391_r15_c12"></td><td class="cell c13 val4112" id="feedback-showentry-list-391_r15_c13"></td><td class="cell c14 deleteentry" id="feedback-showentry-list-391_r15_c14"></td></tr><tr class="emptyrow" id="feedback-showentry-list-391_r16"><td class="cell c0 userpic" id="feedback-showentry-list-391_r16_c0"></td><td class="cell c1 fullname" id="feedback-showentry-list-391_r16_c1"></td><td class="cell c2 groups" id="feedback-showentry-list-391_r16_c2"></td><td class="cell c3 completed_timemodified" id="feedback-showentry-list-391_r16_c3"></td><td class="cell c4 val4171" id="feedback-showentry-list-391_r16_c4"></td><td class="cell c5 val4172" id="feedback-showentry-list-391_r16_c5"></td><td class="cell c6 val4173" id="feedback-showentry-list-391_r16_c6"></td><td class="cell c7 val4219" id="feedback-showentry-list-391_r16_c7"></td><td class="cell c8 val4225" id="feedback-showentry-list-391_r16_c8"></td><td class="cell c9 val4022" id="feedback-showentry-list-391_r16_c9"></td><td class="cell c10 val4097" id="feedback-showentry-list-391_r16_c10"></td><td class="cell c11 val5147" id="feedback-showentry-list-391_r16_c11"></td><td class="cell c12 val4023" id="feedback-showentry-list-391_r16_c12"></td><td class="cell c13 val4112" id="feedback-showentry-list-391_r16_c13"></td><td class="cell c14 deleteentry" id="feedback-showentry-list-391_r16_c14"></td></tr><tr class="emptyrow" id="feedback-showentry-list-391_r17"><td class="cell c0 userpic" id="feedback-showentry-list-391_r17_c0"></td><td class="cell c1 fullname" id="feedback-showentry-list-391_r17_c1"></td><td class="cell c2 groups" id="feedback-showentry-list-391_r17_c2"></td><td class="cell c3 completed_timemodified" id="feedback-showentry-list-391_r17_c3"></td><td class="cell c4 val4171" id="feedback-showentry-list-391_r17_c4"></td><td class="cell c5 val4172" id="feedback-showentry-list-391_r17_c5"></td><td class="cell c6 val4173" id="feedback-showentry-list-391_r17_c6"></td><td class="cell c7 val4219" id="feedback-showentry-list-391_r17_c7"></td><td class="cell c8 val4225" id="feedback-showentry-list-391_r17_c8"></td><td class="cell c9 val4022" id="feedback-showentry-list-391_r17_c9"></td><td class="cell c10 val4097" id="feedback-showentry-list-391_r17_c10"></td><td class="cell c11 val5147" id="feedback-showentry-list-391_r17_c11"></td><td class="cell c12 val4023" id="feedback-showentry-list-391_r17_c12"></td><td class="cell c13 val4112" id="feedback-showentry-list-391_r17_c13"></td><td class="cell c14 deleteentry" id="feedback-showentry-list-391_r17_c14"></td></tr><tr class="emptyrow" id="feedback-showentry-list-391_r18"><td class="cell c0 userpic" id="feedback-showentry-list-391_r18_c0"></td><td class="cell c1 fullname" id="feedback-showentry-list-391_r18_c1"></td><td class="cell c2 groups" id="feedback-showentry-list-391_r18_c2"></td><td class="cell c3 completed_timemodified" id="feedback-showentry-list-391_r18_c3"></td><td class="cell c4 val4171" id="feedback-showentry-list-391_r18_c4"></td><td class="cell c5 val4172" id="feedback-showentry-list-391_r18_c5"></td><td class="cell c6 val4173" id="feedback-showentry-list-391_r18_c6"></td><td class="cell c7 val4219" id="feedback-showentry-list-391_r18_c7"></td><td class="cell c8 val4225" id="feedback-showentry-list-391_r18_c8"></td><td class="cell c9 val4022" id="feedback-showentry-list-391_r18_c9"></td><td class="cell c10 val4097" id="feedback-showentry-list-391_r18_c10"></td><td class="cell c11 val5147" id="feedback-showentry-list-391_r18_c11"></td><td class="cell c12 val4023" id="feedback-showentry-list-391_r18_c12"></td><td class="cell c13 val4112" id="feedback-showentry-list-391_r18_c13"></td><td class="cell c14 deleteentry" id="feedback-showentry-list-391_r18_c14"></td></tr><tr class="emptyrow" id="feedback-showentry-list-391_r19"><td class="cell c0 userpic" id="feedback-showentry-list-391_r19_c0"></td><td class="cell c1 fullname" id="feedback-showentry-list-391_r19_c1"></td><td class="cell c2 groups" id="feedback-showentry-list-391_r19_c2"></td><td class="cell c3 completed_timemodified" id="feedback-showentry-list-391_r19_c3"></td><td class="cell c4 val4171" id="feedback-showentry-list-391_r19_c4"></td><td class="cell c5 val4172" id="feedback-showentry-list-391_r19_c5"></td><td class="cell c6 val4173" id="feedback-showentry-list-391_r19_c6"></td><td class="cell c7 val4219" id="feedback-showentry-list-391_r19_c7"></td><td class="cell c8 val4225" id="feedback-showentry-list-391_r19_c8"></td><td class="cell c9 val4022" id="feedback-showentry-list-391_r19_c9"></td><td class="cell c10 val4097" id="feedback-showentry-list-391_r19_c10"></td><td class="cell c11 val5147" id="feedback-showentry-list-391_r19_c11"></td><td class="cell c12 val4023" id="feedback-showentry-list-391_r19_c12"></td><td class="cell c13 val4112" id="feedback-showentry-list-391_r19_c13"></td><td class="cell c14 deleteentry" id="feedback-showentry-list-391_r19_c14"></td></tr></tbody>
```

### Url para obtener CSV

Codigo ejemplo que contiene la url correcta.

```js
const url = `${BASE_URL}/mod/feedback/show_entries.php?sesskey=${M.cfg.sesskey}&download=csv&id=${CMID_FEEDBACK}`;

const response = await fetch(url, { credentials: "include" });
const csvText = await response.text();
```

id = `54062`

## Encuesta Cuatrimestral

### HTML VISTA (Para scraping)

```
<tbody><tr class="" id="feedback-showentry-list-394_r0"><td class="cell c0 userpic" id="feedback-showentry-list-394_r0_c0"><a href="https://ingenieria.campus.mdp.edu.ar/user/view.php?id=2539&amp;course=1732" class="d-inline-block aabtn"><span class="userinitials size-35" title="GIAN LUCA ARRIGONI CARRARA" aria-label="GIAN LUCA ARRIGONI CARRARA" role="img">GA</span></a></td><td class="cell c1 fullname" id="feedback-showentry-list-394_r0_c1"><a href="https://ingenieria.campus.mdp.edu.ar/user/view.php?id=2539&amp;course=1732">GIAN LUCA ARRIGONI CARRARA</a></td><td class="cell c2 groups" id="feedback-showentry-list-394_r0_c2">2026-Glass Group</td><td class="cell c3 completed_timemodified" id="feedback-showentry-list-394_r0_c3"><a href="https://ingenieria.campus.mdp.edu.ar/mod/feedback/show_entries.php?id=54067&amp;userid=2539&amp;showcompleted=3250">viernes, 22 de mayo de 2026, 18:56</a></td><td class="cell c4 val4094" id="feedback-showentry-list-394_r0_c4">Sí</td><td class="cell c5 val4096" id="feedback-showentry-list-394_r0_c5"></td><td class="cell c6 val4113" id="feedback-showentry-list-394_r0_c6">Si</td><td class="cell c7 val4115" id="feedback-showentry-list-394_r0_c7">No se</td><td class="cell c8 val4109" id="feedback-showentry-list-394_r0_c8">4</td><td class="cell c9 val4116" id="feedback-showentry-list-394_r0_c9">3</td><td class="cell c10 val4117" id="feedback-showentry-list-394_r0_c10">3</td><td class="cell c11 val4891" id="feedback-showentry-list-394_r0_c11"></td><td class="cell c12 val4095" id="feedback-showentry-list-394_r0_c12">3 - Regular</td><td class="cell c13 val4102" id="feedback-showentry-list-394_r0_c13">5 - Estrés elevado</td><td class="cell c14 deleteentry" id="feedback-showentry-list-394_r0_c14"><a href="https://ingenieria.campus.mdp.edu.ar/mod/feedback/show_entries.php?id=54067&amp;delete=3250&amp;sesskey=bN4VoosUA9" id="action_link6a2b2542d9d50143" class="action-icon"><i class="icon fa fa-trash fa-fw" title="Borrar entrada" role="img" aria-label="Borrar entrada"></i></a></td></tr><tr class="" id="feedback-showentry-list-394_r1"><td class="cell c0 userpic" id="feedback-showentry-list-394_r1_c0"><a href="https://ingenieria.campus.mdp.edu.ar/user/view.php?id=2987&amp;course=1732" class="d-inline-block aabtn"><img src="https://ingenieria.campus.mdp.edu.ar/pluginfile.php/36551/user/icon/adaptable/f2?rev=890264" class="userpicture" width="35" height="35" alt="MARTIN ESTEBAN GIRAU" title="MARTIN ESTEBAN GIRAU"></a></td><td class="cell c1 fullname" id="feedback-showentry-list-394_r1_c1"><a href="https://ingenieria.campus.mdp.edu.ar/user/view.php?id=2987&amp;course=1732">MARTIN ESTEBAN GIRAU</a></td><td class="cell c2 groups" id="feedback-showentry-list-394_r1_c2">2026-Glass Group</td><td class="cell c3 completed_timemodified" id="feedback-showentry-list-394_r1_c3"><a href="https://ingenieria.campus.mdp.edu.ar/mod/feedback/show_entries.php?id=54067&amp;userid=2987&amp;showcompleted=3285">jueves, 11 de junio de 2026, 13:41</a></td><td class="cell c4 val4094" id="feedback-showentry-list-394_r1_c4">Sí</td><td class="cell c5 val4096" id="feedback-showentry-list-394_r1_c5">No lo se, siento que vocacion es dedicarme al arte.</td><td class="cell c6 val4113" id="feedback-showentry-list-394_r1_c6">Si</td><td class="cell c7 val4115" id="feedback-showentry-list-394_r1_c7">Mate 1 y otras, porque ninguna tiene arte</td><td class="cell c8 val4109" id="feedback-showentry-list-394_r1_c8">10</td><td class="cell c9 val4116" id="feedback-showentry-list-394_r1_c9">0</td><td class="cell c10 val4117" id="feedback-showentry-list-394_r1_c10">0</td><td class="cell c11 val4891" id="feedback-showentry-list-394_r1_c11">30</td><td class="cell c12 val4095" id="feedback-showentry-list-394_r1_c12">1 - No satisfactorio</td><td class="cell c13 val4102" id="feedback-showentry-list-394_r1_c13">5 - Estrés elevado</td><td class="cell c14 deleteentry" id="feedback-showentry-list-394_r1_c14"><a href="https://ingenieria.campus.mdp.edu.ar/mod/feedback/show_entries.php?id=54067&amp;delete=3285&amp;sesskey=bN4VoosUA9" id="action_link6a2b2542d9d50144" class="action-icon"><i class="icon fa fa-trash fa-fw" title="Borrar entrada" role="img" aria-label="Borrar entrada"></i></a></td></tr><tr class="" id="feedback-showentry-list-394_r2"><td class="cell c0 userpic" id="feedback-showentry-list-394_r2_c0"><a href="https://ingenieria.campus.mdp.edu.ar/user/view.php?id=3571&amp;course=1732" class="d-inline-block aabtn"><img src="https://ingenieria.campus.mdp.edu.ar/pluginfile.php/37135/user/icon/adaptable/f2?rev=465869" class="userpicture" width="35" height="35" alt="MAURO GABRIEL SCARDAMAGLIA GALBUSERA" title="MAURO GABRIEL SCARDAMAGLIA GALBUSERA"></a></td><td class="cell c1 fullname" id="feedback-showentry-list-394_r2_c1"><a href="https://ingenieria.campus.mdp.edu.ar/user/view.php?id=3571&amp;course=1732">MAURO GABRIEL SCARDAMAGLIA GALBUSERA</a></td><td class="cell c2 groups" id="feedback-showentry-list-394_r2_c2">2026-Glass Group</td><td class="cell c3 completed_timemodified" id="feedback-showentry-list-394_r2_c3"><a href="https://ingenieria.campus.mdp.edu.ar/mod/feedback/show_entries.php?id=54067&amp;userid=3571&amp;showcompleted=3249">viernes, 22 de mayo de 2026, 18:47</a></td><td class="cell c4 val4094" id="feedback-showentry-list-394_r2_c4">No</td><td class="cell c5 val4096" id="feedback-showentry-list-394_r2_c5"></td><td class="cell c6 val4113" id="feedback-showentry-list-394_r2_c6">No</td><td class="cell c7 val4115" id="feedback-showentry-list-394_r2_c7"></td><td class="cell c8 val4109" id="feedback-showentry-list-394_r2_c8"></td><td class="cell c9 val4116" id="feedback-showentry-list-394_r2_c9">1</td><td class="cell c10 val4117" id="feedback-showentry-list-394_r2_c10">1</td><td class="cell c11 val4891" id="feedback-showentry-list-394_r2_c11"></td><td class="cell c12 val4095" id="feedback-showentry-list-394_r2_c12">5 - Muy satisfactorio</td><td class="cell c13 val4102" id="feedback-showentry-list-394_r2_c13">4 - Estrés considerable</td><td class="cell c14 deleteentry" id="feedback-showentry-list-394_r2_c14"><a href="https://ingenieria.campus.mdp.edu.ar/mod/feedback/show_entries.php?id=54067&amp;delete=3249&amp;sesskey=bN4VoosUA9" id="action_link6a2b2542d9d50145" class="action-icon"><i class="icon fa fa-trash fa-fw" title="Borrar entrada" role="img" aria-label="Borrar entrada"></i></a></td></tr><tr class="" id="feedback-showentry-list-394_r3"><td class="cell c0 userpic" id="feedback-showentry-list-394_r3_c0"><a href="https://ingenieria.campus.mdp.edu.ar/user/view.php?id=3641&amp;course=1732" class="d-inline-block aabtn"><img src="https://ingenieria.campus.mdp.edu.ar/pluginfile.php/37205/user/icon/adaptable/f2?rev=891185" class="userpicture" width="35" height="35" alt="SANTIAGO SULCA" title="SANTIAGO SULCA"></a></td><td class="cell c1 fullname" id="feedback-showentry-list-394_r3_c1"><a href="https://ingenieria.campus.mdp.edu.ar/user/view.php?id=3641&amp;course=1732">SANTIAGO SULCA</a></td><td class="cell c2 groups" id="feedback-showentry-list-394_r3_c2">2026-Glass Group</td><td class="cell c3 completed_timemodified" id="feedback-showentry-list-394_r3_c3"><a href="https://ingenieria.campus.mdp.edu.ar/mod/feedback/show_entries.php?id=54067&amp;userid=3641&amp;showcompleted=3288">jueves, 11 de junio de 2026, 17:51</a></td><td class="cell c4 val4094" id="feedback-showentry-list-394_r3_c4">No</td><td class="cell c5 val4096" id="feedback-showentry-list-394_r3_c5"></td><td class="cell c6 val4113" id="feedback-showentry-list-394_r3_c6">Si</td><td class="cell c7 val4115" id="feedback-showentry-list-394_r3_c7">algebra i - laburaba y matrices me re cuesta
informatica basica - no me corria el scratch en la compu</td><td class="cell c8 val4109" id="feedback-showentry-list-394_r3_c8">4</td><td class="cell c9 val4116" id="feedback-showentry-list-394_r3_c9">0</td><td class="cell c10 val4117" id="feedback-showentry-list-394_r3_c10">1</td><td class="cell c11 val4891" id="feedback-showentry-list-394_r3_c11">2</td><td class="cell c12 val4095" id="feedback-showentry-list-394_r3_c12">1 - No satisfactorio</td><td class="cell c13 val4102" id="feedback-showentry-list-394_r3_c13">5 - Estrés elevado</td><td class="cell c14 deleteentry" id="feedback-showentry-list-394_r3_c14"><a href="https://ingenieria.campus.mdp.edu.ar/mod/feedback/show_entries.php?id=54067&amp;delete=3288&amp;sesskey=bN4VoosUA9" id="action_link6a2b2542d9d50146" class="action-icon"><i class="icon fa fa-trash fa-fw" title="Borrar entrada" role="img" aria-label="Borrar entrada"></i></a></td></tr><tr class="emptyrow" id="feedback-showentry-list-394_r4"><td class="cell c0 userpic" id="feedback-showentry-list-394_r4_c0"></td><td class="cell c1 fullname" id="feedback-showentry-list-394_r4_c1"></td><td class="cell c2 groups" id="feedback-showentry-list-394_r4_c2"></td><td class="cell c3 completed_timemodified" id="feedback-showentry-list-394_r4_c3"></td><td class="cell c4 val4094" id="feedback-showentry-list-394_r4_c4"></td><td class="cell c5 val4096" id="feedback-showentry-list-394_r4_c5"></td><td class="cell c6 val4113" id="feedback-showentry-list-394_r4_c6"></td><td class="cell c7 val4115" id="feedback-showentry-list-394_r4_c7"></td><td class="cell c8 val4109" id="feedback-showentry-list-394_r4_c8"></td><td class="cell c9 val4116" id="feedback-showentry-list-394_r4_c9"></td><td class="cell c10 val4117" id="feedback-showentry-list-394_r4_c10"></td><td class="cell c11 val4891" id="feedback-showentry-list-394_r4_c11"></td><td class="cell c12 val4095" id="feedback-showentry-list-394_r4_c12"></td><td class="cell c13 val4102" id="feedback-showentry-list-394_r4_c13"></td><td class="cell c14 deleteentry" id="feedback-showentry-list-394_r4_c14"></td></tr><tr class="emptyrow" id="feedback-showentry-list-394_r5"><td class="cell c0 userpic" id="feedback-showentry-list-394_r5_c0"></td><td class="cell c1 fullname" id="feedback-showentry-list-394_r5_c1"></td><td class="cell c2 groups" id="feedback-showentry-list-394_r5_c2"></td><td class="cell c3 completed_timemodified" id="feedback-showentry-list-394_r5_c3"></td><td class="cell c4 val4094" id="feedback-showentry-list-394_r5_c4"></td><td class="cell c5 val4096" id="feedback-showentry-list-394_r5_c5"></td><td class="cell c6 val4113" id="feedback-showentry-list-394_r5_c6"></td><td class="cell c7 val4115" id="feedback-showentry-list-394_r5_c7"></td><td class="cell c8 val4109" id="feedback-showentry-list-394_r5_c8"></td><td class="cell c9 val4116" id="feedback-showentry-list-394_r5_c9"></td><td class="cell c10 val4117" id="feedback-showentry-list-394_r5_c10"></td><td class="cell c11 val4891" id="feedback-showentry-list-394_r5_c11"></td><td class="cell c12 val4095" id="feedback-showentry-list-394_r5_c12"></td><td class="cell c13 val4102" id="feedback-showentry-list-394_r5_c13"></td><td class="cell c14 deleteentry" id="feedback-showentry-list-394_r5_c14"></td></tr><tr class="emptyrow" id="feedback-showentry-list-394_r6"><td class="cell c0 userpic" id="feedback-showentry-list-394_r6_c0"></td><td class="cell c1 fullname" id="feedback-showentry-list-394_r6_c1"></td><td class="cell c2 groups" id="feedback-showentry-list-394_r6_c2"></td><td class="cell c3 completed_timemodified" id="feedback-showentry-list-394_r6_c3"></td><td class="cell c4 val4094" id="feedback-showentry-list-394_r6_c4"></td><td class="cell c5 val4096" id="feedback-showentry-list-394_r6_c5"></td><td class="cell c6 val4113" id="feedback-showentry-list-394_r6_c6"></td><td class="cell c7 val4115" id="feedback-showentry-list-394_r6_c7"></td><td class="cell c8 val4109" id="feedback-showentry-list-394_r6_c8"></td><td class="cell c9 val4116" id="feedback-showentry-list-394_r6_c9"></td><td class="cell c10 val4117" id="feedback-showentry-list-394_r6_c10"></td><td class="cell c11 val4891" id="feedback-showentry-list-394_r6_c11"></td><td class="cell c12 val4095" id="feedback-showentry-list-394_r6_c12"></td><td class="cell c13 val4102" id="feedback-showentry-list-394_r6_c13"></td><td class="cell c14 deleteentry" id="feedback-showentry-list-394_r6_c14"></td></tr><tr class="emptyrow" id="feedback-showentry-list-394_r7"><td class="cell c0 userpic" id="feedback-showentry-list-394_r7_c0"></td><td class="cell c1 fullname" id="feedback-showentry-list-394_r7_c1"></td><td class="cell c2 groups" id="feedback-showentry-list-394_r7_c2"></td><td class="cell c3 completed_timemodified" id="feedback-showentry-list-394_r7_c3"></td><td class="cell c4 val4094" id="feedback-showentry-list-394_r7_c4"></td><td class="cell c5 val4096" id="feedback-showentry-list-394_r7_c5"></td><td class="cell c6 val4113" id="feedback-showentry-list-394_r7_c6"></td><td class="cell c7 val4115" id="feedback-showentry-list-394_r7_c7"></td><td class="cell c8 val4109" id="feedback-showentry-list-394_r7_c8"></td><td class="cell c9 val4116" id="feedback-showentry-list-394_r7_c9"></td><td class="cell c10 val4117" id="feedback-showentry-list-394_r7_c10"></td><td class="cell c11 val4891" id="feedback-showentry-list-394_r7_c11"></td><td class="cell c12 val4095" id="feedback-showentry-list-394_r7_c12"></td><td class="cell c13 val4102" id="feedback-showentry-list-394_r7_c13"></td><td class="cell c14 deleteentry" id="feedback-showentry-list-394_r7_c14"></td></tr><tr class="emptyrow" id="feedback-showentry-list-394_r8"><td class="cell c0 userpic" id="feedback-showentry-list-394_r8_c0"></td><td class="cell c1 fullname" id="feedback-showentry-list-394_r8_c1"></td><td class="cell c2 groups" id="feedback-showentry-list-394_r8_c2"></td><td class="cell c3 completed_timemodified" id="feedback-showentry-list-394_r8_c3"></td><td class="cell c4 val4094" id="feedback-showentry-list-394_r8_c4"></td><td class="cell c5 val4096" id="feedback-showentry-list-394_r8_c5"></td><td class="cell c6 val4113" id="feedback-showentry-list-394_r8_c6"></td><td class="cell c7 val4115" id="feedback-showentry-list-394_r8_c7"></td><td class="cell c8 val4109" id="feedback-showentry-list-394_r8_c8"></td><td class="cell c9 val4116" id="feedback-showentry-list-394_r8_c9"></td><td class="cell c10 val4117" id="feedback-showentry-list-394_r8_c10"></td><td class="cell c11 val4891" id="feedback-showentry-list-394_r8_c11"></td><td class="cell c12 val4095" id="feedback-showentry-list-394_r8_c12"></td><td class="cell c13 val4102" id="feedback-showentry-list-394_r8_c13"></td><td class="cell c14 deleteentry" id="feedback-showentry-list-394_r8_c14"></td></tr><tr class="emptyrow" id="feedback-showentry-list-394_r9"><td class="cell c0 userpic" id="feedback-showentry-list-394_r9_c0"></td><td class="cell c1 fullname" id="feedback-showentry-list-394_r9_c1"></td><td class="cell c2 groups" id="feedback-showentry-list-394_r9_c2"></td><td class="cell c3 completed_timemodified" id="feedback-showentry-list-394_r9_c3"></td><td class="cell c4 val4094" id="feedback-showentry-list-394_r9_c4"></td><td class="cell c5 val4096" id="feedback-showentry-list-394_r9_c5"></td><td class="cell c6 val4113" id="feedback-showentry-list-394_r9_c6"></td><td class="cell c7 val4115" id="feedback-showentry-list-394_r9_c7"></td><td class="cell c8 val4109" id="feedback-showentry-list-394_r9_c8"></td><td class="cell c9 val4116" id="feedback-showentry-list-394_r9_c9"></td><td class="cell c10 val4117" id="feedback-showentry-list-394_r9_c10"></td><td class="cell c11 val4891" id="feedback-showentry-list-394_r9_c11"></td><td class="cell c12 val4095" id="feedback-showentry-list-394_r9_c12"></td><td class="cell c13 val4102" id="feedback-showentry-list-394_r9_c13"></td><td class="cell c14 deleteentry" id="feedback-showentry-list-394_r9_c14"></td></tr><tr class="emptyrow" id="feedback-showentry-list-394_r10"><td class="cell c0 userpic" id="feedback-showentry-list-394_r10_c0"></td><td class="cell c1 fullname" id="feedback-showentry-list-394_r10_c1"></td><td class="cell c2 groups" id="feedback-showentry-list-394_r10_c2"></td><td class="cell c3 completed_timemodified" id="feedback-showentry-list-394_r10_c3"></td><td class="cell c4 val4094" id="feedback-showentry-list-394_r10_c4"></td><td class="cell c5 val4096" id="feedback-showentry-list-394_r10_c5"></td><td class="cell c6 val4113" id="feedback-showentry-list-394_r10_c6"></td><td class="cell c7 val4115" id="feedback-showentry-list-394_r10_c7"></td><td class="cell c8 val4109" id="feedback-showentry-list-394_r10_c8"></td><td class="cell c9 val4116" id="feedback-showentry-list-394_r10_c9"></td><td class="cell c10 val4117" id="feedback-showentry-list-394_r10_c10"></td><td class="cell c11 val4891" id="feedback-showentry-list-394_r10_c11"></td><td class="cell c12 val4095" id="feedback-showentry-list-394_r10_c12"></td><td class="cell c13 val4102" id="feedback-showentry-list-394_r10_c13"></td><td class="cell c14 deleteentry" id="feedback-showentry-list-394_r10_c14"></td></tr><tr class="emptyrow" id="feedback-showentry-list-394_r11"><td class="cell c0 userpic" id="feedback-showentry-list-394_r11_c0"></td><td class="cell c1 fullname" id="feedback-showentry-list-394_r11_c1"></td><td class="cell c2 groups" id="feedback-showentry-list-394_r11_c2"></td><td class="cell c3 completed_timemodified" id="feedback-showentry-list-394_r11_c3"></td><td class="cell c4 val4094" id="feedback-showentry-list-394_r11_c4"></td><td class="cell c5 val4096" id="feedback-showentry-list-394_r11_c5"></td><td class="cell c6 val4113" id="feedback-showentry-list-394_r11_c6"></td><td class="cell c7 val4115" id="feedback-showentry-list-394_r11_c7"></td><td class="cell c8 val4109" id="feedback-showentry-list-394_r11_c8"></td><td class="cell c9 val4116" id="feedback-showentry-list-394_r11_c9"></td><td class="cell c10 val4117" id="feedback-showentry-list-394_r11_c10"></td><td class="cell c11 val4891" id="feedback-showentry-list-394_r11_c11"></td><td class="cell c12 val4095" id="feedback-showentry-list-394_r11_c12"></td><td class="cell c13 val4102" id="feedback-showentry-list-394_r11_c13"></td><td class="cell c14 deleteentry" id="feedback-showentry-list-394_r11_c14"></td></tr><tr class="emptyrow" id="feedback-showentry-list-394_r12"><td class="cell c0 userpic" id="feedback-showentry-list-394_r12_c0"></td><td class="cell c1 fullname" id="feedback-showentry-list-394_r12_c1"></td><td class="cell c2 groups" id="feedback-showentry-list-394_r12_c2"></td><td class="cell c3 completed_timemodified" id="feedback-showentry-list-394_r12_c3"></td><td class="cell c4 val4094" id="feedback-showentry-list-394_r12_c4"></td><td class="cell c5 val4096" id="feedback-showentry-list-394_r12_c5"></td><td class="cell c6 val4113" id="feedback-showentry-list-394_r12_c6"></td><td class="cell c7 val4115" id="feedback-showentry-list-394_r12_c7"></td><td class="cell c8 val4109" id="feedback-showentry-list-394_r12_c8"></td><td class="cell c9 val4116" id="feedback-showentry-list-394_r12_c9"></td><td class="cell c10 val4117" id="feedback-showentry-list-394_r12_c10"></td><td class="cell c11 val4891" id="feedback-showentry-list-394_r12_c11"></td><td class="cell c12 val4095" id="feedback-showentry-list-394_r12_c12"></td><td class="cell c13 val4102" id="feedback-showentry-list-394_r12_c13"></td><td class="cell c14 deleteentry" id="feedback-showentry-list-394_r12_c14"></td></tr><tr class="emptyrow" id="feedback-showentry-list-394_r13"><td class="cell c0 userpic" id="feedback-showentry-list-394_r13_c0"></td><td class="cell c1 fullname" id="feedback-showentry-list-394_r13_c1"></td><td class="cell c2 groups" id="feedback-showentry-list-394_r13_c2"></td><td class="cell c3 completed_timemodified" id="feedback-showentry-list-394_r13_c3"></td><td class="cell c4 val4094" id="feedback-showentry-list-394_r13_c4"></td><td class="cell c5 val4096" id="feedback-showentry-list-394_r13_c5"></td><td class="cell c6 val4113" id="feedback-showentry-list-394_r13_c6"></td><td class="cell c7 val4115" id="feedback-showentry-list-394_r13_c7"></td><td class="cell c8 val4109" id="feedback-showentry-list-394_r13_c8"></td><td class="cell c9 val4116" id="feedback-showentry-list-394_r13_c9"></td><td class="cell c10 val4117" id="feedback-showentry-list-394_r13_c10"></td><td class="cell c11 val4891" id="feedback-showentry-list-394_r13_c11"></td><td class="cell c12 val4095" id="feedback-showentry-list-394_r13_c12"></td><td class="cell c13 val4102" id="feedback-showentry-list-394_r13_c13"></td><td class="cell c14 deleteentry" id="feedback-showentry-list-394_r13_c14"></td></tr><tr class="emptyrow" id="feedback-showentry-list-394_r14"><td class="cell c0 userpic" id="feedback-showentry-list-394_r14_c0"></td><td class="cell c1 fullname" id="feedback-showentry-list-394_r14_c1"></td><td class="cell c2 groups" id="feedback-showentry-list-394_r14_c2"></td><td class="cell c3 completed_timemodified" id="feedback-showentry-list-394_r14_c3"></td><td class="cell c4 val4094" id="feedback-showentry-list-394_r14_c4"></td><td class="cell c5 val4096" id="feedback-showentry-list-394_r14_c5"></td><td class="cell c6 val4113" id="feedback-showentry-list-394_r14_c6"></td><td class="cell c7 val4115" id="feedback-showentry-list-394_r14_c7"></td><td class="cell c8 val4109" id="feedback-showentry-list-394_r14_c8"></td><td class="cell c9 val4116" id="feedback-showentry-list-394_r14_c9"></td><td class="cell c10 val4117" id="feedback-showentry-list-394_r14_c10"></td><td class="cell c11 val4891" id="feedback-showentry-list-394_r14_c11"></td><td class="cell c12 val4095" id="feedback-showentry-list-394_r14_c12"></td><td class="cell c13 val4102" id="feedback-showentry-list-394_r14_c13"></td><td class="cell c14 deleteentry" id="feedback-showentry-list-394_r14_c14"></td></tr><tr class="emptyrow" id="feedback-showentry-list-394_r15"><td class="cell c0 userpic" id="feedback-showentry-list-394_r15_c0"></td><td class="cell c1 fullname" id="feedback-showentry-list-394_r15_c1"></td><td class="cell c2 groups" id="feedback-showentry-list-394_r15_c2"></td><td class="cell c3 completed_timemodified" id="feedback-showentry-list-394_r15_c3"></td><td class="cell c4 val4094" id="feedback-showentry-list-394_r15_c4"></td><td class="cell c5 val4096" id="feedback-showentry-list-394_r15_c5"></td><td class="cell c6 val4113" id="feedback-showentry-list-394_r15_c6"></td><td class="cell c7 val4115" id="feedback-showentry-list-394_r15_c7"></td><td class="cell c8 val4109" id="feedback-showentry-list-394_r15_c8"></td><td class="cell c9 val4116" id="feedback-showentry-list-394_r15_c9"></td><td class="cell c10 val4117" id="feedback-showentry-list-394_r15_c10"></td><td class="cell c11 val4891" id="feedback-showentry-list-394_r15_c11"></td><td class="cell c12 val4095" id="feedback-showentry-list-394_r15_c12"></td><td class="cell c13 val4102" id="feedback-showentry-list-394_r15_c13"></td><td class="cell c14 deleteentry" id="feedback-showentry-list-394_r15_c14"></td></tr><tr class="emptyrow" id="feedback-showentry-list-394_r16"><td class="cell c0 userpic" id="feedback-showentry-list-394_r16_c0"></td><td class="cell c1 fullname" id="feedback-showentry-list-394_r16_c1"></td><td class="cell c2 groups" id="feedback-showentry-list-394_r16_c2"></td><td class="cell c3 completed_timemodified" id="feedback-showentry-list-394_r16_c3"></td><td class="cell c4 val4094" id="feedback-showentry-list-394_r16_c4"></td><td class="cell c5 val4096" id="feedback-showentry-list-394_r16_c5"></td><td class="cell c6 val4113" id="feedback-showentry-list-394_r16_c6"></td><td class="cell c7 val4115" id="feedback-showentry-list-394_r16_c7"></td><td class="cell c8 val4109" id="feedback-showentry-list-394_r16_c8"></td><td class="cell c9 val4116" id="feedback-showentry-list-394_r16_c9"></td><td class="cell c10 val4117" id="feedback-showentry-list-394_r16_c10"></td><td class="cell c11 val4891" id="feedback-showentry-list-394_r16_c11"></td><td class="cell c12 val4095" id="feedback-showentry-list-394_r16_c12"></td><td class="cell c13 val4102" id="feedback-showentry-list-394_r16_c13"></td><td class="cell c14 deleteentry" id="feedback-showentry-list-394_r16_c14"></td></tr><tr class="emptyrow" id="feedback-showentry-list-394_r17"><td class="cell c0 userpic" id="feedback-showentry-list-394_r17_c0"></td><td class="cell c1 fullname" id="feedback-showentry-list-394_r17_c1"></td><td class="cell c2 groups" id="feedback-showentry-list-394_r17_c2"></td><td class="cell c3 completed_timemodified" id="feedback-showentry-list-394_r17_c3"></td><td class="cell c4 val4094" id="feedback-showentry-list-394_r17_c4"></td><td class="cell c5 val4096" id="feedback-showentry-list-394_r17_c5"></td><td class="cell c6 val4113" id="feedback-showentry-list-394_r17_c6"></td><td class="cell c7 val4115" id="feedback-showentry-list-394_r17_c7"></td><td class="cell c8 val4109" id="feedback-showentry-list-394_r17_c8"></td><td class="cell c9 val4116" id="feedback-showentry-list-394_r17_c9"></td><td class="cell c10 val4117" id="feedback-showentry-list-394_r17_c10"></td><td class="cell c11 val4891" id="feedback-showentry-list-394_r17_c11"></td><td class="cell c12 val4095" id="feedback-showentry-list-394_r17_c12"></td><td class="cell c13 val4102" id="feedback-showentry-list-394_r17_c13"></td><td class="cell c14 deleteentry" id="feedback-showentry-list-394_r17_c14"></td></tr><tr class="emptyrow" id="feedback-showentry-list-394_r18"><td class="cell c0 userpic" id="feedback-showentry-list-394_r18_c0"></td><td class="cell c1 fullname" id="feedback-showentry-list-394_r18_c1"></td><td class="cell c2 groups" id="feedback-showentry-list-394_r18_c2"></td><td class="cell c3 completed_timemodified" id="feedback-showentry-list-394_r18_c3"></td><td class="cell c4 val4094" id="feedback-showentry-list-394_r18_c4"></td><td class="cell c5 val4096" id="feedback-showentry-list-394_r18_c5"></td><td class="cell c6 val4113" id="feedback-showentry-list-394_r18_c6"></td><td class="cell c7 val4115" id="feedback-showentry-list-394_r18_c7"></td><td class="cell c8 val4109" id="feedback-showentry-list-394_r18_c8"></td><td class="cell c9 val4116" id="feedback-showentry-list-394_r18_c9"></td><td class="cell c10 val4117" id="feedback-showentry-list-394_r18_c10"></td><td class="cell c11 val4891" id="feedback-showentry-list-394_r18_c11"></td><td class="cell c12 val4095" id="feedback-showentry-list-394_r18_c12"></td><td class="cell c13 val4102" id="feedback-showentry-list-394_r18_c13"></td><td class="cell c14 deleteentry" id="feedback-showentry-list-394_r18_c14"></td></tr><tr class="emptyrow" id="feedback-showentry-list-394_r19"><td class="cell c0 userpic" id="feedback-showentry-list-394_r19_c0"></td><td class="cell c1 fullname" id="feedback-showentry-list-394_r19_c1"></td><td class="cell c2 groups" id="feedback-showentry-list-394_r19_c2"></td><td class="cell c3 completed_timemodified" id="feedback-showentry-list-394_r19_c3"></td><td class="cell c4 val4094" id="feedback-showentry-list-394_r19_c4"></td><td class="cell c5 val4096" id="feedback-showentry-list-394_r19_c5"></td><td class="cell c6 val4113" id="feedback-showentry-list-394_r19_c6"></td><td class="cell c7 val4115" id="feedback-showentry-list-394_r19_c7"></td><td class="cell c8 val4109" id="feedback-showentry-list-394_r19_c8"></td><td class="cell c9 val4116" id="feedback-showentry-list-394_r19_c9"></td><td class="cell c10 val4117" id="feedback-showentry-list-394_r19_c10"></td><td class="cell c11 val4891" id="feedback-showentry-list-394_r19_c11"></td><td class="cell c12 val4095" id="feedback-showentry-list-394_r19_c12"></td><td class="cell c13 val4102" id="feedback-showentry-list-394_r19_c13"></td><td class="cell c14 deleteentry" id="feedback-showentry-list-394_r19_c14"></td></tr></tbody>
```

### Url para obtener CSV

Codigo es el mismo que antes, solo cambia id:
id = `54284`

---

# Preguntas y Valores de cada una

## Encuestas

### Encuesta Inicial:

Datos Personales
DNI (Id para conectar con csv de primer año)
Fecha de nacimiento
Año
Mes
Día
Género (Selección única)
Masculino
Femenino
Otros

Datos académicos
Orientación del colegio secundario (β=0.5)
Técnico (X = 0)
Bachiller (X = 0.2)
¿En qué año ingresaste a la carrera? (Primer cuatrimestre cursado)
¿En qué cuatrimestre?
Máximo nivel académico alcanzado por alguno de tus padres/tutores (Selección única).(β = 1)
No posee (X = 0.8)
Primario completo (X = 0.6)
Secundario completo (X = 0.3)
Terciario-Universitario completo (X = 0.1)
¿Es tu primera carrera universitaria dentro de la facultad? (Si / No) (β=0.5)
[SI] (X = 0.3)
¿Qué carrera/s cursaste?
¿Te tomaron materias de la carrera anterior?
[NO] (X = 0)
Datos varios
¿Cuántas personas tenés a cargo? (Numérico) (β=2)
¿Trabaja? (Si / No) (β=1.5)
[Si] ¿Cuántas horas semanales trabaja? (Selección única)  
Menos de 5 hs (X = 0.0)
Entre 6 hs y 20 hs (X = 0.1)
Entre 21 hs y 40 hs (X = 0.25)
Más de 40 hs (X = 0.45)

Situación económica (β = 2)
(1 a 5 - Muy mala /… / Muy buena)
1 (X = 1)
2 (X = 0.5)
3 (X = 0.2)
4 (X = -0.2)
5 (X = -0.5)
¿Con cuánta disponibilidad horaria posees para estudiar? (β=2.5)
(1 a 5 - Muy poco/… /Mucho tiempo)
1 (X = 0.9)
2 (X = 0.7)
3 (X = 0.0)
4 (X = -0.2)
5 (X = -0.5)
¿Cuántos minutos tardas en llegar a la facultad? (β = 1)
Menos de 20 min. (X = 0)
Entre 20 min. y 40 min. (X = 0.08)
Entre 41 min. y 60 min. (X = 0.156)
Más de 60 min. (X = 0.25)
¿Qué medio de transporte utilizas para ir a la facultad? (Selección múltiple) (β=0) (no contribuye al cálculo pero es interesante saberlo)
Caminando
Bicicleta
Colectivo
Uber / Taxi / Remis
Moto / Auto
¿Cómo financiás económicamente tus estudios? (β = 1.8)
Beca (X = -1)
Financiamiento familiar (X = 0)
Financiamiento propio (X = 0.5).
Otros
¿Por qué eligió la carrera? (β = 0.5)
Vocación (X = 0.2)
Salida laboral (X = 0.6)
Recomendación (X = 0.4)
Otro

### Encuesta Cuatrimestral:

Rendimiento
¿Crees que estás en riesgo de abandonar la carrera? (AUTOMÁTICAMENTE ALUMNO EN RIESGO)
[SI] ¿Porque? (Cuadro de texto)
¿Abandonó alguna materia? (Si / No) (β = 2)
[SI] (Depende de cuantas abandono el valor de X)
¿Cuántas y por qué?
¿Cuántas materias dejó este cuatrimestre?
Finales rendidos desde la última encuesta (Numérico)
Finales aprobados (Numérico)
Finales que debe (Númerico)
(En cuanto al valor de β o x se tendrá que observar el promedio, créditos y como va con la carrera se tendría que ver más a fondo)

Experiencias
Rango de satisfacción con respecto al cuatrimestre (β = 1)
(1 a 5 - No satisfactorio /…/ Satisfactorio)
1 (x = 1)
2 (x = 0.5)
3 ( x = 0)
4 (x = -0.5)
5 (x = -1)
Nivel de estrés que sufrió durante el cuatrimestre (β = 1.5)
(1 a 5 - Nada/…/Mucho)
1 (x = 0)
2 (x = 0.2)
3 (x = 0.35)
4 (x = 0.5)
5 (x = 0.7)
¿Qué tan motivado está a seguir la carrera? (β = 2.5)
(1 a 5 - Nada/…/Mucha)
1 (x = 1)
2 (x = 0.5)
3 (x = 0)
4 (x = -0.5)
5 (x = -1)

¿Qué tan al día estás con el plan de estudios? (β = 1.5)
Adelantado (x = -1)
Al día (x = 0)
Atrasado un cuatrimestre (x = 0.25)
Atrasado un año (x = 0.5)
Atrasado más de un año (x = 0.8)

¿Tenes grupos de estudio? (β = 1)
Sí (x = -0.1)
No (x = 0.4)
Cuadro de texto opcional comentarios varios: qué opina del plan de estudio, de algún aspecto particular de la facultad o del cuatrimestre, entre otros.
Plan de Estudios
Por cada materia del estudiante
Nota de la materia
Estado finalizado (Aprobado/Habilitado/Desaprobado)
Opinión sobre la materia y los docentes (Cuadro de texto)
Comentarios acerca del Trabajo Final (sea que lo realizó ya o no)
¿Ha egresado? (Sí/No)

---

# Recordar

1. La config se guarda como un solo texto plano en un formato json para ser leido facilmente.
2. Pedirle a la IA que genere una estructura json comoda para trabajar y que yo mismo añadire la config como una entrada de texto plano a la db de config.
   Esta entrada de texto plano debera tener las configuraciones iniciales para mostrar los indices, asi como el Beta, peso de cada respuesta, cantidad de preguntas, se debera poder añadir preguntas y sus respuestas aqui, de forma no programatica. (Desde la Actividad de Pagina para editar config desde la interfaz)
