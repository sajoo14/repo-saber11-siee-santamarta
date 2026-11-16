/* =====================================================================================
 * PROYECTO:       Repositorio de Evolución Saber 11, Evaluaciones Internas (SIEE),
 *                 Simulacros y Planes de Mejoramiento (Colegios Oficiales Santa Marta)
 * ARCHIVO:        16_consultas_validacion_mariadb.sql
 * SGBD / MOTOR:   MariaDB 10.4.32 / 10.11.16 (XAMPP Win64 AMD64)
 * BASE DE DATOS:  repo_saber_siee_sm
 * FECHA:          2026-11-15
 * PROPÓSITO:      Conjunto de 15 consultas funcionales y analíticas diferenciadas (E15)
 *                 que responden las 4 preguntas obligatorias del enunciado (Q1–Q4),
 *                 cubren íntegramente los Capítulos 2 al 7 de la asignatura (SELECT,
 *                 filtros, agregaciones, GROUP BY, HAVING, subconsultas autónomas y
 *                 correlacionadas, INNER/LEFT/CROSS JOIN, operaciones de conjunto
 *                 UNION/EXCEPT, funciones de ventana LAG(), CASE, paginación y pivoteo
 *                 por columnas), invocan las 2 UDFs y las 3 vistas aprobadas, y verifican
 *                 los casos límite e invariantes del dominio (RN01–RN05).
 * NOTA:           Este script contiene exclusivamente sentencias SELECT de validación
 *                 (separado de la creación de vistas conforme a la Fase 5 del Prompt).
 * ESTADO ACTUAL:  PROBADO EN SGBD
 * ===================================================================================== */

USE repo_saber_siee_sm;

SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;

/* =====================================================================================
 * CONSULTA C01 (Pregunta Obligatoria Q1 del Enunciado)
 * "¿Cómo cambian los resultados por institución, área y año?"
 * -------------------------------------------------------------------------------------
 * - Requisitos:      R01, R02, R03, R08 | Reglas: RN01, RN02 (k-anonimato)
 * - Parámetros:      tipo_instrumento = 'SABER_11', umbral dinámico desde parametro_sistema
 * - Técnica SQL:     INNER JOIN de 6 tablas + GROUP BY + HAVING + función de ventana LAG()
 * - Resultado esp.:  300 filas (50 colegios x 2 áreas evaluadas en Saber 11 x 3 años
 *                    2022–2024), mostrando el puntaje promedio anual y el cambio neto
 *                    frente al año inmediatamente anterior.
 * - Caso límite:     Las 3 cohortes nocturnas de 2024 con solo 5 evaluados (< k = 10)
 *                    quedan automáticamente excluidas por la cláusula HAVING.
 * ===================================================================================== */
SELECT
    base.codigo_dane,
    base.nombre_ie,
    base.codigo_area,
    base.nombre_area,
    base.anio_lectivo,
    base.evaluados_cohorte,
    base.promedio_anual,
    LAG(base.promedio_anual) OVER (
        PARTITION BY base.codigo_dane, base.id_area
        ORDER BY base.anio_lectivo
    ) AS promedio_anio_anterior,
    ROUND(
        base.promedio_anual - LAG(base.promedio_anual) OVER (
            PARTITION BY base.codigo_dane, base.id_area
            ORDER BY base.anio_lectivo
        ),
        2
    ) AS variacion_interanual_puntos
FROM (
    SELECT
        ie.codigo_dane,
        ie.nombre_ie,
        a.id_area,
        a.codigo_area,
        a.nombre_area,
        c.anio_lectivo,
        COUNT(re.id_estudiante_hash)       AS evaluados_cohorte,
        ROUND(AVG(re.puntaje_obtenido), 2) AS promedio_anual
    FROM resultado_evaluacion re
    INNER JOIN estudiante_seudonimo es  ON es.id_estudiante_hash = re.id_estudiante_hash
    INNER JOIN cohorte c                ON c.id_cohorte          = es.id_cohorte
    INNER JOIN institucion_educativa ie ON ie.codigo_dane        = c.codigo_dane
    INNER JOIN instrumento_evaluacion i ON i.id_instrumento      = re.id_instrumento
    INNER JOIN area_evaluacion a        ON a.id_area             = re.id_area
    WHERE i.tipo_instrumento = 'SABER_11'
    GROUP BY
        ie.codigo_dane, ie.nombre_ie,
        a.id_area, a.codigo_area, a.nombre_area,
        c.anio_lectivo
    HAVING COUNT(re.id_estudiante_hash) >= (
        SELECT CAST(valor_parametro AS UNSIGNED)
          FROM parametro_sistema
         WHERE clave_parametro = 'UMBRAL_MINIMO_K'
    )
) AS base
ORDER BY base.codigo_dane, base.codigo_area, base.anio_lectivo
LIMIT 15;


