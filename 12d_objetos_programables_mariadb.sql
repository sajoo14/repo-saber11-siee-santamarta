/* =====================================================================================
 * PROYECTO:       Repositorio de Evolución Saber 11, Evaluaciones Internas (SIEE),
 *                 Simulacros y Planes de Mejoramiento (Colegios Oficiales Santa Marta)
 * ARCHIVO:        12d_objetos_programables_mariadb.sql
 * SGBD / MOTOR:   MariaDB 10.4.32 / 10.11.16 (XAMPP Win64 AMD64)
 * BASE DE DATOS:  repo_saber_siee_sm
 * FECHA:          2026-11-15
 * AUTORÍA:        Trabajo asistido por IA (Metodología Vibe Coding Supervisado v3.0)
 * ALCANCE:        Capa de programabilidad completa (supera los mínimos de la Guía General
 *                 y de la Matriz de los 12 Capítulos de Unimagdalena):
 *                   - 2 Funciones Definidas por el Usuario (UDFs):
 *                       * fn_transformar_puntaje (RN04, R07)
 *                       * fn_clasificar_brecha_nacional (RN04, R04, R08)
 *                   - 12 Triggers de Integridad, Coherencia Temporal, Inmutabilidad y Auditoría:
 *                       * trg_res_validar_rango_ins (rango + decimales + coherencia temporal)
 *                       * trg_resag_validar_rango_ins
 *                       * trg_ref_validar_rango_ins
 *                       * trg_trans_unica_vigente_ins (control de única versión vigente = 1)
 *                       * trg_res_inmutabilidad_upd / trg_res_inmutabilidad_del
 *                       * trg_resag_inmutabilidad_upd / trg_resag_inmutabilidad_del
 *                       * trg_seg_inmutabilidad_upd / trg_seg_inmutabilidad_del
 *                       * trg_param_auditoria_upd (validación k >= 5 y sello de auditoría)
 *                       * trg_plan_auditoria_upd (bitácora automática de cambios de meta en plan)
 *                   - 3 Procedimientos Almacenados Transaccionales (ACID + Handlers):
 *                       * sp_registrar_seguimiento_plan (R06, RN03)
 *                       * sp_registrar_apoyo_institucional (R05, R01)
 *                       * sp_actualizar_parametro_sistema (R07, RN02, RN03)
 *                   - 3 Vistas Analíticas con GROUP BY y HAVING (RN02, RN04, Q1–Q4):
 *                       * vw_evolucion_ie_area_anio
 *                       * vw_brecha_promedio_nacional
 *                       * vw_impacto_simulacros_planes
 * PRERREQUISITO:  Haber ejecutado previamente 12_creacion_esquema_mariadb.sql.
 * ESTADO ACTUAL:  PROBADO EN SGBD (Verificado en MariaDB sobre XAMPP local).
 * ===================================================================================== */

USE repo_saber_siee_sm;

SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;
SET SESSION sql_mode = 'STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,NO_ENGINE_SUBSTITUTION,ERROR_FOR_DIVISION_BY_ZERO';
SET time_zone = '-05:00';

-- Limpieza idempotente solo de objetos programables si se re-ejecuta el módulo
DROP VIEW IF EXISTS vw_impacto_simulacros_planes;
DROP VIEW IF EXISTS vw_brecha_promedio_nacional;
DROP VIEW IF EXISTS vw_evolucion_ie_area_anio;

DROP PROCEDURE IF EXISTS sp_actualizar_parametro_sistema;
DROP PROCEDURE IF EXISTS sp_registrar_apoyo_institucional;
DROP PROCEDURE IF EXISTS sp_registrar_seguimiento_plan;

DROP TRIGGER IF EXISTS trg_plan_auditoria_upd;
DROP TRIGGER IF EXISTS trg_param_auditoria_upd;
DROP TRIGGER IF EXISTS trg_trans_unica_vigente_ins;
DROP TRIGGER IF EXISTS trg_seg_inmutabilidad_del;
DROP TRIGGER IF EXISTS trg_seg_inmutabilidad_upd;
DROP TRIGGER IF EXISTS trg_resag_inmutabilidad_del;
DROP TRIGGER IF EXISTS trg_resag_inmutabilidad_upd;
DROP TRIGGER IF EXISTS trg_res_inmutabilidad_del;
DROP TRIGGER IF EXISTS trg_res_inmutabilidad_upd;
DROP TRIGGER IF EXISTS trg_ref_validar_rango_ins;
DROP TRIGGER IF EXISTS trg_resag_validar_rango_ins;
DROP TRIGGER IF EXISTS trg_res_validar_rango_ins;

