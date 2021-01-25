-- PROCEDURES DE INSERTS
CREATE OR REPLACE PROCEDURE insertar_app_delivery(nombre VARCHAR2,
                                                  rif VARCHAR2,
                                                  fecha_registro DATE,
                                                  nombre_img_logo VARCHAR2)
    IS
    l_size     NUMBER;
    l_file_ptr BFILE;
    l_blob     BLOB;
BEGIN
    l_file_ptr := bfilename('IMGDIR_APPS', nombre_img_logo);
    dbms_lob.fileopen(l_file_ptr);
    l_size := dbms_lob.getlength(l_file_ptr);
    INSERT INTO aplicaciones_delivery (id, app)
    VALUES (DEFAULT, marca(nombre, rif, fecha_registro))
    RETURNING TREAT(app AS MARCA).logo INTO l_blob;
    dbms_lob.loadfromfile(l_blob, l_file_ptr, l_size);
    COMMIT;
    dbms_lob.close(l_file_ptr);
END;

CREATE OR REPLACE PROCEDURE insertar_empresa(nombre VARCHAR2, rif VARCHAR2,
                                             fecha_registro DATE,
                                             nombre_img_logo VARCHAR2,
                                             id_sector INTEGER)
    IS
    l_size     NUMBER;
    l_file_ptr BFILE;
    l_blob     BLOB;
BEGIN
    l_file_ptr := bfilename('IMGDIR_EMPRESAS', nombre_img_logo);
    dbms_lob.fileopen(l_file_ptr);
    l_size := dbms_lob.getlength(l_file_ptr);
    INSERT INTO empresas (id, empresa, id_sector)
    VALUES (DEFAULT, marca(nombre, rif, fecha_registro), id_sector)
    RETURNING TREAT(empresa AS MARCA).logo INTO l_blob;
    dbms_lob.loadfromfile(l_blob, l_file_ptr, l_size);
    COMMIT;
    dbms_lob.close(l_file_ptr);
END;
/

CREATE OR REPLACE PROCEDURE insertar_usuario(p_nombre VARCHAR2,
                                             s_nombre VARCHAR2,
                                             p_apellido VARCHAR2,
                                             s_apellido VARCHAR2,
                                             t_cedula CHAR,
                                             n_cedula NUMBER,
                                             u_email VARCHAR2,
                                             nombre_img_foto VARCHAR2)
    IS
    l_size     NUMBER;
    l_file_ptr BFILE;
    l_blob     BLOB;
BEGIN
    l_file_ptr := bfilename('IMGDIR_USUARIOS', nombre_img_foto);
    dbms_lob.fileopen(l_file_ptr);
    l_size := dbms_lob.getlength(l_file_ptr);
    INSERT INTO usuarios (id, primer_nombre, segundo_nombre, primer_apellido, segundo_apellido, tipo_de_cedula,
                          numero_de_cedula, email, estado, foto)
    VALUES (DEFAULT, p_nombre, s_nombre, p_apellido, s_apellido, t_cedula, n_cedula, u_email, rango_tiempo(SYSDATE),
            empty_blob())
    RETURNING foto INTO l_blob;
    dbms_lob.loadfromfile(l_blob, l_file_ptr, l_size);
    COMMIT;
    dbms_lob.close(l_file_ptr);
END;
/

-- SIMULACION
CREATE OR REPLACE PROCEDURE update_sim_time(p_descripcion VARCHAR2) IS
    d   DATE;
    ids INTEGER;
BEGIN
    UPDATE
        sim_time sm
    SET sm.tiempo = rango_tiempo(sm.tiempo.fecha_inicio, sm.tiempo.fecha_inicio + 15 / 24 / 60)
    WHERE sm.tiempo.fecha_fin IS NULL
    RETURNING sm.tiempo.fecha_inicio INTO d;
    INSERT INTO sim_time
    VALUES (DEFAULT, rango_tiempo(d + 15 / 24 / 60), p_descripcion)
    RETURNING id INTO ids;
    dbms_output.put_line(
                    '# SE HA ACTUALIZADO LA FECHA DE LA SIMULACIÓN DE ' || TO_CHAR(d,'dd-mm-yyyy HH:MI:SS') || ' A ' || TO_CHAR(d + 1 / 4 / 24,'dd-mm-yyyy HH:MI:SS') || ' POR ' ||
                    p_descripcion);
END;

CREATE OR REPLACE FUNCTION sim_date RETURN DATE IS
    d DATE;
BEGIN
    SELECT sm.tiempo.fecha_inicio INTO d FROM sim_time sm WHERE sm.tiempo.fecha_fin IS NULL;
    RETURN d;
END;

--CONTRATOS

--TODO VALIDAR SI LA EMPRESA TIENE SUCURSALES APLICABLES PARA ENTRAR EN ESTA OPCION
--UNA EMPRESA NO CONTRATADA ES AQUELLA DONDE EL ESTADO DEL GARAJE DE LAS APPS Y UNA SUCURSAL COINCIDA
CREATE OR REPLACE FUNCTION obtener_empresa_no_contratada(id_app_busqueda aplicaciones_delivery.id%TYPE,
                                                         fecha_sim DATE DEFAULT sim_date())
    RETURN empresas.id%TYPE
    IS
    appl         aplicaciones_delivery%ROWTYPE;
    san_empresa  empresas%ROWTYPE;
    rand_empresa empresas.id%TYPE;
BEGIN
    SELECT ad.* INTO appl FROM aplicaciones_delivery ad WHERE ad.id = id_app_busqueda;
    dbms_output.put_line(
                '## SELECIONAMOS UNA EMPRESA AL AZAR NO TIENE CONTRADOS POR LA APLICACIÓN (' || id_app_busqueda ||
                ') ' || appl.app.nombre);
    SELECT pac.id_empresa
    INTO rand_empresa
    FROM (SELECT s.id_empresa
          FROM planes_de_servicio pds
                   INNER JOIN ubicaciones_aplicables ua ON pds.id_app = ua.id_app AND pds.id = ua.id_plan
                   INNER JOIN sucursales s ON ua.id_estado = s.id_estado
          WHERE pds.id_app = id_app_busqueda
            AND TREAT(pds.duracion AS RANGO_TIEMPO).fecha_fin > sim_date()
            AND (
                  pds.cancelado IS NULL
                  OR
                  TREAT(pds.cancelado AS CANCELACION).fecha_cancelacion > sim_date()
              )
          GROUP BY s.id_empresa) pac
             LEFT JOIN
         (SELECT e.id
          FROM planes_de_servicio pds
                   INNER JOIN contratos c2 ON pds.id_app = c2.id_app AND pds.id = c2.id_plan
                   INNER JOIN empresas e ON c2.id_empresa = e.id
          WHERE pds.id_app = id_app_busqueda
            AND TREAT(pds.duracion AS RANGO_TIEMPO).fecha_fin > sim_date()
            AND (
                  pds.cancelado IS NULL
                  OR
                  TREAT(pds.cancelado AS CANCELACION).fecha_cancelacion > sim_date()
              )
            AND (
                  c2.cancelado IS NULL
                  OR
                  TREAT(c2.cancelado AS CANCELACION).fecha_cancelacion > sim_date()
              )) yc
         ON yc.id = pac.id_empresa
    WHERE yc.id IS NULL
    ORDER BY dbms_random.value()
        FETCH FIRST ROW ONLY;

    SELECT ep.* INTO san_empresa FROM empresas ep WHERE ep.id = rand_empresa;
    dbms_output.put_line('# LA EMPRESA (' || san_empresa.id || ') ' || san_empresa.empresa.nombre);

    RETURN rand_empresa;

EXCEPTION
    WHEN no_data_found THEN
        RETURN 0;
END;

CREATE OR REPLACE PROCEDURE crear_contrato(in_id_app aplicaciones_delivery.id%TYPE,
                                           in_id_plan planes_de_servicio.id%TYPE, in_id_empresa empresas.id%TYPE)
    IS
    cantidad_contratos_anteriores NUMBER;
    descuento                     contratos.porcentaje_descuento%TYPE;
    api                           aplicaciones_delivery%ROWTYPE;
    emp                           empresas%ROWTYPE;
    plan                          planes_de_servicio%ROWTYPE;
    id_ctro                       INTEGER;
