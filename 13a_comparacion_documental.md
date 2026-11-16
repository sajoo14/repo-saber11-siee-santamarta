# 13a · Comparación Documental y Evidencia de Verificación en Catálogo (Regla R16)

**Proyecto:** Repositorio Saber 11, Evaluaciones Internas (SIEE), Simulacros y Planes de Mejoramiento (Santa Marta)  
**Motor y Versión Ejecutados:** `10.4.32-MariaDB` / Compatible con `10.11.16-MariaDB` (XAMPP Win64 AMD64, `ENGINE=InnoDB`, `utf8mb4_unicode_ci`)  
**Base de Datos:** `repo_saber_siee_sm`  
**Estado Operativo (Regla R8):** **`PROBADO EN SGBD`** (Ejecución real y auditoría de catálogo en servidor MariaDB local)

---

## 1. Resumen Ejecutivo de Auditoría del Catálogo (`INFORMATION_SCHEMA`)

Tras ejecutar `12_creacion_esquema_mariadb.sql`, `12d_objetos_programables_mariadb.sql` y el script auditor `13_verificaciones_estructura_mariadb.sql` sobre la instancia local de MariaDB en XAMPP (`C:\xampp\mysql\bin\mysqld.exe`), se obtuvieron los siguientes resultados reales:

```text
+-----------+------------------+---------+----------------+-------+-------+-------+--------+------------+---------+-------------+-------+------+
| tablas_14 | tablas_sin_com_0 | cols_89 | cols_sin_com_0 | pk_14 | fk_17 | uq_11 | chk_52 | idx_sec_18 | views_3 | triggers_12 | udf_2 | sp_3 |
+-----------+------------------+---------+----------------+-------+-------+-------+--------+------------+---------+-------------+-------+------+
|        14 |                0 |      89 |              0 |    14 |    17 |    11 |     52 |         18 |       3 |          12 |     2 |    3 |
+-----------+------------------+---------+----------------+-------+-------+-------+--------+------------+---------+-------------+-------+------+
```

---

## 2. Matriz de Comparación Antes / Después y Planeado vs. Observado (Regla R16)

| Categoría de Objeto | Estado Previo (Esquema Vacío) | Diseño Físico Aprobado (`09_`, `10_`, `12a_`) | Observado en Catálogo MariaDB (`13_`) | Cobertura de `COMMENT` Persistente | Veredicto R16 |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Tablas base (`BASE TABLE`)** | 0 | 14 (`InnoDB`, `utf8mb4_unicode_ci`) | **14** (`14` con `TABLE_COMMENT`, `0` vacías) | **100 % (14/14)** nativo en `TABLES.TABLE_COMMENT` | **CONFORME** |
| **Columnas de tablas base** | 0 | 89 columnas distribuidas en 14 tablas | **89** (`89` con `COLUMN_COMMENT`, `0` vacías) | **100 % (89/89)** nativo en `COLUMNS.COLUMN_COMMENT` | **CONFORME** |
| **Claves Primarias (`PRIMARY KEY`)** | 0 | 14 (13 simples + 1 compuesta ternaria en `resultado_evaluacion`) | **14** | 100 % documentadas en SQL y `12a_` | **CONFORME** |
| **Claves Foráneas (`FOREIGN KEY`)** | 0 | 17 (`ON DELETE RESTRICT ON UPDATE CASCADE`) | **17** (`17` con `RESTRICT` / `CASCADE`) | 100 % documentadas en SQL y `12a_` | **CONFORME** |
| **Restricciones `UNIQUE`** | 0 | 11 (4 simples + 7 compuestas) | **11** | 100 % documentadas en SQL y `12a_` | **CONFORME** |
| **Restricciones `CHECK`** | 0 | 52 expresiones deterministas de dominio/rango | **52** activas en `CHECK_CONSTRAINTS` | 100 % documentadas en SQL y `12a_` | **CONFORME** |
| **Índices Secundarios (`NON_UNIQUE = 1`)** | 0 | 18 índices explícitos sin duplicar prefijos PK/UQ | **18** con `INDEX_COMMENT` | **100 % (18/18)** nativo en `STATISTICS.INDEX_COMMENT` | **CONFORME** |
| **Funciones Definidas por Usuario (`UDF`)** | 0 | 2 (`fn_transformar_puntaje`, `fn_clasificar_brecha_nacional`) | **2** | **100 % (2/2)** nativo en `ROUTINES.ROUTINE_COMMENT` | **CONFORME** |
| **Procedimientos Almacenados (`SP`)** | 0 | 3 (`sp_registrar_seguimiento_plan`, `sp_registrar_apoyo_institucional`, `sp_actualizar_parametro_sistema`) | **3** | **100 % (3/3)** nativo en `ROUTINES.ROUTINE_COMMENT` | **CONFORME** |
| **Disparadores (`TRIGGERS`)** | 0 | 12 (4 de validación/coherencia/vigencia + 6 de inmutabilidad `RN03` + 2 de auditoría de cambios) | **12** | 100 % documentados en SQL y `12a_` | **CONFORME** |
| **Vistas Analíticas (`VIEWS`)** | 0 | 3 (`vw_evolucion_ie_area_anio`, `vw_brecha_promedio_nacional`, `vw_impacto_simulacros_planes`) | **3** | 100 % documentadas en SQL y `12a_` | **CONFORME** |

---

## 3. Verificación Tabla por Tabla (Columnas, Claves, Índices y `TABLE_COMMENT`)

