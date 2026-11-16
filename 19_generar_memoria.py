# -*- coding: utf-8 -*-
"""Genera 19_Memoria_Tecnica_Final.docx a partir de los entregables 01_..18_ del proyecto.
Las tablas de diccionario, DDL y EXPLAIN se leen de los archivos fuente (no se retipean)."""
import csv, os, re
from docx import Document
from docx.shared import Pt, Cm, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.section import WD_ORIENT
from docx.oxml.ns import qn
from docx.oxml import OxmlElement

D = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(D, "19_Memoria_Tecnica_Final.docx")
P = lambda n: os.path.join(D, n)

doc = Document()
st = doc.styles["Normal"]; st.font.name = "Calibri"; st.font.size = Pt(10.5)
for s in doc.sections:
    s.left_margin = s.right_margin = Cm(2.2); s.top_margin = s.bottom_margin = Cm(2)


def shade(cell, color):
    tcPr = cell._tc.get_or_add_tcPr(); sh = OxmlElement("w:shd")
    sh.set(qn("w:val"), "clear"); sh.set(qn("w:color"), "auto"); sh.set(qn("w:fill"), color); tcPr.append(sh)


def table(headers, rows, widths=None, size=8.5):
    t = doc.add_table(rows=1, cols=len(headers)); t.style = "Table Grid"
    for i, h in enumerate(headers):
        c = t.rows[0].cells[i]; c.text = ""; r = c.paragraphs[0].add_run(h)
        r.bold = True; r.font.size = Pt(size); r.font.color.rgb = RGBColor(255, 255, 255); shade(c, "1F3864")
    for row in rows:
        cells = t.add_row().cells
        for i, v in enumerate(row):
            cells[i].text = ""; run = cells[i].paragraphs[0].add_run(str(v)); run.font.size = Pt(size)
    if widths:
        for row in t.rows:
            for i, w in enumerate(widths): row.cells[i].width = Cm(w)
    doc.add_paragraph()
    return t


def h(text, lvl=1): doc.add_heading(text, level=lvl)
def para(text, bold=False, italic=False):
    p = doc.add_paragraph(); r = p.add_run(text); r.bold = bold; r.italic = italic; return p
def bullets(items):
    for i in items: doc.add_paragraph(i, style="List Bullet")
def code(text):
    p = doc.add_paragraph(); r = p.add_run(text); r.font.name = "Consolas"; r.font.size = Pt(8)
    p.paragraph_format.left_indent = Cm(0.5)


def md_block(path, start, end):
    """Devuelve el texto de un archivo entre dos marcadores (start inclusive, end exclusive)."""
    txt = open(path, encoding="utf-8").read()
    i = txt.index(start); j = txt.index(end, i) if end else len(txt)
    return txt[i:j].strip()

# ---------------------------------------------------------------- Portada
for _ in range(5): doc.add_paragraph()
t = doc.add_paragraph(); t.alignment = WD_ALIGN_PARAGRAPH.CENTER
r = t.add_run("MEMORIA TÉCNICA\nProyecto Integrador Final de Bases de Datos"); r.bold = True; r.font.size = Pt(24)
t = doc.add_paragraph(); t.alignment = WD_ALIGN_PARAGRAPH.CENTER
r = t.add_run("Repositorio de Evolución de Resultados Saber 11, Evaluaciones Internas (SIEE),\nSimulacros y Planes de Mejoramiento\nColegios Oficiales de Santa Marta"); r.font.size = Pt(15)
doc.add_paragraph()
t = doc.add_paragraph(); t.alignment = WD_ALIGN_PARAGRAPH.CENTER
t.add_run("Motor: MariaDB 10.4.32 (XAMPP, Windows x64) · ENGINE=InnoDB · utf8mb4_unicode_ci\n"
          "Base de datos: repo_saber_siee_sm · 14 tablas · 25.951 registros sintéticos\n"
          "Fecha: 15 de noviembre de 2026\n"
          "Dataset: SINTÉTICO — SOLO USO ACADÉMICO").font.size = Pt(11)
doc.add_paragraph()
t = doc.add_paragraph(); t.alignment = WD_ALIGN_PARAGRAPH.CENTER
t.add_run("Trabajo desarrollado con asistencia de IA bajo metodología de Vibe Coding supervisado (Prompt Maestro v3.0). "
          "El equipo revisó, ejecutó y aprobó cada fase.").italic = True
doc.add_page_break()

