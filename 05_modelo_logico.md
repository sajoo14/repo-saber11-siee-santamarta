# 05 · Modelo Lógico Relacional (Fase 2)

**Proyecto:** Repositorio Saber 11, SIEE y Planes de Mejoramiento (Santa Marta)  
**Estado:** PROPUESTO (Independiente del SGBD — Pendiente de aprobación de Fase 2 antes de la Puerta del Motor)

---

## 1. Esquema Lógico Relacional (14 Tablas · Dominios Independientes del SGBD)

> **Nota de separación Fase 2 vs. Fase 3 (Regla R5):** Los dominios aquí expresados (`Texto`, `Entero`, `Decimal(p,s)`, `Fecha`, `FechaHora`, `Booleano`) son lógicos y neutrales. Los tipos físicos exactos, secuencias, índices físicos y sintaxis DDL se definirán en Fase 3 tras responder la **Puerta Obligatoria del Motor**.

1. **`INSTITUCION_EDUCATIVA`**
   * **PK:** `codigo_dane` (`Texto(12)`)
   * **Clave alternativa (`UQ`):** `nombre_ie` (`Texto(150)`)
   * **Atributos:** `comuna_localidad` (`Texto(60)`, NULL), `sector` (`Texto(20)`, NOT NULL, dominio `{'OFICIAL'}`), `calendario` (`Caracter(1)`, NOT NULL, dominio `{'A','B'}`), `jornada_predominante` (`Texto(20)`, NULL), `estado_activa` (`Booleano`, NOT NULL).

2. **`COHORTE`**
   * **PK:** `id_cohorte` (`Entero`)
   * **Clave candidata / alternativa (`UQ Compuesta`):** `(codigo_dane, anio_lectivo, jornada)`
   * **FK:** `codigo_dane` $\rightarrow$ `INSTITUCION_EDUCATIVA` (Política lógica: no permitir borrado si tiene cohortes; propagar cambio de código).
   * **Atributos:** `anio_lectivo` (`Entero`, NOT NULL), `jornada` (`Texto(20)`, NOT NULL), `total_matriculados` (`Entero`, NULL, `> 0`).

3. **`ESTUDIANTE_SEUDONIMO`** *(Minimizada según Regla R9)*
   * **PK:** `id_estudiante_hash` (`Texto(64)`) — hash seudónimo no reversible.
   * **FK:** `id_cohorte` $\rightarrow$ `COHORTE` (No permitir borrado si hay estudiantes).
   * *(Sin datos de identificación directa, género ni estrato).*

4. **`ESCALA_EVALUACION`**
   * **PK:** `id_escala` (`Entero`)
   * **Clave alternativa (`UQ`):** `nombre_escala` (`Texto(60)`)
   * **Atributos:** `valor_minimo` (`Decimal(6,2)`, NOT NULL), `valor_maximo` (`Decimal(6,2)`, NOT NULL, `> valor_minimo`), `permite_decimales` (`Booleano`, NOT NULL), `unidad_medida` (`Texto(25)`, NOT NULL).

5. **`TRANSFORMACION_ESCALA`** *(Resuelve M:N recursiva entre escalas — RN04)*
   * **PK:** `id_transformacion` (`Entero`)
   * **Clave alternativa (`UQ Compuesta`):** `(id_escala_origen, id_escala_destino, vigente)` *(donde solo existe una transformación vigente por par de escalas)*.
   * **FK:** `id_escala_origen` $\rightarrow$ `ESCALA_EVALUACION`; `id_escala_destino` $\rightarrow$ `ESCALA_EVALUACION` (`id_escala_origen <> id_escala_destino`).
   * **Atributos:** `factor_multiplicador` (`Decimal(10,6)`, NOT NULL), `constante_desplazamiento` (`Decimal(10,4)`, NOT NULL), `metodo_justificacion` (`Texto largo`, NOT NULL), `vigente` (`Booleano`, NOT NULL).

6. **`INSTRUMENTO_EVALUACION`**
   * **PK:** `id_instrumento` (`Entero`)
   * **Clave alternativa (`UQ Compuesta`):** `(nombre_instrumento, periodo_aplicacion, fuente_emision)`
   * **FK:** `id_escala` $\rightarrow$ `ESCALA_EVALUACION`.
   * **Atributos:** `tipo_instrumento` (`Texto(20)`, NOT NULL, dominio `{'SABER_11','SIEE','SIMULACRO'}`), `nombre_instrumento` (`Texto(100)`, NOT NULL), `fuente_emision` (`Texto(80)`, NOT NULL), `periodo_aplicacion` (`Texto(15)`, NOT NULL).

7. **`AREA_EVALUACION`**
   * **PK:** `id_area` (`Entero`)
   * **Claves alternativas (`UQ`):** `codigo_area` (`Texto(10)`), `nombre_area` (`Texto(80)`).
   * **Atributos:** `es_nucleo_comun` (`Booleano`, NOT NULL).