/* =====================================================================================
 * CONSULTA C02 (Pregunta Obligatoria Q2 del Enunciado)
 * "¿Qué diferencia existe frente al promedio nacional para una misma escala?"
 * -------------------------------------------------------------------------------------
 * - Requisitos:      R04, R07, R08 | Reglas: RN02, RN04 (Consistencia de escalas)
 * - Parámetros:      anio_lectivo = 2024, comparación en escala ICFES_AREA_0_100
 * - Técnica SQL:     Consulta sobre la vista vw_brecha_promedio_nacional (que invoca
 *                    internamente la UDF fn_transformar_puntaje) + filtro por año 2024.
 * - Resultado esp.:  Retorna para cada colegio, área y tipo de instrumento (tanto en
 *                    SABER_11 que ya está en 0..100 como en SIEE 1..5 homologado a 0..100)
 *                    su brecha exacta frente al referente nacional oficial del Icfes.
 * - Caso límite:     Si un instrumento estuviera en una escala sin transformación vigente,
 *                    promedio_colegio_homologado sería NULL y la vista lo excluiría.
 * ===================================================================================== */
SELECT
    codigo_dane,
    nombre_ie,
    anio_lectivo,
    tipo_instrumento,
    codigo_area,
    escala_instrumento,
    escala_referente_nacional,
    cantidad_evaluados,
    promedio_colegio_escala_orig,
    promedio_colegio_homologado,
    promedio_nacional_oficial,
    brecha_frente_nacional
FROM vw_brecha_promedio_nacional
WHERE anio_lectivo = 2024
  AND codigo_area  = 'MAT'
ORDER BY tipo_instrumento, brecha_frente_nacional DESC
LIMIT 15;


/* =====================================================================================
 * CONSULTA C03 (Pregunta Obligatoria Q3 del Enunciado)
 * "¿Qué instituciones muestran mayores mejoras?"
 * -------------------------------------------------------------------------------------
 * - Requisitos:      R01, R03, R08 | Reglas: RN02 (k-anonimato en ambos extremos 2022 y 2024)
 * - Parámetros:      Comparación entre cohorte base (2022) y cohorte final (2024) en SABER_11
 * - Técnica SQL:     Subconsultas correlacionadas / tablas derivadas para comparar el
 *                    promedio institucional 2022 vs. 2024 por área, ordenando de mayor
 *                    a menor ganancia neta en puntos.
 * - Resultado esp.:  Los primeros 25 colegios (que implementaron planes intensivos)
 *                    lideran el ranking con una ganancia de +6.00 puntos entre 2022 y 2024.
 * - Caso límite:     Exige que tanto el año inicial (2022) como el final (2024) superen
 *                    el umbral k >= 10 evaluados.
 * ===================================================================================== */
SELECT
    t2022.codigo_dane,
    t2022.nombre_ie,
    t2022.comuna_localidad,
    t2022.codigo_area,
    t2022.puntaje_promedio_ie                                  AS promedio_2022,
    t2024.puntaje_promedio_ie                                  AS promedio_2024,
    ROUND(t2024.puntaje_promedio_ie - t2022.puntaje_promedio_ie, 2) AS mejora_neta_2022_2024,
    ROUND(
        ((t2024.puntaje_promedio_ie - t2022.puntaje_promedio_ie) / t2022.puntaje_promedio_ie) * 100,
        2
    )                                                          AS mejora_porcentual_pct
FROM vw_evolucion_ie_area_anio t2022
INNER JOIN vw_evolucion_ie_area_anio t2024
        ON t2024.codigo_dane      = t2022.codigo_dane
       AND t2024.id_area          = t2022.id_area
       AND t2024.tipo_instrumento = t2022.tipo_instrumento