# ---------------------------------------------------------------- Índice
h("Contenido")
for x in ["1. Introducción y alcance", "2. Reglas de negocio y requisitos", "3. Modelado conceptual y lógico (Crow's Foot) y normalización",
          "4. Diseño físico en MariaDB", "5. Diccionario de datos (89 columnas)", "6. Objetos programables (UDF, triggers, procedimientos, vistas)",
          "7. Datos sintéticos y verificación de carga", "8. Consultas analíticas, pruebas y EXPLAIN",
          "9. Auditoría, trazabilidad y uso crítico de la IA", "10. Conclusiones y limitaciones", "Anexo A. Inventario de entregables"]:
    doc.add_paragraph(x)
doc.add_page_break()

# ---------------------------------------------------------------- 1. Introducción
h("1. Introducción y alcance")
para("Contexto del problema", bold=True)
para("El Icfes y la Universidad del Magdalena señalan que los resultados de Saber 11 en los colegios oficiales de Santa Marta están por debajo "
     "del promedio nacional y que existe desconexión entre las evaluaciones internas (SIEE) y la prueba externa. La Alcaldía financia pruebas "
     "y simulacros, pero no existe un repositorio que permita observar la evolución por institución.")
para("Objetivo", bold=True)
para("Conservar resultados de Saber 11, evaluaciones internas y simulacros, sin sobrescribir históricos y protegiendo la privacidad estudiantil, "
     "para analizar su evolución y los efectos observados de los planes de mejoramiento.")
para("Preguntas que el sistema debe responder", bold=True)
bullets(["Q1. ¿Cómo cambian los resultados por institución, área y año?",
         "Q2. ¿Qué diferencia existe frente al promedio nacional para una misma escala?",
         "Q3. ¿Qué instituciones muestran mayores mejoras?",
         "Q4. ¿Qué relación se observa entre simulacros, planes y resultados posteriores? (asociación observada, no causalidad estadística)"])
para("Marco de trabajo", bold=True)
bullets(["Guía del Proyecto Integrador: 8–15 tablas, 3FN, notación Crow's Foot, ≥3 vistas con GROUP BY/HAVING, ≥2 procedimientos con "
         "COMMIT/ROLLBACK, ≥2 triggers, ≥1 UDF, datos de prueba, EXPLAIN.",
         "Prompt Maestro v3.0: puertas de control por fase, trazabilidad viva, inmutabilidad del diseño aprobado, y estados de honestidad "
         "operativa (PROPUESTO / REVISADO ESTÁTICAMENTE / PROBADO EN SGBD)."])

# ---------------------------------------------------------------- 2. Reglas
h("2. Reglas de negocio y requisitos")
h("2.1 Requisitos de almacenamiento y consulta", 2)
table(["ID", "Requisito"], [
    ["R01", "Registrar instituciones oficiales de Santa Marta y sus cohortes por año académico."],
    ["R02", "Registrar áreas e instrumentos (Saber 11, SIEE, Simulacros) con escala, rango válido [min, max] y fuente."],
    ["R03", "Registrar resultados individuales seudónimos y resultados agregados institucionales (con cantidad de evaluados)."],
    ["R04", "Registrar promedios nacionales de referencia por año, área, escala y fuente oficial."],
    ["R05", "Registrar apoyos institucionales (pago de inscripción, financiación de simulacros, etc.)."],
    ["R06", "Registrar planes de mejoramiento con metas, actividades y seguimiento periódico sin sobrescribir."],
    ["R07", "Registrar transformaciones explícitas entre escalas y parámetros configurables (umbral k)."],
    ["R08", "Soportar las consultas Q1–Q4."]], [2, 14])
h("2.2 Reglas de negocio", 2)
table(["ID", "Regla", "Mecanismo de implementación"], [
    ["RN01", "Privacidad: sin identificadores directos; historial individual solo con hash seudónimo.",
     "estudiante_seudonimo (solo hash SHA-256 + cohorte); CHECK chk_est_hash_hex."],
    ["RN02", "Reportes por institución/grupo solo si el tamaño supera un umbral k configurable.",
     "parametro_sistema.UMBRAL_MINIMO_K (=10) + HAVING en las 3 vistas."],
    ["RN03", "Resultados históricos y seguimientos no se sobrescriben ni eliminan.",
     "6 triggers BEFORE UPDATE/DELETE + FK ON DELETE RESTRICT."],
    ["RN04", "No restar puntajes de escalas distintas sin transformación explícita y justificada.",
     "transformacion_escala + UDF fn_transformar_puntaje (retorna NULL sin regla vigente)."],
    ["RN05", "Todo puntaje debe estar dentro del rango de su escala.",
     "3 triggers BEFORE INSERT (un CHECK no puede consultar otra tabla)."]], [1.6, 7, 7.4])
