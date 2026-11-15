/* =====================================================================================
 * PROYECTO:       Repositorio de Evolución Saber 11, Evaluaciones Internas (SIEE),
 *                 Simulacros y Planes de Mejoramiento (Colegios Oficiales Santa Marta)
 * ARCHIVO:        15_verificaciones_carga_mariadb.sql
 * SGBD / MOTOR:   MariaDB 10.4.32 / 10.11.16 (XAMPP Win64 AMD64)
 * BASE DE DATOS:  repo_saber_siee_sm
 * FECHA:          2026-11-15
 * PROPÓSITO:      Auditar la calidad, integridad referencial, dominios, rangos según
 *                 escala, no solapamiento, cobertura analítica (Q1–Q4) y tamaño en disco
 *                 tras la ejecución única de 14_carga_datos_sinteticos_mariadb.sql.
 * PROCEDIMIENTO SEGURO DE EJECUCIÓN:
 *   1. Cargar una sola vez 14_carga_datos_sinteticos_mariadb.sql sobre el esquema vacío
 *      creado con 12_creacion_esquema_mariadb.sql y 12d_objetos_programables_mariadb.sql.
 *   2. Ejecutar este script de solo lectura (SELECT) para contrastar totales esperados
 *      frente a los totales reales observados en el servidor.
 * ESTADO ACTUAL:  PROBADO EN SGBD
 * ===================================================================================== */

USE repo_saber_siee_sm;

-- -------------------------------------------------------------------------------------
-- 1. CONTEO DE FILAS POR TABLA: ESPERADO VS. OBSERVADO EN SGBD
-- -------------------------------------------------------------------------------------
SELECT '01. parametro_sistema'          AS tabla,     5 AS filas_esperadas, COUNT(*) AS filas_observadas, IF(COUNT(*) =     5, 'OK', 'FALLO') AS estado FROM parametro_sistema
UNION ALL
SELECT '02. institucion_educativa',                  50, COUNT(*), IF(COUNT(*) =    50, 'OK', 'FALLO') FROM institucion_educativa
UNION ALL
SELECT '03. escala_evaluacion',                       6, COUNT(*), IF(COUNT(*) =     6, 'OK', 'FALLO') FROM escala_evaluacion
UNION ALL
SELECT '04. area_evaluacion',                         6, COUNT(*), IF(COUNT(*) =     6, 'OK', 'FALLO') FROM area_evaluacion
UNION ALL
SELECT '05. cohorte',                               153, COUNT(*), IF(COUNT(*) =   153, 'OK', 'FALLO') FROM cohorte
UNION ALL
SELECT '06. transformacion_escala',                   8, COUNT(*), IF(COUNT(*) =     8, 'OK', 'FALLO') FROM transformacion_escala
UNION ALL
SELECT '07. instrumento_evaluacion',                 54, COUNT(*), IF(COUNT(*) =    54, 'OK', 'FALLO') FROM instrumento_evaluacion
UNION ALL
SELECT '08. promedio_nacional_ref',                  54, COUNT(*), IF(COUNT(*) =    54, 'OK', 'FALLO') FROM promedio_nacional_ref
UNION ALL
SELECT '09. plan_mejoramiento',                     300, COUNT(*), IF(COUNT(*) =   300, 'OK', 'FALLO') FROM plan_mejoramiento
UNION ALL
SELECT '10. estudiante_seudonimo',                 3015, COUNT(*), IF(COUNT(*) =  3015, 'OK', 'FALLO') FROM estudiante_seudonimo
UNION ALL
SELECT '11. apoyo_institucional',                   180, COUNT(*), IF(COUNT(*) =   180, 'OK', 'FALLO') FROM apoyo_institucional
UNION ALL
SELECT '12. resultado_agregado_ie',                 120, COUNT(*), IF(COUNT(*) =   120, 'OK', 'FALLO') FROM resultado_agregado_ie
UNION ALL
SELECT '13. seguimiento_actividad_plan',          10000, COUNT(*), IF(COUNT(*) = 10000, 'OK', 'FALLO') FROM seguimiento_actividad_plan
UNION ALL
SELECT '14. resultado_evaluacion',                12000, COUNT(*), IF(COUNT(*) = 12000, 'OK', 'FALLO') FROM resultado_evaluacion;

