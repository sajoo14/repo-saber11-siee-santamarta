/* =====================================================================================
 * PROYECTO:       Repositorio de Evolución Saber 11, Evaluaciones Internas (SIEE),
 *                 Simulacros y Planes de Mejoramiento (Colegios Oficiales Santa Marta)
 * ARCHIVO:        13_verificaciones_estructura_mariadb.sql
 * SGBD / MOTOR:   MariaDB 10.4.32 / 10.11.16 (XAMPP Win64 AMD64)
 * BASE DE DATOS:  repo_saber_siee_sm
 * FECHA:          2026-11-15
 * PROPÓSITO:      Auditar en el catálogo del motor (INFORMATION_SCHEMA, SHOW CREATE TABLE
 *                 y SHOW FULL COLUMNS) la creación exacta de los objetos estructurales,
 *                 programables y documentales conforme a la Regla R16.
 * ESTADO ACTUAL:  PROBADO EN SGBD
 * ===================================================================================== */

USE repo_saber_siee_sm;

-- -------------------------------------------------------------------------------------
-- 1. RESUMEN EJECUTIVO DE CONTEO DE OBJETOS Y COBERTURA DOCUMENTAL
-- -------------------------------------------------------------------------------------
SELECT
    (SELECT COUNT(*)
       FROM INFORMATION_SCHEMA.TABLES
      WHERE TABLE_SCHEMA = 'repo_saber_siee_sm'
        AND TABLE_TYPE = 'BASE TABLE')                         AS total_tablas_base_esp_14,
    (SELECT COUNT(*)
       FROM INFORMATION_SCHEMA.TABLES
      WHERE TABLE_SCHEMA = 'repo_saber_siee_sm'
        AND TABLE_TYPE = 'BASE TABLE'
        AND TRIM(IFNULL(TABLE_COMMENT, '')) = '')              AS tablas_sin_comentario_esp_0,
    (SELECT COUNT(*)
       FROM INFORMATION_SCHEMA.COLUMNS c
       INNER JOIN INFORMATION_SCHEMA.TABLES t
               ON t.TABLE_SCHEMA = c.TABLE_SCHEMA
              AND t.TABLE_NAME   = c.TABLE_NAME
      WHERE c.TABLE_SCHEMA = 'repo_saber_siee_sm'
        AND t.TABLE_TYPE   = 'BASE TABLE')                     AS total_columnas_base_esp_89,
    (SELECT COUNT(*)
       FROM INFORMATION_SCHEMA.COLUMNS c
       INNER JOIN INFORMATION_SCHEMA.TABLES t
               ON t.TABLE_SCHEMA = c.TABLE_SCHEMA
              AND t.TABLE_NAME   = c.TABLE_NAME
      WHERE c.TABLE_SCHEMA = 'repo_saber_siee_sm'
        AND t.TABLE_TYPE   = 'BASE TABLE'
        AND TRIM(IFNULL(c.COLUMN_COMMENT, '')) = '')           AS columnas_sin_comentario_esp_0,
    (SELECT COUNT(*)
       FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
      WHERE TABLE_SCHEMA = 'repo_saber_siee_sm'
        AND CONSTRAINT_TYPE = 'PRIMARY KEY')                   AS total_pk_esp_14,
    (SELECT COUNT(*)
       FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
      WHERE TABLE_SCHEMA = 'repo_saber_siee_sm'
        AND CONSTRAINT_TYPE = 'FOREIGN KEY')                   AS total_fk_esp_17,
    (SELECT COUNT(*)
       FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
      WHERE TABLE_SCHEMA = 'repo_saber_siee_sm'
        AND CONSTRAINT_TYPE = 'UNIQUE')                        AS total_unique_esp_9,
    (SELECT COUNT(*)
       FROM INFORMATION_SCHEMA.CHECK_CONSTRAINTS
      WHERE CONSTRAINT_SCHEMA = 'repo_saber_siee_sm')          AS total_check_esp_52,
    (SELECT COUNT(DISTINCT CONCAT(TABLE_NAME, '.', INDEX_NAME))
       FROM INFORMATION_SCHEMA.STATISTICS
      WHERE TABLE_SCHEMA = 'repo_saber_siee_sm'
        AND NON_UNIQUE = 1)                                    AS total_indices_secundarios_esp_18,
    (SELECT COUNT(*)
       FROM INFORMATION_SCHEMA.VIEWS
      WHERE TABLE_SCHEMA = 'repo_saber_siee_sm')               AS total_vistas_esp_3,
    (SELECT COUNT(*)
       FROM INFORMATION_SCHEMA.TRIGGERS
      WHERE TRIGGER_SCHEMA = 'repo_saber_siee_sm')             AS total_triggers_esp_9,
    (SELECT COUNT(*)
       FROM INFORMATION_SCHEMA.ROUTINES
      WHERE ROUTINE_SCHEMA = 'repo_saber_siee_sm'
        AND ROUTINE_TYPE = 'FUNCTION')                         AS total_udf_esp_1,
    (SELECT COUNT(*)
       FROM INFORMATION_SCHEMA.ROUTINES
      WHERE ROUTINE_SCHEMA = 'repo_saber_siee_sm'
        AND ROUTINE_TYPE = 'PROCEDURE')                        AS total_sp_esp_2;