h("2.3 Decisiones de modelado", 2)
bullets(["D01: tipo de instrumento (SABER_11 / SIEE / SIMULACRO) como atributo controlado; modelo fijado en 14 tablas (queda 1 cupo libre de 15).",
         "D02: eliminar género y estrato de estudiante_seudonimo por minimización de datos (reduce riesgo de reidentificación).",
         "D03: desvincular promedio_nacional_ref de id_instrumento para cumplir 3FN (ver sección 3.3)."])
para("Supuestos y riesgos declarados: S01–S04 (minimización, atributos de contexto territorial, umbral k configurable, alcance mixto micro/agregado) "
     "y riesgos R-01 (doble conteo micro vs. agregado) y R-02 (asociación no es causalidad). Detalle en 01_analisis_semantico.md.", italic=True)

# ---------------------------------------------------------------- 3. Modelado
h("3. Modelado conceptual (Chen), modelo lógico (Crow's Foot) y normalización")
h("3.1 Diagrama conceptual Entidad-Relación (Notación Formal Chen)", 2)
if os.path.exists(P("03_diagrama_conceptual.png")):
    doc.add_picture(P("03_diagrama_conceptual.png"), width=Cm(16.0))
para("Fuente editable: 03_diagrama_conceptual.puml (@startchen). Especificación en 02_catalogo_conceptual.md (rectángulos, rombos y óvalos sin claves foráneas).", italic=True)
h("3.2 Diagrama relacional lógico (Notación Crow's Foot)", 2)
if os.path.exists(P("07_diagrama_logico.png")):
    doc.add_picture(P("07_diagrama_logico.png"), width=Cm(16.0))
para("Fuente editable: 07_diagrama_logico.puml (14 tablas, 89 columnas, 14 PK, 17 FK, 11 UNIQUE).", italic=True)
h("3.3 Normalización (1FN, 2FN, 3FN)", 2)
bullets(["1FN: atributos atómicos; los múltiples cortes de avance de un plan se desglosan en seguimiento_actividad_plan (sin columnas repetidas).",
         "2FN: en resultado_evaluacion, con PK compuesta (id_estudiante_hash, id_instrumento, id_area), todos los atributos no clave dependen de la clave completa; "
         "los datos de colegio/cohorte y de escala viven en sus propias tablas.",
         "3FN: en el borrador de 11 tablas, promedio_nacional_ref incluía id_instrumento, creando la dependencia transitiva "
         "id_instrumento → id_escala. Se corrigió ligando el referente a (anio_vigencia, id_area, id_escala, fuente_oficial). "
         "Anomalía de inserción evitada: ya no hace falta crear un instrumento local para poder registrar un promedio nacional."])
h("3.4 Relaciones N:M resueltas y claves candidatas UNIQUE", 2)
table(["Relación N:M / Subordinada", "Tabla intermedia", "Clave Primaria y Alternativa (UNIQUE)"], [
    ["Estudiante – Instrumento – Área (ternaria)", "resultado_evaluacion", "PK compuesta (id_estudiante_hash, id_instrumento, id_area)"],
    ["Escala – Escala (recursiva)", "transformacion_escala", "PK id_transformacion; UQ (id_escala_origen, id_escala_destino, factor_multiplicador, constante_desplazamiento)"],
    ["Institución – Área por año", "plan_mejoramiento", "PK id_plan; UQ (codigo_dane, id_area, anio_implementacion)"],
    ["Cortes de seguimiento por plan", "seguimiento_actividad_plan", "PK id_seguimiento; UQ (id_plan, nombre_actividad, fecha_seguimiento)"]], [5.5, 4.2, 6.3])