BEGIN
    SELECT ap.* INTO api FROM aplicaciones_delivery ap WHERE ap.id = in_id_app;
    SELECT ps.* INTO plan FROM planes_de_servicio ps WHERE ps.id = in_id_plan;
    SELECT ep.* INTO emp FROM empresas ep WHERE ep.id = in_id_empresa;
    dbms_output.put_line('## SE PROCEDE A GENERAR UN CONTRATO ENTRE LA APP (' || api.id || ') ' || api.app.nombre ||
                         ' Y LA EMPRESA (' || emp.id || ') ' || emp.empresa.nombre);
    dbms_output.put_line('## EL PLAN SELECIONADO TIENE EL ID ' || in_id_plan);
    dbms_output.put_line('## SE VERIFICAN LOS DESCUENTOS POR ANTIGÜEDAD PARA EL CONTRATO');
    SELECT COUNT(1)
    INTO cantidad_contratos_anteriores
    FROM contratos
    WHERE id_app = in_id_app
      AND id_empresa = in_id_empresa;

    IF cantidad_contratos_anteriores > 4 THEN
        descuento := ROUND(dbms_random.value(0, 30), 2);
        dbms_output.put_line(
                    '### SE APLICA UN DESCUENTO (DE 0% a 30%) POR ANTIGUEDAD (>4) EN EL CONTRATO DE ' || descuento ||
                    '%');
    ELSIF cantidad_contratos_anteriores > 2 THEN
        descuento := ROUND(dbms_random.value(0, 10), 2);
        dbms_output.put_line(
                    '### SE APLICA UN DESCUENTO (DE 0% a 10%) POR ANTIGUEDAD (>2) EN EL CONTRATO DE ' || descuento ||
                    '%');
    ELSE
        dbms_output.put_line('### NO SE APLICA PARA DESCUENTO YA QUE EXISTEN MENOS DE 2 CONTRATOS ENTRE AMBOS');
        descuento := 0;
    END IF;

    INSERT INTO contratos
    VALUES (in_id_app,
            in_id_plan,
            in_id_empresa,
            DEFAULT,
            rango_tiempo(sim_date(), sim_date() + ROUND(dbms_random.value(0, 365))),
            descuento,
            NULL)
    RETURN id INTO id_ctro;
    dbms_output.put_line('## EL SE HA CONTRATO GENERADO EXITOSAMENTE CON EL ID ' || id_ctro);
END;

CREATE OR REPLACE PROCEDURE crear_plan_servicio(in_app_id aplicaciones_delivery.id%TYPE,
                                                in_id_empresa empresas.id%TYPE DEFAULT NULL)
    IS
    random_val     NUMBER;
    plan_modalidad planes_de_servicio.modalidad%TYPE;
    id_nuevo_plan  planes_de_servicio.id%TYPE;
    api            aplicaciones_delivery%ROWTYPE;
BEGIN
    SELECT ap.* INTO api FROM aplicaciones_delivery ap WHERE ap.id = in_app_id;
    dbms_output.put_line('## GENERAMOS UN PLAN DE SERVICIO PARA LA APP (' || api.id || ') ' || api.app.nombre);
    dbms_output.put_line('### GENERAMOS UN VALOR ALEATORIO ENTRE 0 Y 1 PARA ELEGIR LA MODALIDAD DEL PLAN DE SERVICIO');
    random_val := dbms_random.value(0, 1);

    IF random_val < 0.25 THEN
        plan_modalidad := 'MENSUAL';
    ELSIF random_val < 0.5 THEN
        plan_modalidad := 'TRIMESTRAL';
    ELSIF random_val < 0.75 THEN
        plan_modalidad := 'SEMESTRAL';
    ELSE
        plan_modalidad := 'ANUAL';
    END IF;
    dbms_output.put_line(
                '### EL VALOR ALEATORIO ES ' || random_val || ' Y LA MODALIDAD ESCOGIDA ES ' || plan_modalidad);

    INSERT INTO planes_de_servicio
    VALUES (in_app_id,
            DEFAULT,
            rango_tiempo(sim_date(), sim_date() + ROUND(dbms_random.value(0, 365))),
            ROUND(dbms_random.value(50, 4000), 2), --PRECIO
            ROUND(dbms_random.value(10, 800)), --CANTIDAD DE ENVIO
            plan_modalidad, --MODALIDAD
            NULL --cancelacion
           )
    RETURNING id INTO id_nuevo_plan;

    dbms_output.put_line('### SE HA GENERADO UN NUEVO PLAN DE SERVICIO CON EL ID ' || id_nuevo_plan);

    IF dbms_random.value(0, 1) < 0.3 THEN
        INSERT INTO ubicaciones_aplicables VALUES (in_app_id, id_nuevo_plan, 14);
    END IF;
    IF dbms_random.value(0, 1) < 0.4 THEN
        INSERT INTO ubicaciones_aplicables VALUES (in_app_id, id_nuevo_plan, 16);
    ELSE
        INSERT INTO ubicaciones_aplicables VALUES (in_app_id, id_nuevo_plan, 24);
    END IF;

    IF in_id_empresa IS NOT NULL THEN
        crear_contrato(in_app_id, id_nuevo_plan, in_id_empresa);
    ELSE
        dbms_output.put_line('## SE SELECCIONA UNA EMPRESA SIN CONTRATO VIGENTE');
        crear_contrato(in_app_id, id_nuevo_plan, obtener_empresa_no_contratada(in_app_id));
    END IF;


END;

CREATE OR REPLACE PROCEDURE modulo_contratos(fecha_sim DATE DEFAULT sim_date())
    IS
    id_app_rand     aplicaciones_delivery.id%TYPE;
    id_plan_selec   planes_de_servicio.id%TYPE;
    id_empresa_rand empresas.id%TYPE;
    CURSOR cursor_planes_app(id_app_rand aplicaciones_delivery.id%TYPE)
        IS
        SELECT ps.id
        FROM planes_de_servicio ps
        WHERE ps.id_app = id_app_rand
          AND TREAT(duracion AS RANGO_TIEMPO).fecha_fin > sim_date()
          AND (
                cancelado IS NULL
                OR
                TREAT(cancelado AS CANCELACION).fecha_cancelacion > sim_date()
            )
        ORDER BY dbms_random.value()
            FETCH FIRST ROW ONLY;
    san_app         aplicaciones_delivery%ROWTYPE;
BEGIN
    --se obtiene la app
    dbms_output.put_line(' ');
    dbms_output.put_line('# SE INICIA EL MÓDULO PARA LA GESTIÓN CONTRATOS');

    dbms_output.put_line('## SE SELECCIONA UNA APLICACION REGISTRADA ALEATORIAMENTE');
    SELECT id
    INTO id_app_rand
    FROM aplicaciones_delivery
    ORDER BY dbms_random.value()
        FETCH FIRST ROW ONLY;
    -- Prefiero no tocar el Query :)
    SELECT ad.* INTO san_app FROM aplicaciones_delivery ad WHERE ad.id = id_app_rand;
    dbms_output.put_line(
                '## SE VERIFICAN LOS PLANES DE SERVICIO DE LA APP (' || san_app.id || ') ' || san_app.app.nombre);

    OPEN cursor_planes_app(id_app_rand);
    dbms_output.put_line('## SE ELIGE UN PLAN DE SERVICIO PARA LA APLICACIÓN ALEATORIAMENTE');
    --se obtiene un plan al azar
    FETCH cursor_planes_app INTO id_plan_selec;


    --NO EXISTEN PLANES VIGENTES O ESTAN CANCELADOS
    IF cursor_planes_app%NOTFOUND = TRUE THEN
        dbms_output.put_line(
                    '### NO EXISTEN PLANES VIGENTES PARA LA APLICACIÓN  (' || san_app.id || ') ' || san_app.app.nombre);
        crear_plan_servicio(id_app_rand);
    ELSE
        dbms_output.put_line(
                    '## SE VERIFICAN SI HAY EMPRESAS NO CONTRADAS VÁLIDAS PARA EL PLAN (' || id_plan_selec || ')');
        id_empresa_rand := obtener_empresa_no_contratada(id_app_rand, fecha_sim);
        IF id_empresa_rand = 0 THEN
            --se usa el plan al azar
            dbms_output.put_line('## NO HAY EMPRESAS DISPONIBLES PARA SE CONTRATADAS');
            dbms_output.put_line('## SE SELECCIONA UN PLAN PARA EVALUAR UN CONTRATO VIGENTE');
            IF dbms_random.value(0, 1) > 0.5 THEN
                dbms_output.put_line('### SE DECIDE CANCELAR UN CONTRATO DEL PLAN ' || id_plan_selec);
                --CANCELAR UN CONTRATO AL AZAR DE DICHO PLAN
                UPDATE contratos
                SET cancelado = cancelacion(fecha_sim, 'CONTRATO NO FACTIBLE POR REVISIÓN PROGRAMADA')
                WHERE id = (
                    SELECT id
                    FROM contratos
                    WHERE id_plan = id_plan_selec
                    ORDER BY dbms_random.value()
                        FETCH FIRST ROW ONLY
                );
            ELSE
                dbms_output.put_line('### NO SE DECIDE CANCELAR UN CONTRATO DEL PLAN' || id_plan_selec);
            END IF;
        ELSIF dbms_random.value(0, 1) > 0.8 THEN
            dbms_output.put_line('### HAY PROVEEDORES A CONTRATARSE');
            dbms_output.put_line('## SE DECIDE GENERAR UN NUEVO PLAN DE SERVICIO A LA EMPRESA ' || id_empresa_rand);
            crear_plan_servicio(id_app_rand, id_empresa_rand);
        ELSE
            dbms_output.put_line('### HAY PROVEEDORES A CONTRATARSE');
            dbms_output.put_line(
                        '### SE DECIDE GENERAR UN CONTRATO EN BASE EL PLAN ' || id_plan_selec || ' A LA EMPRESA ' ||
                        id_empresa_rand);
            crear_contrato(id_app_rand, id_plan_selec, id_empresa_rand);
        END IF;

    END IF;
    dbms_output.put_line('## FIN DEL MÓDULO PARA LA GESTIÓN DE CONTRATOS');
    CLOSE cursor_planes_app;
