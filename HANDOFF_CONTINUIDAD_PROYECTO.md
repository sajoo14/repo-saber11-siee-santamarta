# Documento de Relevo y Planificación Integral del Proyecto (Handoff)

**Proyecto:** Sistema de Gestión y Analítica de Resultados Saber 11, Evaluaciones Internas (SIEE), Simulacros y Planes de Mejoramiento (Colegios Oficiales de Santa Marta)  
**Última actualización:** 15 de noviembre de 2026  
**Propósito de este archivo:** Servir como guía completa y autosuficiente para que otro integrante del equipo pueda entender todo lo realizado hasta hoy, evitar errores con archivos antiguos, conocer las decisiones técnicas aprobadas y ejecutar paso a paso todas las fases pendientes hasta la entrega y sustentación final.

---

## 1. Marco Rector del Proyecto (Las 2 Referencias Obligatorias)

Este proyecto se rige simultáneamente por **dos documentos**:

1. **Guía Oficial del Proyecto Integrador Final (del Profesor):**
   * **Alcance estructural:** Entre **8 y 15 tablas** en el modelo final, relaciones `1:N` y `N:M` resueltas mediante tablas intermedias, claves compuestas justificadas, normalización mínima hasta **3FN**, políticas `ON DELETE` / `ON UPDATE`, `CHECK`, `UNIQUE`, `NOT NULL`, `DEFAULT`.
   * **Diagramas:** Notación formal **Crow's Foot** (Pata de Cuervo).
   * **Programabilidad obligatoria:** Al menos **3 vistas** (con `GROUP BY` y `HAVING`), mínimo **2 procedimientos almacenados** (con `COMMIT`, `ROLLBACK` y manejo de excepciones), mínimo **2 triggers** (auditoría/inmutabilidad y validación de reglas no soportadas por `CHECK`), y al menos **1 función definida por el usuario (UDF)**.
   * **Datos y Optimización:** Datos de prueba coherentes (mínimo 50 registros donde aplique según la guía) y análisis de planes de ejecución con `EXPLAIN`.
   * **Entrega final:** Repositorio Git, Memoria Técnica consolidada en PDF y sustentación oral en vivo.

2. **Metodología de Trabajo (`PROMPT_MAESTRO_ADAPTADO.md`):**
   * Define puertas de control estrictas (**R5**): no generar DDL antes de aprobar Fase 3 ni DML antes de aprobar el DDL documentado.
   * Exige trazabilidad viva (`R10`), separación estricta entre DDL de creación y DML de datos (`R16`), documentación integral con `COMMENT` nativos (`R13`), inmutabilidad del diseño aprobado (`R14`) y honestidad operativa (**R8**: distinguir siempre entre `PROPUESTO`, `REVISADO ESTÁTICAMENTE` y `PROBADO EN SGBD`).
   * Exige carga sintética masiva de **10.000 filas en al menos dos tablas principales de hechos/historial** (siempre superando el mínimo de 50 de la guía) y al menos **10 consultas de validación** con pruebas positivas/negativas y `EXPLAIN` real.

---

## 2. Estado Actual del Proyecto (Punto Exacto de Relevo)

