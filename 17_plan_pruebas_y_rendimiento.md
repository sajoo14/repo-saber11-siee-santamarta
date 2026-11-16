# 17 · Plan de Pruebas de Reglas de Negocio y Análisis de Rendimiento con `EXPLAIN` (Fase 5)

**Proyecto:** Repositorio Saber 11, Evaluaciones Internas (SIEE), Simulacros y Planes de Mejoramiento (Santa Marta)  
**Motor y Versión Ejecutados:** `10.4.32-MariaDB` / Compatible con `10.11.16-MariaDB` (XAMPP Win64 AMD64, `ENGINE=InnoDB`, `utf8mb4_unicode_ci`)  
**Volumen de Datos bajo Prueba:** **25.951 registros totales** (`12.000` en `resultado_evaluacion`, `10.000` en `seguimiento_actividad_plan`, `3.015` en `estudiante_seudonimo`)  
**Estado Operativo (Regla R8):** **`PROBADO EN SGBD`** (Pruebas positivas/negativas, `EXPLAIN` y tiempos medidos en el servidor MariaDB local)

---

## 1. Matriz de Pruebas Positivas y Negativas por Regla Crítica (`RN01`–`RN05` y SPs)

Todas las pruebas se ejecutaron sobre la base de datos poblada `repo_saber_siee_sm` sin alterar ni corromper registros ajenos (las pruebas negativas fueron rechazadas preventivamente por `CHECK` o `BEFORE TRIGGER` / `ROLLBACK` antes de persistir):