END;

--FIN CONTRATOS

--INICIO MANTENIMIENTO

--SE PUEDE HACER POR APP
CREATE OR REPLACE PROCEDURE modulo_mantenimiento(fecha_sim DATE DEFAULT sim_date(),
                                                 in_app aplicaciones_delivery.id%TYPE DEFAULT NULL)
    IS
    dias_para_descontinuar CONSTANT       NUMBER := 30;
    dias_para_realizar_mant_prev CONSTANT NUMBER := 90;
    unidad                                unidades_de_transporte%ROWTYPE;
    ult_mantenimiento                     registro_de_mantenimiento%ROWTYPE;
    CURSOR unidades_app(in_id_app aplicaciones_delivery.id%TYPE DEFAULT NULL)
        IS
        SELECT *
        FROM unidades_de_transporte ut
        WHERE in_id_app IS NULL
           OR ut.id_app = in_id_app
        ORDER BY dbms_random.value();
    CURSOR mant_unidad(unidad unidades_app%ROWTYPE)
        IS
        SELECT *
        INTO ult_mantenimiento
        FROM registro_de_mantenimiento
        WHERE id_app = unidad.id_app
          AND id_garaje = unidad.id_garaje
          AND id_unidad = unidad.id
        ORDER BY id DESC
            FETCH FIRST ROW ONLY;

BEGIN
    dbms_output.put_line(' ');
    dbms_output.put_line('# SE INICIA EL MÓDULO PARA LA GESTIÓN DE MANTENIMIENTO DE LAS UNIDADES DE TRANSPORTE');
    FOR unidad IN unidades_app(in_app)
        LOOP
            dbms_output.put_line('## SE VERIFICA EL ESTADO DE LA UNIDAD (' || unidad.id || ')');

            IF unidad.estado = 'REPARACION' THEN
                dbms_output.put_line(
                        '### LA UNIDAD ESTÁ DAÑADA SE DECIDE SI REALIZAR O NO EL MANTENIMIENTO (ALEATORIAMENTE) A LA UNIDAD');
                IF dbms_random.value(0, 1) > 0.5 THEN

                    dbms_output.put_line('## SE DECIDE SI REALIZAR MANTENIMIENTO CORRECTIVO ' ||
                                         'O DESCONTINUAR LA UNIDAD');

                    SELECT *
                    INTO ult_mantenimiento
                    FROM registro_de_mantenimiento
                    WHERE id_app = unidad.id_app
                      AND id_garaje = unidad.id_garaje
                      AND id_unidad = unidad.id
                    ORDER BY id DESC
                        FETCH FIRST ROW ONLY;

                    IF ult_mantenimiento.fecha_registro - fecha_sim
                        >
                       dias_para_descontinuar THEN
                        dbms_output.put_line('### SE DECIDE A NO REALIZAR MANTENIMIENTO Y DESCONTINUAR LA UNIDAD');

                        UPDATE unidades_de_transporte
                        SET estado = 'DESCONTINUADA'
                        WHERE id = unidad.id
                          AND id_garaje = unidad.id_garaje
                          AND id_app = unidad.id_app;
                    ELSE
                        dbms_output.put_line('### SE DECIDE REALIZAR MANTENIMIENTO Y REPARAR LA UNIDAD');

                        UPDATE unidades_de_transporte
                        SET estado = 'OPERATIVA'
                        WHERE id = unidad.id
                          AND id_garaje = unidad.id_garaje
                          AND id_app = unidad.id_app;

                    END IF;

                ELSE
                    dbms_output.put_line(
                            '### SE DECIDE NO REALIZAR MANTENIMIENTO A LA UNIDAD Y CONTINUARÁ EN MANTENIMIENTO');
                END IF;
            ELSIF unidad.estado = 'OPERATIVA' THEN

                dbms_output.put_line('### LA UNIDAD ESTÁ OPERATIVA');

                OPEN mant_unidad(unidad);
                FETCH mant_unidad INTO ult_mantenimiento;

                IF mant_unidad%NOTFOUND AND dbms_random.value(0, 1) > 0.2 THEN
                    dbms_output.put_line('### SE REALIZA MANTENIMIENTO PREVENTIVO ' ||
                                         'A LA UNIDAD');

                    UPDATE unidades_de_transporte
                    SET estado = 'REPARACION'
                    WHERE id = unidad.id
                      AND id_garaje = unidad.id_garaje
                      AND id_app = unidad.id_app;

                ELSE
                    dbms_output.put_line('## SE VERIFICA SI REQUIERE DE MANTENIMIENTO PREVENTIVO');
                    IF ult_mantenimiento.fecha_registro - fecha_sim > dias_para_realizar_mant_prev THEN
                        dbms_output.put_line('### SE REALIZA MANTENIMIENTO PREVENTIVO' ||
                                             ' A LA UNIDAD');

                        UPDATE unidades_de_transporte
                        SET estado = 'REPARACION'
                        WHERE id = unidad.id
                          AND id_garaje = unidad.id_garaje
                          AND id_app = unidad.id_app;
                    ELSE
                        dbms_output.put_line('### SE MANTIENE OPERATIVA LA UNIDAD');
                    END IF;

                END IF;

                CLOSE mant_unidad;

            END IF;
        END LOOP;
    dbms_output.put_line('## FIN DEL MÓDULO PARA La GESTIÓN DE MANTENIMIENTO DE LAS UNIDADES DE TRANSPORTE');
END;

--FIN MANTENIMIENTO

-- PEDIDOS

CREATE OR REPLACE FUNCTION sucursal_factible(in_id_app aplicaciones_delivery.id%TYPE,
                                             in_id_empresa empresas.id%TYPE,
                                             in_direccion direcciones%ROWTYPE)
    RETURN sucursales.id%TYPE
    IS
    id_sucursal  sucursales.id%TYPE;
    id_zona      NUMBER;
    id_municipio NUMBER;
    id_estado    NUMBER;
    san_app      aplicaciones_delivery%ROWTYPE;
    san_empresa  empresas%ROWTYPE;
    n_e          VARCHAR2(80);
    n_m          VARCHAR2(80);
    n_z          VARCHAR2(80);
BEGIN
    SELECT ad.* INTO san_app FROM aplicaciones_delivery ad WHERE ad.id = in_id_app;
    SELECT ep.* INTO san_empresa FROM empresas ep WHERE ep.id = in_id_empresa;
    SELECT e.nombre, m.nombre, z.nombre
    INTO n_e, n_m, n_z
    FROM zonas z
             INNER JOIN municipios m ON m.id = z.id_municipio
             INNER JOIN estados e ON e.id = z.id_estado
    WHERE z.id = in_direccion.id_zona;

    dbms_output.put_line('SELECIONAMOS LA SUCURSAL FACTIBLE MÁS CERCANA PARA LA EMPRESA (' || san_empresa.id || ') ' ||
                         san_empresa.empresa.nombre || ' CERCANO ' || n_e || ', ' || n_m || ', ' || n_z);
    SELECT DISTINCT s.id,
                    DECODE(s.id_zona, DECODE(in_direccion.id_zona, g.id_zona, s.id_zona, 0), s.id_zona, 0)           AS id_zona,
                    DECODE(s.id_municipio, DECODE(in_direccion.id_municipio, g.id_municipio, s.id_municipio, 0),
                           s.id_municipio,
                           0)                                                                                        AS id_municipio,
                    DECODE(s.id_estado, DECODE(in_direccion.id_estado, g.id_estado, s.id_estado, 0), s.id_estado,
                           0)                                                                                        AS id_estado
    INTO sucursal_factible.id_sucursal, sucursal_factible.id_zona, sucursal_factible.id_municipio, sucursal_factible.id_estado
    FROM sucursales s
             JOIN garajes g ON s.id_estado = g.id_estado
        --JOIN direcciones d ON g.id_estado = d.id_estado
             JOIN unidades_de_transporte udt ON g.id_app = udt.id_app AND g.id = udt.id_garaje
             JOIN tipos_de_unidades tdu ON udt.id_tipo = tdu.id
             JOIN almacenes a2 ON s.id_empresa = a2.id_empresa AND s.id = a2.id_sucursal
    WHERE g.id_app = in_id_app                                                                       --APP
      --AND d.id_usuario = in_id_usuario --USUARIO
      AND s.id_empresa = in_id_empresa--EMPRESA
      AND 0 < (SELECT COUNT(disponibilidad) FROM almacenes al WHERE al.id_sucursal = a2.id_sucursal) --DISPONIBILIDAD
      AND udt.estado = 'OPERATIVA'
      AND (
            (s.id_zona = g.id_zona AND s.id_zona = in_direccion.id_zona) --ZONA
            OR
            (s.id_municipio = g.id_municipio AND s.id_municipio = in_direccion.id_municipio AND
             tdu.distancia_operativa NOT LIKE 'ZONA')--MUNICIPIO
            OR
            (tdu.distancia_operativa LIKE 'ESTADO')--ESTADO
        )--ALCANCE
    ORDER BY id_zona DESC, id_municipio DESC, id_estado DESC
        FETCH FIRST ROW ONLY;

    RETURN id_sucursal;

