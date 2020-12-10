--SIMULACION

--MANTENIMIENTO
CREATE OR REPLACE TRIGGER registro_mantenimiento_unidades
BEFORE UPDATE OF estado ON unidades_de_transporte
FOR EACH ROW
WHEN ( NEW.estado = 'REPARACION' )
BEGIN
INSERT INTO registro_de_mantenimiento(id_app,id_garaje,id_unidad,id,fecha_registro)
VALUES (:OLD.id_app,:OLD.id_garaje,:OLD.id,DEFAULT,SYSDATE);
END;

CREATE OR REPLACE TRIGGER se_ha_insertado_un_contrato
AFTER INSERT ON contratos
FOR EACH ROW
DECLARE
    aplicacion VARCHAR2(80);
    empresa VARCHAR2(80);
BEGIN
    SELECT TREAT(AP.APP AS MARCA).NOMBRE INTO aplicacion FROM APLICACIONES_DELIVERY AP WHERE :NEW.ID_APP = AP.ID;
    SELECT TREAT(EP.EMPRESA AS MARCA).NOMBRE INTO empresa FROM EMPRESAS EP WHERE :NEW.ID_EMPRESA = EP.ID;
    DBMS_OUTPUT.PUT_LINE('#### SE HA REGISTRADO UN CONTRATO ENTRE ' || UPPER(aplicacion) || ' y ' || UPPER(empresa) || ' el ' || :NEW.DURACION.FECHA_INICIO);
END;

CREATE OR REPLACE TRIGGER se_ha_cancelado_un_contrato
AFTER UPDATE OF CANCELADO ON contratos
FOR EACH ROW
DECLARE
    aplicacion VARCHAR2(80);
    empresa VARCHAR2(80);
BEGIN
    SELECT TREAT(AP.APP AS MARCA).NOMBRE INTO aplicacion FROM APLICACIONES_DELIVERY AP WHERE :NEW.ID_APP = AP.ID;
    SELECT TREAT(EP.EMPRESA AS MARCA).NOMBRE INTO empresa FROM EMPRESAS EP WHERE :NEW.ID_EMPRESA = EP.ID;
    DBMS_OUTPUT.PUT_LINE('#### SE HA CANCELADO UN CONTRATO ENTRE ' || UPPER(aplicacion) || ' y ' || UPPER(empresa) || ' el ' || :NEW.DURACION.FECHA_INICIO);
END;

CREATE OR REPLACE TRIGGER se_ha_creado_una_promocion
AFTER INSERT ON EVENTOS
FOR EACH ROW
DECLARE
    empresa VARCHAR2(80);
    zona VARCHAR2(80);
    estado VARCHAR2(80);
    municipio VARCHAR2(80);
BEGIN
    SELECT
        TREAT(EP.EMPRESA AS MARCA).NOMBRE,
        Z.NOMBRE,
        M.NOMBRE,
        E.NOMBRE
    INTO
        empresa,
        zona,
        municipio,
        estado
    FROM
        SUCURSALES SC
    INNER JOIN
        EMPRESAS EP ON SC.ID_EMPRESA = EP.ID
    INNER JOIN
        ZONAS Z ON Z.ID = SC.ID_ZONA
    INNER JOIN
        MUNICIPIOS M ON M.ID = SC.ID_MUNICIPIO
    INNER JOIN
        ESTADOS E ON E.ID = SC.ID_ESTADO
    WHERE
        SC.ID = :NEW.ID AND
        SC.ID_EMPRESA = :NEW.ID_EMPRESA;
    DBMS_OUTPUT.PUT_LINE('#### SE CREÓ UN DESCUENTO PARA ' || UPPER(empresa) || ' EN SUS PRODUCTOS DE LA SUCURSAL DE ' || UPPER(zona) || ', ' || UPPER(municipio) || ', ' || UPPER(estado));
    DBMS_OUTPUT.PUT_LINE('##### LA PROMOCIÓN SERÁ VÁLIDAD DESDE EL ' || :NEW.DURACION.FECHA_INICIO || ' HASTA EL ' || :NEW.DURACION.FECHA_FIN);
END;

CREATE OR REPLACE TRIGGER se_inserta_una_nueva_unidad
AFTER INSERT ON UNIDADES_DE_TRANSPORTE
FOR EACH ROW
DECLARE
    aplicacion VARCHAR2(80);
    tipo_de_unidad VARCHAR2(80);
    zona VARCHAR2(80);
    estado VARCHAR2(80);
    municipio VARCHAR2(80);
