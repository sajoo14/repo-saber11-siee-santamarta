# 06 · Normalización (1FN, 2FN, 3FN) y Dependencias Funcionales (Fase 2)

**Proyecto:** Repositorio Saber 11, SIEE y Planes de Mejoramiento (Santa Marta)  
**Estado:** APROBADO (Normalización 1FN, 2FN y 3FN Verificada)

---

## 1. Proceso de Normalización Paso a Paso y Anomalías Prevenidas

Partiendo de una sábana plana no normalizada (**UNF**) donde cada registro mezcla colegio, cohorte, estudiante, notas de 5 áreas en columnas repetitivas, escala, promedio nacional, apoyos separados por comas y actividades/avances del plan:

1. **Primera Forma Normal (1FN — Atomicidad y cero grupos repetitivos):**
   * *Transformación:* Las notas de áreas (`puntaje_mat`, `puntaje_lec`, etc.), los múltiples apoyos y las múltiples actividades/seguimientos de un plan se separan en filas atómicas dentro de `RESULTADO_EVALUACION`, `APOYO_INSTITUCIONAL` y `SEGUIMIENTO_ACTIVIDAD_PLAN`.
   * *Anomalías prevenidas:* Impide límites fijos de columnas (ej. si entra una nueva área o un plan tiene 10 actividades y 4 cortes de seguimiento) y evita parsear listas separadas por comas.

2. **Segunda Forma Normal (2FN — Eliminación de dependencias parciales):**
   * *Transformación:* En las relaciones con clave compuesta o candidata múltiple (`RESULTADO_EVALUACION` con `(id_estudiante_hash, id_instrumento, id_area)` y `RESULTADO_AGREGADO_IE`), los atributos propios de la cohorte (`total_matriculados`), del instrumento (`fuente_emision`, `id_escala`) y del área (`nombre_area`) dependían solo de una parte de la clave. Se extraen a `COHORTE`, `INSTRUMENTO_EVALUACION` y `AREA_EVALUACION`.
   * *Anomalías prevenidas:* **Inserción** (no poder crear un instrumento o área sin tener antes un estudiante evaluado); **Modificación** (tener que editar `nombre_instrumento` en miles de filas); **Eliminación** (perder la metadata del área o instrumento si se retira una cohorte de prueba).

3. **Tercera Forma Normal (3FN — Eliminación de dependencias transitivas):**
   * *Transformación:*
     * `id_estudiante_hash -> id_cohorte -> codigo_dane -> nombre_ie`: se separa en `ESTUDIANTE_SEUDONIMO`, `COHORTE` e `INSTITUCION_EDUCATIVA`.
     * `id_instrumento -> id_escala -> (valor_minimo, valor_maximo)`: se separa `ESCALA_EVALUACION`.
     * **Corrección clave detectada en auditoría sobre `PROMEDIO_NACIONAL_REF`:** En el borrador previo tenía `id_instrumento` en la PK junto con `id_escala` fuera de la clave. Como `id_instrumento -> id_escala`, existía dependencia transitiva. Al reemplazar `id_instrumento` por la clave natural `(anio_vigencia, id_area, id_escala, fuente_oficial)` queda estrictamente en **3FN** y permite cruzar promedios nacionales por escala sin amarrarlos a un instrumento específico.
     * **Justificación de 3FN en `RESULTADO_EVALUACION.periodo_reporte`:** Aunque `instrumento_evaluacion` posee `periodo_aplicacion` (ventana macro del instrumento), en `resultado_evaluacion` el atributo `periodo_reporte` registra el corte o subperiodo individual en que se calificó al estudiante (por ejemplo, corte académico o convocatoria individual), y `nivel_desempeno` corresponde al rótulo oficial emitido por la fuente para esa combinación `(id_estudiante_hash, id_instrumento, id_area)` sin depender transitivamente de otro atributo no clave.
     * **Justificación de 3FN en `SEGUIMIENTO_ACTIVIDAD_PLAN`:** Cada tupla modela un corte cronológico atómico de verificación identificado por la clave candidata compuesta `(id_plan, nombre_actividad, fecha_seguimiento)` (y la clave subrogada `id_seguimiento`). Los atributos `porcentaje_avance_corte`, `observaciones` y `estado_actividad` dependen de la totalidad de `(id_plan, nombre_actividad, fecha_seguimiento)`, separando los cortes históricos de los datos maestros de `PLAN_MEJORAMIENTO` (que a su vez tiene clave candidata `(codigo_dane, id_area, anio_implementacion)`).
   * *Anomalías prevenidas:* Evita inconsistencias en rangos de escalas repetidos o cambios de nombres institucionales y evita sobrescribir el historial de seguimiento de un plan.