EXCEPTION
    WHEN no_data_found THEN
        RETURN 0;
END;

CREATE OR REPLACE FUNCTION obtener_descuentos(empresa_id empresas.id%TYPE, sucursal_id sucursales.id%TYPE)
    RETURN eventos.porcentaje_descuento%TYPE
    IS
    res eventos.porcentaje_descuento%TYPE := 0;
BEGIN
    dbms_output.put_line('## BUSCAMOS SI LA SUCURSAL (' || sucursal_id || ') TIENE ALGÚN EVENTO DE DESCUENTO');
    SELECT e.porcentaje_descuento
    INTO res
    FROM eventos e
    WHERE id_empresa = empresa_id
      AND id_sucursal = sucursal_id
      AND e.duracion.fecha_inicio >= sim_date()
      AND e.duracion.fecha_fin IS NULL
        FETCH FIRST ROW ONLY;

    RETURN res;

EXCEPTION
    WHEN no_data_found THEN RETURN res;

END;

CREATE OR REPLACE PROCEDURE crear_pedido_aleatorio(app_id aplicaciones_delivery.id%TYPE,
                                                   plan_id planes_de_servicio.id%TYPE,
                                                   empresa_id empresas.id%TYPE,
                                                   contrato_id contratos.id%TYPE,
                                                   estado_id estados.id%TYPE,
                                                   municipio_id municipios.id%TYPE,
                                                   zona_id zonas.id%TYPE,
                                                   usuario_id usuarios.id%TYPE,
                                                   direccion_id direcciones.id%TYPE,
                                                   sucursal_id sucursales.id%TYPE)
    IS

    CURSOR disponibilidad_producto(
        in_cur_id_empresa empresas.id%TYPE,
        in_cur_id_sucursal sucursales.id%TYPE)
        IS
        SELECT p.id, p.precio, a.disponibilidad
        FROM almacenes a
                 JOIN productos p ON a.id_producto = p.id
        WHERE a.id_empresa = in_cur_id_empresa
          AND a.id_sucursal = in_cur_id_sucursal;
    TYPE ITEM IS RECORD (
        producto_id productos.id%TYPE,
        cantidad detalles.cantidad%TYPE,
        precio_unitario detalles.precio_unitario%TYPE
        );
    TYPE CARRITO IS TABLE OF ITEM;
    descuento     eventos.porcentaje_descuento%TYPE;
    producto      disponibilidad_producto%ROWTYPE;
    detalle_orden CARRITO := carrito();
    total_orden   NUMBER  := 0;
    pedido        pedidos.tracking%TYPE;
BEGIN
    dbms_output.put_line('## SE PRODCE A CREAR UN PEDIDO PARA LA EMPRESA (' || empresa_id || ') CON EL CONTRATO (' ||
                         contrato_id || ') PARA EL USUARIO (' || usuario_id || ')');
    descuento := obtener_descuentos(empresa_id, sucursal_id);
    FOR producto IN disponibilidad_producto(empresa_id, sucursal_id)
        LOOP
            IF producto.disponibilidad > 0 THEN
                detalle_orden.extend();

                --aux.cantidad := FLOOR(dbms_random.VALUE(1,producto.disponibilidad));
                --aux.precio_unitario := producto.precio;

                detalle_orden(detalle_orden.last).producto_id := producto.id;
                detalle_orden(detalle_orden.last).cantidad := FLOOR(dbms_random.value(1, producto.disponibilidad));
                detalle_orden(detalle_orden.last).precio_unitario := producto.precio * (1 - descuento);

                total_orden := total_orden +
                               producto.precio * detalle_orden(detalle_orden.last).cantidad * (1 - descuento);
            END IF;
        END LOOP;

    IF descuento > 0 THEN
        dbms_output.put_line(
                    '### EL PEDIDO HA APLICADO UN DESCUENTO DE ' || descuento || '% A LOS PRODUCTOS DEL CONTRATO');
    END IF;

    INSERT INTO pedidos
    VALUES (app_id,
            plan_id,
            empresa_id,
            contrato_id,
            DEFAULT,
            estado_id,
            municipio_id,
            zona_id,
            usuario_id,
            direccion_id,
            rango_tiempo(sim_date()),
            total_orden,
            NULL,
            NULL,
            NULL)
    RETURNING tracking INTO pedido;

    FOR l_orden IN detalle_orden.first..detalle_orden.last
        LOOP
            INSERT INTO detalles
            VALUES (empresa_id,
                    sucursal_id,
                    detalle_orden(l_orden).producto_id,
                    pedido,
                    DEFAULT,
                    detalle_orden(l_orden).precio_unitario,
                    detalle_orden(l_orden).cantidad);

            UPDATE almacenes
            SET disponibilidad = disponibilidad - detalle_orden(l_orden).cantidad
            WHERE id_sucursal = sucursal_id
              AND id_empresa = empresa_id
              AND id_producto = producto.id;
        END LOOP;
END;

CREATE OR REPLACE FUNCTION obtener_usuario_azar_pedido
    RETURN usuarios.id%TYPE
    IS
BEGIN

    FOR l_usuario IN (
        SELECT u.id, r.id_app, u.primer_nombre, ad.app.nombre
        FROM usuarios u
                 INNER JOIN registros r ON u.id = r.id_usuario
                 INNER JOIN aplicaciones_delivery ad ON ad.id = r.id_app
        ORDER BY dbms_random.value()
        )
        LOOP
            dbms_output.put_line('## SE SELECCIONA LA USUARIO DE ID ' || l_usuario.id);
            dbms_output.put_line('## SE VERIFICA SI TIENE APPS CON CONTRATOS VIGENTES');
            FOR l_app IN (
                SELECT DISTINCT r.id_app
                FROM registros r
                         INNER JOIN contratos c2 ON r.id_app = c2.id_app
                         INNER JOIN planes_de_servicio pds ON c2.id_app = pds.id_app AND c2.id_plan = pds.id
                WHERE r.id_usuario = l_usuario.id
                  AND c2.duracion.fecha_fin >= sim_date()
                  AND c2.cancelado IS NULL
                  AND pds.duracion.fecha_fin >= sim_date()
                  AND pds.cancelado IS NULL
                    FETCH FIRST ROW ONLY)
                LOOP
                    RETURN l_usuario.id;
                END LOOP;
            dbms_output.put_line('## EL USUARIO' || l_usuario.id || ' NO TIENE APPS CON CONTRATOS VIGENTES');
        END LOOP;

    RETURN 0;

END;