-- -------------------------------------------------------------------------------------
-- 2. VERIFICACIÓN DE LAS 14 TABLAS BASE: MOTOR, COLLATION Y TABLE_COMMENT
-- -------------------------------------------------------------------------------------
SELECT
    TABLE_NAME,
    ENGINE,
    TABLE_COLLATION,
    CHAR_LENGTH(TABLE_COMMENT) AS longitud_comentario,
    TABLE_COMMENT
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'repo_saber_siee_sm'
  AND TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME;

-- -------------------------------------------------------------------------------------
-- 3. VERIFICACIÓN DE LAS 82 COLUMNAS: TIPO, NULABILIDAD, DEFAULT, EXTRA Y COLUMN_COMMENT
-- -------------------------------------------------------------------------------------
SELECT
    c.TABLE_NAME,
    c.ORDINAL_POSITION,
    c.COLUMN_NAME,
    c.COLUMN_TYPE,
    c.IS_NULLABLE,
    c.COLUMN_DEFAULT,
    c.EXTRA,
    c.COLLATION_NAME,
    c.COLUMN_COMMENT
FROM INFORMATION_SCHEMA.COLUMNS c
INNER JOIN INFORMATION_SCHEMA.TABLES t
        ON t.TABLE_SCHEMA = c.TABLE_SCHEMA
       AND t.TABLE_NAME   = c.TABLE_NAME
WHERE c.TABLE_SCHEMA = 'repo_saber_siee_sm'
  AND t.TABLE_TYPE   = 'BASE TABLE'
ORDER BY c.TABLE_NAME, c.ORDINAL_POSITION;

-- -------------------------------------------------------------------------------------
-- 4. VERIFICACIÓN DE LAS 18 CLAVES FORÁNEAS Y SUS POLÍTICAS ON DELETE / ON UPDATE
-- -------------------------------------------------------------------------------------
SELECT
    rc.TABLE_NAME              AS tabla_hija,
    rc.CONSTRAINT_NAME         AS nombre_fk,
    kcu.COLUMN_NAME            AS columna_hija,
    rc.REFERENCED_TABLE_NAME   AS tabla_padre,
    kcu.REFERENCED_COLUMN_NAME AS columna_padre,
    rc.UPDATE_RULE             AS politica_on_update,
    rc.DELETE_RULE             AS politica_on_delete
FROM INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS rc
INNER JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu
        ON kcu.CONSTRAINT_SCHEMA = rc.CONSTRAINT_SCHEMA
       AND kcu.CONSTRAINT_NAME   = rc.CONSTRAINT_NAME
       AND kcu.TABLE_NAME        = rc.TABLE_NAME
WHERE rc.CONSTRAINT_SCHEMA = 'repo_saber_siee_sm'
ORDER BY rc.TABLE_NAME, rc.CONSTRAINT_NAME;

