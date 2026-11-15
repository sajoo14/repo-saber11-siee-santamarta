# 11 · Verificación Previa de Compatibilidad y Entorno (Fase 3)

**Proyecto:** Repositorio Saber 11, SIEE, Simulacros y Planes de Mejoramiento (Santa Marta)  
**Entorno Inspeccionado:** XAMPP Windows x64 (`C:\xampp\mysql\bin\mysqld.exe` — `10.11.16-MariaDB`)  
**Estado:** REVISADO ESTÁTICAMENTE + ENTORNO BINARIO VERIFICADO

---

## 1. Comprobación Técnica del Entorno Local XAMPP

| Aspecto | Valor Observado en el Equipo (`C:\xampp`) | Impacto en el Diseño Físico |
| :--- | :--- | :--- |
| **Binario del servidor** | `10.11.16-MariaDB` (Win64 AMD64) | Soporta `CHECK` reales, `COMMENT` en tablas/columnas/índices, `DATETIME DEFAULT CURRENT_TIMESTAMP` y funciones de ventana (`LAG`/`LEAD`). |
| **Puerto en `my.ini`** | `3306` | Puerto estándar para conexión desde cliente CLI o phpMyAdmin. |
| **Charset / Collation en `my.ini`** | `character-set-server=utf8mb4` / `collation-server=utf8mb4_general_ci` | Se definirá `COLLATE utf8mb4_unicode_ci` explícitamente en el esquema y tablas para ordenamiento español preciso. |
| **`sql_mode` en `my.ini`** | `NO_ZERO_IN_DATE,NO_ZERO_DATE,NO_ENGINE_SUBSTITUTION` | **Hallazgo crítico:** XAMPP no activa `STRICT_TRANS_TABLES` por defecto. Se incluirá `SET SESSION sql_mode = 'STRICT_TRANS_TABLES,...'` en los scripts para garantizar rechazo estricto de datos inválidos. |

---

## 2. Lista de Chequeo de Compatibilidad MariaDB 10.11.16 (Pre-DDL)

* [x] **Coincidencia exacta de tipos en Claves Foráneas (InnoDB):** Todas las PK y FK enteras usan `INT UNSIGNED` (`escala_evaluacion`, `area_evaluacion`, `cohorte`, `transformacion_escala`, `instrumento_evaluacion`, `promedio_nacional_ref`, `plan_mejoramiento`, `estudiante_seudonimo`, `apoyo_institucional`, `resultado_agregado_ie`, `seguimiento_actividad_plan`, `resultado_evaluacion`) y las de texto usan `VARCHAR(12)` (`codigo_dane`) o `CHAR(64)` (`id_estudiante_hash`) con igual charset y collation.
* [x] **Longitud de índices `UNIQUE` compuestos bajo `utf8mb4`:** En InnoDB con `utf8mb4` (4 bytes por carácter), el límite de prefijo de índice es 3072 bytes. La clave `UNIQUE` más larga es `uq_inst_nombre_per_fuente` (`100 + 15 + 80 = 195` caracteres $\times 4 = 780$ bytes), muy por debajo de 3072 bytes.
* [x] **Expresiones `CHECK` soportadas por MariaDB 10.11:** Todas las cláusulas `CHECK` diseñadas usan operadores deterministas sobre la misma fila (`IN`, `BETWEEN`, `>`, `>=`, `<>`, `TRIM`, `REGEXP`). Ningún `CHECK` incluye subconsultas ni funciones no deterministas.
* [x] **Conservación íntegra del diseño lógico aprobado (Regla R14):** Las 14 tablas, sus 89 columnas, sus PKs (incluyendo la PK compuesta de 3 columnas en `resultado_evaluacion`), sus 5 claves `UNIQUE` compuestas y sus 17 relaciones `FOREIGN KEY` coinciden 1 a 1 con `05_modelo_logico.md`.
* [x] **Existencia de esquema previo (Regla R15):** En esta etapa se trata de un diseño desde cero (no hay esquema previo en producción reportado por el usuario), por lo que en la siguiente etapa aplicará `12b_migracion_solo_comentarios_PENDIENTE.md` salvo que indiques una BD preexistente para cotejar.