DROP FUNCTION IF EXISTS fn_clasificar_brecha_nacional;
DROP FUNCTION IF EXISTS fn_transformar_puntaje;

DELIMITER $$

/* =====================================================================================
 * 1. FUNCIONES DEFINIDAS POR EL USUARIO (UDFs) — Regla RN04 y Requisitos R04, R07, R08
 * ===================================================================================== */

-- -------------------------------------------------------------------------------------
-- UDF 1.1: fn_transformar_puntaje (RN04, R07)
-- Propósito: Homologar un puntaje desde p_escala_origen hacia p_escala_destino aplicando
--            exclusivamente una regla vigente y justificada en transformacion_escala:
--            P_dest = ROUND(p_puntaje * factor_multiplicador + constante_desplazamiento, 2).
--            Si las escalas son idénticas retorna el mismo puntaje; si son distintas y
--            NO existe regla vigente, retorna NULL para impedir restas arbitrarias (RN04).
-- -------------------------------------------------------------------------------------
CREATE FUNCTION fn_transformar_puntaje(
    p_puntaje        DECIMAL(6,2),
    p_escala_origen  INT UNSIGNED,
    p_escala_destino INT UNSIGNED
)
RETURNS DECIMAL(6,2)
READS SQL DATA
COMMENT 'Homologa un puntaje entre escalas distintas usando transformacion_escala vigente (RN04).'
BEGIN
    DECLARE v_factor    DECIMAL(10,6) DEFAULT NULL;
    DECLARE v_constante DECIMAL(10,4) DEFAULT NULL;
    DECLARE v_resultado DECIMAL(6,2)  DEFAULT NULL;

    IF p_puntaje IS NULL OR p_escala_origen IS NULL OR p_escala_destino IS NULL THEN
        RETURN NULL;
    END IF;

    -- Caso trivial: misma escala métrica
    IF p_escala_origen = p_escala_destino THEN
        RETURN p_puntaje;
    END IF;

    -- Consulta la regla lineal vigente y justificada en transformacion_escala
    SELECT factor_multiplicador, constante_desplazamiento
      INTO v_factor, v_constante
      FROM transformacion_escala
     WHERE id_escala_origen  = p_escala_origen
       AND id_escala_destino = p_escala_destino
       AND vigente = 1
     LIMIT 1;

    IF v_factor IS NULL THEN
        RETURN NULL;
    END IF;

    SET v_resultado = ROUND((p_puntaje * v_factor) + v_constante, 2);
    RETURN v_resultado;
END$$


-- -------------------------------------------------------------------------------------
-- UDF 1.2: fn_clasificar_brecha_nacional (RN04, R04, R08)
-- Propósito: Homologar el puntaje promedio institucional a la escala del referente
--            nacional mediante fn_transformar_puntaje y clasificar semánticamente la
--            magnitud de la brecha frente al promedio nacional.
-- -------------------------------------------------------------------------------------
CREATE FUNCTION fn_clasificar_brecha_nacional(
    p_puntaje_ie       DECIMAL(6,2),
    p_puntaje_nacional DECIMAL(6,2),
    p_escala_ie        INT UNSIGNED,
    p_escala_nacional  INT UNSIGNED
)
RETURNS VARCHAR(35)
READS SQL DATA
COMMENT 'Homologa escalas y clasifica la brecha de la IE frente al referente nacional (R04 RN04).'
BEGIN
    DECLARE v_homologado DECIMAL(6,2);
    DECLARE v_brecha     DECIMAL(6,2);

    SET v_homologado = fn_transformar_puntaje(p_puntaje_ie, p_escala_ie, p_escala_nacional);

    IF v_homologado IS NULL OR p_puntaje_nacional IS NULL THEN
        RETURN 'ESCALAS_INCOMPATIBLES_RN04';
    END IF;

    SET v_brecha = ROUND(v_homologado - p_puntaje_nacional, 2);

    IF v_brecha >= 2.00 THEN
        RETURN 'SUPERIOR_AL_NACIONAL';
    ELSEIF v_brecha >= -1.99 THEN
        RETURN 'EN_PARIDAD_NACIONAL';
    ELSEIF v_brecha >= -7.99 THEN
        RETURN 'REZAGO_MODERADO';
    ELSE
        RETURN 'REZAGO_CRITICO';
    END IF;
