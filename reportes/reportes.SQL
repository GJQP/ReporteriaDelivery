CREATE OR REPLACE FUNCTION buscar(l_array dbms_utility.lname_array,busq VARCHAR2)
RETURN VARCHAR2
IS
BEGIN
    FOR i IN 1 .. l_array.last
    LOOP
        IF l_array(i) = busq THEN
            RETURN busq;
        END IF;
    END LOOP;

    RETURN '';
END;

CREATE OR REPLACE PROCEDURE reporte1(test_cur OUT sys_refcursor) IS
BEGIN
    OPEN test_cur FOR
    SELECT
        TREAT(APLICACIONES_DELIVERY.app AS MARCA).LOGO as LOGO,
        TREAT(APLICACIONES_DELIVERY.app AS MARCA).NOMBRE as NOMBRE,
        PLANES_DE_SERVICIO.cantidad_envios,
        PLANES_DE_SERVICIO.modalidad,
        TREAT(PLANES_DE_SERVICIO.duracion AS RANGO_TIEMPO).FECHA_INICIO AS FECHA_INICIO,
        TREAT(PLANES_DE_SERVICIO.DURACION AS RANGO_TIEMPO).FECHA_FIN AS FECHA_FIN,
        PLANES_DE_SERVICIO.precio
    FROM
         PLANES_DE_SERVICIO
    INNER JOIN
        APLICACIONES_DELIVERY
    ON
        PLANES_DE_SERVICIO.ID_APP = APLICACIONES_DELIVERY.ID AND PLANES_DE_SERVICIO.CANCELADO IS NULL
    ORDER BY NOMBRE, TREAT(PLANES_DE_SERVICIO.duracion AS RANGO_TIEMPO).FECHA_INICIO;
END;

CREATE OR REPLACE PROCEDURE reporte2(test_cur OUT sys_refcursor, p_estado VARCHAR2 DEFAULT NULL)
IS
    l_count PLS_INTEGER;
    l_array dbms_utility.lname_array;
BEGIN

IF p_estado IS NOT NULL THEN
    dbms_utility.COMMA_TO_TABLE(p_estado,l_count,l_array);
    OPEN test_cur FOR
    SELECT
        EP.EMPRESA.LOGO LOGO,
        EP.EMPRESA.NOMBRE NOMBRE,
        S.*
    FROM
    (SELECT
        C.ID_EMPRESA EMPRESA_ID,
        AD.APP.NOMBRE NOMBRE_APP,
        TO_CHAR(C.DURACION.FECHA_INICIO, 'DD-MM-YYYY') FECHA_REGISTRO,
        TO_CHAR(C.DURACION.FECHA_INICIO, 'DD-MM-YYYY') FECHA_INICIO,
        TO_CHAR(C.DURACION.FECHA_FIN, 'DD-MM-YYYY') FECHA_FIN,
        C.PORCENTAJE_DESCUENTO DESCUENTO,
        PS.MODALIDAD MODALIDAD,
        PS.CANTIDAD_ENVIOS CANTIDAD_ENVIOS,
        PS.PRECIO PRECIO,
        LISTAGG(E.NOMBRE,', ') WITHIN GROUP (ORDER BY E.NOMBRE) AS ESTADOS
    FROM
        PLANES_DE_SERVICIO PS
    INNER JOIN
        APLICACIONES_DELIVERY AD ON AD.id = PS.id_app
    INNER JOIN
        UBICACIONES_APLICABLES UAP ON UAP.ID_APP = PS.ID_APP AND UAP.ID_PLAN = PS.ID
    INNER JOIN
        ESTADOS E ON E.id = UAP.ID_ESTADO
    INNER JOIN
        ESTADOS ESTA ON ESTA.NOMBRE = buscar(l_array,ESTA.nombre)
    INNER JOIN
        UBICACIONES_APLICABLES UBI ON UBI.ID_APP = PS.ID_APP AND UBI.ID_PLAN = PS.ID AND UBI.ID_ESTADO = ESTA.ID
    INNER JOIN
        CONTRATOS C ON C.id_plan = PS.id AND C.id_app = PS.id_app AND C.cancelado IS NULL
    WHERE
        PS.cancelado IS NULL
    GROUP BY
        C.ID_EMPRESA,
        AD.APP.NOMBRE,
        C.DURACION.FECHA_INICIO,
        C.DURACION.FECHA_FIN,
        PS.MODALIDAD,
        PS.CANTIDAD_ENVIOS,
        PS.PRECIO,
        C.PORCENTAJE_DESCUENTO
    ORDER BY
        AD.APP.NOMBRE,
        C.DURACION.FECHA_INICIO) S
    INNER JOIN
        EMPRESAS EP ON EP.id = S.EMPRESA_ID
    ORDER BY 2;