-- -------------------------------------------------------------------------------------
-- 2. CONTROL DE REGISTROS HUÉRFANOS EN LAS 17 CLAVES FORÁNEAS (ESPERADO: 0 EN TODAS)
-- -------------------------------------------------------------------------------------
SELECT
    (SELECT COUNT(*) FROM cohorte c LEFT JOIN institucion_educativa ie ON ie.codigo_dane = c.codigo_dane WHERE ie.codigo_dane IS NULL) AS huerfanos_cohorte_ie,
    (SELECT COUNT(*) FROM transformacion_escala t LEFT JOIN escala_evaluacion e1 ON e1.id_escala = t.id_escala_origen WHERE e1.id_escala IS NULL) AS huerfanos_trans_orig,
    (SELECT COUNT(*) FROM transformacion_escala t LEFT JOIN escala_evaluacion e2 ON e2.id_escala = t.id_escala_destino WHERE e2.id_escala IS NULL) AS huerfanos_trans_dest,
    (SELECT COUNT(*) FROM instrumento_evaluacion i LEFT JOIN escala_evaluacion e ON e.id_escala = i.id_escala WHERE e.id_escala IS NULL) AS huerfanos_inst_escala,
    (SELECT COUNT(*) FROM promedio_nacional_ref r LEFT JOIN area_evaluacion a ON a.id_area = r.id_area WHERE a.id_area IS NULL) AS huerfanos_ref_area,
    (SELECT COUNT(*) FROM promedio_nacional_ref r LEFT JOIN escala_evaluacion e ON e.id_escala = r.id_escala WHERE e.id_escala IS NULL) AS huerfanos_ref_escala,
    (SELECT COUNT(*) FROM plan_mejoramiento p LEFT JOIN institucion_educativa ie ON ie.codigo_dane = p.codigo_dane WHERE ie.codigo_dane IS NULL) AS huerfanos_plan_ie,
    (SELECT COUNT(*) FROM plan_mejoramiento p LEFT JOIN area_evaluacion a ON a.id_area = p.id_area WHERE a.id_area IS NULL) AS huerfanos_plan_area,
    (SELECT COUNT(*) FROM estudiante_seudonimo es LEFT JOIN cohorte c ON c.id_cohorte = es.id_cohorte WHERE c.id_cohorte IS NULL) AS huerfanos_est_cohorte,
    (SELECT COUNT(*) FROM apoyo_institucional ap LEFT JOIN cohorte c ON c.id_cohorte = ap.id_cohorte WHERE c.id_cohorte IS NULL) AS huerfanos_apoyo_cohorte,
    (SELECT COUNT(*) FROM resultado_agregado_ie ra LEFT JOIN cohorte c ON c.id_cohorte = ra.id_cohorte WHERE c.id_cohorte IS NULL) AS huerfanos_resag_cohorte,
    (SELECT COUNT(*) FROM resultado_agregado_ie ra LEFT JOIN instrumento_evaluacion i ON i.id_instrumento = ra.id_instrumento WHERE i.id_instrumento IS NULL) AS huerfanos_resag_inst,
    (SELECT COUNT(*) FROM resultado_agregado_ie ra LEFT JOIN area_evaluacion a ON a.id_area = ra.id_area WHERE a.id_area IS NULL) AS huerfanos_resag_area,
    (SELECT COUNT(*) FROM seguimiento_actividad_plan s LEFT JOIN plan_mejoramiento p ON p.id_plan = s.id_plan WHERE p.id_plan IS NULL) AS huerfanos_seg_plan,
    (SELECT COUNT(*) FROM resultado_evaluacion re LEFT JOIN estudiante_seudonimo es ON es.id_estudiante_hash = re.id_estudiante_hash WHERE es.id_estudiante_hash IS NULL) AS huerfanos_res_est,
    (SELECT COUNT(*) FROM resultado_evaluacion re LEFT JOIN instrumento_evaluacion i ON i.id_instrumento = re.id_instrumento WHERE i.id_instrumento IS NULL) AS huerfanos_res_inst,
    (SELECT COUNT(*) FROM resultado_evaluacion re LEFT JOIN area_evaluacion a ON a.id_area = re.id_area WHERE a.id_area IS NULL) AS huerfanos_res_area;

-- -------------------------------------------------------------------------------------
-- 3. CONTROL DE DUPLICADOS EN CLAVES COMPUESTAS DE NEGOCIO Y DE DOBLE CONTEO (ESPERADO: 0)
-- -------------------------------------------------------------------------------------
SELECT
    -- Duplicados en cohorte (codigo_dane, anio_lectivo, jornada)
    (SELECT COUNT(*) FROM (
        SELECT codigo_dane, anio_lectivo, jornada FROM cohorte GROUP BY codigo_dane, anio_lectivo, jornada HAVING COUNT(*) > 1
    ) d1) AS dup_cohorte_esp_0,
    -- Duplicados en resultado_evaluacion (id_estudiante_hash, id_instrumento, id_area)
    (SELECT COUNT(*) FROM (
        SELECT id_estudiante_hash, id_instrumento, id_area FROM resultado_evaluacion GROUP BY id_estudiante_hash, id_instrumento, id_area HAVING COUNT(*) > 1
    ) d2) AS dup_resultado_eval_esp_0,
    -- Verificación de Riesgo R-01 (Cero solapamiento entre microdatos y agregados para el mismo instrumento)
    (SELECT COUNT(*)
       FROM resultado_agregado_ie ra
      INNER JOIN (
          SELECT DISTINCT es.id_cohorte, re.id_instrumento, re.id_area
            FROM resultado_evaluacion re
           INNER JOIN estudiante_seudonimo es ON es.id_estudiante_hash = re.id_estudiante_hash
      ) micro ON micro.id_cohorte     = ra.id_cohorte
             AND micro.id_instrumento = ra.id_instrumento
             AND micro.id_area        = ra.id_area) AS solapamiento_micro_vs_agregado_esp_0;