CREATE OR REPLACE PROCEDURE modulo_pedido
    IS

    CURSOR empresas_elegibles(cur_app_id aplicaciones_delivery.id%TYPE, cur_usuario_id usuarios.id%TYPE)
        IS
        SELECT c2.id_app, c2.id_plan, c2.id_empresa, c2.id AS id_contrato
        FROM contratos c2
                 JOIN planes_de_servicio pds ON pds.id_app = c2.id_app AND pds.id = c2.id_plan
                 JOIN ubicaciones_aplicables ua ON pds.id_app = ua.id_app AND pds.id = ua.id_plan

        WHERE (pds.duracion.fecha_fin > sim_date() OR pds.duracion.fecha_fin IS NULL) --PLAN VIGENTE
          AND (c2.duracion.fecha_fin > sim_date() OR c2.duracion.fecha_fin IS NULL)   --CONTRATO VIGENTE
          AND ua.id_estado IN (SELECT d.id_estado
                               FROM direcciones d
                               WHERE d.id_usuario = cur_usuario_id)                   -- DEL ESTADO DE LAS DIRECCIONES DE LA PERSONA
          AND c2.id_app = cur_app_id;-- DE LA APP

    rand_usuario_id     usuarios.id%TYPE;
    app_id              aplicaciones_delivery.id%TYPE;
    cont_id             contratos.id%TYPE;
    direccion_usuario   direcciones%ROWTYPE;
    fk_pedidos_sucursal empresas_elegibles%ROWTYPE;
    id_suc              sucursales.id%TYPE := 0;
    san_usuario         usuarios%ROWTYPE;
    san_app             aplicaciones_delivery%ROWTYPE;
    san_empresa         empresas%ROWTYPE;
BEGIN
    dbms_output.put_line(' ');
    dbms_output.put_line('# SE INICIA EL MÓDULO PARA LA GESTIÓN DE PEDIDOS');
    dbms_output.put_line('## SE SELECIONA UN USUARIO ALEATORIAMENTE');
    --SELECCIONA UN USUARIO AL AZAR REGISTRADO
    rand_usuario_id := obtener_usuario_azar_pedido();

    IF rand_usuario_id = 0 THEN
        dbms_output.put_line('### NO SE HA OBTENIDO UN USUARIO VÁLIDO');
        GOTO fin;
    END IF;
    SELECT u.* INTO san_usuario FROM usuarios u WHERE u.id = rand_usuario_id;
    dbms_output.put_line('### EL USUARIO ELEGIDO ES (' || san_usuario.id || ') ' || san_usuario.primer_nombre || ' ' ||
                         san_usuario.primer_apellido);

    dbms_output.put_line('## SE ELIGE UNA APLICACIÓN ALEATORIAMENTE DONDE SE ENCUENTRE REGISTRADO EL USUARIO');
    SELECT r.id_app
    INTO app_id
    FROM registros r
             INNER JOIN contratos c2 ON r.id_app = c2.id_app
             INNER JOIN planes_de_servicio pds ON c2.id_app = pds.id_app AND c2.id_plan = pds.id
    WHERE r.id_usuario = rand_usuario_id
      AND c2.duracion.fecha_fin >= sim_date()
      AND c2.cancelado IS NULL
      AND pds.duracion.fecha_fin >= sim_date()
      AND pds.cancelado IS NULL
    ORDER BY dbms_random.value()
        FETCH FIRST ROW ONLY;

    SELECT ap.* INTO san_app FROM aplicaciones_delivery ap WHERE ap.id = app_id;
    dbms_output.put_line('## SE SELECCIONA LA APP (' || app_id || ') ' || san_app.app.nombre);

    dbms_output.put_line('## SE OBTIENEN LOS CONTRATOS QUE APLIQUEN DE LA APP Y LAS EMPRESAS DE LOS CONTRATOS');
    --CONSULTA LAS SUCURSALES APLICABLES PARA ESA APP
    OPEN empresas_elegibles(app_id, rand_usuario_id);
    FETCH empresas_elegibles INTO fk_pedidos_sucursal;

    --verifica si existe
    IF empresas_elegibles%FOUND THEN

        SELECT *
        INTO direccion_usuario
        FROM direcciones
        WHERE id_usuario = rand_usuario_id
        ORDER BY dbms_random.value()
            FETCH FIRST ROW ONLY;

        LOOP
            EXIT WHEN empresas_elegibles%NOTFOUND;
            SELECT ep.* INTO san_empresa FROM empresas ep WHERE ep.id = fk_pedidos_sucursal.id_empresa;
            dbms_output.put_line('## SE VERIFICA SI LA SUCURSAL MAS CERCANA DE LA EMPRESA (' ||
                                 fk_pedidos_sucursal.id_empresa || ') ' || san_empresa.empresa.nombre ||
                                 ' PUEDE ATENDER EL PEDIDO CON LAS UNIDADES DISPONIBLES DE LA APP');

            id_suc := sucursal_factible(app_id, fk_pedidos_sucursal.id_empresa, direccion_usuario);

            --dbms_output.PUT_LINE('DEBUG '|| id_suc);
            EXIT WHEN id_suc > 0;

            FETCH empresas_elegibles INTO fk_pedidos_sucursal;
        END LOOP;

        IF id_suc > 0 THEN
            dbms_output.put_line('## SE REGISTRA EL PEDIDO');
            crear_pedido_aleatorio(app_id,
                                   fk_pedidos_sucursal.id_plan,
                                   fk_pedidos_sucursal.id_empresa,
                                   fk_pedidos_sucursal.id_contrato,
                                   direccion_usuario.id_estado,
                                   direccion_usuario.id_municipio,
                                   direccion_usuario.id_zona,
                                   rand_usuario_id,
                                   direccion_usuario.id,
                                   id_suc
                );
        ELSE
            dbms_output.put_line('NO SE OBTUVO SUCURSAL');

        END IF;

    ELSE
        dbms_output.put_line('### LA APLICACIÓN NO PRESENTA SERVICIOS O SUCURSALES DISPONIBLES');
    END IF;
    dbms_output.put_line('# SE FINALIZA EL MÓDULO PARA LA GESTIÓN DE PEDIDOS');
    <<fin>>
        NULL;

END;

-- FIN PEDIDOS

-- INICIO DESPACHO

CREATE OR REPLACE FUNCTION unidad_disponible(unidad_id unidades_de_transporte.id%TYPE)
    RETURN BOOLEAN
    IS
    res NUMBER;
BEGIN
    --dbms_output.put_line('VERIFICAMOS SI LA UNIDAD (' || unidad_id || ') ESTÁ DISPONIBLE');
    SELECT COUNT(1)
    INTO res
    FROM rutas r
             INNER JOIN pedidos p ON p.tracking = r.id_traking
    WHERE r.id_unidad = unidad_id
      AND r.proposito IN ('PEDIDO', 'ENVIO')
      AND (p.duracion.fecha_fin IS NULL AND p.cancelado IS NULL AND r.cancelado IS NULL);

    RETURN (res <= 0);

EXCEPTION
    WHEN no_data_found THEN RETURN TRUE;
END;

CREATE OR REPLACE PROCEDURE simular_accidente(unidad_id unidades_de_transporte.id%TYPE,
                                              in_pedido pedidos%ROWTYPE,
                                              nuevo_estado unidades_de_transporte.estado%TYPE,
                                              ruta_id rutas.id%TYPE,
                                              ruta_origen rutas.origen%TYPE,
                                              rapidez tipos_de_unidades.velocidad_media%TYPE,
                                              rehacer_pedido BOOLEAN DEFAULT FALSE)
    IS
    ruta         rutas%ROWTYPE;
    nueva_ubi    UBICACION;
    nuevo_pedido pedidos.tracking%TYPE;
    testo        NUMBER(8, 3);
    a            DATE;
    b            DATE;
BEGIN


    IF nuevo_estado = 'DESCONTINUADA' THEN
        dbms_output.put_line('### LA UNIDAD (' || unidad_id || ') HA SUFRIDO UN ACCIDENTE QUE REQUEIRE DESCONTINUARLA');

        UPDATE unidades_de_transporte
        SET estado = 'DESCONTINUADA'
        WHERE id = unidad_id;
    ELSE
        dbms_output.put_line(
                    '### LA UNIDAD ' || unidad_id || ' HA SUFRIDO UN ACCIDENTE POR LO TANTO DEBE SER REPARADA');
        UPDATE unidades_de_transporte
        SET estado = 'REPARACION'
        WHERE id = unidad_id;
    END IF;

    a := sim_date();
    b := ruta_origen.actualizado;
    testo := (a - b) * 24;

    nueva_ubi := ubicacion.obtener_posicion(ruta.destino, ruta.origen,
                                            rapidez, testo);

    UPDATE rutas r
    SET r.destino   = nueva_ubi,
        r.cancelado = cancelacion(sim_date(), 'LA UNIDAD TIENE EL PEDIDO A MITAD DE CAMINO')
    WHERE r.id = ruta_id;

    IF nuevo_estado = 'DESCONTINUADA' OR rehacer_pedido THEN

        IF nuevo_estado = 'DESCONTINUADA' THEN
            dbms_output.put_line('## LA UNIDAD HA DAÑADO EL PEDIDO ' || in_pedido.tracking ||
                                 ' SE HA NOTIFICADO A LA SUCURSAL PARA LA NUEVA ELABORACION DEL MISMO');
        ELSE
            dbms_output.put_line('### SE HA NOTIFICADO A LA SUCURSAL PARA LA NUEVA ELABORACIÓN DE PEDIDO '
                || in_pedido.tracking);
        END IF;


        UPDATE pedidos p
        SET p.cancelado = cancelacion(sim_date(), 'EL PEDIDO FUE DESTRUIDO O DESCARTADO')
        WHERE p.tracking = in_pedido.tracking;

        INSERT INTO pedidos p
        VALUES (in_pedido.id_app,
                in_pedido.id_plan,
                in_pedido.id_empresa,
                in_pedido.id_contrato,
                DEFAULT,
                in_pedido.id_estado,
                in_pedido.id_municipio,
                in_pedido.id_zona,
                in_pedido.id_usuario,
                in_pedido.id_direccion,
                in_pedido.duracion,
                in_pedido.total,
                NULL,
                NULL,
                in_pedido.tracking)
        RETURNING tracking INTO nuevo_pedido;

        UPDATE detalles
        SET id_tracking = nuevo_pedido
        WHERE id_tracking = in_pedido.tracking;

    ELSE
        dbms_output.put_line('## LA UNIDAD HA ACTUALIZADO SU UBICACION PARA QUE OTRA PUEDA FINALIZAR EL PEDIDO');
    END IF;

