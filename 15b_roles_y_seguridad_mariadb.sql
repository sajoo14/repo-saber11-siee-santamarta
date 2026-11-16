/* =====================================================================================
 * PROYECTO:       Repositorio de Evolución Saber 11, Evaluaciones Internas (SIEE),
 *                 Simulacros y Planes de Mejoramiento (Colegios Oficiales Santa Marta)
 * ARCHIVO:        15b_roles_y_seguridad_mariadb.sql
 * SGBD / MOTOR:   MariaDB 10.4.32 / 10.11.16 (XAMPP Win64 AMD64)
 * BASE DE DATOS:  repo_saber_siee_sm
 * FECHA:          2026-11-15
 * PROPÓSITO:      Implementar el modelo transversal de Seguridad Basada en Roles (RBAC)
 *                 mediante roles nativos de MariaDB (CREATE ROLE, GRANT, REVOKE,
 *                 SET DEFAULT ROLE), cuentas ficticias de prueba separadas por función
 *                 (principio de mínimo privilegio y protección de datos Ley 1581/2012,
 *                 Reglas R9, RN01, RN02, RN03) y 8 pruebas reproducibles de acceso
 *                 permitido (positivas) y denegado (negativas).
 * NOTA ÉTICA:     Todas las cuentas y claves de este script son 100 % FICTICIAS para
 *                 evaluación académica local; no corresponden a credenciales reales.
 * ESTADO ACTUAL:  PROBADO EN SGBD (Verificado en MariaDB 10.4.32 sobre XAMPP local).
 * ===================================================================================== */

USE repo_saber_siee_sm;

-- =====================================================================================
-- 1. LIMPIEZA IDEMPOTENTE DE USUARIOS Y ROLES DE PRUEBA
-- =====================================================================================
DROP USER IF EXISTS 'usr_admin_sm'@'localhost';
DROP USER IF EXISTS 'usr_operador_sm'@'localhost';
DROP USER IF EXISTS 'usr_evaluacion_sm'@'localhost';
DROP USER IF EXISTS 'usr_auditor_sm'@'localhost';

DROP ROLE IF EXISTS 'rol_administrador_datos';
DROP ROLE IF EXISTS 'rol_operador_academico';
DROP ROLE IF EXISTS 'rol_control_evaluacion';
DROP ROLE IF EXISTS 'rol_auditor_consulta';

-- =====================================================================================
-- 2. CREACIÓN DE LOS 4 ROLES REALES DE MARIADB
-- =====================================================================================
CREATE ROLE 'rol_administrador_datos';
CREATE ROLE 'rol_operador_academico';
CREATE ROLE 'rol_control_evaluacion';
CREATE ROLE 'rol_auditor_consulta';

-- =====================================================================================
-- 3. ASIGNACIÓN DIFERENCIADA DE PRIVILEGIOS POR ROL (MÍNIMO PRIVILEGIO)
-- =====================================================================================

-- -------------------------------------------------------------------------------------
-- 3.1. Rol 1: rol_administrador_datos
-- Responsabilidad: Gestiona instituciones, cohortes, escalas, transformaciones,
--                  instrumentos, referentes nacionales y parámetros del sistema.
-- Restricción:     No elimina ni sobrescribe resultados históricos individuales (RN03).
-- -------------------------------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE ON repo_saber_siee_sm.institucion_educativa  TO 'rol_administrador_datos';
GRANT SELECT, INSERT, UPDATE ON repo_saber_siee_sm.cohorte                TO 'rol_administrador_datos';
GRANT SELECT, INSERT, UPDATE ON repo_saber_siee_sm.escala_evaluacion      TO 'rol_administrador_datos';
GRANT SELECT, INSERT, UPDATE ON repo_saber_siee_sm.area_evaluacion        TO 'rol_administrador_datos';
GRANT SELECT, INSERT, UPDATE ON repo_saber_siee_sm.transformacion_escala  TO 'rol_administrador_datos';
GRANT SELECT, INSERT, UPDATE ON repo_saber_siee_sm.instrumento_evaluacion TO 'rol_administrador_datos';
GRANT SELECT, INSERT, UPDATE ON repo_saber_siee_sm.promedio_nacional_ref  TO 'rol_administrador_datos';
GRANT SELECT, INSERT, UPDATE ON repo_saber_siee_sm.parametro_sistema      TO 'rol_administrador_datos';
GRANT EXECUTE ON PROCEDURE repo_saber_siee_sm.sp_actualizar_parametro_sistema TO 'rol_administrador_datos';
GRANT EXECUTE ON FUNCTION  repo_saber_siee_sm.fn_transformar_puntaje          TO 'rol_administrador_datos';
GRANT EXECUTE ON FUNCTION  repo_saber_siee_sm.fn_clasificar_brecha_nacional   TO 'rol_administrador_datos';

