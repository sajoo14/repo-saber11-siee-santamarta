# Repositorio de Gestión y Analítica de Resultados Saber 11, Evaluaciones Internas (SIEE), Simulacros y Planes de Mejoramiento (Santa Marta)

**Asignatura:** Bases de Datos — Proyecto Integrador Final  
**Dominio Territorial:** Instituciones Educativas Oficiales del Distrito de Santa Marta, Magdalena  
**Motor de Base de Datos:** `MariaDB 10.4.32 / 10.11.16` (XAMPP Windows x64 · `ENGINE=InnoDB` · `utf8mb4_unicode_ci`)  
**Nombre del Esquema:** `repo_saber_siee_sm`  
**Etiqueta Ética de Datos:** `SINTÉTICO — SOLO USO ACADÉMICO` (Cero datos personales reales; seudonimización SHA-256 y $k$-anonimato)  
**Estado Operativo:** **`PROBADO EN SGBD`**

---

## 1. Descripción del Proyecto

El Icfes y la Universidad del Magdalena han señalado que los resultados de las pruebas **Saber 11** en los colegios oficiales de Santa Marta se ubican por debajo del promedio nacional y que existe desconexión entre los Sistemas Institucionales de Evaluación de Estudiantes (**SIEE**) y la prueba de Estado. Aunque la Alcaldía Distrital financia inscripciones y simulacros, se carecía de un repositorio relacional unificado para evaluar la evolución histórica por institución y el impacto observado de los planes de mejoramiento.

Este repositorio implementa una solución integral de **14 tablas en Tercera Forma Normal (3FN)** que resuelve las cuatro preguntas analíticas del enunciado:
1. **Q1 (`C01`):** ¿Cómo cambian los resultados por institución, área y año?
2. **Q2 (`C02`):** ¿Qué diferencia existe frente al promedio nacional para una misma escala?
3. **Q3 (`C03`):** ¿Qué instituciones muestran mayores mejoras?
4. **Q4 (`C04`):** ¿Qué relación se observa entre simulacros, planes y resultados posteriores?

---

## 2. Arquitectura del Modelo (14 Tablas en 4 Niveles Topológicos)

| Nivel | Orden | Tabla Física | Rol / Propósito | Clave Primaria (PK) | Filas Sintéticas |
| :---: | :---: | :--- | :--- | :--- | ---: |
| **1** | 1 | `parametro_sistema` | Parámetros operativos (`UMBRAL_MINIMO_K = 10` para $k$-anonimato `RN02`) | `clave_parametro` | 5 |
| **1** | 2 | `institucion_educativa` | Colegios oficiales del Distrito de Santa Marta (`R01`) | `codigo_dane` | 50 |
| **1** | 3 | `escala_evaluacion` | Escalas métricas con rango cerrado `[valor_minimo, valor_maximo]` (`R02`, `RN05`) | `id_escala` | 6 |
| **1** | 4 | `area_evaluacion` | Áreas evaluadas (`MAT`, `LEC`, `SOC`, `NAT`, `ING`, `GLOB`) (`R02`) | `id_area` | 6 |
| **2** | 5 | `cohorte` | Grupos anuales por institución y jornada escolar (`R01`) | `id_cohorte` | 153 |
| **2** | 6 | `transformacion_escala` | Reglas lineales explícitas y justificadas $P_{\text{dest}} = m \cdot P_{\text{orig}} + b$ (`R07`, `RN04`) | `id_transformacion` | 8 |
| **2** | 7 | `instrumento_evaluacion` | Pruebas aplicadas (`SABER_11`, `SIEE`, `SIMULACRO`), fuente y periodo (`R02`) | `id_instrumento` | 54 |
| **2** | 8 | `promedio_nacional_ref` | Referentes nacionales oficiales en 3FN por año, área, escala y fuente (`R04`, `D03`) | `id_referente` | 54 |
| **2** | 9 | `plan_mejoramiento` | Planes institucionales por colegio, área y año con diagnóstico y meta (`R06`) | `id_plan` | 300 |
| **3** | 10 | `estudiante_seudonimo` | Hash seudónimo `SHA-256` minimizado sin datos personales ni demográficos (`R03`, `RN01`, `D02`) | `id_estudiante_hash` | 3.015 |
| **3** | 11 | `apoyo_institucional` | Subsidios y financiación pública en pesos COP por cohorte (`R05`) | `id_apoyo` | 180 |
| **3** | 12 | `resultado_agregado_ie` | Consolidados institucionales cuando no existen microdatos individuales (`R03`, `RN02`, `RN03`) | `id_agregado` | 120 |
| **3** | 13 | `seguimiento_actividad_plan` | **Historial Principal #1:** Cortes periódicos de avance de actividades sin sobrescribir (`R06`, `RN03`) | `id_seguimiento` | **10.000** |
| **4** | 14 | `resultado_evaluacion` | **Hechos Principales #2:** Microdatos inmutables por estudiante seudónimo, instrumento y área (`R03`, `RN03`, `RN05`) | `(id_estudiante_hash, id_instrumento, id_area)` | **12.000** |
| — | — | **TOTAL** | **14 Tablas (`ENGINE=InnoDB`)** | **14 PK / 17 FK / 9 UQ / 52 CHECK / 18 Índices** | **25.951** |