END;

CREATE OR REPLACE FUNCTION crear_ubicacion(ubi_ref UBICACION)
    RETURN UBICACION
    IS
BEGIN
    RETURN ubicacion(ubi_ref.latitud, ubi_ref.longitud, sim_date());
END;

CREATE OR REPLACE PROCEDURE modulo_despacho(pedido_sel pedidos%ROWTYPE)
    IS

    --CURSOR SI DE LAS UNIDADES QUE PUEDEN REALIZAR EL PEDIDO (APP,DIR,SUCURSAL)
    CURSOR unidades_permitidas(in_app_id aplicaciones_delivery.id%TYPE,
        in_sucursal sucursales%ROWTYPE,
        in_direccion direcciones%ROWTYPE
        )
        IS
        SELECT udt.id,
               udt.id_garaje,
               tdu.distancia_operativa,
               tdu.velocidad_media,
               tdu.cantidad_pedidos,
               g.ubicacion AS ubicacion_garaje
        FROM garajes g
                 INNER JOIN unidades_de_transporte udt ON g.id_app = udt.id_app AND g.id = udt.id_garaje
                 INNER JOIN tipos_de_unidades tdu ON tdu.id = udt.id_tipo
        WHERE g.id_app = in_app_id                 --APP
          AND g.id_estado = in_direccion.id_estado --ESTADO
          AND udt.estado = 'OPERATIVA'
          AND (
                (g.id_zona = in_sucursal.id_zona
                    AND
                 g.id_zona = in_direccion.id_zona) --ESTAN LOS 3 EN LA MISMA ZONA POR ENDE TODAS PUEDEN ENVIAR
                OR
                (tdu.distancia_operativa IN ('MUNICIPIO', 'ESTADO')
                    AND (g.id_municipio = in_sucursal.id_municipio
                        OR
                         g.id_municipio = in_direccion.id_municipio)) --UNO SE ENCUENTRA EN MUNICIPIO DISTITNO
                OR
                (tdu.distancia_operativa = 'ESTADO'
                    AND g.id_estado = in_sucursal.id_estado
                    AND g.id_estado = in_direccion.id_estado) -- PUEDE ENTREGAR EN EL ESTADO
            )
        ORDER BY tdu.distancia_operativa DESC
    ;
    CURSOR rutas_pedido(pedido_id pedidos.tracking%TYPE)
        IS
        SELECT *
        FROM rutas
        WHERE id_traking = pedido_id
          AND proposito = 'ENVIO'
          AND cancelado IS NOT NULL
        ORDER BY id DESC
            FETCH FIRST ROW ONLY;
    CURSOR pedidos_sucursal(
        capacidad tipos_de_unidades.cantidad_pedidos%TYPE,
        in_sucursal sucursales%ROWTYPE,
        distancia tipos_de_unidades.distancia_operativa%TYPE
        )
        IS
        SELECT p.*, d4.ubicacion
        FROM pedidos p,
             (
                 SELECT d.id_tracking, d.id_sucursal, d.id_empresa
                 FROM detalles d
                 WHERE d.id_sucursal = in_sucursal.id
                 GROUP BY d.id_tracking, d.id_sucursal, d.id_empresa
             ) s,
             direcciones d4
        WHERE p.tracking = s.id_tracking --EQUI JOIN
          AND d4.id = p.id_direccion
          AND p.duracion.fecha_fin IS NULL
          AND p.cancelado IS NULL
          AND p.duracion.fecha_inicio <= (sim_date() - (
            SELECT MAX(NVL(p2.tiempo_de_preparacion, 0)) / 24 / 60
            FROM productos p2
            WHERE p2.id_empresa = s.id_empresa
        ))
          AND 0 = (
            SELECT COUNT(1)
            FROM rutas r
            WHERE r.proposito = 'PEDIDO'
              AND r.id_traking = p.tracking
              AND r.cancelado IS NOT NULL
        )                                --SIN RUTAS EN CAMINO O CANCELADAS
          AND DECODE(distancia, 'ESTADO', d4.id_estado,
                     'MUNICIPIO', d4.id_municipio,
                     d4.id_zona)
            = DECODE(distancia, 'ESTADO', in_sucursal.id_estado,
                     'MUNICIPIO', in_sucursal.id_municipio,
                     in_sucursal.id_zona)
        ORDER BY p.duracion.fecha_inicio
            FETCH FIRST capacidad ROWS ONLY;
    preparacion        NUMBER;
    sucursal_sel       sucursales%ROWTYPE;
    direccion_sel      direcciones%ROWTYPE;
    ruta_actual        rutas%ROWTYPE;
    ruta_id_actual     rutas.id%TYPE;
    ruta_origen_actual rutas.origen%TYPE;
    unidad_trnsp       unidades_permitidas%ROWTYPE;
    TYPE PEDIDO_RUTA IS RECORD (
        pedido pedidos_sucursal%ROWTYPE,
        ruta rutas.id%TYPE
        );
    TYPE LOTE_PEDIDO IS TABLE OF PEDIDO_RUTA;
    maleta             LOTE_PEDIDO := lote_pedido();
    pedido_aux         pedidos%ROWTYPE;
    pedidos_enviados   NUMBER      := 1;

BEGIN
    dbms_output.put_line('# SE INICIA EL MÓDULO PARA LA GESTIÓN DE DESPACHOS');

    --selecciona el pedido mas antigo sin finalizar
    --Y SIN RUTAS CANCELADAS O QUE NO SEA RETORNO
    dbms_output.put_line('## SE SELECIONA EL PEDIDO MÁS ANTIGUO SIN FINALIZAR');

    dbms_output.put_line('## SE OBTIENE EL PEDIDO CON EL NÚMERO DE TRACKING ' || pedido_sel.tracking);


    --veririficar si esta listo (pedido)
    SELECT MAX(NVL(p2.tiempo_de_preparacion, 0)) / 24 / 60
    INTO preparacion
    FROM pedidos p
             INNER JOIN detalles d ON p.tracking = d.id_tracking
             INNER JOIN productos p2 ON d.id_empresa = p2.id_empresa
    WHERE p.tracking = pedido_sel.tracking;

    dbms_output.put_line('## SE VERIFICA SI EL PEDIDO YA FUE ELEBORADO');

    IF pedido_sel.duracion.fecha_inicio + preparacion > sim_date() THEN
        dbms_output.put_line('## EL PEDIDO NO HA SIDO ELABORADO, POR ENDE NO PUEDE SER RECOGIDO');
        GOTO fin;
    END IF;

