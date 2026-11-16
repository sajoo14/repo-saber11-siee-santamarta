# 14a · Plan de Volumen, Perfil Sintético y Evidencia de Carga Masiva (Fase 4)

**Proyecto:** Repositorio Saber 11, Evaluaciones Internas (SIEE), Simulacros y Planes de Mejoramiento (Santa Marta)  
**Motor y Versión:** `MariaDB 10.4.32 / 10.11.16` (XAMPP Win64 AMD64, `ENGINE=InnoDB`, `utf8mb4_unicode_ci`)  
**Etiqueta Ética (Regla R9):** **`SINTÉTICO — SOLO USO ACADÉMICO`** (Cero datos personales reales, cero nombres, hashes SHA-256 deterministas ficticios)  
**Estado Operativo (Regla R8):** **`PROBADO EN SGBD`**

---

## 1. Tabla Objetivo de Volúmenes Sintéticos (Reglas R5 y R12)

De acuerdo con la Fase 4 del Prompt Maestro, se seleccionaron **dos tablas principales de hechos e historial con $\ge 10.000$ registros cada una** (`resultado_evaluacion` con **12.000 filas** y `seguimiento_actividad_plan` con **10.000 filas**), manteniendo los catálogos maestros en sus cardinalidades reales de dominio y las tablas intermedias por encima de los 50 registros exigidos por la guía del curso:

| Nivel | Orden | Tabla | Rol en el Modelo | Volumen Planeado | Volumen Observado (`COUNT(*)`) | Dependencias (Padres) | Justificación de Cardinalidad y Perfil Sintético |
| :---: | :---: | :--- | :--- | ---: | ---: | :--- | :--- |
| **1** | 1 | `parametro_sistema` | Catálogo de configuración | 5 | **5** | Ninguna | Parámetros globales reales (`UMBRAL_MINIMO_K = 10`, etiqueta ética, año vigente, escala base, algoritmo SHA-256). No se infla artificialmente (**R12**). |
| **1** | 2 | `institucion_educativa` | Dimensión institucional | 50 | **50** | Ninguna | 50 colegios oficiales sintéticos distribuidos en las 9 comunas urbanas y 4 corregimientos de Santa Marta (`147001000001` a `147001000050`). Cumple mínimo $\ge 50$ de la guía. |
| **1** | 3 | `escala_evaluacion` | Catálogo métrico | 6 | **6** | Ninguna | Escalas reales del dominio (`ICFES_AREA_0_100`, `ICFES_GLOBAL_0_500`, `SIEE_1_5`, `SIEE_0_10`, `SIMULACRO_0_100` y 1 escala experimental sin transformación vigente para pruebas de bloqueo `RN04`). |
| **1** | 4 | `area_evaluacion` | Catálogo curricular | 6 | **6** | Ninguna | Las 5 áreas del núcleo común Saber 11 (`MAT`, `LEC`, `SOC`, `NAT`, `ING`) + `GLOB` (Puntaje Global). |
| **2** | 5 | `cohorte` | Dimensión temporal/escolar | 153 | **153** | `institucion_educativa` | 150 cohortes regulares (50 colegios $\times$ 3 años `2022`–`2024`) + **3 cohortes nocturnas pequeñas** (5 matriculados) diseñadas para verificar la supresión por $k$-anonimato (`RN02`). |
| **2** | 6 | `transformacion_escala` | Reglas de negocio (`RN04`) | 8 | **8** | `escala_evaluacion` | 7 reglas lineales vigentes ($P_{\text{dest}} = m \cdot P_{\text{orig}} + b$) + 1 regla histórica inactiva (`vigente = 0`) para probar el caso negativo de `fn_transformar_puntaje`. |
| **2** | 7 | `instrumento_evaluacion` | Dimensión evaluativa | 54 | **54** | `escala_evaluacion` | 9 instrumentos troncales para microdatos (`2022`–`2024` $\times$ `SIMULACRO`, `SIEE`, `SABER_11`) + 45 instrumentos de lotes históricos consolidados ($\ge 50$). |
| **2** | 8 | `promedio_nacional_ref` | Referente externo (3FN) | 54 | **54** | `area_evaluacion`, `escala_evaluacion` | Serie de promedios nacionales `2016`–`2024` $\times$ 6 áreas ($\ge 50$). |
| **2** | 9 | `plan_mejoramiento` | Entidad de gestión | 300 | **300** | `institucion_educativa`, `area_evaluacion` | 50 colegios $\times$ 2 áreas prioritarias (`MAT`, `LEC`) $\times$ 3 años (`2022`–`2024`). |
| **3** | 10 | `estudiante_seudonimo` | Dimensión seudonimizada | 3.015 | **3.015** | `cohorte` | 3.000 estudiantes en cohortes regulares (20 por cohorte) + 15 estudiantes en las 3 cohortes pequeñas (5 por cohorte). Hashes SHA-256 hexadecimales puros (`RN01`). |
| **3** | 11 | `apoyo_institucional` | Transaccional financiera | 180 | **180** | `cohorte` | Subsidios de inscripción Saber 11, simulacros, material y capacitación docente en pesos COP, respetando `beneficiarios_cubiertos <= total_matriculados`. |
| **3** | 12 | `resultado_agregado_ie` | Hechos agregados | 120 | **120** | `cohorte`, `instrumento_evaluacion`, `area_evaluacion` | Consolidados históricos sobre instrumentos `10..54` (cero solapamiento con microdatos para evitar doble conteo `Riesgo R-01`). Incluye 10 filas con `cantidad_evaluados = 6 < 10` para pruebas de filtro `RN02`. |
| **3** | 13 | **`seguimiento_actividad_plan`** | **Historial principal #1 ($\ge 10.000$)** | **10.000** | **10.000** | `plan_mejoramiento` | 33 a 34 cortes periódicos de avance por cada uno de los 300 planes de mejoramiento, respetando `uq_seg_plan_act_fecha` y conservando la evolución temporal sin sobrescribir registros (`RN03`). |
| **4** | 14 | **`resultado_evaluacion`** | **Hechos principales #2 ($\ge 10.000$)** | **12.000** | **12.000** | `estudiante_seudonimo`, `instrumento_evaluacion`, `area_evaluacion` | 11.985 microdatos en cohortes regulares distribuidos en las **5 áreas nucleares (`MAT`, `LEC`, `SOC`, `NAT`, `ING`)** con trayectorias interanuales diferenciadas por colegio + 15 microdatos en las 3 cohortes pequeñas ($< 10$ evaluados). Validados en tiempo real por `trg_res_validar_rango_ins` (rango, decimales y coherencia temporal). |
| — | — | **TOTAL GENERAL** | **14 Tablas** | **25.951** | **25.951** | Orden estricto Nivel 1 $\rightarrow$ 4 | **0 errores, 0 huérfanos, 0 duplicados, 0 violaciones de rango.** |