END$$


/* =====================================================================================
 * 2. TRIGGERS DE VALIDACIÓN DE RANGO, COHERENCIA TEMPORAL Y UNICIDAD DE VIGENCIA
 * ===================================================================================== */

-- Trigger 2.1: Validación de rango, decimales y coherencia temporal en microdatos (resultado_evaluacion)
CREATE TRIGGER trg_res_validar_rango_ins
BEFORE INSERT ON resultado_evaluacion
FOR EACH ROW
BEGIN
    DECLARE v_min          DECIMAL(6,2);
    DECLARE v_max          DECIMAL(6,2);
    DECLARE v_decimales    TINYINT(1);
    DECLARE v_anio_cohorte SMALLINT UNSIGNED;

    SELECT e.valor_minimo, e.valor_maximo, e.permite_decimales
      INTO v_min, v_max, v_decimales
      FROM instrumento_evaluacion i
      INNER JOIN escala_evaluacion e ON e.id_escala = i.id_escala
     WHERE i.id_instrumento = NEW.id_instrumento;

    IF NEW.puntaje_obtenido < v_min OR NEW.puntaje_obtenido > v_max THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RN05 Violada: puntaje_obtenido fuera del rango [valor_minimo, valor_maximo] de la escala del instrumento.';
    END IF;

    IF v_decimales = 0 AND NEW.puntaje_obtenido <> FLOOR(NEW.puntaje_obtenido) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RN05 Violada: La escala del instrumento no admite fracciones decimales en puntaje_obtenido.';
    END IF;

    -- Validación de coherencia temporal entre el año de presentación y el año lectivo de la cohorte del estudiante
    SELECT c.anio_lectivo
      INTO v_anio_cohorte
      FROM estudiante_seudonimo es
      INNER JOIN cohorte c ON c.id_cohorte = es.id_cohorte
     WHERE es.id_estudiante_hash = NEW.id_estudiante_hash;

    IF v_anio_cohorte IS NOT NULL AND YEAR(NEW.fecha_presentacion) <> v_anio_cohorte THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Coherencia Temporal Violada: El anio de fecha_presentacion no coincide con el anio_lectivo de la cohorte del estudiante.';
    END IF;
END$$

-- Trigger 2.2: Validación de rango en resultados agregados institucionales (resultado_agregado_ie)
CREATE TRIGGER trg_resag_validar_rango_ins
BEFORE INSERT ON resultado_agregado_ie
FOR EACH ROW
BEGIN
    DECLARE v_min DECIMAL(6,2);
    DECLARE v_max DECIMAL(6,2);

    SELECT e.valor_minimo, e.valor_maximo
      INTO v_min, v_max
      FROM instrumento_evaluacion i
      INNER JOIN escala_evaluacion e ON e.id_escala = i.id_escala
     WHERE i.id_instrumento = NEW.id_instrumento;

    IF NEW.puntaje_promedio < v_min OR NEW.puntaje_promedio > v_max THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RN05 Violada: puntaje_promedio consolidado fuera del rango [valor_minimo, valor_maximo] de la escala.';
    END IF;
END$$

-- Trigger 2.3: Validación de rango en promedios nacionales de referencia (promedio_nacional_ref)
CREATE TRIGGER trg_ref_validar_rango_ins
BEFORE INSERT ON promedio_nacional_ref
FOR EACH ROW
BEGIN
    DECLARE v_min DECIMAL(6,2);
    DECLARE v_max DECIMAL(6,2);

    SELECT valor_minimo, valor_maximo
      INTO v_min, v_max
      FROM escala_evaluacion
     WHERE id_escala = NEW.id_escala;

    IF NEW.puntaje_promedio < v_min OR NEW.puntaje_promedio > v_max THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RN05 Violada: puntaje_promedio nacional fuera del rango [valor_minimo, valor_maximo] de su escala.';
    END IF;
END$$

-- Trigger 2.4: Garantía de única versión vigente (vigente = 1) por par de escalas en transformacion_escala
CREATE TRIGGER trg_trans_unica_vigente_ins
BEFORE INSERT ON transformacion_escala
FOR EACH ROW
BEGIN
    DECLARE v_activas INT DEFAULT 0;

    IF NEW.vigente = 1 THEN
        SELECT COUNT(*)
          INTO v_activas
          FROM transformacion_escala
         WHERE id_escala_origen  = NEW.id_escala_origen
           AND id_escala_destino = NEW.id_escala_destino
           AND vigente = 1;

        IF v_activas > 0 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'RN04 Violada: Ya existe una regla de transformacion vigente=1 para ese par de escalas; desactive la previa antes de activar una nueva.';
        END IF;
    END IF;