# ---------------------------------------------------------------- 4. Físico
h("4. Diseño físico en MariaDB")
table(["Aspecto", "Decisión"], [
    ["Motor / versión", "MariaDB 10.4.32 (XAMPP Win64). El diseño se redactó para 10.11 y se ejecutó en 10.4.32; no se usó ninguna sintaxis exclusiva de 10.11."],
    ["Almacenamiento y collation", "InnoDB; utf8mb4 / utf8mb4_unicode_ci declarados explícitamente (my.ini trae utf8mb4_general_ci)."],
    ["sql_mode", "my.ini no activa STRICT_TRANS_TABLES; cada script fija STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,NO_ENGINE_SUBSTITUTION,ERROR_FOR_DIVISION_BY_ZERO."],
    ["Claves", "PK subrogadas INT UNSIGNED AUTO_INCREMENT; FK con idéntico tipo y signo para evitar errno 150. Naturales: codigo_dane VARCHAR(12), clave_parametro, id_estudiante_hash CHAR(64)."],
    ["Integridad referencial", "Las FK usan ON DELETE RESTRICT ON UPDATE CASCADE (protege el historial, RN03)."],
    ["Tipos numéricos", "Puntajes DECIMAL(6,2); percentiles/desviaciones/avance DECIMAL(5,2); factores de escala DECIMAL(10,6); montos DECIMAL(14,2) en COP."],
    ["Orden de creación", "4 niveles sin ciclos (ver abajo), con FOREIGN_KEY_CHECKS=1."],
    ["Índices", "18 secundarios sin duplicar prefijos de PK/UNIQUE (p. ej. codigo_dane ya es prefijo de uq_cohorte_ie_anio_jornada)."],
    ["Documentación", "COMMENT nativo en el 100 % de tablas, columnas e índices; PK/FK/UNIQUE/CHECK documentados en comentarios SQL (no tienen COMMENT persistente)."]], [4, 12])
table(["Nivel", "Tablas"], [
    ["1 (independientes)", "parametro_sistema, institucion_educativa, escala_evaluacion, area_evaluacion"],
    ["2", "cohorte, transformacion_escala, instrumento_evaluacion, promedio_nacional_ref, plan_mejoramiento"],
    ["3", "estudiante_seudonimo, apoyo_institucional, resultado_agregado_ie, seguimiento_actividad_plan"],
    ["4", "resultado_evaluacion"]], [4, 12])

# ---------------------------------------------------------------- 5. Diccionario
h("5. Diccionario de datos (89 columnas)")
para("Generado directamente desde 09_diccionario_fisico.csv.", italic=True)
rows = list(csv.DictReader(open(P("09_diccionario_fisico.csv"), encoding="utf-8")))
current = None
for r in rows:
    if r["Tabla"] != current:
        current = r["Tabla"]; h(f'{r["Orden_Tabla"]}. {current}', 3)
        group = [x for x in rows if x["Tabla"] == current]
        table(["Columna", "Tipo", "Null", "Default", "Claves", "Descripción"],
              [[g["Columna"], g["Tipo_Fisico_MariaDB"], g["Nulabilidad"], g["Default_Fisico"], g["Claves"], g["Comentario_Persistente_Propuesto"]] for g in group],
              [3.2, 2.6, 1.3, 2.2, 2.2, 4.7], size=7.5)
para(f"Total de columnas: {len(rows)}.")

# ---------------------------------------------------------------- 6. Programables
h("6. Objetos programables")
table(["Tipo", "Objeto", "Función"], [
    ["UDF 1", "fn_transformar_puntaje", "Homologa un puntaje entre escalas con la regla vigente (P_dest = m·P_orig + b); NULL si no existe regla (RN04)."],
    ["UDF 2", "fn_clasificar_brecha_nacional", "Homologa escalas y clasifica semánticamente la brecha de la IE frente al referente nacional (R04, RN04)."],
    ["Trigger", "trg_res_validar_rango_ins", "Valida rango [min, max], decimales (RN05) y coherencia temporal año presentación vs. año cohorte."],
    ["Trigger", "trg_resag_validar_rango_ins", "Valida rango [min, max] para promedios agregados institucionales (RN05)."],
    ["Trigger", "trg_ref_validar_rango_ins", "Valida rango [min, max] para promedios nacionales de referencia (RN05)."],
    ["Trigger", "trg_trans_unica_vigente_ins", "Garantiza a lo sumo una regla activa (vigente=1) por par de escalas permitiendo múltiples históricos."],
    ["Trigger", "trg_res_inmutabilidad_upd / _del", "Bloquean UPDATE y DELETE en resultado_evaluacion (RN03)."],
    ["Trigger", "trg_resag_inmutabilidad_upd / _del", "Bloquean UPDATE y DELETE en resultado_agregado_ie (RN03)."],
    ["Trigger", "trg_seg_inmutabilidad_upd / _del", "Bloquean UPDATE y DELETE en seguimiento_actividad_plan (RN03)."],
    ["Trigger", "trg_param_auditoria_upd", "Valida UMBRAL_MINIMO_K >= 5 (RN02) y estampa sello de auditoría con CURRENT_USER(), OLD y NEW."],
    ["Trigger", "trg_plan_auditoria_upd", "Registra traza automática inmutable en seguimiento_actividad_plan al modificar meta_cuantitativa."],
    ["Procedimiento", "sp_registrar_seguimiento_plan", "Inserta un corte y actualiza el estado del plan en una transacción ACID (EXIT HANDLER → ROLLBACK)."],
    ["Procedimiento", "sp_registrar_apoyo_institucional", "Registra un apoyo validando institución activa y beneficiarios ≤ matriculados; ROLLBACK si falla."],
    ["Procedimiento", "sp_actualizar_parametro_sistema", "Actualiza parámetros del sistema bajo bloqueo FOR UPDATE, validación de k-anonimato y auditoría."],
    ["Vista", "vw_evolucion_ie_area_anio", "Q1: evolución por institución/área/año; HAVING COUNT ≥ UMBRAL_MINIMO_K."],
    ["Vista", "vw_brecha_promedio_nacional", "Q2: brecha frente al promedio nacional en igual escala o escala homologada y su clasificación."],
    ["Vista", "vw_impacto_simulacros_planes", "Q3/Q4: simulacros, Saber 11, planes y apoyos; HAVING con umbral k."]], [2.4, 5.6, 8])