ELSIF p_estado IS NULL THEN
 OPEN test_cur FOR
    SELECT
            EP.EMPRESA.LOGO LOGO,
            EP.EMPRESA.NOMBRE NOMBRE,
            S.*
        FROM
        (SELECT
            C.ID_EMPRESA EMPRESA_ID,
            AD.APP.NOMBRE NOMBRE_APP,
            TO_CHAR(C.DURACION.FECHA_INICIO, 'DD-MM-YYYY') FECHA_REGISTRO,
            TO_CHAR(C.DURACION.FECHA_INICIO, 'DD-MM-YYYY') FECHA_INICIO,
            TO_CHAR(C.DURACION.FECHA_FIN, 'DD-MM-YYYY') FECHA_FIN,
            C.PORCENTAJE_DESCUENTO DESCUENTO,
            PS.MODALIDAD MODALIDAD,
            PS.CANTIDAD_ENVIOS CANTIDAD_ENVIOS,
            PS.PRECIO PRECIO,
            LISTAGG(E.NOMBRE,', ') WITHIN GROUP (ORDER BY E.NOMBRE) AS ESTADOS
        FROM
            PLANES_DE_SERVICIO PS
        INNER JOIN
            APLICACIONES_DELIVERY AD ON AD.id = PS.id_app
        INNER JOIN
            UBICACIONES_APLICABLES UAP ON UAP.ID_APP = PS.ID_APP AND UAP.ID_PLAN = PS.ID
        INNER JOIN
            ESTADOS E ON E.id = UAP.ID_ESTADO
        INNER JOIN
            CONTRATOS C ON C.id_plan = PS.id AND C.id_app = PS.id_app AND C.cancelado IS NULL
        WHERE
            PS.cancelado IS NULL
        GROUP BY
            C.ID_EMPRESA,
            AD.APP.NOMBRE,
            C.DURACION.FECHA_INICIO,
            C.DURACION.FECHA_FIN,
            PS.MODALIDAD,
            PS.CANTIDAD_ENVIOS,
            PS.PRECIO,
            C.PORCENTAJE_DESCUENTO
        ORDER BY
            AD.APP.NOMBRE,
            C.DURACION.FECHA_INICIO) S
        INNER JOIN
            EMPRESAS EP ON EP.id = S.EMPRESA_ID
        ORDER BY 2;
END IF;
END;

CREATE OR REPLACE PROCEDURE reporte3 (test_cur OUT sys_refcursor, sector VARCHAR2 DEFAULT NULL, fecha_ini DATE DEFAULT NULL, fecha_fin DATE DEFAULT NULL, estado_nombre VARCHAR2 DEFAULT NULL)
IS
    l_count_e PLS_INTEGER;
    l_array_e dbms_utility.lname_array;
    l_count_s PLS_INTEGER;
    l_array_s dbms_utility.lname_array;