| Orden | Tabla | Columnas | PK | FK | UNIQUE | CHECK | Índices Secundarios | Motor / Collation | Comentario de Tabla Verificado en `INFORMATION_SCHEMA.TABLES` |
| :---: | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| 1 | `parametro_sistema` | 4 | 1 | 0 | 0 | 2 | 0 | `InnoDB` / `utf8mb4_unicode_ci` | `Parametros operativos configurables del sistema incluido el umbral minimo k (RN02) para supresion de grupos pequenos en reportes.` |
| 2 | `institucion_educativa` | 7 | 1 | 0 | 1 | 6 | 1 (`idx_ie_comuna`) | `InnoDB` / `utf8mb4_unicode_ci` | `Catalogo maestro de instituciones educativas oficiales del Distrito de Santa Marta identificadas por su codigo DANE (R01).` |
| 3 | `escala_evaluacion` | 6 | 1 | 0 | 1 | 4 | 0 | `InnoDB` / `utf8mb4_unicode_ci` | `Catalogo de escalas metricas de calificacion con rango valido cerrado [valor_minimo valor_maximo] y precision decimal (R02 RN05).` |
| 4 | `area_evaluacion` | 4 | 1 | 0 | 2 | 3 | 0 | `InnoDB` / `utf8mb4_unicode_ci` | `Catalogo de areas de conocimiento evaluadas en Saber 11 SIEE y simulacros (R02).` |
| 5 | `cohorte` | 5 | 1 | 1 | 1 | 3 | 1 (`idx_cohorte_anio`) | `InnoDB` / `utf8mb4_unicode_ci` | `Cohortes academicas anuales por institucion educativa y jornada escolar en Santa Marta (R01).` |
| 6 | `transformacion_escala` | 7 | 1 | 2 | 1 | 4 | 1 (`idx_trans_escala_destino`) | `InnoDB` / `utf8mb4_unicode_ci` | `Reglas de transformacion lineal explicita y justificada (P_dest = m * P_orig + b) entre escalas de evaluacion diferentes (R07 RN04).` |
| 7 | `instrumento_evaluacion` | 6 | 1 | 1 | 1 | 4 | 2 (`idx_inst_escala`, `idx_inst_tipo_periodo`) | `InnoDB` / `utf8mb4_unicode_ci` | `Instrumentos de evaluacion aplicados (SABER_11 SIEE SIMULACRO) con su escala metrica fuente emisora y periodo (R02).` |
| 8 | `promedio_nacional_ref` | 7 | 1 | 2 | 1 | 4 | 2 (`idx_ref_area`, `idx_ref_escala`) | `InnoDB` / `utf8mb4_unicode_ci` | `Promedios nacionales oficiales de referencia por anio vigencia area escala y fuente para analisis de brechas en 3FN (R04 D03).` |
| 9 | `plan_mejoramiento` | 8 | 1 | 2 | 1 | 5 | 2 (`idx_plan_ie_anio`, `idx_plan_area`) | `InnoDB` / `utf8mb4_unicode_ci` | `Planes de mejoramiento academico formulados por institucion educativa area y anio con linea base y meta cuantitativa (R06).` |
| 10 | `estudiante_seudonimo` | 2 | 1 | 1 | 0 | 1 | 1 (`idx_est_cohorte`) | `InnoDB` / `utf8mb4_unicode_ci` | `Registro seudonimizado de estudiantes mediante hash SHA-256 sin datos personales directos ni atributos demograficos (R03 RN01 D02).` |
| 11 | `apoyo_institucional` | 7 | 1 | 1 | 0 | 4 | 2 (`idx_apoyo_cohorte`, `idx_apoyo_fecha`) | `InnoDB` / `utf8mb4_unicode_ci` | `Apoyos institucionales y financieros (pago de inscripcion simulacros material capacitacion) asignados por cohorte (R05).` |
| 12 | `resultado_agregado_ie` | 10 | 1 | 3 | 1 | 5 | 2 (`idx_resag_instrumento`, `idx_resag_area`) | `InnoDB` / `utf8mb4_unicode_ci` | `Resultados consolidados por cohorte instrumento y area cuando no existen microdatos individuales con control de cantidad de evaluados (R03 RN02 RN03).` |
| 13 | `seguimiento_actividad_plan` | 7 | 1 | 1 | 1 | 3 | 1 (`idx_seg_plan_fecha`) | `InnoDB` / `utf8mb4_unicode_ci` | `Historial inmutable de actividades y cortes periodicos de avance porcentual de los planes de mejoramiento (R06 RN03).` |
| 14 | `resultado_evaluacion` | 9 | 1 | 3 | 0 | 4 | 3 (`idx_res_inst_area`, `idx_res_area`, `idx_res_periodo_fecha`) | `InnoDB` / `utf8mb4_unicode_ci` | `Microdatos historicos inmutables de resultados por estudiante seudonimo instrumento y area evaluada (R03 RN01 RN03 RN05).` |
| **TOTAL** | **14 tablas** | **89** | **14** | **17** | **11** | **52** | **18** | **100 % InnoDB** | **0 tablas sin comentario / 0 columnas sin comentario** |

---

## 4. Dictamen de Comparación Estructural (Regla R16)

* **Diferencias no documentales entre el diseño físico aprobado (`09_diccionario_fisico.csv`) y el esquema creado (`12_creacion_esquema_mariadb.sql`):** **0 diferencias**.
* **Estado de la puerta de control:** Aprobado técnicamente y **`PROBADO EN SGBD`**, listo para recibir la aprobación del usuario e iniciar la **Fase 4 (DML Masivo Sintético Independiente)**.