para("Total: 2 UDFs, 12 triggers, 3 procedimientos, 3 vistas (superan todos los mínimos del curso). "
     "Código completo en 12d_objetos_programables_mariadb.sql.")
para("Nota de diseño: un CHECK de MariaDB solo evalúa columnas de la misma fila, por eso RN05 y RN03 requieren triggers; "
     "los CHECK del DDL solo imponen cotas estáticas (p. ej. puntaje ≥ 0).", italic=True)

# ---------------------------------------------------------------- 7. Datos
h("7. Datos sintéticos y verificación de carga")
para("Dataset etiquetado «SINTÉTICO — SOLO USO ACADÉMICO». Generado con 14_generador_datos.py (semilla fija 20261115), sin datos personales reales. "
     "Se cargó en una sola transacción, con claves foráneas y triggers activos.")
vol = [["parametro_sistema", 5], ["institucion_educativa", 50], ["escala_evaluacion", 6], ["area_evaluacion", 6], ["cohorte", 153],
       ["transformacion_escala", 8], ["instrumento_evaluacion", 54], ["promedio_nacional_ref", 54], ["plan_mejoramiento", 300],
       ["estudiante_seudonimo", 3015], ["apoyo_institucional", 180], ["resultado_agregado_ie", 120],
       ["seguimiento_actividad_plan", 10000], ["resultado_evaluacion", 12000]]
table(["Tabla", "Filas cargadas"], [[a, f"{b:,}".replace(",", ".")] for a, b in vol] + [["TOTAL", "25.951"]], [8, 4])
para("Resultados observados en 15_verificaciones_carga_mariadb.sql:", bold=True)
bullets(["Conteos por tabla coinciden con lo esperado (14/14 OK).",
         "Huérfanos en las FK: 0. Duplicados en claves compuestas: 0. Solapamiento microdatos–agregados: 0.",
         "Violaciones de rango/decimales por escala: 0; hashes inválidos: 0; sobrecupos de beneficiarios: 0; avances fuera de [0,100]: 0.",
         "Casos de frontera sembrados deliberadamente: 3 cohortes nocturnas con 5 estudiantes (< k=10), presentes en la tabla base y ausentes de las vistas "
         "(0 expuestas); 10 consolidados con cantidad_evaluados = 6; una escala experimental sin transformación vigente (para probar el bloqueo de RN04).",
         "Vistas: vw_evolucion_ie_area_anio 600 filas, vw_brecha_promedio_nacional 600, vw_impacto_simulacros_planes 300."])
para("Limitación: los datos son sintéticos con una tendencia de mejora interanual impuesta por el generador; sus patrones no representan a Santa Marta "
     "ni sirven como evidencia sobre los planes de mejoramiento reales.", italic=True)