-- -------------------------------------------------------------------------------------
-- 5. VERIFICACIÓN DE LAS 41 RESTRICCIONES CHECK PERSISTIDAS EN EL CATÁLOGO
-- -------------------------------------------------------------------------------------
SELECT
    TABLE_NAME,
    CONSTRAINT_NAME,
    CHECK_CLAUSE
FROM INFORMATION_SCHEMA.CHECK_CONSTRAINTS
WHERE CONSTRAINT_SCHEMA = 'repo_saber_siee_sm'
ORDER BY TABLE_NAME, CONSTRAINT_NAME;

-- -------------------------------------------------------------------------------------
-- 6. VERIFICACIÓN DE ÍNDICES (PK, UNIQUE Y 18 SECUNDARIOS CON SU INDEX_COMMENT)
-- -------------------------------------------------------------------------------------
SELECT
    TABLE_NAME,
    INDEX_NAME,
    NON_UNIQUE,
    GROUP_CONCAT(COLUMN_NAME ORDER BY SEQ_IN_INDEX SEPARATOR ', ') AS columnas_indice,
    INDEX_TYPE,
    INDEX_COMMENT
FROM INFORMATION_SCHEMA.STATISTICS
WHERE TABLE_SCHEMA = 'repo_saber_siee_sm'
GROUP BY TABLE_NAME, INDEX_NAME, NON_UNIQUE, INDEX_TYPE, INDEX_COMMENT
ORDER BY TABLE_NAME, NON_UNIQUE, INDEX_NAME;

-- -------------------------------------------------------------------------------------
-- 7. VERIFICACIÓN DE OBJETOS PROGRAMABLES (UDF, PROCEDIMIENTOS, TRIGGERS Y VISTAS)
-- -------------------------------------------------------------------------------------
SELECT ROUTINE_TYPE, ROUTINE_NAME, DATA_TYPE AS tipo_retorno, ROUTINE_COMMENT
  FROM INFORMATION_SCHEMA.ROUTINES
 WHERE ROUTINE_SCHEMA = 'repo_saber_siee_sm'
 ORDER BY ROUTINE_TYPE, ROUTINE_NAME;

SELECT TRIGGER_NAME, EVENT_MANIPULATION, ACTION_TIMING, EVENT_OBJECT_TABLE
  FROM INFORMATION_SCHEMA.TRIGGERS
 WHERE TRIGGER_SCHEMA = 'repo_saber_siee_sm'
 ORDER BY EVENT_OBJECT_TABLE, ACTION_TIMING, EVENT_MANIPULATION;

SELECT TABLE_NAME AS nombre_vista, IS_UPDATABLE, SECURITY_TYPE
  FROM INFORMATION_SCHEMA.VIEWS
 WHERE TABLE_SCHEMA = 'repo_saber_siee_sm'
 ORDER BY TABLE_NAME;

-- -------------------------------------------------------------------------------------
-- 8. INSPECCIÓN NATIVA SHOW CREATE TABLE Y SHOW FULL COLUMNS (MUESTRA REPRESENTATIVA)
-- -------------------------------------------------------------------------------------
SHOW CREATE TABLE parametro_sistema;
SHOW CREATE TABLE institucion_educativa;
SHOW CREATE TABLE escala_evaluacion;
SHOW CREATE TABLE area_evaluacion;
SHOW CREATE TABLE cohorte;
SHOW CREATE TABLE transformacion_escala;
SHOW CREATE TABLE instrumento_evaluacion;
SHOW CREATE TABLE promedio_nacional_ref;
SHOW CREATE TABLE plan_mejoramiento;
SHOW CREATE TABLE estudiante_seudonimo;
SHOW CREATE TABLE apoyo_institucional;
SHOW CREATE TABLE resultado_agregado_ie;
SHOW CREATE TABLE seguimiento_actividad_plan;
SHOW CREATE TABLE resultado_evaluacion;

SHOW FULL COLUMNS FROM resultado_evaluacion;
SHOW FULL COLUMNS FROM promedio_nacional_ref;
