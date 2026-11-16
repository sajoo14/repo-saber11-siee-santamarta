/* =====================================================================================
 * PROYECTO:       Repositorio de Evolución Saber 11, Evaluaciones Internas (SIEE),
 *                 Simulacros y Planes de Mejoramiento (Colegios Oficiales Santa Marta)
 * ARCHIVO:        12_creacion_esquema_mariadb.sql
 * SGBD / MOTOR:   MariaDB 10.4.32 / 10.11.16 (XAMPP Win64 AMD64) — ENGINE=InnoDB
 * BASE DE DATOS:  repo_saber_siee_sm
 * FECHA:          2026-11-15
 * AUTORÍA:        Trabajo asistido por IA (Metodología Vibe Coding Supervisado v3.0)
 * CODIFICACIÓN:   UTF-8 (CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci)
 * ALCANCE:        DDL estructural puro de creación desde cero (14 tablas, 89 columnas,
 *                 14 PK, 17 FK, 11 UNIQUE, 52 CHECK, 15 DEFAULT, 18 índices secundarios).
 *                 NO incluye datos de prueba (DML separado en Fase 4) ni sentencias
 *                 destructivas. Los objetos programables (UDF, Triggers, SP y Vistas)
 *                 se entregan de forma modular en 12d_objetos_programables_mariadb.sql.
 * PRERREQUISITOS: Ejecutar sobre una instancia MariaDB activa en un esquema vacío de
 *                 desarrollo/pruebas con privilegios CREATE, ALTER, INDEX y REFERENCES.
 * ORDEN DE CREACIÓN (4 Niveles Topológicos sin Ciclos — FOREIGN_KEY_CHECKS = 1):
 *   - Nivel 1 (Maestros independientes):
 *       1. parametro_sistema
 *       2. institucion_educativa
 *       3. escala_evaluacion
 *       4. area_evaluacion
 *   - Nivel 2 (Dimensiones y reglas dependientes del Nivel 1):
 *       5. cohorte
 *       6. transformacion_escala
 *       7. instrumento_evaluacion
 *       8. promedio_nacional_ref
 *       9. plan_mejoramiento
 *   - Nivel 3 (Entidades dependientes del Nivel 2 y Nivel 1):
 *      10. estudiante_seudonimo
 *      11. apoyo_institucional
 *      12. resultado_agregado_ie
 *      13. seguimiento_actividad_plan
 *   - Nivel 4 (Hechos transaccionales de microdatos):
 *      14. resultado_evaluacion
 * NOTA SOBRE COMENTARIOS EN EL CATÁLOGO DE MARIADB (Regla R13):
 *   - MariaDB persiste nativamente en INFORMATION_SCHEMA los atributos COMMENT de:
 *       * Tablas   -> INFORMATION_SCHEMA.TABLES.TABLE_COMMENT
 *       * Columnas -> INFORMATION_SCHEMA.COLUMNS.COLUMN_COMMENT
 *       * Índices  -> INFORMATION_SCHEMA.STATISTICS.INDEX_COMMENT
 *   - Las restricciones PRIMARY KEY, FOREIGN KEY, UNIQUE, CHECK y DEFAULT NO poseen
 *     columna de comentario persistente en INFORMATION_SCHEMA.TABLE_CONSTRAINTS, por
 *     lo que se documentan mediante bloques de comentarios SQL en este script y en el
 *     inventario formal 12a_inventario_documentacion.csv.
 * ESTADO ACTUAL:  PROBADO EN SGBD (Verificado en MariaDB sobre XAMPP local).
 * ===================================================================================== */

-- -------------------------------------------------------------------------------------
-- 0. CONFIGURACIÓN ESTRICTA DE SESIÓN Y ZONA HORARIA
-- -------------------------------------------------------------------------------------
-- Garantiza rechazo estricto de truncamientos, divisiones por cero o fechas inválidas
-- (corrige la ausencia de STRICT_TRANS_TABLES por defecto en my.ini de XAMPP).
SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;
SET SESSION sql_mode = 'STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,NO_ENGINE_SUBSTITUTION,ERROR_FOR_DIVISION_BY_ZERO';
SET time_zone = '-05:00';

-- -------------------------------------------------------------------------------------
-- OPCIÓN REVISABLE DE CREACIÓN DEL ESQUEMA VACÍO DE PRUEBA
-- (Separada explícitamente según directriz F de Entrega DDL)
-- -------------------------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS repo_saber_siee_sm
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE repo_saber_siee_sm;


/* =====================================================================================
 * NIVEL 1 · TABLAS MAESTRAS Y PARÁMETROS INDEPENDIENTES (SIN CLAVES FORÁNEAS)
 * ===================================================================================== */