| ID Prueba | Regla / Requisito | Tipo | Caso de Prueba y Datos Ficticios de Entrada | Sentencia SQL Ejecutada | Resultado Esperado | Resultado Real Observado en MariaDB | Estado |
| :---: | :---: | :---: | :--- | :--- | :--- | :--- | :---: |
| **P-01** | `RN01` / `R03` (Seudonimización) | **Positiva** | Inserción de 3.015 estudiantes con hash hexadecimal SHA-256 de 64 caracteres. | `INSERT INTO estudiante_seudonimo ...` (lotes en `14_` + consulta `15_`) | Acepta las 3.015 filas; `hashes_invalidos_esp_0 = 0`. | **3.015 filas insertadas**, `0` hashes inválidos. | **PROBADO EN SGBD (OK)** |
| **N-01** | `RN01` / `R03` (Seudonimización) | **Negativa** | Intentar insertar un documento y nombre real en claro (`'TI_1082999888_JUAN_PEREZ'`). | `INSERT INTO estudiante_seudonimo (id_estudiante_hash, id_cohorte) VALUES ('TI_1082999888_JUAN_PEREZ', 1);` | Rechazo por restricción `CHECK chk_est_hash_hex`. | `ERROR 4025 (23000): CONSTRAINT chk_est_hash_hex failed for repo_saber_siee_sm.estudiante_seudonimo` | **PROBADO EN SGBD (OK)** |
| **P-02** | `RN02` / `R07` ($k$-anonimato) | **Positiva** | Consulta de cohortes regulares con $n = 20 \ge k = 10$ en `vw_evolucion_ie_area_anio`. | `SELECT COUNT(*) FROM vw_evolucion_ie_area_anio;` | Publica los 600 grupos que cumplen $n \ge 10$. | **600 filas publicadas** en la vista analítica. | **PROBADO EN SGBD (OK)** |
| **N-02** | `RN02` / `R07` ($k$-anonimato) | **Negativa (Frontera)** | Verificar que las 3 cohortes nocturnas pequeñas ($n = 5 < 10$) sean suprimidas de la vista pública. | Consulta `C07` en `16_consultas_validacion_mariadb.sql`. | `evaluados_reales = 5`, `dictamen = SUPRIMIDO_POR_RN02`, `apariciones_en_vista_publica = 0`. | **3 cohortes detectadas y suprimidas (`0` expuestas)**. | **PROBADO EN SGBD (OK)** |
| **P-03** | `RN03` / `R06` (Inmutabilidad e historial) | **Positiva** | Conservación de 33–34 cortes sucesivos por plan en `seguimiento_actividad_plan` sin sobrescribir. | Consulta `C09` en `16_consultas_validacion_mariadb.sql`. | Conserva los 10.000 cortes desde `3.03%` hasta `100.00%`. | **10.000 cortes conservados** con trazabilidad de fecha inicial y final. | **PROBADO EN SGBD (OK)** |
| **N-03a** | `RN03` / `R03` (Inmutabilidad `UPDATE`) | **Negativa** | Intentar sobrescribir con `UPDATE` el puntaje de un resultado histórico en `resultado_evaluacion`. | `UPDATE resultado_evaluacion SET puntaje_obtenido = 99.00 WHERE id_instrumento = 3 AND id_area = 1 LIMIT 1;` | Rechazo por trigger `trg_res_inmutabilidad_upd` (`SQLSTATE '45000'`). | `ERROR 1644 (45000): RN03 Violada: Los resultados historicos individuales en resultado_evaluacion son inmutables y no pueden sobrescribirse.` | **PROBADO EN SGBD (OK)** |
| **N-03b** | `RN03` / `R06` (Inmutabilidad `DELETE`) | **Negativa** | Intentar eliminar con `DELETE` un corte histórico en `seguimiento_actividad_plan`. | `DELETE FROM seguimiento_actividad_plan WHERE id_seguimiento = 1;` | Rechazo por trigger `trg_seg_inmutabilidad_del` (`SQLSTATE '45000'`). | `ERROR 1644 (45000): RN03 Violada: Prohibido eliminar cortes historicos de seguimiento_actividad_plan.` | **PROBADO EN SGBD (OK)** |
| **P-04** | `RN04` / `R07` (Transformación de escalas) | **Positiva** | Convertir nota `4.00` de `SIEE_1_5` (`id_escala = 3`) a `ICFES_AREA_0_100` (`id_escala = 1`). | `SELECT fn_transformar_puntaje(4.00, 3, 1);` (Consulta `C08`) | Retorna `75.00` ($25 \times 4.00 - 25 = 75.00$). | **`75.00` (`HOMOLOGACION_AUTORIZADA`)**. | **PROBADO EN SGBD (OK)** |
| **N-04** | `RN04` / `R07` (Bloqueo sin regla vigente) | **Negativa** | Intentar convertir desde `PORCENTAJE_EXPERIMENTAL_0_200` (`id_escala = 6`, `vigente = 0`) hacia `id_escala = 1`. | `SELECT fn_transformar_puntaje(4.00, 6, 1);` (Consulta `C08`) | Retorna `NULL` impidiendo restar escalas sin regla vigente. | **`NULL` (`BLOQUEADO_POR_RN04`)**. | **PROBADO EN SGBD (OK)** |
| **P-05** | `RN05` / `R02` (Rango válido según escala) | **Positiva** | Inserción de 12.000 microdatos dentro de `[0, 100]` (enteros) para Saber 11/Simulacro y `[1.00, 5.00]` (decimales) para SIEE. | Carga `14_` + verificación `15_`. | `violaciones_rango_microdatos_esp_0 = 0`. | **12.000 filas válidas (`0` violaciones)**. | **PROBADO EN SGBD (OK)** |
| **N-05a** | `RN05` / `R02` (Exceso de cota superior) | **Negativa** | Intentar insertar puntaje `150.00` en un instrumento con escala `ICFES_AREA_0_100` (`[0.00, 100.00]`). | `INSERT INTO resultado_evaluacion ... SELECT id_estudiante_hash, 3, 5, 150.00, '2022-2', '2022-08-18' ...` | Rechazo por trigger `trg_res_validar_rango_ins` (`SQLSTATE '45000'`). | `ERROR 1644 (45000): RN05 Violada: puntaje_obtenido fuera del rango [valor_minimo, valor_maximo] de la escala del instrumento.` | **PROBADO EN SGBD (OK)** |
| **N-05b** | `RN05` / `R02` (Decimales en escala entera) | **Negativa** | Intentar insertar puntaje fraccionario `55.75` en instrumento con `permite_decimales = 0`. | `INSERT INTO resultado_evaluacion ... SELECT id_estudiante_hash, 3, 5, 55.75, '2022-2', '2022-08-18' ...` | Rechazo por trigger `trg_res_validar_rango_ins` (`SQLSTATE '45000'`). | `ERROR 1644 (45000): RN05 Violada: La escala del instrumento no admite fracciones decimales en puntaje_obtenido.` | **PROBADO EN SGBD (OK)** |
| **N-05c** | `R01` / `R03` (Coherencia temporal estudiante-cohorte) | **Negativa** | Intentar insertar un examen con `fecha_presentacion = '2019-08-18'` a un estudiante de una cohorte `2022`. | `INSERT INTO resultado_evaluacion ... SELECT id_estudiante_hash, 3, 5, 60.00, '2019-2', '2019-08-18' FROM estudiante_seudonimo WHERE id_cohorte=1 LIMIT 1;` | Rechazo por trigger `trg_res_validar_rango_ins` (`SQLSTATE '45000'`). | `ERROR 1644 (45000): Coherencia Temporal Violada: El anio de fecha_presentacion no coincide con el anio_lectivo de la cohorte del estudiante.` | **PROBADO EN SGBD (OK)** |
| **N-06** | `R05` / `R01` (Transacción y cupo en SP) | **Negativa** | Invocar `sp_registrar_apoyo_institucional` con `9999` beneficiarios superando `total_matriculados` de la cohorte. | `CALL sp_registrar_apoyo_institucional(1, 'PAGO_INSCRIPCION', 'ALCALDIA', 5000000.00, 9999, '2024-05-01', @id);` | Ejecuta `ROLLBACK` en el `EXIT HANDLER` y lanza `SQLSTATE '45000'`. | `ERROR 1644 (45000): R05 Error: La cantidad de beneficiarios cubiertos supera el total de matriculados de la cohorte.` | **PROBADO EN SGBD (OK)** |
| **P-06** | `R06` / `RN03` (Trigger de Auditoría) | **Positiva** | Actualizar `meta_cuantitativa` de un plan en `plan_mejoramiento` y comprobar la traza automática en `seguimiento_actividad_plan`. | `UPDATE plan_mejoramiento SET meta_cuantitativa = meta_cuantitativa + 0.50 WHERE id_plan = 1;` | El trigger `trg_plan_auditoria_upd` inserta una fila inmutable con `CURRENT_USER()`, `OLD` y `NEW`. | **Traza de auditoría creada automáticamente** con usuario y valores anterior/nuevo. | **PROBADO EN SGBD (OK)** |
| **N-07** | `RN02` / `R07` (Protección de $k$-anonimato en SP y Trigger) | **Negativa** | Intentar rebajar `UMBRAL_MINIMO_K` a `'3'` ($< 5$) mediante `sp_actualizar_parametro_sistema`. | `CALL sp_actualizar_parametro_sistema('UMBRAL_MINIMO_K', '3', @ant);` | Rechazo por `trg_param_auditoria_upd` y `ROLLBACK` preservando `10`. | `ERROR 1644 (45000): RN02 Violada: El parametro UMBRAL_MINIMO_K no puede ser inferior a 5 evaluados por proteccion de k-anonimato estudiantil.` | **PROBADO EN SGBD (OK)** |