| Etapa / Puerta | Estado Actual | Evidencias Existentes | Acción Siguiente Requerida |
| :--- | :---: | :--- | :--- |
| **FASE 1 · Conceptual y Análisis Semántico** | **APROBADA** | `01_` a `04_` + Word Fase 1 | Ninguna (solo mantener trazabilidad si hubiera cambios). |
| **FASE 2 · Diseño Lógico y Normalización 3FN** | **APROBADA** | `05_` a `08_` + Word Fase 2 | Ninguna (modelo fijado en **14 tablas**). |
| **PUERTA OBLIGATORIA DEL MOTOR** | **COMPLETADA** | XAMPP `C:\xampp` inspeccionado | Confirmado **`10.11.16-MariaDB`** (Win64 AMD64). |
| **FASE 3 · Diseño Físico (`MariaDB 10.11.16 / 10.4.32`)** | **APROBADA** | `09_diccionario_fisico.csv`, `10_especificacion_fisica.md`, `11_verificacion_previa.md` | Ninguna (Fase 3 aprobada íntegramente). |
| **ENTREGA DDL + DOCUMENTACIÓN TOTAL** | **APROBADA Y PROBADA EN SGBD** | `12a_inventario_documentacion.csv`, `12_creacion_esquema_mariadb.sql`, `12b_migracion_solo_comentarios_PENDIENTE.md`, `12c_mejoras_diseno_no_aplicadas.md`, `13_verificaciones_estructura_mariadb.sql`, `13a_comparacion_documental.md` | Ninguna (DDL aprobado y verificado en XAMPP). |
| **PROGRAMABILIDAD (Vistas, Triggers, SP, UDF)** | **APROBADA Y PROBADA EN SGBD** | `12d_objetos_programables_mariadb.sql` (1 UDF, 9 Triggers, 2 SP, 3 Vistas) | Integrada y verificada en catálogo MariaDB. |
| **FASE 4 · DML Masivo Sintético** | **APROBADA Y PROBADA EN SGBD** | `14_generador_datos.py`, `14a_plan_volumen_y_perfil_sintetico.md`, `14_carga_datos_sinteticos_mariadb.sql`, `15_verificaciones_carga_mariadb.sql` (**25.951 filas cargadas**) | Ninguna (Fase 4 aprobada y verificada en XAMPP). |
| **FASE 5 · Consultas y Rendimiento (`EXPLAIN`)** | **APROBADA Y PROBADA EN SGBD** | `16_consultas_validacion_mariadb.sql` (12 consultas diferenciadas), `17_plan_pruebas_y_rendimiento.md` (13 pruebas positivas/negativas + 4 `EXPLAIN` medidos) | Ninguna (Fase 5 aprobada y verificada en XAMPP). |
| **FASE 6 · Auditoría, Memoria PDF, Git y Defensa** | **COMPLETADA (`E1`–`E20`)** | `18_auditoria_final_y_defensa.md`, `18a_trazabilidad_completa.csv` | **Proyecto técnico 100 % completado y probado en SGBD.** Listo para exportar PDF / subir a Git y sustentar. |

---

## 3. Inventario de Archivos en la Carpeta (Qué Usar y Qué Ignorar)

La carpeta de trabajo es `C:\Users\Sebastian\Downloads\Proyecto bases de datos`. **Lee con atención esta clasificación para no usar borradores viejos:**

