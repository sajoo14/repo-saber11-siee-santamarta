#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
=====================================================================================
PROYECTO:       Repositorio de Evolución Saber 11, Evaluaciones Internas (SIEE),
                Simulacros y Planes de Mejoramiento (Colegios Oficiales Santa Marta)
ARCHIVO:        14_generador_datos.py
PROPÓSITO:      Generador determinista y reproducible (semilla fija) del archivo DML
                independiente 14_carga_datos_sinteticos_mariadb.sql (Fase 4).
ETIQUETA ÉTICA: SINTÉTICO — SOLO USO ACADÉMICO (Regla R9: cero datos personales reales).
VOLUMEN GENERADO (14 Tablas en orden topológico Nivel 1 -> Nivel 4):
  - Nivel 1:
      1. parametro_sistema           :      5 filas
      2. institucion_educativa       :     50 filas (colegios ficticios en Santa Marta)
      3. escala_evaluacion           :      6 filas
      4. area_evaluacion             :      6 filas
  - Nivel 2:
      5. cohorte                     :    153 filas (150 normales + 3 grupos pequeños < k)
      6. transformacion_escala       :      8 filas
      7. instrumento_evaluacion      :     54 filas
      8. promedio_nacional_ref       :     54 filas
      9. plan_mejoramiento           :    300 filas
  - Nivel 3:
     10. estudiante_seudonimo        :  3.015 filas (hashes SHA-256 sintéticos)
     11. apoyo_institucional         :    180 filas
     12. resultado_agregado_ie       :    120 filas (consolidados sin microdatos)
     13. seguimiento_actividad_plan  : 10.000 filas (TABLA PRINCIPAL DE HISTORIAL #1)
  - Nivel 4:
     14. resultado_evaluacion        : 12.000 filas (TABLA PRINCIPAL DE HECHOS #2)
  TOTAL DE FILAS SINTÉTICAS          : 25.951 filas
=====================================================================================
"""

import hashlib
import os
import random
from datetime import date, timedelta

SEED = 20261115
random.seed(SEED)

OUTPUT_SQL = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "14_carga_datos_sinteticos_mariadb.sql",
)
BATCH_SIZE = 250  # Seguro para max_allowed_packet = 1M en my.ini de XAMPP


def sql_str(val):
    if val is None:
        return "NULL"
    escaped = str(val).replace("\\", "\\\\").replace("'", "''")
    return f"'{escaped}'"


def write_batches(f, table_name, columns, rows, comment_header):
    f.write(f"\n-- -------------------------------------------------------------------------------------\n")
    f.write(f"-- {comment_header}\n")
    f.write(f"-- Total de registros a insertar en {table_name}: {len(rows)}\n")
    f.write(f"-- -------------------------------------------------------------------------------------\n")
    col_list = ", ".join(columns)
    for i in range(0, len(rows), BATCH_SIZE):
        chunk = rows[i : i + BATCH_SIZE]
        f.write(f"INSERT INTO {table_name} ({col_list}) VALUES\n")
        value_lines = []
        for r in chunk:
            formatted = ", ".join(r)
            value_lines.append(f"  ({formatted})")
        f.write(",\n".join(value_lines))
        f.write(";\n")


def main():
    # =========================================================================
    # NIVEL 1
    # =========================================================================

    # 1. parametro_sistema (5 filas)
    parametros = [
        (
            sql_str("UMBRAL_MINIMO_K"),
            sql_str("10"),
            sql_str("Tamano minimo de estudiantes evaluados requerido para publicar reportes agregados por institucion o cohorte (RN02 k-anonimato)."),
            sql_str("2026-11-15 08:00:00"),
        ),
        (
            sql_str("ETIQUETA_DATASET"),
            sql_str("SINTETICO — SOLO USO ACADEMICO"),
            sql_str("Etiqueta obligatoria de trazabilidad etica y privacidad del conjunto de datos cargado (Regla R9)."),
            sql_str("2026-11-15 08:00:00"),
        ),
        (
            sql_str("ANIO_LECTIVO_VIGENTE"),
            sql_str("2024"),
            sql_str("Anio academico de corte principal para tableros de seguimiento distrital en Santa Marta."),
            sql_str("2026-11-15 08:00:00"),
        ),
        (
            sql_str("ESCALA_OFICIAL_COMPARACION"),
            sql_str("ICFES_AREA_0_100"),
            sql_str("Escala metrica estandar de referencia por area para calculo de brechas frente al promedio nacional (RN04)."),
            sql_str("2026-11-15 08:00:00"),
        ),
        (
            sql_str("ALGORITMO_SEUDONIMIZACION"),
            sql_str("SHA-256"),
            sql_str("Funcion criptografica de resumen de 64 caracteres hexadecimales aplicada a identificadores estudiantiles (RN01)."),
            sql_str("2026-11-15 08:00:00"),
        ),
    ]

    # 2. institucion_educativa (50 filas)
    comunas = [
        "COMUNA 1 - MARIA EUGENIA - PANDO",
        "COMUNA 2 - CENTRAL",
        "COMUNA 3 - PESCAITO - ALMENDROS",
        "COMUNA 4 - POLIDEPORTIVO - JARDIN",
        "COMUNA 5 - SANTANA - BASTIDAS",
        "COMUNA 6 - MAMATOCO - 11 DE NOVIEMBRE",
        "COMUNA 7 - GAIRA - RODADERO",
        "COMUNA 8 - POZOS COLORADOS - DON JACA",
        "COMUNA 9 - PARQUE - BURECHE",
        "CORREGIMIENTO BONDA",
        "CORREGIMIENTO TAGANGA",
        "CORREGIMIENTO MINCA",
        "CORREGIMIENTO GUACHACA",
    ]
    jornadas_ie = ["MANANA", "TARDE", "UNICA", "COMPLETA"]
    instituciones = []
    codigos_dane = []
    for idx in range(1, 51):
        dane = f"147001{idx:06d}"  # 12 dígitos exactos
        codigos_dane.append(dane)
        comuna = comunas[(idx - 1) % len(comunas)]
        jornada_pred = jornadas_ie[(idx - 1) % len(jornadas_ie)]
        nombre = f"IED SINTETICA SANTA MARTA NRO {idx:02d} - {comuna.split(' - ')[0]}"
        instituciones.append(
            (
                sql_str(dane),
                sql_str(nombre),
                sql_str(comuna),
                sql_str("OFICIAL"),
                sql_str("A"),
                sql_str(jornada_pred),
                "1",
            )
        )

    # 3. escala_evaluacion (6 filas)
    escalas = [
        ("1", sql_str("ICFES_AREA_0_100"), "0.00", "100.00", "0", sql_str("PUNTOS")),
        ("2", sql_str("ICFES_GLOBAL_0_500"), "0.00", "500.00", "0", sql_str("PUNTOS")),
        ("3", sql_str("SIEE_1_5"), "1.00", "5.00", "1", sql_str("NOTA")),
        ("4", sql_str("SIEE_0_10"), "0.00", "10.00", "1", sql_str("NOTA")),
        ("5", sql_str("SIMULACRO_0_100"), "0.00", "100.00", "0", sql_str("PUNTOS")),
        ("6", sql_str("PORCENTAJE_ EXPERIMENTAL_0_200".replace(" ", "")), "0.00", "200.00", "1", sql_str("PUNTOS")),
    ]

    # 4. area_evaluacion (6 filas)
    areas = [
        ("1", sql_str("MAT"), sql_str("MATEMATICAS"), "1"),
        ("2", sql_str("LEC"), sql_str("LECTURA CRITICA"), "1"),
        ("3", sql_str("SOC"), sql_str("SOCIALES Y CIUDADANAS"), "1"),
        ("4", sql_str("NAT"), sql_str("CIENCIAS NATURALES"), "1"),
        ("5", sql_str("ING"), sql_str("INGLES"), "1"),
        ("6", sql_str("GLOB"), sql_str("PUNTAJE GLOBAL"), "0"),
    ]

    # =========================================================================
    # NIVEL 2
    # =========================================================================

    # 5. cohorte (153 filas: 50 colegios x 3 años [2022, 2023, 2024] + 3 cohortes nocturnas pequeñas < k)
    cohortes = []
    cohorte_id = 1
    # Guardamos metadatos para generar hijos
    cohortes_normales_meta = []  # (id_cohorte, codigo_dane, anio, jornada, matriculados)
    for dane_idx, dane in enumerate(codigos_dane):
        jornada_base = jornadas_ie[dane_idx % len(jornadas_ie)]
        for anio in (2022, 2023, 2024):
            matriculados = 35 + ((dane_idx * 3 + anio) % 25)
            cohortes.append(
                (
                    str(cohorte_id),
                    sql_str(dane),
                    str(anio),
                    sql_str(jornada_base),
                    str(matriculados),
                )
            )
            cohortes_normales_meta.append((cohorte_id, dane, anio, jornada_base, matriculados))
            cohorte_id += 1

    # 3 cohortes pequeñas de jornada NOCTURNA con solo 5 matriculados/evaluados (< UMBRAL_MINIMO_K=10)
    cohortes_pequenas_meta = []
    for i in range(3):
        dane = codigos_dane[i]
        cohortes.append(
            (
                str(cohorte_id),
                sql_str(dane),
                "2024",
                sql_str("NOCTURNA"),
                "5",
            )
        )
        cohortes_pequenas_meta.append((cohorte_id, dane, 2024, "NOCTURNA", 5))
        cohorte_id += 1

    # 6. transformacion_escala (8 filas)
    # Nota: La escala 6 (PORCENTAJE_EXPERIMENTAL_0_200) se deja deliberadamente sin regla vigente
    # hacia ICFES_AREA_0_100 para probar el caso límite de bloqueo RN04 (fn_transformar_puntaje -> NULL).
    transformaciones = [
        (
            "1", "3", "1", "25.000000", "-25.0000",
            sql_str("Homologacion lineal SIEE [1.00, 5.00] a ICFES_AREA [0, 100]: P_dest = 25 * P_orig - 25 (Acuerdo Pedagogico Distrital 01/2022)."),
            "1",
        ),
        (
            "2", "1", "3", "0.040000", "1.0000",
            sql_str("Homologacion inversa ICFES_AREA [0, 100] a SIEE [1.00, 5.00]: P_dest = 0.04 * P_orig + 1 (Acuerdo Pedagogico Distrital 01/2022)."),
            "1",
        ),
        (
            "3", "4", "1", "10.000000", "0.0000",
            sql_str("Homologacion proporcional SIEE [0.00, 10.00] a ICFES_AREA [0, 100]: P_dest = 10 * P_orig (Guia Tecnica SED Santa Marta)."),
            "1",
        ),
        (
            "4", "1", "4", "0.100000", "0.0000",
            sql_str("Homologacion inversa ICFES_AREA [0, 100] a SIEE [0.00, 10.00]: P_dest = 0.10 * P_orig (Guia Tecnica SED Santa Marta)."),
            "1",
        ),
        (
            "5", "5", "1", "1.000000", "0.0000",
            sql_str("Equivalencia directa 1:1 entre SIMULACRO_0_100 e ICFES_AREA_0_100 bajo matriz de especificaciones Icfes."),
            "1",
        ),
        (
            "6", "1", "5", "1.000000", "0.0000",
            sql_str("Equivalencia inversa 1:1 entre ICFES_AREA_0_100 y SIMULACRO_0_100."),
            "1",
        ),
        (
            "7", "1", "2", "5.000000", "0.0000",
            sql_str("Proyeccion lineal de escala de area [0, 100] a escala global [0, 500]: P_dest = 5 * P_orig."),
            "1",
        ),
        (
            "8", "6", "1", "0.500000", "0.0000",
            sql_str("Regla experimental historica NO VIGENTE (vigente=0) para pruebas de bloqueo de transformacion RN04."),
            "0",
        ),
    ]

    # 7. instrumento_evaluacion (54 filas)
    # 1..9   : Instrumentos para microdatos (2022, 2023, 2024 x SIMULACRO, SIEE, SABER_11)
    # 10..54 : 45 instrumentos adicionales de cortes históricos/consolidados
    instrumentos = []
    inst_id = 1
    inst_microdatos_por_anio = {}  # anio -> {'SIMULACRO': id, 'SIEE': id, 'SABER_11': id}
    for anio in (2022, 2023, 2024):
        # Simulacro primer semestre (escala 5: SIMULACRO_0_100)
        id_sim = inst_id
        instrumentos.append((
            str(inst_id), "5", sql_str("SIMULACRO"),
            sql_str(f"SIMULACRO DISTRITAL DIAGNOSTICO {anio}-1"),
            sql_str("ALCALDIA DE SANTA MARTA - UNIMAGDALENA"),
            sql_str(f"{anio}-1"),
        ))
        inst_id += 1

        # SIEE corte interno (escala 3: SIEE_1_5)
        id_siee = inst_id
        instrumentos.append((
            str(inst_id), "3", sql_str("SIEE"),
            sql_str(f"EVALUACION INTERNA SIEE INTEGRAL {anio}-1"),
            sql_str("COMISIONES DE EVALUACION Y PROMOCION IED"),
            sql_str(f"{anio}-1"),
        ))
        inst_id += 1

        # Saber 11 oficial calendario A (escala 1: ICFES_AREA_0_100)
        id_saber = inst_id
        instrumentos.append((
            str(inst_id), "1", sql_str("SABER_11"),
            sql_str(f"EXAMEN DE ESTADO SABER 11 CALENDARIO A {anio}-2"),
            sql_str("ICFES"),
            sql_str(f"{anio}-2"),
        ))
        inst_id += 1

        inst_microdatos_por_anio[anio] = {
            "SIMULACRO": id_sim,
            "SIEE": id_siee,
            "SABER_11": id_saber,
        }

    # Instrumentos adicionales (IDs 10..54) para consolidados agregados y cobertura de catálogo >= 50
    inst_agregados_ids = []
    for k in range(1, 46):
        anio_k = 2018 + (k % 7)  # 2018..2024
        sem_k = 1 if (k % 2 == 1) else 2
        if k % 3 == 0:
            tipo_k = "SABER_11"
            esc_k = "1"
            fte_k = "ICFES - HISTORICO AGREGADO"
            nom_k = f"REPORTE HISTORICO AGREGADO SABER 11 LOTE {k:02d}"
        elif k % 3 == 1:
            tipo_k = "SIMULACRO"
            esc_k = "5"
            fte_k = "OPERADOR PEDAGOGICO DISTRITAL"
            nom_k = f"SIMULACRO CONTROL SEGUIMIENTO LOTE {k:02d}"
        else:
            tipo_k = "SIEE"
            esc_k = "4"
            fte_k = "SECRETARIA DE EDUCACION DISTRITAL"
            nom_k = f"CONSOLIDADO SIEE INSTITUCIONAL LOTE {k:02d}"

        instrumentos.append((
            str(inst_id), esc_k, sql_str(tipo_k),
            sql_str(nom_k), sql_str(fte_k), sql_str(f"{anio_k}-{sem_k}"),
        ))
        inst_agregados_ids.append((inst_id, int(esc_k), f"{anio_k}-{sem_k}"))
        inst_id += 1

    # 8. promedio_nacional_ref (54 filas: años 2016..2024 x 6 áreas)
    promedios_nac = []
    ref_id = 1
    base_nac_area = {
        1: 52.40,  # MAT
        2: 54.10,  # LEC
        3: 49.80,  # SOC
        4: 51.20,  # NAT
        5: 50.60,  # ING
        6: 258.00, # GLOB (escala 2)
    }
    for anio in range(2016, 2025):
        for id_area in range(1, 7):
            escala_ref = 2 if id_area == 6 else 1
            variacion = (anio - 2016) * 0.25
            prom = round(base_nac_area[id_area] + variacion, 2)
            desv = round(11.50 if id_area < 6 else 48.20, 2)
            promedios_nac.append((
                str(ref_id),
                str(anio),
                str(id_area),
                str(escala_ref),
                f"{prom:.2f}",
                f"{desv:.2f}",
                sql_str(f"BOLETIN OFICIAL ICFES SABER 11 NACIONAL {anio}"),
            ))
            ref_id += 1

    # 9. plan_mejoramiento (300 filas: 50 colegios x 2 áreas principales x 3 años 2022..2024)
    planes = []
    plan_id = 1
    estados_plan = ["CUMPLIDO", "EN_EJECUCION", "FORMULADO", "CERRADO"]
    for dane_idx, dane in enumerate(codigos_dane):
        for anio in (2022, 2023, 2024):
            for id_area in (1, 2):  # 1=MAT, 2=LEC
                area_nom = "MATEMATICAS" if id_area == 1 else "LECTURA CRITICA"
                meta = round(52.0 + (dane_idx % 12) * 0.8 + (anio - 2022) * 1.5, 2)
                if anio == 2022:
                    estado = "CUMPLIDO" if dane_idx % 3 != 0 else "CERRADO"
                elif anio == 2023:
                    estado = "CUMPLIDO" if dane_idx % 2 == 0 else "EN_EJECUCION"
                else:
                    estado = "EN_EJECUCION" if dane_idx % 4 != 0 else "FORMULADO"

                planes.append((
                    str(plan_id),
                    sql_str(dane),
                    str(id_area),
                    str(anio),
                    sql_str(f"PLAN DE MEJORAMIENTO {area_nom} {anio} - COLEGIO {dane[-2:]}"),
                    sql_str(f"Diagnostico base {anio}: brecha detectada en {area_nom} entre SIEE y prueba Saber 11; se prioriza alineacion curricular por competencias."),
                    f"{meta:.2f}",
                    sql_str(estado),
                ))
                plan_id += 1

    # =========================================================================
    # NIVEL 3
    # =========================================================================

    # 10. estudiante_seudonimo (3.015 filas: 20 estudiantes x 150 cohortes normales + 5 x 3 cohortes pequeñas)
    estudiantes = []
    estudiantes_normales_por_cohorte = {}  # id_cohorte -> list of hashes
    estudiantes_pequenos_por_cohorte = {}  # id_cohorte -> list of hashes
    est_counter = 1

    for (id_coh, dane, anio, jorn, _) in cohortes_normales_meta:
        hashes_coh = []
        for s in range(20):
            raw_seed = f"SINTETICO_SM_EST_{id_coh}_{anio}_{est_counter:06d}"
            h = hashlib.sha256(raw_seed.encode("utf-8")).hexdigest()
            estudiantes.append((sql_str(h), str(id_coh)))
            hashes_coh.append(h)
            est_counter += 1
        estudiantes_normales_por_cohorte[id_coh] = hashes_coh

    for (id_coh, dane, anio, jorn, _) in cohortes_pequenas_meta:
        hashes_coh = []
        for s in range(5):
            raw_seed = f"SINTETICO_SM_PEQ_{id_coh}_{anio}_{est_counter:06d}"
            h = hashlib.sha256(raw_seed.encode("utf-8")).hexdigest()
            estudiantes.append((sql_str(h), str(id_coh)))
            hashes_coh.append(h)
            est_counter += 1
        estudiantes_pequenos_por_cohorte[id_coh] = hashes_coh

    # 11. apoyo_institucional (180 filas)
    tipos_apoyo = [
        "PAGO_INSCRIPCION",
        "FINANCIACION_SIMULACRO",
        "MATERIAL_PEDAGOGICO",
        "CAPACITACION_DOCENTE",
    ]
    apoyos = []
    for ap_id in range(1, 181):
        coh_tuple = cohortes_normales_meta[(ap_id - 1) % len(cohortes_normales_meta)]
        id_coh, dane, anio, _, matriculados = coh_tuple
        tipo = tipos_apoyo[(ap_id - 1) % len(tipos_apoyo)]
        monto = round(1500000.00 + (ap_id % 15) * 450000.00, 2)
        benef = min(matriculados, 20 + (ap_id % 15))
        fecha_des = f"{anio}-03-{(ap_id % 25) + 1:02d}"
        apoyos.append((
            str(ap_id),
            str(id_coh),
            sql_str(tipo),
            sql_str("ALCALDIA DISTRITAL DE SANTA MARTA"),
            f"{monto:.2f}",
            str(benef),
            sql_str(fecha_des),
        ))

    # 12. resultado_agregado_ie (120 filas: consolidados históricos usando instrumentos 10..54)
    # Incluye 110 grupos con cantidad_evaluados >= 10 y 10 grupos con cantidad_evaluados < 10
    resultados_agregados = []
    for ag_id in range(1, 121):
        id_coh, dane, anio, _, matriculados = cohortes_normales_meta[(ag_id - 1) % len(cohortes_normales_meta)]
        inst_ag_id, esc_id, per_rep = inst_agregados_ids[(ag_id - 1) % len(inst_agregados_ids)]
        id_area = ((ag_id - 1) % 5) + 1
        if esc_id == 4:  # SIEE_0_10
            prom = round(random.uniform(5.50, 8.90), 2)
            desv = round(random.uniform(0.60, 1.40), 2)
        else:            # 0..100
            prom = round(random.uniform(42.00, 68.00), 2)
            desv = round(random.uniform(6.50, 12.80), 2)

        cant_eval = 6 if ag_id > 110 else (22 + (ag_id % 18))
        resultados_agregados.append((
            str(ag_id),
            str(id_coh),
            str(inst_ag_id),
            str(id_area),
            sql_str(per_rep),
            f"{prom:.2f}",
            f"{desv:.2f}",
            str(cant_eval),
            sql_str("ACTA CONSOLIDADA SECRETARIA DE EDUCACION SANTA MARTA"),
            sql_str(f"{anio}-11-20 10:30:00"),
        ))

    # 13. seguimiento_actividad_plan (10.000 filas — TABLA PRINCIPAL DE HISTORIAL #1)
    # 300 planes x ~33-34 cortes periódicos de seguimiento de sus actividades
    seguimientos = []
    actividades_base = [
        "Taller de resolucion de items liberados Icfes por competencias",
        "Simulacro focalizado con retroalimentacion metacognitiva",
        "Alineacion de rubricas SIEE con estandares basicos de competencias",
        "Semillero de refuerzo sabatino para estudiantes con desempeno minimo",
        "Comunidad de aprendizaje docente para analisis psicometrico de resultados",
        "Tutoria intensiva de comprension lectora y razonamiento cuantitativo",
    ]
    seg_id = 1
    for p_idx in range(1, 301):
        anio_plan = 2022 + ((p_idx - 1) // 2) % 3
        fecha_inicio = date(anio_plan, 2, 1)
        # 33 cortes para los primeros 200 planes y 34 cortes para los últimos 100 planes = 6600 + 3400 = 10.000 exactos
        num_cortes = 33 if p_idx <= 200 else 34
        for c_idx in range(num_cortes):
            act_nom = f"{actividades_base[c_idx % len(actividades_base)]} - Modulo {(c_idx // 6) + 1}"
            fecha_corte = fecha_inicio + timedelta(days=(c_idx * 8) % 280)
            avance = round(min(100.00, ((c_idx + 1) / num_cortes) * 100.0), 2)
            if avance >= 100.00:
                est_act = "COMPLETADA"
            elif avance >= 15.00:
                est_act = "EN_PROGRESO"
            else:
                est_act = "PENDIENTE"

            seguimientos.append((
                str(seg_id),
                str(p_idx),
                sql_str(act_nom),
                sql_str(fecha_corte.isoformat()),
                f"{avance:.2f}",
                sql_str(f"Corte periodico #{c_idx + 1:02d} verificado por coordinacion academica sin sobrescribir historicos (RN03)."),
                sql_str(est_act),
            ))
            seg_id += 1

    assert len(seguimientos) == 10000, f"Error: seguimientos={len(seguimientos)}"

    # =========================================================================
    # NIVEL 4
    # =========================================================================

    # 14. resultado_evaluacion (12.000 filas — TABLA PRINCIPAL DE HECHOS #2)
    # Distribución:
    # - 11.985 filas en cohortes normales (>= 20 evaluados por cohorte, superando UMBRAL_MINIMO_K=10)
    # -     15 filas en las 3 cohortes nocturnas pequeñas (5 evaluados por cohorte < 10, para probar que
    #          las vistas analíticas las suprimen por RN02!)
    resultados_eval = []

    # A) 15 filas de cohortes pequeñas (3 cohortes x 5 estudiantes x 1 área MAT en SABER_11 2024)
    id_saber_2024 = inst_microdatos_por_anio[2024]["SABER_11"]
    for (id_coh, dane, anio, _, _) in cohortes_pequenas_meta:
        for h in estudiantes_pequenos_por_cohorte[id_coh]:
            puntaje_int = float(random.randint(44, 62))
            percentil = round(min(99.0, max(5.0, puntaje_int * 1.1)), 2)
            nivel = "SATISFACTORIO" if puntaje_int >= 51 else "MINIMO"
            resultados_eval.append((
                sql_str(h),
                str(id_saber_2024),
                "1",  # MAT
                f"{puntaje_int:.2f}",
                f"{percentil:.2f}",
                sql_str(nivel),
                sql_str("2024-2"),
                sql_str("2024-08-18"),
                sql_str("2024-09-15 14:00:00"),
            ))

    # B) 11.985 filas en cohortes normales:
    # Distribuimos los 11.985 microdatos cubriendo las 5 áreas nucleares del Icfes
    # (1=MAT, 2=LEC, 3=SOC, 4=NAT, 5=ING) y garantizando variaciones interanuales
    # diferenciadas por colegio (sin empates artificiales en el ranking Q3/C03).
    for (id_coh, dane, anio, _, _) in cohortes_normales_meta:
        dane_num = int(dane[-2:])
        # Ganancia base diferenciada según intensidad del plan y código del colegio
        ganancia_base = (anio - 2022) * (3 if dane_num <= 25 else 1)
        base_colegio = 42 + (dane_num % 14) + ganancia_base

        id_sim = inst_microdatos_por_anio[anio]["SIMULACRO"]
        id_siee = inst_microdatos_por_anio[anio]["SIEE"]
        id_saber = inst_microdatos_por_anio[anio]["SABER_11"]

        # Asignamos la segunda área evaluada en Saber 11 de forma cíclica coprima con las 13 zonas
        # (mcd(4, 13) = 1) para cubrir uniformemente LEC (2), SOC (3), NAT (4) e ING (5) en todo el Distrito
        segunda_area = ((dane_num - 1) % 4) + 2

        for h_idx, h in enumerate(estudiantes_normales_por_cohorte[id_coh]):
            # Bono diferencial por estudiante y año para que cada colegio tenga un promedio único sin empates planos
            bono_est = (anio - 2022) * (2 if h_idx < ((dane_num * 3) % 19) + 1 else 0)

            # 1) SABER_11 en Matemáticas (id_area = 1, escala 1 entera 0..100)
            if len(resultados_eval) < 12000:
                pts = float(max(20, min(98, base_colegio + bono_est + ((h_idx % 9) - 4))))
                perc = round(min(99.5, max(1.0, pts * 1.05)), 2)
                niv = "AVANZADO" if pts >= 70 else ("SATISFACTORIO" if pts >= 50 else ("MINIMO" if pts >= 36 else "INSUFICIENTE"))
                resultados_eval.append((
                    sql_str(h), str(id_saber), "1", f"{pts:.2f}", f"{perc:.2f}",
                    sql_str(niv), sql_str(f"{anio}-2"), sql_str(f"{anio}-08-18"),
                    sql_str(f"{anio}-09-15 14:00:00"),
                ))

            # 2) SABER_11 en segunda área nuclear (2=LEC, 3=SOC, 4=NAT, 5=ING, escala 1 entera 0..100)
            if len(resultados_eval) < 12000:
                pts = float(max(22, min(99, base_colegio + bono_est + (segunda_area % 4) + ((h_idx % 7) - 3))))
                perc = round(min(99.5, max(1.0, pts * 1.04)), 2)
                niv = "AVANZADO" if pts >= 66 else ("SATISFACTORIO" if pts >= 51 else ("MINIMO" if pts >= 36 else "INSUFICIENTE"))
                resultados_eval.append((
                    sql_str(h), str(id_saber), str(segunda_area), f"{pts:.2f}", f"{perc:.2f}",
                    sql_str(niv), sql_str(f"{anio}-2"), sql_str(f"{anio}-08-18"),
                    sql_str(f"{anio}-09-15 14:00:00"),
                ))

            # 3) SIMULACRO en Matemáticas (id_area = 1, escala 5 entera 0..100)
            if len(resultados_eval) < 12000:
                pts_sim = float(max(18, min(95, base_colegio - 3 + ((h_idx % 9) - 4))))
                perc_sim = round(min(99.0, max(1.0, pts_sim * 1.02)), 2)
                niv_sim = "SATISFACTORIO" if pts_sim >= 50 else "MINIMO"
                resultados_eval.append((
                    sql_str(h), str(id_sim), "1", f"{pts_sim:.2f}", f"{perc_sim:.2f}",
                    sql_str(niv_sim), sql_str(f"{anio}-1"), sql_str(f"{anio}-04-14"),
                    sql_str(f"{anio}-05-02 10:00:00"),
                ))

            # 4) SIEE en Matemáticas (id_area = 1, escala 3 decimal 1.00..5.00)
            if len(resultados_eval) < 12000:
                nota_siee = round(max(1.50, min(4.95, 2.80 + (base_colegio - 40) * 0.05 + (h_idx % 5) * 0.12)), 2)
                niv_siee = "SUPERIOR" if nota_siee >= 4.60 else ("ALTO" if nota_siee >= 4.00 else ("BASICO" if nota_siee >= 3.00 else "BAJO"))
                resultados_eval.append((
                    sql_str(h), str(id_siee), "1", f"{nota_siee:.2f}", "NULL",
                    sql_str(niv_siee), sql_str(f"{anio}-1"), sql_str(f"{anio}-05-20"),
                    sql_str(f"{anio}-06-01 16:00:00"),
                ))

    assert len(resultados_eval) == 12000, f"Error: resultados_eval={len(resultados_eval)}"

    # =========================================================================
    # ESCRITURA DEL ARCHIVO SQL DML INDEPENDIENTE
    # =========================================================================
    with open(OUTPUT_SQL, "w", encoding="utf-8") as f:
        f.write("/* =====================================================================================\n")
        f.write(" * PROYECTO:       Repositorio de Evolución Saber 11, Evaluaciones Internas (SIEE),\n")
        f.write(" *                 Simulacros y Planes de Mejoramiento (Colegios Oficiales Santa Marta)\n")
        f.write(" * ARCHIVO:        14_carga_datos_sinteticos_mariadb.sql\n")
        f.write(" * GENERADOR:      14_generador_datos.py (Semilla determinista: 20261115)\n")
        f.write(" * ETIQUETA:       SINTÉTICO — SOLO USO ACADÉMICO (Regla R9: cero datos personales reales)\n")
        f.write(" * SGBD / MOTOR:   MariaDB 10.4.32 / 10.11.16 (XAMPP Win64 AMD64)\n")
        f.write(" * ALCANCE:        DML puro e independiente del DDL. Ordenado de padres a hijos (Niveles 1 a 4)\n")
        f.write(" *                 con FOREIGN_KEY_CHECKS = 1 y triggers activos. No contiene sentencias\n")
        f.write(" *                 DDL ni operaciones destructivas (DROP/TRUNCATE/DELETE).\n")
        f.write(" * ===================================================================================== */\n\n")
        f.write("USE repo_saber_siee_sm;\n\n")
        f.write("SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;\n")
        f.write("SET SESSION sql_mode = 'STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,NO_ENGINE_SUBSTITUTION,ERROR_FOR_DIVISION_BY_ZERO';\n")
        f.write("SET time_zone = '-05:00';\n\n")
        f.write("START TRANSACTION;\n")

        write_batches(
            f, "parametro_sistema",
            ["clave_parametro", "valor_parametro", "descripcion", "fecha_actualizacion"],
            parametros, "NIVEL 1 · 1/14: parametro_sistema"
        )
        write_batches(
            f, "institucion_educativa",
            ["codigo_dane", "nombre_ie", "comuna_localidad", "sector", "calendario", "jornada_predominante", "estado_activa"],
            instituciones, "NIVEL 1 · 2/14: institucion_educativa"
        )
        write_batches(
            f, "escala_evaluacion",
            ["id_escala", "nombre_escala", "valor_minimo", "valor_maximo", "permite_decimales", "unidad_medida"],
            escalas, "NIVEL 1 · 3/14: escala_evaluacion"
        )
        write_batches(
            f, "area_evaluacion",
            ["id_area", "codigo_area", "nombre_area", "es_nucleo_comun"],
            areas, "NIVEL 1 · 4/14: area_evaluacion"
        )
        write_batches(
            f, "cohorte",
            ["id_cohorte", "codigo_dane", "anio_lectivo", "jornada", "total_matriculados"],
            cohortes, "NIVEL 2 · 5/14: cohorte"
        )
        write_batches(
            f, "transformacion_escala",
            ["id_transformacion", "id_escala_origen", "id_escala_destino", "factor_multiplicador", "constante_desplazamiento", "metodo_justificacion", "vigente"],
            transformaciones, "NIVEL 2 · 6/14: transformacion_escala"
        )
        write_batches(
            f, "instrumento_evaluacion",
            ["id_instrumento", "id_escala", "tipo_instrumento", "nombre_instrumento", "fuente_emision", "periodo_aplicacion"],
            instrumentos, "NIVEL 2 · 7/14: instrumento_evaluacion"
        )
        write_batches(
            f, "promedio_nacional_ref",
            ["id_referente", "anio_vigencia", "id_area", "id_escala", "puntaje_promedio", "desviacion_estandar", "fuente_oficial"],
            promedios_nac, "NIVEL 2 · 8/14: promedio_nacional_ref"
        )
        write_batches(
            f, "plan_mejoramiento",
            ["id_plan", "codigo_dane", "id_area", "anio_implementacion", "titulo_plan", "diagnostico_base", "meta_cuantitativa", "estado_plan"],
            planes, "NIVEL 2 · 9/14: plan_mejoramiento"
        )
        write_batches(
            f, "estudiante_seudonimo",
            ["id_estudiante_hash", "id_cohorte"],
            estudiantes, "NIVEL 3 · 10/14: estudiante_seudonimo"
        )
        write_batches(
            f, "apoyo_institucional",
            ["id_apoyo", "id_cohorte", "tipo_apoyo", "entidad_financiadora", "monto_invertido", "beneficiarios_cubiertos", "fecha_desembolso"],
            apoyos, "NIVEL 3 · 11/14: apoyo_institucional"
        )
        write_batches(
            f, "resultado_agregado_ie",
            ["id_agregado", "id_cohorte", "id_instrumento", "id_area", "periodo_reporte", "puntaje_promedio", "desviacion_estandar", "cantidad_evaluados", "fuente_reporte", "fecha_registro"],
            resultados_agregados, "NIVEL 3 · 12/14: resultado_agregado_ie"
        )
        write_batches(
            f, "seguimiento_actividad_plan",
            ["id_seguimiento", "id_plan", "nombre_actividad", "fecha_seguimiento", "porcentaje_avance_corte", "observaciones", "estado_actividad"],
            seguimientos, "NIVEL 3 · 13/14: seguimiento_actividad_plan (TABLA PRINCIPAL DE HISTORIAL #1 >= 10.000 FILAS)"
        )
        write_batches(
            f, "resultado_evaluacion",
            ["id_estudiante_hash", "id_instrumento", "id_area", "puntaje_obtenido", "percentil_alcanzado", "nivel_desempeno", "periodo_reporte", "fecha_presentacion", "fecha_registro"],
            resultados_eval, "NIVEL 4 · 14/14: resultado_evaluacion (TABLA PRINCIPAL DE HECHOS #2 >= 10.000 FILAS)"
        )

        f.write("\nCOMMIT;\n")

    print(f"Archivo generado exitosamente: {OUTPUT_SQL}")
    print(f"Total filas generadas: {sum(len(x) for x in [parametros, instituciones, escalas, areas, cohortes, transformaciones, instrumentos, promedios_nac, planes, estudiantes, apoyos, resultados_agregados, seguimientos, resultados_eval])}")


if __name__ == "__main__":
    main()