END$$


/* =====================================================================================
 * 3. TRIGGERS DE INMUTABILIDAD HISTÓRICA Y AUDITORÍA DE CAMBIOS — Regla RN03 y RN02
 * ===================================================================================== */

-- Trigger 3.1: Bloqueo de UPDATE en resultado_evaluacion
CREATE TRIGGER trg_res_inmutabilidad_upd
BEFORE UPDATE ON resultado_evaluacion
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'RN03 Violada: Los resultados historicos individuales en resultado_evaluacion son inmutables y no pueden sobrescribirse.';
END$$

-- Trigger 3.2: Bloqueo de DELETE en resultado_evaluacion
CREATE TRIGGER trg_res_inmutabilidad_del
BEFORE DELETE ON resultado_evaluacion
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'RN03 Violada: Prohibido eliminar registros historicos de resultado_evaluacion.';
END$$

-- Trigger 3.3: Bloqueo de UPDATE en resultado_agregado_ie
CREATE TRIGGER trg_resag_inmutabilidad_upd
BEFORE UPDATE ON resultado_agregado_ie
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'RN03 Violada: Los resultados consolidados en resultado_agregado_ie son inmutables y no pueden sobrescribirse.';
END$$

-- Trigger 3.4: Bloqueo de DELETE en resultado_agregado_ie
CREATE TRIGGER trg_resag_inmutabilidad_del
BEFORE DELETE ON resultado_agregado_ie
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'RN03 Violada: Prohibido eliminar registros historicos de resultado_agregado_ie.';
END$$

-- Trigger 3.5: Bloqueo de UPDATE en seguimiento_actividad_plan
CREATE TRIGGER trg_seg_inmutabilidad_upd
BEFORE UPDATE ON seguimiento_actividad_plan
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'RN03 Violada: Los cortes de seguimiento de planes no pueden sobrescribirse; inserte un nuevo corte cronologico.';
END$$

-- Trigger 3.6: Bloqueo de DELETE en seguimiento_actividad_plan
CREATE TRIGGER trg_seg_inmutabilidad_del
BEFORE DELETE ON seguimiento_actividad_plan
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'RN03 Violada: Prohibido eliminar cortes historicos de seguimiento_actividad_plan.';
END$$

-- Trigger 3.7: Validación de privacidad y sello de auditoría al actualizar parametro_sistema (RN02, RN03)
CREATE TRIGGER trg_param_auditoria_upd
BEFORE UPDATE ON parametro_sistema
FOR EACH ROW
BEGIN
    IF OLD.clave_parametro = 'UMBRAL_MINIMO_K' AND CAST(NEW.valor_parametro AS SIGNED) < 5 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'RN02 Violada: El parametro UMBRAL_MINIMO_K no puede ser inferior a 5 evaluados por proteccion de k-anonimato estudiantil.';
    END IF;

    SET NEW.fecha_actualizacion = CURRENT_TIMESTAMP;
    SET NEW.descripcion = LEFT(
        CONCAT(
            OLD.descripcion,
            ' [Auditado por ', CURRENT_USER(), ': ', OLD.valor_parametro, ' -> ', NEW.valor_parametro, ']'
        ),
        250
    );
END$$

-- Trigger 3.8: Bitácora automática de auditoría al modificar meta_cuantitativa en plan_mejoramiento (R06, RN03)
CREATE TRIGGER trg_plan_auditoria_upd
AFTER UPDATE ON plan_mejoramiento
FOR EACH ROW
BEGIN
    DECLARE v_ultimo_avance DECIMAL(5,2) DEFAULT 0.00;

    IF OLD.meta_cuantitativa <> NEW.meta_cuantitativa THEN
        SELECT COALESCE(MAX(porcentaje_avance_corte), 0.00)
          INTO v_ultimo_avance
          FROM seguimiento_actividad_plan
         WHERE id_plan = NEW.id_plan;

        INSERT INTO seguimiento_actividad_plan (
            id_plan,
            nombre_actividad,
            fecha_seguimiento,
            porcentaje_avance_corte,
            observaciones,
            estado_actividad
        ) VALUES (
            NEW.id_plan,
            CONCAT('AUDITORIA_CAMBIO_META_', DATE_FORMAT(NOW(6), '%H%i%s%f')),
            CURDATE(),
            v_ultimo_avance,
            CONCAT(
                'Registro automatico de auditoria [Usuario: ', CURRENT_USER(),
                ']: meta_cuantitativa ajustada de ', OLD.meta_cuantitativa,
                ' a ', NEW.meta_cuantitativa,
                ' (estado_plan: ', OLD.estado_plan, ' -> ', NEW.estado_plan, ').'
            ),
            'EN_PROGRESO'
        );
    END IF;
