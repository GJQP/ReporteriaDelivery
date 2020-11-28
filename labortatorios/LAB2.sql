--INICIO TDAS
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
--FIN TDAS
--INICIO TABLAS
CREATE TABLE aplicaciones_delivery(
    id NUMBER PRIMARY KEY,
    --marca
    nombre VARCHAR2(30) NOT NULL UNIQUE,
    RIF VARCHAR2(10) NOT NULL
);
/

CREATE TABLE usuarios(
    id NUMBER PRIMARY KEY,
    --persona
    --fecha_de_registros
    id_app NUMBER NOT NULL,

    CONSTRAINT fk_aplicaciones_delivery FOREIGN KEY (id_app) REFERENCES aplicaciones_delivery(id)
);
/

CREATE TABLE zonas(
    id NUMBER PRIMARY KEY,
    nombre VARCHAR2(30) NOT NULL

);
/

CREATE TABLE direcciones(
    id NUMBER PRIMARY KEY,
    --descripcion
    --ubicacion
    --referencia
    id_usuario NUMBER NOT NULL,
    id_zona NUMBER NOT NULL,

    CONSTRAINT fk_usuarios FOREIGN KEY (id_usuario) REFERENCES usuarios(id),
    CONSTRAINT fk_zonas FOREIGN KEY (id_zona) REFERENCES zonas(id)
);
/

CREATE TABLE pedidos(
    tracking NUMBER PRIMARY KEY,
    fechas rango_tiempo NOT NULL,
    precio_total NUMBER(10,2) NOT NULL,
    --cancelado
    --valoracion
    id_direccion NUMBER NOT NULL,

    CONSTRAINT fk_direcciones FOREIGN KEY (id_direccion) REFERENCES direcciones(id)
);
/
--FIN TABLAS

-- INICIO INSERTS
INSERT INTO zonas VALUES (1,'Carapita');
INSERT INTO zonas VALUES (2,'Altagracia');
INSERT INTO zonas VALUES (3,'La Pastora');
INSERT INTO zonas VALUES (4,'La Bombilla');

INSERT INTO aplicaciones_delivery VALUES(1,'Traetelo','J-2314');
INSERT INTO aplicaciones_delivery VALUES(2,'Ubiigo','J-5678');
INSERT INTO aplicaciones_delivery VALUES(3,'Yummy','J-91011');
INSERT INTO aplicaciones_delivery VALUES(4,'PedidosToGo','J-121114');

INSERT INTO usuarios VALUES (1,1);
INSERT INTO usuarios VALUES (2,1);
INSERT INTO usuarios VALUES (3,2);
INSERT INTO usuarios VALUES (4,2);
INSERT INTO usuarios VALUES (5,3);
INSERT INTO usuarios VALUES (6,3);
INSERT INTO usuarios VALUES (7,4);
INSERT INTO usuarios VALUES (8,4);

INSERT INTO direcciones VALUES(1,1,1);
INSERT INTO direcciones VALUES(2,2,2);
INSERT INTO direcciones VALUES(3,3,3);
INSERT INTO direcciones VALUES(4,4,4);
INSERT INTO direcciones VALUES(5,5,1);
INSERT INTO direcciones VALUES(6,6,2);
INSERT INTO direcciones VALUES(7,7,3);
INSERT INTO direcciones VALUES(8,8,4);

INSERT INTO pedidos VALUES(1,rango_tiempo(TO_DATE('2020/09/01', 'yyyy/mm/dd'),TO_DATE('2020/09/01', 'yyyy/mm/dd')),10,1);
INSERT INTO pedidos VALUES(2,rango_tiempo(TO_DATE('2020/09/02', 'yyyy/mm/dd'),TO_DATE('2020/09/02', 'yyyy/mm/dd')),100,2);
INSERT INTO pedidos VALUES(3,rango_tiempo(TO_DATE('2020/09/01', 'yyyy/mm/dd'),TO_DATE('2020/09/01', 'yyyy/mm/dd')),30,3);
INSERT INTO pedidos VALUES(4,rango_tiempo(TO_DATE('2020/09/02', 'yyyy/mm/dd'),TO_DATE('2020/09/02', 'yyyy/mm/dd')),45,4);
INSERT INTO pedidos VALUES(5,rango_tiempo(TO_DATE('2020/09/01', 'yyyy/mm/dd'),TO_DATE('2020/09/01', 'yyyy/mm/dd')),60,5);
INSERT INTO pedidos VALUES(6,rango_tiempo(TO_DATE('2020/09/01', 'yyyy/mm/dd'),TO_DATE('2020/09/01', 'yyyy/mm/dd')),10,6);
INSERT INTO pedidos VALUES(7,rango_tiempo(TO_DATE('2020/09/01', 'yyyy/mm/dd'),TO_DATE('2020/09/01', 'yyyy/mm/dd')),100,7);
INSERT INTO pedidos VALUES(8,rango_tiempo(TO_DATE('2020/09/02', 'yyyy/mm/dd'),TO_DATE('2020/09/02', 'yyyy/mm/dd')),200,8);
INSERT INTO pedidos VALUES(9,rango_tiempo(TO_DATE('2020/09/02', 'yyyy/mm/dd'),TO_DATE('2020/09/02', 'yyyy/mm/dd')),23,1);
INSERT INTO pedidos VALUES(10,rango_tiempo(TO_DATE('2020/09/02', 'yyyy/mm/dd'),TO_DATE('2020/09/02', 'yyyy/mm/dd')),400,2);
INSERT INTO pedidos VALUES(11,rango_tiempo(TO_DATE('2020/09/02', 'yyyy/mm/dd'),TO_DATE('2020/09/02', 'yyyy/mm/dd')),500,3);
INSERT INTO pedidos VALUES(12,rango_tiempo(TO_DATE('2020/09/01', 'yyyy/mm/dd'),TO_DATE('2020/09/01', 'yyyy/mm/dd')),700,4);
INSERT INTO pedidos VALUES(13,rango_tiempo(TO_DATE('2020/09/01', 'yyyy/mm/dd'),TO_DATE('2020/09/01', 'yyyy/mm/dd')),800,5);
INSERT INTO pedidos VALUES(14,rango_tiempo(TO_DATE('2020/09/01', 'yyyy/mm/dd'),TO_DATE('2020/09/01', 'yyyy/mm/dd')),100,6);
INSERT INTO pedidos VALUES(15,rango_tiempo(TO_DATE('2020/09/01', 'yyyy/mm/dd'),TO_DATE('2020/09/01', 'yyyy/mm/dd')),102,7);
INSERT INTO pedidos VALUES(16,rango_tiempo(TO_DATE('2020/09/01', 'yyyy/mm/dd'),TO_DATE('2020/09/01', 'yyyy/mm/dd')),102,8);
-- FIN INSERTS