BEGIN
    IF estado_nombre IS NOT NULL THEN
        dbms_utility.COMMA_TO_TABLE(estado_nombre,l_count_e,l_array_e);
    END IF;
    IF sector IS NOT NULL THEN
        dbms_utility.COMMA_TO_TABLE(sector,l_count_s,l_array_s);
    END IF;

    OPEN test_cur FOR
    SELECT S.*,
        TREAT(AP.APP AS MARCA).LOGO LOGO_APP,
        TREAT(EP.EMPRESA AS MARCA).LOGO LOGO_EMPRESA
        FROM
            (
                SELECT
                PD.ID_APP IDAPP,
                PD.ID_EMPRESA IDEMPRESA,
                E.NOMBRE NOMESTADO,
                TREAT(EP.EMPRESA AS MARCA).NOMBRE NOMBRE_EMP,
                TREAT(AD.APP AS MARCA).NOMBRE NOMBRE_APP,
                SDC.NOMBRE,
                COUNT(PD.TRACKING) AS CANTIDAD_PEDIDOS,
                TRUNC(TREAT(PD.DURACION AS RANGO_TIEMPO).FECHA_INICIO) FI,
                TRUNC(TREAT(PD.DURACION AS RANGO_TIEMPO).FECHA_FIN) FF
            FROM
                PEDIDOS PD
            INNER JOIN
                EMPRESAS EP ON EP.ID = PD.ID_EMPRESA
            INNER JOIN
                APLICACIONES_DELIVERY AD ON AD.ID = PD.ID_APP
            INNER JOIN
                ESTADOS E ON E.ID = PD.ID_ESTADO
            INNER JOIN
                SECTORES_DE_COMERCIO SDC ON SDC.ID = EP.id_sector
            WHERE
                  PD.CANCELADO IS NULL AND
                  (fecha_ini IS NULL OR TRUNC(TREAT(PD.DURACION AS RANGO_TIEMPO).FECHA_INICIO) >= TRUNC(fecha_ini)) AND
                  (fecha_fin IS NULL OR TRUNC(TREAT(PD.DURACION AS RANGO_TIEMPO).FECHA_FIN) <= TRUNC(fecha_fin)) AND
                  (sector IS NULL OR SDC.NOMBRE = buscar(l_array_s,SDC.nombre))
                   AND (estado_nombre IS NULL OR E.nombre = buscar(l_array_e,E.nombre))
            GROUP BY
                    PD.ID_APP,
                    PD.ID_EMPRESA,
                    TREAT(EP.EMPRESA AS MARCA).NOMBRE,
                    TREAT(AD.APP AS MARCA).NOMBRE,
                    SDC.NOMBRE,
                    E.NOMBRE,
                    TRUNC(TREAT(PD.DURACION AS RANGO_TIEMPO).FECHA_INICIO),
                    TRUNC(TREAT(PD.DURACION AS RANGO_TIEMPO).FECHA_FIN)
            ORDER BY
                    PD.ID_EMPRESA,
                    PD.ID_APP,
                    E.NOMBRE,
                    TRUNC(TREAT(PD.DURACION AS RANGO_TIEMPO).FECHA_INICIO)
            ) S
        INNER JOIN
            EMPRESAS EP ON EP.ID = S.IDEMPRESA
        INNER JOIN
            APLICACIONES_DELIVERY AP ON AP.ID = S.IDAPP;
END;

CREATE OR REPLACE PROCEDURE reporte4 (test_cur OUT sys_refcursor, p_estado VARCHAR2 DEFAULT NULL)
IS
    l_count PLS_INTEGER;
    l_array dbms_utility.lname_array;
BEGIN
    IF p_estado IS NOT NULL THEN
        dbms_utility.COMMA_TO_TABLE(p_estado,l_count,l_array);
    END IF;
    OPEN test_cur FOR
    SELECT S.*, TREAT(EX.APP AS MARCA).LOGO LOGO_APP
    FROM
    (
    SELECT
        AD.ID APPI,
        TREAT(AD.APP AS MARCA).NOMBRE NOMBRE_APP,
        E.NOMBRE NOMBRE_ESTADO,
        TDU.NOMBRE NOMBRE_TIPO,
        SUM(DECODE(udt.estado,'OPERATIVA',1,0)) AS UNIDADES_OP,
        SUM(DECODE(udt.estado,'REPARACION',1,0)) AS UNIDADES_REP
    FROM
        GARAJES
    INNER JOIN
        APLICACIONES_DELIVERY AD ON AD.ID = GARAJES.ID_APP
    INNER JOIN
        UNIDADES_DE_TRANSPORTE UDT ON GARAJES.ID_APP = UDT.ID_APP and GARAJES.ID = UDT.ID_GARAJE
    INNER JOIN
        TIPOS_DE_UNIDADES TDU ON UDT.ID_TIPO = TDU.ID
    INNER JOIN
        ESTADOS E ON GARAJES.ID_ESTADO = E.ID
    GROUP BY
        TREAT(AD.APP AS MARCA).NOMBRE,
        E.NOMBRE,
        TDU.NOMBRE,
        AD.ID
    ORDER BY
        TREAT(AD.APP AS MARCA).NOMBRE,
        E.NOMBRE,
        TDU.NOMBRE
    ) S
    INNER JOIN
        APLICACIONES_DELIVERY EX ON EX.ID = S.APPI AND ((p_estado IS NULL) OR S.NOMBRE_ESTADO = buscar(l_array,S.NOMBRE_ESTADO));
END;

CREATE OR REPLACE PROCEDURE reporte6 (test_cur OUT sys_refcursor, p_estado VARCHAR2 DEFAULT NULL, p_fecha_registro DATE DEFAULT NULL)
IS
    l_count PLS_INTEGER;
    l_array dbms_utility.lname_array;