8. **`RESULTADO_EVALUACION`** *(Resuelve N:M ternaria y garantiza inmutabilidad)*
   * **PK Compuesta:** `(id_estudiante_hash, id_instrumento, id_area)`
   * **FK:** `id_estudiante_hash` $\rightarrow$ `ESTUDIANTE_SEUDONIMO`; `id_instrumento` $\rightarrow$ `INSTRUMENTO_EVALUACION`; `id_area` $\rightarrow$ `AREA_EVALUACION`.
   * **Atributos:** `puntaje_obtenido` (`Decimal(6,2)`, NOT NULL), `percentil_alcanzado` (`Decimal(5,2)`, NULL, `[0,100]`), `nivel_desempeno` (`Texto(20)`, NULL, dato emitido por la fuente), `periodo_reporte` (`Texto(15)`, NOT NULL), `fecha_presentacion` (`Fecha`, NOT NULL), `fecha_registro` (`FechaHora`, NOT NULL).
   * **Regla de integridad:** El puntaje obtenido debe estar dentro de `[valor_minimo, valor_maximo]` de la escala del instrumento; registros históricos inmutables (sin sobrescritura).

9. **`RESULTADO_AGREGADO_IE`** *(Resultados consolidados cuando no existen microdatos)*
   * **PK:** `id_agregado` (`Entero`)
   * **Clave alternativa (`UQ Compuesta`):** `(id_cohorte, id_instrumento, id_area, periodo_reporte)`
   * **FK:** `id_cohorte` $\rightarrow$ `COHORTE`; `id_instrumento` $\rightarrow$ `INSTRUMENTO_EVALUACION`; `id_area` $\rightarrow$ `AREA_EVALUACION`.
   * **Atributos:** `periodo_reporte` (`Texto(15)`, NOT NULL), `puntaje_promedio` (`Decimal(6,2)`, NOT NULL), `desviacion_estandar` (`Decimal(5,2)`, NULL, `>= 0`), `cantidad_evaluados` (`Entero`, NOT NULL, `> 0`), `fuente_reporte` (`Texto(80)`, NOT NULL), `fecha_registro` (`FechaHora`, NOT NULL).

10. **`PROMEDIO_NACIONAL_REF`** *(Corregida en 3FN — sin `id_instrumento`)*
    * **PK:** `id_referente` (`Entero`)
    * **Clave alternativa (`UQ Compuesta`):** `(anio_vigencia, id_area, id_escala, fuente_oficial)`
    * **FK:** `id_area` $\rightarrow$ `AREA_EVALUACION`; `id_escala` $\rightarrow$ `ESCALA_EVALUACION`.
    * **Atributos:** `anio_vigencia` (`Entero`, NOT NULL), `puntaje_promedio` (`Decimal(6,2)`, NOT NULL), `desviacion_estandar` (`Decimal(5,2)`, NULL, `>= 0`), `fuente_oficial` (`Texto(100)`, NOT NULL).

11. **`PLAN_MEJORAMIENTO`** *(Resuelve M:N Institución–Área por año)*
    * **PK:** `id_plan` (`Entero`)
    * **FK:** `codigo_dane` $\rightarrow$ `INSTITUCION_EDUCATIVA`; `id_area` $\rightarrow$ `AREA_EVALUACION`.
    * **Atributos:** `anio_implementacion` (`Entero`, NOT NULL), `titulo_plan` (`Texto(150)`, NOT NULL), `diagnostico_base` (`Texto largo`, NOT NULL), `meta_cuantitativa` (`Decimal(6,2)`, NOT NULL), `estado_plan` (`Texto(20)`, NOT NULL).

12. **`SEGUIMIENTO_ACTIVIDAD_PLAN`** *(Desglosa actividades y cortes de seguimiento sin sobrescribir)*
    * **PK:** `id_seguimiento` (`Entero`)
    * **FK:** `id_plan` $\rightarrow$ `PLAN_MEJORAMIENTO`.
    * **Atributos:** `nombre_actividad` (`Texto(150)`, NOT NULL), `fecha_seguimiento` (`Fecha`, NOT NULL), `porcentaje_avance_corte` (`Decimal(5,2)`, NOT NULL, `[0,100]`), `observaciones` (`Texto largo`, NULL), `estado_actividad` (`Texto(20)`, NOT NULL).

13. **`APOYO_INSTITUCIONAL`**
    * **PK:** `id_apoyo` (`Entero`)
    * **FK:** `id_cohorte` $\rightarrow$ `COHORTE`.
    * **Atributos:** `tipo_apoyo` (`Texto(50)`, NOT NULL), `entidad_financiadora` (`Texto(100)`, NOT NULL), `monto_invertido` (`Decimal(14,2)`, NOT NULL, `>= 0`), `beneficiarios_cubiertos` (`Entero`, NOT NULL, `> 0`), `fecha_desembolso` (`Fecha`, NOT NULL).

14. **`PARAMETRO_SISTEMA`**
    * **PK:** `clave_parametro` (`Texto(50)`)
    * **Atributos:** `valor_parametro` (`Texto(100)`, NOT NULL), `descripcion` (`Texto(250)`, NOT NULL), `fecha_actualizacion` (`FechaHora`, NOT NULL).