END$$


/* =====================================================================================
 * 4. PROCEDIMIENTOS ALMACENADOS CON CONTROL TRANSACCIONAL ACID (COMMIT / ROLLBACK)
 * ===================================================================================== */

-- -------------------------------------------------------------------------------------
-- Procedimiento 4.1: sp_registrar_seguimiento_plan (R06, RN03)
-- Propósito: Insertar un nuevo corte de avance en seguimiento_actividad_plan sin
--            sobrescribir el historial previo y actualizar de forma atómica el
--            estado_plan en plan_mejoramiento según el progreso alcanzado.
-- -------------------------------------------------------------------------------------
CREATE PROCEDURE sp_registrar_seguimiento_plan(
    IN  p_id_plan           INT UNSIGNED,
    IN  p_nombre_actividad  VARCHAR(150),
    IN  p_fecha_seguimiento DATE,
    IN  p_porcentaje_avance DECIMAL(5,2),
    IN  p_observaciones     TEXT,
    IN  p_estado_actividad  VARCHAR(20),
    OUT p_id_seguimiento    INT UNSIGNED,
    OUT p_nuevo_estado_plan VARCHAR(20)
)
MODIFIES SQL DATA
COMMENT 'Registra un corte inmutable de avance y sincroniza el estado del plan bajo transaccion ACID con COMMIT y ROLLBACK.'
BEGIN
    DECLARE v_estado_actual_plan VARCHAR(20);
    DECLARE v_promedio_avance    DECIMAL(5,2);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- 1. Verificar existencia y estado vigente del plan bloqueando la fila padre (FOR UPDATE)
    SELECT estado_plan
      INTO v_estado_actual_plan
      FROM plan_mejoramiento
     WHERE id_plan = p_id_plan
       FOR UPDATE;

    IF v_estado_actual_plan IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'R06 Error: El id_plan especificado no existe en plan_mejoramiento.';
    END IF;

    IF v_estado_actual_plan = 'CERRADO' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'R06 Error: No se pueden agregar cortes de seguimiento a un plan en estado CERRADO.';
    END IF;

    -- 2. Insertar el nuevo corte de seguimiento (sin sobrescribir cortes anteriores, RN03)
    INSERT INTO seguimiento_actividad_plan (
        id_plan,
        nombre_actividad,
        fecha_seguimiento,
        porcentaje_avance_corte,
        observaciones,
        estado_actividad
    ) VALUES (
        p_id_plan,
        p_nombre_actividad,
        p_fecha_seguimiento,
        p_porcentaje_avance,
        p_observaciones,
        p_estado_actividad
    );

    SET p_id_seguimiento = LAST_INSERT_ID();

    -- 3. Calcular el avance promedio de los últimos cortes por actividad del plan
    SELECT AVG(ult.max_avance)
      INTO v_promedio_avance
      FROM (
          SELECT MAX(porcentaje_avance_corte) AS max_avance
            FROM seguimiento_actividad_plan
           WHERE id_plan = p_id_plan
           GROUP BY nombre_actividad
      ) AS ult;

    -- 4. Determinar y actualizar el estado del plan
    IF v_promedio_avance >= 100.00 THEN
        SET p_nuevo_estado_plan = 'CUMPLIDO';
    ELSEIF v_promedio_avance > 0.00 THEN
        SET p_nuevo_estado_plan = 'EN_EJECUCION';
    ELSE
        SET p_nuevo_estado_plan = v_estado_actual_plan;
    END IF;

    UPDATE plan_mejoramiento
       SET estado_plan = p_nuevo_estado_plan
     WHERE id_plan = p_id_plan;

    COMMIT;
END$$