---

### 1.2. Matriz de las 8 Pruebas de Seguridad y Privilegios por Rol (`15b_roles_y_seguridad_mariadb.sql`)

Se verificaron en sesiones independientes de MariaDB los **4 roles nativos** y sus **4 cuentas ficticias de prueba** (1 prueba positiva de acceso permitido y 1 prueba negativa de acceso denegado por cada rol):

| ID Prueba | Rol MariaDB | Usuario Ficticio | Tipo | Operación Ejecutada | Resultado Real Observado en MariaDB | Estado |
| :---: | :--- | :--- | :---: | :--- | :--- | :---: |
| **S-01+** | `rol_administrador_datos` | `usr_admin_sm` | **Positiva** | `SELECT CURRENT_ROLE(), clave_parametro, valor_parametro FROM parametro_sistema WHERE clave_parametro='UMBRAL_MINIMO_K';` | Retorna `rol_administrador_datos \| UMBRAL_MINIMO_K \| 10`. | **PROBADO EN SGBD (OK)** |
| **S-01-** | `rol_administrador_datos` | `usr_admin_sm` | **Negativa** | `SELECT COUNT(*) FROM resultado_evaluacion;` (Intento de leer microdatos crudos) | `ERROR 1142 (42000): SELECT command denied to user 'usr_admin_sm'@'localhost' for table 'resultado_evaluacion'` | **PROBADO EN SGBD (OK)** |
| **S-02+** | `rol_operador_academico` | `usr_operador_sm` | **Positiva** | `SELECT CURRENT_ROLE(), COUNT(*) AS total_planes FROM plan_mejoramiento;` | Retorna `rol_operador_academico \| 300`. | **PROBADO EN SGBD (OK)** |
| **S-02-** | `rol_operador_academico` | `usr_operador_sm` | **Negativa** | `UPDATE escala_evaluacion SET valor_maximo=200 WHERE id_escala=1;` (Intento de alterar catálogo de escalas) | `ERROR 1142 (42000): UPDATE command denied to user 'usr_operador_sm'@'localhost' for table 'escala_evaluacion'` | **PROBADO EN SGBD (OK)** |
| **S-03+** | `rol_control_evaluacion` | `usr_evaluacion_sm` | **Positiva** | `SELECT CURRENT_ROLE(), fn_transformar_puntaje(4.00, 3, 1) AS homologado;` | Retorna `rol_control_evaluacion \| 75.00`. | **PROBADO EN SGBD (OK)** |
| **S-03-** | `rol_control_evaluacion` | `usr_evaluacion_sm` | **Negativa** | `UPDATE parametro_sistema SET valor_parametro='2' WHERE clave_parametro='UMBRAL_MINIMO_K';` | `ERROR 1142 (42000): UPDATE command denied to user 'usr_evaluacion_sm'@'localhost' for table 'parametro_sistema'` | **PROBADO EN SGBD (OK)** |
| **S-04+** | `rol_auditor_consulta` | `usr_auditor_sm` | **Positiva** | `SELECT CURRENT_ROLE(), COUNT(*) AS grupos_publicables FROM vw_evolucion_ie_area_anio;` | Retorna `rol_auditor_consulta \| 600` (solo grupos con $n \ge 10$). | **PROBADO EN SGBD (OK)** |
| **S-04-** | `rol_auditor_consulta` | `usr_auditor_sm` | **Negativa** | `SELECT * FROM estudiante_seudonimo LIMIT 1;` (Intento de evadir vista pública y consultar microdatos) | `ERROR 1142 (42000): SELECT command denied to user 'usr_auditor_sm'@'localhost' for table 'estudiante_seudonimo'` | **PROBADO EN SGBD (OK)** |