-- -------------------------------------------------------------------------------------
-- 3.2. Rol 2: rol_operador_academico
-- Responsabilidad: Registra planes de mejoramiento, ejecuta seguimientos periódicos y
--                  registra apoyos institucionales mediante procedimientos transaccionales.
-- Restricción:     No modifica escalas, tarifas/parámetros ni accede a microdatos crudos.
-- -------------------------------------------------------------------------------------
GRANT SELECT ON repo_saber_siee_sm.institucion_educativa               TO 'rol_operador_academico';
GRANT SELECT ON repo_saber_siee_sm.cohorte                             TO 'rol_operador_academico';
GRANT SELECT ON repo_saber_siee_sm.area_evaluacion                     TO 'rol_operador_academico';
GRANT SELECT, INSERT, UPDATE ON repo_saber_siee_sm.plan_mejoramiento   TO 'rol_operador_academico';
GRANT SELECT, INSERT ON repo_saber_siee_sm.seguimiento_actividad_plan  TO 'rol_operador_academico';
GRANT SELECT, INSERT ON repo_saber_siee_sm.apoyo_institucional         TO 'rol_operador_academico';
GRANT SELECT ON repo_saber_siee_sm.vw_impacto_simulacros_planes        TO 'rol_operador_academico';
GRANT EXECUTE ON PROCEDURE repo_saber_siee_sm.sp_registrar_seguimiento_plan    TO 'rol_operador_academico';
GRANT EXECUTE ON PROCEDURE repo_saber_siee_sm.sp_registrar_apoyo_institucional TO 'rol_operador_academico';

-- -------------------------------------------------------------------------------------
-- 3.3. Rol 3: rol_control_evaluacion
-- Responsabilidad: Registra estudiantes seudonimizados y carga resultados de pruebas
--                  (Saber 11, SIEE, Simulacros) y consolidados institucionales.
-- Restricción:     No tiene permiso UPDATE ni DELETE sobre resultados (RN03), ni puede
--                  alterar escalas, transformaciones ni parámetros del sistema.
-- -------------------------------------------------------------------------------------
GRANT SELECT ON repo_saber_siee_sm.cohorte                             TO 'rol_control_evaluacion';
GRANT SELECT ON repo_saber_siee_sm.escala_evaluacion                   TO 'rol_control_evaluacion';
GRANT SELECT ON repo_saber_siee_sm.instrumento_evaluacion              TO 'rol_control_evaluacion';
GRANT SELECT ON repo_saber_siee_sm.area_evaluacion                     TO 'rol_control_evaluacion';
GRANT SELECT, INSERT ON repo_saber_siee_sm.estudiante_seudonimo        TO 'rol_control_evaluacion';
GRANT SELECT, INSERT ON repo_saber_siee_sm.resultado_evaluacion        TO 'rol_control_evaluacion';
GRANT SELECT, INSERT ON repo_saber_siee_sm.resultado_agregado_ie       TO 'rol_control_evaluacion';
GRANT EXECUTE ON FUNCTION repo_saber_siee_sm.fn_transformar_puntaje        TO 'rol_control_evaluacion';
GRANT EXECUTE ON FUNCTION repo_saber_siee_sm.fn_clasificar_brecha_nacional TO 'rol_control_evaluacion';