-- -------------------------------------------------------------------------------------
-- Procedimiento 4.2: sp_registrar_apoyo_institucional (R05, R01)
-- Propósito: Registrar un apoyo institucional validando dentro de una transacción ACID
--            que la cohorte pertenezca a una institución activa y que los beneficiarios
--            cubiertos no superen el total_matriculados de la cohorte cuando esté definido.
-- -------------------------------------------------------------------------------------
CREATE PROCEDURE sp_registrar_apoyo_institucional(
    IN  p_id_cohorte              INT UNSIGNED,
    IN  p_tipo_apoyo              VARCHAR(50),
    IN  p_entidad_financiadora    VARCHAR(100),
    IN  p_monto_invertido         DECIMAL(14,2),
    IN  p_beneficiarios_cubiertos INT UNSIGNED,
    IN  p_fecha_desembolso        DATE,
    OUT p_id_apoyo_generado       INT UNSIGNED
)
MODIFIES SQL DATA
COMMENT 'Inserta un apoyo institucional verificando consistencia de beneficiarios frente a la cohorte con control COMMIT y ROLLBACK.'
BEGIN
    DECLARE v_total_matriculados INT UNSIGNED;
    DECLARE v_ie_activa          TINYINT(1);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- 1. Validar que la cohorte exista y que el colegio esté activo
    SELECT c.total_matriculados, ie.estado_activa
      INTO v_total_matriculados, v_ie_activa
      FROM cohorte c
      INNER JOIN institucion_educativa ie ON ie.codigo_dane = c.codigo_dane
     WHERE c.id_cohorte = p_id_cohorte
       FOR UPDATE;

    IF v_ie_activa IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'R05 Error: La cohorte indicada no existe.';
    END IF;

    IF v_ie_activa = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'R05 Error: No se pueden asignar apoyos a una institucion educativa inactiva.';
    END IF;

    -- 2. Validar coherencia de cupo: beneficiarios <= total_matriculados de la cohorte
    IF v_total_matriculados IS NOT NULL AND p_beneficiarios_cubiertos > v_total_matriculados THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'R05 Error: La cantidad de beneficiarios cubiertos supera el total de matriculados de la cohorte.';
    END IF;

    -- 3. Insertar el apoyo institucional
    INSERT INTO apoyo_institucional (
        id_cohorte,
        tipo_apoyo,
        entidad_financiadora,
        monto_invertido,
        beneficiarios_cubiertos,
        fecha_desembolso
    ) VALUES (
        p_id_cohorte,
        p_tipo_apoyo,
        p_entidad_financiadora,
        p_monto_invertido,
        p_beneficiarios_cubiertos,
        p_fecha_desembolso
    );

    SET p_id_apoyo_generado = LAST_INSERT_ID();

    COMMIT;
END$$


-- -------------------------------------------------------------------------------------
-- Procedimiento 4.3: sp_actualizar_parametro_sistema (R07, RN02, RN03)
-- Propósito: Actualizar un parámetro de gobernanza en parametro_sistema bajo control
--            transaccional ACID, disparando trg_param_auditoria_upd y devolviendo el
--            valor anterior junto con el nuevo valor vigente.
-- -------------------------------------------------------------------------------------
CREATE PROCEDURE sp_actualizar_parametro_sistema(
    IN  p_clave_parametro VARCHAR(50),
    IN  p_nuevo_valor     VARCHAR(100),
    OUT p_valor_anterior  VARCHAR(100)
)
MODIFIES SQL DATA
COMMENT 'Actualiza un parametro de gobernanza con bloqueo FOR UPDATE validacion de k-anonimato y sello de auditoria.'
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT valor_parametro
      INTO p_valor_anterior
      FROM parametro_sistema
     WHERE clave_parametro = p_clave_parametro
       FOR UPDATE;

    IF p_valor_anterior IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'R07 Error: La clave_parametro indicada no existe en parametro_sistema.';
    END IF;

    UPDATE parametro_sistema
       SET valor_parametro = p_nuevo_valor
     WHERE clave_parametro = p_clave_parametro;

    COMMIT;
END$$

DELIMITER ;


/* =====================================================================================
 * 5. VISTAS ANALÍTICAS CON GROUP BY Y HAVING — Reglas RN01, RN02, RN04 y Consultas Q1–Q4
 * =====================================================================================
 * Nota documental (Regla R13): MariaDB no almacena comentarios nativos sobre vistas en
 * INFORMATION_SCHEMA.VIEWS; se documentan mediante bloques SQL y en 12a_inventario_documentacion.csv.
 * ===================================================================================== */