---

## 2. Análisis de Planes de Ejecución (`EXPLAIN`) y Rendimiento Real Medido

Se ejecutó `EXPLAIN` y se midió el tiempo real de respuesta con precisión de microsegundos (`NOW(6)` / `TIMESTAMPDIFF`) sobre **4 consultas analíticas representativas** en el servidor local `10.4.32-MariaDB`:

### 2.1. Consulta Analítica 1: Evolución Interanual por Institución, Área y Año (`C01` sobre 12.000 microdatos)

* **Tiempo real medido en servidor:** **`66,480 ms`** (`0,0665 s`) para agregar y filtrar las 300 combinaciones publicables.
* **Salida real de `EXPLAIN`:**

```text
+------+-------------+-------+--------+----------------------------------------+----------------------------+---------+------------------------------------------+------+----------------------------------------------+
| id   | select_type | table | type   | possible_keys                          | key                        | key_len | ref                                      | rows | Extra                                        |
+------+-------------+-------+--------+----------------------------------------+----------------------------+---------+------------------------------------------+------+----------------------------------------------+
|    1 | SIMPLE      | ie    | index  | PRIMARY                                | uq_ie_nombre               | 602     | NULL                                     | 50   | Using index; Using temporary; Using filesort |
|    1 | SIMPLE      | c     | ref    | PRIMARY,uq_cohorte_ie_anio_jornada     | uq_cohorte_ie_anio_jornada | 50      | repo_saber_siee_sm.ie.codigo_dane        | 1    | Using index                                  |
|    1 | SIMPLE      | es    | ref    | PRIMARY,idx_est_cohorte                | idx_est_cohorte            | 4       | repo_saber_siee_sm.c.id_cohorte          | 9    | Using index                                  |
|    1 | SIMPLE      | re    | ref    | PRIMARY,idx_res_inst_area,idx_res_area | PRIMARY                    | 256     | repo_saber_siee_sm.es.id_estudiante_hash | 1    |                                              |
|    1 | SIMPLE      | a     | eq_ref | PRIMARY                                | PRIMARY                    | 4       | repo_saber_siee_sm.re.id_area            | 1    |                                              |
|    1 | SIMPLE      | i     | eq_ref | PRIMARY,idx_inst_tipo_periodo          | PRIMARY                    | 4       | repo_saber_siee_sm.re.id_instrumento     | 1    | Using where                                  |
+------+-------------+-------+--------+----------------------------------------+----------------------------+---------+------------------------------------------+------+----------------------------------------------+
```