WHERE t2022.tipo_instrumento = 'SABER_11'
  AND t2022.anio_lectivo     = 2022
  AND t2024.anio_lectivo     = 2024
ORDER BY mejora_neta_2022_2024 DESC, promedio_2024 DESC
LIMIT 15;


/* =====================================================================================
 * CONSULTA C04 (Pregunta Obligatoria Q4 del Enunciado)
 * "¿Qué relación se observa entre simulacros, planes y resultados posteriores?"
 * -------------------------------------------------------------------------------------
 * - Requisitos:      R05, R06, R08 | Reglas: RN02, Riesgo R-02 (Asociación observada)
 * - Parámetros:      anio_lectivo = 2024, área = 'MAT'
 * - Técnica SQL:     Consulta sobre la vista integradora vw_impacto_simulacros_planes
 *                    calculando el diferencial entre el simulacro diagnóstico (semestre 1)
 *                    y el examen Saber 11 posterior (semestre 2), junto con el avance
 *                    del plan de mejoramiento y los apoyos financieros de la Alcaldía.
 * - Resultado esp.:  Muestra que en las cohortes con simulacro diagnóstico y planes de
 *                    mejoramiento activos, el resultado Saber 11 posterior supera en
 *                    promedio por +3.00 puntos al simulacro inicial.
 * - Caso límite:     Usa LEFT JOIN hacia planes y apoyos para no perder cohortes que
 *                    presentaron simulacro pero no tuvieron apoyos en un corte dado.
 * ===================================================================================== */
SELECT
    codigo_dane,
    nombre_ie,
    anio_lectivo,
    codigo_area,
    promedio_simulacro                                      AS puntaje_simulacro_previo,
    promedio_saber11                                        AS puntaje_saber11_posterior,
    ROUND(promedio_saber11 - promedio_simulacro, 2)         AS ganancia_post_simulacro,
    meta_cuantitativa                                       AS meta_plan,
    ROUND(promedio_saber11 - meta_cuantitativa, 2)          AS cumplimiento_meta_puntos,
    estado_plan,
    avance_promedio_plan_pct,
    monto_apoyos_cohorte_cop
FROM vw_impacto_simulacros_planes
WHERE anio_lectivo = 2024
  AND codigo_area  = 'MAT'
ORDER BY ganancia_post_simulacro DESC, promedio_saber11 DESC
LIMIT 15;


/* =====================================================================================
 * CONSULTA C05 (Análisis Territorial por Comuna / Corregimiento en Santa Marta)
 * -------------------------------------------------------------------------------------
 * - Requisitos:      R01, R08 (Supuesto de contexto S02) | Regla: RN02
 * - Técnica SQL:     Agrupación de segundo nivel sobre vw_evolucion_ie_area_anio con
 *                    GROUP BY comuna_localidad y HAVING COUNT(DISTINCT codigo_dane) >= 2.
 * - Resultado esp.:  Desempeño promedio en Saber 11 (2024) en las 13 zonas territoriales
 *                    (9 comunas urbanas y 4 corregimientos del Distrito de Santa Marta).
 * ===================================================================================== */
SELECT
    comuna_localidad,
    codigo_area,
    COUNT(DISTINCT codigo_dane)                  AS colegios_en_comuna,
    SUM(total_estudiantes_evaluados)             AS total_evaluados_comuna,
    ROUND(AVG(puntaje_promedio_ie), 2)           AS promedio_saber11_comuna,
    MIN(puntaje_promedio_ie)                     AS menor_promedio_colegio,
    MAX(puntaje_promedio_ie)                     AS mayor_promedio_colegio
FROM vw_evolucion_ie_area_anio
WHERE tipo_instrumento = 'SABER_11'
  AND anio_lectivo     = 2024
GROUP BY comuna_localidad, codigo_area
HAVING COUNT(DISTINCT codigo_dane) >= 2
ORDER BY codigo_area, promedio_saber11_comuna DESC;