--    IF pedido_sel.duracion.fecha_inicio + preparacion <= SIM_DATE() THEN

    SELECT d3.*
    INTO direccion_sel
    FROM sucursales s
             INNER JOIN detalles d2 ON d2.id_tracking = pedido_sel.tracking
             INNER JOIN direcciones d3 ON d3.id = pedido_sel.id_direccion
    WHERE s.id = d2.id_sucursal
        FETCH FIRST ROW ONLY;

    SELECT s.*
    INTO sucursal_sel
    FROM sucursales s
             INNER JOIN detalles d2 ON d2.id_tracking = pedido_sel.tracking
             INNER JOIN direcciones d3 ON d3.id = pedido_sel.id_direccion
    WHERE s.id = d2.id_sucursal
        FETCH FIRST ROW ONLY;

    preparacion := 24;
    dbms_output.put_line(
            '## SE CONSULTAN LAS UNIDADES QUE PUEDEN DESPACHAR EL PEDIDO EN FUNCIÓN DE SU PROXIMIDAD Y ALCANCE');


    FOR l_unidad IN unidades_permitidas(pedido_sel.id_app
        , sucursal_sel
        , direccion_sel)
        LOOP
            unidad_trnsp := l_unidad;
            --dbms_output.PUT_LINE('AMAAA');
            IF unidad_disponible(l_unidad.id)
                AND preparacion > ubicacion.obtener_tiempo_estimado_en_horas(
                                          l_unidad.ubicacion_garaje, sucursal_sel.ubicacion, l_unidad.velocidad_media)
                    +
                                  ubicacion.obtener_tiempo_estimado_en_horas(
                                          sucursal_sel.ubicacion, direccion_sel.ubicacion, l_unidad.velocidad_media)
            THEN
                --dbms_output.PUT_LINE('AMAAA asignadaa');
                unidad_trnsp := l_unidad;
                preparacion := ubicacion.obtener_tiempo_estimado_en_horas(
                                       l_unidad.ubicacion_garaje, sucursal_sel.ubicacion, l_unidad.velocidad_media)
                    +
                               ubicacion.obtener_tiempo_estimado_en_horas(
                                       sucursal_sel.ubicacion, direccion_sel.ubicacion, l_unidad.velocidad_media);
            END IF;
        END LOOP;

    IF (unidad_trnsp.id IS NULL) THEN
        --CANCELAR PEDIDO
        dbms_output.put_line('## LA APLICACION YA NO PUEDE REALIZAR ENVÍOS POR LO TANTO DEBERÁ SER CANCELADO');
        UPDATE pedidos p
        SET p.cancelado = cancelacion(sim_date(), 'NO HAY UNIDADES QUE PUEDAN COMPLETAR EL PEDIDO')
        WHERE p.tracking = pedido_sel.tracking;
        GOTO fin;
    ELSIF NOT unidad_disponible(unidad_trnsp.id) THEN
        dbms_output.put_line('## LAS UNIDADES SE ENCUENTRAN REALIZANDO PEDIDOS, EL PEDIDO NO PUEDE SER ATENDIDO');
        GOTO fin;
    END IF;
    --        ELSE
    --
    dbms_output.put_line('## SE HA ASIGNADO LA UNIDAD DE TRANSPORTE ' || unidad_trnsp.id);

    --RELEVO
    /*FOR l_ruta IN rutas_pedido(pedido_sel.tracking)
        LOOP
            dbms_output.put_line('## LA UNIDAD VA A RETOMAR EL PEDIDO DE LA UNIDAD ' || l_ruta.id_unidad);

            --IR A LA ULTIMA UBICACION
            INSERT INTO rutas
            VALUES (pedido_sel.id_app, unidad_trnsp.id_garaje, unidad_trnsp.id,
                    pedido_sel.tracking, DEFAULT,
                    crear_ubicacion(unidad_trnsp.ubicacion_garaje),
                    crear_ubicacion(l_ruta.destino), 'PEDIDO', NULL)
            RETURNING id, origen INTO ruta_id_actual, ruta_origen_actual;

            --ACCIDENTE
            IF dbms_random.value(0, 1) < 0.1 THEN
                UPDATE unidades_de_transporte
                SET estado = 'DESCONTINUADA'
                WHERE id = unidad_trnsp.id;
                dbms_output.put_line('### LA UNIDAD HA SUFRIDO UN ACCIDENTE GRAVE NO PUEDE RETOMAR EL PEDIDO');
                GOTO fin;
            ELSIF dbms_random.value(0, 1) < 0.1 THEN
                UPDATE unidades_de_transporte
                SET estado = 'REPARACION'
                WHERE id = unidad_trnsp.id;
                dbms_output.put_line('### LA UNIDAD HA SUFRIDO UN ACCIDENTE MENOR NO PUEDE RETOMAR EL PEDIDO');
                GOTO fin;
            END IF;

            INSERT INTO rutas
            VALUES (pedido_sel.id_app, l_ruta.id_garaje, l_ruta.id_unidad,
                    pedido_sel.tracking, DEFAULT,
                    crear_ubicacion(unidad_trnsp.ubicacion_garaje),
                    crear_ubicacion(l_ruta.destino), 'PEDIDO', NULL)
            RETURNING id, origen INTO ruta_id_actual, ruta_origen_actual;

            INSERT INTO rutas
            VALUES (pedido_sel.id_app, l_ruta.id_garaje, l_ruta.id_unidad,
                    pedido_sel.tracking, DEFAULT, crear_ubicacion(l_ruta.destino), crear_ubicacion(l_ruta.origen),
                    'RETORNO', NULL);

            INSERT INTO rutas
            VALUES (pedido_sel.id_app, unidad_trnsp.id_garaje, unidad_trnsp.id,
                    pedido_sel.tracking, DEFAULT, crear_ubicacion(l_ruta.destino),
                    crear_ubicacion(direccion_sel.ubicacion), 'ENVIO', NULL)
            RETURNING id, origen INTO ruta_id_actual, ruta_origen_actual;

            dbms_output.put_line('## LA UNIDAD HA RETOMADO EL PEDIDO Y SE DIRIGE AL DESTINO');
            --ACCIDENTE
            IF dbms_random.value(0, 1) > 0.7 THEN

                IF dbms_random.value(0, 1) > 0.5 THEN
                    simular_accidente(unidad_trnsp.id, pedido_sel, 'REPARACION', ruta_id_actual, ruta_origen_actual,
                                      unidad_trnsp.velocidad_media);
                ELSE
                    simular_accidente(unidad_trnsp.id, pedido_sel, 'DESCONTINUADA', ruta_id_actual, ruta_origen_actual,
                                      unidad_trnsp.velocidad_media);
                END IF;

                GOTO fin;
            END IF;

            dbms_output.put_line('## LA UNIDAD HA ENTREGADO EL PEDIDO');
            UPDATE pedidos p
            SET p.valoracion = FLOOR(dbms_random.value(3, 5)),
                p.duracion   = rango_tiempo(p.duracion.fecha_inicio, sim_date())
            WHERE tracking = pedido_sel.tracking;

            dbms_output.put_line('## LA UNIDAD SE REGRESA A SU GARAJE');
            INSERT INTO rutas
            VALUES (pedido_sel.id_app, unidad_trnsp.id_garaje, unidad_trnsp.id,
                    pedido_sel.tracking, DEFAULT, crear_ubicacion(direccion_sel.ubicacion),
                    crear_ubicacion(unidad_trnsp.ubicacion_garaje), 'RETORNO', NULL);

            GOTO fin;
        END LOOP;*/
    --IR A LA SUCURSAL
    dbms_output.put_line('## LA UNIDAD SE DIRIGE A RETIRAR EL PEDIDO EN LA SUCURSAL');
    --por cada pedido en la sucursal listo

    --CARGO LOTE
    FOR n_pedido IN pedidos_sucursal(unidad_trnsp.cantidad_pedidos, sucursal_sel, unidad_trnsp.distancia_operativa)
        LOOP
            maleta.extend();
            maleta(maleta.last).pedido := n_pedido;
        END LOOP;

    ruta_origen_actual := crear_ubicacion(unidad_trnsp.ubicacion_garaje);


    --ACCIDENTE
    IF dbms_random.value(0, 1) < 0.1 THEN
        UPDATE unidades_de_transporte
        SET estado = 'DESCONTINUADA'
        WHERE id = unidad_trnsp.id;
        dbms_output.put_line('### LA UNIDAD HA SUFRIDO UN ACCIDENTE NO SE PUEDE ATENDER EL PEDIDO POR ESTA UNIDAD');
        GOTO fin;
    ELSIF dbms_random.value(0, 1) < 0.1 THEN
        UPDATE unidades_de_transporte
        SET estado = 'REPARACION'
        WHERE id = unidad_trnsp.id;
        dbms_output.put_line(
                '### LA UNIDAD HA SUFRIDO UN ACCIDENTE MENOR NO SE PUEDE ATENDER EL PEDIDO POR ESTA UNIDAD');
        GOTO fin;
    END IF;

    --CREO RUTA A PEDIDO DE TODOS
    FOR l_ped_rut IN maleta.first .. maleta.last
        LOOP
            INSERT INTO rutas
            VALUES (maleta(l_ped_rut).pedido.id_app,
                    unidad_trnsp.id_garaje,
                    unidad_trnsp.id,
                    maleta(l_ped_rut).pedido.tracking,
                    DEFAULT,
                    ruta_origen_actual,
                    crear_ubicacion(sucursal_sel.ubicacion),
                    'PEDIDO',
                    NULL)
            RETURNING id INTO maleta(l_ped_rut).ruta;
        END LOOP;

    dbms_output.put_line('## LA UNIDAD SE DIRIGE A ENVIAR  ' || maleta.count || ' PEDIDO(S)');
    ruta_origen_actual := crear_ubicacion(sucursal_sel.ubicacion);
    <<despacho_a_enesimo_destino>>
        IF (pedidos_enviados > 1) THEN
        ruta_origen_actual := crear_ubicacion(maleta(pedidos_enviados - 1).pedido.ubicacion);
    END IF;
    --AQUI HACE
    FOR l_ped_rut IN pedidos_enviados .. maleta.last
        LOOP
            INSERT INTO rutas
            VALUES (maleta(l_ped_rut).pedido.id_app,
                    unidad_trnsp.id_garaje,
                    unidad_trnsp.id,
                    maleta(l_ped_rut).pedido.tracking,
                    DEFAULT,
                    ruta_origen_actual,
                    crear_ubicacion(maleta(pedidos_enviados).pedido.ubicacion),
                    'ENVIO',
                    NULL)
            RETURNING id INTO maleta(l_ped_rut).ruta;
        END LOOP;

    --ACCIDENTE
    IF dbms_random.value(0, 1) > 0.7 THEN
        IF dbms_random.value(0, 1) > 0.5 THEN
            FOR l_ped_rut IN pedidos_enviados..maleta.last
                LOOP
                    SELECT * INTO pedido_aux FROM pedidos p WHERE maleta(l_ped_rut).pedido.tracking = p.tracking;
                    simular_accidente(
                            unidad_trnsp.id,
                            pedido_aux,
                            'DESCONTINUADA',
                            maleta(l_ped_rut).ruta,
                            ruta_origen_actual,
                            unidad_trnsp.velocidad_media,
                            TRUE);
                END LOOP;
        ELSE
            FOR l_ped_rut IN pedidos_enviados..maleta.last
                LOOP
                    SELECT * INTO pedido_aux FROM pedidos p WHERE maleta(l_ped_rut).pedido.tracking = p.tracking;
                    simular_accidente(unidad_trnsp.id,
                                      pedido_aux,
                                      'DESCONTINUADA',
                                      maleta(l_ped_rut).ruta,
                                      ruta_origen_actual,
                                      unidad_trnsp.velocidad_media,
                                      TRUE);
                END LOOP;
        END IF;
        GOTO fin;
    END IF;

    dbms_output.put_line('## LA UNIDAD HA ENTREGADO EL PEDIDO ' || pedidos_enviados || ' EN SU LISTA DE ENVIOS');

    UPDATE pedidos p
    SET p.valoracion = dbms_random.value(4, 5),
        p.duracion   = rango_tiempo(p.duracion.fecha_inicio, sim_date())
    WHERE tracking = maleta(pedidos_enviados).pedido.tracking;

    IF (pedidos_enviados < maleta.count) THEN
        pedidos_enviados := pedidos_enviados + 1;
        GOTO despacho_a_enesimo_destino;
    ELSE
        dbms_output.put_line('## LA UNIDAD SE REGRESA A SU GARAJE');
        INSERT INTO rutas
        VALUES (pedido_sel.id_app, unidad_trnsp.id_garaje, unidad_trnsp.id, pedido_sel.tracking,
                DEFAULT, direccion_sel.ubicacion, unidad_trnsp.ubicacion_garaje, 'RETORNO', NULL);
    END IF;

    --       END IF;