* **Interpretación técnica del plan:**
  * El optimizador de MariaDB **evita cualquier `ALL` (Full Table Scan)**.
  * Recorre las 50 instituciones en memoria desde el índice `uq_ie_nombre` (`Using index`), salta por prefijo izquierdo a `uq_cohorte_ie_anio_jornada` (`type = ref`, `rows = 1`, `Using index` — validando la decisión de Fase 3 de no duplicar un índice sobre `cohorte.codigo_dane`), enlaza a `estudiante_seudonimo` mediante `idx_est_cohorte` (`Using index`), accede al índice agrupado `PRIMARY` de `resultado_evaluacion` por su primer componente (`id_estudiante_hash`) y resuelve `area_evaluacion` e `instrumento_evaluacion` con búsqueda única `eq_ref` (`rows = 1`).

---

### 2.2. Consulta Analítica 2: Historial de Seguimiento de Planes por Institución y Año (`C09` sobre 10.000 cortes)

* **Tiempo real medido en servidor:** **`1,109 ms`** (`0,0011 s`).
* **Salida real de `EXPLAIN`:**

```text
+------+-------------+-------+--------+----------------------------------------+--------------------+---------+-------------------------------+------+---------------------------------+
| id   | select_type | table | type   | possible_keys                          | key                | key_len | ref                           | rows | Extra                           |
+------+-------------+-------+--------+----------------------------------------+--------------------+---------+-------------------------------+------+---------------------------------+
|    1 | SIMPLE      | ie    | const  | PRIMARY                                | PRIMARY            | 50      | const                         | 1    | Using temporary; Using filesort |
|    1 | SIMPLE      | pm    | ref    | PRIMARY,idx_plan_ie_anio,idx_plan_area | idx_plan_ie_anio   | 52      | const,const                   | 2    | Using index condition           |
|    1 | SIMPLE      | a     | eq_ref | PRIMARY                                | PRIMARY            | 4       | repo_saber_siee_sm.pm.id_area | 1    |                                 |
|    1 | SIMPLE      | sap   | ref    | idx_seg_plan_fecha                     | idx_seg_plan_fecha | 4       | repo_saber_siee_sm.pm.id_plan | 16   | Using index                     |
+------+-------------+-------+--------+----------------------------------------+--------------------+---------+-------------------------------+------+---------------------------------+
```

* **Interpretación técnica del plan:**
  * Resuelve `institucion_educativa` como constante (`type = const`, `rows = 1`).
  * Filtra `plan_mejoramiento` con el índice compuesto `idx_plan_ie_anio (codigo_dane, anio_implementacion)` aplicando *Index Condition Pushdown* (`Using index condition`, `rows = 2`).
  * En la tabla de **10.000 filas** (`seguimiento_actividad_plan`), el índice compuesto `idx_seg_plan_fecha (id_plan, fecha_seguimiento)` actúa como **índice cubriente (`Using index`)**, examinando apenas ~16 entradas de hoja B-Tree por plan sin leer las páginas de datos de la tabla.

---

### 2.3. Consulta Analítica 3: Desconexión SIEE vs. Saber 11 con UDF `fn_transformar_puntaje` (`C06`)

* **Tiempo real medido en servidor:** **`137,715 ms`** (`0,1377 s`).
* **Salida real de `EXPLAIN`:**

```text
+------+-------------+----------+--------+-----------------------------------------------------+----------------------------+---------+--------------------------------------------+------+--------------------------+
| id   | select_type | table    | type   | possible_keys                                       | key                        | key_len | ref                                        | rows | Extra                    |
+------+-------------+----------+--------+-----------------------------------------------------+----------------------------+---------+--------------------------------------------+------+--------------------------+
|    1 | SIMPLE      | ie       | index  | PRIMARY                                             | PRIMARY                    | 50      | NULL                                       | 50   | Using index              |
|    1 | SIMPLE      | c        | ref    | PRIMARY,uq_cohorte_ie_anio_jornada,idx_cohorte_anio | uq_cohorte_ie_anio_jornada | 52      | repo_saber_siee_sm.ie.codigo_dane,const    | 1    | Using index              |
|    1 | SIMPLE      | es       | ref    | PRIMARY,idx_est_cohorte                             | idx_est_cohorte            | 4       | repo_saber_siee_sm.c.id_cohorte            | 9    | Using index              |
|    1 | SIMPLE      | re_saber | ref    | PRIMARY,idx_res_inst_area,idx_res_area              | PRIMARY                    | 256     | repo_saber_siee_sm.es.id_estudiante_hash   | 1    | Using where              |
|    1 | SIMPLE      | i_sab    | eq_ref | PRIMARY,idx_inst_tipo_periodo                       | PRIMARY                    | 4       | repo_saber_siee_sm.re_saber.id_instrumento | 1    | Using where              |
|    1 | SIMPLE      | re_siee  | ref    | PRIMARY,idx_res_inst_area,idx_res_area              | PRIMARY                    | 256     | repo_saber_siee_sm.es.id_estudiante_hash   | 1    | Using where              |
|    1 | SIMPLE      | i_sie    | ref    | PRIMARY,idx_inst_tipo_periodo                       | idx_inst_tipo_periodo      | 82      | const                                      | 18   | Using where; Using index |
+------+-------------+----------+--------+-----------------------------------------------------+----------------------------+---------+--------------------------------------------+------+--------------------------+
```