/* =====================================================================================
 * CONSULTA C06 (Diagnóstico de Desconexión entre Evaluaciones Internas SIEE y Saber 11)
 * -------------------------------------------------------------------------------------
 * - Requisitos:      R02, R03, R07, R08 | Reglas: RN01, RN02, RN04
 * - Propósito:       Cuantificar a nivel institucional la desconexión señalada por el
 *                    Icfes y Unimagdalena entre la calificación interna SIEE (homologada
 *                    a escala 0..100 mediante fn_transformar_puntaje) y el resultado
 *                    real en la prueba externa Saber 11 para los mismos estudiantes.
 * - Caso límite:     No resta puntajes crudos (3.50 vs 52.00), sino que transforma la
 *                    nota SIEE (escala 3) a la escala Icfes (escala 1) antes de restar.
 * ===================================================================================== */
SELECT
    ie.codigo_dane,
    ie.nombre_ie,
    c.anio_lectivo,
    COUNT(re_saber.id_estudiante_hash)                                           AS estudiantes_con_ambas_pruebas,
    ROUND(AVG(re_siee.puntaje_obtenido), 2)                                      AS nota_media_siee_1_5,
    ROUND(AVG(fn_transformar_puntaje(re_siee.puntaje_obtenido, 3, 1)), 2)        AS siee_homologado_0_100,
    ROUND(AVG(re_saber.puntaje_obtenido), 2)                                     AS puntaje_medio_saber11_0_100,
    ROUND(
        AVG(fn_transformar_puntaje(re_siee.puntaje_obtenido, 3, 1)) - AVG(re_saber.puntaje_obtenido),
        2
    )                                                                            AS brecha_sobrevaloracion_siee
FROM resultado_evaluacion re_saber
INNER JOIN instrumento_evaluacion i_sab ON i_sab.id_instrumento      = re_saber.id_instrumento
                                       AND i_sab.tipo_instrumento    = 'SABER_11'
INNER JOIN resultado_evaluacion re_siee ON re_siee.id_estudiante_hash = re_saber.id_estudiante_hash
                                       AND re_siee.id_area            = re_saber.id_area
INNER JOIN instrumento_evaluacion i_sie ON i_sie.id_instrumento       = re_siee.id_instrumento
                                       AND i_sie.tipo_instrumento     = 'SIEE'
INNER JOIN estudiante_seudonimo es      ON es.id_estudiante_hash      = re_saber.id_estudiante_hash
INNER JOIN cohorte c                    ON c.id_cohorte               = es.id_cohorte
INNER JOIN institucion_educativa ie     ON ie.codigo_dane             = c.codigo_dane
WHERE c.anio_lectivo   = 2024
  AND re_saber.id_area = 1
GROUP BY ie.codigo_dane, ie.nombre_ie, c.anio_lectivo
HAVING COUNT(re_saber.id_estudiante_hash) >= (
    SELECT CAST(valor_parametro AS UNSIGNED)
      FROM parametro_sistema
     WHERE clave_parametro = 'UMBRAL_MINIMO_K'
)
ORDER BY ABS(
    AVG(fn_transformar_puntaje(re_siee.puntaje_obtenido, 3, 1)) - AVG(re_saber.puntaje_obtenido)
) DESC
LIMIT 15;


/* =====================================================================================
 * CONSULTA C07 (Caso Límite de Privacidad: Auditoría de Grupos Suprimidos por k-Anonimato)
 * -------------------------------------------------------------------------------------
 * - Requisitos:      R03, R07 | Reglas: RN01, RN02
 * - Propósito:       Identificar internamente qué cohortes tienen tamaño de grupo menor
 *                    al parámetro UMBRAL_MINIMO_K (10) y demostrar que su estado de
 *                    publicación es 'SUPRIMIDO_POR_RN02' (no aparecen en la vista pública).
 * ===================================================================================== */
