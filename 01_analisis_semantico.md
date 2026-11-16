# 01 · Análisis Semántico y Diagnóstico Consultivo (Fase 1)

**Proyecto:** Repositorio de Evolución Saber 11, Evaluaciones Internas (SIEE), Simulacros y Planes de Mejoramiento (Santa Marta)  
**Estado:** APROBADO (Fase 1 validada e implementada hasta Fase 6 · `PROBADO EN SGBD`)

---

## 1. Diagnóstico Consultivo del Enunciado

### A. Hechos Confirmados (extraídos literalmente del enunciado)
* **Situación problemática:** El Icfes y la Universidad del Magdalena señalan que los resultados de Saber 11 en colegios oficiales de Santa Marta están por debajo del promedio nacional y existe desconexión entre las evaluaciones internas (SIEE) y la prueba externa. La Alcaldía financia pruebas y simulacros, pero falta un repositorio para observar la evolución por institución.
* **Objetivo:** Conservar resultados de Saber 11, evaluaciones internas y simulacros para analizar su evolución y los efectos observados de planes de mejoramiento.
* **Actores:** Instituciones educativas, equipos académicos y responsables de seguimiento de resultados.
* **Datos y procesos requeridos:**
  1. Instituciones, cohortes, año académico, instrumentos de evaluación y áreas de prueba.
  2. Resultados por estudiante seudónimo o agregados institucionales (según alcance), indicando periodo, escala, rango válido y fuente de cada instrumento.
  3. Simulacros, planes de mejoramiento (con metas, actividades y seguimiento) y apoyos (como pago de inscripción).
  4. Promedios nacionales de referencia con año, área, escala y fuente.
* **Reglas y límites explícitos:**
  * No se publican resultados individuales; se usan identificadores seudónimos donde se requiera historial.
  * Los reportes por institución o grupo deben cumplir un tamaño mínimo configurable antes de publicarse.
  * Los resultados históricos se conservan sin sobrescribir.
  * No se restan puntajes de escalas diferentes sin una transformación explícita y justificada.
* **Consultas obligatorias:**
  1. ¿Cómo cambian los resultados por institución, área y año?
  2. ¿Qué diferencia existe frente al promedio nacional para una misma escala?
  3. ¿Qué instituciones muestran mayores mejoras?
  4. ¿Qué relación se observa entre simulacros, planes y resultados posteriores?

### B. Inferencias, Supuestos por Validar y Riesgos (Regla R2 y R9)
* **Supuesto S01 (Minimización en `ESTUDIANTE_SEUDONIMO`):** Se conservan únicamente `id_estudiante_hash` e `id_cohorte`, eliminando `genero_declarado` y `estrato_socioeconomico` del borrador previo para reducir el riesgo de reidentificación en grupos pequeños (R9). *Aprobado (Decisión D02).*
* **Supuesto S02 (Atributos institucionales de contexto):** Campos como `comuna_localidad`, `sector`, `calendario` y `jornada` en institución/cohorte no figuran literalmente en el enunciado, pero se conservan como atributos de caracterización territorial en Santa Marta.
* **Supuesto S03 (Umbral mínimo configurable):** El tamaño mínimo de grupo ($k$) se modela como parámetro configurable (valor inicial sugerido de ejemplo: `10`, no regla fija del enunciado).
* **Supuesto S04 (Alcance mixto de resultados):** Se separan los resultados individuales seudónimos (`RESULTADO_EVALUACION`) de los reportes consolidados cuando no existan microdatos (`RESULTADO_AGREGADO_IE`), evitando mezclar conteos individuales y agregados en una misma suma.
* **Riesgo R-01 (Doble conteo agregado vs. individual):** Al coexistir microdatos seudónimos y agregados institucionales, las consultas deben evitar sumar ambos niveles para un mismo instrumento, periodo y cohorte.
* **Riesgo R-02 (Causalidad vs. asociación):** La consulta 4 mide relación observada entre simulacros, planes y resultados posteriores; la BD soporta trazabilidad y correlación temporal, sin afirmar causalidad estadística automática.