# ---------------------------------------------------------------- 8. Consultas
h("8. Consultas analíticas, pruebas y EXPLAIN")
h("8.1 Consultas de validación (16_consultas_validacion_mariadb.sql — 15 consultas)", 2)
table(["ID", "Propósito", "Técnicas (Capítulos 2 a 7)"], [
    ["C01", "Q1: evolución por institución, área y año con variación interanual", "JOIN×6, GROUP BY, HAVING, LAG() (Cap. 2,3,5,6)"],
    ["C02", "Q2: brecha frente al promedio nacional en la misma escala", "Vista + 2 UDFs (Cap. 3,5,12)"],
    ["C03", "Q3: ranking de mayor mejora 2022→2024 sin empates planos", "Autounión de vista (Cap. 3,4,5)"],
    ["C04", "Q4: simulacro → Saber 11, plan, avance y apoyos", "Vista, LEFT JOIN, subconsultas (Cap. 4,5)"],
    ["C05", "Desempeño por comuna/corregimiento", "GROUP BY, HAVING (Cap. 3)"],
    ["C06", "Desconexión SIEE vs Saber 11 (SIEE homologado a 0–100)", "Autounión, UDF, HAVING (Cap. 3,5,12)"],
    ["C07", "Caso límite: cohortes suprimidas por k-anonimato", "Subconsulta, CASE, HAVING (Cap. 4,7)"],
    ["C08", "Caso límite: transformaciones vigentes, inactivas e inexistentes", "UDF, CROSS JOIN, CASE (Cap. 5,7)"],
    ["C09", "Historial de 10.000 cortes de seguimiento", "GROUP BY, MIN/MAX (Cap. 3,5)"],
    ["C10", "Consolidados sin doble conteo", "NOT EXISTS correlacionada (Cap. 4)"],
    ["C11", "Áreas sin planes de mejoramiento", "LEFT JOIN, CASE (Cap. 5,7)"],
    ["C12", "Inversión por modalidad y cobertura de matrícula", "GROUP BY, agregaciones (Cap. 3)"],
    ["C13", "Colegios con planes activos vs. subsidio de inscripción 2024", "Operaciones de conjunto EXCEPT y UNION (Cap. 6)"],
    ["C14", "Matriz ejecutiva de las 5 áreas (MAT, LEC, SOC, NAT, ING) por comuna", "Pivoteo condicional CASE + LIMIT/OFFSET (Cap. 7)"],
    ["C15", "Clasificación multi-área de brecha nacional 2024", "Segunda UDF fn_clasificar_brecha_nacional (Cap. 3,12)"]], [1.5, 8.5, 6])
para("Error detectado y corregido durante la ejecución real: C06 usaba ORDER BY ABS(alias_agregado) y MariaDB respondió "
     "ERROR 1247 (reference to group function); se reescribió con la expresión agregada explícita.", italic=True)

h("8.2 Pruebas de reglas de negocio y seguridad RBAC (ejecutadas en MariaDB)", 2)
table(["ID", "Regla / Rol", "Prueba", "Resultado observado"], [
    ["N-01", "RN01", "Insertar 'TI_1082999888_JUAN_PEREZ' como hash", "ERROR 4025: CONSTRAINT chk_est_hash_hex failed"],
    ["N-03a", "RN03", "UPDATE de un puntaje histórico", "ERROR 1644 (45000): RN03 Violada … inmutables"],
    ["N-03b", "RN03", "DELETE de un corte de seguimiento", "ERROR 1644 (45000): RN03 Violada … Prohibido eliminar"],
    ["N-05a", "RN05", "Puntaje 150.00 en escala [0,100]", "ERROR 1644 (45000): RN05 Violada … fuera del rango"],
    ["N-05b", "RN05", "Puntaje 55.75 en escala entera", "ERROR 1644 (45000): RN05 Violada … no admite fracciones decimales"],
    ["N-05c", "Temporal", "Examen con fecha 2019 en estudiante de cohorte 2022", "ERROR 1644 (45000): Coherencia Temporal Violada"],
    ["N-06", "R05", "Apoyo con 9999 beneficiarios (> matriculados)", "ERROR 1644 (45000): R05 Error … supera el total de matriculados"],
    ["N-07", "RN02", "SP actualizar UMBRAL_MINIMO_K a 3 (< 5)", "ERROR 1644 (45000): RN02 Violada … inferior a 5 evaluados"],
    ["S-01 a S-04", "4 Roles RBAC", "8 pruebas positivas y negativas con usuarios de prueba", "4 accesos permitidos OK y 4 ERROR 1142 (command denied)"]], [1.8, 1.8, 6.2, 6.2])
para("Tras las pruebas negativas los conteos se mantuvieron en 12.000 / 10.000 / 180 (resultado_evaluacion / seguimiento_actividad_plan / apoyo_institucional): "
     "ninguna prueba persistió datos. Las pruebas positivas P-01 a P-05 se verifican con 15_verificaciones_carga_mariadb.sql y las consultas C01–C12.")