---

## 2. Reproducibilidad y Procedimiento Seguro de Ejecución

1. **Semilla fija y determinismo:** El script [`14_generador_datos.py`](file:///c:/Users/samue/OneDrive/Documentos/Uni/bd/final/Proyecto%20bases%20de%20datos%20(2)/Proyecto%20bases%20de%20datos/14_generador_datos.py) utiliza `SEED = 20261115` (`random.seed(20261115)`) y generación determinista `hashlib.sha256(...)`, produciendo siempre exactamente los mismos **25.951 registros** en [`14_carga_datos_sinteticos_mariadb.sql`](file:///c:/Users/samue/OneDrive/Documentos/Uni/bd/final/Proyecto%20bases%20de%20datos%20(2)/Proyecto%20bases%20de%20datos/14_carga_datos_sinteticos_mariadb.sql).
2. **Tamaño de lote compatible con XAMPP (`BATCH_SIZE = 250`):** Dado que `C:\xampp\mysql\bin\my.ini` define `max_allowed_packet=1M`, los `INSERT` masivos están fraccionados en bloques de 250 filas (~25 KB por sentencia), garantizando carga fluida en una única transacción (`START TRANSACTION ... COMMIT;`) sin desactivar `FOREIGN_KEY_CHECKS` ni triggers.

---

## 3. Evidencia Real de Verificación Post-Carga (`15_verificaciones_carga_mariadb.sql`)

### 3.1. Conteos, Integridad Referencial, Dominios y Cobertura Analítica

```text
+-----------------------+--------------------+------------------------+--------------------------------+-------------------------------------------+
| filas_vw_evolucion_q1 | filas_vw_brecha_q2 | filas_vw_impacto_q3_q4 | grupos_menores_k_en_base_esp_3 | grupos_menores_k_expuestos_en_vista_esp_0 |
+-----------------------+--------------------+------------------------+--------------------------------+-------------------------------------------+
|                   600 |                600 |                    300 |                              3 |                                         0 |
+-----------------------+--------------------+------------------------+--------------------------------+-------------------------------------------+
```

* **Huérfanos en las 17 claves foráneas:** `0` en las 17 relaciones.
* **Duplicados en claves compuestas y solapamiento microdatos vs. agregados (`Riesgo R-01`):** `0`.
* **Violaciones de rango según escala (`RN05`), formato SHA-256 (`RN01`) o cupo de beneficiarios (`R05`):** `0`.
* **Efectividad del filtro de $k$-anonimato (`RN02`):** Los **3 grupos pequeños** ($n = 5 < 10$) existen en `resultado_evaluacion` pero quedan **100 % suprimidos (`0` expuestos)** en las vistas analíticas.

### 3.2. Tamaño Físico Real Observado en Disco (`InnoDB` tras `ANALYZE TABLE`)

```text
+----------------------------+------------------------+----------+------------+----------+
| TABLE_NAME                 | filas_estimadas_innodb | datos_mb | indices_mb | total_mb |
+----------------------------+------------------------+----------+------------+----------+
| resultado_evaluacion       |                  11681 |    4.547 |      6.547 |   11.094 |
| seguimiento_actividad_plan |                   9936 |    2.516 |      0.188 |    2.703 |
| estudiante_seudonimo       |                   3008 |    0.406 |      0.391 |    0.797 |
| plan_mejoramiento          |                    300 |    0.109 |      0.031 |    0.141 |
| apoyo_institucional        |                    180 |    0.047 |      0.031 |    0.078 |
| instrumento_evaluacion     |                     54 |    0.016 |      0.047 |    0.063 |
| promedio_nacional_ref      |                     54 |    0.016 |      0.047 |    0.063 |
| resultado_agregado_ie      |                    120 |    0.016 |      0.047 |    0.063 |
| institucion_educativa      |                     50 |    0.016 |      0.031 |    0.047 |
| transformacion_escala      |                      8 |    0.016 |      0.031 |    0.047 |
| area_evaluacion            |                      6 |    0.016 |      0.031 |    0.047 |
| cohorte                    |                    153 |    0.016 |      0.031 |    0.047 |
| escala_evaluacion          |                      6 |    0.016 |      0.016 |    0.031 |
| parametro_sistema          |                      5 |    0.016 |      0.000 |    0.016 |
+----------------------------+------------------------+----------+------------+----------+
```
* **Tamaño total del esquema en disco:** **`15.237 MB`** (`7.381 MB` en páginas de datos agrupadas por PK + `7.856 MB` en árboles B-Tree de índices secundarios y `UNIQUE`).