* **Interpretación técnica del plan:**
  * Realiza un *Self-Join* sobre `resultado_evaluacion` (`re_saber` y `re_siee`) para el mismo `id_estudiante_hash` e `id_area`, aprovechando en ambos lados la clave primaria agrupada (`PRIMARY`, `rows = 1`) y el índice compuesto `idx_inst_tipo_periodo` (`Using where; Using index`).

---

### 2.4. Consulta Analítica 4: Consolidados Institucionales con Verificación `NOT EXISTS` de No Doble Conteo (`C10`)

* **Tiempo real medido en servidor:** **`27,109 ms`** (`0,0271 s`).
* **Salida real de `EXPLAIN`:**

```text
+------+--------------------+-------+--------+-----------------------------------------------------------------+-----------------+---------+----------------------------------------------------+------+-------------+
| id   | select_type        | table | type   | possible_keys                                                   | key             | key_len | ref                                                | rows | Extra       |
+------+--------------------+-------+--------+-----------------------------------------------------------------+-----------------+---------+----------------------------------------------------+------+-------------+
|    1 | PRIMARY            | a     | index  | PRIMARY                                                         | uq_area_codigo  | 42      | NULL                                               | 6    | Using index |
|    1 | PRIMARY            | ra    | ref    | uq_resag_coh_inst_area_per,idx_resag_instrumento,idx_resag_area | idx_resag_area  | 4       | repo_saber_siee_sm.a.id_area                       | 12   | Using where |
|    1 | PRIMARY            | i     | eq_ref | PRIMARY                                                         | PRIMARY         | 4       | repo_saber_siee_sm.ra.id_instrumento               | 1    |             |
|    1 | PRIMARY            | c     | eq_ref | PRIMARY,uq_cohorte_ie_anio_jornada                              | PRIMARY         | 4       | repo_saber_siee_sm.ra.id_cohorte                   | 1    |             |
|    1 | PRIMARY            | ie    | eq_ref | PRIMARY                                                         | PRIMARY         | 50      | repo_saber_siee_sm.c.codigo_dane                   | 1    | Using index |
|    2 | DEPENDENT SUBQUERY | es    | ref    | PRIMARY,idx_est_cohorte                                         | idx_est_cohorte | 4       | func                                               | 9    | Using index |
|    2 | DEPENDENT SUBQUERY | re    | eq_ref | PRIMARY,idx_res_inst_area,idx_res_area,idx_res_periodo_fecha    | PRIMARY         | 264     | repo_saber_siee_sm.es.id_estudiante_hash,func,func | 1    | Using index |
+------+--------------------+-------+--------+-----------------------------------------------------------------+-----------------+---------+----------------------------------------------------+------+-------------+
```

* **Interpretación técnica del plan:**
  * En la subconsulta dependiente (`NOT EXISTS`), el optimizador utiliza `idx_est_cohorte` (`Using index`) y la clave primaria compuesta completa de 3 columnas de `resultado_evaluacion` (`key = PRIMARY`, `key_len = 264` bytes = `256 + 4 + 4`, `type = eq_ref`, `rows = 1`, `Using index`).

---

## 3. Conclusión de Optimización de Índices

Los **18 índices secundarios** y las **9 claves `UNIQUE`** diseñados en la Fase 3 cubrieron el 100 % de los predicados de unión (`JOIN`), filtrado (`WHERE`) y agrupación (`GROUP BY`) de las consultas analíticas con tiempos de respuesta entre **`1,1 ms` y `137,7 ms`**, sin requerir añadir ni eliminar índices sobre el diseño físico aprobado.
