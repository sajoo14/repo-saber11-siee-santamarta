# 02 · Catálogo Conceptual y Especificación Chen (Fase 1)

**Proyecto:** Repositorio Saber 11, SIEE y Planes de Mejoramiento (Santa Marta)  
**Estado:** PROPUESTO (Pendiente de aprobación de Fase 1)

---

## 1. Catálogo de Entidades Conceptuales (14 Entidades)

| # | Entidad | Clasificación | Identificador de Negocio | Atributos Clave | Justificación |
| :-: | :--- | :--- | :--- | :--- | :--- |
| 1 | `INSTITUCION_EDUCATIVA` | Maestra | `codigo_dane` | `nombre_ie`, `comuna_localidad`, `sector`, `calendario`, `jornada_predominante`, `estado_activa` | Unidad institucional principal requerida por el enunciado. |
| 2 | `COHORTE` | Transaccional / Temporal | `id_cohorte` / `(codigo_dane, anio_lectivo, jornada)` | `anio_lectivo`, `jornada`, `total_matriculados` | Agrupa la población escolar por año académico y jornada. |
| 3 | `ESTUDIANTE_SEUDONIMO` | Maestra Protegida | `id_estudiante_hash` | `id_cohorte` (vínculo de pertenencia) | Permite trazabilidad longitudinal de resultados sin exponer identidad (RN01). |
| 4 | `ESCALA_EVALUACION` | Catálogo | `id_escala` / `nombre_escala` | `valor_minimo`, `valor_maximo`, `permite_decimales`, `unidad_medida` | Define rango válido y métrica de cada evaluación (R02, RN05). |
| 5 | `TRANSFORMACION_ESCALA` | Regla / Catálogo | `id_transformacion` | `id_escala_origen`, `id_escala_destino`, `factor_multiplicador`, `constante_desplazamiento`, `metodo_justificacion`, `vigente` | Formaliza la conversión explícita y justificada entre escalas (RN04). |
| 6 | `INSTRUMENTO_EVALUACION` | Catálogo | `id_instrumento` | `id_escala`, `tipo_instrumento` (SABER_11, SIEE, SIMULACRO), `nombre_instrumento`, `fuente_emision`, `periodo_aplicacion` | Modela pruebas externas, internas y simulacros con su fuente y escala. |
| 7 | `AREA_EVALUACION` | Catálogo | `id_area` / `codigo_area` | `nombre_area`, `es_nucleo_comun` | Homologa las áreas evaluadas entre SIEE, simulacros y Saber 11. |
| 8 | `RESULTADO_EVALUACION` | Transaccional (Hecho) | `(id_estudiante_hash, id_instrumento, id_area)` | `puntaje_obtenido`, `percentil_alcanzado`, `nivel_desempeno`, `periodo_reporte`, `fecha_presentacion`, `fecha_registro` | Registra calificaciones individuales seudónimas sin sobrescritura (R03, RN03). |
| 9 | `RESULTADO_AGREGADO_IE` | Transaccional (Hecho) | `id_agregado` / `(id_cohorte, id_instrumento, id_area, periodo_reporte)` | `puntaje_promedio`, `desviacion_estandar`, `cantidad_evaluados`, `fuente_reporte`, `fecha_registro` | Conserva consolidados institucionales cuando no hay microdatos y permite validar el umbral $k$ (R03, RN02). |
| 10 | `PROMEDIO_NACIONAL_REF` | Referencia | `id_referente` / `(anio_vigencia, id_area, id_escala, fuente_oficial)` | `puntaje_promedio`, `desviacion_estandar`, `fuente_oficial` | Referentes nacionales por año, área, escala y fuente (R04). |
| 11 | `PLAN_MEJORAMIENTO` | Transaccional | `id_plan` | `codigo_dane`, `id_area`, `anio_implementacion`, `titulo_plan`, `diagnostico_base`, `meta_cuantitativa`, `estado_plan` | Modela el plan institucional y su meta por área y año (R06). |
| 12 | `SEGUIMIENTO_ACTIVIDAD_PLAN` | Transaccional (Débil) | `id_seguimiento` | `id_plan`, `nombre_actividad`, `fecha_seguimiento`, `porcentaje_avance_corte`, `observaciones`, `estado_actividad` | Registra múltiples actividades y cortes históricos de seguimiento sin sobrescribir avances (R06, RN03). |
| 13 | `APOYO_INSTITUCIONAL` | Transaccional | `id_apoyo` | `id_cohorte`, `tipo_apoyo`, `entidad_financiadora`, `monto_invertido`, `beneficiarios_cubiertos`, `fecha_desembolso` | Registra apoyos como pago de inscripciones y simulacros financiados (R05). |
| 14 | `PARAMETRO_SISTEMA` | Configuración | `clave_parametro` | `valor_parametro`, `descripcion`, `fecha_actualizacion` | Almacena el tamaño mínimo configurable ($k$) antes de publicar reportes (RN02). |

