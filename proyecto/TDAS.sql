-- CREATES TDAS
CREATE OR REPLACE TYPE MARCA AS OBJECT
(
    nombre            VARCHAR2(80),
    rif               VARCHAR2(18),
    fecha_de_registro DATE,
    logo              BLOB,
    CONSTRUCTOR FUNCTION MARCA(self IN OUT NOCOPY MARCA, nombre VARCHAR2, rif VARCHAR2,
                               fecha_de_registro DATE) RETURN SELF AS RESULT,
    STATIC
    FUNCTION validar_rif(rif VARCHAR2) RETURN VARCHAR2
);
/
CREATE OR REPLACE TYPE BODY MARCA IS
    STATIC FUNCTION validar_rif(rif VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        IF REGEXP_LIKE(rif, '^J-[[:digit:]]{8}-[[:digit:]]') THEN
            RETURN rif;
        ELSE
            RAISE_APPLICATION_ERROR(-20001, 'Error: El rif no es válido');
        END IF;
    END;

    CONSTRUCTOR FUNCTION MARCA(self IN OUT NOCOPY MARCA, nombre VARCHAR2, rif VARCHAR2,
                               fecha_de_registro DATE) RETURN SELF AS RESULT IS
    BEGIN
        self.nombre := nombre;
        self.rif := marca.validar_rif(rif);
        self.fecha_de_registro := fecha_de_registro;
        self.logo := EMPTY_BLOB();
        RETURN;
    END;
END;
/
CREATE OR REPLACE TYPE RANGO_TIEMPO AS OBJECT
(
    fecha_inicio DATE,
    fecha_fin    DATE,
    CONSTRUCTOR FUNCTION RANGO_TIEMPO(self IN OUT NOCOPY RANGO_TIEMPO) RETURN SELF AS RESULT,
    CONSTRUCTOR FUNCTION RANGO_TIEMPO(self IN OUT NOCOPY RANGO_TIEMPO, fecha_inicio DATE) RETURN SELF AS RESULT,
    CONSTRUCTOR FUNCTION RANGO_TIEMPO(self IN OUT NOCOPY RANGO_TIEMPO, fecha_inicio DATE, fecha_fin DATE) RETURN SELF AS RESULT,
    STATIC
    FUNCTION valido(fecha_inicio DATE, fecha_fin DATE) RETURN BOOLEAN,
    STATIC
    FUNCTION vencido(fecha_fin DATE) RETURN BOOLEAN,
    STATIC
    FUNCTION tiempo_para_caducar(fecha_fin DATE, fecha_objetivo DATE) RETURN VARCHAR2,
    STATIC
    FUNCTION tiempo_para_caducar(fecha_fin DATE) RETURN VARCHAR2
);
/
CREATE OR REPLACE TYPE BODY RANGO_TIEMPO IS
    CONSTRUCTOR FUNCTION RANGO_TIEMPO(self IN OUT NOCOPY RANGO_TIEMPO) RETURN SELF AS RESULT IS
    BEGIN
        self.fecha_inicio := NULL;
        self.fecha_fin := NULL;
        RETURN;
    END;

    CONSTRUCTOR FUNCTION RANGO_TIEMPO(self IN OUT NOCOPY RANGO_TIEMPO, fecha_inicio DATE) RETURN SELF AS RESULT IS
    BEGIN
        self.fecha_inicio := fecha_inicio;
        self.fecha_fin := NULL;
        RETURN;
    END;

    CONSTRUCTOR FUNCTION RANGO_TIEMPO(self IN OUT NOCOPY RANGO_TIEMPO, fecha_inicio DATE, fecha_fin DATE) RETURN SELF AS RESULT IS
    BEGIN
        IF rango_tiempo.valido(fecha_inicio, fecha_fin) THEN
            self.fecha_inicio := fecha_inicio;
            self.fecha_fin := fecha_fin;
        ELSE
            RAISE_APPLICATION_ERROR(-20001, 'Error: rango de fechas no válidos');
        END IF;
        RETURN;
    END;

    STATIC FUNCTION valido(fecha_inicio DATE, fecha_fin DATE) RETURN BOOLEAN
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
        IF (NOT rango_tiempo.valido(fecha_objetivo, fecha_fin)) THEN
            RAISE_APPLICATION_ERROR(-20001, 'Error: rango de fechas no válidos');
        END IF;

        IF (d_diff < 1) THEN
            RETURN REGEXP_SUBSTR(NUMTODSINTERVAL(d_diff, 'DAY'), '\d{2}:\d{2}');
        ELSIF (d_diff < 2) THEN
            RETURN TRUNC(d_diff) || ' dia ' || REGEXP_SUBSTR(NUMTODSINTERVAL(d_diff, 'DAY'), '\d{2}:\d{2}');
        ELSE
            RETURN TRUNC(d_diff) || ' dias ' || REGEXP_SUBSTR(NUMTODSINTERVAL(d_diff, 'DAY'), '\d{2}:\d{2}');
        END IF;

    END;

    STATIC FUNCTION tiempo_para_caducar(fecha_fin DATE) RETURN VARCHAR2
        IS
    BEGIN
        RETURN tiempo_para_caducar(fecha_fin, CURRENT_DATE);
    END;
END;
/
CREATE OR REPLACE TYPE CANCELACION AS OBJECT
(
    fecha_cancelacion DATE,
    motivo            VARCHAR(2000),
    CONSTRUCTOR FUNCTION CANCELACION(self IN OUT NOCOPY CANCELACION, fecha_cancelacion DATE) RETURN SELF AS RESULT,
    CONSTRUCTOR FUNCTION CANCELACION(self IN OUT NOCOPY CANCELACION, fecha_cancelacion DATE, motivo VARCHAR2) RETURN SELF AS RESULT,
    STATIC
    FUNCTION validar_finalizacion(fecha_cancelacion DATE) RETURN DATE
);
/
CREATE OR REPLACE TYPE BODY CANCELACION IS
    CONSTRUCTOR FUNCTION CANCELACION(self IN OUT NOCOPY CANCELACION, fecha_cancelacion DATE) RETURN SELF AS RESULT IS
    BEGIN
        self.fecha_cancelacion := cancelacion.validar_finalizacion(fecha_cancelacion);
        self.motivo := NULL;
        RETURN;
    END;

    CONSTRUCTOR FUNCTION CANCELACION(self IN OUT NOCOPY CANCELACION, fecha_cancelacion DATE, motivo VARCHAR2) RETURN SELF AS RESULT IS
    BEGIN
        self.fecha_cancelacion := cancelacion.validar_finalizacion(fecha_cancelacion);
        self.motivo := motivo;
        RETURN;
    END;

    STATIC FUNCTION validar_finalizacion(fecha_cancelacion DATE) RETURN DATE IS
    BEGIN
        --         IF fecha_cancelacion > SYSDATE THEN
        RETURN fecha_cancelacion;
        --         ELSE
--             RAISE_APPLICATION_ERROR(-20001,'Error: la fecha de caducidad no puede ser menor a la actual');
--         END IF;
    END;
END;
/
CREATE OR REPLACE TYPE UBICACION AS OBJECT
(
    latitud     NUMBER(17, 14),
    longitud    NUMBER(17, 14),
    actualizado DATE,
    STATIC
    FUNCTION obtener_posicion(p2 UBICACION, p1 UBICACION, velocidad_med NUMBER, tiempo_horas NUMBER) RETURN UBICACION,
    STATIC
    FUNCTION validar_latitud(lat NUMBER) RETURN NUMBER,
    STATIC
    FUNCTION validar_longitud(lon NUMBER) RETURN NUMBER,
    STATIC
    FUNCTION sumar_coordenadas(p1 UBICACION, p2 UBICACION) RETURN UBICACION,
    STATIC
    FUNCTION modulo(p UBICACION) RETURN NUMBER,
    STATIC
    FUNCTION distancia_entre_dos_puntos(p2 UBICACION, p1 UBICACION) RETURN NUMBER,
    STATIC
    FUNCTION vector_ubicacion(p2 UBICACION, p1 UBICACION) RETURN UBICACION,
    STATIC
    FUNCTION obtener_tiempo_estimado_en_horas(p2 UBICACION, p1 UBICACION, velocidad_med NUMBER) RETURN NUMBER
);
/
CREATE OR REPLACE TYPE BODY UBICACION IS
    STATIC FUNCTION obtener_posicion(p2 UBICACION, p1 UBICACION, velocidad_med NUMBER, tiempo_horas NUMBER) RETURN UBICACION IS
        modulo_deseado   NUMBER(30, 14);
        modulo_real      NUMBER(30, 14);
        vector_ubi       UBICACION;
        modulo_kmh       NUMBER(30, 14);
        tiempo_necesario NUMBER(30, 14);
        delta            NUMBER(30, 14);
    BEGIN
        delta := 0.000002;
        modulo_kmh := 0.00134245661127421263782387653989 * velocidad_med;
        modulo_deseado := ubicacion.distancia_entre_dos_puntos(p2, p1);
        vector_ubi := ubicacion.vector_ubicacion(p2, p1);
        modulo_real := ubicacion.distancia_entre_dos_puntos(
                ubicacion(vector_ubi.latitud * modulo_kmh * tiempo_horas + p1.latitud,
                          vector_ubi.longitud * modulo_kmh * tiempo_horas + p1.longitud, SYSDATE), p1);
        dbms_output.put_line(modulo_real - modulo_deseado);
        IF (modulo_real > modulo_deseado + delta) THEN
            dbms_output.put_line('##### El vehículo recorre más de lo esperado');
            tiempo_necesario := distancia_entre_dos_puntos(p2, p1) / modulo_kmh;
            RETURN ubicacion(p2.latitud, p2.longitud, p1.actualizado + tiempo_necesario / 24);
        ELSIF (modulo_real < (modulo_deseado + delta) AND
               modulo_real > (modulo_deseado - delta)) THEN --Falta agregar un delta
            dbms_output.put_line('##### El vehículo recorre lo esperado');
            RETURN ubicacion(p2.latitud, p2.longitud, p1.actualizado + tiempo_horas / 24);
        ELSE
            dbms_output.put_line('##### El vehículo recorre menos de lo esperado');
            RETURN ubicacion(vector_ubi.latitud * modulo_kmh * tiempo_horas + p1.latitud,
                             vector_ubi.longitud * modulo_kmh * tiempo_horas + p1.longitud,
                             p1.actualizado + tiempo_horas / 24);
        END IF;
    END;

    STATIC FUNCTION validar_latitud(lat NUMBER) RETURN NUMBER IS
    BEGIN
        IF (lat > 90 OR lat < -90) THEN
            RAISE_APPLICATION_ERROR(-20001, 'Error: la latitud debe estar entre 90 y -90');
        ELSE
            RETURN lat;
        END IF;
    END;

    STATIC FUNCTION validar_longitud(lon NUMBER) RETURN NUMBER IS
    BEGIN
        IF (lon > 180 OR lon < -180) THEN
            RAISE_APPLICATION_ERROR(-20001, 'Error: la longitud debe estar entre 180 y -180');
        ELSE
            RETURN lon;
        END IF;
    END;

    STATIC FUNCTION sumar_coordenadas(p1 UBICACION, p2 UBICACION) RETURN UBICACION IS
    BEGIN
        RETURN ubicacion(p1.latitud + p2.latitud, p1.longitud + p2.longitud, SYSDATE);
    END;

    STATIC FUNCTION modulo(p UBICACION) RETURN NUMBER IS
    BEGIN
        RETURN SQRT(p.latitud * p.latitud + p.longitud * p.longitud);
    END;

    STATIC FUNCTION distancia_entre_dos_puntos(p2 UBICACION, p1 UBICACION) RETURN NUMBER IS
    BEGIN
        RETURN modulo(ubicacion(p2.latitud - p1.latitud, p2.longitud - p1.longitud, SYSDATE));
    END;

    STATIC FUNCTION vector_ubicacion(p2 UBICACION, p1 UBICACION) RETURN UBICACION IS
        modulo NUMBER(30, 14);
    BEGIN
        modulo := ubicacion.distancia_entre_dos_puntos(p2, p1);
        RETURN ubicacion((p2.latitud - p1.latitud) / modulo, (p2.longitud - p1.longitud) / modulo, SYSDATE);
    END;

    STATIC FUNCTION obtener_tiempo_estimado_en_horas(p2 UBICACION, p1 UBICACION, velocidad_med NUMBER) RETURN NUMBER IS
        modulo_kmh NUMBER(30, 14);
        delta      NUMBER(30, 14);
    BEGIN
        delta := 0.00004;
        modulo_kmh := 0.00134245661127421263782387653989 * velocidad_med;
        RETURN distancia_entre_dos_puntos(p2, p1) / modulo_kmh + delta;
    END;
END;
/

--SELECT UBICACION(10.498337827572668, -66.88071887446146, SYSDATE) FROM DUAL;
--SELECT UBICACION(10.5022515698636, -66.87855164952926, SYSDATE) FROM DUAL;
--SELECT UBICACION.OBTENER_POSICION(UBICACION(10.5022515698636, -66.87855164952926, SYSDATE), UBICACION(10.498337827572668, -66.88071887446146, SYSDATE), 40,5/60) FROM DUAL;
--SELECT UBICACION.VECTOR_UBICACION(UBICACION(10.5022515698636, -66.87855164952926, SYSDATE),UBICACION(10.498337827572668, -66.88071887446146, SYSDATE)) FROM DUAL;
--SELECT ROUND(UBICACION.OBTENER_TIEMPO_ESTIMADO_EN_HORAS(UBICACION(10.5022515698636, -66.87855164952926, SYSDATE), UBICACION(10.498337827572668, -66.88071887446146, SYSDATE), 40)*60) MINUTOS FROM DUAL;
--SELECT 5-4.99874037800506796104299661316991687011 FROM DUAL;
-- P1
--10.498337827572668, -66.88071887446146
-- P2
--10.5022515698636, -66.87855164952926
-- Se supone que debe ir de P1 a P2 en 5 min a 40Km/h