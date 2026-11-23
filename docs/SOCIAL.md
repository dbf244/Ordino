# Social posts

When an achievement is closed, draft posts for it. Rules:
- English. Plain, honest, a bit personal. No hype words ("revolutionary",
  "game-changer"), no more than 2 emojis.
- X post: max 280 characters, plus an optional thread of 2-4 posts with
  technical details.
- Say what works now, show it (suggest which screenshot or GIF to record),
  and end with the repo link.
- Hashtags at the end: #buildinpublic #macOS #SwiftUI #opensource
- Also give a Spanish version for the maintainer's own audience.
- Never invent numbers (times, counts, users): use only what really happened.
- Append the final posts to this file under the achievement heading.

Where to post: X, Mastodon (iosdev.space), Bluesky on every achievement.
r/SwiftUI and r/swift for technical milestones (3, 5, 6). r/macapps at the
beta and 1.0. Show HN, Product Hunt, AlternativeTo and awesome lists at 1.0.

## Tone examples (drafts, rewrite with what really happened)

**Achievement 0**
> I'm building a free, open-source alternative to Hazel for macOS: Ordino, a native app that watches your folders and tidies them with simple rules. Swift, SwiftUI, MIT, built in public. Day 0: empty menu bar app, green CI. Follow along 👇 [repo] #buildinpublic #macOS #opensource

**Achievement 5**
> The feature I'm proudest of: every action Ordino takes can be undone, and before you enable a rule you see a simulation of exactly what it would do. Automation shouldn't feel scary. [GIF] #macOS #opensource

---

## Published posts

### Achievement 0 — Foundations (v0.0.1)

Suggested media: a screenshot of the menu bar with the Ordino icon open,
showing "Quit Ordino", next to the green CI run on GitHub Actions.

**X (English)**

> I'm building Ordino, a free, open-source Mac app that tidies your folders with simple rules. A friendly Hazel alternative, built in public.
>
> Day 0: an empty, sandboxed menu bar app and green CI.
>
> https://github.com/dbf244/Ordino
>
> #buildinpublic #macOS #SwiftUI #opensource

Thread:

1. How it's set up: all the logic lives in a Swift package with no UI, the Xcode project is generated with XcodeGen, and Swift 6 strict concurrency is on from the first line. Any warning fails the build.
2. Safety rules come before features. Ordino will never delete a file permanently (Trash only), never overwrite one silently, and every action will be undoable. The App Sandbox is on from day one, and CI checks it on every push.
3. Next up: the Watcher. Pick a folder once, and Ordino sees every file that lands there, waiting until downloads finish before touching anything.

**X (Spanish)**

> Estoy creando Ordino, una app gratis y open source para Mac que ordena tus carpetas con reglas sencillas. Alternativa a Hazel, hecha en público.
>
> Día 0: app vacía en la barra de menús, sandbox y CI en verde.
>
> https://github.com/dbf244/Ordino
>
> #buildinpublic #macOS #SwiftUI #opensource

Hilo:

1. Cómo está montado: toda la lógica vive en un paquete Swift sin UI, el proyecto de Xcode se genera con XcodeGen y la concurrencia estricta de Swift 6 está activa desde la primera línea. Cualquier warning rompe la build.
2. La seguridad va antes que las funciones. Ordino nunca borrará un archivo para siempre (solo a la Papelera), nunca sobrescribirá nada sin avisar y todo se podrá deshacer. El sandbox está activo desde el día 0 y el CI lo comprueba en cada push.
3. Lo siguiente: el Watcher. Eliges una carpeta una vez y Ordino ve cada archivo que llega, esperando a que terminen las descargas antes de tocar nada.

### Achievement 1 — The Watcher (v0.1.0)

Suggested media: a short screen recording of Finder dropping a file into
~/Ordino-Playground while the Activity Log window shows it appear, then a
rename and a delete.

**X (English)**

> Ordino now watches a folder. Pick it once and access survives relaunches. Files show up ~1 s after they stop changing; a 400 MB file written over 6 s was reported once, when done. Idle CPU: 0%.
>
> https://github.com/dbf244/Ordino
>
> #buildinpublic #macOS #SwiftUI #opensource

Thread:

1. The tricky part isn't seeing files, it's knowing when they're finished. FSEvents tells you something changed; Ordino then measures the file until its size and date stop moving for a second. Partial downloads (.crdownload, .download, .part) are ignored.
2. Real numbers from my Mac: new file reported 1.2 s after it was written, renames and deletes in 0.2 s, 0.00 s of CPU over a minute of idle. FSEvents only wakes the app when something happens.
3. Sandboxed from the start: Ordino only sees the folder you pick, remembered with a security-scoped bookmark. System folders and ~/Library can't be chosen at all. Next: the first rule that actually moves a file.

**X (Spanish)**

> Ordino ya vigila una carpeta. La eliges una vez y no vuelve a pedir permiso. Un archivo aparece ~1 s tras dejar de cambiar; uno de 400 MB escrito en 6 s se avisó una vez, al acabar. CPU en reposo: 0%.
>
> https://github.com/dbf244/Ordino
>
> #buildinpublic #macOS #SwiftUI #opensource

Hilo:

1. Lo difícil no es ver los archivos, es saber cuándo han terminado. FSEvents avisa de que algo cambió; Ordino mide el archivo hasta que su tamaño y fecha dejan de moverse durante un segundo. Las descargas a medias (.crdownload, .download, .part) se ignoran.
2. Números reales en mi Mac: archivo nuevo avisado 1,2 s después de escribirse, renombrados y borrados en 0,2 s, 0,00 s de CPU en un minuto en reposo. FSEvents solo despierta la app cuando pasa algo.
3. Con sandbox desde el principio: Ordino solo ve la carpeta que eliges, recordada con un security-scoped bookmark. Las carpetas del sistema y ~/Library no se pueden elegir. Lo siguiente: la primera regla que mueve un archivo de verdad.