### A. Archivos Vigentes (Fuente de Verdad — Modelo Definitivo de 14 Tablas)
* **`PROMPT_MAESTRO_ADAPTADO.md`**: Reglas completas v3.0 + contexto del problema y guía del curso.
* **Fase 1 (Conceptual):**
  * `01_analisis_semantico.md`: Diagnóstico consultivo, hechos confirmados vs. supuestos, redacción mejorada del enunciado, requisitos `R01`–`R08`, reglas `RN01`–`RN05` y decisiones `D01`–`D03`.
  * `02_catalogo_conceptual.md`: Catálogo justificado de 14 entidades y especificación textual formal en **notación Chen**.
  * `03_diagrama_conceptual.puml` y `03_diagrama_conceptual.png`: Diagrama PlantUML en **Pata de Cuervo (Crow's Foot)** rotulado como no-Chen.
  * `04_trazabilidad_conceptual.csv`: Matriz requisito $\rightarrow$ entidad.
  * `Fase_1_Especificacion_y_Modelo_Conceptual.docx`: Documento Word actualizado (15/11/2026) con el modelo de 14 tablas y la imagen `03_diagrama_conceptual.png`.
* **Fase 2 (Lógica y 3FN):**
  * `05_modelo_logico.md`: Esquema relacional independiente del SGBD (PK, FK, UQ, dominios lógicos).
  * `06_normalizacion.md`: Demostración 1FN, 2FN, 3FN, anomalías prevenidas y matriz de dependencias funcionales.
  * `07_diagrama_logico.puml` y `07_diagrama_logico.png`: Diagrama lógico PlantUML actualizado.
  * `08_trazabilidad_logica.csv`: Matriz requisito $\rightarrow$ tabla/columna lógica.
  * `Fase_2_Diseno_Logico_y_Normalizacion.docx`: Documento Word actualizado (15/11/2026) con 14 tablas, dominios neutrales e imagen `07_diagrama_logico.png`.
* **Fase 3 (Física para MariaDB 10.11.16 — Lista para Aprobación):**
  * `09_diccionario_fisico.csv`: Las 89 columnas de las 14 tablas con tipos MariaDB, nulabilidad, `DEFAULT`, `CHECK`, políticas FK, índices y texto de `COMMENT` propuesto.
  * `10_especificacion_fisica.md`: Configuración del servidor, orden de creación en 4 niveles, 18 índices sin duplicación y separación DDL vs. lógica programable.
  * `11_verificacion_previa.md`: Evidencia de inspección del entorno XAMPP local y chequeo de prefijos `utf8mb4`.

### B. Borradores Históricos Obsoletos (NO Usar como Base — Modelo Viejo de 11 Tablas)
Estos archivos quedaron de la primera iteración previa a la auditoría del Prompt Maestro. Se recomienda moverlos a una subcarpeta `_archivo_historico` o ignorarlos para no confundirte:
* `Diagrama_ER_Conceptual_Fase1.puml` / `.png`
* `Diagrama_Relacional_Logico_Fase2.puml` / `.png`
* `Fase_1_Especificacion_y_Modelo_Conceptual_Resumido.docx`
* `Fase_1_Especificacion_y_Modelo_Conceptual_Resumido_Con_Diagrama.docx`

---

## 4. Arquitectura Técnica Aprobada (Resumen para el Compañero)

### 4.1. Las 14 Tablas y su Orden de Creación (4 Niveles sin Ciclos)
El modelo se fijó en **14 tablas** para respetar el límite de **8 a 15 tablas** de la guía del profesor y dejar **1 cupo libre (tabla #15)** por si durante la implementación de Triggers se decide añadir una tabla de auditoría de intentos (`auditoria_sistema`).

* **Nivel 1 (Independientes):**
  1. `parametro_sistema` — Parámetros configurables (ej. `UMBRAL_MINIMO_K` para $k$-anonimato antes de publicar reportes).
  2. `institucion_educativa` — Colegios oficiales de Santa Marta (`PK: codigo_dane VARCHAR(12)`).
  3. `escala_evaluacion` — Escalas métricas con rango cerrado `[valor_minimo, valor_maximo]`, decimales y unidad.
  4. `area_evaluacion` — Áreas evaluadas (`MAT`, `LEC`, `SOC`, `NAT`, `ING`, `GLOB`).
* **Nivel 2:**
  5. `cohorte` — Agrupación anual por colegio y jornada (`UQ: (codigo_dane, anio_lectivo, jornada)`).
  6. `transformacion_escala` — Reglas explícitas y justificadas de conversión lineal ($P_{\text{dest}} = m \cdot P_{\text{orig}} + b$) entre `id_escala_origen` e `id_escala_destino`.
  7. `instrumento_evaluacion` — Pruebas (`tipo_instrumento` IN `('SABER_11','SIEE','SIMULACRO')`), fuente, periodo y su `id_escala`.
  8. `promedio_nacional_ref` — Referentes nacionales por `(anio_vigencia, id_area, id_escala, fuente_oficial)`.
  9. `plan_mejoramiento` — Planes por colegio, área y año con `diagnostico_base` y `meta_cuantitativa`.
* **Nivel 3:**
  10. `estudiante_seudonimo` — Solo `id_estudiante_hash CHAR(64)` (SHA-256) e `id_cohorte`. *(Minimización estricta de privacidad: se eliminaron género y estrato).*
  11. `apoyo_institucional` — Subsidios/apoyos (pago inscripción Saber 11, financiación simulacros, etc.) con monto COP `DECIMAL(14,2)` y beneficiarios.
  12. `resultado_agregado_ie` — Resultados consolidados por colegio/cohorte cuando no existen microdatos individuales; incluye `cantidad_evaluados` para validar el umbral $k$.
  13. `seguimiento_actividad_plan` — Actividades y cortes de avance periódicos (`0.00` a `100.00`) sin sobrescribir avances anteriores.
* **Nivel 4:**
  14. `resultado_evaluacion` — Microdatos seudónimos con **PK Compuesta** `(id_estudiante_hash, id_instrumento, id_area)`, puntaje, percentil, nivel de desempeño, periodo, fecha de presentación y marca de registro inmutable.

### 4.2. Decisiones Clave ya Resueltas (No Rediseñar — Regla R14)
1. **3FN corregida en `promedio_nacional_ref`:** Se eliminó `id_instrumento` de esta tabla porque `id_instrumento -> id_escala` creaba una dependencia transitiva y ataba el referente nacional a un examen puntual. Ahora cruza directamente por año, área, escala y fuente.
2. **Doble nivel sin doble conteo:** `resultado_evaluacion` guarda microdatos seudónimos y `resultado_agregado_ie` guarda consolidados históricos sin microdatos. Las vistas/consultas **nunca** deben sumar ambos para la misma cohorte/instrumento/área.
3. **Política FK unificada:** Todas las 17 claves foráneas usan **`INT UNSIGNED`** (coincidente con las PKs subrogadas para evitar `errno: 150` en InnoDB) y **`ON DELETE RESTRICT ON UPDATE CASCADE`** para proteger la inmutabilidad histórica (`RN03`).
4. **Configuración real detectada en XAMPP (`C:\xampp\mysql\bin\my.ini`):**
   * Binario: `10.11.16-MariaDB` Win64 AMD64, puerto `3306`.
   * `my.ini` viene con `sql_mode=NO_ZERO_IN_DATE,NO_ZERO_DATE,NO_ENGINE_SUBSTITUTION` (no activa `STRICT_TRANS_TABLES`) y `collation-server=utf8mb4_general_ci`.
   * **Solución obligatoria en todos los scripts SQL:** Activar `SET SESSION sql_mode = 'STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,NO_ENGINE_SUBSTITUTION,ERROR_FOR_DIVISION_BY_ZERO';`, `SET time_zone = '-05:00';` y declarar explícitamente `CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci` y `ENGINE=InnoDB` en esquema y tablas.

---

## 5. Planificación Detallada de lo Que Toca Hacer Ahora

### Paso 1 (Inmediato): Aprobar la Fase 3 Física
* **Qué revisar:** Abrir `09_diccionario_fisico.csv`, `10_especificacion_fisica.md` y `11_verificacion_previa.md`.
* **Qué responder para aprobar:** Confirmar que los tipos físicos (`INT UNSIGNED`, `DECIMAL(6,2)`, `DECIMAL(14,2)`, `CHAR(64)`), el orden de creación de las 14 tablas y los 18 índices están correctos, y responder las 2 preguntas de control del cierre anterior:
  1. Por qué el rango de puntaje contra `escala_evaluacion` requiere Trigger y no `CHECK`.
  2. Por qué no se duplican índices sobre el prefijo izquierdo de una PK o `UNIQUE`.

### Paso 2: Entrega DDL Totalmente Documentado y Verificación en XAMPP
Una vez aprobada la Fase 3, generar y revisar los siguientes archivos **sin datos de prueba todavía**:
1. **`12a_inventario_documentacion.csv`**: Inventario completo de las 14 tablas, 89 columnas, PK, FK, UNIQUE, CHECK, DEFAULT y 18 índices, con su requisito (`Rxx`/`RNxx`) y comentario propuesto.
2. **`12_creacion_esquema_mariadb.sql`**:
   * `CREATE DATABASE IF NOT EXISTS repo_saber_siee_sm CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;` (separado/comentado como opción revisable).
   * Creación en 4 niveles con `COMMENT` nativos en todas las tablas, columnas e índices, más bloques de comentario SQL explicando cada PK, FK, UNIQUE, CHECK y DEFAULT.
   * Etiquetado inicialmente como `NO PROBADO EN SERVIDOR`.
3. **`12b_migracion_solo_comentarios_PENDIENTE.md`**: Como el proyecto parte de una base vacía nueva (sin esquema previo en producción), se documenta formalmente que la migración documental no aplica aún y qué pasos (`SHOW CREATE TABLE`, `MODIFY COLUMN` completo) se exigirían si existiera una BD previa.
4. **`12c_mejoras_diseno_no_aplicadas.md`**: Reporte separado (aunque diga *"Sin recomendaciones"* o liste mejoras futuras sin tocar el diseño aprobado, cumpliendo R14).
5. **`13_verificaciones_estructura_mariadb.sql`** y **`13a_comparacion_documental.md`**: Consultas reales contra `INFORMATION_SCHEMA.TABLES`, `INFORMATION_SCHEMA.COLUMNS`, `INFORMATION_SCHEMA.TABLE_CONSTRAINTS`, `INFORMATION_SCHEMA.STATISTICS`, `SHOW CREATE TABLE` y `SHOW FULL COLUMNS`.
6. **Ejecución real en XAMPP:**
   * Iniciar **MySQL (MariaDB)** desde el *XAMPP Control Panel*.
   * Ejecutar `12_creacion_esquema_mariadb.sql` y luego `13_verificaciones_estructura_mariadb.sql` (vía `C:\xampp\mysql\bin\mysql.exe -u root` o phpMyAdmin).
   * Guardar la evidencia real de ejecución para cambiar el estado a **`PROBADO EN SGBD`**.

### Paso 3: Objetos Programables Exigidos por la Guía del Profesor (Punto 4.3)
En un script SQL separado y aprobado (o integrado como extensión controlada antes de Fase 5, manteniendo separado el DDL estructural del DDL programable según prefiera el flujo):
* **1+ UDF (`fn_transformar_puntaje`):** Recibe puntaje, `id_escala_origen`, `id_escala_destino`, consulta `transformacion_escala` (`vigente = 1`) y retorna el puntaje homologado o `NULL`/señal de error si no hay transformación justificada (`RN04`).
* **2+ Triggers:**
  * `trg_res_validar_rango_ins` (y análogo en `resultado_agregado_ie`): `BEFORE INSERT` valida que `puntaje_obtenido` esté entre `valor_minimo` y `valor_maximo` de la escala del instrumento (`RN05`), lanzando `SIGNAL SQLSTATE '45000'` si falla.
  * `trg_res_inmutabilidad_upd` / `trg_res_inmutabilidad_del`: `BEFORE UPDATE` y `BEFORE DELETE` en `resultado_evaluacion` (y `resultado_agregado_ie` / `seguimiento_actividad_plan`) bloqueando sobrescrituras destructivas (`RN03`). *(Opcional: si se requiere bitácora de auditoría persistente en tabla propia, usar el cupo #15 creando `auditoria_eventos`, sin exceder nunca las 15 tablas).*
* **2+ Procedimientos Almacenados (SP):**
  * `sp_registrar_seguimiento_plan`: Inserta un nuevo corte en `seguimiento_actividad_plan` y actualiza `estado_plan` dentro de `START TRANSACTION` / `COMMIT` con `DECLARE EXIT HANDLER FOR SQLEXCEPTION ROLLBACK`.
  * `sp_registrar_apoyo_y_cohorte` (o `sp_consultar_reporte_ie_seguro`): Transacción controlada para registro institucional o emisión de reporte verificando `UMBRAL_MINIMO_K`.
* **3+ Vistas (`VIEW`):**
  * `vw_evolucion_ie_area_anio`: Evolución por institución, área y año filtrada por `HAVING COUNT(*) >= umbral_k` (`RN02`).
  * `vw_brecha_promedio_nacional`: Comparación frente a `promedio_nacional_ref` en igual escala (o transformada vía `fn_transformar_puntaje`).
  * `vw_impacto_simulacros_planes`: Correlación temporal entre simulacros, planes de mejora, apoyos y resultados Saber 11 posteriores.

### Paso 4: Fase 4 · DML Masivo Sintético Independiente (`14_` y `15_`)
* **Regla de volumen:**
  * Seleccionar **al menos 2 tablas principales de hechos/historial** con **10.000 filas sintéticas cada una** (propuesta recomendada: `resultado_evaluacion` con $\ge 10.000$ registros y `estudiante_seudonimo` —o `seguimiento_actividad_plan` si se justifica mejor como tabla de eventos; acordarlo antes de generar).
  * Catálogos pequeños (`area_evaluacion`, `escala_evaluacion`, `transformacion_escala`, `parametro_sistema`) con sus valores reales coherentes (no inflar catálogos artificialmente, R12); dimensiones/transacciones intermedias (`institucion_educativa`, `cohorte`, `plan_mejoramiento`, `apoyo_institucional`, `resultado_agregado_ie`) con volúmenes realistas ($\ge 50$ registros donde tenga sentido para cumplir también la guía del profesor).
* **Entregables:**
  * `14_generador_datos.py`: Script reproducible con semilla fija (`random.seed(...)`), hashes SHA-256 sintéticos ficticios, etiqueta **`SINTÉTICO — SOLO USO ACADÉMICO`**, respetando orden de padres antes que hijos y rangos válidos de cada escala.
  * `14_carga_datos_sinteticos_mariadb.sql`: DML puro (`INSERT` en lotes), **nunca mezclado con DDL**, sin `DROP`/`TRUNCATE`/`DELETE` ni `SET FOREIGN_KEY_CHECKS = 0`.
  * `15_verificaciones_carga_mariadb.sql`: `COUNT(*)` por tabla, verificación de 0 huérfanos, 0 duplicados, rangos válidos y cobertura de consultas.
* **Ejecución en XAMPP:** Cargar una sola vez sobre la BD de prueba y registrar los conteos reales observados.

### Paso 5: Fase 5 · Consultas Funcionales, Pruebas y Rendimiento (`16_` y `17_`)
* **`16_consultas_validacion_mariadb.sql`**: Mínimo **10 consultas reales diferenciadas** (las 4 preguntas del enunciado + `JOIN`, `GROUP BY`, `HAVING` para umbral $k$, subconsultas, uso de las vistas, casos límite como grupos $< k$ suprimidos, ausencia de datos, escalas sin transformación bloqueadas).
* **`17_plan_pruebas_y_rendimiento.md`**:
  * Casos de prueba positivos y negativos por cada regla crítica (`RN01`–`RN05`).
  * Salida real de **`EXPLAIN`** (y `ANALYZE` si aplica en MariaDB 10.11) sobre al menos 3 consultas analíticas pesadas sobre las $\ge 10.000$ filas, documentando filas examinadas, índices utilizados y tiempos reales medidos.

### Paso 6: Fase 6 · Auditoría, Memoria Técnica PDF, Git y Defensa Oral
* Actualizar matriz de trazabilidad completa (`Rxx | RNxx | conceptual | lógico | físico/DDL | DML | consulta/prueba | estado | evidencia`).
* Completar tabla de verificación **`E1`–`E20`** distinguiendo `PROPUESTO` / `REVISADO ESTÁTICAMENTE` / `PROBADO EN SGBD`.
* Consolidar la **Memoria Técnica en PDF** (siguiendo el Punto 6 de la guía del profesor: Introducción, Reglas de Negocio, Modelado Crow's Foot + Normalización, Diccionario de Datos, Implementación/Consultas/`EXPLAIN`, Conclusiones).
* Preparar **Repositorio Git** limpio (excluyendo archivos obsoletos) y repasar las **5 preguntas de defensa oral**.

---

## 6. Cómo Instruir a la IA si Continúan en una Nueva Conversación

Si tu compañero abre una sesión nueva con un asistente de IA, basta con decirle:

> *"Lee `PROMPT_MAESTRO_ADAPTADO.md` y `HANDOFF_CONTINUIDAD_PROYECTO.md` en esta carpeta. Las Fases 1 y 2 ya están aprobadas (14 tablas, modelo vigente en `01_`–`08_`), el motor confirmado es `10.11.16-MariaDB` en XAMPP (`C:\xampp`) y la Fase 3 física está redactada en `09_`–`11_`. Aprobamos la Fase 3 (o queremos ajustar X) y vamos a continuar estrictamente con el siguiente paso del Prompt Maestro y la Guía del Proyecto Integrador."*

Con eso, el compañero podrá retomar exactamente en el punto correcto sin perder contexto, sin rehacer trabajo y sin romper ninguna regla del profesor ni del Prompt Maestro.