-- -------------------------------------------------------------------------------------
-- Vista 5.1: vw_evolucion_ie_area_anio (Consulta Q1 + Regla RN02 de k-anonimato)
-- -------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_evolucion_ie_area_anio AS
SELECT
    ie.codigo_dane,
    ie.nombre_ie,
    ie.comuna_localidad,
    c.anio_lectivo,
    i.id_instrumento,
    i.tipo_instrumento,
    i.nombre_instrumento,
    i.periodo_aplicacion,
    a.id_area,
    a.codigo_area,
    a.nombre_area,
    e.id_escala,
    e.nombre_escala,
    e.unidad_medida,
    COUNT(re.id_estudiante_hash)              AS total_estudiantes_evaluados,
    ROUND(AVG(re.puntaje_obtenido), 2)        AS puntaje_promedio_ie,
    ROUND(STDDEV_POP(re.puntaje_obtenido), 2) AS desviacion_estandar_ie,
    MIN(re.puntaje_obtenido)                  AS puntaje_minimo_ie,
    MAX(re.puntaje_obtenido)                  AS puntaje_maximo_ie
FROM resultado_evaluacion re
INNER JOIN estudiante_seudonimo es   ON es.id_estudiante_hash = re.id_estudiante_hash
INNER JOIN cohorte c                 ON c.id_cohorte          = es.id_cohorte
INNER JOIN institucion_educativa ie  ON ie.codigo_dane        = c.codigo_dane
INNER JOIN instrumento_evaluacion i  ON i.id_instrumento      = re.id_instrumento
INNER JOIN area_evaluacion a         ON a.id_area             = re.id_area
INNER JOIN escala_evaluacion e       ON e.id_escala           = i.id_escala
GROUP BY
    ie.codigo_dane,
    ie.nombre_ie,
    ie.comuna_localidad,
    c.anio_lectivo,
    i.id_instrumento,
    i.tipo_instrumento,
    i.nombre_instrumento,
    i.periodo_aplicacion,
    a.id_area,
    a.codigo_area,
    a.nombre_area,
    e.id_escala,
    e.nombre_escala,
    e.unidad_medida
HAVING COUNT(re.id_estudiante_hash) >= COALESCE(
    (SELECT CAST(ps.valor_parametro AS UNSIGNED)
       FROM parametro_sistema ps
      WHERE ps.clave_parametro = 'UMBRAL_MINIMO_K'
      LIMIT 1),
    10
);


-- -------------------------------------------------------------------------------------
-- Vista 5.2: vw_brecha_promedio_nacional (Consulta Q2 + Reglas RN02 y RN04)
-- -------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_brecha_promedio_nacional AS
SELECT
    ie.codigo_dane,
    ie.nombre_ie,
    c.anio_lectivo,
    i.tipo_instrumento,
    i.nombre_instrumento,
    a.codigo_area,
    a.nombre_area,
    e_inst.nombre_escala                                                    AS escala_instrumento,
    e_nac.nombre_escala                                                     AS escala_referente_nacional,
    COUNT(re.id_estudiante_hash)                                            AS cantidad_evaluados,
    ROUND(AVG(re.puntaje_obtenido), 2)                                      AS promedio_colegio_escala_orig,
    fn_transformar_puntaje(
        ROUND(AVG(re.puntaje_obtenido), 2),
        i.id_escala,
        pnr.id_escala
    )                                                                       AS promedio_colegio_homologado,
    pnr.puntaje_promedio                                                    AS promedio_nacional_oficial,
    ROUND(
        fn_transformar_puntaje(
            ROUND(AVG(re.puntaje_obtenido), 2),
            i.id_escala,
            pnr.id_escala
        ) - pnr.puntaje_promedio,
        2
    )                                                                       AS brecha_frente_nacional,
    fn_clasificar_brecha_nacional(
        ROUND(AVG(re.puntaje_obtenido), 2),
        pnr.puntaje_promedio,
        i.id_escala,
        pnr.id_escala
    )                                                                       AS clasificacion_brecha,
    pnr.fuente_oficial
FROM resultado_evaluacion re
INNER JOIN estudiante_seudonimo es   ON es.id_estudiante_hash = re.id_estudiante_hash
INNER JOIN cohorte c                 ON c.id_cohorte          = es.id_cohorte
INNER JOIN institucion_educativa ie  ON ie.codigo_dane        = c.codigo_dane
INNER JOIN instrumento_evaluacion i  ON i.id_instrumento      = re.id_instrumento
INNER JOIN area_evaluacion a         ON a.id_area             = re.id_area
INNER JOIN escala_evaluacion e_inst  ON e_inst.id_escala      = i.id_escala
INNER JOIN promedio_nacional_ref pnr ON pnr.anio_vigencia     = c.anio_lectivo
                                    AND pnr.id_area           = a.id_area