---

## 2. Especificación Textual Inequívoca en Notación Chen (Regla R7 y Fase 1.D)

*Nota metodológica:* El archivo visual [`03_diagrama_conceptual.puml`](file:///c:/Users/Sebastian/Downloads/Proyecto%20bases%20de%20datos/03_diagrama_conceptual.puml) utiliza representación gráfica en **Pata de Cuervo (Crow's Foot)** por exigencia de la guía del curso; esta sección provee la especificación textual formal de **Chen** (entidades fuertes/débiles, relaciones, roles, cardinalidades `(min, max)` y participación).

1. **ORGANIZA** (`INSTITUCION_EDUCATIVA` [1,1] — **1:N** — `COHORTE` [0,N]): Participación parcial de institución, total de cohorte.
2. **AGRUPA** (`COHORTE` [1,1] — **1:N** — `ESTUDIANTE_SEUDONIMO` [0,N]): Participación total del estudiante seudónimo en una cohorte.
3. **RECIBE_APOYO** (`COHORTE` [1,1] — **1:N** — `APOYO_INSTITUCIONAL` [0,N]): Participación total del apoyo hacia la cohorte beneficiaria.
4. **RIGE_ESCALA** (`ESCALA_EVALUACION` [1,1] — **1:N** — `INSTRUMENTO_EVALUACION` [0,N]): Todo instrumento tiene exactamente una escala obligatoria.
5. **CONVIERTE_DESDE / CONVIERTE_HACIA** (`ESCALA_EVALUACION` — **M:N recursiva** — `ESCALA_EVALUACION`, entidad asociativa `TRANSFORMACION_ESCALA`): Atributos de transformación (`factor_multiplicador`, `constante_desplazamiento`, `metodo_justificacion`).
6. **PRESENTA_EN_AREA** (`ESTUDIANTE_SEUDONIMO` — **M:N ternaria** entre `ESTUDIANTE_SEUDONIMO`, `INSTRUMENTO_EVALUACION` y `AREA_EVALUACION`, resuelta mediante entidad asociativa `RESULTADO_EVALUACION` [0,N]): Atributos propios de la relación: `puntaje_obtenido`, `percentil_alcanzado`, `nivel_desempeno`, `periodo_reporte`, `fecha_presentacion`, `fecha_registro`.
7. **CONSOLIDA_EN** (ternaria entre `COHORTE`, `INSTRUMENTO_EVALUACION` y `AREA_EVALUACION`, entidad asociativa `RESULTADO_AGREGADO_IE` [0,N]): Atributos: `periodo_reporte`, `puntaje_promedio`, `desviacion_estandar`, `cantidad_evaluados`, `fuente_reporte`.
8. **REFERENCIA_NACIONAL** (`AREA_EVALUACION` y `ESCALA_EVALUACION` — **M:N con periodo y fuente** mediante `PROMEDIO_NACIONAL_REF`): Atributos: `anio_vigencia`, `puntaje_promedio`, `desviacion_estandar`, `fuente_oficial`.
9. **INTERVIENE_AREA** (`INSTITUCION_EDUCATIVA` — **M:N con año** hacia `AREA_EVALUACION`, entidad asociativa `PLAN_MEJORAMIENTO` [0,N]): Atributos: `anio_implementacion`, `titulo_plan`, `diagnostico_base`, `meta_cuantitativa`, `estado_plan`.
10. **EJECUTA_SEGUIMIENTO** (`PLAN_MEJORAMIENTO` [1,1] — **1:N** — `SEGUIMIENTO_ACTIVIDAD_PLAN` [1,N], **entidad débil dependiente de identificación/existencia** del plan): Atributos: `nombre_actividad`, `fecha_seguimiento`, `porcentaje_avance_corte`, `observaciones`, `estado_actividad`.