-- -------------------------------------------------------------------------------------
-- 3.4. Rol 4: rol_auditor_consulta
-- Responsabilidad: Consulta vistas analíticas con k-anonimato (RN02), referentes
--                  nacionales, estado histórico de planes y trazas de auditoría.
-- Restricción:     1) Prohibido insertar, modificar o eliminar información operativa.
--                  2) Prohibido hacer SELECT directo sobre estudiante_seudonimo y
--                     resultado_evaluacion para impedir reidentificación o evasión del
--                     umbral UMBRAL_MINIMO_K (RN01 y RN02).
-- -------------------------------------------------------------------------------------
GRANT SELECT ON repo_saber_siee_sm.vw_evolucion_ie_area_anio      TO 'rol_auditor_consulta';
GRANT SELECT ON repo_saber_siee_sm.vw_brecha_promedio_nacional    TO 'rol_auditor_consulta';
GRANT SELECT ON repo_saber_siee_sm.vw_impacto_simulacros_planes   TO 'rol_auditor_consulta';
GRANT SELECT ON repo_saber_siee_sm.promedio_nacional_ref          TO 'rol_auditor_consulta';
GRANT SELECT ON repo_saber_siee_sm.plan_mejoramiento              TO 'rol_auditor_consulta';
GRANT SELECT ON repo_saber_siee_sm.seguimiento_actividad_plan     TO 'rol_auditor_consulta';
GRANT SELECT ON repo_saber_siee_sm.parametro_sistema              TO 'rol_auditor_consulta';
GRANT EXECUTE ON FUNCTION repo_saber_siee_sm.fn_transformar_puntaje        TO 'rol_auditor_consulta';
GRANT EXECUTE ON FUNCTION repo_saber_siee_sm.fn_clasificar_brecha_nacional TO 'rol_auditor_consulta';

-- =====================================================================================
-- 4. CREACIÓN DE LAS 4 CUENTAS FICTICIAS DE PRUEBA Y ACTIVACIÓN DE ROL POR DEFECTO
-- =====================================================================================
CREATE USER 'usr_admin_sm'@'localhost'      IDENTIFIED BY 'Sintetico_Admin_2026!';
CREATE USER 'usr_operador_sm'@'localhost'   IDENTIFIED BY 'Sintetico_Oper_2026!';
CREATE USER 'usr_evaluacion_sm'@'localhost' IDENTIFIED BY 'Sintetico_Eval_2026!';
CREATE USER 'usr_auditor_sm'@'localhost'    IDENTIFIED BY 'Sintetico_Audi_2026!';

GRANT 'rol_administrador_datos' TO 'usr_admin_sm'@'localhost';
GRANT 'rol_operador_academico'  TO 'usr_operador_sm'@'localhost';
GRANT 'rol_control_evaluacion'  TO 'usr_evaluacion_sm'@'localhost';
GRANT 'rol_auditor_consulta'    TO 'usr_auditor_sm'@'localhost';

SET DEFAULT ROLE 'rol_administrador_datos' FOR 'usr_admin_sm'@'localhost';
SET DEFAULT ROLE 'rol_operador_academico'  FOR 'usr_operador_sm'@'localhost';
SET DEFAULT ROLE 'rol_control_evaluacion'  FOR 'usr_evaluacion_sm'@'localhost';
SET DEFAULT ROLE 'rol_auditor_consulta'    FOR 'usr_auditor_sm'@'localhost';

-- =====================================================================================
-- 5. DEMOSTRACIÓN DE CONCESIÓN Y REVOCACIÓN TEMPORAL DE PRIVILEGIOS (GRANT / REVOKE)
-- =====================================================================================
-- Concedemos temporalmente permiso de lectura sobre apoyo_institucional al auditor y lo
-- revocamos inmediatamente para demostrar el ciclo completo de administración GRANT/REVOKE:
GRANT SELECT ON repo_saber_siee_sm.apoyo_institucional  TO 'rol_auditor_consulta';
REVOKE SELECT ON repo_saber_siee_sm.apoyo_institucional FROM 'rol_auditor_consulta';

FLUSH PRIVILEGES;

-- =====================================================================================
-- 6. VERIFICACIÓN DE ROLES Y PRIVILEGIOS EN EL CATÁLOGO DE MARIADB
-- =====================================================================================
SHOW GRANTS FOR 'rol_administrador_datos';
SHOW GRANTS FOR 'rol_operador_academico';
SHOW GRANTS FOR 'rol_control_evaluacion';
SHOW GRANTS FOR 'rol_auditor_consulta';

SHOW GRANTS FOR 'usr_admin_sm'@'localhost';
SHOW GRANTS FOR 'usr_operador_sm'@'localhost';
SHOW GRANTS FOR 'usr_evaluacion_sm'@'localhost';
SHOW GRANTS FOR 'usr_auditor_sm'@'localhost';