BEGIN
    SELECT
        TREAT(AD.APP AS MARCA).NOMBRE,
        Z.NOMBRE,
        M.NOMBRE,
        E.NOMBRE
    INTO
        aplicacion,
        zona,
        estado,
        municipio
    FROM
        GARAJES GJ
    INNER JOIN
        APLICACIONES_DELIVERY AD ON AD.ID = GJ.ID_APP
    INNER JOIN
        ZONAS Z ON Z.ID = GJ.ID_ZONA
    INNER JOIN
        MUNICIPIOS M ON M.ID = GJ.ID_ZONA
    INNER JOIN
        ESTADOS E ON Z.ID = GJ.ID_ESTADO
    WHERE
        GJ.ID_APP = :NEW.ID_APP AND
        GJ.ID = :NEW.ID_GARAJE;
    SELECT
        TP.NOMBRE
    INTO
        tipo_de_unidad
    FROM
        TIPOS_DE_UNIDADES TP
    WHERE
        TP.ID = :NEW.ID_TIPO;
    DBMS_OUTPUT.PUT_LINE('#### HA INGRESADO UNA NUEVA UNIDAD ' || :NEW.ID || ' DEL TIPO ' || UPPER(tipo_de_unidad) || ' en el garaje de ' || UPPER(aplicacion));
    DBMS_OUTPUT.PUT_LINE('##### UBICADO EN ' || UPPER(zona) || ', ' || UPPER(municipio) || ', ' || UPPER(estado));
END;

CREATE OR REPLACE TRIGGER se_ha_cambiado_el_estado_de_la_unidad
AFTER UPDATE OF ESTADO ON UNIDADES_DE_TRANSPORTE
FOR EACH ROW
DECLARE
    aplicacion VARCHAR2(80);
    tipo_de_unidad VARCHAR2(80);
    zona VARCHAR2(80);
    qestado VARCHAR2(80);
    municipio VARCHAR2(80);
BEGIN
    SELECT
        TREAT(AD.APP AS MARCA).NOMBRE,
        Z.NOMBRE,
        M.NOMBRE,
        E.NOMBRE
    INTO
        aplicacion,
        zona,
        qestado,
        municipio
    FROM
        GARAJES GJ
    INNER JOIN
        APLICACIONES_DELIVERY AD ON AD.ID = GJ.ID_APP
    INNER JOIN
        ZONAS Z ON Z.ID = GJ.ID_ZONA
    INNER JOIN
        MUNICIPIOS M ON M.ID = GJ.ID_ZONA
    INNER JOIN
        ESTADOS E ON Z.ID = GJ.ID_ESTADO
    WHERE
        GJ.ID_APP = :NEW.ID_APP AND
        GJ.ID = :NEW.ID_GARAJE;
    SELECT
        TP.NOMBRE
    INTO
        tipo_de_unidad
    FROM
        TIPOS_DE_UNIDADES TP
    WHERE
        TP.ID = :NEW.ID_TIPO;
    DBMS_OUTPUT.PUT_LINE('#### EL ESTADO DE LA UNIDAD' || :NEW.ID || 'DEL TIPO ' || UPPER(tipo_de_unidad) || ' en el garaje de ' || UPPER(aplicacion));
    DBMS_OUTPUT.PUT_LINE('##### UBICADO EN ' || UPPER(zona) || ', ' || UPPER(municipio) || ', ' || UPPER(qestado));
END;

CREATE OR REPLACE TRIGGER se_ha_hecho_un_nuevo_pedido
AFTER INSERT ON PEDIDOS
FOR EACH ROW
DECLARE
    nombre_usuario VARCHAR2(80);
    apelldio_usario VARCHAR2(80);
    nombre_app VARCHAR2(80);
    nombre_empresa VARCHAR2(80);
    u_zona VARCHAR2(80);
    u_municipio VARCHAR2(80);
    u_estado VARCHAR2(80);
