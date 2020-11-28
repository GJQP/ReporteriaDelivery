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

---- Probando ---
CREATE TABLE rangos (
    id NUMERIC PRIMARY KEY,
    rango rango_tiempo
);
/

-- Probando todos los constructores
INSERT INTO rangos VALUES (1,rango_tiempo());
/
INSERT INTO rangos VALUES (2,rango_tiempo(CURRENT_DATE));
/
INSERT INTO rangos VALUES (3,rango_tiempo(CURRENT_DATE,CURRENT_DATE));
/

-- live sql no soporta tipos nuevos
SELECT * FROM rangos;
/

--
SELECT rng.rango.fecha_inicio, rng.rango.fecha_fin FROM rangos rng;
/


-- Creando un Store Procedure para imprimir una variable boolean
CREATE OR REPLACE PROCEDURE imprimir_variable_boolean(var_boolean BOOLEAN)
AS
BEGIN
    IF var_boolean THEN
       DBMS_OUTPUT.PUT_LINE('Var_boolean es TRUE');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Var_boolean es FALSE');
    END IF;
END;
/

-- Probando cada uno de métodos
DECLARE
    variable_boolean BOOLEAN;
    variable_varchar VARCHAR2(100);
    rng rango_tiempo;
BEGIN

-- Probando método válido

DBMS_OUTPUT.PUT_LINE('PROBANDO MÉTODO VÁLIDO');

DBMS_OUTPUT.PUT_LINE('Debe retornar TRUE');
variable_boolean := rango_tiempo.valido(CURRENT_DATE,CURRENT_DATE);
imprimir_variable_boolean(variable_boolean);

DBMS_OUTPUT.PUT_LINE('Debe retornar FALSE');
variable_boolean := rango_tiempo.valido(CURRENT_DATE,TO_DATE( '08-07-2017 01:30:45', 'MM-DD-YYYY HH24:MI:SS' ));
imprimir_variable_boolean(variable_boolean);

-- Probando método vencido

DBMS_OUTPUT.PUT_LINE('PROBANDO MÉTODO VENCIDO');

DBMS_OUTPUT.PUT_LINE('Debe retornar TRUE');
variable_boolean:= rango_tiempo.vencido( TO_DATE( '08-07-2018 01:30:45', 'MM-DD-YYYY HH24:MI:SS' ));
imprimir_variable_boolean(variable_boolean);

DBMS_OUTPUT.PUT_LINE('Debe retornar FALSE');
variable_boolean:= rango_tiempo.vencido( TO_DATE( '08-07-2021 01:30:45', 'MM-DD-YYYY HH24:MI:SS' ));
imprimir_variable_boolean(variable_boolean);

-- Probando método tiempo para caducar

DBMS_OUTPUT.PUT_LINE('PROBANDO MÉTODO TIEMPO PARA CADUCAR');
variable_varchar:= rango_tiempo.tiempo_para_caducar( TO_DATE( '08-07-2022 05:30:45', 'MM-DD-YYYY HH24:MI:SS' ),TO_DATE( '08-07-2021 01:45:45', 'MM-DD-YYYY HH24:MI:SS' ));
DBMS_OUTPUT.PUT_LINE(variable_varchar);

-- con una fecha
variable_varchar:= rango_tiempo.tiempo_para_caducar( TO_DATE( '08-07-2021 01:30:45', 'MM-DD-YYYY HH24:MI:SS' ));
DBMS_OUTPUT.PUT_LINE(variable_varchar);

-- con fechas no válidas -- lanza error
--variable_varchar:= rango_tiempo.tiempo_para_caducar( TO_DATE( '08-07-2019 01:30:45', 'MM-DD-YYYY HH24:MI:SS' ),TO_DATE( '08-07-2020 01:30:45', 'MM-DD-YYYY HH24:MI:SS' ));
--DBMS_OUTPUT.PUT_LINE(variable_varchar);
END;
/

-- Probando el error de validación en el tercer constructor
--INSERT INTO rangos VALUES (4,rango_tiempo(CURRENT_DATE, TO_DATE( '08-07-2017 01:30:45', 'MM-DD-YYYY HH24:MI:SS' )));
/

DROP TABLE rangos;
/
DROP PROCEDURE imprimir_variable_boolean;
/
DROP TYPE rango_tiempo;
