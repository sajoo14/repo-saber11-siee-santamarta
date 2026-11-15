# 10 · Especificación Física del Esquema (Fase 3 · MariaDB 10.11.16 en XAMPP)

**Proyecto:** Repositorio Saber 11, SIEE, Simulacros y Planes de Mejoramiento (Santa Marta)  
**Motor y Versión Confirmados:** `10.11.16-MariaDB` (XAMPP 8.3.36 for Win64 on AMD64)  
**Estado:** PROPUESTO / REVISADO ESTÁTICAMENTE (Sin ejecutar aún DDL en servidor)

---

## 1. Parámetros Físicos Globales del Servidor y Esquema

* **Nombre físico de la base de datos:** `repo_saber_siee_sm`
* **Motor de almacenamiento:** `ENGINE=InnoDB` en las 14 tablas (obligatorio para integridad referencial transaccional ACID y bloqueo a nivel de fila).
* **Codificación y Collation:** `CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci` (soporta tildes, `ñ` y caracteres especiales; se especifica explícitamente para no depender del `utf8mb4_general_ci` por defecto de `my.ini` en XAMPP).
* **Convención de nombres en Windows:** Todas las tablas, columnas, índices y restricciones usan `snake_case` en minúsculas, compatible con `lower_case_table_names=1` de MariaDB sobre Windows.
* **Modo SQL estricto requerido en sesión:** En `C:\xampp\mysql\bin\my.ini` el servidor trae `sql_mode=NO_ZERO_IN_DATE,NO_ZERO_DATE,NO_ENGINE_SUBSTITUTION`. Para impedir truncamientos silenciosos o conversiones implícitas inválidas, el script DDL fijará:
  `SET SESSION sql_mode = 'STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,NO_ENGINE_SUBSTITUTION,ERROR_FOR_DIVISION_BY_ZERO';`
* **Fechas y Zona Horaria:** `DATE` (`YYYY-MM-DD`) para fechas de aplicación/desembolso/seguimiento y `DATETIME` con `DEFAULT CURRENT_TIMESTAMP` para auditoría temporal (`SET time_zone = '-05:00';` — Hora Oficial de Colombia).

---

## 2. Decisiones Físicas de Tipos, Precisión y Claves

1. **Generación de Claves Primarias (PK) y compatibilidad de FKs en InnoDB:**
   * En las tablas con clave subrogada (`cohorte`, `escala_evaluacion`, `transformacion_escala`, `instrumento_evaluacion`, `area_evaluacion`, `promedio_nacional_ref`, `plan_mejoramiento`, `apoyo_institucional`, `resultado_agregado_ie`, `seguimiento_actividad_plan`) se usa **`INT UNSIGNED NOT NULL AUTO_INCREMENT`**.
   * **Justificación técnica InnoDB:** En MariaDB, una columna `FOREIGN KEY` debe tener **exactamente** el mismo tipo físico y signo (`UNSIGNED`) que la `PRIMARY KEY` referenciada. Estandarizar todas las PK/FK enteras en `INT UNSIGNED` evita errores `errno: 150 (Foreign key constraint is incorrectly formed)`.
   * Claves naturales y compuestas conservadas exactamente del modelo lógico (Regla R14):
     * `institucion_educativa`: `codigo_dane VARCHAR(12)`
     * `parametro_sistema`: `clave_parametro VARCHAR(50)`
     * `estudiante_seudonimo`: `id_estudiante_hash CHAR(64)` (longitud fija exacta para SHA-256 en hexadecimal)
     * `resultado_evaluacion`: `PRIMARY KEY (id_estudiante_hash, id_instrumento, id_area)`
2. **Precisión numérica y monetaria:**
   * Puntajes, promedios y metas: `DECIMAL(6,2)` (cubre escalas `0.00` a `500.00` o `1000.00` sin error de coma flotante).
   * Percentiles, desviaciones y porcentajes de avance: `DECIMAL(5,2)` (`0.00` a `100.00`).
   * Coeficientes de transformación de escalas: `factor_multiplicador DECIMAL(10,6)` y `constante_desplazamiento DECIMAL(10,4)`.
   * Montos financieros (`apoyo_institucional.monto_invertido`): `DECIMAL(14,2)` en pesos colombianos (COP).