---

## 3. Capa de Programabilidad Implementada (`12d_objetos_programables_mariadb.sql`)

* **1 Función Definida por el Usuario (UDF):**
  * `fn_transformar_puntaje(p_puntaje, p_escala_origen, p_escala_destino)`: Homologa puntajes entre escalas consultando `transformacion_escala` (`vigente = 1`) o retorna `NULL` si no existe regla aprobada (`RN04`).
* **9 Disparadores (`TRIGGERS`):**
  * Validación cruzada de rango `[valor_minimo, valor_maximo]` y precisión decimal (`RN05`): `trg_res_validar_rango_ins`, `trg_resag_validar_rango_ins`, `trg_ref_validar_rango_ins`.
  * Bloqueo estricto de inmutabilidad histórica ante `UPDATE` y `DELETE` con `SIGNAL SQLSTATE '45000'` (`RN03`): `trg_res_inmutabilidad_upd/del`, `trg_resag_inmutabilidad_upd/del`, `trg_seg_inmutabilidad_upd/del`.
* **2 Procedimientos Almacenados Transaccionales (`START TRANSACTION` / `COMMIT` / `ROLLBACK` + `EXIT HANDLER`):**
  * `sp_registrar_seguimiento_plan`: Inserta un nuevo corte de actividad y actualiza atómicamente el estado del plan (`EN_EJECUCION` / `CUMPLIDO`).
  * `sp_registrar_apoyo_institucional`: Registra un apoyo verificando con bloqueo `FOR UPDATE` que la institución esté activa y que `beneficiarios_cubiertos <= total_matriculados`.
* **3 Vistas Analíticas con `GROUP BY` y `HAVING` (`RN02` $k$-anonimato):**
  * `vw_evolucion_ie_area_anio` (Pregunta Q1)
  * `vw_brecha_promedio_nacional` (Pregunta Q2)
  * `vw_impacto_simulacros_planes` (Preguntas Q3 y Q4)

---

## 4. Guía de Ejecución Paso a Paso en XAMPP (MariaDB)

Con el servicio **MySQL (MariaDB)** activo en XAMPP, ejecute en orden desde la terminal o cliente SQL:

```powershell
# 1. Crear el esquema vacío documentado (14 tablas, 89 columnas, 17 FK, 52 CHECK, 18 índices)
C:\xampp\mysql\bin\mysql.exe -u root --default-character-set=utf8mb4 -e "SOURCE 12_creacion_esquema_mariadb.sql"

# 2. Crear la capa de programabilidad (1 UDF, 9 Triggers, 2 Procedimientos, 3 Vistas)
C:\xampp\mysql\bin\mysql.exe -u root --default-character-set=utf8mb4 -e "SOURCE 12d_objetos_programables_mariadb.sql"

# 3. Verificar la estructura y el 100 % de comentarios en INFORMATION_SCHEMA
C:\xampp\mysql\bin\mysql.exe -u root --default-character-set=utf8mb4 -t -e "SOURCE 13_verificaciones_estructura_mariadb.sql"

# 4. (Opcional) Regenerar el archivo DML desde Python (semilla fija 20261115)
python 14_generador_datos.py

# 5. Cargar los 25.951 registros sintéticos en una transacción controlada
C:\xampp\mysql\bin\mysql.exe -u root --default-character-set=utf8mb4 -e "SOURCE 14_carga_datos_sinteticos_mariadb.sql"

# 6. Ejecutar las verificaciones post-carga (conteos, 0 huérfanos, 0 duplicados, k-anonimato)
C:\xampp\mysql\bin\mysql.exe -u root --default-character-set=utf8mb4 -t -e "SOURCE 15_verificaciones_carga_mariadb.sql"

# 7. Ejecutar las 12 consultas funcionales y analíticas (Q1–Q4 y casos límite)
C:\xampp\mysql\bin\mysql.exe -u root --default-character-set=utf8mb4 -t -e "SOURCE 16_consultas_validacion_mariadb.sql"
```

---

## 5. Índice Completo de Entregables (`E1`–`E20` y Memoria Técnica)