-- -------------------------------------------------------------------------------------
-- 4. CONTROL DE DOMINIOS, INTERVALOS DE ESCALA (RN05), PRIVACIDAD (RN01) Y AFOROS (R05)
-- -------------------------------------------------------------------------------------
SELECT
    -- Violaciones de rango [valor_minimo, valor_maximo] en resultado_evaluacion (RN05)
    (SELECT COUNT(*)
       FROM resultado_evaluacion re
      INNER JOIN instrumento_evaluacion i ON i.id_instrumento = re.id_instrumento
      INNER JOIN escala_evaluacion e      ON e.id_escala      = i.id_escala
      WHERE re.puntaje_obtenido < e.valor_minimo
         OR re.puntaje_obtenido > e.valor_maximo
         OR (e.permite_decimales = 0 AND re.puntaje_obtenido <> FLOOR(re.puntaje_obtenido))) AS violaciones_rango_microdatos_esp_0,

    -- Violaciones de rango [valor_minimo, valor_maximo] en resultado_agregado_ie (RN05)
    (SELECT COUNT(*)
       FROM resultado_agregado_ie ra
      INNER JOIN instrumento_evaluacion i ON i.id_instrumento = ra.id_instrumento
      INNER JOIN escala_evaluacion e      ON e.id_escala      = i.id_escala
      WHERE ra.puntaje_promedio < e.valor_minimo
         OR ra.puntaje_promedio > e.valor_maximo) AS violaciones_rango_agregados_esp_0,

    -- Violaciones de formato SHA-256 en estudiante_seudonimo (RN01)
    (SELECT COUNT(*)
       FROM estudiante_seudonimo
      WHERE id_estudiante_hash NOT REGEXP '^[0-9a-fA-F]{64}$') AS hashes_invalidos_esp_0,

    -- Violaciones de cupo en apoyo_institucional: beneficiarios_cubiertos > total_matriculados (R05)
    (SELECT COUNT(*)
       FROM apoyo_institucional ap
      INNER JOIN cohorte c ON c.id_cohorte = ap.id_cohorte
      WHERE c.total_matriculados IS NOT NULL
        AND ap.beneficiarios_cubiertos > c.total_matriculados) AS excesos_beneficiarios_cohorte_esp_0,

    -- Violaciones de rango porcentual [0, 100] en seguimiento_actividad_plan (R06)
    (SELECT COUNT(*)
       FROM seguimiento_actividad_plan
      WHERE porcentaje_avance_corte < 0.00 OR porcentaje_avance_corte > 100.00) AS avances_fuera_rango_esp_0;

-- -------------------------------------------------------------------------------------
-- 5. PRUEBA DE COBERTURA DE LAS VISTAS ANALÍTICAS Y SUPRESIÓN k-ANONIMATO (RN02)
-- -------------------------------------------------------------------------------------
SELECT
    (SELECT COUNT(*) FROM vw_evolucion_ie_area_anio)    AS filas_vw_evolucion_q1,
    (SELECT COUNT(*) FROM vw_brecha_promedio_nacional)  AS filas_vw_brecha_q2,
    (SELECT COUNT(*) FROM vw_impacto_simulacros_planes) AS filas_vw_impacto_q3_q4,
    -- Grupos pequeños (< 10 evaluados) presentes en la tabla base pero suprimidos en la vista Q1
    (SELECT COUNT(*) FROM (
        SELECT es.id_cohorte, re.id_instrumento, re.id_area, COUNT(*) AS n
          FROM resultado_evaluacion re
         INNER JOIN estudiante_seudonimo es ON es.id_estudiante_hash = re.id_estudiante_hash
         GROUP BY es.id_cohorte, re.id_instrumento, re.id_area
        HAVING COUNT(*) < 10
    ) g_peq) AS grupos_menores_k_en_base_esp_3,
    (SELECT COUNT(*) FROM vw_evolucion_ie_area_anio WHERE total_estudiantes_evaluados < 10) AS grupos_menores_k_expuestos_en_vista_esp_0;

-- -------------------------------------------------------------------------------------
-- 6. TAMAÑO FÍSICO REAL EN DISCO (DATOS + ÍNDICES EN INNODB)
-- -------------------------------------------------------------------------------------
SELECT
    TABLE_NAME,
    TABLE_ROWS AS filas_estimadas_innodb,
    ROUND(DATA_LENGTH / 1024 / 1024, 3)  AS datos_mb,
    ROUND(INDEX_LENGTH / 1024 / 1024, 3) AS indices_mb,
    ROUND((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 3) AS total_mb
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'repo_saber_siee_sm'
  AND TABLE_TYPE = 'BASE TABLE'
ORDER BY (DATA_LENGTH + INDEX_LENGTH) DESC;