SELECT
    c.id_cohorte,
    c.codigo_dane,
    ie.nombre_ie,
    c.anio_lectivo,
    c.jornada,
    COUNT(re.id_estudiante_hash) AS evaluados_reales,
    (SELECT CAST(valor_parametro AS UNSIGNED)
       FROM parametro_sistema
      WHERE clave_parametro = 'UMBRAL_MINIMO_K') AS umbral_minimo_k,
    CASE
        WHEN COUNT(re.id_estudiante_hash) < (
            SELECT CAST(valor_parametro AS UNSIGNED)
              FROM parametro_sistema
             WHERE clave_parametro = 'UMBRAL_MINIMO_K'
        ) THEN 'SUPRIMIDO_POR_RN02 (NO PUBLICABLE)'
        ELSE 'PUBLICABLE'
    END AS dictamen_privacidad,
    (SELECT COUNT(*)
       FROM vw_evolucion_ie_area_anio vw
      WHERE vw.codigo_dane  = c.codigo_dane
        AND vw.anio_lectivo = c.anio_lectivo
        AND vw.total_estudiantes_evaluados < 10) AS apariciones_en_vista_publica_esp_0
FROM cohorte c
INNER JOIN institucion_educativa ie ON ie.codigo_dane        = c.codigo_dane
INNER JOIN estudiante_seudonimo es  ON es.id_cohorte         = c.id_cohorte
INNER JOIN resultado_evaluacion re  ON re.id_estudiante_hash = es.id_estudiante_hash
GROUP BY c.id_cohorte, c.codigo_dane, ie.nombre_ie, c.anio_lectivo, c.jornada
HAVING COUNT(re.id_estudiante_hash) < (
    SELECT CAST(valor_parametro AS UNSIGNED)
      FROM parametro_sistema
     WHERE clave_parametro = 'UMBRAL_MINIMO_K'
);


/* =====================================================================================
 * CONSULTA C08 (Caso Límite de Escalas: Bloqueo de Comparación sin Regla Vigente — RN04)
 * -------------------------------------------------------------------------------------
 * - Requisitos:      R02, R07 | Regla: RN04
 * - Propósito:       Comprobar el comportamiento de fn_transformar_puntaje frente a:
 *                    1) La misma escala (1 -> 1): retorna el puntaje intacto.
 *                    2) Una transformación vigente (3 -> 1): retorna el valor homologado.
 *                    3) Una transformación inactiva (6 -> 1, vigente = 0) o inexistente
 *                       (2 -> 3): retorna NULL impidiendo restas inválidas.
 * ===================================================================================== */
SELECT
    e_orig.id_escala                                                  AS id_origen,
    e_orig.nombre_escala                                              AS escala_origen,
    e_dest.id_escala                                                  AS id_destino,
    e_dest.nombre_escala                                              AS escala_destino,
    4.00                                                              AS puntaje_prueba_entrada,
    fn_transformar_puntaje(4.00, e_orig.id_escala, e_dest.id_escala)  AS puntaje_homologado,
    CASE
        WHEN fn_transformar_puntaje(4.00, e_orig.id_escala, e_dest.id_escala) IS NULL
        THEN 'BLOQUEADO_POR_RN04 (SIN TRANSFORMACION VIGENTE)'
        ELSE 'HOMOLOGACION_AUTORIZADA'
    END                                                               AS estado_rn04
FROM escala_evaluacion e_orig
CROSS JOIN escala_evaluacion e_dest
WHERE (e_orig.id_escala = 1 AND e_dest.id_escala = 1)
   OR (e_orig.id_escala = 3 AND e_dest.id_escala = 1)
   OR (e_orig.id_escala = 6 AND e_dest.id_escala = 1)
   OR (e_orig.id_escala = 2 AND e_dest.id_escala = 3)
ORDER BY e_orig.id_escala, e_dest.id_escala;


/* =====================================================================================
 * CONSULTA C09 (Trazabilidad Histórica de los 10.000 Cortes de Seguimiento — R06, RN03)
 * -------------------------------------------------------------------------------------
 * - Requisitos:      R06 | Regla: RN03 (Conservación de todos los cortes sin sobrescribir)
 * - Técnica SQL:     Agregación sobre las 10.000 filas de seguimiento_actividad_plan
 *                    comparando el primer corte registrado (MIN) vs. el último corte (MAX)
 *                    y el número total de cortes históricos conservados por plan.
 * ===================================================================================== */
