-- CREATES TDAS
CREATE OR REPLACE TYPE MARCA AS OBJECT(
    nombre VARCHAR2(80),
    rif VARCHAR2(18),
    fecha_de_registro DATE,
    logo BLOB,
    CONSTRUCTOR FUNCTION MARCA(SELF IN OUT NOCOPY MARCA, nombre VARCHAR2, RIF VARCHAR2, fecha_de_registro DATE) RETURN SELF AS RESULT,
    STATIC FUNCTION VALIDAR_RIF(rif VARCHAR2) RETURN VARCHAR2
);
/
CREATE OR REPLACE TYPE BODY MARCA IS
    STATIC FUNCTION VALIDAR_RIF(rif VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        IF REGEXP_LIKE(rif, '^J-[[:digit:]]{8}-[[:digit:]]') THEN
            RETURN rif;
        ELSE
            RAISE_APPLICATION_ERROR(-20001,'Error: El rif no es válido');
        END IF;
    END;

    CONSTRUCTOR FUNCTION MARCA(SELF IN OUT NOCOPY MARCA, nombre VARCHAR2, rif VARCHAR2, fecha_de_registro DATE) RETURN SELF AS RESULT IS
    BEGIN
        SELF.nombre := nombre;
        SELF.rif := MARCA.VALIDAR_RIF(rif);
        SELF.fecha_de_registro := fecha_de_registro;
        SELF.logo := EMPTY_BLOB();
        RETURN;
    END;
END;
/
CREATE OR REPLACE TYPE RANGO_TIEMPO AS OBJECT (
    fecha_inicio DATE,
    fecha_fin DATE,
    CONSTRUCTOR FUNCTION RANGO_TIEMPO(SELF IN OUT NOCOPY RANGO_TIEMPO) RETURN SELF AS RESULT,
    CONSTRUCTOR FUNCTION RANGO_TIEMPO(SELF IN OUT NOCOPY RANGO_TIEMPO, fecha_inicio DATE) RETURN SELF AS RESULT,
    CONSTRUCTOR FUNCTION RANGO_TIEMPO(SELF IN OUT NOCOPY RANGO_TIEMPO, fecha_inicio DATE,fecha_fin DATE) RETURN SELF AS RESULT,
    STATIC FUNCTION VALIDO(fecha_inicio DATE,fecha_fin DATE) RETURN BOOLEAN,
    STATIC FUNCTION VENCIDO(fecha_fin DATE) RETURN BOOLEAN,
    STATIC FUNCTION TIEMPO_PARA_CADUCAR(fecha_fin DATE, fecha_objetivo DATE) RETURN VARCHAR2,
    STATIC FUNCTION TIEMPO_PARA_CADUCAR(fecha_fin DATE) RETURN VARCHAR2
);
/
CREATE OR REPLACE TYPE BODY RANGO_TIEMPO IS
    CONSTRUCTOR FUNCTION RANGO_TIEMPO(SELF IN OUT NOCOPY rango_tiempo) RETURN SELF AS RESULT IS
    BEGIN
        SELF.fecha_inicio := NULL;
        SELF.fecha_fin := NULL;
        RETURN;
    END;

    CONSTRUCTOR FUNCTION RANGO_TIEMPO(SELF IN OUT NOCOPY rango_tiempo,fecha_inicio DATE) RETURN SELF AS RESULT IS
    BEGIN
        SELF.fecha_inicio := fecha_inicio;
        SELF.fecha_fin := NULL;
        RETURN;
    END;

    CONSTRUCTOR FUNCTION RANGO_TIEMPO(SELF IN OUT NOCOPY rango_tiempo, fecha_inicio DATE,fecha_fin DATE) RETURN SELF AS RESULT IS
    BEGIN
        IF RANGO_TIEMPO.valido(fecha_inicio,fecha_fin) THEN
            SELF.fecha_inicio := fecha_inicio;
            SELF.fecha_fin := fecha_fin;
        ELSE
            RAISE_APPLICATION_ERROR(-20001,'Error: rango de fechas no válidos');
        END IF;
        RETURN;
    END;

    STATIC FUNCTION VALIDO(fecha_inicio DATE,fecha_fin DATE) RETURN BOOLEAN
    IS
    BEGIN
        RETURN fecha_inicio <= fecha_fin;
    END;

    STATIC FUNCTION VENCIDO(fecha_fin DATE) RETURN BOOLEAN
    IS
    BEGIN
        RETURN SYSDATE > fecha_fin;
    END;

   STATIC FUNCTION TIEMPO_PARA_CADUCAR(fecha_fin DATE, fecha_objetivo DATE) RETURN VARCHAR2
    AS
        d_diff NUMBER;
    BEGIN
        d_diff := fecha_fin - fecha_objetivo;
        IF (NOT RANGO_TIEMPO.valido(fecha_objetivo,fecha_fin)) THEN RAISE_APPLICATION_ERROR(-20001,'Error: rango de fechas no válidos'); END IF;

        IF (d_diff < 1) THEN
            RETURN REGEXP_SUBSTR(NUMTODSINTERVAL(d_diff,'DAY'),'\d{2}:\d{2}');
        ELSIF (d_diff < 2) THEN
            RETURN TRUNC(d_diff) || ' dia ' || REGEXP_SUBSTR(NUMTODSINTERVAL(d_diff,'DAY'),'\d{2}:\d{2}');
        ELSE
            RETURN TRUNC(d_diff) || ' dias ' || REGEXP_SUBSTR(NUMTODSINTERVAL(d_diff,'DAY'),'\d{2}:\d{2}');
        END IF;

    END;

    STATIC FUNCTION TIEMPO_PARA_CADUCAR(fecha_fin DATE) RETURN VARCHAR2
    IS
    BEGIN
        RETURN TIEMPO_PARA_CADUCAR(fecha_fin,CURRENT_DATE);
    END;
END;
/
CREATE OR REPLACE TYPE CANCELACION AS OBJECT (
   fecha_cancelacion DATE,
   motivo VARCHAR(2000),
   CONSTRUCTOR FUNCTION CANCELACION(SELF IN OUT NOCOPY CANCELACION, fecha_cancelacion DATE) RETURN SELF AS RESULT,
   CONSTRUCTOR FUNCTION CANCELACION(SELF IN OUT NOCOPY CANCELACION, fecha_cancelacion DATE, motivo VARCHAR2) RETURN SELF AS RESULT,
   STATIC FUNCTION VALIDAR_FINALIZACION(fecha_cancelacion DATE) RETURN DATE
);
/
CREATE OR REPLACE TYPE BODY CANCELACION IS
    CONSTRUCTOR FUNCTION CANCELACION(SELF IN OUT NOCOPY CANCELACION, fecha_cancelacion DATE) RETURN SELF AS RESULT IS
    BEGIN
        SELF.fecha_cancelacion := CANCELACION.VALIDAR_FINALIZACION(fecha_cancelacion);
        SELF.motivo := NULL;
        RETURN;
    END;

    CONSTRUCTOR FUNCTION CANCELACION(SELF IN OUT NOCOPY CANCELACION, fecha_cancelacion DATE, motivo VARCHAR2) RETURN SELF AS RESULT IS
    BEGIN
        SELF.fecha_cancelacion := CANCELACION.VALIDAR_FINALIZACION(fecha_cancelacion);
        SELF.motivo := motivo;
        RETURN;
    END;

    STATIC FUNCTION VALIDAR_FINALIZACION(fecha_cancelacion DATE) RETURN DATE IS
    BEGIN
        IF fecha_cancelacion > SYSDATE THEN
            RETURN fecha_cancelacion;
        ELSE
            RAISE_APPLICATION_ERROR(-20001,'Error: la fecha de caducidad no puede ser menor a la actual');
        END IF;
    END;
END;
/
CREATE OR REPLACE TYPE UBICACION AS OBJECT (
    coordenada SDO_GEOMETRY,
    actualizado TIMESTAMP,
    MEMBER FUNCTION OBTENER_POSICION(timpo_transcurrido TIMESTAMP, velocidad_med NUMBER) RETURN SDO_GEOMETRY
);
/
CREATE OR REPLACE TYPE BODY UBICACION IS
    MEMBER FUNCTION OBTENER_POSICION(timpo_transcurrido TIMESTAMP, velocidad_med NUMBER) RETURN SDO_GEOMETRY IS
    BEGIN
        RETURN NULL;
    END;
END;
/