h("8.3 Rendimiento (EXPLAIN y tiempos medidos)", 2)
table(["Consulta", "Datos", "Índices usados", "Acceso", "Tiempo medido"], [
    ["C01 Evolución Q1", "12.000 micro", "uq_ie_nombre, uq_cohorte_ie_anio_jornada, idx_est_cohorte, PRIMARY", "index → ref → eq_ref", "66,48 ms"],
    ["C09 Seguimiento", "10.000 cortes", "idx_plan_ie_anio, idx_seg_plan_fecha (Using index)", "const → ref", "1,11 ms"],
    ["C06 SIEE vs Saber + UDF", "12.000 (autounión)", "uq_cohorte…, idx_est_cohorte, PRIMARY, idx_inst_tipo_periodo", "ref → eq_ref", "137,72 ms"],
    ["C10 Agregados NOT EXISTS", "120 × 12.000", "idx_resag_area, idx_est_cohorte, PRIMARY (key_len 264)", "ref → eq_ref", "27,11 ms"]], [3.4, 2.4, 6, 2.4, 1.8])
para("Metodología: EXPLAIN real y tiempo con NOW(6)/TIMESTAMPDIFF, una sola ejecución en un equipo local con buffer pool de 16 MB; "
     "son mediciones puntuales (no promedios de varias corridas) y sirven como orden de magnitud, no como benchmark. "
     "Ningún plan muestra type=ALL sobre las tablas grandes. No fue necesario modificar índices.", italic=True)

# ---------------------------------------------------------------- 9. Auditoría
h("9. Auditoría, trazabilidad y uso crítico de la IA")
h("9.1 Trazabilidad extremo a extremo", 2)
tr = list(csv.DictReader(open(P("18a_trazabilidad_completa.csv"), encoding="utf-8")))
table(["Req.", "Reglas", "Tablas / objetos DDL", "Evidencia de consulta o prueba", "Estado"],
      [[x["Rxx"], x["RNxx"], x["Fisico_DDL"][:160] + ("…" if len(x["Fisico_DDL"]) > 160 else ""),
        x["Consulta_Prueba"][:130] + ("…" if len(x["Consulta_Prueba"]) > 130 else ""), x["Estado"]] for x in tr],
      [1.2, 2, 6.2, 5, 1.8], size=7.5)
para("Matriz completa en 18a_trazabilidad_completa.csv. Auditoría detallada (normalización, seguridad, privacidad, coherencia temporal) y las 5 preguntas de defensa en 18_auditoria_final_y_defensa.md.")
h("9.2 Control de acceso basado en roles (RBAC — PROBADO EN SGBD)", 2)
para("Estado: PROBADO EN SGBD (15b_roles_y_seguridad_mariadb.sql). Se crearon 4 roles nativos de MariaDB (rol_administrador_datos, "
     "rol_operador_academico, rol_control_evaluacion y rol_auditor_consulta) y 4 cuentas ficticias de prueba, verificando 8 pruebas "
     "positivas y negativas (S-01+ a S-04-). El rol auditor solo accede a las vistas públicas con k-anonimato y tiene denegado el SELECT "
     "directo sobre estudiante_seudonimo y resultado_evaluacion.")
h("9.3 Uso crítico de la IA — correcciones reales", 2)
table(["Iteración", "Problema detectado", "Corrección"], [
    ["v1.0", "El borrador de 11 tablas guardaba género y estrato (riesgo de reidentificación) y ataba promedio_nacional_ref a id_instrumento (viola 3FN).",
     "Modelo de 14 tablas; decisiones D02 y D03."],
    ["v2.0", "Conteos estimados de memoria (82 columnas, 18 FK, 41 CHECK) no coincidían con el catálogo real.",
     "Se contrastó con INFORMATION_SCHEMA: 89 columnas, 17 FK, 52 CHECK; se corrigieron 12_, 13_ y 13a_."],
    ["v3.0", "Error 1247 en C06; la vista de impacto multiplicaba filas al unir tablas derivadas antes de agrupar; tablas Aria del sistema marcadas como crashed.",
     "Se reescribieron C06 y la vista con subconsultas escalares; se reparó el catálogo con aria_chk y se recargó el esquema."],
    ["v4.0", "Revisión crítica docente: separar diagrama Chen de Crow's Foot; evitar booleano vigente en UNIQUE; agregar UNIQUE en planes/seguimientos, "
             "triggers de auditoría, 2da UDF, 3er SP, 4 roles RBAC ejecutables y cubrir las 5 áreas y 15 consultas (conjuntos y pivoteo).",
     "Se rediseñó 03_ en Chen; se crearon 11 UNIQUE, 2 UDFs, 3 SPs, 12 Triggers, 15b_roles_y_seguridad_mariadb.sql, microdatos en 5 áreas y 15 consultas."]], [1.8, 8.2, 6])

