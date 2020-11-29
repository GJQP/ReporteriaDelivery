CREATE TABLE estados(
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(80) NOT NULL
);
/
CREATE TABLE sumario (
    id_estado INTEGER,
    id INTEGER GENERATED ALWAYS AS IDENTITY,
    fecha DATE,
    deliverys NUMBER(10),
    acumulado NUMBER(20) DEFAULT NULL,
    FOREIGN KEY(id_estado) REFERENCES estados(id),
    PRIMARY KEY(id_estado, id)
);
/
CREATE OR REPLACE PROCEDURE modificar_tabla IS
    cur SYS_REFCURSOR;
    id_e INTEGER;
    id_s INTEGER;
    del NUMBER(10);
    acum NUMBER(20);
BEGIN
    acum := 0;
    OPEN cur FOR SELECT sumario.id_estado, sumario.id, sumario.deliverys FROM sumario ORDER BY fecha;
    LOOP
        FETCH cur INTO id_e, id_s, del;
        exit when cur%notfound;
            acum := acum + del;
            UPDATE sumario SET sumario.acumulado=acum WHERE sumario.id_estado = id_e AND sumario.id = id_s;
    END LOOP;
END;
/
INSERT INTO estados VALUES (DEFAULT, 'Amazonas'); --1
INSERT INTO estados VALUES (DEFAULT, 'Anzoátegui'); --2
INSERT INTO estados VALUES (DEFAULT, 'Apure'); --3
INSERT INTO estados VALUES (DEFAULT, 'Aragua'); --4
INSERT INTO estados VALUES (DEFAULT, 'Barinas'); --5
INSERT INTO estados VALUES (DEFAULT, 'Bolívar'); --6
INSERT INTO estados VALUES (DEFAULT, 'Carabobo'); --7
INSERT INTO estados VALUES (DEFAULT, 'Cojedes'); --8
INSERT INTO estados VALUES (DEFAULT, 'Delta Amacuro'); --9
INSERT INTO estados VALUES (DEFAULT, 'Delta Amacuro'); --10
INSERT INTO estados VALUES (DEFAULT, 'Distrito Capital'); --11
INSERT INTO estados VALUES (DEFAULT, 'Falcón'); --12
INSERT INTO estados VALUES (DEFAULT, 'Guárico'); --13
INSERT INTO estados VALUES (DEFAULT, 'Lara'); --14
INSERT INTO estados VALUES (DEFAULT, 'Mérida'); --15
INSERT INTO estados VALUES (DEFAULT, 'Miranda'); --16
INSERT INTO estados VALUES (DEFAULT, 'Monagas'); --17
INSERT INTO estados VALUES (DEFAULT, 'Nueva Esparta'); --18
INSERT INTO estados VALUES (DEFAULT, 'Portuguesa'); --19
INSERT INTO estados VALUES (DEFAULT, 'Sucre'); --20
INSERT INTO estados VALUES (DEFAULT, 'Táchira'); --21
INSERT INTO estados VALUES (DEFAULT, 'Vargas'); --22
INSERT INTO estados VALUES (DEFAULT, 'Yaracuy'); --23
INSERT INTO estados VALUES (DEFAULT, 'Zulia'); --24
INSERT INTO estados VALUES (DEFAULT, 'Dependencias Federales'); --25

INSERT INTO sumario VALUES (11, DEFAULT, TO_DATE('02-06-2020', 'DD-MM-YYYY'), 100, DEFAULT);
INSERT INTO sumario VALUES (16, DEFAULT, TO_DATE('08-06-2020', 'DD-MM-YYYY'), 500, DEFAULT);
INSERT INTO sumario VALUES (24, DEFAULT, TO_DATE('03-06-2020', 'DD-MM-YYYY'), 200, DEFAULT);
INSERT INTO sumario VALUES (17, DEFAULT, TO_DATE('04-06-2020', 'DD-MM-YYYY'), 5000, DEFAULT);
INSERT INTO sumario VALUES (20, DEFAULT, TO_DATE('01-06-2020', 'DD-MM-YYYY'), 2000, DEFAULT);
/
SELECT TO_CHAR(sumario.fecha, 'DD-MM-YYYY') AS FECHA, estados.nombre, sumario.deliverys, sumario.acumulado FROM sumario INNER JOIN estados ON sumario.id_estado = estados.id;
BEGIN
    modificar_tabla();
END;
SELECT TO_CHAR(sumario.fecha, 'DD-MM-YYYY') AS FECHA, estados.nombre, sumario.deliverys, sumario.acumulado FROM sumario INNER JOIN estados ON sumario.id_estado = estados.id ORDER BY acumulado;
/
DROP PROCEDURE modificar_tabla;
DROP TABLE sumario;
DROP TABLE estados;
/