---

## 3. Orden Estricto de Creación de las 14 Tablas (Sin Dependencias Circulares)

Para que el DDL cree todas las claves foráneas en una sola pasada con `FOREIGN_KEY_CHECKS = 1`:

* **Nivel 1 (Tablas independientes sin FKs):**
  1. `parametro_sistema`
  2. `institucion_educativa`
  3. `escala_evaluacion`
  4. `area_evaluacion`
* **Nivel 2 (Dependen únicamente del Nivel 1):**
  5. `cohorte` *(FK $\rightarrow$ `institucion_educativa`)*
  6. `transformacion_escala` *(FKs $\rightarrow$ `escala_evaluacion`)*
  7. `instrumento_evaluacion` *(FK $\rightarrow$ `escala_evaluacion`)*
  8. `promedio_nacional_ref` *(FKs $\rightarrow$ `area_evaluacion`, `escala_evaluacion`)*
  9. `plan_mejoramiento` *(FKs $\rightarrow$ `institucion_educativa`, `area_evaluacion`)*
* **Nivel 3 (Dependen del Nivel 2 y Nivel 1):**
  10. `estudiante_seudonimo` *(FK $\rightarrow$ `cohorte`)*
  11. `apoyo_institucional` *(FK $\rightarrow$ `cohorte`)*
  12. `resultado_agregado_ie` *(FKs $\rightarrow$ `cohorte`, `instrumento_evaluacion`, `area_evaluacion`)*
  13. `seguimiento_actividad_plan` *(FK $\rightarrow$ `plan_mejoramiento`)*
* **Nivel 4 (Depende del Nivel 3, 2 y 1):**
  14. `resultado_evaluacion` *(FKs $\rightarrow$ `estudiante_seudonimo`, `instrumento_evaluacion`, `area_evaluacion`)*

*Política de integridad referencial en todas las FKs:* `ON DELETE RESTRICT ON UPDATE CASCADE` (protege la inmutabilidad histórica **RN03** impidiendo borrar padres con historial, y propaga cambios administrativos de códigos maestros).

---

## 4. Diseño de Índices sin Duplicación

En InnoDB, cada `PRIMARY KEY` y cada `UNIQUE` generan su propio índice B-Tree. Para no duplicar índices sobre el prefijo izquierdo de una clave existente, se crean **únicamente** los siguientes índices secundarios explícitos:

| Tabla | Nombre del Índice | Columnas | Propósito (FK / Consultas Q1–Q4) |
| :--- | :--- | :--- | :--- |
| `institucion_educativa` | `idx_ie_comuna` | `(comuna_localidad)` | Filtro territorial por comuna en Santa Marta. |
| `cohorte` | `idx_cohorte_anio` | `(anio_lectivo)` | Agrupación interanual en consultas Q1 y Q3 (`codigo_dane` ya es prefijo de `uq_cohorte_ie_anio_jornada`). |
| `transformacion_escala` | `idx_trans_escala_destino` | `(id_escala_destino)` | Soporte de FK y búsqueda de conversión hacia escala destino (`id_escala_origen` ya es prefijo de `uq_trans_origen_destino_vig`). |
| `instrumento_evaluacion` | `idx_inst_escala` | `(id_escala)` | Soporte de FK hacia `escala_evaluacion`. |
| `instrumento_evaluacion` | `idx_inst_tipo_periodo` | `(tipo_instrumento, periodo_aplicacion)` | Filtro rápido de simulacros vs. Saber 11 vs. SIEE por periodo (Q1, Q4). |
| `promedio_nacional_ref` | `idx_ref_area` | `(id_area)` | Soporte de FK y cruce por área en Q2 (`anio_vigencia` es prefijo de `uq_ref_anio_area_esc_fte`). |
| `promedio_nacional_ref` | `idx_ref_escala` | `(id_escala)` | Soporte de FK y cruce por escala en Q2. |
| `plan_mejoramiento` | `idx_plan_ie_anio` | `(codigo_dane, anio_implementacion)` | Soporte de FK y cruce de planes por colegio y año en Q4. |
| `plan_mejoramiento` | `idx_plan_area` | `(id_area)` | Soporte de FK y filtro por área intervenida en Q4. |
| `estudiante_seudonimo` | `idx_est_cohorte` | `(id_cohorte)` | Soporte de FK y `JOIN` estudiante $\rightarrow$ cohorte en Q1, Q3, Q4. |
| `apoyo_institucional` | `idx_apoyo_cohorte` | `(id_cohorte)` | Soporte de FK y cruce de apoyos por cohorte en Q4. |
| `apoyo_institucional` | `idx_apoyo_fecha` | `(fecha_desembolso)` | Filtro cronológico de desembolsos. |
| `resultado_agregado_ie` | `idx_resag_instrumento` | `(id_instrumento)` | Soporte de FK (`id_cohorte` ya es prefijo de `uq_resag_coh_inst_area_per`). |
| `resultado_agregado_ie` | `idx_resag_area` | `(id_area)` | Soporte de FK y agrupación por área. |
| `seguimiento_actividad_plan` | `idx_seg_plan_fecha` | `(id_plan, fecha_seguimiento)` | Soporte de FK y consulta cronológica de cortes de avance del plan. |
| `resultado_evaluacion` | `idx_res_inst_area` | `(id_instrumento, id_area)` | Soporte de FK y agregación por instrumento y área (`id_estudiante_hash` ya es prefijo 1 de la PK). |
| `resultado_evaluacion` | `idx_res_area` | `(id_area)` | Soporte directo de FK hacia `area_evaluacion` y agrupación en Q1–Q3. |
| `resultado_evaluacion` | `idx_res_periodo_fecha` | `(periodo_reporte, fecha_presentacion)` | Serie temporal de evaluaciones en Q1, Q3 y Q4. |