--INICIO PROCEDURES
CREATE OR REPLACE PROCEDURE validar_pedidos(
    in_fecha IN DATE,
    in_zona VARCHAR2
)
IS
    cur SYS_REFCURSOR;

    nombre_app VARCHAR2(30);
    counting VARCHAR2(30);
    nombre_zona VARCHAR2(30);
    id_zona NUMBER; 

    records NUMBER(1);
BEGIN
    records:= 0;
    SELECT z.id INTO id_zona FROM zonas z WHERE z.nombre = in_zona;
    DBMS_OUTPUT.PUT_LINE('ID zona '|| id_zona);

    OPEN cur FOR
        SELECT app.nombre,
               COUNT(pe.tracking) AS "Pedidos"
        FROM pedidos pe, direcciones dir, zonas zo, aplicaciones_delivery app, usuarios u
        WHERE pe.id_direccion = dir.id
          AND dir.id_zona = zo.id
          AND zo.id = id_zona
          AND zo.nombre = in_zona
          AND u.id = dir.id_usuario
          AND app.id = u.id_app
          AND TRIM(pe.fechas.FECHA_INICIO) = TRIM(IN_FECHA)
        GROUP BY app.nombre;

    LOOP
        FETCH cur INTO nombre_app, counting;
        exit when cur%notfound;
        dbms_output.put_line('RESULTADO: ' || nombre_app || ' generó ' || counting || ' pedido(s) en ' || in_zona || ' para el ' || TO_CHAR(in_fecha, 'yyyy/mm/dd') );
        records := 1;
    END LOOP;
    CLOSE cur;

    IF (records = 0) THEN
       DBMS_OUTPUT.PUT_LINE('NO EXISTEN REGISTROS PARA LA BÚSQUEDA SOLICITADA');
    END IF;

    EXCEPTION
    WHEN no_data_found THEN
        DBMS_OUTPUT.PUT_LINE('NO EXISTE LA ZONA SOLICITADA');
END;
/

--se muestran 2 registros para un total de 3 pedidos
declare
	FECHA DATE := TO_DATE('2020/09/01', 'yyyy/mm/dd');
	ZONA VARCHAR2(100) := 'La Pastora';
begin
    DBMS_OUTPUT.put_line('IMPRIMIENDO RESULTADOS STORED PROCEDURE: ');
	validar_pedidos(
		IN_FECHA => FECHA,
		IN_ZONA => ZONA
	);
end;
/
--IMPRIME NO EXISTEN REGISTROS PARA LA BUSQUEDA
declare
	FECHA DATE := SYSDATE;
	ZONA VARCHAR2(30) := 'Carapita';
begin
	validar_pedidos(
		IN_FECHA => FECHA,
		IN_ZONA => ZONA
	);
end;
/
--IMPRIME NO EXISTE LA ZONA SOLICITADA
declare
	FECHA DATE := SYSDATE;
	ZONA VARCHAR(30) := 'La Yaguara';
begin
	validar_pedidos(
		IN_FECHA => FECHA,
		IN_ZONA => ZONA
	);
end;
--FIN PROCEDURES
/

--DROPS
DROP TABLE pedidos;
DROP TABLE direcciones;
DROP TABLE usuarios;
DROP TABLE aplicaciones_delivery;
DROP TABLE zonas;
DROP PROCEDURE validar_pedidos;
DROP TYPE rango_tiempo;
/

