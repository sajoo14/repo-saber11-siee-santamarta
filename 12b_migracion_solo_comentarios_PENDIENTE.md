# 12b · Migración Exclusivamente Documental de Comentarios (PENDIENTE — Sin Esquema Previo)

**Proyecto:** Repositorio Saber 11, Evaluaciones Internas (SIEE), Simulacros y Planes de Mejoramiento (Santa Marta)  
**Motor y Versión:** `MariaDB 10.4.32 / 10.11.16` (`ENGINE=InnoDB`, `utf8mb4_unicode_ci`)  
**Estado:** `BORRADOR NO EJECUTABLE HASTA COTEJAR METADATOS` (Regla R15 — No existe esquema productivo previo)

---

## 1. Justificación de Entrega en Estado `PENDIENTE` (Regla R15)

Conforme a la **Regla R15** del Prompt Maestro:
> *"Entrega `12b_migracion_solo_comentarios_<motor>.sql` exclusivamente cuando conozcas las definiciones reales del esquema existente... Si no hay metadatos reales, entrega `12b_migracion_solo_comentarios_PENDIENTE.md` con los pasos y los datos de esquema necesarios, sin fabricar un SQL listo para ejecutar."*

1. **Verificación del entorno local (`C:\xampp\mysql\data`):** La base de datos `repo_saber_siee_sm` es un desarrollo completamente nuevo (Greenfield) y no poseía tablas preexistentes sin documentar antes de ejecutar `12_creacion_esquema_mariadb.sql`.
2. **Por qué no se fabrica un `ALTER TABLE ... MODIFY COLUMN` a ciegas:** En MySQL y MariaDB, la sentencia `ALTER TABLE <tabla> MODIFY COLUMN <columna> <definicion_completa> COMMENT '...'` **sobreescribe por completo** la definición de la columna. Si se ejecutara sobre una base de datos preexistente sin haber inspeccionado primero `SHOW CREATE TABLE`, cualquier diferencia en `UNSIGNED`, `AUTO_INCREMENT`, `CHARACTER SET`, `COLLATE`, `NULL`/`NOT NULL`, `DEFAULT` o `ON UPDATE CURRENT_TIMESTAMP` alteraría silenciosamente la estructura o provocaría pérdida de atributos.

---

## 2. Insumos Requeridos si en el Futuro Existiera un Esquema Previo a Documentar

Para habilitar un script `12b_migracion_solo_comentarios_mariadb.sql` seguro sobre un entorno existente, se deben extraer primero los siguientes metadatos reales del servidor destino:

```sql
-- 1. Definición exacta vigente de cada una de las 14 tablas
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

-- 2. Metadatos completos de columnas (tipos, nulabilidad, default, extra, collation y comentarios actuales)
SELECT TABLE_NAME, COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE, COLUMN_DEFAULT,
       EXTRA, CHARACTER_SET_NAME, COLLATION_NAME, COLUMN_COMMENT
  FROM INFORMATION_SCHEMA.COLUMNS
 WHERE TABLE_SCHEMA = 'repo_saber_siee_sm'
 ORDER BY TABLE_NAME, ORDINAL_POSITION;
```

---

## 3. Reglas Técnicas y Riesgos Operativos de Migración Documental en MariaDB

Si se llegara a ejecutar una migración exclusivamente documental sobre un esquema existente con datos:

1. **Comentarios de tabla (`ALTER TABLE <tabla> COMMENT = '...'`):**
   * En MariaDB (`InnoDB`), cambiar únicamente el comentario de tabla es una operación de metadatos rápida (`ALGORITHM=INSTANT` o `INPLACE`), pero igualmente adquiere un *Metadata Lock (MDL)* exclusivo breve.
2. **Comentarios de columna (`ALTER TABLE <tabla> MODIFY COLUMN ... COMMENT '...'`):**
   * Exige repetir **íntegramente** la definición real vigente de la columna (por ejemplo: `id_escala INT(10) UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '...'`).
   * **Prohibición de sentencias destructivas:** Nunca debe incluir `DROP`, `TRUNCATE`, `DELETE` ni `UPDATE`.
3. **Confirmación implícita (`Implicit Commit`) y ausencia de `ROLLBACK`:**
   * En MariaDB, toda sentencia `ALTER TABLE` ejecuta un `COMMIT` implícito antes y después de su ejecución; **no puede revertirse con `ROLLBACK`**.
4. **Criterio de parada (`FALLO: NO EJECUTAR MIGRACIÓN`):**
   * Si al comparar el `SHOW CREATE TABLE` antes y después (normalizando espacios y excluyendo únicamente las cláusulas `COMMENT`) existiera cualquier diferencia en tipos, longitudes, signo, nulabilidad, claves o índices, el proceso debe abortarse con estado **`FALLO: NO EJECUTAR MIGRACIÓN`** (Regla R16).