BEGIN
    IF p_estado IS NOT NULL THEN
        dbms_utility.COMMA_TO_TABLE(p_estado,l_count,l_array);
    END IF;
    OPEN test_cur FOR
    SELECT
        USUARIOS.FOTO,
        USUARIOS.PRIMER_NOMBRE,
        USUARIOS.SEGUNDO_NOMBRE,
        USUARIOS.PRIMER_APELLIDO,
        USUARIOS.SEGUNDO_APELLIDO,
        USUARIOS.TIPO_DE_CEDULA,
        USUARIOS.NUMERO_DE_CEDULA,
        --TREAT(USUARIOS.ESTADO AS RANGO_TIEMPO) FECHA_NACIMIENTO,
        USUARIOS.EMAIL,
        TREAT(R.REGISTRO AS RANGO_TIEMPO).FECHA_INICIO,
        TREAT(AD.APP AS MARCA).NOMBRE NOMBRE_APP,
        TREAT(AD.APP AS MARCA).LOGO LOGO_APP,
        D.DESCRIPCION,
        E.NOMBRE
    FROM
        USUARIOS
    INNER JOIN
        REGISTROS R ON USUARIOS.ID = R.ID_USUARIO
    INNER JOIN
        APLICACIONES_DELIVERY AD ON R.ID_APP = AD.ID
    INNER JOIN
        DIRECCIONES D ON USUARIOS.ID = D.ID_USUARIO
    INNER JOIN
        ESTADOS E ON E.ID = D.ID_ESTADO
    WHERE
        R.REGISTRO.FECHA_FIN IS NULL AND (p_estado IS NULL OR E.NOMBRE = buscar(l_array,E.nombre)) AND (p_fecha_registro IS NULL OR TREAT(R.REGISTRO AS RANGO_TIEMPO).FECHA_INICIO >= p_fecha_registro)
    ORDER BY
        E.NOMBRE,
        R.REGISTRO.FECHA_INICIO;
END;



CREATE OR REPLACE PROCEDURE reporte6Version1Direccion(test_cur OUT sys_refcursor, p_estado VARCHAR2 DEFAULT NULL, p_fecha_registro DATE DEFAULT NULL)
IS
    l_count PLS_INTEGER;
    l_array dbms_utility.lname_array;
BEGIN
    IF p_estado IS NOT NULL THEN
        dbms_utility.COMMA_TO_TABLE(p_estado,l_count,l_array);
    END IF;
    OPEN test_cur FOR
    SELECT s.*, u.foto FOTO, TREAT(app.APP AS MARCA).LOGO LOGO_APP FROM
    (SELECT
        --USUARIOS.FOTO,
        USUARIOS.PRIMER_NOMBRE,
        USUARIOS.SEGUNDO_NOMBRE,
        USUARIOS.PRIMER_APELLIDO,
        USUARIOS.SEGUNDO_APELLIDO,
        USUARIOS.TIPO_DE_CEDULA,
        USUARIOS.NUMERO_DE_CEDULA,
        USUARIOS.EMAIL,
        TREAT(R.REGISTRO AS RANGO_TIEMPO).FECHA_INICIO,
        TREAT(AD.APP AS MARCA).NOMBRE NOMBRE_APP,
        MAX(D.DESCRIPCION) DESCRIPCION,
        E.NOMBRE,
        D.ID_ESTADO,
        AD.ID APP_ID,
        USUARIOS.ID U_ID
    FROM
        USUARIOS
    INNER JOIN
        REGISTROS R ON USUARIOS.ID = R.ID_USUARIO
    INNER JOIN
        APLICACIONES_DELIVERY AD ON R.ID_APP = AD.ID
    INNER JOIN
        DIRECCIONES D ON USUARIOS.ID = D.ID_USUARIO
    INNER JOIN
        ESTADOS E ON E.ID = D.ID_ESTADO
    WHERE
        R.REGISTRO.FECHA_FIN IS NULL AND (p_estado IS NULL OR E.NOMBRE = buscar(l_array,E.nombre)) AND (p_fecha_registro IS NULL OR TREAT(R.REGISTRO AS RANGO_TIEMPO).FECHA_INICIO >= p_fecha_registro)
    GROUP BY
        D.ID_ESTADO,
        E.NOMBRE,
        E.ID,
        AD.ID,
        USUARIOS.PRIMER_NOMBRE,
        USUARIOS.SEGUNDO_NOMBRE,
        USUARIOS.PRIMER_APELLIDO,
        USUARIOS.SEGUNDO_APELLIDO,
        USUARIOS.TIPO_DE_CEDULA,
        USUARIOS.NUMERO_DE_CEDULA,
        USUARIOS.ID,
        TREAT(R.REGISTRO AS RANGO_TIEMPO).FECHA_INICIO,
        TREAT(AD.APP AS MARCA).NOMBRE,
        USUARIOS.EMAIL
    ORDER BY
        E.NOMBRE,
        MAX(TREAT(R.REGISTRO AS RANGO_TIEMPO).FECHA_INICIO)) s, USUARIOS u, APLICACIONES_DELIVERY app
    WHERE app.ID = s.APP_ID AND u.ID = s.U_ID;