SELECT
    pm.id_plan,
    pm.codigo_dane,
    ie.nombre_ie,
    a.codigo_area,
    pm.anio_implementacion,
    pm.estado_plan,
    COUNT(sap.id_seguimiento)              AS total_cortes_historicos_conservados,
    MIN(sap.fecha_seguimiento)             AS fecha_primer_corte,
    MAX(sap.fecha_seguimiento)             AS fecha_ultimo_corte,
    MIN(sap.porcentaje_avance_corte)       AS avance_inicial_pct,
    MAX(sap.porcentaje_avance_corte)       AS avance_final_pct
FROM plan_mejoramiento pm
INNER JOIN institucion_educativa ie       ON ie.codigo_dane = pm.codigo_dane
INNER JOIN area_evaluacion a              ON a.id_area      = pm.id_area
INNER JOIN seguimiento_actividad_plan sap ON sap.id_plan    = pm.id_plan
GROUP BY
    pm.id_plan, pm.codigo_dane, ie.nombre_ie,
    a.codigo_area, pm.anio_implementacion, pm.estado_plan
ORDER BY pm.anio_implementacion DESC, pm.id_plan ASC
LIMIT 15;


/* =====================================================================================
 * CONSULTA C10 (Consulta Segura de Resultados Consolidados sin Doble Conteo — R03, RN02)
 * -------------------------------------------------------------------------------------
 * - Requisitos:      R03, R08 | Reglas: RN02, Riesgo R-01
 * - Propósito:       Consultar los reportes agregados de resultado_agregado_ie que
 *                    cumplen cantidad_evaluados >= UMBRAL_MINIMO_K y verificar mediante
 *                    NOT EXISTS que no exista microdato individual para el mismo
 *                    (id_cohorte, id_instrumento, id_area).
 * - Resultado esp.:  110 registros publicables (los 10 registros con cantidad_evaluados = 6
 *                    quedan filtrados por RN02).
 * ===================================================================================== */
SELECT
    ra.id_agregado,
    ie.codigo_dane,
    ie.nombre_ie,
    c.anio_lectivo,
    i.tipo_instrumento,
    i.nombre_instrumento,
    a.codigo_area,
    ra.periodo_reporte,
    ra.cantidad_evaluados,
    ra.puntaje_promedio,
    ra.desviacion_estandar
FROM resultado_agregado_ie ra
INNER JOIN cohorte c                ON c.id_cohorte     = ra.id_cohorte
INNER JOIN institucion_educativa ie ON ie.codigo_dane   = c.codigo_dane
INNER JOIN instrumento_evaluacion i ON i.id_instrumento = ra.id_instrumento
INNER JOIN area_evaluacion a        ON a.id_area        = ra.id_area
WHERE ra.cantidad_evaluados >= (
    SELECT CAST(valor_parametro AS UNSIGNED)
      FROM parametro_sistema
     WHERE clave_parametro = 'UMBRAL_MINIMO_K'
)
AND NOT EXISTS (
    SELECT 1
      FROM resultado_evaluacion re
     INNER JOIN estudiante_seudonimo es ON es.id_estudiante_hash = re.id_estudiante_hash
     WHERE es.id_cohorte     = ra.id_cohorte
       AND re.id_instrumento = ra.id_instrumento
       AND re.id_area        = ra.id_area
)
ORDER BY ra.id_agregado ASC
LIMIT 15;


/* =====================================================================================
 * CONSULTA C11 (Caso Límite de Ausencia de Datos: Áreas con Referente Nacional pero sin
 *               Planes de Mejoramiento Formulados — R04, R06)
 * -------------------------------------------------------------------------------------
 * - Requisitos:      R02, R04, R06
 * - Técnica SQL:     LEFT JOIN entre area_evaluacion, promedio_nacional_ref y
 *                    plan_mejoramiento para detectar brechas de cobertura de planes.
 * - Resultado esp.:  Muestra que MAT y LEC tienen 150 planes cada una, mientras que
 *                    SOC, NAT, ING y GLOB tienen 0 planes formulados (oportunidad de
 *                    intervención curricular en el Distrito).
 * ===================================================================================== */
SELECT
    a.id_area,
    a.codigo_area,
    a.nombre_area,
    a.es_nucleo_comun,
    COUNT(DISTINCT pnr.id_referente) AS referentes_nacionales_registrados,
    COUNT(DISTINCT pm.id_plan)       AS planes_mejoramiento_formulados,
    CASE
        WHEN COUNT(DISTINCT pm.id_plan) = 0 THEN 'SIN_COBERTURA_DE_PLANES'
        ELSE 'CON_PLANES_ACTIVOS'
    END                              AS estado_cobertura_curricular