BEGIN
    SELECT
        AD.APP.NOMBRE,
        EP.EMPRESA.NOMBRE,
        U.PRIMER_NOMBRE,
        U.PRIMER_APELLIDO,
        Z.NOMBRE,
        M.NOMBRE,
        E.NOMBRE
    INTO
        nombre_app,
        nombre_empresa,
        u_zona,
        u_municipio,
        u_estado,
        nombre_usuario,
        apelldio_usario
    FROM
        PEDIDOS PD
    INNER JOIN
        APLICACIONES_DELIVERY AD ON PD.ID_APP = AD.ID
    INNER JOIN
        EMPRESAS EP ON PD.ID_EMPRESA = EP.ID
    INNER JOIN
        ZONAS Z ON Z.ID = PD.ID_ZONA
    INNER JOIN
        MUNICIPIOS M ON M.ID = PD.ID_MUNICIPIO
    INNER JOIN
        ESTADOS E ON E.ID = PD.ID_ESTADO
    INNER JOIN
        USUARIOS U ON U.ID = PD.ID_USUARIO
    WHERE
        PD.TRACKING = :NEW.TRACKING;
    DBMS_OUTPUT.PUT_LINE('#### SE HA GENERADO UN NUEVO PEDIDO DEL USUARIO ' || UPPER(nombre_usuario) || ' ' || UPPER(apelldio_usario) || ' de ' || UPPER(u_zona) || ', ' || UPPER(u_municipio) || ', ' || UPPER(u_estado));
    DBMS_OUTPUT.PUT_LINE('##### PARA LA APLICACIÓN' || UPPER(nombre_app) || ' DE LA EMPRESA ' || UPPER(nombre_empresa) || ' CON EL ID ' || :NEW.TRACKING || ' EL ' || :NEW.DURACION.FECHA_INICIO);
END;

CREATE OR REPLACE TRIGGER se_ha_cancelado_un_pedido
AFTER UPDATE OF cancelado ON PEDIDOS
FOR EACH ROW
DECLARE
    nombre_usuario VARCHAR2(80);
    apelldio_usario VARCHAR2(80);
    nombre_app VARCHAR2(80);
    nombre_empresa VARCHAR2(80);
    u_zona VARCHAR2(80);
    u_municipio VARCHAR2(80);
    u_estado VARCHAR2(80);
BEGIN
    SELECT
        AD.APP.NOMBRE,
        EP.EMPRESA.NOMBRE,
        U.PRIMER_NOMBRE,
        U.PRIMER_APELLIDO,
        Z.NOMBRE,
        M.NOMBRE,
        E.NOMBRE
    INTO
        nombre_app,
        nombre_empresa,
        u_zona,
        u_municipio,
        u_estado,
        nombre_usuario,
        apelldio_usario
    FROM
        PEDIDOS PD
    INNER JOIN
        APLICACIONES_DELIVERY AD ON PD.ID_APP = AD.ID
    INNER JOIN
        EMPRESAS EP ON PD.ID_EMPRESA = EP.ID
    INNER JOIN
        ZONAS Z ON Z.ID = PD.ID_ZONA
    INNER JOIN
        MUNICIPIOS M ON M.ID = PD.ID_MUNICIPIO
    INNER JOIN
        ESTADOS E ON E.ID = PD.ID_ESTADO
    INNER JOIN
        USUARIOS U ON U.ID = PD.ID_USUARIO
    WHERE
        PD.TRACKING = :NEW.TRACKING;
    DBMS_OUTPUT.PUT_LINE('#### SE HA CANCELADO EL PEDIDO DEL USUARIO ' || UPPER(nombre_usuario) || ' ' || UPPER(apelldio_usario) || ' de ' || UPPER(u_zona) || ', ' || UPPER(u_municipio) || ', ' || UPPER(u_estado));
    DBMS_OUTPUT.PUT_LINE('##### PARA LA APLICACIÓN ' || UPPER(nombre_app) || ' DE LA EMPRESA ' || UPPER(nombre_empresa) || ' CON EL ID ' || :NEW.TRACKING || ' EL ' || :NEW.CANCELADO.FECHA_CANCELACION);
    DBMS_OUTPUT.PUT_LINE('##### DEBIDO A ' || :NEW.CANCELADO.MOTIVO);
END;

CREATE OR REPLACE TRIGGER se_ha_creado_una_ruta
AFTER INSERT ON RUTAS
FOR EACH ROW
DECLARE
    tipo_vehiculo VARCHAR(80);
    nombre_app VARCHAR(80);