---

## 5. Soporte de `COMMENT` y Límites entre DDL Estático y Lógica Programable

* **Comentarios persistentes en catálogo (Regla R13):** MariaDB 10.11.16 persiste `COMMENT '...'` en `INFORMATION_SCHEMA.TABLES` (`TABLE_COMMENT`) y en `INFORMATION_SCHEMA.COLUMNS` (`COLUMN_COMMENT`), así como `COMMENT` en índices (`INFORMATION_SCHEMA.STATISTICS`). Las restricciones `PK`, `FK`, `UNIQUE` y `CHECK` no poseen columna de comentario en `INFORMATION_SCHEMA.TABLE_CONSTRAINTS`, por lo que se documentan con bloques de comentario SQL en el archivo DDL y en `12a_inventario_documentacion.csv`.
* **Reglas que NO caben en `CHECK` estático de MariaDB y requieren Triggers, Vistas, UDF o Procedimientos (sin hacerlas pasar por DDL básico):**
  1. **Validación cruzada de rango según escala (`RN05`):** En MariaDB un `CHECK` no puede hacer `SELECT valor_minimo, valor_maximo FROM escala_evaluacion`. Requiere **Triggers `BEFORE INSERT` / `BEFORE UPDATE`** sobre `resultado_evaluacion`, `resultado_agregado_ie` y `promedio_nacional_ref`.
  2. **Inmutabilidad histórica (`RN03`):** Impedir que un `UPDATE` o `DELETE` sobrescriba o borre registros en `resultado_evaluacion`, `resultado_agregado_ie` y `seguimiento_actividad_plan` requiere **Triggers `BEFORE UPDATE` / `BEFORE DELETE`** que lancen `SIGNAL SQLSTATE '45000'`.
  3. **Supresión de grupos pequeños ($k$-anonimato, `RN02`):** Verificar que `COUNT(*)` o `cantidad_evaluados` sea $\ge$ al valor de `UMBRAL_MINIMO_K` en `parametro_sistema` requiere **Vistas Analíticas con `GROUP BY ... HAVING`** y/o **Procedimientos Almacenados**.
  4. **Conversión entre escalas (`RN04`):** Aplicar la fórmula `puntaje * factor_multiplicador + constante_desplazamiento` consultando `transformacion_escala` requiere una **Función Definida por el Usuario (UDF)** o cruce explícito en vistas/consultas.
  5. **Prevención de doble conteo (Riesgo R-01):** No sumar `resultado_evaluacion` y `resultado_agregado_ie` para una misma cohorte/instrumento/área se controla en las **Vistas y Consultas Analíticas** (y procedimiento de carga).