### C. Redacción Mejorada Propuesta del Enunciado (Regla R3)
> *"Repositorio relacional para colegios oficiales de Santa Marta que consolida, sin sobrescribir históricos, resultados de Saber 11, evaluaciones SIEE y simulacros (a nivel de estudiante seudónimo o agregado institucional según disponibilidad, con periodo, escala, rango válido y fuente), junto con promedios nacionales de referencia (año, área, escala y fuente), apoyos recibidos y planes de mejoramiento (metas, actividades y seguimiento). El sistema restringe la publicación de reportes a grupos que superen un umbral mínimo configurable, impide comparar o restar puntajes de escalas distintas sin una transformación explícita registrada y permite analizar evolución por colegio/área/año, brecha nacional, mayores mejoras y relación entre simulacros, planes y resultados posteriores."*
*Qué cambia:* Aclara que la transformación entre escalas debe quedar registrada explícitamente y que los resultados individuales y agregados se manejan según alcance sin mezclarse en promedios.

---

## 2. Requisitos del Sistema (Rxx), Reglas de Negocio (RNxx) y Decisiones (Dxx)

### Requisitos de Almacenamiento y Consulta
* **R01:** Registrar instituciones educativas oficiales del Distrito de Santa Marta y sus cohortes por año académico. *(Criterio: cada cohorte pertenece a una única institución y año/jornada).*
* **R02:** Registrar áreas de prueba e instrumentos de evaluación (Saber 11, SIEE, Simulacros) indicando escala, rango válido `[min, max]` y fuente. *(Criterio: todo instrumento apunta a una escala con `valor_maximo > valor_minimo`).*
* **R03:** Registrar resultados individuales mediante identificador seudónimo (`id_estudiante_hash`) indicando periodo y fecha, y resultados agregados institucionales cuando no existan microdatos, registrando `cantidad_evaluados`. *(Criterio: cero nombres o documentos reales almacenados).*
* **R04:** Registrar promedios nacionales de referencia por año, área, escala y fuente oficial. *(Criterio: unicidad por año, área, escala y fuente).*
* **R05:** Registrar apoyos institucionales (como pago de inscripción o financiación de simulacros) asociados a cohorte e institución.
* **R06:** Registrar planes de mejoramiento institucional por colegio y área, desglosando metas, actividades y seguimiento periódico sin sobrescribir avances.
* **R07:** Registrar transformaciones explícitas y justificadas entre escalas de evaluación distintas y parámetros configurables del sistema (como el umbral $k$).
* **R08:** Soportar las 4 consultas analíticas del problema (evolución por institución/área/año, brecha frente al promedio nacional en igual escala, ranking de mejoras, y relación simulacros–planes–resultados posteriores).

### Reglas de Negocio
* **RN01 (Privacidad y seudonimización):** No se almacenan datos de identificación directa ni se publican resultados individuales; todo historial individual usa `id_estudiante_hash`.
* **RN02 (Umbral mínimo configurable de publicación):** Todo reporte agregado por institución o grupo solo se expone si `cantidad_evaluados >= umbral_k` configurado en `PARAMETRO_SISTEMA`.
* **RN03 (Inmutabilidad histórica):** Los resultados históricos (individuales y agregados) y los seguimientos de planes no se sobrescriben ni eliminan.
* **RN04 (Consistencia de escalas):** Prohibido restar o promediar directamente puntajes de escalas diferentes sin aplicar una regla registrada y justificada en `TRANSFORMACION_ESCALA`.
* **RN05 (Rango válido):** Todo puntaje obtenido o promedio registrado debe estar dentro del rango `[valor_minimo, valor_maximo]` de su escala.

### Decisiones de Modelado (Dxx)
* **D01:** Consolidar el tipo de instrumento (`SABER_11`, `SIEE`, `SIMULACRO`) como atributo controlado dentro de `INSTRUMENTO_EVALUACION`, manteniendo el modelo en **14 entidades/tablas** para cumplir el tope académico de 8 a 15 tablas y reservar margen para auditoría futura.
* **D02:** Eliminar `genero_declarado` y `estrato_socioeconomico` de `ESTUDIANTE_SEUDONIMO` por principio de minimización de datos (R9).
* **D03:** Desvincular `PROMEDIO_NACIONAL_REF` de `id_instrumento` y vincularlo a `(anio_vigencia, id_area, id_escala, fuente_oficial)` para cumplir 3FN y el enunciado.
