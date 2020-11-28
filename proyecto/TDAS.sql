CREATE OR REPLACE TYPE rango_tiempo AS OBJECT (
    fecha_inicio DATE,
    fecha_fin DATE,
    CONSTRUCTOR FUNCTION rango_tiempo(SELF IN OUT NOCOPY rango_tiempo) RETURN SELF AS RESULT,
    CONSTRUCTOR FUNCTION rango_tiempo(SELF IN OUT NOCOPY rango_tiempo, fecha_inicio DATE) RETURN SELF AS RESULT,
    CONSTRUCTOR FUNCTION rango_tiempo(SELF IN OUT NOCOPY rango_tiempo, fecha_inicio DATE,fecha_fin DATE) RETURN SELF AS RESULT,
    STATIC FUNCTION valido(fecha_inicio DATE,fecha_fin DATE) RETURN BOOLEAN,
    STATIC FUNCTION vencido(fecha_fin DATE) RETURN BOOLEAN,
    STATIC FUNCTION tiempo_para_caducar(fecha_fin DATE, fecha_objetivo DATE) RETURN VARCHAR2,
    STATIC FUNCTION tiempo_para_caducar(fecha_fin DATE) RETURN VARCHAR2
);
/

CREATE OR REPLACE TYPE BODY rango_tiempo IS

    CONSTRUCTOR FUNCTION rango_tiempo(SELF IN OUT NOCOPY rango_tiempo) RETURN SELF AS RESULT IS
    BEGIN
        SELF.fecha_inicio := NULL;
        SELF.fecha_fin := NULL;
        RETURN;
    END;

    CONSTRUCTOR FUNCTION rango_tiempo(SELF IN OUT NOCOPY rango_tiempo,fecha_inicio DATE) RETURN SELF AS RESULT IS
    BEGIN
        SELF.fecha_inicio := fecha_inicio;
        SELF.fecha_fin := NULL;
        RETURN;
    END;

    CONSTRUCTOR FUNCTION rango_tiempo(SELF IN OUT NOCOPY rango_tiempo, fecha_inicio DATE,fecha_fin DATE) RETURN SELF AS RESULT IS
    BEGIN
        IF rango_tiempo.valido(fecha_inicio,fecha_fin) THEN
            SELF.fecha_inicio := fecha_inicio;
            SELF.fecha_fin := fecha_fin;
        ELSE
            RAISE_APPLICATION_ERROR(-20001,'Error: rango de fechas no válidos');
        END IF;
        RETURN;
    END;

    STATIC FUNCTION valido(fecha_inicio DATE,fecha_fin DATE) RETURN BOOLEAN
    IS
    BEGIN
        RETURN fecha_inicio <= fecha_fin;
    END;

    STATIC FUNCTION vencido(fecha_fin DATE) RETURN BOOLEAN
    IS
    BEGIN
        RETURN SYSDATE > fecha_fin;
    END;

   STATIC FUNCTION tiempo_para_caducar(fecha_fin DATE, fecha_objetivo DATE) RETURN VARCHAR2
    AS
        d_diff NUMBER;
    BEGIN
        d_diff := fecha_fin - fecha_objetivo;
        IF (NOT rango_tiempo.valido(fecha_objetivo,fecha_fin)) THEN RAISE_APPLICATION_ERROR(-20001,'Error: rango de fechas no válidos'); END IF;

        IF (d_diff < 1) THEN
            RETURN REGEXP_SUBSTR(NUMTODSINTERVAL(d_diff,'DAY'),'\d{2}:\d{2}');
        ELSIF (d_diff < 2) THEN
            RETURN TRUNC(d_diff) || ' dia ' || REGEXP_SUBSTR(NUMTODSINTERVAL(d_diff,'DAY'),'\d{2}:\d{2}');
        ELSE
            RETURN TRUNC(d_diff) || ' dias ' || REGEXP_SUBSTR(NUMTODSINTERVAL(d_diff,'DAY'),'\d{2}:\d{2}');
        END IF;

    END;

    STATIC FUNCTION tiempo_para_caducar(fecha_fin DATE) RETURN VARCHAR2
    IS
    BEGIN
        RETURN tiempo_para_caducar(fecha_fin,CURRENT_DATE);
    END;
END;
/

CREATE OR REPLACE TYPE MARCA AS OBJECT(
    nombre VARCHAR2(80),
    rif VARCHAR2(11),
    fecha_de_registro DATE,
    --logo BLOB,
    STATIC FUNCTION VALIDAR_RIF(rif VARCHAR2) RETURN VARCHAR2
);
/
CREATE OR REPLACE TYPE BODY MARCA IS
    STATIC FUNCTION VALIDAR_RIF(rif VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        IF True THEN
            RETURN rif;
        ELSE
            RAISE_APPLICATION_ERROR(-20001,'Error: El rif no es válido');
        END IF;
    END;
END;
/