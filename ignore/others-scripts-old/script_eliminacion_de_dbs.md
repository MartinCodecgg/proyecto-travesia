var dry_run_rids;

(async function () {

// ═══════════════════════════════════════════════════════════
// CONFIGURACIÓN — editar esto antes de ejecutar
// ═══════════════════════════════════════════════════════════
const CONFIG = {
DATAID: null, // ID de la base de datos (d=...) — OBLIGATORIO
CMID: null, // Course Module ID (cm=...) — OBLIGATORIO
USERID: 2987, // ID numérico del usuario — OBLIGATORIO
USERNAME: "MARTIN ESTEBAN GIRAU", // Nombre visible del usuario — OBLIGATORIO
DELAY_MS: 500, // Pausa entre deletes (ms)
DRY_RUN: true, // true = guarda en dry_run_rids, no borra nada
};
// ═══════════════════════════════════════════════════════════

const missing = [];
if (!CONFIG.DATAID) missing.push("DATAID");
if (!CONFIG.CMID) missing.push("CMID");
if (!CONFIG.USERID) missing.push("USERID");
if (!CONFIG.USERNAME) missing.push("USERNAME");

if (missing.length > 0) {
console.error(
`❌ Script abortado. Faltan definir los siguientes valores en CONFIG:\n` +
missing.map(k => `  • ${k}`).join("\n") +
`\n\nEditá CONFIG al inicio del script y volvé a ejecutar.`
);
return;
}

const { DATAID, CMID, USERID, USERNAME, DELAY_MS, DRY_RUN } = CONFIG;
const BASE_URL = window.location.origin;
const sesskey = M.cfg.sesskey;

if (DRY_RUN) {
console.warn("⚠️ DRY_RUN activado — no se eliminará nada. Los resultados quedarán en dry_run_rids.");
}

console.log(`🔍 Buscando entradas de "${USERNAME}" (id=${USERID}) en dataid=${DATAID}, cmid=${CMID}...`);

const rids = [];
let page = 0;

while (true) {
const url = `${BASE_URL}/mod/data/view.php?d=${DATAID}&cm=${CMID}&uid=${USERID}&page=${page}`;
const res = await fetch(url, { credentials: "include" });

    if (!res.ok) {
      console.error(`❌ Error al cargar página ${page}: HTTP ${res.status}. Abortando.`);
      return;
    }

    const html = await res.text();
    const doc  = new DOMParser().parseFromString(html, "text/html");
    const deleteLinks = [...doc.querySelectorAll('a[href*="delete="]')];

    if (deleteLinks.length === 0) break;

    deleteLinks.forEach(link => {
      const container =
        link.closest('[id^="entry-"]')   ||
        link.closest(".defaulttemplate") ||
        link.closest(".card")            ||
        link.closest("tr")               ||
        link.parentElement?.closest("div");

      if (!container) {
        console.warn(`⚠️ No se encontró contenedor para: ${link.href}`);
        return;
      }

      const hasUserById   = container.querySelector(`a[href*="user/view.php?id=${USERID}"]`);
      const hasUserByName = container.textContent.includes(USERNAME);

      if (hasUserById || hasUserByName) {
        const match = link.href.match(/[?&]delete=(\d+)/);
        if (match) {
          const autorEl   = container.querySelector(`a[href*="user/view.php?id=${USERID}"]`);
          const fechaEls  = container.querySelectorAll("span.data-timeinfo span[title]");
          const autorImg = autorEl?.querySelector("img");
          const autor = autorEl?.textContent.trim() || autorImg?.getAttribute("alt") || USERNAME;
          const publicado = fechaEls[0]?.getAttribute("title") ?? "?";
          const editado   = fechaEls[1]?.getAttribute("title") ?? "?";
          console.log(`✅ rid=${match[1]} | autor: ${autor} | publicado: ${publicado} | editado: ${editado}`);
          rids.push({ rid: match[1], autor, publicado, editado });
        }
      } else {
        console.warn(`⚠️ Entrada omitida (usuario no coincide): ${link.href}`);
      }
    });

    const hasNext = doc.querySelector(`a[href*="page=${page + 1}"]`);
    if (!hasNext) break;
    page++;

}

if (rids.length === 0) {
console.log(`ℹ️ No se encontraron entradas de "${USERNAME}". Nada que eliminar.`);
return;
}

console.log(`\n📋 Total encontradas: ${rids.length} entradas de "${USERNAME}".`);

if (DRY_RUN) {
dry_run_rids = rids;
console.log("🔎 Revisá dry_run_rids en la consola para verificar antes de eliminar.");
return;
}

console.log("🗑️ Procediendo con la eliminación...\n");

for (let i = 0; i < rids.length; i++) {
const { rid, autor, publicado } = rids[i];
const form = new FormData();
form.append("d", DATAID);
form.append("delete", rid);
form.append("confirm", "1");
form.append("sesskey", sesskey);

    const res = await fetch(`${BASE_URL}/mod/data/view.php`, {
      method:      "POST",
      body:        form,
      credentials: "include",
      redirect:    "manual",
    });

    const ok = res.status === 200 || res.status === 0;
    console.log(`${ok ? "✅" : "❌"} (${i + 1}/${rids.length}) rid=${rid} | ${autor} | ${publicado} — status: ${res.status}`);
    await new Promise(r => setTimeout(r, DELAY_MS));

}

console.log("\n✅ Listo. Recargá la página para verificar.");

})();

```

**Flujo recomendado:** primero corrés con `DRY_RUN: true` → revisás en consola los rids que listaría → si están bien, cambiás a `false` y ejecutás de nuevo.

El flujo queda así:

1. `DRY_RUN: true` → ejecutás → cuando terminan los logs, escribís `dry_run_rids` en la consola y ves el array completo
2. Si todo está bien, cambiás a `DRY_RUN: false` y ejecutás de nuevo → borra
```
