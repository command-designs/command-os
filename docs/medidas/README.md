# Medidas de ligereza

Lo que apunta `build/x86/medir-vm.sh` (método: `docs/testing.md` § «Medir la ligereza»). Una fila por
medida, de la más antigua a la más nueva; para comparar un cambio, la fila de antes y la de después.
Las cifras de la VM solo se comparan entre sí.

`registro.tsv`, la mediana de los arranques medidos:

| Columna | Qué es |
| --- | --- |
| `fecha`, `commit`, `rama` | cuándo y con qué árbol (`+cambios`: `os/` tenía algo sin commit) |
| `entorno`, `version`, `sesion` | dónde (`vbox`), versión del paquete instalado y compositor |
| `arranques` | cuántos arranques se midieron |
| `escritorio_s` | segundos desde que arranca el núcleo hasta el escritorio (compositor y Waybar) |
| `kernel_s`, `initrd_s`, `userspace_s` | los tiempos de `systemd-analyze` |
| `mem_usada_mb` | `MemTotal − MemAvailable` en reposo |
| `pss_total_mb` | suma del PSS de todos los procesos (sin el medidor ni su SSH) |
| `procesos_tics_min` | tics de CPU por minuto de los procesos: la cifra de CPU que se compara |
| `cpu_tics_min` | tics por minuto de todo el sistema (en la VM, casi todo interrupciones) |
| `espera_s`, `ventana_s` | espera tras el escritorio y duración de la medida de CPU |
| `nota` | qué se cambió |

`procesos.tsv`, los 12 programas con más PSS del arranque mediano: `fecha`, `commit`, `programa`,
`procesos` (cuántos con ese nombre), `pss_kb`, `rss_kb` y `tics_min`.