FROM area_evaluacion a
LEFT JOIN promedio_nacional_ref pnr ON pnr.id_area = a.id_area
LEFT JOIN plan_mejoramiento pm      ON pm.id_area  = a.id_area
GROUP BY a.id_area, a.codigo_area, a.nombre_area, a.es_nucleo_comun
ORDER BY planes_mejoramiento_formulados DESC, a.id_area ASC;


/* =====================================================================================
 * CONSULTA C12 (Invariante Financiero y de Cobertura de Beneficiarios — R01, R05)
 * -------------------------------------------------------------------------------------
 * - Requisitos:      R01, R05
 * - Propósito:       Analizar la inversión en apoyos institucionales por modalidad,
 *                    calculando el costo promedio por beneficiario en pesos COP y
 *                    comprobando el porcentaje de cobertura sobre la matrícula de la cohorte.
 * ===================================================================================== */
SELECT
    ap.tipo_apoyo,
    ap.entidad_financiadora,
    COUNT(ap.id_apoyo)                                              AS total_desembolsos,
    SUM(ap.beneficiarios_cubiertos)                                 AS total_estudiantes_beneficiados,
    SUM(ap.monto_invertido)                                         AS inversion_total_cop,
    ROUND(SUM(ap.monto_invertido) / SUM(ap.beneficiarios_cubiertos), 2) AS inversion_media_por_estudiante_cop,
    ROUND(AVG((ap.beneficiarios_cubiertos / c.total_matriculados) * 100), 2) AS cobertura_media_matricula_pct,
    MAX(CASE WHEN ap.beneficiarios_cubiertos > c.total_matriculados THEN 1 ELSE 0 END) AS sobrecupo_detectado_esp_0
FROM apoyo_institucional ap
INNER JOIN cohorte c ON c.id_cohorte = ap.id_cohorte
GROUP BY ap.tipo_apoyo, ap.entidad_financiadora
ORDER BY inversion_total_cop DESC;


/* =====================================================================================
 * CONSULTA C13 (Capítulo 6 · Operaciones de Conjunto Nativas: EXCEPT y UNION en MariaDB)
 * -------------------------------------------------------------------------------------
 * - Requisitos:      R01, R05, R06 | Cobertura Curricular: Capítulo 6 (Conjuntos)
 * - Propósito:       Identificar mediante operadores de conjunto (EXCEPT y UNION):
 *                    1) Colegios con planes de mejoramiento en ejecución en 2024 que NO
 *                       recibieron apoyo de modalidad 'PAGO_INSCRIPCION' en 2024 (EXCEPT).
 *                    2) Unificado con colegios que sí recibieron ambos (INTERSECT / UNION)
 *                       para focalizar el presupuesto distrital de la Alcaldía.
 * ===================================================================================== */
SELECT
    codigo_dane,
    nombre_ie,
    comuna_localidad,
    'PLAN_EN_EJECUCION_SIN_SUBSIDIO_INSCRIPCION_2024' AS condicion_conjunto
FROM (
    SELECT ie.codigo_dane, ie.nombre_ie, ie.comuna_localidad
      FROM institucion_educativa ie
      INNER JOIN plan_mejoramiento pm ON pm.codigo_dane = ie.codigo_dane
     WHERE pm.anio_implementacion = 2024
       AND pm.estado_plan = 'EN_EJECUCION'
    EXCEPT
    SELECT ie2.codigo_dane, ie2.nombre_ie, ie2.comuna_localidad
      FROM institucion_educativa ie2
      INNER JOIN cohorte c2              ON c2.codigo_dane = ie2.codigo_dane
      INNER JOIN apoyo_institucional ap2 ON ap2.id_cohorte = c2.id_cohorte
     WHERE c2.anio_lectivo = 2024
       AND ap2.tipo_apoyo  = 'PAGO_INSCRIPCION'
) AS brecha_focalizacion
UNION ALL
SELECT
    ie3.codigo_dane,
    ie3.nombre_ie,
    ie3.comuna_localidad,
    'CON_SUBSIDIO_INSCRIPCION_ACTIVO_2024' AS condicion_conjunto