INNER JOIN escala_evaluacion e_nac   ON e_nac.id_escala       = pnr.id_escala
GROUP BY
    ie.codigo_dane,
    ie.nombre_ie,
    c.anio_lectivo,
    i.id_instrumento,
    i.tipo_instrumento,
    i.nombre_instrumento,
    i.id_escala,
    a.id_area,
    a.codigo_area,
    a.nombre_area,
    e_inst.nombre_escala,
    e_nac.nombre_escala,
    pnr.id_escala,
    pnr.puntaje_promedio,
    pnr.fuente_oficial
HAVING COUNT(re.id_estudiante_hash) >= COALESCE(
    (SELECT CAST(ps.valor_parametro AS UNSIGNED)
       FROM parametro_sistema ps
      WHERE ps.clave_parametro = 'UMBRAL_MINIMO_K'
      LIMIT 1),
    10
)
AND promedio_colegio_homologado IS NOT NULL;


-- -------------------------------------------------------------------------------------
-- Vista 5.3: vw_impacto_simulacros_planes (Consultas Q3 y Q4 + Regla RN02)
-- -------------------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_impacto_simulacros_planes AS
SELECT
    ie.codigo_dane,
    ie.nombre_ie,
    c.anio_lectivo,
    a.codigo_area,
    a.nombre_area,
    COUNT(DISTINCT CASE WHEN i.tipo_instrumento = 'SIMULACRO' THEN re.id_estudiante_hash END) AS evaluados_simulacro,
    ROUND(AVG(CASE WHEN i.tipo_instrumento = 'SIMULACRO' THEN re.puntaje_obtenido END), 2)    AS promedio_simulacro,
    COUNT(DISTINCT CASE WHEN i.tipo_instrumento = 'SABER_11' THEN re.id_estudiante_hash END)  AS evaluados_saber11,
    ROUND(AVG(CASE WHEN i.tipo_instrumento = 'SABER_11' THEN re.puntaje_obtenido END), 2)     AS promedio_saber11,
    pm.id_plan,
    pm.titulo_plan,
    pm.meta_cuantitativa,
    pm.estado_plan,
    COALESCE(
        (SELECT ROUND(AVG(sap.porcentaje_avance_corte), 2)
           FROM seguimiento_actividad_plan sap
          WHERE sap.id_plan = pm.id_plan),
        0.00
    )                                                                                         AS avance_promedio_plan_pct,
    COALESCE(
        (SELECT SUM(ap.monto_invertido)
           FROM apoyo_institucional ap
          WHERE ap.id_cohorte = c.id_cohorte),
        0.00
    )                                                                                         AS monto_apoyos_cohorte_cop
FROM cohorte c
INNER JOIN institucion_educativa ie  ON ie.codigo_dane        = c.codigo_dane
INNER JOIN estudiante_seudonimo es   ON es.id_cohorte         = c.id_cohorte
INNER JOIN resultado_evaluacion re   ON re.id_estudiante_hash = es.id_estudiante_hash
INNER JOIN instrumento_evaluacion i  ON i.id_instrumento      = re.id_instrumento
INNER JOIN area_evaluacion a         ON a.id_area             = re.id_area
LEFT JOIN plan_mejoramiento pm       ON pm.codigo_dane        = ie.codigo_dane
                                    AND pm.id_area            = a.id_area
                                    AND pm.anio_implementacion = c.anio_lectivo
WHERE i.tipo_instrumento IN ('SIMULACRO', 'SABER_11')
GROUP BY
    c.id_cohorte,
    ie.codigo_dane,
    ie.nombre_ie,
    c.anio_lectivo,
    a.id_area,
    a.codigo_area,
    a.nombre_area,
    pm.id_plan,
    pm.titulo_plan,
    pm.meta_cuantitativa,
    pm.estado_plan
HAVING COUNT(DISTINCT CASE WHEN i.tipo_instrumento = 'SABER_11' THEN re.id_estudiante_hash END) >= COALESCE(
    (SELECT CAST(ps.valor_parametro AS UNSIGNED)
       FROM parametro_sistema ps
      WHERE ps.clave_parametro = 'UMBRAL_MINIMO_K'
      LIMIT 1),
    10
);

/* =====================================================================================
 * FIN DEL SCRIPT DE PROGRAMABILIDAD 12d_objetos_programables_mariadb.sql
 * ===================================================================================== */
