--SIMULACION

--MANTENIMIENTO
CREATE OR REPLACE TRIGGER registro_mantenimiento_unidades
    AFTER INSERT OR UPDATE OF estado
    ON unidades_de_transporte
    FOR EACH ROW
    WHEN ( new.estado = 'REPARACION' )
BEGIN
    INSERT INTO registro_de_mantenimiento(id_app, id_garaje, id_unidad, id, fecha_registro)
    VALUES (:NEW.id_app, :NEW.id_garaje, :NEW.id, DEFAULT, SIM_DATE());
END;

CREATE OR REPLACE TRIGGER se_ha_insertado_un_contrato
    AFTER INSERT
    ON contratos
    FOR EACH ROW
DECLARE
    aplicacion VARCHAR2(80);
    empresa    VARCHAR2(80);
BEGIN
    SELECT TREAT(ap.app AS MARCA).nombre INTO aplicacion FROM aplicaciones_delivery ap WHERE :new.id_app = ap.id;
    SELECT TREAT(ep.empresa AS MARCA).nombre INTO empresa FROM empresas ep WHERE :new.id_empresa = ep.id;
    dbms_output.put_line(
                '#### SE HA REGISTRADO UN CONTRATO ENTRE ' || UPPER(aplicacion) || ' y ' || UPPER(empresa) || ' el ' ||
                :new.duracion.fecha_inicio);
END;

CREATE OR REPLACE TRIGGER se_ha_cancelado_un_contrato
    AFTER UPDATE OF cancelado
    ON contratos
    FOR EACH ROW
DECLARE
    aplicacion VARCHAR2(80);
    empresa    VARCHAR2(80);
BEGIN
    SELECT TREAT(ap.app AS MARCA).nombre INTO aplicacion FROM aplicaciones_delivery ap WHERE :new.id_app = ap.id;
    SELECT TREAT(ep.empresa AS MARCA).nombre INTO empresa FROM empresas ep WHERE :new.id_empresa = ep.id;
    dbms_output.put_line(
                '#### SE HA CANCELADO UN CONTRATO ENTRE ' || UPPER(aplicacion) || ' y ' || UPPER(empresa) || ' el ' ||
                :new.duracion.fecha_inicio);
END;

CREATE OR REPLACE TRIGGER se_ha_creado_una_promocion
    AFTER INSERT
    ON eventos
    FOR EACH ROW
DECLARE
    empresa   VARCHAR2(80);
    zona      VARCHAR2(80);
    estado    VARCHAR2(80);
    municipio VARCHAR2(80);
BEGIN
    SELECT TREAT(ep.empresa AS MARCA).nombre,
           z.nombre,
           m.nombre,
           e.nombre
    INTO
        empresa,
        zona,
        municipio,
        estado
    FROM sucursales sc
             INNER JOIN
         empresas ep ON sc.id_empresa = ep.id
             INNER JOIN
         zonas z ON z.id = sc.id_zona
             INNER JOIN
         municipios m ON m.id = sc.id_municipio
             INNER JOIN
         estados e ON e.id = sc.id_estado
    WHERE sc.id = :new.id
      AND sc.id_empresa = :new.id_empresa;
    dbms_output.put_line(
                '#### SE CREÓ UN DESCUENTO PARA ' || UPPER(empresa) || ' EN SUS PRODUCTOS DE LA SUCURSAL DE ' ||
                UPPER(zona) || ', ' || UPPER(municipio) || ', ' || UPPER(estado));
    dbms_output.put_line('##### LA PROMOCIÓN SERÁ VÁLIDAD DESDE EL ' || :new.duracion.fecha_inicio || ' HASTA EL ' ||
                         :new.duracion.fecha_fin);
END;

CREATE OR REPLACE TRIGGER se_inserta_una_nueva_unidad
    AFTER INSERT
    ON unidades_de_transporte
    FOR EACH ROW
DECLARE
    aplicacion     VARCHAR2(80);
    tipo_de_unidad VARCHAR2(80);
    zona           VARCHAR2(80);
    estado         VARCHAR2(80);
    municipio      VARCHAR2(80);
BEGIN
    SELECT TREAT(ad.app AS MARCA).nombre,
           z.nombre,
           m.nombre,
           e.nombre
    INTO
        aplicacion,
        zona,
        estado,
        municipio
    FROM garajes gj
             INNER JOIN
         aplicaciones_delivery ad ON ad.id = gj.id_app
             INNER JOIN
         zonas z ON z.id = gj.id_zona
             INNER JOIN
         municipios m ON m.id = gj.id_zona
             INNER JOIN
         estados e ON z.id = gj.id_estado
    WHERE gj.id_app = :new.id_app
      AND gj.id = :new.id_garaje;
    SELECT tp.nombre
    INTO
        tipo_de_unidad
    FROM tipos_de_unidades tp
    WHERE tp.id = :new.id_tipo;
    dbms_output.put_line('#### HA INGRESADO UNA NUEVA UNIDAD ' || :new.id || ' DEL TIPO ' || UPPER(tipo_de_unidad) ||
                         ' en el garaje de ' || UPPER(aplicacion));
    dbms_output.put_line('##### UBICADO EN ' || UPPER(zona) || ', ' || UPPER(municipio) || ', ' || UPPER(estado));