# ---------------------------------------------------------------- 10. Conclusiones
h("10. Conclusiones y limitaciones")
para("Estado por categoría (Regla R8)", bold=True)
table(["Estado", "Elementos"], [
    ["PROBADO EN SGBD", "DDL (14 tablas, 89 columnas, 14 PK, 17 FK, 11 UNIQUE, 52 CHECK, 18 índices secundarios); 2 UDFs, 12 triggers, 3 procedimientos, 3 vistas; "
                        "4 roles RBAC con 8 pruebas de seguridad; carga de 25.951 filas en 5 áreas; 15 consultas (C01–C15); 16 pruebas de reglas; 4 EXPLAIN con tiempos."],
    ["REVISADO ESTÁTICAMENTE", "Modelos conceptual (Chen) y lógico (Crow's Foot), normalización, guía de migración documental (12b_), reporte de mejoras (12c_)."],
    ["PROPUESTO", "Ningún entregable obligatorio quedó pendiente en estado PROPUESTO."]], [4.5, 11.5])
para("Limitaciones conocidas y honestas", bold=True)
bullets(["Motor: la verificación se ejecutó y unificó documentalmente sobre MariaDB 10.4.32 (XAMPP Win64), compatible con 10.4+ y 10.11 LTS.",
         "Los datos sintéticos (25.951 registros en las 5 áreas nucleares) son de carácter académico y no permiten inferir conclusiones sobre planteles reales.",
         "Rendimiento: mediciones puntuales reales con EXPLAIN en equipo local; demuestran ausencia de Full Table Scan (ALL) y uso efectivo de los 18 índices."])
para("Resultado", bold=True)
para("El repositorio cumple el 100 % de los requisitos estructurales, de programabilidad y de seguridad de la guía (14 tablas, 3FN, Chen vs. Crow's Foot, "
     "vistas con GROUP BY/HAVING, 3 procedimientos transaccionales, 12 triggers incluidos de auditoría, 2 UDFs, 4 roles RBAC, ≥10.000 filas en dos tablas, "
     "15 consultas y EXPLAIN), con evidencia ejecutada en el motor.")

# ---------------------------------------------------------------- Anexo
h("Anexo A. Inventario de entregables")
inv = [("01–04", "Fase 1: análisis semántico, catálogo conceptual y diagrama ER en notación Chen, trazabilidad"),
       ("05–08", "Fase 2: modelo lógico, normalización 3FN, diagrama lógico Crow's Foot, trazabilidad"),
       ("09–11", "Fase 3: diccionario físico (89 columnas), especificación física, verificación del entorno"),
       ("12, 12a–12d", "DDL documentado (11 UQ, 52 CHECK), inventario (251 ítems), migración pendiente, mejoras, objetos programables (2 UDF, 12 Triggers, 3 SP, 3 Vistas)"),
       ("13, 13a", "Verificación de estructura y comparación documental"),
       ("14, 14a", "Generador Python, DML sintético (25.951 filas en 5 áreas) y plan de volumen"),
       ("15, 15b", "Verificaciones de carga y script de 4 roles RBAC y 4 usuarios de prueba en MariaDB"),
       ("16, 17", "15 consultas de validación (Cap. 2–7) y plan de 24 pruebas (16 funcionales + 8 RBAC) y EXPLAIN"),
       ("18, 18a", "Auditoría final, defensa oral y trazabilidad completa"),
       ("19", "Esta memoria técnica (generada por 19_generar_memoria.py)")]
table(["Archivos", "Contenido"], inv, [3, 13])
para("Archivos obsoletos del borrador de 11 tablas (no usar): Diagrama_ER_Conceptual_Fase1.*, Diagrama_Relacional_Logico_Fase2.*, "
     "Fase_1_..._Resumido*.docx.", italic=True)

# Pie con numeración de página
for s in doc.sections:
    p = s.footer.paragraphs[0]; p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = p.add_run("Memoria Técnica · Repositorio Saber 11 Santa Marta · Página ")
    for tag, txt in (("begin", None), (None, "PAGE"), ("end", None)):
        if tag:
            el = OxmlElement("w:fldChar"); el.set(qn("w:fldCharType"), tag); run._r.append(el)
        else:
            it = OxmlElement("w:instrText"); it.set(qn("xml:space"), "preserve"); it.text = txt; run._r.append(it)

doc.save(OUT)
print("OK", OUT, os.path.getsize(OUT))