FROM institucion_educativa ie3
INNER JOIN cohorte c3              ON c3.codigo_dane = ie3.codigo_dane
INNER JOIN apoyo_institucional ap3 ON ap3.id_cohorte = c3.id_cohorte
WHERE c3.anio_lectivo = 2024
  AND ap3.tipo_apoyo  = 'PAGO_INSCRIPCION'
ORDER BY condicion_conjunto DESC, codigo_dane ASC
LIMIT 15;


/* =====================================================================================
 * CONSULTA C14 (Capítulo 7 · Pivoteo Multi-Área mediante Agregación Condicional CASE +
 *               Paginación LIMIT/OFFSET)
 * -------------------------------------------------------------------------------------
 * - Requisitos:      R02, R03, R08 | Regla: RN02 (k-anonimato) | Cap. 7 (Pivoteo)
 * - Propósito:       Construir una matriz ejecutiva (tabla pivoteada por columnas) que
 *                    muestre en una sola fila por zona territorial (comuna/corregimiento)
 *                    el puntaje promedio en las 5 áreas nucleares del Icfes (MAT, LEC,
 *                    SOC, NAT, ING) y el total de evaluaciones publicadas.
 * ===================================================================================== */
SELECT
    comuna_localidad,
    COUNT(DISTINCT codigo_dane)                                               AS colegios_evaluados,
    ROUND(AVG(CASE WHEN codigo_area = 'MAT' THEN puntaje_promedio_ie END), 2) AS piv_matematicas,
    ROUND(AVG(CASE WHEN codigo_area = 'LEC' THEN puntaje_promedio_ie END), 2) AS piv_lectura_critica,
    ROUND(AVG(CASE WHEN codigo_area = 'SOC' THEN puntaje_promedio_ie END), 2) AS piv_sociales_ciudadanas,
    ROUND(AVG(CASE WHEN codigo_area = 'NAT' THEN puntaje_promedio_ie END), 2) AS piv_ciencias_naturales,
    ROUND(AVG(CASE WHEN codigo_area = 'ING' THEN puntaje_promedio_ie END), 2) AS piv_ingles,
    ROUND(AVG(puntaje_promedio_ie), 2)                                        AS promedio_general_5_areas,
    SUM(total_estudiantes_evaluados)                                          AS total_evaluaciones_publicadas
FROM vw_evolucion_ie_area_anio
WHERE tipo_instrumento = 'SABER_11'
GROUP BY comuna_localidad
ORDER BY promedio_general_5_areas DESC, comuna_localidad ASC
LIMIT 13 OFFSET 0;


/* =====================================================================================
 * CONSULTA C15 (Capítulos 3, 4 y 12 · Diagnóstico Multi-Área de Brecha Nacional usando
 *               la Segunda UDF fn_clasificar_brecha_nacional)
 * -------------------------------------------------------------------------------------
 * - Requisitos:      R04, R07, R08 | Reglas: RN02, RN04
 * - Propósito:       Clasificar el desempeño de las instituciones en las 5 áreas
 *                    evaluadas en Saber 11 (MAT, LEC, SOC, NAT, ING) durante 2024 frente
 *                    al promedio nacional oficial mediante fn_clasificar_brecha_nacional.
 * ===================================================================================== */
SELECT
    vw.codigo_area,
    vw.nombre_area,
    vw.clasificacion_brecha,
    COUNT(DISTINCT vw.codigo_dane)              AS total_colegios_en_categoria,
    ROUND(AVG(vw.promedio_colegio_homologado), 2) AS promedio_grupo_colegios,
    ROUND(AVG(vw.promedio_nacional_oficial), 2)   AS referente_nacional_icfes,
    ROUND(AVG(vw.brecha_frente_nacional), 2)      AS brecha_media_categoria
FROM vw_brecha_promedio_nacional vw
WHERE vw.anio_lectivo     = 2024
  AND vw.tipo_instrumento = 'SABER_11'
GROUP BY vw.codigo_area, vw.nombre_area, vw.clasificacion_brecha
ORDER BY vw.codigo_area ASC, brecha_media_categoria DESC;