| Fase | Archivo | Evidencia | Descripción |
| :---: | :--- | :---: | :--- |
| **Marco** | `PROMPT_MAESTRO_ADAPTADO.md` | Rector | Metodología de ingeniería de BD v3.0 y reglas `R1`–`R16`. |
| **Marco** | `HANDOFF_CONTINUIDAD_PROYECTO.md` | Relevo | Estado integral del proyecto y guía de continuidad. |
| **Fase 1** | `01_analisis_semantico.md` | **E1** | Diagnóstico consultivo, requisitos `R01`–`R08`, reglas `RN01`–`RN05` y decisiones `D01`–`D03`. |
| **Fase 1** | `02_catalogo_conceptual.md` | **E2** | Catálogo justificado de 14 entidades y especificación textual en notación **Chen**. |
| **Fase 1** | `03_diagrama_conceptual.puml` / `.png` | **E3** | Diagrama conceptual en notación **Crow's Foot** (Pata de Cuervo). |
| **Fase 1** | `04_trazabilidad_conceptual.csv` | **E4** | Matriz de trazabilidad conceptual. |
| **Fase 1** | `Fase_1_Especificacion_y_Modelo_Conceptual.docx` | Doc | Entregable consolidado en Word de la Fase 1. |
| **Fase 2** | `05_modelo_logico.md` | **E5** | Esquema relacional lógico de 14 tablas independiente del SGBD. |
| **Fase 2** | `06_normalizacion.md` | **E6** | Demostración formal de 1FN, 2FN y 3FN y anomalías prevenidas. |
| **Fase 2** | `07_diagrama_logico.puml` / `.png` | **E7** | Diagrama relacional lógico con PK, FK y cardinalidades. |
| **Fase 2** | `08_trazabilidad_logica.csv` | **E8** | Matriz de trazabilidad lógica. |
| **Fase 2** | `Fase_2_Diseno_Logico_y_Normalizacion.docx` | Doc | Entregable consolidado en Word de la Fase 2. |
| **Fase 3** | `09_diccionario_fisico.csv` | **E9** | Diccionario físico de las 89 columnas en MariaDB con `CHECK`, FK y `COMMENT`. |
| **Fase 3** | `10_especificacion_fisica.md` | **E10** | Configuración física, 4 niveles de creación y 18 índices secundarios. |
| **Fase 3** | `11_verificacion_previa.md` | **E11** | Verificación técnica del entorno XAMPP local. |
| **DDL** | `12a_inventario_documentacion.csv` | **E17** | Inventario documental de los 244 objetos del esquema. |
| **DDL** | `12_creacion_esquema_mariadb.sql` | **E17** | Script DDL estructural 100 % documentado con `COMMENT` nativos. |
| **DDL** | `12b_migracion_solo_comentarios_PENDIENTE.md` | **E18** | Protocolo de migración documental bajo Regla R15. |
| **DDL** | `12c_mejoras_diseno_no_aplicadas.md` | **E20** | Reporte separado de mejoras futuras respetando inmutabilidad R14. |
| **DDL** | `12d_objetos_programables_mariadb.sql` | **E17** | Implementación de 1 UDF, 9 Triggers, 2 Procedimientos y 3 Vistas. |
| **DDL** | `13_verificaciones_estructura_mariadb.sql` | **E19** | Consultas de auditoría contra `INFORMATION_SCHEMA` y `SHOW CREATE TABLE`. |
| **DDL** | `13a_comparacion_documental.md` | **E19** | Evidencia real de verificación del catálogo en SGBD. |
| **Fase 4** | `14_generador_datos.py` | **E12** | Generador reproducible en Python (`SEED = 20261115`). |
| **Fase 4** | `14_carga_datos_sinteticos_mariadb.sql` | **E12** | DML puro e independiente con **25.951 registros sintéticos**. |
| **Fase 4** | `14a_plan_volumen_y_perfil_sintetico.md` | **E13** | Plan de volumen, justificación de cardinalidades y tamaño en disco (`15,24 MB`). |
| **Fase 4** | `15_verificaciones_carga_mariadb.sql` | **E14** | Auditoría post-carga (conteos, 0 huérfanos, 0 duplicados, $k$-anonimato). |
| **Fase 5** | `16_consultas_validacion_mariadb.sql` | **E15** | 12 consultas analíticas diferenciadas (`C01`–`C12`). |
| **Fase 5** | `17_plan_pruebas_y_rendimiento.md` | **E16** | 13 pruebas positivas/negativas ejecutadas y 4 planes `EXPLAIN` medidos. |
| **Fase 6** | `18_auditoria_final_y_defensa.md` | Auditoría | Auditoría final, tabla `E1`–`E20`, uso crítico de IA y 5 preguntas de defensa oral. |
| **Fase 6** | `18a_trazabilidad_completa.csv` | Matriz | Matriz de trazabilidad extremo a extremo. |
| **Entrega** | `19_Memoria_Tecnica_Final.pdf` / `.docx` | **Memoria** | **Memoria Técnica Final consolidada en PDF (14 páginas) y Word editable.** |
