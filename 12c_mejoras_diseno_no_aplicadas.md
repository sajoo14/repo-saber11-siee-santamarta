# 12c · Reporte Separado de Mejoras de Diseño No Aplicadas (Regla R14)

**Proyecto:** Repositorio Saber 11, Evaluaciones Internas (SIEE), Simulacros y Planes de Mejoramiento (Santa Marta)  
**Motor y Versión:** `MariaDB 10.4.32 / 10.11.16` (`ENGINE=InnoDB`, `utf8mb4_unicode_ci`)  
**Estado:** `REVISADO ESTÁTICAMENTE` (Cumplimiento de Inmutabilidad del Diseño Aprobado — Regla R14)

---

## 1. Propósito de este Documento

De acuerdo con la **Regla R14 (Inmutabilidad del diseño aprobado)** y el apartado **C de la Entrega DDL** del Prompt Maestro:
> *"Documentar no autoriza rediseñar. Durante la entrega DDL o la migración documental conserva exactamente los nombres, tipos, longitudes, precisión, signo, NULL/NOT NULL, DEFAULT, PK, FK, UNIQUE, CHECK, índices, orden y condiciones de generación, collation, motor de almacenamiento y relaciones que quedaron aprobados... Las propuestas de rediseño se registran en un reporte aparte y nunca se aplican silenciosamente."*

El archivo `12_creacion_esquema_mariadb.sql` conserva **1 a 1** las 14 tablas, 89 columnas, tipos físicos, restricciones e índices aprobados en la Fase 3 (`09_diccionario_fisico.csv` y `10_especificacion_fisica.md`). A continuación se documentan tres oportunidades de mejora identificadas durante la auditoría técnica que **NO fueron aplicadas** para respetar estrictamente el congelamiento del diseño aprobado.

---

## 2. Registro de Mejoras Potenciales No Aplicadas

| ID | Objeto Afectado | Gravedad | Requisito Relacionado | Descripción de la Observación | Cambio Alternativo Propuesto (Futuro) | Consecuencia de No Aplicarlo Ahora |
| :---: | :--- | :---: | :---: | :--- | :--- | :--- |
| **M-01** | `transformacion_escala` (`uq_trans_origen_destino_vig`) | Baja | `R07`, `RN04` | La clave única compuesta `(id_escala_origen, id_escala_destino, vigente)` impide dos reglas vigentes (`vigente = 1`) para el mismo par de escalas, pero también impide conservar más de una regla histórica inactiva (`vigente = 0`) para el mismo par. | En motores con índices únicos parciales o usando columna generada virtual (`vigente_unico AS (IF(vigente=1, 1, NULL)) PERSISTENT`), indexar `(id_escala_origen, id_escala_destino, vigente_unico)`. | Ningún impacto en la operación actual: para cada par de escalas se maneja una regla vigente y a lo sumo una histórica previa. |
| **M-02** | Esquema general (Cupo de tabla #15) | Baja (Informativa) | `RN03` | Los triggers `BEFORE UPDATE` y `BEFORE DELETE` (`trg_res_inmutabilidad_*`) rechazan con `SIGNAL SQLSTATE '45000'` cualquier intento de sobrescritura o borrado. Como el `SIGNAL` aborta la transacción activa, cualquier `INSERT` en una tabla de bitácora dentro del mismo trigger también haría rollback. | Usar el cupo libre #15 (`auditoria_accesos_reportes`) únicamente si se desea registrar eventos exitosos de consulta/inserción vía procedimientos almacenados, manteniendo el modelo dentro del tope de 8 a 15 tablas. | El modelo se mantiene limpio en **14 tablas**, sin complejidad artificial (**R12**) y con bloqueo preventivo estricto de inmutabilidad (**RN03**). |
| **M-03** | `resultado_evaluacion` / `resultado_agregado_ie` | Media (Analítica) | `R03`, `R08`, `Riesgo R-01` | Ambas tablas pueden almacenar resultados del mismo colegio y año si en un periodo se cargaron microdatos y en otro consolidados. | Crear una restricción por trigger de exclusión mutua por `(id_cohorte, id_instrumento, id_area)` o mantener las vistas analíticas separadas por nivel de granularidad. | Mitigado en la capa de vistas (`12d_objetos_programables_mariadb.sql`): ninguna vista suma `resultado_evaluacion` y `resultado_agregado_ie` al mismo tiempo. |