-- -------------------------------------------------------------------------------------
-- TABLA 1/14: parametro_sistema
-- Propósito: Almacenar parámetros operativos configurables del sistema, en particular
--            UMBRAL_MINIMO_K para impedir la publicación de reportes de grupos pequeños
--            (k-anonimato) conforme a R07 y RN02.
-- -------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS parametro_sistema (
    clave_parametro VARCHAR(50) NOT NULL
        COMMENT 'Clave unica del parametro operativo del sistema (ej. UMBRAL_MINIMO_K para publicacion de reportes agregados).',
    valor_parametro VARCHAR(100) NOT NULL
        COMMENT 'Valor configurado del parametro en formato texto interpretable por las vistas y procedimientos de reporte.',
    descripcion VARCHAR(250) NOT NULL
        COMMENT 'Explicacion funcional del parametro su unidad y el impacto de su modificacion en las reglas de privacidad o negocio.',
    -- DEFAULT def_param_fecha_act: Sella automáticamente la creación y última modificación del parámetro (R07, RN03).
    fecha_actualizacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        COMMENT 'Marca temporal de ultima actualizacion del parametro en zona horaria America/Bogota.',

    -- PK (parametro_sistema): Clave natural sobre el código del parámetro para búsqueda puntual O(1) (R07, RN02).
    PRIMARY KEY (clave_parametro),

    -- CHECK chk_param_clave_no_vacia: Impide registrar claves vacías o compuestas solo por espacios (R07).
    CONSTRAINT chk_param_clave_no_vacia CHECK (TRIM(clave_parametro) <> ''),
    -- CHECK chk_param_valor_no_vacio: Impide valores de parámetro vacíos que dejen indefinido el umbral k (R07, RN02).
    CONSTRAINT chk_param_valor_no_vacio CHECK (TRIM(valor_parametro) <> '')
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Parametros operativos configurables del sistema incluido el umbral minimo k (RN02) para supresion de grupos pequenos en reportes.';


-- -------------------------------------------------------------------------------------
-- TABLA 2/14: institucion_educativa
-- Propósito: Registrar el catálogo maestro de colegios oficiales del Distrito de
--            Santa Marta identificados por su código DANE (R01).
-- -------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS institucion_educativa (
    codigo_dane VARCHAR(12) NOT NULL
        COMMENT 'Codigo DANE oficial de 10 a 12 digitos que identifica univocamente al establecimiento educativo en Santa Marta.',
    nombre_ie VARCHAR(150) NOT NULL
        COMMENT 'Nombre oficial completo de la institucion educativa distrital.',
    comuna_localidad VARCHAR(60) NULL DEFAULT NULL
        COMMENT 'Comuna o localidad geografica del Distrito de Santa Marta donde se ubica la sede principal (supuesto de contexto S02).',
    -- DEFAULT def_ie_sector: Todo colegio del repositorio pertenece por alcance al sector OFICIAL (R01).
    sector VARCHAR(20) NOT NULL DEFAULT 'OFICIAL'
        COMMENT 'Sector administrativo del establecimiento; restringido a OFICIAL conforme al alcance del problema.',
    -- DEFAULT def_ie_calendario: Los colegios oficiales distritales operan por defecto en calendario A (R01).
    calendario CHAR(1) NOT NULL DEFAULT 'A'
        COMMENT 'Calendario academico bajo el cual opera la institucion (A o B).',
    jornada_predominante VARCHAR(20) NULL DEFAULT NULL
        COMMENT 'Jornada escolar predominante del plantel educativo.',
    -- DEFAULT def_ie_estado: Toda institución se registra inicialmente como activa = 1 (R01).
    estado_activa TINYINT(1) NOT NULL DEFAULT 1
        COMMENT 'Indicador booleano (1=activa 0=inactiva) de operacion vigente de la institucion.',

    -- PK (institucion_educativa): Clave natural nacional DANE (R01).
    PRIMARY KEY (codigo_dane),

    -- UNIQUE uq_ie_nombre: Evita duplicar la misma institución educativa bajo distinto código (R01).
    CONSTRAINT uq_ie_nombre UNIQUE KEY (nombre_ie),

    -- Índice secundario idx_ie_comuna: Acelera filtros y agrupaciones territoriales por comuna/localidad (R01, R08).
    INDEX idx_ie_comuna (comuna_localidad)
        COMMENT 'Filtro territorial por comuna o localidad en Santa Marta.',

    -- CHECK chk_ie_dane_formato: Garantiza que el código DANE contenga exclusivamente entre 10 y 12 dígitos (R01).
    CONSTRAINT chk_ie_dane_formato CHECK (codigo_dane REGEXP '^[0-9]{10,12}$'),
    -- CHECK chk_ie_nombre_no_vacio: Impide nombres institucionales vacíos (R01).
    CONSTRAINT chk_ie_nombre_no_vacio CHECK (TRIM(nombre_ie) <> ''),
    -- CHECK chk_ie_sector: Restringe el dominio al sector OFICIAL según el alcance del problema (R01).
    CONSTRAINT chk_ie_sector CHECK (sector = 'OFICIAL'),
    -- CHECK chk_ie_calendario: Restringe el calendario académico a 'A' o 'B' (R01).
    CONSTRAINT chk_ie_calendario CHECK (calendario IN ('A', 'B')),
    -- CHECK chk_ie_jornada: Valida el catálogo de jornadas escolares admitidas cuando el dato no es nulo (R01).
    CONSTRAINT chk_ie_jornada CHECK (
        jornada_predominante IS NULL
        OR jornada_predominante IN ('MANANA', 'TARDE', 'UNICA', 'COMPLETA', 'NOCTURNA')
    ),
    -- CHECK chk_ie_estado: Restringe el indicador booleano a 0 o 1 (R01).
    CONSTRAINT chk_ie_estado CHECK (estado_activa IN (0, 1))
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Catalogo maestro de instituciones educativas oficiales del Distrito de Santa Marta identificadas por su codigo DANE (R01).';


-- -------------------------------------------------------------------------------------
-- TABLA 3/14: escala_evaluacion
-- Propósito: Definir las escalas métricas de calificación con su rango cerrado válido
--            [valor_minimo, valor_maximo], precisión decimal y unidad (R02, RN04, RN05).
-- -------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS escala_evaluacion (
    id_escala INT UNSIGNED NOT NULL AUTO_INCREMENT
        COMMENT 'Identificador subrogado de la escala de calificacion.',
    nombre_escala VARCHAR(60) NOT NULL
        COMMENT 'Nombre identificador de la escala metrica (ej. ICFES_AREA_0_100 ICFES_GLOBAL_0_500 SIEE_1_5).',
    valor_minimo DECIMAL(6,2) NOT NULL
        COMMENT 'Limite inferior cerrado permitido por la escala de evaluacion.',
    valor_maximo DECIMAL(6,2) NOT NULL
        COMMENT 'Limite superior cerrado permitido por la escala de evaluacion.',
    -- DEFAULT def_escala_decimales: Por defecto 0 (solo enteros, como en escalas Icfes estándar) (R02, RN05).
    permite_decimales TINYINT(1) NOT NULL DEFAULT 0
        COMMENT 'Indica si la escala admite valores con fraccion decimal (1=Si 0=Solo enteros).',
    -- DEFAULT def_escala_unidad: Unidad métrica predeterminada en PUNTOS (R02).
    unidad_medida VARCHAR(25) NOT NULL DEFAULT 'PUNTOS'
        COMMENT 'Unidad metrica de expresion del resultado (PUNTOS NOTA PORCENTAJE).',

    -- PK (escala_evaluacion): Clave subrogada INT UNSIGNED (R02, RN05).
    PRIMARY KEY (id_escala),

    -- UNIQUE uq_escala_nombre: Evita registrar dos escalas con el mismo nombre técnico (R02).
    CONSTRAINT uq_escala_nombre UNIQUE KEY (nombre_escala),

    -- CHECK chk_escala_nombre: Impide nombres de escala vacíos (R02).
    CONSTRAINT chk_escala_nombre CHECK (TRIM(nombre_escala) <> ''),
    -- CHECK chk_escala_rango: Garantiza que el límite superior supere estrictamente al inferior (R02, RN05).
    CONSTRAINT chk_escala_rango CHECK (valor_maximo > valor_minimo),
    -- CHECK chk_escala_decimales: Restringe el indicador booleano a 0 o 1 (R02, RN05).
    CONSTRAINT chk_escala_decimales CHECK (permite_decimales IN (0, 1)),
    -- CHECK chk_escala_unidad: Impide unidades de medida vacías (R02).
    CONSTRAINT chk_escala_unidad CHECK (TRIM(unidad_medida) <> '')
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Catalogo de escalas metricas de calificacion con rango valido cerrado [valor_minimo valor_maximo] y precision decimal (R02 RN05).';


-- -------------------------------------------------------------------------------------
-- TABLA 4/14: area_evaluacion
-- Propósito: Catalogar las áreas del conocimiento evaluadas en Saber 11, SIEE y
--            simulacros (MAT, LEC, SOC, NAT, ING, GLOB) (R02, R04, R06, R08).
-- -------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS area_evaluacion (
    id_area INT UNSIGNED NOT NULL AUTO_INCREMENT
        COMMENT 'Identificador subrogado del area de prueba o asignatura evaluada.',
    codigo_area VARCHAR(10) NOT NULL
        COMMENT 'Codigo mnemotecnico estandar del area (ej. MAT LEC SOC NAT ING GLOB).',
    nombre_area VARCHAR(80) NOT NULL
        COMMENT 'Nombre descriptivo oficial del area de conocimiento evaluada.',
    -- DEFAULT def_area_nucleo: Por defecto 1 (pertenece al núcleo común obligatorio) (R02).
    es_nucleo_comun TINYINT(1) NOT NULL DEFAULT 1
        COMMENT 'Indica si el area pertenece al nucleo comun obligatorio de Saber 11 (1=Si 0=No).',

    -- PK (area_evaluacion): Clave subrogada INT UNSIGNED (R02).
    PRIMARY KEY (id_area),

    -- UNIQUE uq_area_codigo: Garantiza unicidad del código corto del área (R02).
    CONSTRAINT uq_area_codigo UNIQUE KEY (codigo_area),
    -- UNIQUE uq_area_nombre: Garantiza unicidad del nombre descriptivo del área (R02).
    CONSTRAINT uq_area_nombre UNIQUE KEY (nombre_area),

    -- CHECK chk_area_codigo: Impide códigos de área vacíos (R02).
    CONSTRAINT chk_area_codigo CHECK (TRIM(codigo_area) <> ''),
    -- CHECK chk_area_nombre: Impide nombres de área vacíos (R02).
    CONSTRAINT chk_area_nombre CHECK (TRIM(nombre_area) <> ''),
    -- CHECK chk_area_nucleo: Restringe el indicador booleano a 0 o 1 (R02).
    CONSTRAINT chk_area_nucleo CHECK (es_nucleo_comun IN (0, 1))
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Catalogo de areas de conocimiento evaluadas en Saber 11 SIEE y simulacros (R02).';


/* =====================================================================================
 * NIVEL 2 · ENTIDADES DEPENDIENTES DEL NIVEL 1
 * ===================================================================================== */

-- -------------------------------------------------------------------------------------
-- TABLA 5/14: cohorte
-- Propósito: Agrupar anualmente a los estudiantes de una institución educativa por año
--            lectivo y jornada escolar (R01, R05, R08).
-- -------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cohorte (
    id_cohorte INT UNSIGNED NOT NULL AUTO_INCREMENT
        COMMENT 'Identificador unico de la cohorte academica anual por institucion y jornada.',
    codigo_dane VARCHAR(12) NOT NULL
        COMMENT 'Codigo DANE de la institucion educativa a la que pertenece la cohorte.',
    anio_lectivo SMALLINT UNSIGNED NOT NULL
        COMMENT 'Anio academico de la cohorte escolar.',
    jornada VARCHAR(20) NOT NULL
        COMMENT 'Jornada academica especifica del grupo en ese anio lectivo.',
    total_matriculados INT UNSIGNED NULL DEFAULT NULL
        COMMENT 'Total de estudiantes matriculados en la cohorte segun registro oficial.',

    -- PK (cohorte): Clave subrogada INT UNSIGNED (R01).
    PRIMARY KEY (id_cohorte),

    -- UNIQUE uq_cohorte_ie_anio_jornada: Clave candidata natural compuesta; además sirve como
    -- índice B-Tree para la FK codigo_dane (prefijo izquierdo, evitando duplicar índice) (R01).
    CONSTRAINT uq_cohorte_ie_anio_jornada UNIQUE KEY (codigo_dane, anio_lectivo, jornada),

    -- Índice secundario idx_cohorte_anio: Optimiza agrupaciones y filtros interanuales en Q1 y Q3 (R01, R08).
    INDEX idx_cohorte_anio (anio_lectivo)
        COMMENT 'Agrupacion y filtro interanual en consultas de evolucion Q1 y Q3.',

    -- FK fk_cohorte_ie: Impide borrar colegios con cohortes históricas (RESTRICT) y propaga
    -- cambios administrativos del código DANE (CASCADE) (R01, RN03).
    CONSTRAINT fk_cohorte_ie FOREIGN KEY (codigo_dane)
        REFERENCES institucion_educativa (codigo_dane)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    -- CHECK chk_cohorte_anio: Acota el año lectivo a un rango histórico/operativo válido (R01, R08).
    CONSTRAINT chk_cohorte_anio CHECK (anio_lectivo BETWEEN 2010 AND 2050),
    -- CHECK chk_cohorte_jornada: Valida el dominio de la jornada escolar de la cohorte (R01).
    CONSTRAINT chk_cohorte_jornada CHECK (jornada IN ('MANANA', 'TARDE', 'UNICA', 'COMPLETA', 'NOCTURNA')),
    -- CHECK chk_cohorte_matriculados: Exige matrícula estrictamente positiva cuando se informe (R01).
    CONSTRAINT chk_cohorte_matriculados CHECK (total_matriculados IS NULL OR total_matriculados > 0)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Cohortes academicas anuales por institucion educativa y jornada escolar en Santa Marta (R01).';


-- -------------------------------------------------------------------------------------
-- TABLA 6/14: transformacion_escala
-- Propósito: Resolver la relación M:N recursiva entre escalas registrando fórmulas de
--            conversión lineal explícitas y justificadas (P_dest = m * P_orig + b) para
--            impedir restas o comparaciones directas entre escalas distintas (R07, RN04).
-- -------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS transformacion_escala (
    id_transformacion INT UNSIGNED NOT NULL AUTO_INCREMENT
        COMMENT 'Identificador unico de la regla de transformacion entre dos escalas distintas.',
    id_escala_origen INT UNSIGNED NOT NULL
        COMMENT 'Identificador de la escala metrica de partida que se desea convertir.',
    id_escala_destino INT UNSIGNED NOT NULL
        COMMENT 'Identificador de la escala metrica objetivo a la que se homologa el puntaje.',
    factor_multiplicador DECIMAL(10,6) NOT NULL
        COMMENT 'Pendiente o factor lineal (m) en la transformacion explicita P_dest = m * P_orig + b.',
    -- DEFAULT def_trans_constante: Intercepto 0.0000 por defecto para conversiones proporcionales directas (R07, RN04).
    constante_desplazamiento DECIMAL(10,4) NOT NULL DEFAULT 0.0000
        COMMENT 'Constante aditiva o intercepto (b) de la formula de transformacion lineal entre escalas.',
    metodo_justificacion TEXT NOT NULL
        COMMENT 'Justificacion tecnica y metodologica aprobada que respalda la transformacion entre escalas.',
    -- DEFAULT def_trans_vigente: Marca como activa (1) la regla al crearse (R07, RN04).
    vigente TINYINT(1) NOT NULL DEFAULT 1
        COMMENT 'Indica si la regla de conversion se encuentra activa (1=Vigente 0=Historica).',

    -- PK (transformacion_escala): Clave subrogada INT UNSIGNED (R07, RN04).
    PRIMARY KEY (id_transformacion),

    -- UNIQUE uq_trans_origen_destino_fact: Evita duplicar la misma fórmula lineal para el mismo par de escalas,
    -- permitiendo conservar múltiples versiones históricas inactivas (vigente = 0) mientras un trigger controla
    -- que a lo sumo exista una regla activa (vigente = 1) por par de escalas (R07, RN04).
    CONSTRAINT uq_trans_origen_destino_fact UNIQUE KEY (id_escala_origen, id_escala_destino, factor_multiplicador, constante_desplazamiento),

    -- Índice secundario idx_trans_escala_destino: Soporta la FK id_escala_destino y búsquedas por escala meta (R07, RN04).
    INDEX idx_trans_escala_destino (id_escala_destino)
        COMMENT 'Soporte de FK y busqueda de conversion hacia escala destino.',

    -- FK fk_trans_escala_orig: Protege la escala origen contra eliminación si tiene reglas asociadas (R07, RN04).
    CONSTRAINT fk_trans_escala_orig FOREIGN KEY (id_escala_origen)
        REFERENCES escala_evaluacion (id_escala)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    -- FK fk_trans_escala_dest: Protege la escala destino contra eliminación si tiene reglas asociadas (R07, RN04).
    CONSTRAINT fk_trans_escala_dest FOREIGN KEY (id_escala_destino)
        REFERENCES escala_evaluacion (id_escala)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    -- CHECK chk_trans_escalas_distintas: Impide transformaciones reflexivas redundantes hacia la misma escala (R07, RN04).
    CONSTRAINT chk_trans_escalas_distintas CHECK (id_escala_origen <> id_escala_destino),
    -- CHECK chk_trans_factor_positivo: Exige pendiente positiva para preservar el orden de mérito (R07, RN04).
    CONSTRAINT chk_trans_factor_positivo CHECK (factor_multiplicador > 0),
    -- CHECK chk_trans_justificacion: Obliga a documentar la justificación metodológica de la conversión (RN04).
    CONSTRAINT chk_trans_justificacion CHECK (TRIM(metodo_justificacion) <> ''),
    -- CHECK chk_trans_vigente: Restringe el indicador booleano de vigencia a 0 o 1 (R07, RN04).
    CONSTRAINT chk_trans_vigente CHECK (vigente IN (0, 1))
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Reglas de transformacion lineal explicita y justificada (P_dest = m * P_orig + b) entre escalas de evaluacion diferentes (R07 RN04).';


-- -------------------------------------------------------------------------------------
-- TABLA 7/14: instrumento_evaluacion
-- Propósito: Catalogar cada instrumento evaluativo aplicado (SABER_11, SIEE, SIMULACRO)
--            indicando su escala métrica, fuente emisora y periodo (R02, R08, RN05, D01).
-- -------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS instrumento_evaluacion (
    id_instrumento INT UNSIGNED NOT NULL AUTO_INCREMENT
        COMMENT 'Identificador unico del instrumento de evaluacion aplicado.',
    id_escala INT UNSIGNED NOT NULL
        COMMENT 'Escala metrica que define el rango valido de calificacion del instrumento.',
    tipo_instrumento VARCHAR(20) NOT NULL
        COMMENT 'Clasificacion del instrumento: prueba externa SABER_11 evaluacion interna SIEE o SIMULACRO.',
    nombre_instrumento VARCHAR(100) NOT NULL
        COMMENT 'Denominacion descriptiva de la prueba o corte evaluativo.',
    fuente_emision VARCHAR(80) NOT NULL
        COMMENT 'Entidad u organismo que disena o emite los resultados del instrumento (Icfes IE Operador).',
    periodo_aplicacion VARCHAR(15) NOT NULL
        COMMENT 'Periodo lectivo o corte de aplicacion de la prueba (ej. 2024-1 2024-2).',

    -- PK (instrumento_evaluacion): Clave subrogada INT UNSIGNED (R02).
    PRIMARY KEY (id_instrumento),

    -- UNIQUE uq_inst_nombre_per_fuente: Evita duplicar el mismo instrumento en igual periodo y fuente (R02).
    CONSTRAINT uq_inst_nombre_per_fuente UNIQUE KEY (nombre_instrumento, periodo_aplicacion, fuente_emision),

    -- Índice secundario idx_inst_escala: Soporta la FK hacia escala_evaluacion (R02, RN05).
    INDEX idx_inst_escala (id_escala)
        COMMENT 'Soporte de FK hacia escala_evaluacion y validacion de rangos.',
    -- Índice secundario idx_inst_tipo_periodo: Acelera filtros por tipo de prueba y periodo en Q1 y Q4 (R02, R08).
    INDEX idx_inst_tipo_periodo (tipo_instrumento, periodo_aplicacion)
        COMMENT 'Filtro compuesto por tipologia de prueba (SABER_11 SIEE SIMULACRO) y periodo.',

    -- FK fk_inst_escala: Garantiza que todo instrumento apunte a una escala válida e impide borrarla (R02, RN05).
    CONSTRAINT fk_inst_escala FOREIGN KEY (id_escala)
        REFERENCES escala_evaluacion (id_escala)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    -- CHECK chk_inst_tipo: Clasificación controlada según Decisión D01 (R02, R08).
    CONSTRAINT chk_inst_tipo CHECK (tipo_instrumento IN ('SABER_11', 'SIEE', 'SIMULACRO')),
    -- CHECK chk_inst_nombre: Impide nombres de instrumento vacíos (R02).
    CONSTRAINT chk_inst_nombre CHECK (TRIM(nombre_instrumento) <> ''),
    -- CHECK chk_inst_fuente: Impide fuentes de emisión vacías (R02).
    CONSTRAINT chk_inst_fuente CHECK (TRIM(fuente_emision) <> ''),
    -- CHECK chk_inst_periodo: Impide periodos de aplicación vacíos (R02, R08).
    CONSTRAINT chk_inst_periodo CHECK (TRIM(periodo_aplicacion) <> '')
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Instrumentos de evaluacion aplicados (SABER_11 SIEE SIMULACRO) con su escala metrica fuente emisora y periodo (R02).';


-- -------------------------------------------------------------------------------------
-- TABLA 8/14: promedio_nacional_ref
-- Propósito: Almacenar los promedios nacionales oficiales de referencia por año, área,
--            escala y fuente oficial. Cumple estrictamente 3FN al desvincularse de
--            id_instrumento (Decisión D03, R04, R08, RN04, RN05).
-- -------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS promedio_nacional_ref (
    id_referente INT UNSIGNED NOT NULL AUTO_INCREMENT
        COMMENT 'Identificador subrogado del registro de promedio nacional de referencia.',
    anio_vigencia SMALLINT UNSIGNED NOT NULL
        COMMENT 'Anio al que corresponde el promedio nacional publicado.',
    id_area INT UNSIGNED NOT NULL
        COMMENT 'Area del conocimiento a la que aplica el referente nacional.',
    id_escala INT UNSIGNED NOT NULL
        COMMENT 'Escala en la que esta expresado el promedio nacional para garantizar comparaciones consistentes.',
    puntaje_promedio DECIMAL(6,2) NOT NULL
        COMMENT 'Valor del promedio nacional oficial reportado para el area y anio.',
    desviacion_estandar DECIMAL(5,2) NULL DEFAULT NULL
        COMMENT 'Desviacion estandar nacional reportada cuando la fuente la suministre.',
    fuente_oficial VARCHAR(100) NOT NULL
        COMMENT 'Documento boletin o resolucion oficial del Icfes de donde proviene el referente.',

    -- PK (promedio_nacional_ref): Clave subrogada INT UNSIGNED (R04).
    PRIMARY KEY (id_referente),

    -- UNIQUE uq_ref_anio_area_esc_fte: Garantiza un único referente por año, área, escala y fuente;
    -- su prefijo izquierdo indexa directamente anio_vigencia (R04, RN04).
    CONSTRAINT uq_ref_anio_area_esc_fte UNIQUE KEY (anio_vigencia, id_area, id_escala, fuente_oficial),

    -- Índice secundario idx_ref_area: Soporta la FK id_area y el cruce por asignatura en Q2 (R04, R08).
    INDEX idx_ref_area (id_area)
        COMMENT 'Soporte de FK y cruce por area en comparacion con promedio nacional (Q2).',
    -- Índice secundario idx_ref_escala: Soporta la FK id_escala y el filtro de misma escala en Q2 (R04, RN04).
    INDEX idx_ref_escala (id_escala)
        COMMENT 'Soporte de FK y verificacion de misma escala en Q2.',

    -- FK fk_ref_area: Garantiza existencia del área evaluada e impide borrarla si tiene referentes (R04).
    CONSTRAINT fk_ref_area FOREIGN KEY (id_area)
        REFERENCES area_evaluacion (id_area)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    -- FK fk_ref_escala: Garantiza existencia de la escala métrica e impide borrarla si tiene referentes (R04, RN04).
    CONSTRAINT fk_ref_escala FOREIGN KEY (id_escala)
        REFERENCES escala_evaluacion (id_escala)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    -- CHECK chk_ref_anio: Acota el año de vigencia a un intervalo válido (R04, R08).
    CONSTRAINT chk_ref_anio CHECK (anio_vigencia BETWEEN 2010 AND 2050),
    -- CHECK chk_ref_promedio: Cota inferior estática no negativa; el rango exacto contra la escala se valida en trigger (R04, RN05).
    CONSTRAINT chk_ref_promedio CHECK (puntaje_promedio >= 0),
    -- CHECK chk_ref_desv: Impide desviaciones estándar negativas (R04).
    CONSTRAINT chk_ref_desv CHECK (desviacion_estandar IS NULL OR desviacion_estandar >= 0),
    -- CHECK chk_ref_fuente: Obliga a documentar la resolución o boletín oficial del referente (R04).
    CONSTRAINT chk_ref_fuente CHECK (TRIM(fuente_oficial) <> '')
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Promedios nacionales oficiales de referencia por anio vigencia area escala y fuente para analisis de brechas en 3FN (R04 D03).';


-- -------------------------------------------------------------------------------------
-- TABLA 9/14: plan_mejoramiento
-- Propósito: Registrar los planes institucionales de mejoramiento formulados por
--            colegio, área académica y año, con diagnóstico base y meta (R06, R08).
-- -------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS plan_mejoramiento (
    id_plan INT UNSIGNED NOT NULL AUTO_INCREMENT
        COMMENT 'Identificador unico del plan de mejoramiento institucional.',
    codigo_dane VARCHAR(12) NOT NULL
        COMMENT 'Codigo DANE de la institucion educativa que formula y ejecuta el plan.',
    id_area INT UNSIGNED NOT NULL
        COMMENT 'Area academica prioritaria intervenida por el plan de mejoramiento.',
    anio_implementacion SMALLINT UNSIGNED NOT NULL
        COMMENT 'Anio lectivo en el que se implementa el plan de mejoramiento.',
    titulo_plan VARCHAR(150) NOT NULL
        COMMENT 'Titulo descriptivo del plan de mejoramiento academico.',
    diagnostico_base TEXT NOT NULL
        COMMENT 'Linea base y problematica detectada en SIEE simulacros o Saber 11 que origina el plan.',
    meta_cuantitativa DECIMAL(6,2) NOT NULL
        COMMENT 'Puntaje promedio objetivo o incremento esperado al cierre del plan.',
    -- DEFAULT def_plan_estado: Todo plan inicia su ciclo de vida en estado FORMULADO (R06).
    estado_plan VARCHAR(20) NOT NULL DEFAULT 'FORMULADO'
        COMMENT 'Estado administrativo actual del plan de mejoramiento.',

    -- PK (plan_mejoramiento): Clave subrogada INT UNSIGNED (R06).
    PRIMARY KEY (id_plan),

    -- UNIQUE uq_plan_ie_area_anio: Garantiza que una institución formule un único plan maestro por área y año (R06).
    CONSTRAINT uq_plan_ie_area_anio UNIQUE KEY (codigo_dane, id_area, anio_implementacion),

    -- Índice secundario idx_plan_ie_anio: Soporta la FK codigo_dane y el cruce por colegio y año en Q4 (R06, R08).
    INDEX idx_plan_ie_anio (codigo_dane, anio_implementacion)
        COMMENT 'Soporte de FK codigo_dane y cruce temporal de planes por colegio y anio (Q4).',
    -- Índice secundario idx_plan_area: Soporta la FK id_area y el cruce por asignatura intervenida en Q4 (R06, R08).
    INDEX idx_plan_area (id_area)
        COMMENT 'Soporte de FK y filtro por area academica intervenida en Q4.',

    -- FK fk_plan_ie: Vincula el plan con el colegio oficial e impide borrar colegios con planes históricos (R06, RN03).
    CONSTRAINT fk_plan_ie FOREIGN KEY (codigo_dane)
        REFERENCES institucion_educativa (codigo_dane)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    -- FK fk_plan_area: Vincula el plan con el área académica intervenida (R06).
    CONSTRAINT fk_plan_area FOREIGN KEY (id_area)
        REFERENCES area_evaluacion (id_area)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    -- CHECK chk_plan_anio: Valida el año de implementación dentro del rango 2010–2050 (R06, R08).
    CONSTRAINT chk_plan_anio CHECK (anio_implementacion BETWEEN 2010 AND 2050),
    -- CHECK chk_plan_titulo: Impide títulos vacíos (R06).
    CONSTRAINT chk_plan_titulo CHECK (TRIM(titulo_plan) <> ''),
    -- CHECK chk_plan_diag: Obliga a describir la línea base o diagnóstico que justifica el plan (R06).
    CONSTRAINT chk_plan_diag CHECK (TRIM(diagnostico_base) <> ''),
    -- CHECK chk_plan_meta: Exige meta cuantitativa estrictamente mayor a cero (R06).
    CONSTRAINT chk_plan_meta CHECK (meta_cuantitativa > 0),
    -- CHECK chk_plan_estado: Controla los estados válidos del ciclo de vida del plan (R06).
    CONSTRAINT chk_plan_estado CHECK (estado_plan IN ('FORMULADO', 'EN_EJECUCION', 'CUMPLIDO', 'CERRADO'))
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Planes de mejoramiento academico formulados por institucion educativa area y anio con linea base y meta cuantitativa (R06).';


/* =====================================================================================
 * NIVEL 3 · ENTIDADES DEPENDIENTES DEL NIVEL 2 Y NIVEL 1
 * ===================================================================================== */

-- -------------------------------------------------------------------------------------
-- TABLA 10/14: estudiante_seudonimo
-- Propósito: Conservar únicamente el hash seudónimo SHA-256 del estudiante y su cohorte.
--            Aplica minimización estricta de privacidad (Regla R9, RN01, Decisión D02):
--            cero nombres, cero documentos reales, sin género ni estrato socioeconómico.
-- -------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS estudiante_seudonimo (
    id_estudiante_hash CHAR(64) NOT NULL
        COMMENT 'Identificador seudonimo en formato hash SHA-256 hexadecimal de 64 caracteres sin datos personales reales.',
    id_cohorte INT UNSIGNED NOT NULL
        COMMENT 'Cohorte institucional a la que pertenece el estudiante seudonimo.',

    -- PK (estudiante_seudonimo): Clave primaria de 64 caracteres fijos sobre el hash SHA-256 (R03, RN01).
    PRIMARY KEY (id_estudiante_hash),

    -- Índice secundario idx_est_cohorte: Soporta la FK id_cohorte y acelera el JOIN hacia cohorte en Q1–Q4 (R01, R03, R08).
    INDEX idx_est_cohorte (id_cohorte)
        COMMENT 'Soporte de FK y JOIN de microdatos de estudiantes hacia su cohorte.',

    -- FK fk_est_cohorte: Impide borrar una cohorte si tiene estudiantes seudonimizados asociados (R01, R03, RN03).
    CONSTRAINT fk_est_cohorte FOREIGN KEY (id_cohorte)
        REFERENCES cohorte (id_cohorte)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    -- CHECK chk_est_hash_hex: Garantiza que solo ingresen cadenas hexadecimales SHA-256 de 64 caracteres,
    -- bloqueando la inserción accidental de nombres o documentos de identidad en claro (RN01, R9).
    CONSTRAINT chk_est_hash_hex CHECK (id_estudiante_hash REGEXP '^[0-9a-fA-F]{64}$')
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Registro seudonimizado de estudiantes mediante hash SHA-256 sin datos personales directos ni atributos demograficos (R03 RN01 D02).';


-- -------------------------------------------------------------------------------------
-- TABLA 11/14: apoyo_institucional
-- Propósito: Registrar apoyos y subsidios recibidos por las cohortes (pago de
--            inscripción Saber 11, financiación de simulacros, material, capacitación)
--            con precisión monetaria en pesos colombianos (COP) (R05, R08).
-- -------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS apoyo_institucional (
    id_apoyo INT UNSIGNED NOT NULL AUTO_INCREMENT
        COMMENT 'Identificador unico del apoyo o incentivo publico registrado.',
    id_cohorte INT UNSIGNED NOT NULL
        COMMENT 'Cohorte escolar beneficiaria del apoyo o financiacion.',
    tipo_apoyo VARCHAR(50) NOT NULL
        COMMENT 'Modalidad del apoyo otorgado (ej. pago de inscripcion Saber 11 o simulacro).',
    -- DEFAULT def_apoyo_entidad: La Alcaldía Distrital de Santa Marta es el financiador principal según el enunciado (R05).
    entidad_financiadora VARCHAR(100) NOT NULL DEFAULT 'ALCALDIA DISTRITAL DE SANTA MARTA'
        COMMENT 'Entidad publica o aliada que aporta los recursos del apoyo.',
    -- DEFAULT def_apoyo_monto: Permite 0.00 cuando se trate de un apoyo no monetizado directamente (R05).
    monto_invertido DECIMAL(14,2) NOT NULL DEFAULT 0.00
        COMMENT 'Valor monetario en pesos colombianos (COP) invertido en el apoyo.',
    beneficiarios_cubiertos INT UNSIGNED NOT NULL
        COMMENT 'Cantidad de estudiantes cubiertos por el apoyo en la cohorte.',
    fecha_desembolso DATE NOT NULL
        COMMENT 'Fecha oficial de asignacion o desembolso del apoyo institucional.',

    -- PK (apoyo_institucional): Clave subrogada INT UNSIGNED (R05).
    PRIMARY KEY (id_apoyo),

    -- Índice secundario idx_apoyo_cohorte: Soporta la FK id_cohorte y la agregación de apoyos en Q4 (R05, R08).
    INDEX idx_apoyo_cohorte (id_cohorte)
        COMMENT 'Soporte de FK y agregacion de apoyos institucionales por cohorte.',
    -- Índice secundario idx_apoyo_fecha: Acelera consultas cronológicas de ejecución presupuestal (R05).
    INDEX idx_apoyo_fecha (fecha_desembolso)
        COMMENT 'Filtro cronologico por fecha de desembolso del apoyo.',

    -- FK fk_apoyo_cohorte: Impide borrar cohortes que hayan recibido apoyos institucionales (R05, RN03).
    CONSTRAINT fk_apoyo_cohorte FOREIGN KEY (id_cohorte)
        REFERENCES cohorte (id_cohorte)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    -- CHECK chk_apoyo_tipo: Restringe la modalidad del apoyo a un catálogo controlado (R05).
    CONSTRAINT chk_apoyo_tipo CHECK (
        tipo_apoyo IN (
            'PAGO_INSCRIPCION',
            'FINANCIACION_SIMULACRO',
            'MATERIAL_PEDAGOGICO',
            'CAPACITACION_DOCENTE',
            'OTRO'
        )
    ),
    -- CHECK chk_apoyo_entidad: Impide entidades financiadoras vacías (R05).
    CONSTRAINT chk_apoyo_entidad CHECK (TRIM(entidad_financiadora) <> ''),
    -- CHECK chk_apoyo_monto: Impide montos financieros negativos (R05).
    CONSTRAINT chk_apoyo_monto CHECK (monto_invertido >= 0.00),
    -- CHECK chk_apoyo_benef: Exige al menos 1 estudiante beneficiario cubierto (R05).
    CONSTRAINT chk_apoyo_benef CHECK (beneficiarios_cubiertos > 0)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Apoyos institucionales y financieros (pago de inscripcion simulacros material capacitacion) asignados por cohorte (R05).';


-- -------------------------------------------------------------------------------------
-- TABLA 12/14: resultado_agregado_ie
-- Propósito: Almacenar resultados consolidados por cohorte, instrumento y área cuando
--            no existan microdatos individuales, registrando cantidad_evaluados para
--            aplicar el umbral mínimo k (R03, R08, RN02, RN03, RN05).
-- -------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS resultado_agregado_ie (
    id_agregado INT UNSIGNED NOT NULL AUTO_INCREMENT
        COMMENT 'Identificador unico del registro de resultado agregado institucional.',
    id_cohorte INT UNSIGNED NOT NULL
        COMMENT 'Cohorte institucional a la que corresponde el resultado consolidado.',
    id_instrumento INT UNSIGNED NOT NULL
        COMMENT 'Instrumento evaluativo sobre el cual se reporta el consolidado institucional.',
    id_area INT UNSIGNED NOT NULL
        COMMENT 'Area de conocimiento evaluada en el reporte agregado.',
    periodo_reporte VARCHAR(15) NOT NULL
        COMMENT 'Periodo academico del consolidado institucional (ej. 2023-2 2024-1).',
    puntaje_promedio DECIMAL(6,2) NOT NULL
        COMMENT 'Puntaje promedio institucional obtenido por el grupo en la escala del instrumento.',
    desviacion_estandar DECIMAL(5,2) NULL DEFAULT NULL
        COMMENT 'Dispersion de los puntajes del grupo cuando sea reportada por la fuente.',
    cantidad_evaluados INT UNSIGNED NOT NULL
        COMMENT 'Tamano del grupo evaluado; se contrasta con el umbral k antes de publicar reportes.',
    fuente_reporte VARCHAR(80) NOT NULL
        COMMENT 'Fuente documental o acta oficial del consolidado institucional.',
    -- DEFAULT def_resag_fecha_reg: Sello temporal automático inmutable de carga del consolidado (RN03).
    fecha_registro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        COMMENT 'Marca temporal de insercion inmutable del resultado agregado.',

    -- PK (resultado_agregado_ie): Clave subrogada INT UNSIGNED (R03).
    PRIMARY KEY (id_agregado),

    -- UNIQUE uq_resag_coh_inst_area_per: Impide duplicar consolidados para la misma cohorte, instrumento,
    -- área y periodo; su prefijo izquierdo soporta directamente la FK id_cohorte (R03, RN03).
    CONSTRAINT uq_resag_coh_inst_area_per UNIQUE KEY (id_cohorte, id_instrumento, id_area, periodo_reporte),

    -- Índice secundario idx_resag_instrumento: Soporta la FK hacia instrumento_evaluacion (R03, R08).
    INDEX idx_resag_instrumento (id_instrumento)
        COMMENT 'Soporte de FK hacia instrumento_evaluacion en consolidados.',
    -- Índice secundario idx_resag_area: Soporta la FK hacia area_evaluacion y agrupaciones por área (R03, R08).
    INDEX idx_resag_area (id_area)
        COMMENT 'Soporte de FK y agrupacion por area en consolidados institucionales.',

    -- FK fk_resag_cohorte: Protege el historial consolidado impidiendo borrar la cohorte (R03, RN03).
    CONSTRAINT fk_resag_cohorte FOREIGN KEY (id_cohorte)
        REFERENCES cohorte (id_cohorte)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    -- FK fk_resag_instrumento: Protege el historial consolidado impidiendo borrar el instrumento (R03, RN03).
    CONSTRAINT fk_resag_instrumento FOREIGN KEY (id_instrumento)
        REFERENCES instrumento_evaluacion (id_instrumento)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    -- FK fk_resag_area: Protege el historial consolidado impidiendo borrar el área evaluada (R03, RN03).
    CONSTRAINT fk_resag_area FOREIGN KEY (id_area)
        REFERENCES area_evaluacion (id_area)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    -- CHECK chk_resag_periodo: Impide periodos de reporte vacíos (R03, R08).
    CONSTRAINT chk_resag_periodo CHECK (TRIM(periodo_reporte) <> ''),
    -- CHECK chk_resag_promedio: Cota inferior estática; el rango exacto contra la escala se valida mediante trigger (R03, RN05).
    CONSTRAINT chk_resag_promedio CHECK (puntaje_promedio >= 0),
    -- CHECK chk_resag_desv: Impide desviaciones estándar negativas (R03).
    CONSTRAINT chk_resag_desv CHECK (desviacion_estandar IS NULL OR desviacion_estandar >= 0),
    -- CHECK chk_resag_cantidad: Exige al menos 1 evaluado registrado; la publicación se controla con UMBRAL_MINIMO_K (R03, RN02).
    CONSTRAINT chk_resag_cantidad CHECK (cantidad_evaluados > 0),
    -- CHECK chk_resag_fuente: Obliga a registrar el acta o fuente documental del consolidado (R03).
    CONSTRAINT chk_resag_fuente CHECK (TRIM(fuente_reporte) <> '')
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Resultados consolidados por cohorte instrumento y area cuando no existen microdatos individuales con control de cantidad de evaluados (R03 RN02 RN03).';


-- -------------------------------------------------------------------------------------
-- TABLA 13/14: seguimiento_actividad_plan
-- Propósito: Conservar el historial inmutable de cortes periódicos de avance de las
--            actividades de cada plan de mejoramiento sin sobrescribir cortes previos
--            (R06, R08, RN03).
-- -------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS seguimiento_actividad_plan (
    id_seguimiento INT UNSIGNED NOT NULL AUTO_INCREMENT
        COMMENT 'Identificador unico del registro de seguimiento de actividad del plan.',
    id_plan INT UNSIGNED NOT NULL
        COMMENT 'Plan de mejoramiento al que pertenece la actividad y su corte de seguimiento.',
    nombre_actividad VARCHAR(150) NOT NULL
        COMMENT 'Descripcion concreta de la actividad pedagogica o academica ejecutada.',
    fecha_seguimiento DATE NOT NULL
        COMMENT 'Fecha de corte en que se verifica el avance de la actividad.',
    -- DEFAULT def_seg_avance: Inicia en 0.00% cuando se registra el primer corte sin avance previo (R06).
    porcentaje_avance_corte DECIMAL(5,2) NOT NULL DEFAULT 0.00
        COMMENT 'Porcentaje de cumplimiento medido en este corte (0.00 a 100.00) sin sobrescribir cortes previos.',
    observaciones TEXT NULL DEFAULT NULL
        COMMENT 'Evidencias logros o dificultades observadas durante el seguimiento.',
    -- DEFAULT def_seg_estado: Inicia en estado PENDIENTE por defecto (R06).
    estado_actividad VARCHAR(20) NOT NULL DEFAULT 'PENDIENTE'
        COMMENT 'Estado operativo de la actividad en la fecha del corte de seguimiento.',

    -- PK (seguimiento_actividad_plan): Clave subrogada INT UNSIGNED (R06, RN03).
    PRIMARY KEY (id_seguimiento),

    -- UNIQUE uq_seg_plan_act_fecha: Clave natural compuesta que impide registrar dos veces el mismo corte
    -- de una actividad del plan en la misma fecha de seguimiento (R06, RN03).
    CONSTRAINT uq_seg_plan_act_fecha UNIQUE KEY (id_plan, nombre_actividad, fecha_seguimiento),

    -- Índice secundario idx_seg_plan_fecha: Soporta la FK id_plan y ordena cronológicamente los cortes (R06, R08).
    INDEX idx_seg_plan_fecha (id_plan, fecha_seguimiento)
        COMMENT 'Soporte de FK id_plan y ordenamiento cronologico de cortes de seguimiento.',

    -- FK fk_seg_plan: Impide eliminar planes de mejoramiento que posean seguimientos registrados (R06, RN03).
    CONSTRAINT fk_seg_plan FOREIGN KEY (id_plan)
        REFERENCES plan_mejoramiento (id_plan)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    -- CHECK chk_seg_actividad: Impide descripciones de actividad vacías (R06).
    CONSTRAINT chk_seg_actividad CHECK (TRIM(nombre_actividad) <> ''),
    -- CHECK chk_seg_avance: Garantiza que el porcentaje de avance esté entre 0.00 y 100.00 (R06).
    CONSTRAINT chk_seg_avance CHECK (porcentaje_avance_corte BETWEEN 0.00 AND 100.00),
    -- CHECK chk_seg_estado: Restringe el estado operativo de la actividad a valores controlados (R06).
    CONSTRAINT chk_seg_estado CHECK (
        estado_actividad IN ('PENDIENTE', 'EN_PROGRESO', 'COMPLETADA', 'REPROGRAMADA')
    )
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Historial inmutable de actividades y cortes periodicos de avance porcentual de los planes de mejoramiento (R06 RN03).';


/* =====================================================================================
 * NIVEL 4 · TABLA DE HECHOS DE MICRODATOS SEUDONIMIZADOS
 * ===================================================================================== */

-- -------------------------------------------------------------------------------------
-- TABLA 14/14: resultado_evaluacion
-- Propósito: Conservar los microdatos inmutables de resultados individuales mediante
--            PK compuesta ternaria (id_estudiante_hash, id_instrumento, id_area)
--            (R03, R08, RN01, RN03, RN05).
-- -------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS resultado_evaluacion (
    id_estudiante_hash CHAR(64) NOT NULL
        COMMENT 'Hash seudonimo del estudiante evaluado (parte 1 de la clave primaria compuesta).',
    id_instrumento INT UNSIGNED NOT NULL
        COMMENT 'Instrumento de evaluacion aplicado (parte 2 de la clave primaria compuesta).',
    id_area INT UNSIGNED NOT NULL
        COMMENT 'Area del conocimiento evaluada (parte 3 de la clave primaria compuesta).',
    puntaje_obtenido DECIMAL(6,2) NOT NULL
        COMMENT 'Puntaje bruto o estandarizado obtenido; validado contra el rango de la escala mediante trigger.',
    percentil_alcanzado DECIMAL(5,2) NULL DEFAULT NULL
        COMMENT 'Ubicacion percentilar del estudiante entre 0.00 y 100.00 cuando aplique.',
    nivel_desempeno VARCHAR(20) NULL DEFAULT NULL
        COMMENT 'Nivel cualitativo oficial reportado por la fuente (Icfes o SIEE).',
    periodo_reporte VARCHAR(15) NOT NULL
        COMMENT 'Periodo academico o cohorte temporal del resultado (ej. 2024-1).',
    fecha_presentacion DATE NOT NULL
        COMMENT 'Fecha de presentacion de la prueba o registro de la evaluacion interna.',
    -- DEFAULT def_res_fecha_reg: Sello temporal automático inmutable de carga del microdato (RN03).
    fecha_registro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        COMMENT 'Marca temporal inmutable de carga del resultado en el repositorio.',

    -- PK Compuesta (resultado_evaluacion): Resuelve la relación ternaria N:M garantizando que
    -- un estudiante seudónimo tenga un único registro inmutable por instrumento y área; su prefijo
    -- izquierdo (id_estudiante_hash) soporta directamente la FK hacia estudiante_seudonimo (R03, RN01, RN03).
    PRIMARY KEY (id_estudiante_hash, id_instrumento, id_area),

    -- Índice secundario idx_res_inst_area: Soporta la FK id_instrumento y optimiza agregaciones
    -- analíticas masivas por instrumento y área en Q1–Q4 (R03, R08).
    INDEX idx_res_inst_area (id_instrumento, id_area)
        COMMENT 'Soporte de FK id_instrumento y agregacion analitica por instrumento y area (Q1-Q4).',
    -- Índice secundario idx_res_area: Soporta directamente la FK id_area y filtros por área (R03, R08).
    INDEX idx_res_area (id_area)
        COMMENT 'Soporte directo de FK hacia area_evaluacion y filtro por area.',
    -- Índice secundario idx_res_periodo_fecha: Optimiza series de tiempo por periodo y fecha (R03, R08).
    INDEX idx_res_periodo_fecha (periodo_reporte, fecha_presentacion)
        COMMENT 'Serie temporal de resultados por periodo de reporte y fecha de presentacion.',

    -- FK fk_res_estudiante: Impide borrar estudiantes seudónimos con evaluaciones registradas (R03, RN01, RN03).
    CONSTRAINT fk_res_estudiante FOREIGN KEY (id_estudiante_hash)
        REFERENCES estudiante_seudonimo (id_estudiante_hash)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    -- FK fk_res_instrumento: Impide borrar instrumentos que tengan resultados registrados (R03, RN03).
    CONSTRAINT fk_res_instrumento FOREIGN KEY (id_instrumento)
        REFERENCES instrumento_evaluacion (id_instrumento)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    -- FK fk_res_area: Impide borrar áreas que tengan resultados registrados (R03, RN03).
    CONSTRAINT fk_res_area FOREIGN KEY (id_area)
        REFERENCES area_evaluacion (id_area)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    -- CHECK chk_res_puntaje_no_neg: Cota inferior estática no negativa; el cumplimiento del intervalo
    -- cerrado [valor_minimo, valor_maximo] de la escala del instrumento se valida en trigger (R03, RN05).
    CONSTRAINT chk_res_puntaje_no_neg CHECK (puntaje_obtenido >= 0.00),
    -- CHECK chk_res_percentil: Acota el percentil entre 0.00 y 100.00 cuando se informe (R03).
    CONSTRAINT chk_res_percentil CHECK (
        percentil_alcanzado IS NULL
        OR (percentil_alcanzado >= 0.00 AND percentil_alcanzado <= 100.00)
    ),
    -- CHECK chk_res_nivel: Valida niveles de desempeño oficiales Icfes y SIEE (R03).
    CONSTRAINT chk_res_nivel CHECK (
        nivel_desempeno IS NULL
        OR nivel_desempeno IN (
            'INSUFICIENTE', 'MINIMO', 'SATISFACTORIO', 'AVANZADO',
            'BAJO', 'BASICO', 'ALTO', 'SUPERIOR'
        )
    ),
    -- CHECK chk_res_periodo: Impide periodos de reporte vacíos (R03, R08).
    CONSTRAINT chk_res_periodo CHECK (TRIM(periodo_reporte) <> '')
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci
  COMMENT='Microdatos historicos inmutables de resultados por estudiante seudonimo instrumento y area evaluada (R03 RN01 RN03 RN05).';

/* =====================================================================================
 * FIN DEL SCRIPT ESTRUCTURAL 12_creacion_esquema_mariadb.sql
 * ===================================================================================== */
