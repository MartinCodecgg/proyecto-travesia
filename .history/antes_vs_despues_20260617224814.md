# Antes

          let tutor = "";
          let origen = "";

          const rows = entry.querySelectorAll(".row, div");
          rows.forEach(row => {
            const labelEl = row.querySelector(".font-weight-bold, span");
            if (labelEl) {
              const text = labelEl.textContent.trim().toLowerCase();
              let val = "";
              const valEl = row.querySelector(".col-8, .col-lg-9, p.mt-2, .data-field-html");
              if (valEl) {
                val = valEl.textContent.trim();
              } else if (labelEl.nextElementSibling) {
                val = labelEl.nextElementSibling.textContent.trim();
              }

              if (text.includes("tutor")) {
                tutor = val;
              } else if (text.includes("origen")) {
                origen = val;
              }

          });

          const timeEl = entry.querySelector(".data-timeinfo span[title]");
          const fechaText = timeEl ? timeEl.getAttribute("title") : (entry.querySelector(".data-timeinfo")?.textContent?.trim() || "");

          const parseMoodleDate = (str) => {
            if (!str) return new Date(0);
            try {
              const clean = str.replace(/de/g, "").replace(/,/g, "").replace(/\s+/g, " ");
              const parts = clean.split(" ");
              const dia = parseInt(parts[1]);
              const mesText = parts[2].toLowerCase();
              const anio = parseInt(parts[3]);
              const horaParts = parts[4].split(":");
              const horas = parseInt(horaParts[0]);
              const minutos = parseInt(horaParts[1]);

              const meses = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"];
              const mesIndex = meses.indexOf(mesText);
              return new Date(anio, mesIndex, dia, horas, minutos);
            } catch (e) {
              return new Date(str);


          };

          const logDate = parseMoodleDate(fechaText);
          const existingLog = logsMap.get(idAlumno);
          if (!existingLog || logDate > existingLog.date) {
            logsMap.set(idAlumno, {
              date: logDate,
              fechaText: fechaText,
              tutor: tutor || "Tutor",
              origen: origen || "Proactivo"
            });

                      // 2. Si el origen es "Solicitud", RECHAZAR en DB Solicitudes (d=15)
          const studentObj = alumnosCalculados.find(a => a.id === activeStudentId);
          if (origen === "Solicitud") {
            if (studentObj) {
              if (studentObj.solicitudRid) {
                showLoading("Archivando solicitud del alumno...");
                const disapproveUrl = window.location.origin + "/mod/data/view.php?d=" + systemConfig.urls.dataids.db_solicitudes + "&disapprove=" + studentObj.solicitudRid + "&sesskey=" + sesskey;
                const disapproveRes = await fetch(disapproveUrl);
                if (!disapproveRes.ok) {
                  console.warn("El rechazo/archivado de la solicitud de Moodle retornó un error.");
                }
              }
            }
          }
          // 3. Enviar mensaje por mensajería instantánea AJAX si se escribió un mensaje

                    const hoy = new Date();
          const meses = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"];
          const minText = String(hoy.getMinutes()).padStart(2, "0");
          const horText = String(hoy.getHours()).padStart(2, "0");
          const fechaFormateada = hoy.getDate() + " de " + meses[hoy.getMonth()] + " de " + hoy.getFullYear() + ", " + horText + ":" + minText;

            studentObj.ultimaAsistencia = fechaFormateada;

# Despues

          // Extraer rid desde los enlaces de acción de la entrada
          let rid = null;
          for (let link of entry.querySelectorAll("a[href*='rid=']")) {
            const m = link.getAttribute("href").match(/rid=(\d+)/);
            if (m) { rid = m[1]; break; }
          }
          if (!rid) {
            for (let link of entry.querySelectorAll("a[href*='delete='], a[href*='approve='], a[href*='disapprove=']")) {
              const m = link.getAttribute("href").match(/(?:delete|approve|disapprove)=(\d+)/);
              if (m) { rid = m[1]; break; }

          // Leer el campo asistencias_json: buscar el primer array JSON en .data-field-html
          let asistencias = [];
          for (let el of entry.querySelectorAll(".data-field-html")) {
            const parsed = parseCleanJSON(el.textContent.trim());
            if (Array.isArray(parsed) && parsed.length > 0) {
              asistencias = parsed;
              break;


          // Fallback: buscar array JSON en cualquier parte del texto de la entrada
          if (asistencias.length === 0) {
            const rawMatch = entry.textContent.match(/\[[\s\S]*?\]/);
            if (rawMatch) {
              const parsed = parseCleanJSON(rawMatch[0]);
              if (Array.isArray(parsed)) asistencias = parsed;
            }
          }
          // Si no hay JSON válido, la entrada es del formato antiguo — ignorar
          if (asistencias.length === 0) return;
          const ultima = asistencias[asistencias.length - 1];
          logsMap.set(idAlumno, {
            rid: rid,
            date: new Date(ultima.fecha),
            fechaText: ultima.fecha,
            tutor: ultima.tutor || "Tutor",
            origen: ultima.origen || "Proactivo",
            asistencias: asistencias
          });


              logRid: logObj ? logObj.rid : null,


          solicitudesPendientes = solicitudesPendientes.filter(s => s.idAlumno !== activeStudentId);

            studentObj.ultimaAsistencia = new Date().toISOString();