*Sin desnormalizaciones propuestas en Fase 2.*

---

## 2. Matriz de Dependencias Funcionales ($X \rightarrow Y$)

| Tabla Lógica | Determinante ($X$) | Atributos Dependientes ($Y$) | Verificación 3FN |
| :--- | :--- | :--- | :--- |
| `INSTITUCION_EDUCATIVA` | `codigo_dane` | `nombre_ie`, `comuna_localidad`, `sector`, `calendario`, `jornada_predominante`, `estado_activa` | Cumple 3FN |
| `COHORTE` | `id_cohorte` / `(codigo_dane, anio_lectivo, jornada)` | `codigo_dane`, `anio_lectivo`, `jornada`, `total_matriculados` | Cumple 3FN |
| `ESTUDIANTE_SEUDONIMO` | `id_estudiante_hash` | `id_cohorte` | Cumple 3FN |
| `ESCALA_EVALUACION` | `id_escala` / `nombre_escala` | `valor_minimo`, `valor_maximo`, `permite_decimales`, `unidad_medida` | Cumple 3FN |
| `TRANSFORMACION_ESCALA` | `id_transformacion` | `id_escala_origen`, `id_escala_destino`, `factor_multiplicador`, `constante_desplazamiento`, `metodo_justificacion`, `vigente` | Cumple 3FN |
| `INSTRUMENTO_EVALUACION` | `id_instrumento` | `id_escala`, `tipo_instrumento`, `nombre_instrumento`, `fuente_emision`, `periodo_aplicacion` | Cumple 3FN |
| `AREA_EVALUACION` | `id_area` / `codigo_area` | `nombre_area`, `es_nucleo_comun` | Cumple 3FN |
| `RESULTADO_EVALUACION` | `(id_estudiante_hash, id_instrumento, id_area)` | `puntaje_obtenido`, `percentil_alcanzado`, `nivel_desempeno`, `periodo_reporte`, `fecha_presentacion`, `fecha_registro` | Cumple 2FN y 3FN (`nivel_desempeno` asumido como dato oficial de fuente) |
| `RESULTADO_AGREGADO_IE` | `id_agregado` / `(id_cohorte, id_instrumento, id_area, periodo_reporte)` | `puntaje_promedio`, `desviacion_estandar`, `cantidad_evaluados`, `fuente_reporte`, `fecha_registro` | Cumple 3FN |
| `PROMEDIO_NACIONAL_REF` | `id_referente` / `(anio_vigencia, id_area, id_escala, fuente_oficial)` | `puntaje_promedio`, `desviacion_estandar` | Cumple 3FN (corregida dep. transitiva previa) |
| `PLAN_MEJORAMIENTO` | `id_plan` / `(codigo_dane, id_area, anio_implementacion)` | `titulo_plan`, `diagnostico_base`, `meta_cuantitativa`, `estado_plan` | Cumple 3FN |
| `SEGUIMIENTO_ACTIVIDAD_PLAN` | `id_seguimiento` / `(id_plan, nombre_actividad, fecha_seguimiento)` | `porcentaje_avance_corte`, `observaciones`, `estado_actividad` | Cumple 3FN |
| `APOYO_INSTITUCIONAL` | `id_apoyo` | `id_cohorte`, `tipo_apoyo`, `entidad_financiadora`, `monto_invertido`, `beneficiarios_cubiertos`, `fecha_desembolso` | Cumple 3FN |
| `PARAMETRO_SISTEMA` | `clave_parametro` | `valor_parametro`, `descripcion`, `fecha_actualizacion` | Cumple 3FN |