--    END IF;

    <<fin>>
        NULL;
    dbms_output.put_line('# FINALIZA EL MÓDULO PARA LA GESTIÓN DE DESPACHOS');
EXCEPTION
    WHEN OTHERS THEN dbms_output.put_line('NO HAY PEDIDOS QUE ATENDER');

END;

CREATE OR REPLACE FUNCTION obtener_pedidos RETURN SYS_REFCURSOR
    IS
    pedidos_cur SYS_REFCURSOR;
    d           DATE;
BEGIN
    d := sim_date();
    dbms_output.put_line('## SELECIONAMOS TODOS LOS PEDIDOS VIGENTES');
    OPEN pedidos_cur FOR
        SELECT pd.*
        FROM pedidos pd
        WHERE pd.duracion.fecha_inicio <= sim_date()
          AND pd.duracion.fecha_fin IS NULL
          AND pd.cancelado IS NULL
        ORDER BY pd.duracion.fecha_inicio;
    RETURN pedidos_cur;
END;

CREATE OR REPLACE PROCEDURE realizar_envios
    IS
    pedidos_cur SYS_REFCURSOR;
    pedido      pedidos%ROWTYPE;
BEGIN
    pedidos_cur := obtener_pedidos();
    LOOP
        FETCH pedidos_cur INTO pedido;
        EXIT WHEN pedidos_cur%NOTFOUND;
        dbms_output.put_line(' ');
        dbms_output.put_line('### SE SELECIONA EL PEDIDO CON EL NÚMERO DE TRACKING (' || pedido.tracking || ')');
        modulo_despacho(pedido);
    END LOOP;
END;


-- FIN DESPACHO
CREATE OR REPLACE PROCEDURE simulacion(n_contratos INTEGER, n_pedidos INTEGER, n_despachos INTEGER, n_max_manteniminto INTEGER)
IS
    app_cur SYS_REFCURSOR;
    api APLICACIONES_DELIVERY%ROWTYPE;
    c_contratos INTEGER;
    c_pedidos INTEGER;
    c_despachos INTEGER;
    c_mantenimiento INTEGER;
BEGIN
    c_contratos := 0;
    c_pedidos := 0;
    c_despachos := 0;
    c_mantenimiento := 0;
    IF n_contratos >= 0 AND n_pedidos >= 0 AND n_despachos >=0 AND n_max_manteniminto >=0 THEN
        DBMS_OUTPUT.PUT_LINE(' INICIANDO LA SIMULACIÓN DEL SISTEMA DE DELIVERY');
        DBMS_OUTPUT.PUT_LINE(' EL TIEMPO DE LA SIMULACIÓN ES: ' || TO_CHAR(SIM_DATE(),'dd-mm-yyyy HH:MI:SS'));
        LOOP
            EXIT WHEN c_contratos >= n_contratos;
            modulo_contratos(NULL);
            c_contratos := c_contratos + 1;
        END LOOP;
        LOOP
            EXIT WHEN c_pedidos >= n_pedidos;
            modulo_pedido();
            c_pedidos := c_pedidos + 1;
        END LOOP;
        LOOP
            EXIT WHEN c_despachos >= n_despachos;
            realizar_envios();
            UPDATE_SIM_TIME('AUMENTO DESDE ' || TO_DATE(SIM_DATE(),'dd-mm-yyyy HH:MI:SS'));
            c_despachos := c_despachos + 1;
        END LOOP;
        OPEN app_cur FOR SELECT AD.* FROM APLICACIONES_DELIVERY AD ORDER BY DBMS_RANDOM.VALUE();
        LOOP
            FETCH app_cur INTO api;
            EXIT WHEN app_cur%NOTFOUND OR c_mantenimiento >= n_max_manteniminto;
            modulo_mantenimiento(SIM_DATE(), api.ID);
            c_mantenimiento := c_mantenimiento + 1;
        END LOOP;
    ELSE
        DBMS_OUTPUT.PUT_LINE(' LAS VARIABLES PARA LA SIMULACIÓN DEBEN SER MAYORES O IGUALES A 0');
    END IF;
END;

CREATE OR REPLACE FUNCTION obtener_mapa_lat(origen UBICACION,
                                        destino UBICACION,
                                        velocidad tipos_de_unidades.velocidad_media%TYPE)
    RETURN NUMBER IS

    url  VARCHAR2(68) := 'https://www.mapquestapi.com/staticmap/v5/map?size=170,170&margin=100';
    key  VARCHAR2(32) := 'JX2R0AK3akgJkGxmK9wi5NeAnGRn8rjP';
    moto UBICACION;
BEGIN

    moto := ubicacion.obtener_posicion(destino,
                                       origen,
                                       velocidad,
                                       (sim_date() - origen.actualizado) * 24);

    RETURN
        moto.latitud;
END;

CREATE OR REPLACE FUNCTION obtener_mapa_long(origen UBICACION,
                                        destino UBICACION,
                                        velocidad tipos_de_unidades.velocidad_media%TYPE)
    RETURN NUMBER IS

    url  VARCHAR2(68) := 'https://www.mapquestapi.com/staticmap/v5/map?size=170,170&margin=100';
    key  VARCHAR2(32) := 'JX2R0AK3akgJkGxmK9wi5NeAnGRn8rjP';
    moto UBICACION;
BEGIN

    moto := ubicacion.obtener_posicion(destino,
                                       origen,
                                       velocidad,
                                       (sim_date() - origen.actualizado) * 24);

    RETURN
        moto.longitud;
END;