END;

CREATE OR REPLACE TRIGGER se_ha_cambiado_el_estado_de_la_unidad
    AFTER UPDATE OF estado
    ON unidades_de_transporte
    FOR EACH ROW
DECLARE
    aplicacion     VARCHAR2(80);
    tipo_de_unidad VARCHAR2(80);
    zona           VARCHAR2(80);
    qestado        VARCHAR2(80);
    municipio      VARCHAR2(80);
BEGIN
    SELECT TREAT(ad.app AS MARCA).nombre,
           z.nombre,
           m.nombre,
           e.nombre
    INTO
        aplicacion,
        zona,
        qestado,
        municipio
    FROM garajes gj
             INNER JOIN
         aplicaciones_delivery ad ON ad.id = gj.id_app
             INNER JOIN
         zonas z ON z.id = gj.id_zona
             INNER JOIN
         municipios m ON m.id = gj.id_zona
             INNER JOIN
         estados e ON z.id = gj.id_estado
    WHERE gj.id_app = :new.id_app
      AND gj.id = :new.id_garaje;
    SELECT tp.nombre
    INTO
        tipo_de_unidad
    FROM tipos_de_unidades tp
    WHERE tp.id = :new.id_tipo;
    dbms_output.put_line('#### EL ESTADO DE LA UNIDAD' || :new.id || 'DEL TIPO ' || UPPER(tipo_de_unidad) ||
                         ' en el garaje de ' || UPPER(aplicacion));
    dbms_output.put_line('##### UBICADO EN ' || UPPER(zona) || ', ' || UPPER(municipio) || ', ' || UPPER(qestado));
END;

CREATE OR REPLACE TRIGGER se_ha_hecho_un_nuevo_pedido
    AFTER INSERT
    ON pedidos
    FOR EACH ROW
DECLARE
    nombre_usuario  VARCHAR2(80);
    apelldio_usario VARCHAR2(80);
    nombre_app      VARCHAR2(80);
    nombre_empresa  VARCHAR2(80);
    u_zona          VARCHAR2(80);
    u_municipio     VARCHAR2(80);
    u_estado        VARCHAR2(80);
BEGIN
    SELECT ad.app.nombre,
           ep.empresa.nombre,
           u.primer_nombre,
           u.primer_apellido,
           z.nombre,
           m.nombre,
           e.nombre
    INTO
        nombre_app,
        nombre_empresa,
        u_zona,
        u_municipio,
        u_estado,
        nombre_usuario,
        apelldio_usario
    FROM pedidos pd
             INNER JOIN
         aplicaciones_delivery ad ON pd.id_app = ad.id
             INNER JOIN
         empresas ep ON pd.id_empresa = ep.id
             INNER JOIN
         zonas z ON z.id = pd.id_zona
             INNER JOIN
         municipios m ON m.id = pd.id_municipio
             INNER JOIN
         estados e ON e.id = pd.id_estado
             INNER JOIN
         usuarios u ON u.id = pd.id_usuario
    WHERE pd.tracking = :new.tracking;
    dbms_output.put_line('#### SE HA GENERADO UN NUEVO PEDIDO DEL USUARIO ' || UPPER(nombre_usuario) || ' ' ||
                         UPPER(apelldio_usario) || ' de ' || UPPER(u_zona) || ', ' || UPPER(u_municipio) || ', ' ||
                         UPPER(u_estado));
    dbms_output.put_line(
                '##### PARA LA APLICACIÓN' || UPPER(nombre_app) || ' DE LA EMPRESA ' || UPPER(nombre_empresa) ||
                ' CON EL ID ' || :new.tracking || ' EL ' || :new.duracion.fecha_inicio);
END;

CREATE OR REPLACE TRIGGER se_ha_cancelado_un_pedido
    AFTER UPDATE OF cancelado
    ON pedidos
    FOR EACH ROW
DECLARE
    nombre_usuario  VARCHAR2(80);
    apelldio_usario VARCHAR2(80);
    nombre_app      VARCHAR2(80);
    nombre_empresa  VARCHAR2(80);
    u_zona          VARCHAR2(80);
    u_municipio     VARCHAR2(80);
    u_estado        VARCHAR2(80);