END;



CREATE OR REPLACE PROCEDURE pruebaimagenes(test_cur OUT sys_refcursor) IS
BEGIN
    OPEN test_cur FOR
    SELECT
        TREAT(APLICACIONES_DELIVERY.app AS MARCA).LOGO as LOGO,
        TREAT(APLICACIONES_DELIVERY.app AS MARCA).NOMBRE as NOMBRE
    FROM
        APLICACIONES_DELIVERY;
END;

CREATE OR REPLACE PROCEDURE pruebaimagenes2(test_cur OUT sys_refcursor) IS
BEGIN
    OPEN test_cur FOR
    SELECT
        TREAT(EMPRESAS.empresa AS MARCA).LOGO as LOGO,
        TREAT(EMPRESAS.empresa AS MARCA).NOMBRE as NOMBRE
    FROM
        EMPRESAS;
END;

CREATE OR REPLACE PROCEDURE pruebaimagenes3(test_cur OUT sys_refcursor) IS
BEGIN
    OPEN test_cur FOR
    SELECT FOTO FROM USUARIOS;
END;


CREATE OR REPLACE PROCEDURE reporte5(test_cur OUT sys_refcursor, p_estado VARCHAR2 DEFAULT NULL)
IS
    l_count PLS_INTEGER;
    l_array dbms_utility.lname_array;
BEGIN
    IF p_estado IS NOT NULL THEN
        dbms_utility.COMMA_TO_TABLE(p_estado,l_count,l_array);
    END IF;
    OPEN test_cur FOR
       SELECT
            s.NOMBRE_ESTADO,
            s.NOMBRE_MUNICIPIO,
            s.NOMBRE_EMPRESA,
            s.NOMBRE_APP,
            s.NUMERO_PEDIDOS,
            TREAT(emp.empresa AS MARCA).LOGO as LOGO_EMP,
            TREAT(apps.app AS MARCA).LOGO as LOGO_APP
            FROM(SELECT
                e.ID ID_ESTADO,
                emp.ID ID_EMP,
                app.ID ID_APP,
                e.NOMBRE NOMBRE_ESTADO,
                mun.NOMBRE NOMBRE_MUNICIPIO,
                ROW_NUMBER() over (
                    PARTITION BY e.ID, mun.ID
                    ORDER BY COUNT(pe.TRACKING) DESC
                ) row_number,
                COUNT(pe.TRACKING) NUMERO_PEDIDOS,
                app.APP.nombre NOMBRE_APP,
                emp.EMPRESA.nombre NOMBRE_EMPRESA
                FROM PEDIDOS pe, DIRECCIONES dir, ESTADOS e, MUNICIPIOS mun, EMPRESAS emp, APLICACIONES_DELIVERY app
                WHERE
                pe.CANCELADO IS NULL
                AND pe.DURACION.fecha_fin IS NOT NULL
                AND dir.ID = pe.ID_DIRECCION
                AND e.ID = dir.ID_ESTADO
                AND mun.ID = dir.ID_MUNICIPIO
                AND emp.ID = pe.ID_EMPRESA
                AND app.ID = pe.ID_APP
                AND (p_estado IS NULL OR e.NOMBRE = buscar(l_array,E.nombre))
                GROUP BY
                e.NOMBRE, app.APP.nombre, emp.EMPRESA.nombre, mun.NOMBRE, e.ID, emp.ID, app.ID, mun.ID
                ORDER BY e.NOMBRE,MAX(pe.DURACION.fecha_fin) DESC,mun.NOMBRE) s, APLICACIONES_DELIVERY apps, EMPRESAS emp
        WHERE row_number <=5
        AND s.ID_EMP = emp.ID
        AND s.ID_APP = apps.ID
        ORDER BY NOMBRE_ESTADO, NUMERO_PEDIDOS DESC;
END;