BEGIN
    SELECT
        AP.APP.NOMBRE
    INTO
        nombre_app
    FROM
        APLICACIONES_DELIVERY AP
    WHERE
        AP.ID = :NEW.ID_APP;
    SELECT
        TDU.NOMBRE
    INTO
        tipo_vehiculo
    FROM
        UNIDADES_DE_TRANSPORTE UDT
    INNER JOIN
        TIPOS_DE_UNIDADES TDU on TDU.ID = UDT.ID_TIPO
    WHERE
        UDT.ID = :NEW.ID_UNIDAD;
    DBMS_OUTPUT.PUT_LINE('#### SE HA REGISTRADO UNA RUTA PARA EL PEDIDO NUMERO ' || :NEW.ID_TRAKING || ' A UNA UNIDAD DE TIPO ' || UPPER(tipo_vehiculo) || ' DE LA APP ' || UPPER(nombre_app));
    IF(:NEW.PROPOSITO = 'PEDIDO') THEN
        DBMS_OUTPUT.PUT_LINE('##### LA UNIDAD SE PREPARA PARA BUSCAR EL PEDIDO EN LA SUCURSAL UBICADA EN ' || :NEW.DESTINO.LATITUD || ' ' || :NEW.DESTINO.LONGITUD);
    ELSIF (:NEW.PROPOSITO = 'ENVIO') THEN
        DBMS_OUTPUT.PUT_LINE('##### LA UNIDAD SE PREPARA PARA ENTREGAR EL PEDIDO EN ' || :NEW.DESTINO.LATITUD || ' ' || :NEW.DESTINO.LONGITUD );
    ELSE
        DBMS_OUTPUT.PUT_LINE('##### LA UNIDAD HA ENTREGADO TODOS EL PEDIDO Y SE DIRIGE AL GARAJE UBICADO EN ' || :NEW.DESTINO.LATITUD || ' ' || :NEW.DESTINO.LONGITUD);
    END IF;
END;

CREATE OR REPLACE TRIGGER se_ha_eliminado_una_ruta
AFTER UPDATE OF CANCELADO ON RUTAS
FOR EACH ROW
DECLARE
    tipo_vehiculo VARCHAR(80);
    nombre_app VARCHAR(80);
BEGIN
    SELECT
        AP.APP.NOMBRE
    INTO
        nombre_app
    FROM
        APLICACIONES_DELIVERY AP
    WHERE
        AP.ID = :NEW.ID_APP;
    SELECT
        TDU.NOMBRE
    INTO
        tipo_vehiculo
    FROM
        UNIDADES_DE_TRANSPORTE UDT
    INNER JOIN
        TIPOS_DE_UNIDADES TDU on TDU.ID = UDT.ID_TIPO
    WHERE
        UDT.ID = :NEW.ID_UNIDAD;
    DBMS_OUTPUT.PUT_LINE('#### SE HA CANCELADO UNA RUTA PARA EL PEDIDO NUMERO ' || :NEW.ID_TRAKING || ' DE UNA UNIDAD DE TIPO ' || UPPER(tipo_vehiculo) || ' DE LA APP ' || UPPER(nombre_app));
    IF(:NEW.PROPOSITO = 'PEDIDO') THEN
        DBMS_OUTPUT.PUT_LINE('##### SE CANCELÓ LA BÚSQUEDA DEL PEDIDO EN LA SUCURSAL UBICADA EN ' || :NEW.DESTINO.LATITUD || ' ' || :NEW.DESTINO.LONGITUD);
    ELSIF (:NEW.PROPOSITO = 'ENVIO') THEN
        DBMS_OUTPUT.PUT_LINE('##### SE CANCELÓ LA ENTREGA DEL PEDIDO EN ' || :NEW.DESTINO.LATITUD || ' ' || :NEW.DESTINO.LONGITUD );
    ELSE
        DBMS_OUTPUT.PUT_LINE('##### LA UNIDAD YA NO RETORNA AL GARAJE UBICADO EN ' || :NEW.DESTINO.LATITUD || ' ' || :NEW.DESTINO.LONGITUD);
    END IF;
END;
/* No me acuerdo para que lo ibamos a usar XD
CREATE OR REPLACE TRIGGER se_ha_ingresado_a_mantenimiento_una_unidad
AFTER INSERT ON REGISTRO_DE_MANTENIMIENTO
FOR EACH ROW
BEGIN

END;*/