BEGIN
    SELECT ad.app.nombre,
           ep.empresa.nombre,
           u.primer_nombre,
           u.primer_apellido,
           z.nombre,
           m.nombre,
           e.nombre
    INTO
        nombre_app,
        nombre_empresa,
        u_zona,
        u_municipio,
        u_estado,
        nombre_usuario,
        apelldio_usario
    FROM pedidos pd
             INNER JOIN
         aplicaciones_delivery ad ON pd.id_app = ad.id
             INNER JOIN
         empresas ep ON pd.id_empresa = ep.id
             INNER JOIN
         zonas z ON z.id = pd.id_zona
             INNER JOIN
         municipios m ON m.id = pd.id_municipio
             INNER JOIN
         estados e ON e.id = pd.id_estado
             INNER JOIN
         usuarios u ON u.id = pd.id_usuario
    WHERE pd.tracking = :new.tracking;
    dbms_output.put_line('#### SE HA CANCELADO EL PEDIDO DEL USUARIO ' || UPPER(nombre_usuario) || ' ' ||
                         UPPER(apelldio_usario) || ' de ' || UPPER(u_zona) || ', ' || UPPER(u_municipio) || ', ' ||
                         UPPER(u_estado));
    dbms_output.put_line(
                '##### PARA LA APLICACIÓN ' || UPPER(nombre_app) || ' DE LA EMPRESA ' || UPPER(nombre_empresa) ||
                ' CON EL ID ' || :new.tracking || ' EL ' || :new.cancelado.fecha_cancelacion);
    dbms_output.put_line('##### DEBIDO A ' || :new.cancelado.motivo);
END;

CREATE OR REPLACE TRIGGER se_ha_creado_una_ruta
    AFTER INSERT
    ON rutas
    FOR EACH ROW
DECLARE
    tipo_vehiculo VARCHAR(80);
    nombre_app    VARCHAR(80);
BEGIN
    SELECT ap.app.nombre
    INTO
        nombre_app
    FROM aplicaciones_delivery ap
    WHERE ap.id = :new.id_app;
    SELECT tdu.nombre
    INTO
        tipo_vehiculo
    FROM unidades_de_transporte udt
             INNER JOIN
         tipos_de_unidades tdu ON tdu.id = udt.id_tipo
    WHERE udt.id = :new.id_unidad;
    dbms_output.put_line('#### SE HA REGISTRADO UNA RUTA PARA EL PEDIDO NUMERO ' || :new.id_traking ||
                         ' A UNA UNIDAD DE TIPO ' || UPPER(tipo_vehiculo) || ' DE LA APP ' || UPPER(nombre_app));
    IF (:new.proposito = 'PEDIDO') THEN
        dbms_output.put_line('##### LA UNIDAD SE PREPARA PARA BUSCAR EL PEDIDO EN LA SUCURSAL UBICADA EN ' ||
                             :new.destino.latitud || ' ' || :new.destino.longitud);
    ELSIF (:new.proposito = 'ENVIO') THEN
        dbms_output.put_line('##### LA UNIDAD SE PREPARA PARA ENTREGAR EL PEDIDO EN ' || :new.destino.latitud || ' ' ||
                             :new.destino.longitud);
    ELSE
        dbms_output.put_line('##### LA UNIDAD HA ENTREGADO TODOS EL PEDIDO Y SE DIRIGE AL GARAJE UBICADO EN ' ||
                             :new.destino.latitud || ' ' || :new.destino.longitud);
    END IF;
END;

CREATE OR REPLACE TRIGGER se_ha_eliminado_una_ruta
    AFTER UPDATE OF cancelado
    ON rutas
    FOR EACH ROW
DECLARE
    tipo_vehiculo VARCHAR(80);
    nombre_app    VARCHAR(80);
BEGIN
    SELECT ap.app.nombre
    INTO
        nombre_app
    FROM aplicaciones_delivery ap
    WHERE ap.id = :new.id_app;
    SELECT tdu.nombre
    INTO
        tipo_vehiculo
    FROM unidades_de_transporte udt
             INNER JOIN
         tipos_de_unidades tdu ON tdu.id = udt.id_tipo
    WHERE udt.id = :new.id_unidad;
    dbms_output.put_line('#### SE HA CANCELADO UNA RUTA PARA EL PEDIDO NUMERO ' || :new.id_traking ||
                         ' DE UNA UNIDAD DE TIPO ' || UPPER(tipo_vehiculo) || ' DE LA APP ' || UPPER(nombre_app));
    IF (:new.proposito = 'PEDIDO') THEN
        dbms_output.put_line(
                    '##### SE CANCELÓ LA BÚSQUEDA DEL PEDIDO EN LA SUCURSAL UBICADA EN ' || :new.destino.latitud ||
                    ' ' || :new.destino.longitud);
    ELSIF (:new.proposito = 'ENVIO') THEN
        dbms_output.put_line('##### SE CANCELÓ LA ENTREGA DEL PEDIDO EN ' || :new.destino.latitud || ' ' ||
                             :new.destino.longitud);
    ELSE
        dbms_output.put_line('##### LA UNIDAD YA NO RETORNA AL GARAJE UBICADO EN ' || :new.destino.latitud || ' ' ||
                             :new.destino.longitud);
    END IF;
END;
/* No me acuerdo para que lo ibamos a usar XD
CREATE OR REPLACE TRIGGER se_ha_ingresado_a_mantenimiento_una_unidad
AFTER INSERT ON REGISTRO_DE_MANTENIMIENTO
FOR EACH ROW
BEGIN

END;*/
